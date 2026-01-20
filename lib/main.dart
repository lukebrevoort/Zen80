import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// Legacy models (for migration)
import 'models/task.dart';

// New v2 models
import 'models/tag.dart';
import 'models/sub_task.dart';
import 'models/time_slot.dart';
import 'models/day_schedule.dart';
import 'models/signal_task.dart';
import 'models/user_settings.dart';
import 'models/weekly_stats.dart';
import 'models/calendar_sync_operation.dart';
import 'models/rollover_suggestion.dart';

// Providers
import 'providers/task_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/signal_task_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/rollover_provider.dart';

// Services
import 'services/storage_service.dart';
import 'services/migration_service.dart';
import 'services/notification_service.dart';
import 'services/live_activity_service.dart';
import 'services/settings_service.dart';
import 'services/sync_service.dart';
import 'services/background_sync_service.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/daily_planning_flow.dart';
import 'screens/scheduling_screen.dart';
import 'screens/initial_scheduling_screen.dart';
import 'screens/rollover_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Register legacy adapters (for migration)
  Hive.registerAdapter(TaskTypeAdapter());
  Hive.registerAdapter(TaskAdapter());

  // Register new v2 adapters
  Hive.registerAdapter(TagAdapter());
  Hive.registerAdapter(SubTaskAdapter());
  Hive.registerAdapter(TimeSlotAdapter());
  Hive.registerAdapter(DayScheduleAdapter());
  Hive.registerAdapter(TaskStatusAdapter());
  Hive.registerAdapter(SignalTaskAdapter());
  Hive.registerAdapter(UserSettingsAdapter());
  Hive.registerAdapter(WeeklyStatsAdapter());
  Hive.registerAdapter(SyncOperationTypeAdapter());
  Hive.registerAdapter(CalendarSyncOperationAdapter());
  Hive.registerAdapter(SuggestionStatusAdapter());
  Hive.registerAdapter(RolloverSuggestionAdapter());

  // Open legacy box (for migration)
  await Hive.openBox<Task>('tasks');

  // Open new v2 boxes
  await Hive.openBox<SignalTask>('signal_tasks');
  await Hive.openBox<Tag>('tags');
  await Hive.openBox('settings'); // Dynamic box for UserSettings
  await Hive.openBox<WeeklyStats>('weekly_stats');
  await Hive.openBox<CalendarSyncOperation>('sync_queue');
  await Hive.openBox<RolloverSuggestion>('rollover_suggestions');

  // Initialize services
  final storageService = StorageService();

  // Run migration if needed
  final migrationService = MigrationService(storageService);
  if (migrationService.needsMigration()) {
    final result = await migrationService.migrate();
    debugPrint('Migration result: $result');
  }

  // Initialize default tags if needed
  await storageService.initializeDefaultTags();

  // Initialize other services
  await SettingsService().initialize();
  await NotificationService().initialize();
  await LiveActivityService().initialize();
  await SyncService().initialize();
  await BackgroundSyncService().initialize();

  runApp(Zen80App(storageService: storageService));
}

class Zen80App extends StatefulWidget {
  final StorageService storageService;

  const Zen80App({super.key, required this.storageService});

  @override
  State<Zen80App> createState() => _Zen80AppState();
}

class _Zen80AppState extends State<Zen80App> with WidgetsBindingObserver {
  late TaskProvider _taskProvider;
  late TagProvider _tagProvider;
  late SettingsProvider _settingsProvider;
  late SignalTaskProvider _signalTaskProvider;
  late CalendarProvider _calendarProvider;
  late StatsProvider _statsProvider;
  late RolloverProvider _rolloverProvider;
  bool _showOnboarding = false;
  bool _isInitialized = false;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize providers
    _taskProvider = TaskProvider()..loadTasks();
    _tagProvider = TagProvider(widget.storageService);
    _settingsProvider = SettingsProvider(widget.storageService);
    _signalTaskProvider = SignalTaskProvider(widget.storageService);
    _calendarProvider = CalendarProvider();
    _statsProvider = StatsProvider(widget.storageService, SettingsService());
    _rolloverProvider = RolloverProvider(widget.storageService);

    // Wire up notification callbacks for SignalTaskProvider
    _signalTaskProvider.onTimerStart = _handleTimerStarted;
    _signalTaskProvider.onTimerStop = _handleTimerStopped;
    _signalTaskProvider.onAutoEnd = _handleTaskAutoEnded;
    _signalTaskProvider.onTimerReachedEnd = _handleTimerReachedEnd;

    // Wire up sync callback so remote changes refresh SignalTaskProvider
    _calendarProvider.setOnSignalTasksChanged(() {
      _signalTaskProvider.refresh();
    });

    // Check if onboarding needs to be shown
    // Use both old and new settings for backward compatibility
    _showOnboarding =
        !SettingsService().onboardingCompleted &&
        !_settingsProvider.hasCompletedOnboarding;

    // Determine initial screen after providers are ready
    _determineInitialScreen();

    // Request notification permissions after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      NotificationService().requestPermissions();
    });

    // Record initial activity timestamp
    NotificationService().recordActivity();

    // Reset golden ratio notification status if it's a new day
    SettingsService().resetGoldenRatioIfNewDay();
  }

  /// Handle when a timer starts - update notifications for smart centralized system
  void _handleTimerStarted(SignalTask activeTask, TimeSlot slot) {
    // Cancel notifications for all inactive tasks first
    final allTasks = _signalTaskProvider.tasks;
    NotificationService().cancelNotificationsForInactiveTasks(
      allTasks,
      activeTask.id,
    );

    // Then update notifications for the active task
    NotificationService().onTimerStarted(activeTask, slot);
  }

  /// Handle when a timer stops - update notification state
  void _handleTimerStopped(SignalTask task, TimeSlot slot) {
    NotificationService().onTimerStopped(task, slot);
  }

  /// Handle when a task is auto-ended (timer reached end and autoEnd is enabled)
  void _handleTaskAutoEnded(SignalTask task, TimeSlot slot) {
    final duration = Duration(seconds: slot.accumulatedSeconds);

    // Show task auto-ended notification
    NotificationService().showTaskAutoEndedNotification(
      taskTitle: task.title,
      actualDuration: duration,
    );

    // Cancel the slot-specific notifications since task has ended
    NotificationService().cancelSlotNotifications(slot.id);

    // Check for next task and show reminder if enabled
    if (_settingsProvider.enableNextTaskReminders) {
      _checkForNextTaskReminder();
    }
  }

  /// Handle when timer reaches its planned end time (for UI prompts)
  void _handleTimerReachedEnd(SignalTask task, TimeSlot slot) {
    // This callback is for showing a prompt to the user
    // The actual prompt would typically be shown via a dialog or notification
    // For now, we'll rely on the scheduled "Task Ending Soon" notification
    // which was already scheduled when "Start My Day" was pressed
    debugPrint(
      'Timer reached end for ${task.title} - user can continue or end',
    );
  }

  /// Check if there's a next task scheduled and show reminder
  void _checkForNextTaskReminder() {
    final now = DateTime.now();
    final tasks = _signalTaskProvider.scheduledTasks;

    // Find the next scheduled slot that hasn't started yet
    TimeSlot? nextSlot;
    SignalTask? nextTask;

    for (final task in tasks) {
      for (final slot in task.timeSlots) {
        if (slot.isDiscarded || slot.hasStarted) continue;
        if (slot.plannedStartTime.isAfter(now)) {
          if (nextSlot == null ||
              slot.plannedStartTime.isBefore(nextSlot.plannedStartTime)) {
            nextSlot = slot;
            nextTask = task;
          }
        }
      }
    }

    if (nextTask != null && nextSlot != null) {
      final timeUntilStart = nextSlot.plannedStartTime.difference(now);
      NotificationService().showNextTaskReminder(
        nextTaskTitle: nextTask.title,
        timeUntilStart: timeUntilStart,
      );
    }
  }

  /// Determine which screen to show on app open
  void _determineInitialScreen() {
    // If onboarding needed, that takes priority
    if (_showOnboarding) {
      _initialScreen = OnboardingScreen(onComplete: _onOnboardingComplete);
      _isInitialized = true;
      return;
    }

    // Check for rollover suggestions (async, will update screen when done)
    _checkRolloverAndDetermineScreen();
  }

  /// Check for rollover suggestions and then determine the appropriate screen
  Future<void> _checkRolloverAndDetermineScreen() async {
    // First check for rollover suggestions from previous days
    await _rolloverProvider.checkForRolloverSuggestions();

    // If there are pending rollover suggestions, show the rollover screen
    if (_rolloverProvider.hasPendingSuggestions) {
      setState(() {
        _initialScreen = RolloverScreen(onComplete: _onRolloverComplete);
        _isInitialized = true;
      });
      return;
    }

    // No rollover suggestions - continue with normal flow
    _setNormalInitialScreen();
  }

  /// Called when user finishes processing rollover suggestions
  void _onRolloverComplete() {
    // Refresh tasks to include any newly created rolled tasks
    _signalTaskProvider.refresh();

    // After rollover screen, ALWAYS go to daily planning flow
    // This allows users to add NEW tasks on top of accepted rollovers
    // We don't pass rollovers as suggestions because they're already created in DB
    setState(() {
      _initialScreen = const DailyPlanningFlow(rolloverSuggestions: []);
    });

    // Replace current screen with daily planning flow
    if (mounted && _initialScreen != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => _initialScreen!));
    }
  }

  /// Set the initial screen based on normal app flow (no rollover)
  void _setNormalInitialScreen() {
    // PRIORITY CHECK: If there's an active timer running, always go to HomeScreen
    // This prevents forcing users to reschedule when they're in the middle of work
    // (e.g., ad-hoc session still running after a scheduled slot's end time passed)
    if (_signalTaskProvider.hasActiveTimer) {
      _initialScreen = const HomeScreen();
      setState(() {
        _isInitialized = true;
      });
      return;
    }

    // Check if user has tasks planned for today
    final todayTasks = _signalTaskProvider.tasks;
    final hasPlannedToday = todayTasks.isNotEmpty;

    if (hasPlannedToday) {
      // Check if user has ALREADY set up their day (has any scheduled slots)
      // This distinguishes between:
      // 1. Tasks just added but never scheduled → Force InitialSchedulingScreen
      // 2. Tasks that were scheduled (even if slots are now missed) → Go to HomeScreen
      //
      // We should NOT force users to reschedule missed slots - that's their choice.
      // Missed slots are just part of the day, not a blocking condition.
      final hasAnyScheduledSlots =
          _signalTaskProvider.scheduledTasks.isNotEmpty;

      if (hasAnyScheduledSlots) {
        // User already set up their day - go straight to dashboard
        // Even if some tasks still need scheduling, don't block them
        _initialScreen = const HomeScreen();
      } else {
        // User has tasks but NONE are scheduled yet - this is initial setup
        _initialScreen = const InitialSchedulingScreen();
      }
    } else {
      // User hasn't planned today - show planning screen
      // Get yesterday's incomplete tasks for rollover suggestions
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayTasks = _signalTaskProvider.getTasksForDate(yesterday);
      final incompleteTasks = yesterdayTasks
          .where((t) => !t.isComplete)
          .toList();

      _initialScreen = DailyPlanningFlow(rolloverSuggestions: incompleteTasks);
    }

    setState(() {
      _isInitialized = true;
    });
  }

  void _onOnboardingComplete() {
    // Mark onboarding complete in both old and new settings
    SettingsService().completeOnboarding();
    _settingsProvider.completeOnboarding();

    setState(() {
      _showOnboarding = false;
      // After onboarding, go to daily planning flow so user can add more tasks
      // and schedule their day (whether they created a first task or not)
      _initialScreen = const DailyPlanningFlow(rolloverSuggestions: []);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService().dispose();
    LiveActivityService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground - recalculate timer state
        _taskProvider.onAppResumed();
        _signalTaskProvider.onAppResumed();
        // Record activity
        NotificationService().recordActivity();
        // Trigger two-way calendar sync and refresh tasks if there were changes
        _calendarProvider.performSync().then((_) {
          // Refresh signal tasks in case sync pulled updates from Google Calendar
          _signalTaskProvider.refresh();
        });
        break;
      case AppLifecycleState.paused:
        // App going to background - nothing special needed
        // Live Activities continue to show the timer
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _taskProvider),
        ChangeNotifierProvider.value(value: _tagProvider),
        ChangeNotifierProvider.value(value: _settingsProvider),
        ChangeNotifierProvider.value(value: _signalTaskProvider),
        ChangeNotifierProvider.value(value: _calendarProvider),
        ChangeNotifierProvider.value(value: _statsProvider),
        ChangeNotifierProvider.value(value: _rolloverProvider),
      ],
      child: MaterialApp(
        title: 'Zen 80',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.black,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.black),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black),
            ),
          ),
          fontFamily: 'SF Pro Display',
        ),
        // Define named routes
        routes: {
          '/home': (context) => const HomeScreen(),
          '/planning': (context) => const DailyPlanningFlow(),
          '/scheduling': (context) => const SchedulingScreen(),
          '/initial-scheduling': (context) => const InitialSchedulingScreen(),
        },
        // Use the determined initial screen
        home: _showOnboarding
            ? OnboardingScreen(onComplete: _onOnboardingComplete)
            : !_isInitialized
            ? const _LoadingScreen()
            : _initialScreen ?? const HomeScreen(),
      ),
    );
  }
}

/// Simple loading screen shown while checking for rollover suggestions
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
