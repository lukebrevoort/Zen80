import 'package:flutter/material.dart';
import '../../models/tag.dart';

/// A colored chip displaying a tag
class TagChip extends StatelessWidget {
  final Tag tag;
  final bool selected;
  final bool showRemove;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const TagChip({
    super.key,
    required this.tag,
    this.selected = false,
    this.showRemove = false,
    this.onTap,
    this.onRemove,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? tag.color : tag.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: tag.color.withOpacity(selected ? 1 : 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.name,
              style: TextStyle(
                color: selected ? Colors.white : tag.color,
                fontSize: fontSize ?? 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showRemove) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: selected ? Colors.white70 : tag.color.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small dot indicator for a tag (used in compact views)
class TagDot extends StatelessWidget {
  final Tag tag;
  final double size;
  final VoidCallback? onTap;

  const TagDot({super.key, required this.tag, this.size = 8, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tag.name,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: tag.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// A row of tag chips with overflow handling
class TagChipRow extends StatelessWidget {
  final List<Tag> tags;
  final bool showRemove;
  final Function(Tag)? onRemove;
  final Function(Tag)? onTap;
  final int? maxVisible;
  final double spacing;

  const TagChipRow({
    super.key,
    required this.tags,
    this.showRemove = false,
    this.onRemove,
    this.onTap,
    this.maxVisible,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleTags = maxVisible != null && tags.length > maxVisible!
        ? tags.take(maxVisible!).toList()
        : tags;
    final hiddenCount = tags.length - visibleTags.length;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        ...visibleTags.map(
          (tag) => TagChip(
            tag: tag,
            showRemove: showRemove,
            onRemove: onRemove != null ? () => onRemove!(tag) : null,
            onTap: onTap != null ? () => onTap!(tag) : null,
          ),
        ),
        if (hiddenCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$hiddenCount',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

/// A compact row of tag dots
class TagDotRow extends StatelessWidget {
  final List<Tag> tags;
  final double dotSize;
  final double spacing;
  final int? maxVisible;

  const TagDotRow({
    super.key,
    required this.tags,
    this.dotSize = 8,
    this.spacing = 4,
    this.maxVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleTags = maxVisible != null && tags.length > maxVisible!
        ? tags.take(maxVisible!).toList()
        : tags;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < visibleTags.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          TagDot(tag: visibleTags[i], size: dotSize),
        ],
      ],
    );
  }
}
