import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sub_task.dart';
import '../providers/signal_task_provider.dart';
import '../widgets/tags/tag_selector.dart';
import '../widgets/subtasks/subtask_list.dart';
import '../widgets/common/time_estimate_input.dart';

/// Screen for creating a new Signal task with tags, subtasks, and time estimate
class AddSignalTaskScreen extends StatefulWidget {
  const AddSignalTaskScreen({super.key});

  @override
  State<AddSignalTaskScreen> createState() => _AddSignalTaskScreenState();
}

class _AddSignalTaskScreenState extends State<AddSignalTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  // Task properties
  int _estimatedMinutes = 60; // Default 1 hour
  List<String> _selectedTagIds = [];
  List<SubTask> _subTasks = [];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = context.read<SignalTaskProvider>();

      // Validate task limit
      if (!provider.canAddTask) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Maximum 5 Signal tasks per day'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        return;
      }

      // Validate minimum time estimate
      if (_estimatedMinutes < 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please set an estimated time (at least 5 minutes)',
              ),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        return;
      }

      await provider.createTask(
        title: _titleController.text.trim(),
        estimatedMinutes: _estimatedMinutes,
        tagIds: _selectedTagIds,
        subTasks: _subTasks,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SignalTaskProvider>();
    final canAdd = provider.canAddTask;
    final taskCount = provider.taskCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Signal Task',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Task count indicator
                if (!canAdd)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Maximum 5 Signal tasks reached for today',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Task ${taskCount + 1} of 5',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Task title
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
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
                const SizedBox(height: 28),

                // Time estimate section
                TimeEstimateSelector(
                  initialMinutes: _estimatedMinutes,
                  onMinutesChanged: (minutes) {
                    setState(() {
                      _estimatedMinutes = minutes;
                    });
                  },
                ),
                const SizedBox(height: 28),

                // Tags section
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
                    setState(() {
                      _selectedTagIds = tagIds;
                    });
                  },
                  hintText: 'Add tags to categorize...',
                ),
                const SizedBox(height: 28),

                // Sub-tasks section
                const Text(
                  'Sub-tasks (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
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
                      setState(() {
                        _subTasks = subTasks;
                      });
                    },
                    addButtonText: 'Add step',
                  ),
                ),
                const SizedBox(height: 40),

                // Create button (for bottom of scrollable area)
                ElevatedButton(
                  onPressed: canAdd && !_isSubmitting ? _submit : null,
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
                          'Create Signal Task',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
