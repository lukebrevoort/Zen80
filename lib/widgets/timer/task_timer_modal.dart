import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/signal_task.dart';
import '../../models/time_slot.dart';
import '../../models/tag.dart';
import '../../providers/signal_task_provider.dart';
import '../../providers/tag_provider.dart';
import '../tags/tag_chip.dart';

/// Modal that appears when a task timer is active
/// Shows timer, subtasks, and control options
class TaskTimerModal extends StatefulWidget {
  final SignalTask task;
  final TimeSlot activeSlot;

  const TaskTimerModal({
    super.key,
    required this.task,
    required this.activeSlot,
  });

  /// Show the modal as a bottom sheet
  static Future<void> show(BuildContext context, SignalTask task) async {
    final activeSlot = task.activeTimeSlot;
    if (activeSlot == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => TaskTimerModal(task: task, activeSlot: activeSlot),
    );
  }

  @override
  State<TaskTimerModal> createState() => _TaskTimerModalState();
}

class _TaskTimerModalState extends State<TaskTimerModal> {
  Timer? _timer;
  late final String _taskId;
  late final String _slotId;
  bool _isClosingForMissingData = false;

  @override
  void initState() {
    super.initState();
    _taskId = widget.task.id;
    _slotId = widget.activeSlot.id;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _totalElapsedFor(SignalTask task, TimeSlot activeSlot) {
    final previousElapsed = Duration(
      seconds: task.timeSlots
          .where((slot) => slot.id != activeSlot.id)
          .fold<int>(0, (sum, slot) => sum + slot.actualDuration.inSeconds),
    );
    return previousElapsed + activeSlot.actualDuration;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  void _stopTimer() {
    final provider = context.read<SignalTaskProvider>();
    provider.stopTimeSlot(_taskId, _slotId);
    Navigator.of(context).pop();
  }

  Future<void> _continueTimer() async {
    final provider = context.read<SignalTaskProvider>();
    await provider.continueTimeSlot(_taskId, _slotId);
  }

  void _completeTask() {
    final provider = context.read<SignalTaskProvider>();
    provider.stopTimeSlot(_taskId, _slotId);
    provider.completeTask(_taskId);
    Navigator.of(context).pop();
  }

  void _dismissForMissingData(String message) {
    if (_isClosingForMissingData) return;
    _isClosingForMissingData = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text(message)));

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<SignalTaskProvider>();
    final task = taskProvider.getTask(_taskId);
    if (task == null) {
      _dismissForMissingData('This timer task was removed.');
      return const SizedBox.shrink();
    }

    final activeSlot = task.timeSlots.cast<TimeSlot?>().firstWhere(
      (slot) => slot?.id == _slotId,
      orElse: () => null,
    );
    if (activeSlot == null || !activeSlot.isActive) {
      _dismissForMissingData(
        'This timer session ended or is no longer available.',
      );
      return const SizedBox.shrink();
    }

    final totalElapsed = _totalElapsedFor(task, activeSlot);
    final isPastPlannedEnd = activeSlot.isPastPlannedEnd;

    final tagProvider = context.watch<TagProvider>();
    final tags = task.tagIds
        .map((id) => tagProvider.getTag(id))
        .whereType<Tag>()
        .toList();

    // Calculate progress towards estimated time
    final estimatedDuration = Duration(minutes: task.estimatedMinutes);
    final progress = estimatedDuration.inSeconds > 0
        ? (totalElapsed.inSeconds / estimatedDuration.inSeconds).clamp(0.0, 1.5)
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Task title
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Tags
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: tags
                      .map((tag) => TagChip(tag: tag, fontSize: 12))
                      .toList(),
                ),
              const SizedBox(height: 32),

              // Timer display
              Text(
                _formatDuration(totalElapsed),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isPastPlannedEnd
                      ? Colors.orange.shade700
                      : Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Progress bar
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        progress > 1.0 ? Colors.orange : Colors.black,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0:00',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        task.formattedEstimatedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Scheduled time info
              Text(
                'Scheduled: ${_formatTime(activeSlot.plannedStartTime)} - ${_formatTime(activeSlot.plannedEndTime)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Past end time warning
              if (isPastPlannedEnd && !activeSlot.wasManualContinue) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Past scheduled end time',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Would you like to continue working?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Linked subtasks (if any)
              if (activeSlot.linkedSubTaskIds.isNotEmpty) ...[
                _buildLinkedSubTasks(task, activeSlot),
                const SizedBox(height: 24),
              ],

              // Action buttons
              Row(
                children: [
                  // Continue button (only if past end time)
                  if (isPastPlannedEnd && !activeSlot.wasManualContinue) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _continueTimer,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Continue'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.orange.shade400),
                          foregroundColor: Colors.orange.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Stop button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _stopTimer,
                      icon: const Icon(Icons.stop),
                      label: const Text('End Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Complete task button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _completeTask,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedSubTasks(SignalTask task, TimeSlot activeSlot) {
    final linkedSubTasks = task.subTasks
        .where((st) => activeSlot.linkedSubTaskIds.contains(st.id))
        .toList();

    if (linkedSubTasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sub-tasks for this block',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: linkedSubTasks.map((subTask) {
              return ListTile(
                dense: true,
                leading: Checkbox(
                  value: subTask.isChecked,
                  onChanged: (value) {
                    final provider = context.read<SignalTaskProvider>();
                    provider.toggleSubTask(_taskId, subTask.id);
                  },
                  activeColor: Colors.black,
                ),
                title: Text(
                  subTask.title,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: subTask.isChecked
                        ? TextDecoration.lineThrough
                        : null,
                    color: subTask.isChecked
                        ? Colors.grey.shade500
                        : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
