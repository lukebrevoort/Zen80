import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rollover_suggestion.dart';
import '../providers/rollover_provider.dart';
import '../providers/tag_provider.dart';
import '../widgets/tags/tag_chip.dart';

/// Screen shown on app launch when there are incomplete tasks from previous days
/// that could be rolled over to today.
class RolloverScreen extends StatefulWidget {
  /// Callback when user is done processing all suggestions
  final VoidCallback onComplete;

  const RolloverScreen({super.key, required this.onComplete});

  @override
  State<RolloverScreen> createState() => _RolloverScreenState();
}

class _RolloverScreenState extends State<RolloverScreen> {
  bool _isProcessing = false;

  Future<void> _acceptAll() async {
    setState(() => _isProcessing = true);
    try {
      final provider = context.read<RolloverProvider>();
      await provider.acceptAllSuggestions();
      _checkCompletion();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _dismissAll() async {
    setState(() => _isProcessing = true);
    try {
      final provider = context.read<RolloverProvider>();
      await provider.dismissAllSuggestions();
      _checkCompletion();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _checkCompletion() {
    final provider = context.read<RolloverProvider>();
    if (!provider.hasPendingSuggestions) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolloverProvider = context.watch<RolloverProvider>();
    final suggestions = rolloverProvider.pendingSuggestions;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Unfinished Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Skip button to dismiss all and continue
          TextButton(
            onPressed: _isProcessing ? null : _dismissAll,
            child: const Text('Skip All'),
          ),
        ],
      ),
      body: SafeArea(
        child: rolloverProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : rolloverProvider.errorMessage != null
            ? _buildErrorState(rolloverProvider.errorMessage!)
            : suggestions.isEmpty
            ? _buildEmptyState()
            : _buildSuggestionsList(suggestions, rolloverProvider),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onComplete,
              child: const Text('Continue Anyway'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No unfinished tasks to roll over',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(
    List<RolloverSuggestion> suggestions,
    RolloverProvider provider,
  ) {
    return Column(
      children: [
        // Header info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Colors.orange.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${suggestions.length} unfinished ${suggestions.length == 1 ? 'task' : 'tasks'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'These tasks weren\'t completed. Would you like to continue working on them today?',
                style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${provider.formattedTotalSuggestedTime} remaining',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange.shade600,
                ),
              ),
            ],
          ),
        ),

        // Suggestions list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              return _RolloverSuggestionCard(
                suggestion: suggestions[index],
                onAccept: () => _acceptSuggestion(suggestions[index]),
                onModify: () => _showModifyDialog(suggestions[index]),
                onDismiss: () => _dismissSuggestion(suggestions[index]),
                isProcessing: _isProcessing,
              );
            },
          ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _dismissAll,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Dismiss All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _acceptAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Accept All'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _acceptSuggestion(RolloverSuggestion suggestion) async {
    setState(() => _isProcessing = true);
    try {
      final provider = context.read<RolloverProvider>();
      await provider.acceptSuggestion(suggestion);
      _checkCompletion();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _dismissSuggestion(RolloverSuggestion suggestion) async {
    setState(() => _isProcessing = true);
    try {
      final provider = context.read<RolloverProvider>();
      await provider.dismissSuggestion(suggestion);
      _checkCompletion();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showModifyDialog(RolloverSuggestion suggestion) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _ModifyTimeDialog(
        currentMinutes: suggestion.suggestedMinutes,
        taskTitle: suggestion.originalTaskTitle,
      ),
    );

    if (result != null && mounted) {
      setState(() => _isProcessing = true);
      try {
        final provider = context.read<RolloverProvider>();
        await provider.acceptWithModification(suggestion, result);
        _checkCompletion();
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }
}

/// Individual suggestion card
class _RolloverSuggestionCard extends StatelessWidget {
  final RolloverSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onModify;
  final VoidCallback onDismiss;
  final bool isProcessing;

  const _RolloverSuggestionCard({
    required this.suggestion,
    required this.onAccept,
    required this.onModify,
    required this.onDismiss,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final tagProvider = context.watch<TagProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  suggestion.originalTaskTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Time info
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${suggestion.formattedSuggestedTime} remaining',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                // Tags
                if (suggestion.tagIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestion.tagIds.map((tagId) {
                      final tag = tagProvider.getTag(tagId);
                      if (tag == null) return const SizedBox.shrink();
                      return TagChip(
                        tag: tag,
                        fontSize: 11,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                // Dismiss button
                TextButton(
                  onPressed: isProcessing ? null : onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
                const Spacer(),
                // Modify button
                TextButton(
                  onPressed: isProcessing ? null : onModify,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Modify Time'),
                ),
                const SizedBox(width: 8),
                // Accept button
                ElevatedButton(
                  onPressed: isProcessing ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for modifying the suggested time
class _ModifyTimeDialog extends StatefulWidget {
  final int currentMinutes;
  final String taskTitle;

  const _ModifyTimeDialog({
    required this.currentMinutes,
    required this.taskTitle,
  });

  @override
  State<_ModifyTimeDialog> createState() => _ModifyTimeDialogState();
}

class _ModifyTimeDialogState extends State<_ModifyTimeDialog> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.currentMinutes ~/ 60;
    _minutes = widget.currentMinutes % 60;
  }

  int get _totalMinutes => (_hours * 60) + _minutes;

  String get _formattedTime {
    if (_hours > 0 && _minutes > 0) {
      return '${_hours}h ${_minutes}m';
    } else if (_hours > 0) {
      return '${_hours}h';
    } else {
      return '${_minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modify Time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.taskTitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          const Text(
            'How much time do you need?',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Hours picker
              Expanded(
                child: Column(
                  children: [
                    const Text('Hours'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _hours > 0
                                ? () => setState(() => _hours--)
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Expanded(
                            child: Text(
                              '$_hours',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _hours < 8
                                ? () => setState(() => _hours++)
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Minutes picker
              Expanded(
                child: Column(
                  children: [
                    const Text('Minutes'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _minutes >= 15
                                ? () => setState(() => _minutes -= 15)
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Expanded(
                            child: Text(
                              '$_minutes',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _minutes <= 45
                                ? () => setState(() => _minutes += 15)
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Total: $_formattedTime',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _totalMinutes > 0
              ? () => Navigator.of(context).pop(_totalMinutes)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
