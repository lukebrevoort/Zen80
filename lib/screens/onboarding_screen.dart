import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/settings_service.dart';
import 'onboarding/philosophy_screen.dart';
import 'onboarding/schedule_setup_screen.dart';
import 'onboarding/timezone_screen.dart';
import 'onboarding/first_task_screen.dart';

/// Enhanced Onboarding Flow - 4 step process:
/// 1. Philosophy Screen - Introduce Signal/Noise concept
/// 2. Schedule Setup - Configure focus times per day
/// 3. Timezone - Select timezone (optional, auto-detect available)
/// 4. First Task - Create first Signal task with guided walkthrough
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;

  static const int _totalSteps = 4;

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _skipToEnd() {
    // Skip directly to completing onboarding
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    // Mark schedule setup as complete
    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.completeScheduleSetup();

    // Mark onboarding as complete in settings service
    await SettingsService().completeOnboarding();

    // Call the completion callback
    widget.onComplete();
  }

  Future<void> _handleTimezoneSelected(String? timezone) async {
    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.setTimezone(timezone);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0) {
          _previousStep();
        }
      },
      child: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return PhilosophyScreen(onContinue: _nextStep, onSkip: _skipToEnd);
      case 1:
        return ScheduleSetupScreen(
          onContinue: _nextStep,
          onBack: _previousStep,
          onSkip: _nextStep, // Allow skipping schedule setup
        );
      case 2:
        return Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return TimezoneScreen(
              onContinue: _nextStep,
              onBack: _previousStep,
              onSkip: _nextStep, // Timezone is optional
              onTimezoneSelected: _handleTimezoneSelected,
              currentTimezone: settings.timezone,
            );
          },
        );
      case 3:
        return FirstTaskScreen(
          onComplete: _completeOnboarding,
          onBack: _previousStep,
          onSkip: _completeOnboarding, // Allow skipping first task
        );
      default:
        return PhilosophyScreen(onContinue: _nextStep, onSkip: _skipToEnd);
    }
  }
}
