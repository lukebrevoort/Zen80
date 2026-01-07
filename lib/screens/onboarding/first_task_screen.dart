import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/signal_task.dart';
import '../../providers/signal_task_provider.dart';
import '../../widgets/tags/tag_selector.dart';

/// First Task Screen - Final step in onboarding
/// Guides users through creating their first Signal task
/// with helpful tooltips and explanations
class FirstTaskScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const FirstTaskScreen({
    super.key,
    required this.onComplete,
    this.onBack,
    this.onSkip,
  });

  @override
  State<FirstTaskScreen> createState() => _FirstTaskScreenState();
}

class _FirstTaskScreenState extends State<FirstTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();

  int _estimatedMinutes = 60; // Default 1 hour
  List<String> _selectedTagIds = [];
  bool _isCreating = false;
  int _currentTipIndex = 0;

  // Helpful tips shown during task creation
  static const List<_OnboardingTip> _tips = [
    _OnboardingTip(
      icon: Icons.lightbulb_outline,
      title: 'Think Big Picture',
      description:
          'What\'s the most important thing you could work on today? That\'s your Signal.',
    ),
    _OnboardingTip(
      icon: Icons.access_time,
      title: 'Be Realistic',
      description:
          'Estimate how long it will actually take. It\'s okay to be wrong—you\'ll learn your patterns!',
    ),
    _OnboardingTip(
      icon: Icons.bolt,
      title: 'Start Small',
      description:
          'Pick 3-5 Signal tasks max. Focus is about saying no to the good so you can say yes to the great.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-focus the title field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final taskProvider = context.read<SignalTaskProvider>();

      final task = SignalTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        estimatedMinutes: _estimatedMinutes,
        tagIds: _selectedTagIds,
        subTasks: [],
        status: TaskStatus.notStarted,
        scheduledDate: DateTime.now(),
        timeSlots: [],
        isComplete: false,
        createdAt: DateTime.now(),
      );

      await taskProvider.addSignalTask(task);

      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _nextTip() {
    setState(() {
      _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // Title section
                      _buildTitleSection(),

                      const SizedBox(height: 32),

                      // Tip card
                      _buildTipCard(),

                      const SizedBox(height: 32),

                      // Task form
                      _buildTaskForm(),

                      const SizedBox(height: 32),

                      // Example tasks
                      _buildExampleTasks(),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),

            // Create button
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 48),
          Text(
            'Step 4 of 4',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: Text(
                'Skip',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Your First\nSignal Task',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Let\'s add your first critical task—something that truly moves you forward.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard() {
    final tip = _tips[_currentTipIndex];

    return GestureDetector(
      onTap: _nextTip,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade800, Colors.black],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tip.icon, color: Colors.white, size: 22),
                ),
                const Spacer(),
                // Dot indicators
                Row(
                  children: List.generate(_tips.length, (index) {
                    return Container(
                      width: index == _currentTipIndex ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: index == _currentTipIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tip.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tip.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade300,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap for next tip',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Task name field
        Text(
          'Task Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g., Finish project proposal',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a task name';
            }
            return null;
          },
        ),

        const SizedBox(height: 24),

        // Time estimate
        Text(
          'Time Estimate',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        _buildTimeEstimateSelector(),

        const SizedBox(height: 24),

        // Tags (optional)
        Row(
          children: [
            Text(
              'Tags',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Optional',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TagSelector(
          selectedTagIds: _selectedTagIds,
          onTagsChanged: (tagIds) {
            setState(() => _selectedTagIds = tagIds);
          },
        ),
      ],
    );
  }

  Widget _buildTimeEstimateSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTimeChip(15, '15m'),
        _buildTimeChip(30, '30m'),
        _buildTimeChip(60, '1h'),
        _buildTimeChip(90, '1.5h'),
        _buildTimeChip(120, '2h'),
        _buildTimeChip(180, '3h'),
      ],
    );
  }

  Widget _buildTimeChip(int minutes, String label) {
    final isSelected = _estimatedMinutes == minutes;

    return GestureDetector(
      onTap: () => setState(() => _estimatedMinutes = minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildExampleTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Examples of Signal Tasks',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildExampleChip('Write chapter 3'),
            _buildExampleChip('Practice presentation'),
            _buildExampleChip('Study for exam'),
            _buildExampleChip('Design mockups'),
            _buildExampleChip('Code new feature'),
            _buildExampleChip('Review research paper'),
          ],
        ),
      ],
    );
  }

  Widget _buildExampleChip(String text) {
    return GestureDetector(
      onTap: () {
        _titleController.text = text;
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final hasTitle = _titleController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: hasTitle && !_isCreating ? _createTask : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Create Task & Start',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

/// Onboarding tip data
class _OnboardingTip {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingTip({
    required this.icon,
    required this.title,
    required this.description,
  });
}
