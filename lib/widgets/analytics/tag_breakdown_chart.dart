import 'package:flutter/material.dart';
import '../../models/tag.dart';

/// Horizontal bar chart showing time per tag
///
/// Design: Clean horizontal bars with tag colors
/// - Shows tag name on left, colored bar in middle, time on right
/// - Sorted by time descending
/// - Responsive to container width
class TagBreakdownChart extends StatelessWidget {
  final Map<String, int> tagMinutes; // tagId -> minutes
  final Map<String, Tag> tags; // tagId -> Tag (for colors and names)
  final int? maxMinutes; // for scaling bars (optional, auto-calculate)
  final double barHeight;
  final double spacing;

  const TagBreakdownChart({
    super.key,
    required this.tagMinutes,
    required this.tags,
    this.maxMinutes,
    this.barHeight = 24,
    this.spacing = 12,
  });

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) return '${hours}h ${mins}m';
      return '${hours}h';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty state
    if (tagMinutes.isEmpty) {
      return _buildEmptyState();
    }

    // Sort entries by minutes descending
    final sortedEntries = tagMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate max for scaling
    final maxValue =
        maxMinutes ??
        (sortedEntries.isNotEmpty ? sortedEntries.first.value : 1);
    final effectiveMax = maxValue > 0 ? maxValue : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sortedEntries.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          _buildBarRow(sortedEntries[i], effectiveMax),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_outline, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No tag data',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarRow(MapEntry<String, int> entry, int maxValue) {
    final tag = tags[entry.key];
    final minutes = entry.value;
    final barFraction = (minutes / maxValue).clamp(0.0, 1.0);

    // Use a default color if tag not found
    final color = tag?.color ?? Colors.grey.shade400;
    final name = tag?.name ?? 'Unknown';

    return Row(
      children: [
        // Tag name
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),

        // Bar
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Background
                  Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),
                  // Filled portion
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * barFraction,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),

        // Time
        SizedBox(
          width: 60,
          child: Text(
            _formatMinutes(minutes),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// A more detailed version with percentage indicators
class TagBreakdownChartDetailed extends StatelessWidget {
  final Map<String, int> tagMinutes;
  final Map<String, Tag> tags;
  final int totalMinutes;

  const TagBreakdownChartDetailed({
    super.key,
    required this.tagMinutes,
    required this.tags,
    required this.totalMinutes,
  });

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) return '${hours}h ${mins}m';
      return '${hours}h';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (tagMinutes.isEmpty) {
      return _buildEmptyState();
    }

    // Sort entries by minutes descending
    final sortedEntries = tagMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final effectiveTotal = totalMinutes > 0 ? totalMinutes : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sortedEntries.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _buildDetailedRow(sortedEntries[i], effectiveTotal),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_outline, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No tag data available',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedRow(MapEntry<String, int> entry, int total) {
    final tag = tags[entry.key];
    final minutes = entry.value;
    final percentage = ((minutes / total) * 100).round();
    final barFraction = (minutes / total).clamp(0.0, 1.0);

    final color = tag?.color ?? Colors.grey.shade400;
    final name = tag?.name ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${_formatMinutes(minutes)} ($percentage%)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: barFraction,
            minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
