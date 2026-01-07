import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/signal_task.dart';
import '../models/sub_task.dart';
import '../providers/signal_task_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/tags/tag_selector.dart';
import '../widgets/common/time_estimate_input.dart';
import 'initial_scheduling_screen.dart';

/// Multi-step daily planning flow
/// Step 1: Add task names
/// Step 2: Set time estimates
/// Step 3: Add tags
/// Then navigates to scheduling
class DailyPlanningFlow extends StatefulWidget {
  final List<SignalTask> rolloverSuggestions;

  const DailyPlanningFlow({super.key, this.rolloverSuggestions = const []});

  @override
  State<DailyPlanningFlow> createState() => _DailyPlanningFlowState();
}

class _DailyPlanningFlowState extends State<DailyPlanningFlow> {
  final List<TaskDraft> _taskDrafts = [];
  int _currentStep = 0;

  static const int _maxTasks = 5;
  static const int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    // Start with one empty task
    _taskDrafts.add(TaskDraft());
  }

  @override
  void dispose() {
    for (final draft in _taskDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  bool get _canAddMoreTasks => _taskDrafts.length < _maxTasks;

  int get _totalEstimatedMinutes {
    return _taskDrafts.fold(0, (sum, draft) => sum + draft.estimatedMinutes);
  }

  void _addEmptyTask() {
    if (!_canAddMoreTasks) return;
    setState(() {
      _taskDrafts.add(TaskDraft());
    });
  }

  void _addRolloverTask(SignalTask task) {
    if (!_canAddMoreTasks) return;
    setState(() {
      _taskDrafts.add(TaskDraft.fromTask(task));
    });
  }

  void _removeTask(int index) {
    if (_taskDrafts.length <= 1) return; // Keep at least one
    setState(() {
      _taskDrafts[index].dispose();
      _taskDrafts.removeAt(index);
    });
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0: // Task names
        return _taskDrafts.isNotEmpty &&
            _taskDrafts.every((d) => d.title.trim().isNotEmpty);
      case 1: // Time estimates
        return _taskDrafts.every((d) => d.estimatedMinutes > 0);
      case 2: // Tags (optional, can always proceed)
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _continueToScheduling();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _continueToScheduling() async {
    final provider = context.read<SignalTaskProvider>();

    for (final draft in _taskDrafts) {
      await provider.createTask(
        title: draft.title,
        estimatedMinutes: draft.estimatedMinutes,
        tagIds: draft.tagIds,
        subTasks: draft.subTasks,
      );
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const InitialSchedulingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _skipToHome() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
        title: _buildStepIndicator(),
        actions: [
          TextButton(
            onPressed: _skipToHome,
            child: Text('Skip', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _buildCurrentStep(),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_totalSteps, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? Colors.black
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _TaskNamesStep(
          key: const ValueKey('step_names'),
          taskDrafts: _taskDrafts,
          rolloverSuggestions: widget.rolloverSuggestions,
          canAddMoreTasks: _canAddMoreTasks,
          onAddTask: _addEmptyTask,
          onAddRollover: _addRolloverTask,
          onRemoveTask: _removeTask,
          onChanged: () => setState(() {}),
        );
      case 1:
        return _TimeEstimatesStep(
          key: const ValueKey('step_time'),
          taskDrafts: _taskDrafts,
          totalMinutes: _totalEstimatedMinutes,
          onChanged: () => setState(() {}),
        );
      case 2:
        return _TagsStep(
          key: const ValueKey('step_tags'),
          taskDrafts: _taskDrafts,
          onChanged: () => setState(() {}),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar() {
    final canProceed = _canProceedFromStep(_currentStep);
    final isLastStep = _currentStep == _totalSteps - 1;

    String buttonText;
    if (_currentStep == 0) {
      buttonText = _taskDrafts.isEmpty || !canProceed
          ? 'Add task names to continue'
          : 'Next: Set Time Estimates';
    } else if (_currentStep == 1) {
      buttonText = 'Next: Add Tags';
    } else {
      buttonText = 'Continue to Schedule';
    }

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
          onPressed: canProceed ? _nextStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (canProceed && !isLastStep) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STEP 1: Task Names
// ============================================================================

class _TaskNamesStep extends StatelessWidget {
  final List<TaskDraft> taskDrafts;
  final List<SignalTask> rolloverSuggestions;
  final bool canAddMoreTasks;
  final VoidCallback onAddTask;
  final Function(SignalTask) onAddRollover;
  final Function(int) onRemoveTask;
  final VoidCallback onChanged;

  const _TaskNamesStep({
    super.key,
    required this.taskDrafts,
    required this.rolloverSuggestions,
    required this.canAddMoreTasks,
    required this.onAddTask,
    required this.onAddRollover,
    required this.onRemoveTask,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out already added rollovers
    final addedTaskIds = taskDrafts
        .where((d) => d.originalTaskId != null)
        .map((d) => d.originalTaskId)
        .toSet();
    final availableRollovers = rolloverSuggestions
        .where((t) => !addedTaskIds.contains(t.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Text(
          "What's important today?",
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Name your 3-5 most important tasks for today.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        ),
        const SizedBox(height: 24),

        // Rollover suggestions
        if (availableRollovers.isNotEmpty) ...[
          _buildRolloverSection(context, availableRollovers),
          const SizedBox(height: 24),
        ],

        // Task name inputs
        ...taskDrafts.asMap().entries.map((entry) {
          return _TaskNameCard(
            key: ValueKey(entry.value.id),
            draft: entry.value,
            index: entry.key + 1,
            canRemove: taskDrafts.length > 1,
            onRemove: () => onRemoveTask(entry.key),
            onChanged: onChanged,
          );
        }),

        // Add task button
        if (canAddMoreTasks) ...[const SizedBox(height: 12), _buildAddButton()],

        // Task count info
        const SizedBox(height: 16),
        _buildTaskCountInfo(),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildRolloverSection(
    BuildContext context,
    List<SignalTask> rollovers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Continue from yesterday',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...rollovers.map(
          (task) => _RolloverChip(
            task: task,
            onAdd: canAddMoreTasks ? () => onAddRollover(task) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: onAddTask,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Add Another Task',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCountInfo() {
    final count = taskDrafts.length;
    final color = count < 3
        ? Colors.blue
        : (count == 5 ? Colors.amber : Colors.green);
    final message = count < 3
        ? 'Add ${3 - count} more task${3 - count > 1 ? 's' : ''} (3-5 recommended)'
        : count == 5
        ? 'Maximum 5 tasks reached. Focus is power!'
        : '$count tasks - looking good!';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            count < 3
                ? Icons.lightbulb_outline
                : (count == 5
                      ? Icons.warning_amber
                      : Icons.check_circle_outline),
            size: 18,
            color: color.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskNameCard extends StatelessWidget {
  final TaskDraft draft;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _TaskNameCard({
    super.key,
    required this.draft,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Number badge
          Container(
            width: 48,
            padding: const EdgeInsets.all(16),
            child: Container(
              width: 28,
              height: 28,
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          // Text field
          Expanded(
            child: TextField(
              controller: draft.titleController,
              decoration: const InputDecoration(
                hintText: 'What do you want to accomplish?',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: (_) => onChanged(),
            ),
          ),
          // Remove button
          if (canRemove)
            IconButton(
              icon: Icon(Icons.close, size: 20, color: Colors.grey.shade400),
              onPressed: onRemove,
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _RolloverChip extends StatelessWidget {
  final SignalTask task;
  final VoidCallback? onAdd;

  const _RolloverChip({required this.task, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: TextButton.styleFrom(
              foregroundColor: onAdd != null ? Colors.black : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP 2: Time Estimates
// ============================================================================

class _TimeEstimatesStep extends StatelessWidget {
  final List<TaskDraft> taskDrafts;
  final int totalMinutes;
  final VoidCallback onChanged;

  const _TimeEstimatesStep({
    super.key,
    required this.taskDrafts,
    required this.totalMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final activeMinutes = settingsProvider.todaySchedule.activeMinutes;
    final ratio = activeMinutes > 0
        ? (totalMinutes / activeMinutes).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (ratio * 100).toInt();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Text(
          'How long will each take?',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Estimate the time needed for each task.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        ),
        const SizedBox(height: 20),

        // Ratio preview
        _buildRatioPreview(percentage, ratio >= 0.8),
        const SizedBox(height: 24),

        // Time cards
        ...taskDrafts.asMap().entries.map((entry) {
          return _TimeEstimateCard(
            key: ValueKey('time_${entry.value.id}'),
            draft: entry.value,
            index: entry.key + 1,
            onChanged: onChanged,
          );
        }),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildRatioPreview(int percentage, bool isGood) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGood ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGood ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.trending_up : Icons.trending_flat,
            color: isGood ? Colors.green.shade700 : Colors.orange.shade700,
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
                  '$percentage% Signal (${_formatMinutes(totalMinutes)})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isGood
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (!isGood)
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

class _TimeEstimateCard extends StatelessWidget {
  final TaskDraft draft;
  final int index;
  final VoidCallback onChanged;

  const _TimeEstimateCard({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task title
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  draft.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Time selector
          TimeEstimateSelector(
            initialMinutes: draft.estimatedMinutes,
            onMinutesChanged: (minutes) {
              draft.estimatedMinutes = minutes;
              onChanged();
            },
            showLabel: false,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP 3: Tags
// ============================================================================

class _TagsStep extends StatelessWidget {
  final List<TaskDraft> taskDrafts;
  final VoidCallback onChanged;

  const _TagsStep({
    super.key,
    required this.taskDrafts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Text(
          'Categorize your tasks',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Add tags to help organize and track your work. (Optional)',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        ),
        const SizedBox(height: 24),

        // Tag cards
        ...taskDrafts.asMap().entries.map((entry) {
          return _TagCard(
            key: ValueKey('tags_${entry.value.id}'),
            draft: entry.value,
            index: entry.key + 1,
            onChanged: onChanged,
          );
        }),

        const SizedBox(height: 100),
      ],
    );
  }
}

class _TagCard extends StatelessWidget {
  final TaskDraft draft;
  final int index;
  final VoidCallback onChanged;

  const _TagCard({
    super.key,
    required this.draft,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task title
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  draft.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tag selector
          TagSelector(
            selectedTagIds: draft.tagIds,
            onTagsChanged: (tagIds) {
              draft.tagIds = tagIds;
              onChanged();
            },
            hintText: 'Add tags...',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared TaskDraft class
// ============================================================================

class TaskDraft {
  final String id;
  final TextEditingController titleController;
  int estimatedMinutes;
  List<String> tagIds;
  List<SubTask> subTasks;
  String? originalTaskId;

  TaskDraft({
    String? id,
    String? title,
    this.estimatedMinutes = 60,
    List<String>? tagIds,
    List<SubTask>? subTasks,
    this.originalTaskId,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       titleController = TextEditingController(text: title ?? ''),
       tagIds = tagIds ?? [],
       subTasks = subTasks ?? [];

  factory TaskDraft.fromTask(SignalTask task) {
    return TaskDraft(
      title: task.title,
      estimatedMinutes: task.remainingMinutes > 0
          ? task.remainingMinutes
          : task.estimatedMinutes,
      tagIds: List.from(task.tagIds),
      subTasks: task.subTasks
          .where((st) => !st.isChecked)
          .map((st) => st.copyWith())
          .toList(),
      originalTaskId: task.id,
    );
  }

  String get title => titleController.text;

  void dispose() {
    titleController.dispose();
  }
}
