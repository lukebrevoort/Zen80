import 'package:flutter/material.dart';

import '../../models/signal_task.dart';

/// Dialog for choosing how much time to schedule when placing a task
/// Supports splitting a task into multiple time blocks
class SplitScheduleDialog extends StatefulWidget {
  final SignalTask task;
  final DateTime dropTime;
  final VoidCallback onCancel;
  final void Function(Duration duration) onSchedule;

  const SplitScheduleDialog({
    super.key,
    required this.task,
    required this.dropTime,
    required this.onCancel,
    required this.onSchedule,
  });

  @override
  State<SplitScheduleDialog> createState() => _SplitScheduleDialogState();
}

class _SplitScheduleDialogState extends State<SplitScheduleDialog> {
  late int _hours;
  late int _minutes;
  bool _scheduleRemaining = true;

  @override
  void initState() {
    super.initState();
    // Default to remaining time
    final remaining = widget.task.unscheduledMinutes;
    _hours = remaining ~/ 60;
    _minutes = remaining % 60;
  }

  int get _selectedMinutes => _hours * 60 + _minutes;

  bool get _isValidDuration {
    final selected = _selectedMinutes;
    return selected > 0 && selected <= widget.task.unscheduledMinutes;
  }

  String get _endTimeText {
    final endTime = widget.dropTime.add(Duration(minutes: _selectedMinutes));
    return _formatTime(endTime);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.task.unscheduledMinutes;
    final alreadyScheduled = widget.task.scheduledMinutes;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Schedule "${widget.task.title}"',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Task info
          _buildInfoRow('Task total', widget.task.formattedEstimatedTime),
          if (alreadyScheduled > 0)
            _buildInfoRow(
              'Already scheduled',
              '${_formatMinutes(alreadyScheduled)} (${_formatExistingSlots()})',
            ),
          _buildInfoRow(
            'Remaining',
            _formatMinutes(remaining),
            highlight: true,
          ),

          const SizedBox(height: 24),

          // Schedule options
          Text(
            'How long for this block?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Starting at ${_formatTime(widget.dropTime)}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),

          // Radio: Schedule remaining
          RadioListTile<bool>(
            value: true,
            groupValue: _scheduleRemaining,
            onChanged: (val) {
              setState(() {
                _scheduleRemaining = true;
                _hours = remaining ~/ 60;
                _minutes = remaining % 60;
              });
            },
            title: Text(
              'Schedule remaining time (${_formatMinutes(remaining)})',
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),

          // Radio: Schedule partial
          RadioListTile<bool>(
            value: false,
            groupValue: _scheduleRemaining,
            onChanged: (val) {
              setState(() => _scheduleRemaining = false);
            },
            title: const Text('Schedule partial time'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),

          // Duration picker (only visible for partial)
          if (!_scheduleRemaining) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildNumberPicker(
                    label: 'Hours',
                    value: _hours,
                    max: remaining ~/ 60 + 1, // Allow up to remaining hours
                    onChanged: (val) {
                      setState(() {
                        _hours = val;
                        // Clamp total to remaining
                        if (_selectedMinutes > remaining) {
                          _minutes = (remaining - _hours * 60).clamp(0, 59);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberPicker(
                    label: 'Minutes',
                    value: _minutes,
                    max: 59,
                    step: 15,
                    onChanged: (val) {
                      setState(() {
                        _minutes = val;
                        // Clamp total to remaining
                        if (_selectedMinutes > remaining) {
                          _minutes = remaining - _hours * 60;
                          if (_minutes < 0) {
                            _hours = remaining ~/ 60;
                            _minutes = remaining % 60;
                          }
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Block: ${_formatTime(widget.dropTime)} - $_endTimeText',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isValidDuration
                      ? () => widget.onSchedule(
                          Duration(minutes: _selectedMinutes),
                        )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Schedule ${_formatMinutes(_selectedMinutes)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w600 : null,
                color: highlight ? Colors.black : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPicker({
    required String label,
    required int value,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: value > 0
                    ? () => onChanged((value - step).clamp(0, max))
                    : null,
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: value < max
                    ? () => onChanged((value + step).clamp(0, max))
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatExistingSlots() {
    return widget.task.timeSlots
        .where((s) => !s.isDiscarded)
        .map(
          (s) =>
              '${_formatTime(s.plannedStartTime)}-${_formatTime(s.plannedEndTime)}',
        )
        .join(', ');
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
