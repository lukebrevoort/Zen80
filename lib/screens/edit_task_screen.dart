import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';

/// Screen for editing task details and adding time manually
class EditTaskScreen extends StatefulWidget {
  final Task task;

  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  late TextEditingController _titleController;
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _saveTitle() async {
    if (_titleController.text.trim().isEmpty) return;

    final provider = context.read<TaskProvider>();
    final updatedTask = widget.task.copyWith(
      title: _titleController.text.trim(),
    );
    await provider.updateTask(updatedTask);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _addTime() async {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;

    if (hours == 0 && minutes == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter time to add')));
      return;
    }

    final provider = context.read<TaskProvider>();
    await provider.addTimeToTask(
      widget.task.id,
      Duration(hours: hours, minutes: minutes),
    );

    _hoursController.clear();
    _minutesController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${hours}h ${minutes}m'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
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

    if (confirmed == true) {
      if (!mounted) return;
      final provider = context.read<TaskProvider>();
      await provider.deleteTask(widget.task.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Task',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _deleteTask,
            icon: const Icon(Icons.delete_outline),
            color: Colors.red.shade700,
            tooltip: 'Delete task',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Task type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.task.type == TaskType.signal
                      ? Colors.black
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.task.type == TaskType.signal
                          ? Icons.flag
                          : Icons.blur_on,
                      size: 16,
                      color: widget.task.type == TaskType.signal
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.task.type == TaskType.signal ? 'Signal' : 'Noise',
                      style: TextStyle(
                        color: widget.task.type == TaskType.signal
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Task title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),

              // Time display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Consumer<TaskProvider>(
                      builder: (context, provider, child) {
                        final task = provider.tasks
                            .where((t) => t.id == widget.task.id)
                            .firstOrNull;
                        final isRunning = task?.isTimerRunning ?? false;
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isRunning) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                                Text(
                                  isRunning ? 'Timer Running' : 'Time Logged',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isRunning
                                        ? Colors.red.shade700
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task?.formattedTotalTime ??
                                  widget.task.formattedTotalTime,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: isRunning
                                    ? Colors.red.shade700
                                    : Colors.black,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Add time manually
              const Text(
                'Add Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hoursController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Hours',
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addTime,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Save button
              ElevatedButton(
                onPressed: _saveTitle,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
