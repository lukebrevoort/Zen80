import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/signal_task.dart';
import '../models/time_slot.dart';
import '../providers/signal_task_provider.dart';
import '../providers/tag_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/tags/tag_chip.dart';
import '../widgets/timer/task_timer_modal.dart';
import 'scheduling_screen.dart';
import 'edit_signal_task_screen.dart';
import 'add_signal_task_screen.dart';

import 'settings_screen.dart';
import 'debug_screen.dart';
import 'weekly_review_screen.dart';

/// Main home screen - Dashboard view for executing daily tasks
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _titleTapCount = 0;
  DateTime? _lastTapTime;

  void _onTitleTap() {
    final now = DateTime.now();

    // Reset if more than 2 seconds since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 2) {
      _titleTapCount = 0;
    }

    _lastTapTime = now;
    _titleTapCount++;

    if (_titleTapCount >= 5) {
      _titleTapCount = 0;
      _navigateToDebug();
    }
  }

  void _navigateToDebug() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DebugScreen()));
  }

  void _navigateToScheduling() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SchedulingScreen()));
  }

  void _navigateToEditTask(String taskId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditSignalTaskScreen(taskId: taskId)),
    );
  }

  void _navigateToAddTask() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddSignalTaskScreen()));
  }

  void _navigateToSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _navigateToWeeklyReview() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WeeklyReviewScreen()));
  }

  /// Calculate signal ratio for today based on elapsed time
  /// Signal ratio = time spent on signal tasks / elapsed active time
  double _getSignalRatio(
    SignalTaskProvider taskProvider,
    SettingsProvider settingsProvider,
  ) {
    final schedule = settingsProvider.todaySchedule;
    final now = DateTime.now();

    // Use effective start time if the user started early today.
    // This ensures early work (before configured start) counts toward the ratio.
    final effectiveStart = settingsProvider.getEffectiveStartTime(
      DateTime(now.year, now.month, now.day),
    );

    int elapsedMinutes;
    if (effectiveStart != null) {
      final effectiveEnd = schedule.getEndTimeForDate(now);

      if (!now.isAfter(effectiveStart)) {
        elapsedMinutes = 0;
      } else {
        final cappedNow = now.isAfter(effectiveEnd) ? effectiveEnd : now;
        elapsedMinutes = cappedNow.difference(effectiveStart).inMinutes;
        if (elapsedMinutes < 0) elapsedMinutes = 0;
      }
    } else {
      // Default behavior: elapsed since configured start
      elapsedMinutes = schedule.getElapsedMinutes(now);
    }

    if (elapsedMinutes == 0) return 0;

    // Signal time is actual minutes worked on signal tasks
    final signalMinutes = taskProvider.totalActualMinutes;
    return (signalMinutes / elapsedMinutes).clamp(0.0, 1.0);
  }

  /// Get tasks sorted by schedule time (scheduled first, then unscheduled)
  List<SignalTask> _getSortedTasks(SignalTaskProvider provider) {
    final tasks = List<SignalTask>.from(provider.tasks);

    // Sort: scheduled tasks by start time first, then unscheduled
    tasks.sort((a, b) {
      // Completed tasks go last
      if (a.isComplete && !b.isComplete) return 1;
      if (!a.isComplete && b.isComplete) return -1;

      // Scheduled tasks before unscheduled
      if (a.isScheduled && !b.isScheduled) return -1;
      if (!a.isScheduled && b.isScheduled) return 1;

      // Both scheduled: sort by earliest time slot
      if (a.isScheduled && b.isScheduled) {
        final aStart = a.earliestTimeSlot?.plannedStartTime;
        final bStart = b.earliestTimeSlot?.plannedStartTime;
        if (aStart != null && bStart != null) {
          return aStart.compareTo(bStart);
        }
      }

      // Both unscheduled: sort by creation time
      return a.createdAt.compareTo(b.createdAt);
    });

    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<SignalTaskProvider>();
    final tagProvider = context.watch<TagProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final ratio = _getSignalRatio(taskProvider, settingsProvider);
    final sortedTasks = _getSortedTasks(taskProvider);
    final hasActiveTask = taskProvider.hasActiveTimer;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: const Text(
            'Signal / Noise',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          // Analytics/Weekly Review button
          IconButton(
            onPressed: _navigateToWeeklyReview,
            icon: const Icon(Icons.insights),
            tooltip: 'Weekly Review',
          ),
          // Calendar/Schedule button
          IconButton(
            onPressed: _navigateToScheduling,
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Adjust schedule',
          ),

          IconButton(
            onPressed: _navigateToSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: taskProvider.refresh,
          child: sortedTasks.isEmpty
              ? _buildEmptyState()
              : _buildDashboard(
                  ratio,
                  sortedTasks,
                  tagProvider,
                  taskProvider,
                  settingsProvider,
                  hasActiveTask,
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 24),
              Text(
                'No signals for today',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your most important tasks to get started',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _navigateToAddTask,
                icon: const Icon(Icons.add),
                label: const Text('Add Signal Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    double ratio,
    List<SignalTask> tasks,
    TagProvider tagProvider,
    SignalTaskProvider taskProvider,
    SettingsProvider settingsProvider,
    bool hasActiveTask,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // Signal ratio circle
        _buildRatioCircle(ratio, taskProvider, settingsProvider),
        const SizedBox(height: 8),

        // Time summary
        _buildTimeSummary(taskProvider),
        const SizedBox(height: 32),

        // Section header
        _buildSectionHeader(tasks),
        const SizedBox(height: 16),

        // Task list
        ...tasks.map(
          (task) => _DashboardTaskCard(
            key: ValueKey(task.id),
            task: task,
            tagProvider: tagProvider,
            taskProvider: taskProvider,
            onTap: () {
              // If task has active timer, show timer modal instead of edit screen
              if (task.hasActiveTimeSlot) {
                TaskTimerModal.show(context, task);
              } else {
                _navigateToEditTask(task.id);
              }
            },
            hasOtherActiveTask:
                hasActiveTask && taskProvider.activeTask?.id != task.id,
          ),
        ),

        // Add Signal Task button (when user can add more tasks)
        if (taskProvider.canAddTask) ...[
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _navigateToAddTask,
              icon: const Icon(Icons.add),
              label: const Text('Add Signal Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 40), // Bottom padding
      ],
    );
  }

  Widget _buildRatioCircle(
    double ratio,
    SignalTaskProvider taskProvider,
    SettingsProvider settingsProvider,
  ) {
    final completedCount = taskProvider.completedTasks.length;
    final totalCount = taskProvider.tasks.length;
    final hasActiveTimer = taskProvider.hasActiveTimer;

    // If timer is running, use StreamBuilder to update ratio in real-time
    if (hasActiveTimer) {
      return StreamBuilder(
        stream: Stream.periodic(const Duration(seconds: 1)),
        builder: (context, snapshot) {
          // Recalculate ratio with current time
          final liveRatio = _getSignalRatio(taskProvider, settingsProvider);
          return _buildRatioCircleContent(
            liveRatio,
            completedCount,
            totalCount,
          );
        },
      );
    }

    return _buildRatioCircleContent(ratio, completedCount, totalCount);
  }

  Widget _buildRatioCircleContent(
    double ratio,
    int completedCount,
    int totalCount,
  ) {
    final percentage = (ratio * 100).toInt();

    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getRatioColor(ratio),
              _getRatioColor(ratio).withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _getRatioColor(ratio).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Signal',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$completedCount/$totalCount done',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatioColor(double ratio) {
    if (ratio >= 0.8) return Colors.green.shade600; // Golden ratio achieved
    if (ratio >= 0.65) return Colors.orange.shade600; // Getting close
    if (ratio >= 0.5) return Colors.grey.shade600; // Needs improvement
    return Colors.red.shade600; // Below 50%
  }

  Widget _buildTimeSummary(SignalTaskProvider taskProvider) {
    final actualMinutes = taskProvider.totalActualMinutes;
    final estimatedMinutes = taskProvider.totalEstimatedMinutes;
    final activeTask = taskProvider.activeTask;

    String message;
    if (activeTask != null) {
      // Timer is running
      message = 'Tracking: ${activeTask.title}';
    } else if (actualMinutes > 0) {
      // No active timer but time has been tracked
      message =
          '${_formatMinutes(actualMinutes)} of ${_formatMinutes(estimatedMinutes)} tracked';
    } else {
      // No tracking yet
      message = 'Start a task to track time';
    }

    return Center(
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    );
  }

  Widget _buildSectionHeader(List<SignalTask> tasks) {
    final scheduledCount = tasks.where((t) => t.isScheduled).length;
    final unscheduledCount = tasks.length - scheduledCount;

    return Row(
      children: [
        Text(
          "Today's Signals",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const Spacer(),
        if (unscheduledCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$unscheduledCount unscheduled',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) return '${hours}h ${mins}m';
      return '${hours}h';
    }
    return '${minutes}m';
  }
}

/// Task card for the dashboard
class _DashboardTaskCard extends StatelessWidget {
  final SignalTask task;
  final TagProvider tagProvider;
  final SignalTaskProvider taskProvider;
  final VoidCallback onTap;
  final bool hasOtherActiveTask;

  const _DashboardTaskCard({
    super.key,
    required this.task,
    required this.tagProvider,
    required this.taskProvider,
    required this.onTap,
    required this.hasOtherActiveTask,
  });

  Color get _primaryColor {
    if (task.tagIds.isNotEmpty) {
      final tag = tagProvider.getTag(task.tagIds.first);
      if (tag != null) return tag.color;
    }
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = task.hasActiveTimeSlot;
    final isComplete = task.isComplete;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isComplete ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? _primaryColor : Colors.grey.shade200,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Color indicator
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isComplete ? Colors.grey.shade400 : _primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Task content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isComplete
                                ? Colors.grey.shade500
                                : Colors.black87,
                            decoration: isComplete
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Meta row
                        Row(
                          children: [
                            // Estimated time
                            _buildMetaChip(
                              icon: Icons.schedule,
                              text: task.formattedEstimatedTime,
                            ),

                            // Time tracked - always show if any time logged or timer active
                            if (task.actualMinutes > 0 ||
                                task.hasActiveTimeSlot) ...[
                              const SizedBox(width: 8),
                              _buildLiveTrackedTimeChip(),
                            ],

                            // Scheduled time (only show if no tracked time to save space)
                            if (task.isScheduled &&
                                task.earliestTimeSlot != null &&
                                task.actualMinutes == 0 &&
                                !task.hasActiveTimeSlot) ...[
                              const SizedBox(width: 8),
                              _buildMetaChip(
                                icon: Icons.event,
                                text: _formatTime(
                                  task.earliestTimeSlot!.plannedStartTime,
                                ),
                              ),
                            ],

                            // Subtasks
                            if (task.subTasks.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _buildMetaChip(
                                icon: Icons.check_box_outlined,
                                text:
                                    '${task.completedSubTaskCount}/${task.subTasks.length}',
                              ),
                            ],
                          ],
                        ),

                        // Tags
                        if (task.tagIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: task.tagIds.map((tagId) {
                              final tag = tagProvider.getTag(tagId);
                              if (tag == null) return const SizedBox.shrink();
                              return TagChip(
                                tag: tag,
                                fontSize: 11,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action button
                  const SizedBox(width: 8),
                  _buildActionButton(context),
                ],
              ),
            ),

            // Active indicator
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      size: 18,
                      color: _primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'In progress',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                    const Spacer(),
                    _buildElapsedTime(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    bool isHighlighted = false,
  }) {
    final color = isHighlighted ? _primaryColor : Colors.grey.shade500;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isHighlighted ? _primaryColor : Colors.grey.shade600,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Build a live-updating tracked time chip that shows accumulated time
  Widget _buildLiveTrackedTimeChip() {
    final isActive = task.hasActiveTimeSlot;
    final activeSlot = task.activeTimeSlot;

    // If not active, just show static accumulated time
    if (!isActive || activeSlot?.actualStartTime == null) {
      return _buildMetaChip(
        icon: Icons.timer,
        text: '${task.formattedActualTime} tracked',
        isHighlighted: true,
      );
    }

    // If active, stream live updates
    // Calculate time from other time slots (in seconds)
    final otherSlotsSeconds = task.timeSlots
        .where((s) => s.id != activeSlot!.id)
        .fold<int>(0, (sum, slot) => sum + slot.actualDuration.inSeconds);

    // Get accumulated seconds from previous pause/resume cycles on active slot
    final activeSlotAccumulated = activeSlot!.accumulatedSeconds;

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        // Current session elapsed time
        final currentElapsed = DateTime.now().difference(
          activeSlot.actualStartTime!,
        );

        // Total time = other slots + active slot accumulated + current session
        final totalSeconds =
            otherSlotsSeconds +
            activeSlotAccumulated +
            currentElapsed.inSeconds;
        final totalMinutes = totalSeconds ~/ 60;

        // Format the time
        String formattedTime;
        if (totalMinutes >= 60) {
          final hours = totalMinutes ~/ 60;
          final mins = totalMinutes % 60;
          formattedTime = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
        } else {
          formattedTime = '${totalMinutes}m';
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer, size: 14, color: _primaryColor),
            const SizedBox(width: 3),
            Text(
              '$formattedTime tracked',
              style: TextStyle(
                fontSize: 12,
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (task.isComplete) {
      // Completed - show undo button
      return IconButton(
        onPressed: () => taskProvider.uncompleteTask(task.id),
        icon: Icon(Icons.undo, color: Colors.grey.shade500),
        tooltip: 'Mark incomplete',
      );
    }

    if (task.hasActiveTimeSlot) {
      // Active - show stop button
      return IconButton(
        onPressed: () {
          final activeSlot = task.activeTimeSlot;
          if (activeSlot != null) {
            taskProvider.stopTimeSlot(task.id, activeSlot.id);
          }
        },
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.stop, color: Colors.red.shade700, size: 20),
        ),
        tooltip: 'Stop timer',
      );
    }

    // Not active - show start button
    return IconButton(
      onPressed: hasOtherActiveTask ? null : () => _startTask(context),
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: hasOtherActiveTask
              ? Colors.grey.shade200
              : _primaryColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.play_arrow,
          color: hasOtherActiveTask ? Colors.grey.shade400 : _primaryColor,
          size: 22,
        ),
      ),
      tooltip: hasOtherActiveTask ? 'Stop current task first' : 'Start task',
    );
  }

  void _startTask(BuildContext context) async {
    // Use smartStartTask which handles:
    // 1. Session merging (gaps < 15 min resume same slot)
    // 2. Session splitting (gaps >= 15 min create new slot)
    // 3. Finding the best slot to use (nearest scheduled, or create ad-hoc)
    final now = DateTime.now();
    final settingsProvider = context.read<SettingsProvider>();
    TimeSlot? preferredSlot;

    if (task.timeSlots.isNotEmpty) {
      // Find the nearest scheduled slot that hasn't been used
      final unusedSlots = task.timeSlots
          .where((s) => !s.hasStarted && !s.isDiscarded)
          .toList();

      if (unusedSlots.isNotEmpty) {
        preferredSlot = unusedSlots.reduce((a, b) {
          final aDiff = a.plannedStartTime.difference(now).abs();
          final bDiff = b.plannedStartTime.difference(now).abs();
          return aDiff < bDiff ? a : b;
        });

        // If the preferred slot's planned end time is already in the past, update it
        // This prevents the auto-end checker from immediately stopping the timer
        if (preferredSlot.isPastPlannedEnd) {
          final originalDuration = preferredSlot.plannedDuration;
          final newEndTime = now.add(originalDuration);
          await taskProvider.updateTimeSlot(
            task.id,
            preferredSlot.id,
            startTime: now,
            endTime: newEndTime,
            autoEnd: false, // Disable auto-end for past-due slots
          );
        }
      }
    }

    // smartStartTask handles:
    // - Checking if we should resume a recent slot (gap < 15 min)
    // - Using the preferred slot if no recent slot to resume
    // - Creating a new slot if needed
    final result = await taskProvider.smartStartTask(
      task.id,
      preferredSlot: preferredSlot,
    );

    // Check for early start (before focus time) and handle nudge
    final startTime = result['startTime'] as DateTime;
    final isEarlyStart = settingsProvider.isBeforeFocusTime(startTime);

    if (isEarlyStart) {
      // Extend focus time for this day and check if we should show nudge
      final isFirstEarlyStartToday = settingsProvider.extendFocusTimeForDate(
        DateTime(now.year, now.month, now.day),
        startTime,
      );

      if (!context.mounted) return;

      if (!settingsProvider.hasSeenEarlyStartEducation) {
        // First time ever - show educational dialog
        _showEarlyStartEducationDialog(context, settingsProvider);
      } else if (isFirstEarlyStartToday) {
        // Subsequent times, first early start today - show subtle toast
        _showEarlyStartToast(context, settingsProvider);
      }
    }
  }

  /// Show educational dialog for first-time early start
  void _showEarlyStartEducationDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Friendly Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wb_sunny_rounded,
                  color: Colors.orange.shade500,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Friendly Title
              const Text(
                'Early Start!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Informative Body
              Text(
                'You\'re starting before your scheduled focus time. We\'ve extended your focus window for today so your stats stay accurate.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Tip Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: Your schedule is a guideline. It\'s always okay to work when you feel ready!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    settingsProvider.markEarlyStartEducationSeen();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show subtle toast for subsequent early starts
  void _showEarlyStartToast(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final effectiveStart = settingsProvider.formattedEffectiveStartToday;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.schedule, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                effectiveStart != null
                    ? 'Focus window extended to $effectiveStart for today'
                    : 'Focus window extended for today',
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueGrey.shade700,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildElapsedTime() {
    final activeSlot = task.activeTimeSlot;
    if (activeSlot == null || activeSlot.actualStartTime == null) {
      return const SizedBox.shrink();
    }

    // Calculate time from other time slots (in seconds)
    final otherSlotsSeconds = task.timeSlots
        .where((s) => s.id != activeSlot.id)
        .fold<int>(0, (sum, slot) => sum + slot.actualDuration.inSeconds);

    // Get accumulated seconds from previous pause/resume cycles on active slot
    final activeSlotAccumulated = activeSlot.accumulatedSeconds;

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        // Current session elapsed time
        final currentElapsed = DateTime.now().difference(
          activeSlot.actualStartTime!,
        );

        // Total time = other slots + active slot accumulated + current session
        final totalSeconds =
            otherSlotsSeconds +
            activeSlotAccumulated +
            currentElapsed.inSeconds;
        final totalMinutes = totalSeconds ~/ 60;
        final remainingSecs = totalSeconds % 60;

        return Text(
          '${totalMinutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: _primaryColor,
          ),
        );
      },
    );
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
