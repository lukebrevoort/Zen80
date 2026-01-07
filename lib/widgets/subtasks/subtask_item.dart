import 'package:flutter/material.dart';
import '../../models/sub_task.dart';

/// A single sub-task item with checkbox
class SubTaskItem extends StatefulWidget {
  final SubTask subTask;
  final Function(bool) onCheckChanged;
  final Function(String) onTitleChanged;
  final VoidCallback onDelete;
  final bool isEditing;

  const SubTaskItem({
    super.key,
    required this.subTask,
    required this.onCheckChanged,
    required this.onTitleChanged,
    required this.onDelete,
    this.isEditing = false,
  });

  @override
  State<SubTaskItem> createState() => _SubTaskItemState();
}

class _SubTaskItemState extends State<SubTaskItem> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.subTask.title);
    _focusNode = FocusNode();
    _isEditing = widget.isEditing;

    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _finishEditing() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onTitleChanged(_controller.text.trim());
    }
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox
          GestureDetector(
            onTap: () => widget.onCheckChanged(!widget.subTask.isChecked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: widget.subTask.isChecked
                    ? Colors.black
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: widget.subTask.isChecked
                      ? Colors.black
                      : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: widget.subTask.isChecked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // Title (editable or static)
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _finishEditing(),
                    onTapOutside: (_) => _finishEditing(),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditing = true;
                        _focusNode.requestFocus();
                      });
                    },
                    child: Text(
                      widget.subTask.title,
                      style: TextStyle(
                        fontSize: 15,
                        color: widget.subTask.isChecked
                            ? Colors.grey.shade400
                            : Colors.black,
                        decoration: widget.subTask.isChecked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
            onPressed: widget.onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
