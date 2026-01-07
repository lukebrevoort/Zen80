import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/sub_task.dart';
import 'subtask_item.dart';

/// A list of sub-tasks with add functionality
class SubTaskList extends StatefulWidget {
  final List<SubTask> subTasks;
  final Function(List<SubTask>) onSubTasksChanged;
  final String? addButtonText;

  const SubTaskList({
    super.key,
    required this.subTasks,
    required this.onSubTasksChanged,
    this.addButtonText,
  });

  @override
  State<SubTaskList> createState() => _SubTaskListState();
}

class _SubTaskListState extends State<SubTaskList> {
  final Uuid _uuid = const Uuid();
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();
  bool _isAddingNew = false;

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  void _startAddingNew() {
    setState(() {
      _isAddingNew = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addFocusNode.requestFocus();
    });
  }

  void _finishAddingNew() {
    if (_addController.text.trim().isNotEmpty) {
      final newSubTask = SubTask(
        id: _uuid.v4(),
        title: _addController.text.trim(),
        isChecked: false,
      );
      final updatedList = [...widget.subTasks, newSubTask];
      widget.onSubTasksChanged(updatedList);
    }

    setState(() {
      _isAddingNew = false;
      _addController.clear();
    });
  }

  void _cancelAddingNew() {
    setState(() {
      _isAddingNew = false;
      _addController.clear();
    });
  }

  void _updateSubTask(int index, SubTask updatedSubTask) {
    final updatedList = List<SubTask>.from(widget.subTasks);
    updatedList[index] = updatedSubTask;
    widget.onSubTasksChanged(updatedList);
  }

  void _deleteSubTask(int index) {
    final updatedList = List<SubTask>.from(widget.subTasks);
    updatedList.removeAt(index);
    widget.onSubTasksChanged(updatedList);
  }

  void _toggleCheck(int index, bool checked) {
    final subTask = widget.subTasks[index];
    _updateSubTask(index, subTask.copyWith(isChecked: checked));
  }

  void _updateTitle(int index, String newTitle) {
    final subTask = widget.subTasks[index];
    _updateSubTask(index, subTask.copyWith(title: newTitle));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing sub-tasks
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: widget.subTasks.length,
          onReorder: (oldIndex, newIndex) {
            final updatedList = List<SubTask>.from(widget.subTasks);
            if (newIndex > oldIndex) newIndex--;
            final item = updatedList.removeAt(oldIndex);
            updatedList.insert(newIndex, item);
            widget.onSubTasksChanged(updatedList);
          },
          itemBuilder: (context, index) {
            final subTask = widget.subTasks[index];
            return ReorderableDragStartListener(
              key: ValueKey(subTask.id),
              index: index,
              child: SubTaskItem(
                subTask: subTask,
                onCheckChanged: (checked) => _toggleCheck(index, checked),
                onTitleChanged: (title) => _updateTitle(index, title),
                onDelete: () => _deleteSubTask(index),
              ),
            );
          },
        ),

        // Add new sub-task input
        if (_isAddingNew)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey.shade400, width: 1.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _addController,
                    focusNode: _addFocusNode,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Enter sub-task...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _finishAddingNew(),
                    onTapOutside: (_) {
                      if (_addController.text.isEmpty) {
                        _cancelAddingNew();
                      } else {
                        _finishAddingNew();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: _cancelAddingNew,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),

        // Add button
        if (!_isAddingNew)
          TextButton.icon(
            onPressed: _startAddingNew,
            icon: const Icon(Icons.add, size: 18),
            label: Text(widget.addButtonText ?? 'Add sub-task'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
      ],
    );
  }
}

/// A compact view of sub-task progress
class SubTaskProgress extends StatelessWidget {
  final List<SubTask> subTasks;
  final bool showCount;

  const SubTaskProgress({
    super.key,
    required this.subTasks,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    if (subTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final completed = subTasks.where((st) => st.isChecked).length;
    final total = subTasks.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: progress == 1.0 ? Colors.green : Colors.black,
            ),
          ),
        ),
        if (showCount) ...[
          const SizedBox(width: 6),
          Text(
            '$completed/$total',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}
