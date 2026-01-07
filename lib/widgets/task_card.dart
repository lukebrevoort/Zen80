import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';

/// Card displaying a single task with timer and completion controls
///
/// Design philosophy: Simplicity first
/// - All tasks have the same subtle gray outline
/// - Completed tasks: brief green flash on checkbox, then subtle styling
/// - Active timer: pulsing dot indicator, no background change
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final isActive = task.isTimerRunning;
    final isCompleted = task.isCompleted;

    // Get the current time display
    final displayTime = isActive ? task.formattedTotalTime : task.formattedTime;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Completion checkbox with animation
                _CompletionCheckbox(
                  task: task,
                  onTap: () => provider.toggleTaskComplete(task.id),
                ),
                const SizedBox(width: 14),

                // Task title and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? Colors.grey.shade400
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _TimeDisplay(
                        displayTime: displayTime,
                        isActive: isActive,
                        isCompleted: isCompleted,
                      ),
                    ],
                  ),
                ),

                // Timer controls
                _TimerButton(task: task, isActive: isActive),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated completion checkbox with green flash effect
class _CompletionCheckbox extends StatefulWidget {
  final Task task;
  final VoidCallback onTap;

  const _CompletionCheckbox({required this.task, required this.onTap});

  @override
  State<_CompletionCheckbox> createState() => _CompletionCheckboxState();
}

class _CompletionCheckboxState extends State<_CompletionCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.task.isCompleted;

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _flashAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
      ],
    ).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_CompletionCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger flash when task becomes completed
    if (widget.task.isCompleted && !_wasCompleted) {
      _flashController.forward(from: 0);
    }

    _wasCompleted = widget.task.isCompleted;
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.task.isCompleted;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Flash ring (only visible during animation)
                  if (_flashController.isAnimating)
                    Container(
                      width: 24 + (_flashAnimation.value * 12),
                      height: 24 + (_flashAnimation.value * 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.withValues(
                            alpha: 0.6 * (1 - _flashAnimation.value),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  // Main checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      color: isCompleted
                          ? Colors.green.shade600
                          : Colors.transparent,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Time display with subtle active indicator
class _TimeDisplay extends StatelessWidget {
  final String displayTime;
  final bool isActive;
  final bool isCompleted;

  const _TimeDisplay({
    required this.displayTime,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pulsing dot for active timer
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                child: child,
              ),
            );
          },
          child: isActive
              ? Padding(
                  key: const ValueKey('dot'),
                  padding: const EdgeInsets.only(right: 6),
                  child: _PulsingDot(),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
        Text(
          displayTime,
          style: TextStyle(
            fontSize: 13,
            color: isCompleted
                ? Colors.grey.shade400
                : isActive
                ? Colors.black87
                : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Subtle pulsing dot for active timer
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _opacity = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
  }
}

/// Timer play/stop button
class _TimerButton extends StatelessWidget {
  final Task task;
  final bool isActive;

  const _TimerButton({required this.task, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TaskProvider>();

    // Don't show timer button for completed tasks
    if (task.isCompleted) {
      return const SizedBox(width: 48);
    }

    return IconButton(
      onPressed: () {
        if (isActive) {
          provider.stopTimer();
        } else {
          provider.startTimer(task);
        }
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          isActive ? Icons.stop_circle : Icons.play_circle_outline,
          key: ValueKey(isActive),
          size: 32,
        ),
      ),
      color: Colors.black87,
      tooltip: isActive ? 'Stop timer' : 'Start timer',
    );
  }
}
