import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/signal_task.dart';
import '../models/sub_task.dart';
import '../models/time_slot.dart';
import '../providers/signal_task_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/tags/tag_selector.dart';
import '../widgets/subtasks/subtask_list.dart';
import '../widgets/common/time_estimate_input.dart';

/// Screen for editing an existing Signal task
class EditSignalTaskScreen extends StatefulWidget {
  final String taskId;

  const EditSignalTaskScreen({super.key, required this.taskId});

  @override
  State<EditSignalTaskScreen> createState() => _EditSignalTaskScreenState();
}

class _EditSignalTaskScreenState extends State<EditSignalTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _uuid = const Uuid();

  // Task properties
  late int _estimatedMinutes;
  late List<String> _selectedTagIds;
  late List<SubTask> _subTasks;
  late bool _isComplete;
  late List<TimeSlot> _timeSlots;

  SignalTask? _task;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _loadTask() {
    final provider = context.read<SignalTaskProvider>();
    final task = provider.getTask(widget.taskId);

    if (task == null) {
      // Task not found, go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Task not found')));
        }
      });
      return;
    }

    setState(() {
      _task = task;
      _titleController.text = task.title;
      _estimatedMinutes = task.estimatedMinutes;
      _selectedTagIds = List<String>.from(task.tagIds);
      _subTasks = List<SubTask>.from(task.subTasks);
      _isComplete = task.isComplete;
      _timeSlots = List<TimeSlot>.from(task.timeSlots);
      _isLoading = false;
    });
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting || _task == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = context.read<SignalTaskProvider>();

      // Update the task
      final updatedTask = SignalTask(
        id: _task!.id,
        title: _titleController.text.trim(),
        estimatedMinutes: _estimatedMinutes,
        tagIds: _selectedTagIds,
        subTasks: _subTasks,
        status: _task!.status,
        scheduledDate: _task!.scheduledDate,
        timeSlots: _timeSlots,
        isComplete: _isComplete,
        createdAt: _task!.createdAt,
        googleCalendarEventId: _task!.googleCalendarEventId,
      );

      await provider.updateTask(updatedTask);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving task: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text(
          'Are you sure you want to delete this task? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = context.read<SignalTaskProvider>();
        await provider.deleteTask(widget.taskId);

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting task: ${e.toString()}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Task')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Edit Task',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_hasChanges) {
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
              tooltip: 'Delete task',
            ),
            TextButton(
              onPressed: _hasChanges && !_isSubmitting ? _save : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: _hasChanges ? Colors.black : Colors.grey,
                      ),
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Completion toggle
                  _buildCompletionToggle(),
                  const SizedBox(height: 20),

                  // Task title
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'What\'s the most important thing to focus on?',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.normal,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _markChanged(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a task title';
                      }
                      if (value.trim().length < 2) {
                        return 'Task title is too short';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Time section - combines estimate and actual
                  _buildTimeSection(),
                  const SizedBox(height: 24),

                  // Scheduled time section
                  _buildScheduledTimeSection(),
                  const SizedBox(height: 24),

                  // Tags section
                  _buildTagsSection(),
                  const SizedBox(height: 24),

                  // Sub-tasks section (collapsible)
                  _buildSubTasksSection(),
                  const SizedBox(height: 32),

                  // Save button
                  ElevatedButton(
                    onPressed: _hasChanges && !_isSubmitting ? _save : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Delete button
                  TextButton(
                    onPressed: _confirmDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Delete Task',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today, ${_formatTime(date)}';
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) return '${hours}h ${mins}m';
      return '${hours}h';
    }
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// Build live-updating duration display for an active time slot
  Widget _buildLiveSlotDuration(TimeSlot slot) {
    if (slot.actualStartTime == null) {
      return Text(
        'Starting...',
        style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
      );
    }

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        // Current session + accumulated from previous pause/resume
        final currentSession = DateTime.now().difference(slot.actualStartTime!);
        final totalSeconds = slot.accumulatedSeconds + currentSession.inSeconds;
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;

        return Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} in progress',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }

  Widget _buildCompletionToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isComplete ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isComplete ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isComplete ? Icons.check_circle : Icons.circle_outlined,
            color: _isComplete ? Colors.green.shade700 : Colors.grey.shade500,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isComplete ? 'Completed' : 'In progress',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _isComplete
                    ? Colors.green.shade800
                    : Colors.grey.shade700,
              ),
            ),
          ),
          Switch(
            value: _isComplete,
            onChanged: (value) {
              setState(() => _isComplete = value);
              _markChanged();
            },
            activeTrackColor: Colors.green.shade300,
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSection() {
    final isActive = _task?.hasActiveTimeSlot ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with actual time (live updating if active)
          Row(
            children: [
              const Text(
                'Time',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              _buildTrackedTimeDisplay(isActive),
            ],
          ),
          const SizedBox(height: 12),

          // Estimate label
          Text(
            'Estimated Duration',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),

          // Time estimate selector (simplified - 3 options)
          TimeEstimateSelector(
            initialMinutes: _estimatedMinutes,
            showLabel: false,
            onMinutesChanged: (minutes) {
              setState(() => _estimatedMinutes = minutes);
              _markChanged();
            },
          ),
        ],
      ),
    );
  }

  /// Build tracked time display - live updating if timer is active
  Widget _buildTrackedTimeDisplay(bool isActive) {
    if (_task == null) return const SizedBox.shrink();

    // If not active, show static time
    if (!isActive) {
      final actualMinutes = _task!.actualMinutes;
      if (actualMinutes == 0) return const SizedBox.shrink();

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Text(
            '${_formatMinutes(actualMinutes)} tracked',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade600,
            ),
          ),
        ],
      );
    }

    // If active, stream live updates
    final activeSlot = _task!.activeTimeSlot;
    if (activeSlot == null || activeSlot.actualStartTime == null) {
      return const SizedBox.shrink();
    }

    // Calculate time from other slots
    final otherSlotsSeconds = _task!.timeSlots
        .where((s) => s.id != activeSlot.id)
        .fold<int>(0, (sum, slot) => sum + slot.actualDuration.inSeconds);

    // Get accumulated seconds from active slot's previous sessions
    final activeSlotAccumulated = activeSlot.accumulatedSeconds;

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        // Current session elapsed
        final currentElapsed = DateTime.now().difference(
          activeSlot.actualStartTime!,
        );

        // Total = other slots + active accumulated + current session
        final totalSeconds =
            otherSlotsSeconds +
            activeSlotAccumulated +
            currentElapsed.inSeconds;
        final totalMinutes = totalSeconds ~/ 60;
        final remainingSecs = totalSeconds % 60;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green.shade500,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.timer, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(
              '${totalMinutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')} tracked',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: Colors.green.shade600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduledTimeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Scheduled Time',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addTimeSlot,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (_timeSlots.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No scheduled time yet. Add a time slot to put this task on your calendar.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ..._timeSlots.asMap().entries.map((entry) {
              final index = entry.key;
              final slot = entry.value;
              return _buildTimeSlotTile(slot, index);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSlotTile(TimeSlot slot, int index) {
    final isCompleted = slot.isCompleted;
    final isActive = slot.isActive;
    final hasTrackedTime = slot.accumulatedSeconds > 0 || isActive;

    return Container(
      margin: EdgeInsets.only(bottom: index < _timeSlots.length - 1 ? 8 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.blue.shade50
            : isCompleted
            ? Colors.green.shade50
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? Colors.blue.shade300
              : isCompleted
              ? Colors.green.shade200
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive
                ? Icons.play_circle_filled
                : isCompleted
                ? Icons.check_circle
                : Icons.schedule,
            size: 18,
            color: isActive
                ? Colors.blue.shade600
                : isCompleted
                ? Colors.green.shade600
                : Colors.grey.shade600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTimeRange(slot.plannedStartTime, slot.plannedEndTime),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isActive)
                  _buildLiveSlotDuration(slot)
                else if (hasTrackedTime)
                  Text(
                    '${_formatDuration(slot.actualDuration)} worked',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  )
                else if (isCompleted &&
                    slot.actualStartTime != null &&
                    slot.actualEndTime != null)
                  Text(
                    'Actual: ${_formatTimeRange(slot.actualStartTime!, slot.actualEndTime!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            onPressed: () => _editTimeSlot(slot),
            icon: const Icon(Icons.edit_outlined, size: 18),
            visualDensity: VisualDensity.compact,
            color: Colors.grey.shade600,
          ),
          // Delete button
          IconButton(
            onPressed: () => _removeTimeSlot(index),
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            color: Colors.red.shade400,
          ),
        ],
      ),
    );
  }

  Future<void> _addTimeSlot() async {
    final settingsProvider = context.read<SettingsProvider>();
    final schedule = settingsProvider.todaySchedule;

    // Default to current time or start of active hours
    final now = DateTime.now();
    var defaultStart = _roundToNearestQuarterHour(now);
    if (defaultStart.hour < schedule.activeStartHour) {
      defaultStart = DateTime(
        now.year,
        now.month,
        now.day,
        schedule.activeStartHour,
        0,
      );
    }
    if (defaultStart.hour >= schedule.activeEndHour) {
      defaultStart = DateTime(
        now.year,
        now.month,
        now.day,
        schedule.activeEndHour - 1,
        0,
      );
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(defaultStart),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Start time for "${_titleController.text}"',
    );

    if (pickedTime == null || !mounted) return;

    final startTime = DateTime(
      now.year,
      now.month,
      now.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final endTime = startTime.add(Duration(minutes: _estimatedMinutes));

    final newSlot = TimeSlot(
      id: _uuid.v4(),
      plannedStartTime: startTime,
      plannedEndTime: endTime,
      linkedSubTaskIds: [],
    );

    setState(() {
      _timeSlots.add(newSlot);
      _timeSlots.sort(
        (a, b) => a.plannedStartTime.compareTo(b.plannedStartTime),
      );
    });
    _markChanged();
  }

  Future<void> _editTimeSlot(TimeSlot slot) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(slot.plannedStartTime),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Edit start time',
    );

    if (pickedTime == null || !mounted) return;

    final now = DateTime.now();
    final newStart = DateTime(
      now.year,
      now.month,
      now.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final duration = slot.plannedEndTime.difference(slot.plannedStartTime);
    final newEnd = newStart.add(duration);

    setState(() {
      final index = _timeSlots.indexWhere((s) => s.id == slot.id);
      if (index != -1) {
        _timeSlots[index] = slot.copyWith(
          plannedStartTime: newStart,
          plannedEndTime: newEnd,
        );
        _timeSlots.sort(
          (a, b) => a.plannedStartTime.compareTo(b.plannedStartTime),
        );
      }
    });
    _markChanged();
  }

  void _removeTimeSlot(int index) {
    setState(() {
      _timeSlots.removeAt(index);
    });
    _markChanged();
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

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TagSelector(
          selectedTagIds: _selectedTagIds,
          onTagsChanged: (tagIds) {
            setState(() => _selectedTagIds = tagIds);
            _markChanged();
          },
          hintText: 'Add tags to categorize...',
        ),
      ],
    );
  }

  Widget _buildSubTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Sub-tasks',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (_subTasks.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '(${_subTasks.where((st) => st.isChecked).length}/${_subTasks.length})',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SubTaskList(
            subTasks: _subTasks,
            onSubTasksChanged: (subTasks) {
              setState(() => _subTasks = subTasks);
              _markChanged();
            },
            addButtonText: 'Add step',
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
