import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Input widget for estimated time (hours and minutes)
class TimeEstimateInput extends StatefulWidget {
  final int initialMinutes;
  final Function(int) onMinutesChanged;
  final String? label;

  const TimeEstimateInput({
    super.key,
    required this.initialMinutes,
    required this.onMinutesChanged,
    this.label,
  });

  @override
  State<TimeEstimateInput> createState() => _TimeEstimateInputState();
}

class _TimeEstimateInputState extends State<TimeEstimateInput> {
  late TextEditingController _hoursController;
  late TextEditingController _minutesController;

  @override
  void initState() {
    super.initState();
    final hours = widget.initialMinutes ~/ 60;
    final minutes = widget.initialMinutes % 60;
    _hoursController = TextEditingController(
      text: hours > 0 ? hours.toString() : '',
    );
    _minutesController = TextEditingController(
      text: minutes > 0 ? minutes.toString() : '',
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _updateMinutes() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final totalMinutes = (hours * 60) + minutes;
    widget.onMinutesChanged(totalMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            // Hours input
            Expanded(
              child: _TimeField(
                controller: _hoursController,
                label: 'Hours',
                maxValue: 23,
                onChanged: _updateMinutes,
              ),
            ),
            const SizedBox(width: 12),
            // Minutes input
            Expanded(
              child: _TimeField(
                controller: _minutesController,
                label: 'Minutes',
                maxValue: 59,
                onChanged: _updateMinutes,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxValue;
  final VoidCallback onChanged;

  const _TimeField({
    required this.controller,
    required this.label,
    required this.maxValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _MaxValueFormatter(maxValue),
      ],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

/// Formatter that limits input to a maximum value
class _MaxValueFormatter extends TextInputFormatter {
  final int maxValue;

  _MaxValueFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final value = int.tryParse(newValue.text);
    if (value == null || value > maxValue) {
      return oldValue;
    }
    return newValue;
  }
}

/// Quick preset buttons for common time estimates (simplified to 3 options)
class TimeEstimatePresets extends StatelessWidget {
  final int selectedMinutes;
  final Function(int) onSelect;
  final List<int>? customPresets;

  const TimeEstimatePresets({
    super.key,
    required this.selectedMinutes,
    required this.onSelect,
    this.customPresets,
  });

  // Default: 30m, 1h, 2h - simple and focused
  static const List<int> defaultPresets = [30, 60, 120];
  // Extended presets for when user needs more options
  static const List<int> extendedPresets = [15, 30, 45, 60, 90, 120, 180];

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final presets = customPresets ?? defaultPresets;
    return Row(
      children: presets.map((minutes) {
        final isSelected = selectedMinutes == minutes;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(minutes),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: presets.last == minutes ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                _formatMinutes(minutes),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Combined time estimate selector with presets and custom input
class TimeEstimateSelector extends StatefulWidget {
  final int initialMinutes;
  final Function(int) onMinutesChanged;
  final bool showLabel;

  const TimeEstimateSelector({
    super.key,
    required this.initialMinutes,
    required this.onMinutesChanged,
    this.showLabel = true,
  });

  @override
  State<TimeEstimateSelector> createState() => _TimeEstimateSelectorState();
}

class _TimeEstimateSelectorState extends State<TimeEstimateSelector> {
  late int _selectedMinutes;
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
    // Show custom input if initial value is not a default preset
    _showCustomInput =
        !TimeEstimatePresets.defaultPresets.contains(widget.initialMinutes) &&
        widget.initialMinutes > 0;
  }

  void _onPresetSelect(int minutes) {
    setState(() {
      _selectedMinutes = minutes;
      _showCustomInput = false;
    });
    widget.onMinutesChanged(minutes);
  }

  void _onCustomChange(int minutes) {
    setState(() {
      _selectedMinutes = minutes;
    });
    widget.onMinutesChanged(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          const Text(
            'Estimated Time',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Presets (3 options: 30m, 1h, 2h)
        TimeEstimatePresets(
          selectedMinutes: _showCustomInput ? -1 : _selectedMinutes,
          onSelect: _onPresetSelect,
        ),

        const SizedBox(height: 12),

        // Custom toggle
        GestureDetector(
          onTap: () {
            setState(() {
              _showCustomInput = !_showCustomInput;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _showCustomInput
                  ? Colors.grey.shade100
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showCustomInput
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  _showCustomInput ? 'Hide custom time' : 'Set custom time',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),

        // Custom input
        if (_showCustomInput) ...[
          const SizedBox(height: 8),
          TimeEstimateInput(
            initialMinutes: _selectedMinutes,
            onMinutesChanged: _onCustomChange,
          ),
        ],
      ],
    );
  }
}
