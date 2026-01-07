import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/background_sync_service.dart';
import '../services/sync_service.dart';
import '../providers/calendar_provider.dart';
import '../providers/settings_provider.dart';
import '../models/day_schedule.dart';
import 'tag_management_screen.dart';
import 'calendar_connection_screen.dart';
import 'weekly_review_screen.dart';
import 'onboarding/schedule_setup_screen.dart';
import 'onboarding/timezone_screen.dart';

/// Settings screen for configuring app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  final NotificationService _notifications = NotificationService();
  final BackgroundSyncService _backgroundSync = BackgroundSyncService();

  late int _wakeUpHour;
  late int _wakeUpMinute;
  late int _noiseAlertMinutes;
  late int _inactivityAlertMinutes;
  SyncFrequency _syncFrequency = SyncFrequency.minutes15;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _wakeUpHour = _settings.wakeUpHour;
      _wakeUpMinute = _settings.wakeUpMinute;
      _noiseAlertMinutes = _settings.noiseAlertMinutes;
      _inactivityAlertMinutes = _settings.inactivityAlertMinutes;
    });
    _loadSyncSettings();
  }

  Future<void> _loadSyncSettings() async {
    final frequency = await _backgroundSync.getSyncFrequency();
    final lastSync = await SyncService().getLastSyncTime();
    if (mounted) {
      setState(() {
        _syncFrequency = frequency;
        _lastSyncTime = lastSync;
      });
    }
  }

  Future<void> _selectWakeTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _wakeUpHour, minute: _wakeUpMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _wakeUpHour = picked.hour;
        _wakeUpMinute = picked.minute;
      });
      await _settings.setWakeUpTime(picked.hour, picked.minute);
      await _notifications.scheduleMorningReminder();
    }
  }

  Future<void> _selectNoiseAlertTime() async {
    final result = await _showDurationPicker(
      title: 'Noise Task Alert',
      subtitle: 'Get reminded after spending this long on a noise task',
      currentMinutes: _noiseAlertMinutes,
      options: [15, 30, 45, 60, 90, 120],
    );

    if (result != null) {
      setState(() => _noiseAlertMinutes = result);
      await _settings.setNoiseAlertMinutes(result);
    }
  }

  Future<void> _selectInactivityTime() async {
    final result = await _showDurationPicker(
      title: 'Inactivity Reminder',
      subtitle: 'Get reminded after this long without logging time',
      currentMinutes: _inactivityAlertMinutes,
      options: [30, 60, 90, 120, 180, 240],
    );

    if (result != null) {
      setState(() => _inactivityAlertMinutes = result);
      await _settings.setInactivityAlertMinutes(result);
    }
  }

  void _openFocusTimesSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScheduleSetupScreen(
          onContinue: () => Navigator.of(context).pop(),
          onBack: () => Navigator.of(context).pop(),
          isOnboarding: false,
        ),
      ),
    );
  }

  void _openTimezoneSettings() {
    final settingsProvider = context.read<SettingsProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimezoneScreen(
          onContinue: () => Navigator.of(context).pop(),
          onBack: () => Navigator.of(context).pop(),
          onTimezoneSelected: (timezone) async {
            await settingsProvider.setTimezone(timezone);
          },
          currentTimezone: settingsProvider.timezone,
          isOnboarding: false,
        ),
      ),
    );
  }

  Future<int?> _showDurationPicker({
    required String title,
    required String subtitle,
    required int currentMinutes,
    required List<int> options,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (fixed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Options (scrollable)
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final minutes = options[index];
                        final isSelected = minutes == currentMinutes;
                        return ListTile(
                          onTap: () => Navigator.pop(context, minutes),
                          title: Text(_formatMinutes(minutes)),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.black)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tileColor: isSelected ? Colors.grey.shade100 : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else if (minutes == 60) {
      return '1 hour';
    } else if (minutes % 60 == 0) {
      return '${minutes ~/ 60} hours';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '$hours hour${hours > 1 ? 's' : ''} $mins min';
    }
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  String _formatLastSyncTime() {
    if (_lastSyncTime == null) return 'Never';

    final now = DateTime.now();
    final diff = now.difference(_lastSyncTime!);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Future<void> _selectSyncFrequency() async {
    final result = await showModalBottomSheet<SyncFrequency>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Background Sync',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How often to sync with Google Calendar in the background',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...SyncFrequency.values.map((frequency) {
                final isSelected = frequency == _syncFrequency;
                return ListTile(
                  onTap: () => Navigator.pop(context, frequency),
                  title: Text(frequency.displayName),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.black)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tileColor: isSelected ? Colors.grey.shade100 : null,
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (result != null && result != _syncFrequency) {
      await _backgroundSync.setSyncFrequency(result);
      setState(() {
        _syncFrequency = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Focus Times section
          _buildSectionHeader('FOCUS TIMES'),
          _buildFocusTimesCard(),

          const SizedBox(height: 24),

          // Schedule section
          _buildSectionHeader('SCHEDULE'),
          _buildSettingTile(
            icon: Icons.wb_sunny_outlined,
            title: 'Wake Time',
            subtitle: 'Morning reminder & active hours start',
            value: _formatTime(_wakeUpHour, _wakeUpMinute),
            onTap: _selectWakeTime,
          ),
          _buildSettingTile(
            icon: Icons.public,
            title: 'Timezone',
            subtitle: 'Your local timezone for scheduling',
            value: '',
            onTap: _openTimezoneSettings,
          ),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return _buildInfoTile('Timezone: ${settings.effectiveTimezone}');
            },
          ),

          const SizedBox(height: 24),

          // Notifications section
          _buildSectionHeader('NOTIFICATIONS'),
          _buildSettingTile(
            icon: Icons.timer_outlined,
            title: 'Noise Task Alert',
            subtitle: 'Remind me after spending too long on noise',
            value: _formatMinutes(_noiseAlertMinutes),
            onTap: _selectNoiseAlertTime,
          ),
          _buildSettingTile(
            icon: Icons.hourglass_empty,
            title: 'Inactivity Reminder',
            subtitle: 'Remind me if I haven\'t logged time',
            value: _formatMinutes(_inactivityAlertMinutes),
            onTap: _selectInactivityTime,
          ),

          const SizedBox(height: 24),

          // Tags section
          _buildSectionHeader('ORGANIZATION'),
          _buildSettingTile(
            icon: Icons.label_outline,
            title: 'Manage Tags',
            subtitle: 'Create and customize task tags',
            value: '',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagManagementScreen()),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.insights,
            title: 'Weekly Review',
            subtitle: 'View your productivity analytics',
            value: '',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WeeklyReviewScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // Calendar section
          _buildSectionHeader('CALENDAR'),
          Consumer<CalendarProvider>(
            builder: (context, calendarProvider, child) {
              if (calendarProvider.isConnected) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: CalendarConnectedWidget(),
                    ),
                    const SizedBox(height: 16),
                    // Background sync frequency
                    _buildSettingTile(
                      icon: Icons.sync,
                      title: 'Background Sync',
                      subtitle: 'Sync with Google Calendar automatically',
                      value: _syncFrequency.displayName,
                      onTap: _selectSyncFrequency,
                    ),
                    // Last sync time
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Last synced: ${_formatLastSyncTime()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return _buildSettingTile(
                  icon: Icons.calendar_month,
                  title: 'Connect Google Calendar',
                  subtitle: 'See events and sync tasks',
                  value: '',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CalendarConnectionScreen(),
                      ),
                    );
                  },
                );
              }
            },
          ),

          const SizedBox(height: 24),

          // Info section
          _buildSectionHeader('ABOUT'),
          _buildInfoCard(),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.black, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusTimesCard() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final schedule = settings.weeklySchedule;
        final totalHours = settings.totalWeeklyActiveHours;
        final activeDays = schedule.values.where((s) => s.isActiveDay).length;
        final avgHours = activeDays > 0 ? totalHours / activeDays : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            elevation: 0,
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: _openFocusTimesSettings,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Focus Times',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Your productive hours for Signal Ratio',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Summary stats
                    Row(
                      children: [
                        _buildFocusStat(
                          '${totalHours.toStringAsFixed(1)}h',
                          'Weekly',
                        ),
                        const SizedBox(width: 16),
                        _buildFocusStat('$activeDays', 'Active Days'),
                        const SizedBox(width: 16),
                        _buildFocusStat(
                          '${avgHours.toStringAsFixed(1)}h',
                          'Daily Avg',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Day pills
                    _buildDayPills(schedule),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFocusStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPills(Map<int, DaySchedule> schedule) {
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final dayOfWeek = index + 1; // 1 = Monday, 7 = Sunday
        final daySchedule = schedule[dayOfWeek];
        final isEnabled = daySchedule?.isActiveDay ?? false;

        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isEnabled ? Colors.black : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              dayNames[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEnabled ? Colors.white : Colors.grey.shade500,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Signal / Noise',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Based on Steve Jobs\' productivity philosophy: identify 3-5 critical tasks (Signal) each day and aim to spend 80% of your time on them.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatChip('80%', 'Golden Ratio'),
                  const SizedBox(width: 12),
                  _buildStatChip('3-5', 'Signal Tasks'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
