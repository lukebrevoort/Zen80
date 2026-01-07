import 'package:flutter/material.dart';

/// A card displaying a single statistic with label and optional icon
///
/// Design: Clean, minimal card with subtle shadow
/// - Icon on the left (optional)
/// - Label above value
/// - Large, bold value
class StatsSummaryCard extends StatelessWidget {
  final String label; // e.g., "Total Signal Time"
  final String value; // e.g., "32h 15m"
  final IconData? icon;
  final Color? accentColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const StatsSummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? Colors.black87;
    final effectiveBackgroundColor = backgroundColor ?? Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            if (icon != null) ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveAccentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: effectiveAccentColor, size: 22),
              ),
              const SizedBox(width: 14),
            ],

            // Label and value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: effectiveAccentColor,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron if tappable
            if (onTap != null)
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

/// A compact version of the stats card for grid layouts
class CompactStatsSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final Color? backgroundColor;

  const CompactStatsSummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? Colors.black87;
    final effectiveBackgroundColor = backgroundColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon row
          if (icon != null) ...[
            Icon(icon, color: effectiveAccentColor, size: 20),
            const SizedBox(height: 10),
          ],

          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: effectiveAccentColor,
            ),
          ),
          const SizedBox(height: 2),

          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of stats summary cards
class StatsSummaryRow extends StatelessWidget {
  final List<StatsSummaryData> stats;
  final double spacing;

  const StatsSummaryRow({super.key, required this.stats, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(
            child: CompactStatsSummaryCard(
              label: stats[i].label,
              value: stats[i].value,
              icon: stats[i].icon,
              accentColor: stats[i].accentColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// Data class for stats summary
class StatsSummaryData {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;

  const StatsSummaryData({
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
  });
}

/// A highlighted stats card with gradient background
class HighlightedStatsSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final List<Color>? gradientColors;

  const HighlightedStatsSummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        gradientColors ?? [Colors.green.shade500, Colors.green.shade600];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          if (icon != null) ...[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
          ],

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state card for when there's no data
class EmptyStatsSummaryCard extends StatelessWidget {
  final String message;
  final IconData? icon;

  const EmptyStatsSummaryCard({
    super.key,
    this.message = 'No data available',
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.analytics_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
