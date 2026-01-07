import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/daily_summary.dart';
import '../providers/task_provider.dart';
import '../widgets/ratio_indicator.dart';

/// Screen showing the last 7 days of task history
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final summaries = provider.getWeeklySummaries();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: summaries.length,
        itemBuilder: (context, index) {
          return _DaySummaryCard(summary: summaries[index]);
        },
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  final DailySummary summary;

  const _DaySummaryCard({required this.summary});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final summaryDate = DateTime(date.year, date.month, date.day);

    if (summaryDate == today) {
      return 'Today';
    } else if (summaryDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTasks = summary.tasks.isNotEmpty;
    final hasTime = summary.totalTime.inSeconds > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(summary.date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasTasks) ...[
                    _StatRow(
                      label: 'Signal tasks',
                      value: '${summary.signalTasks.length}',
                      icon: Icons.flag,
                    ),
                    const SizedBox(height: 4),
                    _StatRow(
                      label: 'Noise tasks',
                      value: '${summary.noiseTasks.length}',
                      icon: Icons.blur_on,
                    ),
                    if (hasTime) ...[
                      const SizedBox(height: 4),
                      _StatRow(
                        label: 'Total time',
                        value: summary.formattedTotalTime,
                        icon: Icons.timer_outlined,
                      ),
                    ],
                  ] else
                    Text(
                      'No tasks',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            // Ratio indicator
            if (hasTime)
              CompactRatioIndicator(summary: summary)
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
                child: Icon(Icons.remove, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
