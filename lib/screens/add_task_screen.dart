import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';

/// Screen for adding a new task
class AddTaskScreen extends StatefulWidget {
  final TaskType? initialType;

  const AddTaskScreen({super.key, this.initialType});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  late TaskType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? TaskType.signal;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TaskProvider>();

    try {
      await provider.addTask(
        title: _titleController.text.trim(),
        type: _selectedType,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final canAddSignal = provider.canAddSignalTask;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Task',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Task title
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    hintText: 'What needs to be done?',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Task type selector
                const Text(
                  'Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TypeOption(
                        type: TaskType.signal,
                        title: 'Signal',
                        subtitle: 'Critical task',
                        icon: Icons.flag,
                        isSelected: _selectedType == TaskType.signal,
                        isEnabled:
                            canAddSignal || _selectedType == TaskType.signal,
                        onTap: canAddSignal
                            ? () => setState(
                                () => _selectedType = TaskType.signal,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypeOption(
                        type: TaskType.noise,
                        title: 'Noise',
                        subtitle: 'Other task',
                        icon: Icons.blur_on,
                        isSelected: _selectedType == TaskType.noise,
                        isEnabled: true,
                        onTap: () =>
                            setState(() => _selectedType = TaskType.noise),
                      ),
                    ),
                  ],
                ),

                if (!canAddSignal && _selectedType == TaskType.signal)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Maximum 5 signal tasks per day',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),

                const Spacer(),

                // Submit button
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add Task', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final TaskType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _TypeOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.grey.shade100 : Colors.transparent,
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.black : Colors.grey.shade600,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.grey.shade600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
