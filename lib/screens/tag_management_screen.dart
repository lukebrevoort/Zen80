import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tag.dart';
import '../providers/tag_provider.dart';

/// Screen for managing tags - create, edit, delete custom tags
class TagManagementScreen extends StatefulWidget {
  const TagManagementScreen({super.key});

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Tags',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Consumer<TagProvider>(
        builder: (context, tagProvider, _) {
          final defaultTags = tagProvider.defaultTags;
          final customTags = tagProvider.customTags;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Default tags section
              _SectionHeader(
                title: 'Default Tags',
                subtitle: 'These tags cannot be deleted',
              ),
              const SizedBox(height: 12),
              ...defaultTags.map(
                (tag) => _TagTile(
                  tag: tag,
                  onEdit: () => _editTag(context, tag, tagProvider),
                  canDelete: false,
                ),
              ),

              const SizedBox(height: 28),

              // Custom tags section
              _SectionHeader(
                title: 'Custom Tags',
                subtitle: customTags.isEmpty
                    ? 'Create your own tags'
                    : '${customTags.length} custom tag${customTags.length == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 12),

              if (customTags.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No custom tags yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create tags to organize your tasks',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...customTags.map(
                  (tag) => _TagTile(
                    tag: tag,
                    onEdit: () => _editTag(context, tag, tagProvider),
                    onDelete: () => _deleteTag(context, tag, tagProvider),
                    canDelete: true,
                  ),
                ),

              const SizedBox(height: 24),

              // Add new tag button
              OutlinedButton.icon(
                onPressed: () => _createTag(context, tagProvider),
                icon: const Icon(Icons.add),
                label: const Text('Create New Tag'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade400),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createTag(BuildContext context, TagProvider tagProvider) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _TagEditDialog(
        title: 'Create Tag',
        suggestedColor: tagProvider.getNextAvailableColor(),
        existingNames: tagProvider.tags
            .map((t) => t.name.toLowerCase())
            .toSet(),
      ),
    );

    if (result != null && context.mounted) {
      await tagProvider.createTag(
        name: result['name']!,
        colorHex: result['color']!,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "${result['name']}" created'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editTag(
    BuildContext context,
    Tag tag,
    TagProvider tagProvider,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _TagEditDialog(
        title: 'Edit Tag',
        initialName: tag.name,
        initialColor: tag.colorHex,
        existingNames: tagProvider.tags
            .where((t) => t.id != tag.id)
            .map((t) => t.name.toLowerCase())
            .toSet(),
        isDefault: tag.isDefault,
      ),
    );

    if (result != null && context.mounted) {
      await tagProvider.updateTag(
        tag.copyWith(name: result['name'], colorHex: result['color']),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tag updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteTag(
    BuildContext context,
    Tag tag,
    TagProvider tagProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text(
          'Are you sure you want to delete "${tag.name}"? This will remove the tag from all tasks.',
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

    if (confirmed == true && context.mounted) {
      final success = await tagProvider.deleteTag(tag.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Tag "${tag.name}" deleted' : 'Cannot delete this tag',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _TagTile extends StatelessWidget {
  final Tag tag;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final bool canDelete;

  const _TagTile({
    required this.tag,
    required this.onEdit,
    this.onDelete,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tag.color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Text(
          tag.name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        subtitle: tag.isDefault
            ? Text(
                'Default',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit tag',
            ),
            if (canDelete && onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red.shade400,
                ),
                onPressed: onDelete,
                tooltip: 'Delete tag',
              ),
          ],
        ),
      ),
    );
  }
}

class _TagEditDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialColor;
  final String? suggestedColor;
  final Set<String> existingNames;
  final bool isDefault;

  const _TagEditDialog({
    required this.title,
    this.initialName,
    this.initialColor,
    this.suggestedColor,
    required this.existingNames,
    this.isDefault = false,
  });

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late TextEditingController _nameController;
  late String _selectedColor;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedColor =
        widget.initialColor ?? widget.suggestedColor ?? Tag.colorOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _validateName(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _errorText = 'Name is required';
      } else if (widget.existingNames.contains(value.trim().toLowerCase())) {
        _errorText = 'A tag with this name already exists';
      } else {
        _errorText = null;
      }
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _errorText != null) return;

    Navigator.of(context).pop({'name': name, 'color': _selectedColor});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name input
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tag Name',
                hintText: 'e.g., Urgent, Health, Hobby',
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: _validateName,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),

            // Color picker
            const Text(
              'Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: Tag.colorOptions.map((colorHex) {
                final isSelected =
                    colorHex.toUpperCase() == _selectedColor.toUpperCase();
                final color = _hexToColor(colorHex);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorHex;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),

            // Preview
            const SizedBox(height: 20),
            const Text(
              'Preview',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _hexToColor(_selectedColor).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _hexToColor(_selectedColor).withOpacity(0.3),
                ),
              ),
              child: Text(
                _nameController.text.isEmpty
                    ? 'Tag Name'
                    : _nameController.text,
                style: TextStyle(
                  color: _darkenColor(_hexToColor(_selectedColor)),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty || _errorText != null
              ? null
              : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.initialName != null ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  Color _darkenColor(Color color) {
    // Darken the color for text on light background
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
  }
}
