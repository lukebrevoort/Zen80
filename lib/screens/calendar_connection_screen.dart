import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/calendar_provider.dart';

/// Screen for connecting to Google Calendar
class CalendarConnectionScreen extends StatelessWidget {
  final bool isOnboarding;
  final VoidCallback? onSkip;
  final VoidCallback? onComplete;

  const CalendarConnectionScreen({
    super.key,
    this.isOnboarding = false,
    this.onSkip,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final calendarProvider = context.watch<CalendarProvider>();

    return Scaffold(
      appBar: isOnboarding
          ? null
          : AppBar(title: const Text('Google Calendar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Skip button for onboarding
              if (isOnboarding) ...[
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: onSkip,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month,
                  size: 48,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Connect Google Calendar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'See your existing calendar events alongside your Signal tasks. '
                'Your Signal tasks will also appear in your calendar.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Benefits list
              _buildBenefitItem(
                icon: Icons.visibility,
                text: 'See busy times when scheduling',
              ),
              _buildBenefitItem(
                icon: Icons.sync,
                text: 'Signal tasks sync to your calendar',
              ),
              _buildBenefitItem(
                icon: Icons.flag,
                text: 'Mark existing events as Signal',
              ),

              const Spacer(),

              // Status indicator
              if (calendarProvider.status ==
                  CalendarConnectionStatus.connecting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(),
                ),

              if (calendarProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    calendarProvider.errorMessage!,
                    style: TextStyle(color: Colors.red.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Connect button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed:
                      calendarProvider.status ==
                          CalendarConnectionStatus.connecting
                      ? null
                      : () => _connect(context),
                  icon: _buildGoogleIcon(),
                  label: const Text('Connect with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),

              if (isOnboarding) ...[
                const SizedBox(height: 16),
                TextButton(onPressed: onSkip, child: const Text('Maybe later')),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    // Simple colored G icon matching Google branding
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFF4285F4), // Blue
                  Color(0xFF34A853), // Green
                  Color(0xFFFBBC04), // Yellow
                  Color(0xFFEA4335), // Red
                ],
              ).createShader(const Rect.fromLTWH(0, 0, 24, 24)),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.green.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Future<void> _connect(BuildContext context) async {
    final provider = context.read<CalendarProvider>();
    final success = await provider.connect();

    if (success && context.mounted) {
      onComplete?.call();
      if (!isOnboarding) {
        Navigator.of(context).pop();
      }
    }
  }
}

/// Connected state UI for settings screen
class CalendarConnectedWidget extends StatelessWidget {
  const CalendarConnectedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final calendarProvider = context.watch<CalendarProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (calendarProvider.userEmail != null)
                      Text(
                        calendarProvider.userEmail!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showDisconnectDialog(context),
                child: Text(
                  'Disconnect',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Calendar selection
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_view_day, size: 20),
          ),
          title: const Text('Selected Calendars'),
          subtitle: Text(calendarProvider.getSelectedCalendarNames()),
          trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
          onTap: () => _showCalendarPicker(context),
        ),

        // Pending sync count
        if (calendarProvider.pendingSyncCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${calendarProvider.pendingSyncCount} changes pending sync',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: calendarProvider.forceSync,
                    child: const Text('Sync Now'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showDisconnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'Your Signal tasks will no longer sync to your calendar. '
          'Existing calendar events created by Signal/Noise will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CalendarProvider>().disconnect();
              Navigator.pop(context);
            },
            child: Text(
              'Disconnect',
              style: TextStyle(color: Colors.red.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCalendarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer<CalendarProvider>(
          builder: (context, calendarProvider, child) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Select Calendars',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: calendarProvider.calendars.length,
                    itemBuilder: (context, index) {
                      final calendar = calendarProvider.calendars[index];
                      final isSelected = calendarProvider.selectedCalendarIds
                          .contains(calendar.id);

                      return CheckboxListTile(
                        secondary: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: calendar.backgroundColor != null
                                ? _parseColor(calendar.backgroundColor!)
                                : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(calendar.summary ?? 'Unnamed'),
                        value: isSelected,
                        onChanged: (value) {
                          calendarProvider.toggleCalendar(calendar.id!);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}
