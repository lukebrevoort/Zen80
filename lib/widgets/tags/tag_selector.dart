import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tag.dart';
import '../../providers/tag_provider.dart';
import 'tag_chip.dart';

/// A Notion-style tag selector with multi-select and create-on-the-fly
class TagSelector extends StatefulWidget {
  final List<String> selectedTagIds;
  final Function(List<String>) onTagsChanged;
  final String? hintText;

  const TagSelector({
    super.key,
    required this.selectedTagIds,
    required this.onTagsChanged,
    this.hintText,
  });

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Listen for focus changes to close dropdown when focus is lost
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Don't close immediately on focus loss - let TapRegion handle it
  }

  void _closeDropdown() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        _searchQuery = '';
        _searchController.clear();
      });
      _focusNode.unfocus();
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _focusNode.requestFocus();
      } else {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _toggleTag(String tagId) {
    final newSelection = List<String>.from(widget.selectedTagIds);
    if (newSelection.contains(tagId)) {
      newSelection.remove(tagId);
    } else {
      newSelection.add(tagId);
    }
    widget.onTagsChanged(newSelection);
  }

  void _removeTag(String tagId) {
    final newSelection = List<String>.from(widget.selectedTagIds);
    newSelection.remove(tagId);
    widget.onTagsChanged(newSelection);
  }

  Future<void> _createTag(String name, TagProvider tagProvider) async {
    final color = tagProvider.getNextAvailableColor();
    final newTag = await tagProvider.createTag(name: name, colorHex: color);

    // Add to selection
    final newSelection = List<String>.from(widget.selectedTagIds);
    newSelection.add(newTag.id);
    widget.onTagsChanged(newSelection);

    // Clear search
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TagProvider>(
      builder: (context, tagProvider, _) {
        final allTags = tagProvider.tags;
        final selectedTags = widget.selectedTagIds
            .map((id) => tagProvider.getTag(id))
            .whereType<Tag>()
            .toList();

        // Filter tags based on search
        final filteredTags = _searchQuery.isEmpty
            ? allTags
            : allTags
                  .where(
                    (t) => t.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
                  )
                  .toList();

        // Check if we can create a new tag with this name
        final canCreateNew =
            _searchQuery.isNotEmpty && !tagProvider.tagNameExists(_searchQuery);

        return TapRegion(
          onTapOutside: (_) => _closeDropdown(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selected tags display
              GestureDetector(
                onTap: _toggleExpanded,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isExpanded ? Colors.black : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: selectedTags.isEmpty
                      ? Text(
                          widget.hintText ?? 'Select tags...',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 15,
                          ),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...selectedTags.map(
                              (tag) => TagChip(
                                tag: tag,
                                selected: true,
                                showRemove: true,
                                onRemove: () => _removeTag(tag.id),
                              ),
                            ),
                            // Add more indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Expanded dropdown
              if (_isExpanded) ...[
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search input
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: 'Search or create tag...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade400,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),

                      // Tag list
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Create new option
                              if (canCreateNew)
                                _TagOption(
                                  label: 'Create "$_searchQuery"',
                                  icon: Icons.add_circle_outline,
                                  onTap: () =>
                                      _createTag(_searchQuery, tagProvider),
                                ),

                              // Existing tags
                              ...filteredTags.map((tag) {
                                final isSelected = widget.selectedTagIds
                                    .contains(tag.id);
                                return _TagOption(
                                  tag: tag,
                                  isSelected: isSelected,
                                  onTap: () => _toggleTag(tag.id),
                                );
                              }),

                              // Empty state
                              if (filteredTags.isEmpty && !canCreateNew)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'No tags found',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Bottom padding for cleaner look
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A single option in the tag dropdown
class _TagOption extends StatelessWidget {
  final Tag? tag;
  final String? label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagOption({
    this.tag,
    this.label,
    this.icon,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (tag != null) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: tag!.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tag!.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, size: 18, color: Colors.black),
            ] else ...[
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
