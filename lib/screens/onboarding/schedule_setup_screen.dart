import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/day_schedule.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/focus_hours_dial.dart';

/// Focus Goal Screen - Configure daily focus hours
class ScheduleSetupScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final bool isOnboarding; // If true, shows onboarding-specific UI

  const ScheduleSetupScreen({
    super.key,
    required this.onContinue,
    this.onBack,
    this.onSkip,
    this.isOnboarding = true,
  });

  @override
  State<ScheduleSetupScreen> createState() => _ScheduleSetupScreenState();
}

class _ScheduleSetupScreenState extends State<ScheduleSetupScreen> {
  late Map<int, DaySchedule> _weeklySchedule;
  int _focusHoursPerDay = 8;
  bool _isLoading = false;

  // Common presets for quick selection
  static const List<_SchedulePreset> _presets = [
    _SchedulePreset(
      name: 'Standard (9-5)',
      startHour: 9,
      startMinute: 0,
      endHour: 17,
      endMinute: 0,
      description: 'Traditional work hours',
    ),
    _SchedulePreset(
      name: 'Early Bird (6 AM - 2 PM)',
      startHour: 6,
      startMinute: 0,
      endHour: 14,
      endMinute: 0,
      description: 'Morning focused',
    ),
    _SchedulePreset(
      name: 'Night Owl (12 PM - 2 AM)',
      startHour: 12,
      startMinute: 0,
      endHour: 2,
      endMinute: 0,
      description: 'Late night work sessions',
    ),
    _SchedulePreset(
      name: 'Full Day (8 AM - 11 PM)',
      startHour: 8,
      startMinute: 0,
      endHour: 23,
      endMinute: 0,
      description: 'Maximum flexibility',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentSchedule();
  }

  void _loadCurrentSchedule() {
    final settings = context.read<SettingsProvider>();
    _weeklySchedule = {
      for (var day = 1; day <= 7; day++)
        day: DaySchedule(
          dayOfWeek: day,
          activeStartHour: 0,
          activeStartMinute: 0,
          activeEndHour: 23,
          activeEndMinute: 59,
          isActiveDay: true,
        ),
    };
    _focusHoursPerDay = settings.focusHoursPerDay;
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);

    try {
      final settings = context.read<SettingsProvider>();
      await settings.setFocusHoursPerDay(_focusHoursPerDay);
      await settings.updateWeeklySchedule(_weeklySchedule);
      await settings.completeScheduleSetup();
      widget.onContinue();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save schedule: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyPresetToAll(_SchedulePreset preset) {
    setState(() {
      for (var day = 1; day <= 7; day++) {
        _weeklySchedule[day] = DaySchedule(
          dayOfWeek: day,
          activeStartHour: preset.startHour,
          activeStartMinute: preset.startMinute,
          activeEndHour: preset.endHour,
          activeEndMinute: preset.endMinute,
          isActiveDay: true,
        );
      }
    });
  }

  void _editDaySchedule(int dayOfWeek) async {
    final schedule =
        _weeklySchedule[dayOfWeek] ?? DaySchedule(dayOfWeek: dayOfWeek);

    final result = await showModalBottomSheet<DaySchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _DayScheduleEditor(schedule: schedule, presets: _presets),
    );

    if (result != null) {
      setState(() {
        _weeklySchedule[dayOfWeek] = result;
      });
    }
  }

  void _toggleDayActive(int dayOfWeek) {
    final schedule = _weeklySchedule[dayOfWeek];
    if (schedule != null) {
      setState(() {
        _weeklySchedule[dayOfWeek] = schedule.copyWith(
          isActiveDay: !schedule.isActiveDay,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Title and description
                    _buildTitleSection(),

                    const SizedBox(height: 32),

                    _buildFocusGoalSection(),

                    const SizedBox(height: 32),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Continue button
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 48),
          if (widget.isOnboarding)
            Text(
              'Step 2 of 4',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: Text(
                'Skip',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set Your Focus Goal',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose how many hours you want to focus each day. This powers your Signal Ratio while your schedule below keeps planning on track.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pro tip: Your focus goal is separate from your active hours.',
                  style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFocusGoalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Focus Goal',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              FocusHoursDial(
                hours: _focusHoursPerDay,
                onChanged: (value) => setState(() {
                  _focusHoursPerDay = value;
                }),
              ),
              const SizedBox(height: 8),
              Text(
                'Aim high. Max out at 12.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Presets',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _presets.map((preset) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildPresetChip(preset),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(_SchedulePreset preset) {
    return InkWell(
      onTap: () => _applyPresetToAll(preset),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preset.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              preset.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Weekly Schedule',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: List.generate(7, (index) {
              final dayOfWeek = index + 1; // 1 = Monday, 7 = Sunday
              final schedule =
                  _weeklySchedule[dayOfWeek] ??
                  DaySchedule(dayOfWeek: dayOfWeek);
              final isLast = index == 6;

              return Column(
                children: [
                  _buildDayRow(schedule),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDayRow(DaySchedule schedule) {
    final isActive = schedule.isActiveDay;

    return InkWell(
      onTap: () => _editDaySchedule(schedule.dayOfWeek),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Day toggle
            GestureDetector(
              onTap: () => _toggleDayActive(schedule.dayOfWeek),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? Colors.black : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 16),

            // Day name
            SizedBox(
              width: 80,
              child: Text(
                schedule.dayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.black : Colors.grey.shade400,
                ),
              ),
            ),

            // Time range
            Expanded(
              child: Text(
                isActive ? schedule.formattedActiveHours : 'Off',
                style: TextStyle(
                  fontSize: 14,
                  color: isActive ? Colors.grey.shade700 : Colors.grey.shade400,
                ),
              ),
            ),

            // Hours badge
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${schedule.activeHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummary() {
    final totalMinutes = _weeklySchedule.values.fold<int>(
      0,
      (sum, schedule) => sum + schedule.activeMinutes,
    );
    final totalHours = totalMinutes / 60;
    final activeDays = _weeklySchedule.values
        .where((s) => s.isActiveDay)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            value: '${totalHours.toStringAsFixed(1)}h',
            label: 'Weekly Total',
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade700),
          _buildSummaryItem(value: '$activeDays', label: 'Active Days'),
          Container(width: 1, height: 40, color: Colors.grey.shade700),
          _buildSummaryItem(
            value:
                '${(totalHours / (activeDays > 0 ? activeDays : 1)).toStringAsFixed(1)}h',
            label: 'Daily Average',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveAndContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Continue',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

/// Day Schedule Editor - Bottom sheet for editing a single day's schedule
class _DayScheduleEditor extends StatefulWidget {
  final DaySchedule schedule;
  final List<_SchedulePreset> presets;

  const _DayScheduleEditor({required this.schedule, required this.presets});

  @override
  State<_DayScheduleEditor> createState() => _DayScheduleEditorState();
}

class _DayScheduleEditorState extends State<_DayScheduleEditor> {
  late int _startHour;
  late int _startMinute;
  late int _endHour;
  late int _endMinute;
  late bool _isActive;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    // Sanitize hours on initialization - legacy data may have hour=24 ("end of day")
    // which is invalid for our 0-23 dropdown. Convert 24 to 0 (midnight).
    _startHour = _sanitizeHour(widget.schedule.activeStartHour);
    _startMinute = widget.schedule.activeStartMinute.clamp(0, 59);
    _endHour = _sanitizeHour(widget.schedule.activeEndHour);
    _endMinute = widget.schedule.activeEndMinute.clamp(0, 59);
    _isActive = widget.schedule.isActiveDay;
    _validate();
  }

  /// Sanitize hour values - convert legacy 24 to 0, clamp to valid range
  int _sanitizeHour(int hour) {
    if (hour == 24) return 0; // Legacy "end of day" becomes midnight
    return hour.clamp(0, 23);
  }

  void _validate() {
    final testSchedule = DaySchedule(
      dayOfWeek: widget.schedule.dayOfWeek,
      activeStartHour: _startHour,
      activeStartMinute: _startMinute,
      activeEndHour: _endHour,
      activeEndMinute: _endMinute,
      isActiveDay: _isActive,
    );
    setState(() {
      _validationError = testSchedule.validate();
    });
  }

  bool get _crossesMidnight {
    final startMinutes = _startHour * 60 + _startMinute;
    final endMinutes = _endHour * 60 + _endMinute;
    return endMinutes < startMinutes;
  }

  void _save() {
    if (_validationError != null) return;

    final schedule = DaySchedule(
      dayOfWeek: widget.schedule.dayOfWeek,
      activeStartHour: _startHour,
      activeStartMinute: _startMinute,
      activeEndHour: _endHour,
      activeEndMinute: _endMinute,
      isActiveDay: _isActive,
    );
    Navigator.pop(context, schedule);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.schedule.dayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Active toggle
              Row(
                children: [
                  Text(
                    _isActive ? 'Active' : 'Off',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() => _isActive = value);
                      _validate();
                    },
                    activeColor: Colors.black,
                  ),
                ],
              ),
            ],
          ),

          if (_isActive) ...[
            const SizedBox(height: 32),

            // Start time
            Text(
              'Start Time',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimePicker(
              hour: _startHour,
              minute: _startMinute,
              onChanged: (hour, minute) {
                setState(() {
                  _startHour = hour;
                  _startMinute = minute;
                });
                _validate();
              },
            ),

            const SizedBox(height: 24),

            // End time
            Row(
              children: [
                Text(
                  'End Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_crossesMidnight) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Next day',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _buildTimePicker(
              hour: _endHour,
              minute: _endMinute,
              onChanged: (hour, minute) {
                setState(() {
                  _endHour = hour;
                  _endMinute = minute;
                });
                _validate();
              },
            ),

            // Validation error
            if (_validationError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 32),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _validationError == null ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required int hour,
    required int minute,
    required void Function(int hour, int minute) onChanged,
  }) {
    // Defensive: older persisted data used 24 to represent "end of day".
    // Our model expects 0-23.
    final safeHour = hour == 24 ? 0 : hour.clamp(0, 23);
    final timeOfDay = TimeOfDay(hour: safeHour, minute: minute);

    return InkWell(
      onTap: () async {
        final TimeOfDay? newTime = await showTimePicker(
          context: context,
          initialTime: timeOfDay,
          initialEntryMode: TimePickerEntryMode.input, // Text input by default
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Colors.black, // Header background color
                  onPrimary: Colors.white, // Header text color
                  onSurface: Colors.black, // Body text color
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black, // Button text color
                  ),
                ),
              ),
              child: child!,
            );
          },
        );

        if (newTime != null) {
          onChanged(newTime.hour, newTime.minute);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              timeOfDay.format(context),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

/// Preset schedule option
class _SchedulePreset {
  final String name;
  final String description;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const _SchedulePreset({
    required this.name,
    required this.description,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}
