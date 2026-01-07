import 'package:flutter/material.dart';

import '../models/task.dart';
import 'task_card.dart';

/// Section displaying a list of tasks grouped by type (Signal or Noise)
///
/// Uses AnimatedList for smooth task add/remove transitions
class TaskSection extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final TaskType type;
  final int? maxTasks;
  final VoidCallback? onAddTask;
  final Function(Task)? onTaskTap;

  const TaskSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.type,
    this.maxTasks,
    this.onAddTask,
    this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final canAddMore = maxTasks == null || tasks.length < maxTasks!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (maxTasks != null) ...[
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}/$maxTasks',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (canAddMore && onAddTask != null)
                _AddButton(onPressed: onAddTask!),
            ],
          ),
        ),

        // Task list or empty state
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
            );
          },
          child: tasks.isEmpty
              ? _EmptyTaskState(
                  key: const ValueKey('empty'),
                  type: type,
                  onAdd: canAddMore ? onAddTask : null,
                )
              : Column(
                  key: ValueKey('tasks-${tasks.length}'),
                  children: tasks
                      .map(
                        (task) => TaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          onTap: onTaskTap != null
                              ? () => onTaskTap!(task)
                              : null,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

/// Subtle add button
class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.add, color: Colors.grey.shade600, size: 22),
        ),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  final TaskType type;
  final VoidCallback? onAdd;

  const _EmptyTaskState({super.key, required this.type, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isSignal = type == TaskType.signal;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              isSignal ? Icons.flag_outlined : Icons.blur_on,
              size: 28,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isSignal
                  ? 'What must get done today?'
                  : 'Track everything else here',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAdd,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 18),
                    const SizedBox(width: 6),
                    Text('Add ${isSignal ? "Signal" : "Noise"} Task'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
