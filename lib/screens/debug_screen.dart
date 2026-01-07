import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/live_activity_service.dart';
import '../models/task.dart';
import '../providers/signal_task_provider.dart';
import 'daily_planning_flow.dart';
import 'onboarding_screen.dart';

/// Debug screen for testing notifications and Live Activities
/// Access this from the home screen by tapping the app title 5 times
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final NotificationService _notifications = NotificationService();
  final SettingsService _settings = SettingsService();
  final LiveActivityService _liveActivities = LiveActivityService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String _status = 'Ready to test';
  bool _liveActivityActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug / Testing', style: TextStyle(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'NOTIFICATIONS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),

          // 1. Golden Ratio Achievement
          _buildTestCard(
            title: '1. Golden Ratio Achievement',
            description:
                'Triggers when 80%+ signal AND 6+ hours logged.\nNormally only fires once per day.',
            buttonText: 'Test Now',
            onPressed: _testGoldenRatioNotification,
          ),

          // 2. Morning Reminder
          _buildTestCard(
            title: '2. Morning Reminder',
            description:
                'Scheduled daily at wake time (default 8am).\nThis sends an immediate test notification.',
            buttonText: 'Test Now',
            onPressed: _testMorningReminder,
          ),

          // 3. Noise Task Warning
          _buildTestCard(
            title: '3. Noise Task Warning',
            description:
                'Fires after 1 hour on a noise task.\nThis sends immediately for testing.',
            buttonText: 'Test Now',
            onPressed: _testNoiseWarning,
          ),

          // 4. Inactivity Reminder
          _buildTestCard(
            title: '4. Inactivity Reminder',
            description:
                'Fires after 2 hours of no activity (during active hours).\nThis sends immediately for testing.',
            buttonText: 'Test Now',
            onPressed: _testInactivityReminder,
          ),

          const SizedBox(height: 24),
          const Text(
            'LIVE ACTIVITIES (Dynamic Island)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: Live Activities only work on physical iPhones with Dynamic Island (iPhone 14 Pro+). They won\'t appear on simulators.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          // Live Activity - Signal Task
          _buildTestCard(
            title: 'Live Activity - Signal Task',
            description: 'Starts a Live Activity for a signal task timer.',
            buttonText: _liveActivityActive ? 'Active...' : 'Start',
            onPressed: _liveActivityActive ? null : _testLiveActivitySignal,
          ),

          // Live Activity - Noise Task
          _buildTestCard(
            title: 'Live Activity - Noise Task',
            description: 'Starts a Live Activity for a noise task timer.',
            buttonText: _liveActivityActive ? 'Active...' : 'Start',
            onPressed: _liveActivityActive ? null : _testLiveActivityNoise,
          ),

          // Stop Live Activity
          _buildTestCard(
            title: 'Stop Live Activity',
            description: 'Ends any active Live Activity.',
            buttonText: 'Stop',
            onPressed: _stopLiveActivity,
            isDestructive: true,
          ),

          const SizedBox(height: 24),
          const Text(
            'SETTINGS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),

          // Current settings display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingRow(
                    'Wake Time',
                    '${_settings.wakeUpHour}:${_settings.wakeUpMinute.toString().padLeft(2, '0')}',
                  ),
                  _buildSettingRow(
                    'Noise Alert',
                    '${_settings.noiseAlertMinutes} minutes',
                  ),
                  _buildSettingRow(
                    'Inactivity Alert',
                    '${_settings.inactivityAlertMinutes} minutes',
                  ),
                  _buildSettingRow(
                    'Active Hours',
                    '${_settings.wakeUpHour}:00 - ${_settings.wakeUpHour + 8}:00',
                  ),
                  _buildSettingRow(
                    'Currently Active Hours?',
                    _settings.isWithinActiveHours ? 'Yes' : 'No',
                  ),
                  _buildSettingRow(
                    'Golden Ratio Notified Today?',
                    _settings.goldenRatioNotifiedToday ? 'Yes' : 'No',
                  ),
                ],
              ),
            ),
          ),

          // Reset golden ratio flag
          _buildTestCard(
            title: 'Reset Golden Ratio Flag',
            description:
                'Resets the "notified today" flag so you can test the golden ratio notification again.',
            buttonText: 'Reset',
            onPressed: _resetGoldenRatioFlag,
          ),

          // Reset onboarding
          _buildTestCard(
            title: 'Reset Onboarding',
            description:
                'Resets onboarding so it shows again on next app launch.',
            buttonText: 'Reset',
            onPressed: _resetOnboarding,
          ),

          // Test onboarding flow directly
          _buildTestCard(
            title: 'Test Onboarding Flow',
            description:
                'Opens the new 4-step onboarding flow directly without resetting. Great for testing the UI.',
            buttonText: 'Open Onboarding',
            onPressed: () => _openOnboardingFlow(context),
          ),

          const SizedBox(height: 24),
          const Text(
            'TESTING SHORTCUTS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),

          // Clear all tasks and go to daily planning
          _buildTestCard(
            title: 'Clear All Tasks & Start Fresh',
            description:
                'Deletes all tasks for today and navigates to the Daily Planning screen. Great for testing the full flow.',
            buttonText: 'Clear & Start Fresh',
            onPressed: () => _clearAllTasksAndStartFresh(context),
            isDestructive: true,
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback? onPressed,
    bool isDestructive = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: isDestructive
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      )
                    : null,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ============================================================
  // TEST METHODS
  // ============================================================

  Future<void> _testGoldenRatioNotification() async {
    setState(() => _status = 'Sending Golden Ratio notification...');

    // Temporarily reset the flag, send notification, then let it set again
    await _settings.resetGoldenRatioNotification();

    await _notifications.checkGoldenRatioAchievement(
      signalPercentage: 0.85, // 85%
      totalTime: const Duration(hours: 7), // 7 hours
    );

    setState(() => _status = 'Golden Ratio notification sent!');
  }

  Future<void> _testMorningReminder() async {
    setState(() => _status = 'Sending test morning reminder...');

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      99, // Test ID
      'Good Morning! (TEST)',
      'Time to set your Signal tasks for today. What are the 3-5 things that must get done?',
      details,
    );

    setState(() => _status = 'Morning reminder test sent!');
  }

  Future<void> _testNoiseWarning() async {
    setState(() => _status = 'Sending Noise Warning notification...');

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      30, // Noise warning ID
      'Time to Lock Back In',
      'You\'ve been on "Test Noise Task" for over an hour. Consider switching to a Signal task.',
      details,
    );

    setState(() => _status = 'Noise warning notification sent!');
  }

  Future<void> _testInactivityReminder() async {
    setState(() => _status = 'Sending Inactivity notification...');

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      40, // Inactivity ID
      'Time Check',
      'You haven\'t logged any time in a while. What are you working on?',
      details,
    );

    setState(() => _status = 'Inactivity notification sent!');
  }

  Future<void> _testLiveActivitySignal() async {
    setState(() {
      _status = 'Starting Signal Live Activity...';
      _liveActivityActive = true;
    });

    final testTask = Task(
      id: 'test-signal',
      title: 'Test Signal Task',
      type: TaskType.signal,
      createdAt: DateTime.now(),
      date: DateTime.now(),
    );

    await _liveActivities.startTimerActivity(
      task: testTask,
      startedAt: DateTime.now(),
    );

    setState(
      () => _status = 'Signal Live Activity started! Check Dynamic Island.',
    );
  }

  Future<void> _testLiveActivityNoise() async {
    setState(() {
      _status = 'Starting Noise Live Activity...';
      _liveActivityActive = true;
    });

    final testTask = Task(
      id: 'test-noise',
      title: 'Test Noise Task',
      type: TaskType.noise,
      createdAt: DateTime.now(),
      date: DateTime.now(),
    );

    await _liveActivities.startTimerActivity(
      task: testTask,
      startedAt: DateTime.now(),
    );

    setState(
      () => _status = 'Noise Live Activity started! Check Dynamic Island.',
    );
  }

  Future<void> _stopLiveActivity() async {
    setState(() => _status = 'Stopping Live Activity...');

    await _liveActivities.endTimerActivity();

    setState(() {
      _status = 'Live Activity stopped.';
      _liveActivityActive = false;
    });
  }

  Future<void> _resetGoldenRatioFlag() async {
    await _settings.resetGoldenRatioNotification();
    setState(() => _status = 'Golden ratio flag reset. You can test it again.');
  }

  Future<void> _resetOnboarding() async {
    await _settings.resetOnboarding();
    setState(
      () => _status = 'Onboarding reset. Restart the app to see it again.',
    );
  }

  void _openOnboardingFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          onComplete: () {
            Navigator.of(context).pop();
            setState(() => _status = 'Onboarding flow completed!');
          },
        ),
      ),
    );
  }

  Future<void> _clearAllTasksAndStartFresh(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Tasks?'),
        content: const Text(
          'This will delete all tasks for today and take you to the Daily Planning screen. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _status = 'Clearing all tasks...');

    final taskProvider = context.read<SignalTaskProvider>();

    // Delete all tasks for today
    final tasksToDelete = List<String>.from(
      taskProvider.tasks.map((t) => t.id),
    );
    for (final taskId in tasksToDelete) {
      await taskProvider.deleteTask(taskId);
    }

    setState(
      () => _status = 'All tasks cleared! Navigating to Daily Planning...',
    );

    // Navigate to Daily Planning screen
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DailyPlanningFlow()),
        (route) => false,
      );
    }
  }
}
