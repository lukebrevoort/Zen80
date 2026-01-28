import 'dart:async';

import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/signal_task.dart';
import '../models/time_slot.dart';
import '../models/google_calendar_event.dart';
import '../providers/signal_task_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/calendar_provider.dart';
import '../services/notification_service.dart';
import '../widgets/scheduling/split_schedule_dialog.dart';
import '../widgets/common/blinking_dot.dart';

/// Wrapper to represent either a SignalTask or an external GoogleCalendarEvent
/// This allows us to display both types in the same calendar view
class CalendarItem {
  final SignalTask? signalTask;
  final TimeSlot? timeSlot; // The specific time slot for Signal tasks
  final GoogleCalendarEvent? externalEvent;

  CalendarItem.fromSignalTask(this.signalTask, this.timeSlot)
    : externalEvent = null;
  CalendarItem.fromExternalEvent(this.externalEvent)
    : signalTask = null,
      timeSlot = null;

  bool get isSignalTask => signalTask != null;
  bool get isExternalEvent => externalEvent != null;

  String get title => signalTask?.title ?? externalEvent?.title ?? 'Unknown';
}

/// Screen for initial scheduling of today's tasks
/// Forces user to schedule ALL tasks before proceeding to dashboard
class InitialSchedulingScreen extends StatefulWidget {
  const InitialSchedulingScreen({super.key});

  @override
  State<InitialSchedulingScreen> createState() =>
      _InitialSchedulingScreenState();
}

class _InitialSchedulingScreenState extends State<InitialSchedulingScreen> {
  final Uuid _uuid = const Uuid();
  final DateTime _today = DateTime.now();
  late EventController<CalendarItem> _eventController;

  // For drag-and-drop functionality
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey<DayViewState<CalendarItem>> _dayViewKey = GlobalKey();
  bool _isDragging = false;
  Offset? _dragPosition; // Track current drag position for time preview
  DateTime? _previewTime; // The time at the current drag position
  SignalTask? _draggingTask; // The task being dragged
  Timer? _autoScrollTimer; // Timer for auto-scrolling during drag
  bool _isStartingDay = false; // Loading state for "Start My Day" button

  @override
  void initState() {
    super.initState();
    _eventController = EventController<CalendarItem>();
    // Load existing scheduled tasks and external events into calendar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAllEventsToCalendar();
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _eventController.dispose();
    super.dispose();
  }

  /// Sync Signal tasks from provider to calendar controller
  void _syncTasksToCalendar() {
    final taskProvider = context.read<SignalTaskProvider>();

    for (final task in taskProvider.scheduledTasks) {
      for (final slot in task.timeSlots) {
        // Skip discarded slots - they shouldn't appear on the calendar
        if (slot.isDiscarded) continue;

        // Use calendarStartTime/calendarEndTime which respect session finalization:
        // - Finalized sessions (completed + past 15min merge window) use actual times
        // - Active/resumable sessions use session times or planned times
        if (_isSameDay(slot.calendarStartTime, _today)) {
          _addSignalTaskToCalendar(task, slot);
        }
      }
    }
  }

  /// Sync external Google Calendar events to the calendar
  Future<void> _syncExternalEventsToCalendar() async {
    final calendarProvider = context.read<CalendarProvider>();

    // Only load if connected to Google Calendar
    if (!calendarProvider.isConnected) return;

    // Load events for today
    await calendarProvider.loadEventsForDate(_today);

    // Add external events (not Signal tasks) to the calendar
    for (final event in calendarProvider.externalEvents) {
      if (_isSameDay(event.startTime, _today) && !event.isAllDay) {
        // Skip if this event has already been imported to a Signal task
        if (_isEventAlreadyImported(event.id)) {
          continue;
        }
        _addExternalEventToCalendar(event);
      }
    }
  }

  /// Sync all events (Signal tasks + external Google Calendar events)
  Future<void> _syncAllEventsToCalendar() async {
    _eventController.removeWhere((event) => true);
    _syncTasksToCalendar();
    await _syncExternalEventsToCalendar();
    if (mounted) setState(() {});
  }

  /// Check if an external event has already been imported
  bool _isEventAlreadyImported(String externalEventId) {
    final taskProvider = context.read<SignalTaskProvider>();
    final allTasks = taskProvider.tasks;

    for (final task in allTasks) {
      for (final slot in task.timeSlots) {
        if (slot.externalCalendarEventId == externalEventId) {
          return true;
        }
      }
    }
    return false;
  }

  /// Calculate projected signal ratio based on scheduled tasks
  double _getProjectedRatio(
    SignalTaskProvider taskProvider,
    SettingsProvider settingsProvider,
  ) {
    final schedule = settingsProvider.todaySchedule;

    // Use effective focus window if the user started early.
    // This affects the denominator (total focus window minutes).
    final effectiveStart = settingsProvider.getEffectiveStartTime(_today);
    final effectiveEnd = schedule.getEndTimeForDate(_today);

    final activeMinutes = effectiveStart != null
        ? effectiveEnd.difference(effectiveStart).inMinutes
        : schedule.activeMinutes;

    if (activeMinutes <= 0) return 0;

    final signalMinutes = taskProvider.totalEstimatedMinutes;
    return (signalMinutes / activeMinutes).clamp(0.0, 1.0);
  }

  bool get _allTasksScheduled {
    final taskProvider = context.read<SignalTaskProvider>();
    return taskProvider.unscheduledTasks.isEmpty;
  }

  void _startMyDay() async {
    if (!_allTasksScheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please schedule all tasks before starting your day'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show loading state
    setState(() {
      _isStartingDay = true;
    });

    try {
      final taskProvider = context.read<SignalTaskProvider>();
      final settingsProvider = context.read<SettingsProvider>();

      // 1. Sync all scheduled slots to Google Calendar
      final syncedCount = await taskProvider.syncScheduledSlotsToCalendar();

      if (syncedCount > 0 && mounted) {
        debugPrint('Synced $syncedCount time slots to Google Calendar');
      }

      // 2. Schedule notifications for all tasks
      // Get notification timing preferences from settings
      final minutesBeforeStart =
          settingsProvider.notificationBeforeStartMinutes;
      final minutesBeforeEnd = settingsProvider.notificationBeforeEndMinutes;

      for (final task in taskProvider.scheduledTasks) {
        // Only schedule if user has enabled the relevant notification types
        if (settingsProvider.enableStartReminders ||
            settingsProvider.enableEndReminders) {
          await NotificationService().scheduleTaskNotifications(
            task: task,
            minutesBeforeStart: settingsProvider.enableStartReminders
                ? minutesBeforeStart
                : 0,
            minutesBeforeEnd: settingsProvider.enableEndReminders
                ? minutesBeforeEnd
                : 0,
          );
        }
      }

      debugPrint(
        'Scheduled notifications for ${taskProvider.scheduledTasks.length} tasks',
      );

      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      // Handle sync errors gracefully - don't block the user
      debugPrint('Calendar sync error: $e');

      if (mounted) {
        // Show a non-blocking warning but still let them proceed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Calendar sync had an issue, but you can still start your day',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
          ),
        );

        // Navigate anyway - calendar sync is nice-to-have, not blocking
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingDay = false;
        });
      }
    }
  }

  void _onCalendarTap(DateTime dateTime) async {
    final taskProvider = context.read<SignalTaskProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final unscheduledTasks = taskProvider.unscheduledTasks;
    final schedule = settingsProvider.todaySchedule;

    if (unscheduledTasks.isEmpty) return;

    // Validate the tapped time is within active hours
    final timeOfDay = TimeOfDay.fromDateTime(dateTime);
    if (!_isTimeWithinActiveHours(timeOfDay, schedule)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a time within your focus hours (${_formatActiveHoursRange(schedule)})',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    // If only one unscheduled task, schedule it directly
    if (unscheduledTasks.length == 1) {
      await _scheduleTaskAt(unscheduledTasks.first, dateTime);
      return;
    }

    // Multiple tasks - show picker
    final task = await _showTaskPicker(unscheduledTasks, dateTime);
    if (task != null) {
      await _scheduleTaskAt(task, dateTime);
    }
  }

  Future<void> _scheduleTaskAt(SignalTask task, DateTime startTime) async {
    // Round to nearest 15 minutes
    final roundedStart = _roundToNearestQuarterHour(startTime);

    // If task has remaining unscheduled time, show split dialog
    if (task.unscheduledMinutes > 0) {
      final duration = await _showSplitScheduleDialog(task, roundedStart);
      if (duration == null) return; // User cancelled

      await _createTimeSlot(task, roundedStart, duration);
    }
  }

  Future<Duration?> _showSplitScheduleDialog(
    SignalTask task,
    DateTime dropTime,
  ) async {
    return showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SplitScheduleDialog(
          task: task,
          dropTime: dropTime,
          onCancel: () => Navigator.pop(context),
          onSchedule: (duration) => Navigator.pop(context, duration),
        ),
      ),
    );
  }

  Future<void> _createTimeSlot(
    SignalTask task,
    DateTime startTime,
    Duration duration,
  ) async {
    final provider = context.read<SignalTaskProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final endTime = startTime.add(duration);

    final slot = TimeSlot(
      id: _uuid.v4(),
      plannedStartTime: startTime,
      plannedEndTime: endTime,
      linkedSubTaskIds: [],
    );

    await provider.addTimeSlotToTask(task.id, slot);

    // Sync this new slot to Google Calendar (for slots added after initial scheduling)
    // Get the updated task with the new slot
    final updatedTask = provider.getTask(task.id);
    if (updatedTask != null) {
      final addedSlot = updatedTask.timeSlots.firstWhere(
        (s) => s.id == slot.id,
        orElse: () => slot,
      );
      try {
        await provider.syncTimeSlotToCalendarIfNeeded(updatedTask, addedSlot);
      } catch (e) {
        debugPrint('Failed to sync slot to calendar: $e');
      }

      // Schedule notifications for this new slot
      try {
        if (settingsProvider.enableStartReminders ||
            settingsProvider.enableEndReminders) {
          await NotificationService().scheduleSlotNotifications(
            task: updatedTask,
            slot: addedSlot,
            minutesBeforeStart: settingsProvider.enableStartReminders
                ? settingsProvider.notificationBeforeStartMinutes
                : 0,
            minutesBeforeEnd: settingsProvider.enableEndReminders
                ? settingsProvider.notificationBeforeEndMinutes
                : 0,
          );
        }
      } catch (e) {
        debugPrint('Failed to schedule notifications: $e');
      }
    }

    // Add to calendar with bounds checking
    _addSignalTaskToCalendar(task, slot);

    setState(() {});
  }

  Future<SignalTask?> _showTaskPicker(
    List<SignalTask> tasks,
    DateTime dropTime,
  ) async {
    return showModalBottomSheet<SignalTask>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _TaskPickerSheet(tasks: tasks, dropTime: dropTime),
    );
  }

  void _showScheduleTaskDialog(SignalTask task) async {
    final settingsProvider = context.read<SettingsProvider>();
    final schedule = settingsProvider.todaySchedule;

    // Default to current time rounded up, or start of active hours
    final now = DateTime.now();
    var defaultStart = _roundToNearestQuarterHour(now);
    if (defaultStart.hour < schedule.activeStartHour) {
      defaultStart = DateTime(
        _today.year,
        _today.month,
        _today.day,
        schedule.activeStartHour,
        0,
      );
    }
    // Also clamp to before active end hour
    if (defaultStart.hour >= schedule.activeEndHour) {
      defaultStart = DateTime(
        _today.year,
        _today.month,
        _today.day,
        schedule.activeEndHour - 1,
        0,
      );
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(defaultStart),
      initialEntryMode: TimePickerEntryMode.input,
      helpText:
          'Schedule "${task.title}" (${_formatActiveHoursRange(schedule)})',
    );

    if (pickedTime == null || !mounted) return;

    // Validate the picked time is within active hours
    final isValidTime = _isTimeWithinActiveHours(pickedTime, schedule);
    if (!isValidTime) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a time within your focus hours (${_formatActiveHoursRange(schedule)})',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }

    final startTime = DateTime(
      _today.year,
      _today.month,
      _today.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Use the same split dialog flow as drag-and-drop
    await _scheduleTaskAt(task, startTime);
  }

  /// Check if a TimeOfDay is within active hours
  bool _isTimeWithinActiveHours(TimeOfDay time, dynamic schedule) {
    final hour = time.hour;
    // Task must start at or after active start, and before active end
    return hour >= schedule.activeStartHour && hour < schedule.activeEndHour;
  }

  /// Format active hours range for display
  String _formatActiveHoursRange(dynamic schedule) {
    final startHour = schedule.activeStartHour;
    final endHour = schedule.activeEndHour;
    return '${startHour.toString().padLeft(2, '0')}:00 - ${endHour.toString().padLeft(2, '0')}:00';
  }

  void _onEventTap(
    List<CalendarEventData<CalendarItem>> events,
    DateTime date,
  ) {
    if (events.isEmpty) return;

    final event = events.first;
    final item = event.event;
    if (item == null) return;

    // Only allow editing Signal tasks, not external events
    if (item.isSignalTask && item.signalTask != null) {
      _showEventOptions(item.signalTask!, event);
    } else if (item.isExternalEvent && item.externalEvent != null) {
      _showExternalEventInfo(item.externalEvent!);
    }
  }

  /// Show info sheet for external Google Calendar events
  void _showExternalEventInfo(GoogleCalendarEvent event) {
    final calendarProvider = context.read<CalendarProvider>();
    String calendarName;

    try {
      final calendar = calendarProvider.calendars.firstWhere(
        (c) => c.id == event.calendarId,
      );
      calendarName = calendar.summary ?? 'Unknown';
    } catch (_) {
      calendarName = event.calendarId;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Google Calendar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      calendarName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeRange(event.startTime, event.endTime),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (event.description != null &&
                  event.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  event.description!,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showMarkAsSignalOptions(event);
                  },
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Add to Signal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add this event as a Signal task or link to an existing task.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Create a NEW Signal task from an external Google Calendar event
  Future<void> _createNewTaskFromExternalEvent(
    GoogleCalendarEvent event,
  ) async {
    final taskProvider = context.read<SignalTaskProvider>();
    final calendarProvider = context.read<CalendarProvider>();

    final durationMinutes = event.duration.inMinutes;

    final eventDate = DateTime(
      event.startTime.year,
      event.startTime.month,
      event.startTime.day,
    );

    final task = SignalTask(
      id: const Uuid().v4(),
      title: event.title,
      estimatedMinutes: durationMinutes,
      tagIds: [],
      subTasks: [],
      status: TaskStatus.notStarted,
      scheduledDate: eventDate,
      timeSlots: [
        TimeSlot(
          id: const Uuid().v4(),
          plannedStartTime: event.startTime,
          plannedEndTime: event.endTime,
          autoEnd: true,
          linkedSubTaskIds: [],
          externalCalendarEventId: event.id,
        ),
      ],
      isComplete: false,
      createdAt: DateTime.now(),
    );

    await taskProvider.addSignalTask(task);

    await calendarProvider.markEventAsSignal(event.id);

    await _syncAllEventsToCalendar();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${event.title}" added as a new Signal task'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  /// Add an external Google Calendar event to an EXISTING Signal task
  Future<void> _addExternalEventToExistingTask(
    GoogleCalendarEvent event,
    SignalTask task,
  ) async {
    final taskProvider = context.read<SignalTaskProvider>();
    final calendarProvider = context.read<CalendarProvider>();

    final slot = TimeSlot(
      id: const Uuid().v4(),
      plannedStartTime: event.startTime,
      plannedEndTime: event.endTime,
      autoEnd: true,
      linkedSubTaskIds: [],
      externalCalendarEventId: event.id,
    );

    await taskProvider.addTimeSlotToTask(task.id, slot);

    await calendarProvider.markEventAsSignal(event.id);

    await _syncAllEventsToCalendar();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added time slot to "${task.title}"'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  /// Show options for how to add an external event to Signal
  void _showMarkAsSignalOptions(GoogleCalendarEvent event) {
    final taskProvider = context.read<SignalTaskProvider>();

    final eventDate = DateTime(
      event.startTime.year,
      event.startTime.month,
      event.startTime.day,
    );
    final tasksForDate = taskProvider.getTasksForDate(eventDate);

    final alreadyImported = _isEventAlreadyImported(event.id);

    if (alreadyImported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${event.title}" has already been added to Signal'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade600,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add to Signal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'How would you like to add "${event.title}"?',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.add_circle_outline,
                title: 'Create new Signal task',
                subtitle: 'Make a new task titled "${event.title}"',
                onTap: () {
                  Navigator.pop(context);
                  _createNewTaskFromExternalEvent(event);
                },
              ),
              const SizedBox(height: 12),
              if (tasksForDate.isNotEmpty) ...[
                _buildOptionTile(
                  icon: Icons.playlist_add,
                  title: 'Add to existing task',
                  subtitle:
                      '${tasksForDate.length} task${tasksForDate.length > 1 ? 's' : ''} on this day',
                  onTap: () {
                    Navigator.pop(context);
                    _showExistingTaskSelection(event, tasksForDate);
                  },
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No existing tasks on this day to add to',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Build an option tile for the Mark as Signal options sheet
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// Show list of existing tasks to add the external event to
  void _showExistingTaskSelection(
    GoogleCalendarEvent event,
    List<SignalTask> tasks,
  ) {
    final tagProvider = context.read<TagProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a task',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add "${event.title}" time slot to:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: tasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final tags = tagProvider.getTagsByIds(task.tagIds);

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _addExternalEventToExistingTask(event, task);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: task.isComplete
                                      ? Colors.green
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                                color: task.isComplete
                                    ? Colors.green
                                    : Colors.transparent,
                              ),
                              child: task.isComplete
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        task.formattedEstimatedTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (tags.isNotEmpty) ...[
                                        const SizedBox(width: 12),
                                        ...tags
                                            .take(2)
                                            .map(
                                              (tag) => Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: tag.color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventOptions(
    SignalTask task,
    CalendarEventData<CalendarItem> event,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Change time'),
                onTap: () async {
                  Navigator.pop(context);
                  await _rescheduleTask(task, event);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove from schedule'),
                onTap: () async {
                  Navigator.pop(context);
                  await _removeSchedule(task, event);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rescheduleTask(
    SignalTask task,
    CalendarEventData<CalendarItem> event,
  ) async {
    final settingsProvider = context.read<SettingsProvider>();
    final schedule = settingsProvider.todaySchedule;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(event.startTime!),
      initialEntryMode: TimePickerEntryMode.input,
      helpText:
          'Reschedule "${task.title}" (${_formatActiveHoursRange(schedule)})',
    );

    if (pickedTime == null || !mounted) return;

    // Validate the picked time is within active hours
    final isValidTime = _isTimeWithinActiveHours(pickedTime, schedule);
    if (!isValidTime) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a time within your focus hours (${_formatActiveHoursRange(schedule)})',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }

    final provider = context.read<SignalTaskProvider>();

    // Find and update the time slot
    final slot = task.timeSlots.firstWhere(
      (s) =>
          s.plannedStartTime.hour == event.startTime!.hour &&
          s.plannedStartTime.minute == event.startTime!.minute,
      orElse: () => throw StateError('Slot not found for reschedule'),
    );

    // Cancel existing notifications for this slot before updating
    try {
      await NotificationService().cancelSlotNotifications(slot.id);
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }

    final newStart = DateTime(
      _today.year,
      _today.month,
      _today.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final duration = slot.plannedEndTime.difference(slot.plannedStartTime);
    final newEnd = newStart.add(duration);

    await provider.updateTimeSlot(
      task.id,
      slot.id,
      startTime: newStart,
      endTime: newEnd,
    );

    // Schedule new notifications for the updated slot
    final updatedSlot = slot.copyWith(
      plannedStartTime: newStart,
      plannedEndTime: newEnd,
    );

    try {
      if (settingsProvider.enableStartReminders ||
          settingsProvider.enableEndReminders) {
        await NotificationService().scheduleSlotNotifications(
          task: task,
          slot: updatedSlot,
          minutesBeforeStart: settingsProvider.enableStartReminders
              ? settingsProvider.notificationBeforeStartMinutes
              : 0,
          minutesBeforeEnd: settingsProvider.enableEndReminders
              ? settingsProvider.notificationBeforeEndMinutes
              : 0,
        );
      }
    } catch (e) {
      debugPrint('Failed to schedule notifications: $e');
    }

    // Update calendar with bounds checking
    _eventController.remove(event);
    _addSignalTaskToCalendar(task, updatedSlot);
  }

  Future<void> _removeSchedule(
    SignalTask task,
    CalendarEventData<CalendarItem> event,
  ) async {
    final provider = context.read<SignalTaskProvider>();

    // Find and remove the time slot
    final slot = task.timeSlots.firstWhere(
      (s) =>
          s.plannedStartTime.hour == event.startTime!.hour &&
          s.plannedStartTime.minute == event.startTime!.minute,
      orElse: () => throw StateError('Slot not found for reschedule'),
    );

    // Cancel notifications for this slot before removing
    try {
      await NotificationService().cancelSlotNotifications(slot.id);
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }

    await provider.removeTimeSlot(task.id, slot.id);

    // Update calendar
    _eventController.remove(event);
    setState(() {});
  }

  DateTime _roundToNearestQuarterHour(DateTime dateTime) {
    final minutes = dateTime.minute;
    final roundedMinutes = ((minutes + 7.5) ~/ 15) * 15;
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour + (roundedMinutes == 60 ? 1 : 0),
      roundedMinutes == 60 ? 0 : roundedMinutes,
    );
  }

  Color _getTaskColor(SignalTask task) {
    final tagProvider = context.read<TagProvider>();
    if (task.tagIds.isNotEmpty) {
      final tag = tagProvider.getTag(task.tagIds.first);
      if (tag != null) return tag.color;
    }
    return Colors.black87;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Clamp end time to not cross midnight (calendar_view requirement)
  DateTime _clampToEndOfDay(DateTime endTime, DateTime referenceDay) {
    final endOfDay = DateTime(
      referenceDay.year,
      referenceDay.month,
      referenceDay.day,
      23,
      59,
    );
    if (endTime.isAfter(endOfDay) || !_isSameDay(endTime, referenceDay)) {
      return endOfDay;
    }
    return endTime;
  }

  /// Calculate time from drop position on the calendar
  DateTime? _calculateTimeFromPosition(
    Offset globalPosition,
    int startHour,
    int endHour,
  ) {
    final calendarBox =
        _calendarKey.currentContext?.findRenderObject() as RenderBox?;
    if (calendarBox == null) return null;

    final localPosition = calendarBox.globalToLocal(globalPosition);

    // Account for timeline width (56 pixels)
    if (localPosition.dx < 56) return null;

    // Get scroll offset from DayView's internal ScrollController
    final scrollOffset =
        _dayViewKey.currentState?.scrollController.offset ?? 0.0;

    // Use the same heightPerMinute as DayView (1.2)
    const double heightPerMinute = 1.2;

    // Add scroll offset to get absolute position in the scrollable content
    final absoluteY = localPosition.dy + scrollOffset;

    // Calculate minutes from the start of the day (0:00)
    final minutesFromDayStart = (absoluteY / heightPerMinute).round();

    // Clamp to the active hours range
    final totalMinutes = (endHour - startHour) * 60;
    final clampedMinutes = minutesFromDayStart.clamp(0, totalMinutes - 1);

    final hour = startHour + (clampedMinutes ~/ 60);
    final minute = clampedMinutes % 60;

    return DateTime(_today.year, _today.month, _today.day, hour, minute);
  }

  /// Handle task dropped on calendar
  void _onTaskDropped(
    SignalTask task,
    Offset position,
    int startHour,
    int endHour,
  ) {
    final dropTime = _calculateTimeFromPosition(position, startHour, endHour);
    if (dropTime != null) {
      // Validate the drop time is within active hours
      final timeOfDay = TimeOfDay.fromDateTime(dropTime);
      final settingsProvider = context.read<SettingsProvider>();
      final schedule = settingsProvider.todaySchedule;

      if (!_isTimeWithinActiveHours(timeOfDay, schedule)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please drop within your focus hours (${_formatActiveHoursRange(schedule)})',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      _scheduleTaskAt(task, dropTime);
    }
  }

  /// Add a Signal task event to calendar with proper bounds checking.
  /// Uses calendarStartTime/calendarEndTime which respect session finalization.
  void _addSignalTaskToCalendar(SignalTask task, TimeSlot slot) {
    final displayStart = slot.calendarStartTime;
    final displayEnd = slot.calendarEndTime;
    final clampedEnd = _clampToEndOfDay(displayEnd, _today);

    // Ensure startTime is before endTime
    if (!displayStart.isBefore(clampedEnd)) {
      return; // Invalid event, skip
    }

    _eventController.add(
      CalendarEventData<CalendarItem>(
        date: _today,
        startTime: displayStart,
        endTime: clampedEnd,
        title: task.title,
        event: CalendarItem.fromSignalTask(task, slot),
        color: _getTaskColor(task),
      ),
    );
  }

  /// Add an external Google Calendar event to the calendar (read-only, grayed)
  void _addExternalEventToCalendar(GoogleCalendarEvent event) {
    final localStart = event.startTime.toLocal();
    final localEnd = event.endTime.toLocal();
    final clampedEnd = _clampToEndOfDay(localEnd, _today);

    if (!localStart.isBefore(clampedEnd)) {
      return;
    }

    _eventController.add(
      CalendarEventData<CalendarItem>(
        date: _today,
        startTime: localStart,
        endTime: clampedEnd,
        title: event.title,
        event: CalendarItem.fromExternalEvent(event),
        color: Colors.grey.shade400,
      ),
    );
  }

  /// Build the drag time indicator that shows where the task will be placed
  Widget _buildDragTimeIndicator(dynamic schedule) {
    if (_previewTime == null || _draggingTask == null) {
      return const SizedBox.shrink();
    }

    // Round to nearest 15 minutes for snap effect
    final roundedTime = _roundToNearestQuarterHour(_previewTime!);

    // Calculate preview block height based on task duration
    final taskDurationMinutes = _draggingTask!.estimatedMinutes;

    // Format time for display
    final timeStr = _formatTime(roundedTime);
    final endTime = roundedTime.add(Duration(minutes: taskDurationMinutes));
    final endTimeStr = _formatTime(endTime);

    // Show a floating time indicator at the top of the calendar
    // This avoids issues with scroll position and coordinate systems
    return Positioned(
      left: 56,
      right: 8,
      top: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_draggingTask!.title} • $timeStr - $endTimeStr',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle auto-scrolling when dragging near the top or bottom edge of the calendar
  void _handleAutoScroll(double localY, double viewportHeight) {
    const double edgeThreshold = 60.0;
    const double scrollSpeed = 5.0;

    _autoScrollTimer?.cancel();

    final scrollController = _dayViewKey.currentState?.scrollController;
    if (scrollController == null || !scrollController.hasClients) return;

    if (localY < edgeThreshold && scrollController.offset > 0) {
      // Near top edge - scroll up
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final newOffset = (scrollController.offset - scrollSpeed).clamp(
          0.0,
          scrollController.position.maxScrollExtent,
        );
        scrollController.jumpTo(newOffset);
        // Recalculate preview time as we scroll
        if (_dragPosition != null && mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final schedule = settingsProvider.todaySchedule;
          // Use effective start hour which respects early start overrides
          final effectiveStartHour = settingsProvider
              .getEffectiveStartHourForDate(_today);
          final displayStartHour = (effectiveStartHour - 1).clamp(0, 23);
          final newPreviewTime = _calculateTimeFromPosition(
            _dragPosition!,
            displayStartHour,
            schedule.activeEndHour,
          );
          if (newPreviewTime != _previewTime) {
            setState(() => _previewTime = newPreviewTime);
          }
        }
      });
    } else if (localY > viewportHeight - edgeThreshold &&
        scrollController.offset < scrollController.position.maxScrollExtent) {
      // Near bottom edge - scroll down
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final newOffset = (scrollController.offset + scrollSpeed).clamp(
          0.0,
          scrollController.position.maxScrollExtent,
        );
        scrollController.jumpTo(newOffset);
        // Recalculate preview time as we scroll
        if (_dragPosition != null && mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final schedule = settingsProvider.todaySchedule;
          // Use effective start hour which respects early start overrides
          final effectiveStartHour = settingsProvider
              .getEffectiveStartHourForDate(_today);
          final displayStartHour = (effectiveStartHour - 1).clamp(0, 23);
          final newPreviewTime = _calculateTimeFromPosition(
            _dragPosition!,
            displayStartHour,
            schedule.activeEndHour,
          );
          if (newPreviewTime != _previewTime) {
            setState(() => _previewTime = newPreviewTime);
          }
        }
      });
    }
  }

  /// Stop auto-scrolling
  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<SignalTaskProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final scheduledTasks = taskProvider.scheduledTasks;
    final unscheduledTasks = taskProvider.unscheduledTasks;
    final ratio = _getProjectedRatio(taskProvider, settingsProvider);
    final percentage = (ratio * 100).toInt();
    final schedule = settingsProvider.todaySchedule;
    // Start 1 hour earlier than effective start time to provide visual buffer
    // Use effective start hour which respects any early start overrides
    final effectiveStartHour = settingsProvider.getEffectiveStartHourForDate(
      _today,
    );
    final displayStartHour = effectiveStartHour > 0
        ? effectiveStartHour - 1
        : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Schedule Your Day'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Ratio preview
          _buildRatioPreview(percentage, ratio >= 0.8),

          // Main content - calendar and unscheduled tasks
          Expanded(
            child: Column(
              children: [
                // Calendar section with drag target
                Expanded(
                  flex: 3,
                  child: DragTarget<SignalTask>(
                    onWillAcceptWithDetails: (details) {
                      if (!_isDragging) {
                        setState(() {
                          _isDragging = true;
                          _draggingTask = details.data;
                        });
                      }
                      return true;
                    },
                    onMove: (details) {
                      // Update drag position and calculate preview time
                      final previewTime = _calculateTimeFromPosition(
                        details.offset,
                        displayStartHour,
                        schedule.activeEndHour,
                      );
                      if (previewTime != _previewTime ||
                          _dragPosition != details.offset) {
                        setState(() {
                          _dragPosition = details.offset;
                          _previewTime = previewTime;
                        });
                      }

                      // Handle auto-scroll when near edges
                      final calendarBox =
                          _calendarKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      if (calendarBox != null) {
                        final localPosition = calendarBox.globalToLocal(
                          details.offset,
                        );
                        _handleAutoScroll(
                          localPosition.dy,
                          calendarBox.size.height,
                        );
                      }
                    },
                    onLeave: (_) {
                      _stopAutoScroll();
                      setState(() {
                        _isDragging = false;
                        _dragPosition = null;
                        _previewTime = null;
                        _draggingTask = null;
                      });
                    },
                    onAcceptWithDetails: (details) {
                      _stopAutoScroll();
                      setState(() {
                        _isDragging = false;
                        _dragPosition = null;
                        _previewTime = null;
                        _draggingTask = null;
                      });
                      _onTaskDropped(
                        details.data,
                        details.offset,
                        displayStartHour,
                        schedule.activeEndHour,
                      );
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Stack(
                        children: [
                          CalendarControllerProvider<CalendarItem>(
                            key: _calendarKey,
                            controller: _eventController,
                            child: DayView<CalendarItem>(
                              key: _dayViewKey,
                              controller: _eventController,
                              showVerticalLine: false,
                              minDay: _today,
                              maxDay: _today,
                              initialDay: _today,
                              heightPerMinute: 1.2,
                              startHour: displayStartHour,
                              endHour: schedule.activeEndHour,
                              showHalfHours: true,
                              dayTitleBuilder: (_) => const SizedBox.shrink(),
                              timeLineBuilder: (date) => _buildTimeLabel(date),
                              eventTileBuilder:
                                  (date, events, boundary, start, end) =>
                                      _buildEventTile(events, boundary),
                              onDateLongPress: _onCalendarTap,
                              onEventTap: _onEventTap,
                              backgroundColor: _isDragging
                                  ? Colors.blue.shade50
                                  : Colors.white,
                              timeLineWidth: 56,
                              liveTimeIndicatorSettings:
                                  LiveTimeIndicatorSettings(
                                    color: Colors.red,
                                    height: 2,
                                  ),
                              hourIndicatorSettings: HourIndicatorSettings(
                                color: Colors.grey.shade200,
                                height: 1,
                              ),
                              halfHourIndicatorSettings: HourIndicatorSettings(
                                color: Colors.grey.shade100,
                                height: 1,
                              ),
                            ),
                          ),
                          // Time indicator line at drag position
                          if (_isDragging &&
                              _previewTime != null &&
                              _draggingTask != null)
                            _buildDragTimeIndicator(schedule),
                        ],
                      );
                    },
                  ),
                ),

                // Divider
                Container(height: 1, color: Colors.grey.shade200),

                // Unscheduled tasks section
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.grey.shade50,
                    child: _buildUnscheduledSection(unscheduledTasks),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(
        scheduledTasks.isNotEmpty && unscheduledTasks.isEmpty,
      ),
    );
  }

  Widget _buildTimeLabel(DateTime date) {
    // Only show label for full hours, not half hours
    if (date.minute != 0) {
      return const SizedBox(width: 56);
    }

    final hour = date.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return Container(
      width: 56,
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        '$displayHour $period',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEventTile(
    List<CalendarEventData<CalendarItem>> events,
    Rect boundary,
  ) {
    if (events.isEmpty) return const SizedBox.shrink();

    final event = events.first;
    final item = event.event;
    if (item == null) return const SizedBox.shrink();

    // External Google Calendar events (read-only)
    if (item.isExternalEvent && item.externalEvent != null) {
      return GestureDetector(
        onTap: () => _onEventTap(events, event.date),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: Colors.grey.shade500, width: 3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          clipBehavior: Clip.hardEdge,
          child: Text(
            event.title,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Signal task events
    final task = item.signalTask;
    final slot = item.timeSlot;
    if (task == null || slot == null) return const SizedBox.shrink();

    final status = slot.displayStatus;
    final baseColor = event.color;

    // Calculate available height for content (accounting for padding/margin)
    final availableHeight =
        boundary.height - 4; // 2px vertical margin on each side

    // Determine event size category based on available height
    final isVerySmallEvent = availableHeight < 24; // ~15min events
    final isSmallEvent = availableHeight < 36; // ~30min events
    final isMediumEvent = availableHeight < 50; // ~45min events

    // Visual indicators based on status
    Color bgColor = baseColor.withValues(alpha: 0.65);
    BorderSide leftBorder = BorderSide(color: baseColor, width: 3);
    Widget? statusIcon;

    switch (status) {
      case TimeSlotStatus.scheduled:
        bgColor = baseColor.withValues(alpha: 0.65);
        leftBorder = BorderSide(color: baseColor, width: 3);
        break;
      case TimeSlotStatus.active:
        bgColor = baseColor.withValues(alpha: 0.9);
        leftBorder = BorderSide(color: Colors.green.shade600, width: 4);
        if (!isVerySmallEvent) {
          statusIcon = Container(
            margin: const EdgeInsets.only(right: 6),
            child: const BlinkingDot(),
          );
        }
        break;
      case TimeSlotStatus.completed:
        bgColor = baseColor.withValues(alpha: 0.85);
        leftBorder = BorderSide(color: baseColor, width: 3);
        if (!isVerySmallEvent) {
          statusIcon = Icon(
            Icons.check_circle,
            size: 12,
            color: _getContrastColor(bgColor).withValues(alpha: 0.7),
          );
        }
        break;
      case TimeSlotStatus.missed:
        bgColor = Colors.grey.shade300;
        leftBorder = BorderSide(color: Colors.red.shade400, width: 3);
        if (!isVerySmallEvent) {
          statusIcon = Container(
            padding: const EdgeInsets.all(2),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 14,
              color: Colors.red.shade600,
            ),
          );
        }
        break;
      case TimeSlotStatus.discarded:
        // Shouldn't appear on calendar, but handle gracefully
        return const SizedBox.shrink();
    }

    final textColor = status == TimeSlotStatus.missed
        ? Colors.grey.shade700
        : _getContrastColor(bgColor);

    return GestureDetector(
      onTap: () => _onEventTap(events, event.date),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: leftBorder),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: isVerySmallEvent ? 1 : (isSmallEvent ? 2 : 4),
        ),
        clipBehavior: Clip.hardEdge,
        child: isVerySmallEvent
            // For very small events (~15min), show only title in a single row
            ? Row(
                children: [
                  if (statusIcon != null) statusIcon,
                  Expanded(
                    child: Text(
                      event.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        decoration: status == TimeSlotStatus.missed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : isSmallEvent
            // For small events (~30min), show title with optional icon
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (statusIcon != null) ...[
                    statusIcon,
                    const SizedBox(width: 2),
                  ],
                  Expanded(
                    child: Text(
                      event.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        decoration: status == TimeSlotStatus.missed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            // For larger events, show title, time, and status info
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (statusIcon != null) ...[
                        statusIcon,
                        const SizedBox(width: 2),
                      ],
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: status == TimeSlotStatus.missed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!isMediumEvent) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTimeRange(event.startTime!, event.endTime!),
                      style: TextStyle(
                        color: status == TimeSlotStatus.missed
                            ? Colors.grey.shade600
                            : textColor.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                  // Show actual times if different from planned (for completed slots)
                  if (availableHeight > 55 &&
                      status == TimeSlotStatus.completed &&
                      slot.actualDiffersFromPlanned) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Actual: ${_formatTimeRange(slot.actualStartTime!, slot.actualEndTime!)}',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.65),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  // Show variance badge for completed slots - high contrast pills
                  if (availableHeight > 70 &&
                      status == TimeSlotStatus.completed &&
                      slot.startVariance.inMinutes.abs() > 2) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: slot.startVariance.isNegative
                            ? Colors.green.shade600
                            : Colors.red.shade500,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        slot.formattedStartVariance,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildRatioPreview(int percentage, bool isGoodRatio) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGoodRatio ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGoodRatio ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGoodRatio ? Icons.trending_up : Icons.trending_flat,
            color: isGoodRatio ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Projected Signal Ratio',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '$percentage% Signal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isGoodRatio
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (!isGoodRatio)
            Text(
              'Aim for 80%+',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnscheduledSection(List<SignalTask> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'All tasks scheduled!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "You're ready to start your day",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.pending_actions, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              'Needs Scheduling (${tasks.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Drag tasks to the calendar, or tap to pick a time',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        ...tasks.map(
          (task) => _UnscheduledTaskTile(
            task: task,
            color: _getTaskColor(task),
            onSchedule: () => _showScheduleTaskDialog(task),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool canStart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: canStart && !_isStartingDay ? _startMyDay : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: _isStartingDay
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  canStart ? 'Start My Day' : 'Schedule All Tasks to Continue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

/// Tile for unscheduled task (draggable)
class _UnscheduledTaskTile extends StatelessWidget {
  final SignalTask task;
  final Color color;
  final VoidCallback onSchedule;

  const _UnscheduledTaskTile({
    required this.task,
    required this.color,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<SignalTask>(
      data: task,
      delay: const Duration(milliseconds: 150),
      // Position feedback above the finger/touch point for better visibility
      feedbackOffset: const Offset(0, -80),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.formattedEstimatedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildTileContent()),
      child: GestureDetector(onTap: onSchedule, child: _buildTileContent()),
    );
  }

  Widget _buildTileContent() {
    final isPartial = task.isPartiallyScheduled;
    final remainingText = isPartial
        ? '${task.formattedUnscheduledTime} remaining'
        : task.formattedEstimatedTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPartial ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          remainingText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isPartial
                                ? Colors.orange.shade700
                                : Colors.grey.shade500,
                            fontWeight: isPartial ? FontWeight.w500 : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.drag_indicator, color: Colors.grey.shade400),
            ],
          ),

          // Progress bar for partially scheduled tasks
          if (isPartial) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.scheduledPercentage,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(Colors.orange.shade400),
            ),
            const SizedBox(height: 4),
            Text(
              '${task.formattedScheduledTime} of ${task.formattedEstimatedTime} scheduled',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sheet for picking a task to schedule
class _TaskPickerSheet extends StatelessWidget {
  final List<SignalTask> tasks;
  final DateTime dropTime;

  const _TaskPickerSheet({required this.tasks, required this.dropTime});

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final tagProvider = context.watch<TagProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule at ${_formatTime(dropTime)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a task to schedule',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ...tasks.map((task) {
              final color = task.tagIds.isNotEmpty
                  ? tagProvider.getTag(task.tagIds.first)?.color ??
                        Colors.black87
                  : Colors.black87;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                title: Text(task.title),
                subtitle: Text(task.formattedEstimatedTime),
                onTap: () => Navigator.pop(context, task),
              );
            }),
          ],
        ),
      ),
    );
  }
}
