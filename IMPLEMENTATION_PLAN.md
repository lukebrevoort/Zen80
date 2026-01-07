# Signal/Noise v2.0 - Implementation Plan

## Executive Summary

Transform Signal/Noise from a simple time-tracking app into a comprehensive productivity system with:
- Google Calendar integration (read/write)
- Scheduled time slots with drag-and-drop
- Multi-tag organization system
- Sub-tasks linked to time blocks
- Weekly analytics with tag breakdown
- Smart rollover suggestions
- Interactive onboarding

---

## Table of Contents

1. [New Data Models](#1-new-data-models)
2. [Architecture Changes](#2-architecture-changes)
3. [New Dependencies](#3-new-dependencies)
4. [Screen & UI Changes](#4-screen--ui-changes)
5. [Google Calendar Integration](#5-google-calendar-integration)
6. [Notification System](#6-notification-system)
7. [Implementation Phases](#7-implementation-phases)
8. [Migration Strategy](#8-migration-strategy)
9. [Phase 6: Time Slot Splitting & Predicted vs. Actual Time - Detailed](#phase-6-time-slot-splitting--predicted-vs-actual-time---detailed-implementation)

---

## 1. New Data Models

### 1.1 SignalTask (replaces Task)

```dart
@HiveType(typeId: 1)
class SignalTask extends HiveObject {
  @HiveField(0)
  String id; // UUID
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  int estimatedMinutes; // User's ETC
  
  @HiveField(3)
  int actualMinutes; // Tracked time (calculated from timeSlots)
  
  @HiveField(4)
  List<String> tagIds; // References to Tag objects
  
  @HiveField(5)
  List<SubTask> subTasks; // Embedded sub-tasks
  
  @HiveField(6)
  TaskStatus status; // NotStarted, InProgress, Completed, Rolled
  
  @HiveField(7)
  DateTime scheduledDate; // The day this task is planned for
  
  @HiveField(8)
  List<TimeSlot> timeSlots; // Scheduled time blocks
  
  @HiveField(9)
  String? googleCalendarEventId; // For sync (null if not synced)
  
  @HiveField(10)
  bool isComplete;
  
  @HiveField(11)
  DateTime createdAt;
  
  @HiveField(12)
  String? rolledFromTaskId; // If this was rolled over from another task
  
  @HiveField(13)
  int remainingMinutesFromRollover; // How much time was suggested
}

@HiveType(typeId: 2)
enum TaskStatus {
  @HiveField(0)
  notStarted,
  @HiveField(1)
  inProgress,
  @HiveField(2)
  completed,
  @HiveField(3)
  rolled, // Rolled over to next day
}
```

### 1.2 TimeSlot

```dart
@HiveType(typeId: 3)
class TimeSlot extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  DateTime plannedStartTime;
  
  @HiveField(2)
  DateTime plannedEndTime;
  
  @HiveField(3)
  DateTime? actualStartTime; // When user actually started
  
  @HiveField(4)
  DateTime? actualEndTime; // When user actually ended
  
  @HiveField(5)
  bool isActive; // Currently running
  
  @HiveField(6)
  bool autoEnd; // Should auto-end when planned time is up
  
  @HiveField(7)
  List<String> linkedSubTaskIds; // SubTasks assigned to this slot
  
  @HiveField(8)
  String? googleCalendarEventId; // Individual slot's calendar event
  
  @HiveField(9)
  bool wasManualContinue; // User manually continued past end time
}
```

### 1.3 Tag

```dart
@HiveType(typeId: 4)
class Tag extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  String colorHex; // e.g., "#FF5733"
  
  @HiveField(3)
  bool isDefault; // Personal, School, Work - can't be deleted
  
  @HiveField(4)
  DateTime createdAt;
}
```

### 1.4 SubTask

```dart
@HiveType(typeId: 5)
class SubTask {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  bool isChecked;
  
  @HiveField(3)
  List<String> linkedTimeSlotIds; // Which slots this is assigned to
}
```

### 1.5 WeeklyStats

```dart
@HiveType(typeId: 6)
class WeeklyStats extends HiveObject {
  @HiveField(0)
  DateTime weekStartDate; // Monday of that week
  
  @HiveField(1)
  int totalSignalMinutes;
  
  @HiveField(2)
  int totalNoiseMinutes; // Calculated: totalFocusMinutes - totalSignalMinutes
  
  @HiveField(3)
  double signalNoiseRatio;
  
  @HiveField(4)
  int completedTasksCount;
  
  @HiveField(5)
  Map<String, int> tagBreakdown; // tagId -> minutes
  
  @HiveField(6)
  int totalFocusMinutes; // Sum of user's active hours for the week
}
```

### 1.6 UserSettings (expanded)

```dart
@HiveType(typeId: 7)
class UserSettings extends HiveObject {
  @HiveField(0)
  Map<int, DaySchedule> weeklySchedule; // 1=Mon, 7=Sun -> DaySchedule
  
  @HiveField(1)
  bool autoStartTasks; // default false
  
  @HiveField(2)
  bool autoEndTasks; // default true
  
  @HiveField(3)
  int notificationBeforeEndMinutes; // default 5
  
  @HiveField(4)
  bool hasCompletedOnboarding;
  
  @HiveField(5)
  String? googleAccessToken; // Stored locally for privacy
  
  @HiveField(6)
  String? googleRefreshToken;
  
  @HiveField(7)
  DateTime? googleTokenExpiry;
  
  @HiveField(8)
  String defaultSignalColorHex; // Default color for signal events in calendar
}

@HiveType(typeId: 8)
class DaySchedule {
  @HiveField(0)
  int dayOfWeek; // 1-7 (Mon-Sun)
  
  @HiveField(1)
  int activeStartHour; // e.g., 7 for 7am
  
  @HiveField(2)
  int activeStartMinute;
  
  @HiveField(3)
  int activeEndHour; // e.g., 23 for 11pm
  
  @HiveField(4)
  int activeEndMinute;
  
  @HiveField(5)
  bool isActiveDay; // Some users might not work Sundays
}
```

### 1.7 CalendarSyncQueue (for offline support)

```dart
@HiveType(typeId: 9)
class CalendarSyncOperation extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  SyncOperationType type; // Create, Update, Delete
  
  @HiveField(2)
  String taskId;
  
  @HiveField(3)
  String? timeSlotId;
  
  @HiveField(4)
  Map<String, dynamic> payload; // Event data
  
  @HiveField(5)
  DateTime createdAt;
  
  @HiveField(6)
  int retryCount;
}

@HiveType(typeId: 10)
enum SyncOperationType {
  @HiveField(0)
  create,
  @HiveField(1)
  update,
  @HiveField(2)
  delete,
}
```

### 1.8 RolloverSuggestion

```dart
@HiveType(typeId: 11)
class RolloverSuggestion extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String originalTaskId;
  
  @HiveField(2)
  String originalTaskTitle;
  
  @HiveField(3)
  int suggestedMinutes; // Remaining time
  
  @HiveField(4)
  List<String> tagIds;
  
  @HiveField(5)
  DateTime suggestedForDate;
  
  @HiveField(6)
  SuggestionStatus status; // Pending, Accepted, Modified, Dismissed
}

@HiveType(typeId: 12)
enum SuggestionStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  accepted,
  @HiveField(2)
  modified,
  @HiveField(3)
  dismissed,
}
```

---

## 2. Architecture Changes

### 2.1 New Project Structure

```
lib/
├── main.dart
├── app.dart                          # App configuration, theme
├── models/
│   ├── models.dart                   # Barrel export
│   ├── signal_task.dart              # NEW
│   ├── time_slot.dart                # NEW
│   ├── tag.dart                      # NEW
│   ├── sub_task.dart                 # NEW
│   ├── weekly_stats.dart             # NEW
│   ├── user_settings.dart            # NEW (expanded)
│   ├── day_schedule.dart             # NEW
│   ├── calendar_sync_operation.dart  # NEW
│   ├── rollover_suggestion.dart      # NEW
│   └── legacy/
│       └── task.dart                 # Keep for migration
├── providers/
│   ├── providers.dart                # Barrel export
│   ├── task_provider.dart            # REFACTOR -> signal_task_provider.dart
│   ├── calendar_provider.dart        # NEW - Google Calendar state
│   ├── tag_provider.dart             # NEW - Tag management
│   ├── settings_provider.dart        # NEW - User settings
│   └── stats_provider.dart           # NEW - Weekly stats
├── services/
│   ├── services.dart                 # Barrel export
│   ├── storage_service.dart          # REFACTOR - new models
│   ├── notification_service.dart     # REFACTOR - new notification types
│   ├── settings_service.dart         # REFACTOR -> merge into storage
│   ├── live_activity_service.dart    # UPDATE - new data
│   ├── google_calendar_service.dart  # NEW - Calendar API
│   ├── sync_service.dart             # NEW - Offline queue processing
│   ├── rollover_service.dart         # NEW - Rollover logic
│   └── migration_service.dart        # NEW - v1 -> v2 migration
├── screens/
│   ├── screens.dart                  # Barrel export
│   ├── home_screen.dart              # MAJOR REFACTOR - calendar view
│   ├── add_task_screen.dart          # MAJOR REFACTOR - ETC, tags, subtasks
│   ├── edit_task_screen.dart         # REFACTOR
│   ├── history_screen.dart           # REFACTOR -> weekly_review_screen.dart
│   ├── settings_screen.dart          # REFACTOR - new settings
│   ├── onboarding/                   # NEW folder
│   │   ├── onboarding_flow.dart      # Wrapper/controller
│   │   ├── philosophy_screen.dart    # Philosophy explanation
│   │   ├── schedule_setup_screen.dart # Set active hours per day
│   │   ├── calendar_connect_screen.dart # Optional Google Calendar
│   │   ├── first_task_screen.dart    # Create first signal task
│   │   └── tutorial_overlay.dart     # Interactive hints
│   ├── calendar_day_screen.dart      # NEW - Daily calendar view
│   ├── tag_management_screen.dart    # NEW - Settings sub-screen
│   ├── rollover_screen.dart          # NEW - Morning rollover prompts
│   └── debug_screen.dart             # Keep for development
├── widgets/
│   ├── widgets.dart                  # Barrel export
│   ├── ratio_indicator.dart          # Keep
│   ├── task_card.dart                # REFACTOR - tags, subtasks
│   ├── task_section.dart             # May remove (calendar view)
│   ├── calendar/                     # NEW folder
│   │   ├── day_calendar_view.dart    # Main calendar widget
│   │   ├── time_slot_tile.dart       # Draggable time slot
│   │   ├── calendar_event_tile.dart  # Google Calendar events
│   │   └── current_time_indicator.dart
│   ├── tags/                         # NEW folder
│   │   ├── tag_chip.dart             # Colored tag pill
│   │   ├── tag_selector.dart         # Multi-select with create
│   │   └── tag_input.dart            # Inline tag creation
│   ├── subtasks/                     # NEW folder
│   │   ├── subtask_list.dart         # Checklist
│   │   └── subtask_item.dart         # Single item
│   ├── timer/                        # NEW folder
│   │   ├── task_timer_modal.dart     # Start/continue/end controls
│   │   └── timer_display.dart        # Current timer state
│   └── common/
│       ├── loading_overlay.dart
│       └── error_snackbar.dart
└── utils/
    ├── constants.dart                # Colors, strings, config
    ├── extensions.dart               # DateTime, Duration helpers
    └── validators.dart               # Form validation
```

### 2.2 State Management

Keep **Provider** but add more focused providers:

| Provider | Responsibility |
|----------|----------------|
| `SignalTaskProvider` | CRUD for tasks, timer management, active task state |
| `CalendarProvider` | Google Calendar events, sync status, selected date |
| `TagProvider` | Tag CRUD, default tags initialization |
| `SettingsProvider` | User preferences, schedule, tokens |
| `StatsProvider` | Weekly stats calculation, history |

Consider using `ChangeNotifierProxyProvider` for providers that depend on each other.

---

## 3. New Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  # Existing - keep all
  
  # Google Calendar
  googleapis: ^13.2.0              # Google APIs client
  googleapis_auth: ^1.6.0          # OAuth handling
  google_sign_in: ^6.2.1           # Native sign-in UI
  
  # Calendar UI
  flutter_week_view: ^1.3.0        # Week/day calendar view
  # OR
  syncfusion_flutter_calendar: ^25.1.37  # More features, free community license
  
  # Drag and drop
  # (Built into Flutter, no extra package needed)
  
  # Connectivity for offline queue
  connectivity_plus: ^6.0.3
  
  # Secure storage for tokens
  flutter_secure_storage: ^9.2.2
  
  # Optional: Better state management
  # riverpod: ^2.5.1  # If you want to migrate from Provider
```

### Package Comparison: Calendar UI

| Package | Pros | Cons |
|---------|------|------|
| `flutter_week_view` | Lightweight, customizable, MIT | Less features, manual drag-drop |
| `syncfusion_flutter_calendar` | Rich features, drag-drop built-in, appointments | Larger bundle, license terms |
| Custom build | Full control | Most development time |

**Recommendation**: Start with `flutter_week_view` for simplicity. It's lightweight and gives us control over the drag-and-drop behavior with debounced calendar writes.

---

## 4. Screen & UI Changes

### 4.1 Screen Flow

```
App Launch
    │
    ├── First Launch ──────────────────────────┐
    │                                          │
    │   ┌──────────────────────────────────────▼───────┐
    │   │           ONBOARDING FLOW                    │
    │   │  1. Philosophy Screen (Steve Jobs quote)     │
    │   │  2. Schedule Setup (active hours per day)    │
    │   │  3. Google Calendar (optional connect)       │
    │   │  4. Create First Task (hands-on tutorial)    │
    │   └──────────────────────────────────────────────┘
    │                          │
    │                          ▼
    └── Returning User ──► HOME SCREEN (Daily Calendar View)
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
    Add Task              Weekly Review         Settings
    - Title               - Ratio chart         - Active hours
    - ETC                 - Tag breakdown       - Notifications
    - Tags                - Completed tasks     - Google Calendar
    - Sub-tasks           - History list        - Tag management
         │                                      - Auto start/end
         ▼                                      - Export data
    Calendar Placement                          - Philosophy
    - Drag to time slots
    - Link subtasks to slots
```

### 4.2 Home Screen Transformation

**Current**: List-based with Signal/Noise sections
**New**: Daily calendar timeline view

```
┌─────────────────────────────────────────┐
│  Today, January 1          [Settings]   │
│  Signal: 4h 30m  |  Ratio: 72%         │
├─────────────────────────────────────────┤
│  ┌─ 7:00 ─────────────────────────────┐ │
│  │  (Active hours start)              │ │
│  └────────────────────────────────────┘ │
│  ┌─ 8:00 ─────────────────────────────┐ │
│  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │ │  <- Empty slot
│  └────────────────────────────────────┘ │
│  ┌─ 9:00 ─────────────────────────────┐ │
│  │  ████ CS Class (from GCal) ████    │ │  <- Google event (gray)
│  │  [Mark as Signal]                  │ │
│  └────────────────────────────────────┘ │
│  ┌─ 10:00 ────────────────────────────┐ │
│  │  ▓▓▓▓ Study for CS Exam ▓▓▓▓▓▓▓▓▓  │ │  <- Signal task (colored)
│  │  🏷️ School, CS  ⏱️ 2h EST          │ │
│  │  ☐ Review Chapter 5               │ │  <- Subtask
│  │  ☐ Practice problems              │ │
│  └─ 12:00 ────────────────────────────┘ │
│  ... scrollable ...                     │
├─────────────────────────────────────────┤
│  Unscheduled Tasks (3)            [+]   │
│  ┌────────────────────────────────────┐ │
│  │  Fix website bug  🏷️ Work  1h     │ │  <- Drag to calendar
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### 4.3 Add Task Screen

```
┌─────────────────────────────────────────┐
│  ← New Signal Task                      │
├─────────────────────────────────────────┤
│                                         │
│  Task Name                              │
│  ┌────────────────────────────────────┐ │
│  │ Study for CS Exam                  │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Estimated Time                         │
│  ┌────────────────────────────────────┐ │
│  │  [2] hours  [30] minutes           │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Tags                                   │
│  ┌────────────────────────────────────┐ │
│  │ [School 🔵] [CS 🟣] [+ Add Tag]    │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Sub-tasks (optional)                   │
│  ┌────────────────────────────────────┐ │
│  │ ☐ Review Chapter 5            [×]  │ │
│  │ ☐ Practice problems           [×]  │ │
│  │ ☐ Make flashcards             [×]  │ │
│  │ [+ Add sub-task]                   │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │         Create Task                │ │
│  └────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### 4.4 Timer Modal (appears when task starts)

```
┌─────────────────────────────────────────┐
│                                         │
│         Study for CS Exam               │
│         🏷️ School, CS                   │
│                                         │
│              01:23:45                   │
│         ━━━━━━━━━━━━━━━━━━━             │
│         0:00        2:30 EST            │
│                                         │
│  Sub-tasks for this block:              │
│  ┌────────────────────────────────────┐ │
│  │ ☑ Review Chapter 5                 │ │
│  │ ☐ Practice problems                │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ┌────────────┐    ┌─────────────────┐  │
│  │   Pause    │    │  End Session    │  │
│  └────────────┘    └─────────────────┘  │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │       Continue Past End Time       │ │
│  └────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### 4.5 Weekly Review Screen

```
┌─────────────────────────────────────────┐
│  ← Week in Review                       │
│    Dec 25 - Dec 31, 2025                │
├─────────────────────────────────────────┤
│                                         │
│  ┌────────────────────────────────────┐ │
│  │         Signal : Noise             │ │
│  │                                    │ │
│  │      ████████████░░░░░░░           │ │
│  │         68% : 32%                  │ │
│  │                                    │ │
│  │   32h 15m Signal  |  15h 5m Noise  │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Tasks Completed: 18                    │
│                                         │
│  Time by Tag                            │
│  ┌────────────────────────────────────┐ │
│  │ 🔵 School      ██████████  12h 30m │ │
│  │ 🟢 Personal    ████████    10h 15m │ │
│  │ 🟣 CS          ██████       8h 00m │ │
│  │ 🟠 Work        ████         5h 30m │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Daily Breakdown                        │
│  ┌────────────────────────────────────┐ │
│  │ Mon  ████████████░░░  72%   5h 10m │ │
│  │ Tue  ██████████████░  85%   6h 20m │ │
│  │ Wed  █████████░░░░░░  58%   4h 15m │ │
│  │ ...                                │ │
│  └────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

---

## 5. Google Calendar Integration

### 5.1 Authentication Flow

1. User taps "Connect Google Calendar" in onboarding or settings
2. `google_sign_in` shows native sign-in sheet
3. Request scopes: `calendar.readonly`, `calendar.events`
4. Store tokens in `flutter_secure_storage` (not Hive - more secure)
5. Refresh token automatically when expired

### 5.2 Reading Calendar Events

```dart
class GoogleCalendarService {
  Future<List<CalendarEvent>> getEventsForDay(DateTime date) async {
    // 1. Get events from Google Calendar API
    // 2. Filter to selected date
    // 3. Return list with: title, start, end, eventId, color
  }
}
```

Display in calendar view as gray/muted blocks (Noise by default).

### 5.3 Writing Signal Events

When user creates/schedules a Signal task:
1. Create event in Google Calendar with:
   - Title: Task title
   - Color: Default signal color OR first tag's color
   - Description: "Signal task from Signal/Noise app"
2. Store `googleCalendarEventId` on TimeSlot

### 5.4 Updating Events (Timer Adjustments)

When actual time differs from planned:
```dart
void onTimerEnd(TimeSlot slot) async {
  slot.actualEndTime = DateTime.now();
  
  if (slot.googleCalendarEventId != null) {
    // Update event times in Google Calendar
    await calendarService.updateEvent(
      eventId: slot.googleCalendarEventId,
      newStart: slot.actualStartTime,
      newEnd: slot.actualEndTime,
    );
  }
}
```

### 5.5 Marking Existing Events as Signal

When user taps on a Google Calendar event:
1. Show option "Add to Signal"
2. Create SignalTask with:
   - Title from event
   - TimeSlot matching event times
   - Store `googleCalendarEventId` for reference
3. Update event color in Google Calendar to signal color

### 5.6 Offline Queue

```dart
class SyncService {
  final Queue<CalendarSyncOperation> _pendingOperations;
  
  void enqueue(CalendarSyncOperation op) {
    // Store in Hive
    // Attempt immediate sync if online
  }
  
  void processQueue() async {
    // Called on app launch and connectivity change
    // Process FIFO, retry failed operations
  }
}
```

---

## 6. Notification System

### 6.1 New Notification Types

| Type | Trigger | Action |
|------|---------|--------|
| Task Starting Soon | 5 min before planned start | "CS Exam Study starts in 5 minutes. Ready to focus?" |
| Task Start Prompt | At planned start time | "Time to start: CS Exam Study" with START button |
| Task Ending Soon | 5 min before planned end | "CS Exam Study ends in 5 minutes" |
| Task Auto-Ended | When time slot ends (if autoEnd) | "CS Exam Study session complete. Great work!" |
| Next Task Reminder | After ending, if another scheduled | "Up next: Fix Website Bug in 15 minutes" |
| Rollover Morning | Morning (at active start) | "You have 30 min remaining on CS Exam Study. Add to today?" |

### 6.2 Notification Preferences

In settings, user can toggle:
- Start reminders
- End reminders  
- Auto-end behavior
- Rollover suggestions
- Minutes before for each reminder type

---

## 7. Implementation Phases

### Phase 1: Foundation (Week 1-2)
**Goal**: New data models, storage, migration

- [ ] Create new model files with Hive annotations
- [ ] Run `build_runner` to generate adapters
- [ ] Update `StorageService` for new models
- [ ] Create `MigrationService` to convert old Task -> SignalTask
- [ ] Create default tags (Personal, School, Work)
- [ ] Update `pubspec.yaml` with new dependencies
- [ ] Create `TagProvider` and `SettingsProvider`

**Testing checkpoint**: App launches, old data migrates, new models persist

### Phase 2: Core Task Management (Week 2-3)
**Goal**: Enhanced task creation with tags, subtasks, ETC

- [ ] Build new `AddTaskScreen` with tags and subtasks
- [ ] Create `TagSelector` widget (Notion-style)
- [ ] Create `SubTaskList` widget
- [ ] Update `SignalTaskProvider` for new task structure
- [ ] Refactor `EditTaskScreen`
- [ ] Build `TagManagementScreen` for settings

**Testing checkpoint**: Can create tasks with tags, subtasks, and ETC

### Phase 3: Calendar View (Week 3-4)
**Goal**: Daily timeline view with drag-and-drop

- [ ] Integrate `flutter_week_view` package
- [ ] Create `DayCalendarView` widget
- [ ] Create `TimeSlotTile` (draggable)
- [ ] Implement drag-and-drop scheduling
- [ ] Add "Unscheduled Tasks" section
- [ ] Refactor `HomeScreen` to use calendar view
- [ ] Add current time indicator

**Testing checkpoint**: Can view day, drag tasks to schedule, see timeline

### Phase 4: Timer System (Week 4-5)
**Goal**: Scheduled time-block based timing with manual start

- [ ] Create `TaskTimerModal` widget
- [ ] Implement manual start requirement (default)
- [ ] Implement auto-end behavior
- [ ] Add "Continue" functionality for extending past end time
- [ ] Update `LiveActivityService` for new timer data
- [ ] Handle back-to-back task transitions
- [ ] Update notification service for new notification types

**Testing checkpoint**: Full timer flow with notifications, manual start/continue/end

### Phase 5: Google Calendar Integration (Week 5-7)
**Goal**: Read/write sync with Google Calendar

- [ ] Set up Google Cloud project, OAuth credentials
- [ ] Implement `GoogleCalendarService`
- [ ] Add calendar connection in onboarding
- [ ] Display Google events in calendar view
- [ ] "Mark as Signal" for existing events
- [ ] Write Signal tasks to Google Calendar
- [ ] Update events when actual times differ
- [ ] Implement `SyncService` with offline queue
- [ ] Add `connectivity_plus` for online detection

**Testing checkpoint**: Full calendar sync, offline queue works

### Phase 6: Time Slot Splitting & Predicted vs. Actual Time (Week 7-8)
**Goal**: Advanced scheduling with reality-aware calendar sync

See **[Phase 6 Detailed Implementation](#phase-6-time-slot-splitting--predicted-vs-actual-time---detailed-implementation)** for comprehensive specifications.

**Key Features**:
1. **Time Slot Splitting**: Break large tasks into multiple scheduled blocks
   - Split dialog when scheduling
   - Progress tracking for partially-scheduled tasks
   - Validation that splits sum to estimated time

2. **Predicted vs. Actual Time**: Calendar evolves from prediction to reality
   - Future events = predictions (editable)
   - Active events = locked start time, live end
   - Past events = facts (actual times synced)
   - Missed slot handling (reschedule/discard)

**Testing checkpoint**: Can split a 3h task into multiple blocks; calendar shows actual times after timer stops

### Phase 6.5: Analytics & Weekly Review (Week 8)
**Goal**: Weekly stats with tag breakdown

- [ ] Create `StatsProvider` with calculation logic
- [ ] Build `WeeklyReviewScreen`
- [ ] Ratio visualization (bar chart)
- [ ] Tag time breakdown
- [ ] Daily breakdown view
- [ ] Store `WeeklyStats` for historical access

**Testing checkpoint**: Accurate stats, tag breakdown matches expectations

### Phase 7: Rollover System (Week 8)
**Goal**: Smart suggestions for incomplete tasks

- [ ] Create `RolloverService` logic
- [ ] Detect incomplete tasks at end of day
- [ ] Generate `RolloverSuggestion` objects
- [ ] Build `RolloverScreen` for morning prompts
- [ ] Accept/modify/dismiss suggestions
- [ ] Link rolled tasks to originals

**Testing checkpoint**: Suggestions appear, accepting creates proper tasks

### Phase 8: Onboarding Overhaul (Week 8-9)
**Goal**: Interactive tutorial with real first task

- [ ] Design onboarding flow screens
- [ ] `PhilosophyScreen` with Steve Jobs quote
- [ ] `ScheduleSetupScreen` (per-day active hours)
- [ ] `CalendarConnectScreen` (optional)
- [ ] `FirstTaskScreen` (create real task with guidance)
- [ ] Tutorial overlays/tooltips for first-time features
- [ ] Store onboarding completion state

**Testing checkpoint**: New user can complete onboarding, has working setup

### Phase 9: Polish & Edge Cases (Week 9-10)
**Goal**: Handle all edge cases, polish UI

- [ ] Handle timezone edge cases
- [ ] Export/backup functionality
- [ ] Error handling for calendar API failures
- [ ] Loading states throughout app
- [ ] Empty states for all screens
- [ ] Accessibility review
- [ ] Performance optimization
- [ ] Update iOS Live Activities for new data

**Testing checkpoint**: App handles errors gracefully, feels polished

---

## 8. Migration Strategy

### 8.1 Data Migration (v1 -> v2)

When app launches after update:

```dart
class MigrationService {
  Future<void> migrateIfNeeded() async {
    final version = await getStoredVersion();
    
    if (version < 2) {
      await migrateV1ToV2();
      await setStoredVersion(2);
    }
  }
  
  Future<void> migrateV1ToV2() async {
    final oldTasks = await getOldTasks();
    
    for (final task in oldTasks) {
      if (task.type == TaskType.signal) {
        // Convert to SignalTask
        final signalTask = SignalTask(
          id: task.id,
          title: task.title,
          estimatedMinutes: task.timeSpentSeconds ~/ 60, // Use actual as estimate
          actualMinutes: task.timeSpentSeconds ~/ 60,
          tagIds: [], // No tags in v1
          subTasks: [],
          status: task.isCompleted ? TaskStatus.completed : TaskStatus.notStarted,
          scheduledDate: task.date,
          timeSlots: [], // No slots in v1
          isComplete: task.isCompleted,
          createdAt: task.createdAt,
        );
        await saveSignalTask(signalTask);
      }
      // Note: Noise tasks are not migrated - they're implicit
    }
    
    // Clean up old task box
    await deleteOldTaskBox();
  }
}
```

### 8.2 Preserving User Data

- All Signal tasks convert to SignalTask
- Noise tasks are not migrated (noise is everything not signal)
- Time spent is preserved
- Completion status preserved
- Old history remains viewable

---

## Summary

This transformation takes Signal/Noise from a simple timer to a full productivity system while maintaining its minimalist philosophy. The phased approach allows for incremental development and testing.

**Estimated Total Time**: 8-10 weeks for a solo developer

**Highest Risk Areas**:
1. Google Calendar OAuth setup and token management
2. Offline sync queue reliability
3. Drag-and-drop performance with many events
4. Timer state management across app lifecycle

**Quick Wins** (do first for visible progress):
1. Tag system
2. Calendar view UI
3. Enhanced add task screen

Let me know when you're ready to start implementation!

---

## Phase 5: Google Calendar Integration - Detailed Implementation

### Overview

Phase 5 transforms Signal/Noise from a standalone productivity app into an integrated calendar companion. Users can:
1. See their Google Calendar events alongside Signal tasks
2. "Mark as Signal" existing calendar events to track them
3. Have Signal tasks automatically appear in Google Calendar
4. Work offline with changes syncing when reconnected

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                │
├─────────────────────────────────────────────────────────────────┤
│  CalendarConnectionScreen  │  SettingsScreen  │  SchedulingScreen │
│  (Onboarding/Settings)     │  (Disconnect)    │  (View events)    │
└───────────────────────────────┬─────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│                      Provider Layer                             │
├─────────────────────────────────────────────────────────────────┤
│  CalendarProvider                                               │
│  - Google Calendar events for selected day                      │
│  - Connection status (connected/disconnected/syncing)           │
│  - Sync error state                                             │
│  - Selected calendar ID                                         │
└───────────────────────────────┬─────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│                      Service Layer                              │
├─────────────────────────────────────────────────────────────────┤
│  GoogleCalendarService         │  SyncService                   │
│  - OAuth sign-in/sign-out      │  - Process offline queue       │
│  - Token refresh               │  - Retry failed operations     │
│  - Read calendar events        │  - Conflict resolution         │
│  - Create/update/delete events │  - Connectivity monitoring     │
│  - List user's calendars       │                                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────┐
│                      Storage Layer                              │
├─────────────────────────────────────────────────────────────────┤
│  flutter_secure_storage       │  Hive                           │
│  - Access token               │  - CalendarSyncOperation queue  │
│  - Refresh token              │  - Cached calendar events       │
│  - Token expiry               │  - SignalTask.googleCalendarId  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.1 Google Cloud Project Setup

**Prerequisites** (External to code):

1. **Create Google Cloud Project**
   - Go to: https://console.cloud.google.com/
   - Create new project: "Signal Noise App"
   - Enable Google Calendar API

2. **Configure OAuth Consent Screen**
   - User Type: External
   - App name: Signal / Noise
   - Scopes: `calendar.readonly`, `calendar.events`
   - Test users: Add your email for development

3. **Create OAuth Credentials**
   - iOS: OAuth 2.0 Client ID (iOS application type)
     - Bundle ID: `com.yourcompany.signalnoise`
   - Android: OAuth 2.0 Client ID (Android application type)
     - Package name + SHA-1 fingerprint

4. **iOS Configuration** (`ios/Runner/Info.plist`)
   ```xml
   <!-- Add URL Scheme for OAuth callback -->
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   
   <!-- For google_sign_in plugin -->
   <key>GIDClientID</key>
   <string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>
   ```

5. **Android Configuration** (`android/app/src/main/res/values/strings.xml`)
   ```xml
   <resources>
     <string name="default_web_client_id">YOUR_WEB_CLIENT_ID</string>
   </resources>
   ```

### 5.2 New Files to Create

```
lib/
├── services/
│   ├── google_calendar_service.dart    # NEW - OAuth + API
│   └── sync_service.dart               # NEW - Offline queue
├── providers/
│   └── calendar_provider.dart          # NEW - Calendar state
├── screens/
│   └── calendar_connection_screen.dart # NEW - OAuth UI
└── models/
    └── google_calendar_event.dart      # NEW - Calendar event model
```

### 5.3 Implementation Tasks

#### Task 5.3.1: Create GoogleCalendarEvent Model

```dart
// lib/models/google_calendar_event.dart

/// Represents a Google Calendar event (for display only)
/// We don't persist these - they're fetched fresh from the API
class GoogleCalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final String? colorId;          // Google's color ID (1-11)
  final bool isAllDay;
  final String calendarId;
  
  // For linking to Signal tasks
  final String? linkedSignalTaskId;  // If this event was created by us
  
  GoogleCalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.colorId,
    this.isAllDay = false,
    required this.calendarId,
    this.linkedSignalTaskId,
  });
  
  /// Parse from Google Calendar API response
  factory GoogleCalendarEvent.fromGoogleEvent(Map<String, dynamic> json, String calendarId) {
    // Handle all-day vs timed events
    final start = json['start'];
    final end = json['end'];
    
    DateTime startTime;
    DateTime endTime;
    bool isAllDay = false;
    
    if (start['dateTime'] != null) {
      startTime = DateTime.parse(start['dateTime']);
      endTime = DateTime.parse(end['dateTime']);
    } else {
      // All-day event - date only
      startTime = DateTime.parse(start['date']);
      endTime = DateTime.parse(end['date']);
      isAllDay = true;
    }
    
    // Check if this event was created by Signal/Noise
    String? linkedTaskId;
    final description = json['description'] as String?;
    if (description?.contains('signal-noise-task:') == true) {
      final regex = RegExp(r'signal-noise-task:(\S+)');
      final match = regex.firstMatch(description!);
      linkedTaskId = match?.group(1);
    }
    
    return GoogleCalendarEvent(
      id: json['id'],
      title: json['summary'] ?? '(No title)',
      startTime: startTime,
      endTime: endTime,
      description: description,
      colorId: json['colorId'],
      isAllDay: isAllDay,
      calendarId: calendarId,
      linkedSignalTaskId: linkedTaskId,
    );
  }
  
  /// Whether this event was created by Signal/Noise
  bool get isSignalTask => linkedSignalTaskId != null;
  
  /// Duration of the event
  Duration get duration => endTime.difference(startTime);
  
  /// Get color for display (map Google's color IDs to Flutter colors)
  Color get color {
    // Google Calendar color IDs mapped to colors
    switch (colorId) {
      case '1': return const Color(0xFF7986CB); // Lavender
      case '2': return const Color(0xFF33B679); // Sage
      case '3': return const Color(0xFF8E24AA); // Grape
      case '4': return const Color(0xFFE67C73); // Flamingo
      case '5': return const Color(0xFFF6BF26); // Banana
      case '6': return const Color(0xFFFF8A65); // Tangerine
      case '7': return const Color(0xFF039BE5); // Peacock
      case '8': return const Color(0xFF616161); // Graphite
      case '9': return const Color(0xFF3F51B5); // Blueberry
      case '10': return const Color(0xFF0B8043); // Basil
      case '11': return const Color(0xFFD50000); // Tomato
      default: return const Color(0xFF9E9E9E); // Default gray
    }
  }
}
```

#### Task 5.3.2: Create GoogleCalendarService

```dart
// lib/services/google_calendar_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/google_calendar_event.dart';
import '../models/signal_task.dart';
import '../models/time_slot.dart';

/// Service for Google Calendar OAuth and API operations
class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();
  
  // Storage keys
  static const _accessTokenKey = 'google_access_token';
  static const _refreshTokenKey = 'google_refresh_token';
  static const _tokenExpiryKey = 'google_token_expiry';
  static const _selectedCalendarKey = 'google_selected_calendar';
  
  final _secureStorage = const FlutterSecureStorage();
  
  // Google Sign In configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      gcal.CalendarApi.calendarReadonlyScope,
      gcal.CalendarApi.calendarEventsScope,
    ],
  );
  
  // Cached API client
  gcal.CalendarApi? _calendarApi;
  GoogleSignInAccount? _currentUser;
  
  // State
  bool _isInitialized = false;
  String? _selectedCalendarId;
  
  /// Initialize the service (call on app start)
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Check if user was previously signed in
    _currentUser = await _googleSignIn.signInSilently();
    if (_currentUser != null) {
      await _setupApiClient();
    }
    
    // Load selected calendar
    _selectedCalendarId = await _secureStorage.read(key: _selectedCalendarKey);
    
    _isInitialized = true;
  }
  
  /// Whether user is connected to Google Calendar
  bool get isConnected => _currentUser != null && _calendarApi != null;
  
  /// Current user's email
  String? get userEmail => _currentUser?.email;
  
  /// Selected calendar ID (null = primary)
  String get selectedCalendarId => _selectedCalendarId ?? 'primary';
  
  /// Sign in to Google
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;
      
      await _setupApiClient();
      return true;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return false;
    }
  }
  
  /// Sign out from Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _clearTokens();
    _currentUser = null;
    _calendarApi = null;
    _selectedCalendarId = null;
  }
  
  /// Set up the Calendar API client with authentication
  Future<void> _setupApiClient() async {
    if (_currentUser == null) return;
    
    final auth = await _currentUser!.authentication;
    
    // Store tokens securely
    await _storeTokens(
      accessToken: auth.accessToken!,
      // Note: Google Sign-In handles refresh internally, but we store for reference
      idToken: auth.idToken,
    );
    
    // Create authenticated HTTP client
    final client = GoogleAuthClient(auth);
    _calendarApi = gcal.CalendarApi(client);
  }
  
  /// Store tokens securely
  Future<void> _storeTokens({
    required String accessToken,
    String? idToken,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    if (idToken != null) {
      await _secureStorage.write(key: 'google_id_token', value: idToken);
    }
  }
  
  /// Clear stored tokens
  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    await _secureStorage.delete(key: _selectedCalendarKey);
  }
  
  /// Set the selected calendar
  Future<void> setSelectedCalendar(String calendarId) async {
    _selectedCalendarId = calendarId;
    await _secureStorage.write(key: _selectedCalendarKey, value: calendarId);
  }
  
  // ============ Calendar Operations ============
  
  /// Get list of user's calendars
  Future<List<gcal.CalendarListEntry>> getCalendarList() async {
    if (_calendarApi == null) throw Exception('Not connected to Google Calendar');
    
    final response = await _calendarApi!.calendarList.list();
    return response.items ?? [];
  }
  
  /// Get events for a specific date
  Future<List<GoogleCalendarEvent>> getEventsForDate(DateTime date) async {
    if (_calendarApi == null) return [];
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    try {
      final events = await _calendarApi!.events.list(
        selectedCalendarId,
        timeMin: startOfDay.toUtc(),
        timeMax: endOfDay.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      
      return (events.items ?? [])
          .map((e) => GoogleCalendarEvent.fromGoogleEvent(
                _eventToMap(e),
                selectedCalendarId,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching calendar events: $e');
      return [];
    }
  }
  
  /// Get events for a date range
  Future<List<GoogleCalendarEvent>> getEventsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    if (_calendarApi == null) return [];
    
    try {
      final events = await _calendarApi!.events.list(
        selectedCalendarId,
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      
      return (events.items ?? [])
          .map((e) => GoogleCalendarEvent.fromGoogleEvent(
                _eventToMap(e),
                selectedCalendarId,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching calendar events: $e');
      return [];
    }
  }
  
  /// Create a calendar event for a Signal task time slot
  Future<String?> createEventForTimeSlot({
    required SignalTask task,
    required TimeSlot slot,
    String? colorId,
  }) async {
    if (_calendarApi == null) return null;
    
    final event = gcal.Event()
      ..summary = task.title
      ..description = 'Signal task from Signal/Noise\nsignal-noise-task:${task.id}'
      ..start = gcal.EventDateTime()..dateTime = slot.plannedStartTime.toUtc()
      ..end = gcal.EventDateTime()..dateTime = slot.plannedEndTime.toUtc()
      ..colorId = colorId ?? '9'; // Default to Blueberry (blue)
    
    try {
      final created = await _calendarApi!.events.insert(event, selectedCalendarId);
      return created.id;
    } catch (e) {
      debugPrint('Error creating calendar event: $e');
      return null;
    }
  }
  
  /// Update a calendar event (e.g., when actual times differ from planned)
  Future<bool> updateEvent({
    required String eventId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? colorId,
  }) async {
    if (_calendarApi == null) return false;
    
    try {
      // Fetch existing event
      final existing = await _calendarApi!.events.get(selectedCalendarId, eventId);
      
      // Update fields
      if (title != null) existing.summary = title;
      if (startTime != null) {
        existing.start = gcal.EventDateTime()..dateTime = startTime.toUtc();
      }
      if (endTime != null) {
        existing.end = gcal.EventDateTime()..dateTime = endTime.toUtc();
      }
      if (colorId != null) existing.colorId = colorId;
      
      await _calendarApi!.events.update(existing, selectedCalendarId, eventId);
      return true;
    } catch (e) {
      debugPrint('Error updating calendar event: $e');
      return false;
    }
  }
  
  /// Delete a calendar event
  Future<bool> deleteEvent(String eventId) async {
    if (_calendarApi == null) return false;
    
    try {
      await _calendarApi!.events.delete(selectedCalendarId, eventId);
      return true;
    } catch (e) {
      debugPrint('Error deleting calendar event: $e');
      return false;
    }
  }
  
  /// Mark an existing Google Calendar event as Signal (update its color)
  Future<bool> markEventAsSignal(String eventId) async {
    return updateEvent(eventId: eventId, colorId: '9'); // Blueberry = Signal
  }
  
  // Helper to convert gcal.Event to Map for parsing
  Map<String, dynamic> _eventToMap(gcal.Event event) {
    return {
      'id': event.id,
      'summary': event.summary,
      'description': event.description,
      'colorId': event.colorId,
      'start': {
        'dateTime': event.start?.dateTime?.toIso8601String(),
        'date': event.start?.date?.toString(),
      },
      'end': {
        'dateTime': event.end?.dateTime?.toIso8601String(),
        'date': event.end?.date?.toString(),
      },
    };
  }
}

/// Custom HTTP client that adds authentication headers
class GoogleAuthClient extends http.BaseClient {
  final GoogleSignInAuthentication _auth;
  final http.Client _client = http.Client();
  
  GoogleAuthClient(this._auth);
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer ${_auth.accessToken}';
    return _client.send(request);
  }
}
```

#### Task 5.3.3: Create SyncService

```dart
// lib/services/sync_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/calendar_sync_operation.dart';
import '../models/signal_task.dart';
import '../models/time_slot.dart';
import 'storage_service.dart';
import 'google_calendar_service.dart';

/// Service for managing offline sync queue and connectivity
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();
  
  final StorageService _storage = StorageService();
  final GoogleCalendarService _calendar = GoogleCalendarService();
  final Uuid _uuid = const Uuid();
  
  StreamSubscription? _connectivitySubscription;
  bool _isProcessing = false;
  
  // Callbacks for UI updates
  void Function(String message)? onSyncError;
  void Function()? onSyncComplete;
  void Function(int pending)? onQueueUpdated;
  
  /// Initialize the sync service
  Future<void> initialize() async {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    
    // Process any pending operations on startup if connected
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.none)) {
      await processQueue();
    }
  }
  
  /// Dispose the service
  void dispose() {
    _connectivitySubscription?.cancel();
  }
  
  /// Called when connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!results.contains(ConnectivityResult.none)) {
      // Back online - process queue
      processQueue();
    }
  }
  
  /// Check if currently online
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
  
  /// Get count of pending operations
  int get pendingCount => _storage.getPendingSyncOperations().length;
  
  // ============ Queue Operations ============
  
  /// Queue a CREATE operation for a time slot
  Future<void> queueCreateEvent({
    required SignalTask task,
    required TimeSlot slot,
    String? colorHex,
  }) async {
    final operation = CalendarSyncOperation.createEvent(
      id: _uuid.v4(),
      taskId: task.id,
      timeSlotId: slot.id,
      title: task.title,
      start: slot.plannedStartTime,
      end: slot.plannedEndTime,
      colorHex: colorHex,
    );
    
    await _storage.addSyncOperation(operation);
    onQueueUpdated?.call(pendingCount);
    
    // Try to process immediately if online
    if (await isOnline()) {
      await processQueue();
    }
  }
  
  /// Queue an UPDATE operation for a time slot
  Future<void> queueUpdateEvent({
    required SignalTask task,
    required TimeSlot slot,
    required String googleCalendarEventId,
    String? colorHex,
  }) async {
    final operation = CalendarSyncOperation.updateEvent(
      id: _uuid.v4(),
      taskId: task.id,
      timeSlotId: slot.id,
      googleCalendarEventId: googleCalendarEventId,
      title: task.title,
      start: slot.actualStartTime ?? slot.plannedStartTime,
      end: slot.actualEndTime ?? slot.plannedEndTime,
      colorHex: colorHex,
    );
    
    await _storage.addSyncOperation(operation);
    onQueueUpdated?.call(pendingCount);
    
    if (await isOnline()) {
      await processQueue();
    }
  }
  
  /// Queue a DELETE operation
  Future<void> queueDeleteEvent({
    required String taskId,
    String? timeSlotId,
    required String googleCalendarEventId,
  }) async {
    final operation = CalendarSyncOperation.deleteEvent(
      id: _uuid.v4(),
      taskId: taskId,
      timeSlotId: timeSlotId,
      googleCalendarEventId: googleCalendarEventId,
    );
    
    await _storage.addSyncOperation(operation);
    onQueueUpdated?.call(pendingCount);
    
    if (await isOnline()) {
      await processQueue();
    }
  }
  
  // ============ Queue Processing ============
  
  /// Process all pending operations in the queue
  Future<void> processQueue() async {
    if (_isProcessing) return;
    if (!_calendar.isConnected) return;
    
    _isProcessing = true;
    
    try {
      final operations = _storage.getPendingSyncOperations();
      
      for (final op in operations) {
        if (op.hasExceededRetries) {
          // Move to failed state - don't retry anymore
          continue;
        }
        
        bool success = false;
        String? eventId;
        
        try {
          switch (op.type) {
            case SyncOperationType.create:
              eventId = await _processCreate(op);
              success = eventId != null;
              break;
            case SyncOperationType.update:
              success = await _processUpdate(op);
              break;
            case SyncOperationType.delete:
              success = await _processDelete(op);
              break;
          }
        } catch (e) {
          op.recordFailure(e.toString());
          await _storage.updateSyncOperation(op);
          continue;
        }
        
        if (success) {
          // Update the task with the event ID if created
          if (op.type == SyncOperationType.create && eventId != null) {
            await _updateTaskWithEventId(op.taskId, op.timeSlotId!, eventId);
          }
          
          // Remove from queue
          await _storage.removeSyncOperation(op.id);
        } else {
          op.recordFailure('Operation failed');
          await _storage.updateSyncOperation(op);
        }
      }
      
      onQueueUpdated?.call(pendingCount);
      onSyncComplete?.call();
      
    } finally {
      _isProcessing = false;
    }
  }
  
  /// Process a CREATE operation
  Future<String?> _processCreate(CalendarSyncOperation op) async {
    // Get the task to get tag color
    final task = _storage.getSignalTask(op.taskId);
    if (task == null) return null;
    
    final slot = task.timeSlots.firstWhere(
      (s) => s.id == op.timeSlotId,
      orElse: () => throw Exception('Slot not found'),
    );
    
    return await _calendar.createEventForTimeSlot(
      task: task,
      slot: slot,
      colorId: _hexToGoogleColorId(op.eventColorHex),
    );
  }
  
  /// Process an UPDATE operation
  Future<bool> _processUpdate(CalendarSyncOperation op) async {
    if (op.googleCalendarEventId == null) return false;
    
    return await _calendar.updateEvent(
      eventId: op.googleCalendarEventId!,
      title: op.eventTitle,
      startTime: op.eventStart,
      endTime: op.eventEnd,
      colorId: _hexToGoogleColorId(op.eventColorHex),
    );
  }
  
  /// Process a DELETE operation
  Future<bool> _processDelete(CalendarSyncOperation op) async {
    if (op.googleCalendarEventId == null) return false;
    return await _calendar.deleteEvent(op.googleCalendarEventId!);
  }
  
  /// Update the SignalTask with the Google Calendar event ID
  Future<void> _updateTaskWithEventId(
    String taskId,
    String slotId,
    String eventId,
  ) async {
    final task = _storage.getSignalTask(taskId);
    if (task == null) return;
    
    final slotIndex = task.timeSlots.indexWhere((s) => s.id == slotId);
    if (slotIndex == -1) return;
    
    task.timeSlots[slotIndex] = task.timeSlots[slotIndex].copyWith(
      googleCalendarEventId: eventId,
    );
    
    await _storage.updateSignalTask(task);
  }
  
  /// Convert hex color to Google Calendar color ID
  String? _hexToGoogleColorId(String? hex) {
    if (hex == null) return '9'; // Default blue
    
    // Map common colors to Google's color IDs
    // This is a simplified mapping - could be expanded
    switch (hex.toUpperCase()) {
      case '#4285F4': return '9';  // Blue -> Blueberry
      case '#34A853': return '10'; // Green -> Basil
      case '#FBBC04': return '5';  // Yellow -> Banana
      case '#EA4335': return '11'; // Red -> Tomato
      case '#9C27B0': return '3';  // Purple -> Grape
      default: return '9';
    }
  }
}
```

#### Task 5.3.4: Create CalendarProvider

```dart
// lib/providers/calendar_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import '../models/google_calendar_event.dart';
import '../services/google_calendar_service.dart';
import '../services/sync_service.dart';

/// Connection status for Google Calendar
enum CalendarConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Provider for Google Calendar state
class CalendarProvider extends ChangeNotifier {
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  final SyncService _syncService = SyncService();
  
  CalendarConnectionStatus _status = CalendarConnectionStatus.disconnected;
  List<GoogleCalendarEvent> _events = [];
  List<gcal.CalendarListEntry> _calendars = [];
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;
  int _pendingSyncCount = 0;
  bool _isLoading = false;
  
  CalendarProvider() {
    _initialize();
  }
  
  /// Initialize provider
  Future<void> _initialize() async {
    await _calendarService.initialize();
    await _syncService.initialize();
    
    // Set up sync callbacks
    _syncService.onQueueUpdated = (count) {
      _pendingSyncCount = count;
      notifyListeners();
    };
    
    if (_calendarService.isConnected) {
      _status = CalendarConnectionStatus.connected;
      await loadCalendars();
      await loadEventsForDate(_selectedDate);
    }
    
    notifyListeners();
  }
  
  // ============ Getters ============
  
  CalendarConnectionStatus get status => _status;
  bool get isConnected => _status == CalendarConnectionStatus.connected;
  List<GoogleCalendarEvent> get events => List.unmodifiable(_events);
  List<gcal.CalendarListEntry> get calendars => List.unmodifiable(_calendars);
  DateTime get selectedDate => _selectedDate;
  String? get errorMessage => _errorMessage;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _isLoading;
  String? get userEmail => _calendarService.userEmail;
  String get selectedCalendarId => _calendarService.selectedCalendarId;
  
  /// Events that are NOT linked to Signal tasks (external events)
  List<GoogleCalendarEvent> get externalEvents =>
      _events.where((e) => !e.isSignalTask).toList();
  
  /// Events that ARE linked to Signal tasks
  List<GoogleCalendarEvent> get signalEvents =>
      _events.where((e) => e.isSignalTask).toList();
  
  // ============ Connection ============
  
  /// Connect to Google Calendar
  Future<bool> connect() async {
    _status = CalendarConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final success = await _calendarService.signIn();
      
      if (success) {
        _status = CalendarConnectionStatus.connected;
        await loadCalendars();
        await loadEventsForDate(_selectedDate);
      } else {
        _status = CalendarConnectionStatus.disconnected;
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _status = CalendarConnectionStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  /// Disconnect from Google Calendar
  Future<void> disconnect() async {
    await _calendarService.signOut();
    _status = CalendarConnectionStatus.disconnected;
    _events = [];
    _calendars = [];
    _errorMessage = null;
    notifyListeners();
  }
  
  // ============ Calendars ============
  
  /// Load list of user's calendars
  Future<void> loadCalendars() async {
    if (!isConnected) return;
    
    try {
      _calendars = await _calendarService.getCalendarList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading calendars: $e');
    }
  }
  
  /// Set the selected calendar
  Future<void> selectCalendar(String calendarId) async {
    await _calendarService.setSelectedCalendar(calendarId);
    await loadEventsForDate(_selectedDate);
  }
  
  // ============ Events ============
  
  /// Load events for a specific date
  Future<void> loadEventsForDate(DateTime date) async {
    if (!isConnected) return;
    
    _selectedDate = date;
    _isLoading = true;
    notifyListeners();
    
    try {
      _events = await _calendarService.getEventsForDate(date);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load calendar events';
      debugPrint('Error loading events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Refresh events for current date
  Future<void> refresh() async {
    await loadEventsForDate(_selectedDate);
  }
  
  /// Mark a Google Calendar event as a Signal task
  Future<bool> markEventAsSignal(String eventId) async {
    if (!isConnected) return false;
    
    try {
      final success = await _calendarService.markEventAsSignal(eventId);
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      debugPrint('Error marking event as signal: $e');
      return false;
    }
  }
  
  // ============ Sync ============
  
  /// Force process the sync queue
  Future<void> forceSync() async {
    await _syncService.processQueue();
  }
}
```

#### Task 5.3.5: Create CalendarConnectionScreen

```dart
// lib/screens/calendar_connection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/calendar_provider.dart';

/// Screen for connecting to Google Calendar
class CalendarConnectionScreen extends StatelessWidget {
  final bool isOnboarding;
  final VoidCallback? onSkip;
  final VoidCallback? onComplete;
  
  const CalendarConnectionScreen({
    super.key,
    this.isOnboarding = false,
    this.onSkip,
    this.onComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    final calendarProvider = context.watch<CalendarProvider>();
    
    return Scaffold(
      appBar: isOnboarding
          ? null
          : AppBar(
              title: const Text('Google Calendar'),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Skip button for onboarding
              if (isOnboarding) ...[
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: onSkip,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month,
                  size: 48,
                  color: Colors.grey.shade700,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Connect Google Calendar',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Description
              Text(
                'See your existing calendar events alongside your Signal tasks. '
                'Your Signal tasks will also appear in your calendar.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Benefits list
              _buildBenefitItem(
                icon: Icons.visibility,
                text: 'See busy times when scheduling',
              ),
              _buildBenefitItem(
                icon: Icons.sync,
                text: 'Signal tasks sync to your calendar',
              ),
              _buildBenefitItem(
                icon: Icons.flag,
                text: 'Mark existing events as Signal',
              ),
              
              const Spacer(),
              
              // Status indicator
              if (calendarProvider.status == CalendarConnectionStatus.connecting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(),
                ),
              
              if (calendarProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    calendarProvider.errorMessage!,
                    style: TextStyle(color: Colors.red.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Connect button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: calendarProvider.status == CalendarConnectionStatus.connecting
                      ? null
                      : () => _connect(context),
                  icon: Image.asset(
                    'assets/google_logo.png',
                    width: 24,
                    height: 24,
                    // Fallback if asset doesn't exist
                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata),
                  ),
                  label: const Text('Connect with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              
              if (isOnboarding) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Maybe later'),
                ),
              ],
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBenefitItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.green.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _connect(BuildContext context) async {
    final provider = context.read<CalendarProvider>();
    final success = await provider.connect();
    
    if (success && mounted) {
      onComplete?.call();
      if (!isOnboarding) {
        Navigator.of(context).pop();
      }
    }
  }
}
```

#### Task 5.3.6: Update Settings Screen

Add Google Calendar section to existing SettingsScreen:

```dart
// Add to lib/screens/settings_screen.dart

// In the build method, after the Tags section:

const SizedBox(height: 24),

// Google Calendar section
_buildSectionHeader('CALENDAR'),
Consumer<CalendarProvider>(
  builder: (context, calendarProvider, child) {
    if (calendarProvider.isConnected) {
      return Column(
        children: [
          _buildSettingTile(
            icon: Icons.check_circle,
            title: 'Google Calendar Connected',
            subtitle: calendarProvider.userEmail ?? 'Connected',
            value: '',
            onTap: () => _showCalendarOptions(context, calendarProvider),
          ),
          _buildSettingTile(
            icon: Icons.calendar_view_day,
            title: 'Selected Calendar',
            subtitle: 'Choose which calendar to sync with',
            value: _getCalendarName(calendarProvider),
            onTap: () => _showCalendarPicker(context, calendarProvider),
          ),
          if (calendarProvider.pendingSyncCount > 0)
            _buildInfoTile(
              '${calendarProvider.pendingSyncCount} changes pending sync',
            ),
        ],
      );
    } else {
      return _buildSettingTile(
        icon: Icons.calendar_month,
        title: 'Connect Google Calendar',
        subtitle: 'See events and sync tasks',
        value: '',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CalendarConnectionScreen(),
            ),
          );
        },
      );
    }
  },
),
```

#### Task 5.3.7: Integration Points

**Update main.dart:**
```dart
// Add CalendarProvider to MultiProvider
ChangeNotifierProvider(create: (_) => CalendarProvider()),

// Initialize SyncService
await SyncService().initialize();
```

**Update SignalTaskProvider:**
```dart
// When creating/updating time slots, queue sync operations
// After addTimeSlotToTask:
if (GoogleCalendarService().isConnected) {
  await SyncService().queueCreateEvent(task: task, slot: slot);
}

// After stopTimeSlot (when actual times differ):
if (slot.googleCalendarEventId != null) {
  await SyncService().queueUpdateEvent(
    task: task,
    slot: slot,
    googleCalendarEventId: slot.googleCalendarEventId!,
  );
}
```

**Update SchedulingScreen:**
```dart
// Show Google Calendar events in the calendar view
// Overlay external events (grayed out) with Signal tasks (colored)
```

### 5.4 Testing Checklist

#### 5.4.1 OAuth Flow
- [ ] Can sign in with Google account
- [ ] Token persists across app restarts
- [ ] Can sign out successfully
- [ ] Handle sign-in cancellation gracefully
- [ ] Handle sign-in errors with user feedback

#### 5.4.2 Reading Events
- [ ] Events load for selected date
- [ ] All-day events display correctly
- [ ] Multi-day events handled
- [ ] Events from correct calendar shown
- [ ] Can switch between calendars

#### 5.4.3 Writing Events
- [ ] Signal task time slots create calendar events
- [ ] Event title matches task title
- [ ] Event times match time slot
- [ ] Event color reflects Signal status
- [ ] Description includes task ID for linking

#### 5.4.4 Updating Events
- [ ] Stopping timer updates event end time
- [ ] Moving time slot updates event times
- [ ] Deleting time slot deletes event
- [ ] Task title changes update event title

#### 5.4.5 Offline Queue
- [ ] Operations queue when offline
- [ ] Queue processes when back online
- [ ] Failed operations retry
- [ ] Max retries prevents infinite loops
- [ ] Queue count shows in UI

#### 5.4.6 Mark as Signal
- [ ] External events show "Mark as Signal" option
- [ ] Marking changes event color
- [ ] Creates linked SignalTask
- [ ] Time slot matches event times

### 5.5 Error Handling

| Scenario | Handling |
|----------|----------|
| No internet on sign-in | Show error, allow retry |
| Token expired | Auto-refresh via google_sign_in |
| API rate limit | Exponential backoff in sync queue |
| Calendar deleted | Skip events, don't crash |
| Event deleted externally | Remove link, keep task |
| Concurrent edits | Last-write-wins (simple) |

### 5.6 Privacy & Security

1. **Token Storage**: Use `flutter_secure_storage` (Keychain/Keystore)
2. **Minimal Scopes**: Only request necessary calendar permissions
3. **Local-First**: App works fully offline, calendar is optional
4. **No Server**: All data stays on device + user's Google account
5. **Clear Disconnect**: One-tap to disconnect and clear tokens

### 5.7 Estimated Timeline

| Sub-task | Time |
|----------|------|
| 5.3.1 GoogleCalendarEvent model | 1 hour |
| 5.3.2 GoogleCalendarService | 4 hours |
| 5.3.3 SyncService | 3 hours |
| 5.3.4 CalendarProvider | 2 hours |
| 5.3.5 CalendarConnectionScreen | 2 hours |
| 5.3.6 Settings integration | 1 hour |
| 5.3.7 Provider/Screen integration | 3 hours |
| Google Cloud setup | 2 hours |
| Testing & debugging | 4 hours |
| **Total** | **~22 hours** |

---

## Phase 6: Time Slot Splitting & Predicted vs. Actual Time - Detailed Implementation

### Overview

Phase 6 introduces two powerful features that transform Signal/Noise from a simple scheduler into a dynamic, reality-aware productivity system:

1. **Time Slot Splitting**: Break large tasks into multiple scheduled blocks
2. **Predicted vs. Actual Time**: Calendar events evolve from predictions to reality

### Research-Backed Design Principles

Based on analysis of Sunsama, Motion, Reclaim.ai, Toggl, Clockify, and other leading productivity apps:

#### Key Principles (What Works)

| Principle | Why It Matters | Our Implementation |
|-----------|----------------|-------------------|
| **Link, Don't Duplicate** | Multiple blocks for one task should share parent ID | All TimeSlots reference parent SignalTask.id |
| **Preserve Planning Intent** | Never lose original plan when reality differs | Keep `plannedStartTime` separate from `actualStartTime` |
| **Make Variance Visible** | Show discrepancies prominently | Display "+15m late" badges, color-code over/under |
| **Progressive Commitment** | Allow partial scheduling now, more later | "X/Y hours scheduled" progress bar |
| **State-Based UI** | Clear visual differences between states | Different colors/styles for planned/active/completed/missed |
| **Reduce Rescheduling Friction** | Manual rescheduling kills plan adherence | Smart suggestions, one-tap reschedule |
| **24-Hour Grace Period** | Allow corrections for past events | Editable within 24h, then locked |

#### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Our Solution |
|--------------|---------|--------------|
| Overwriting history | Can't learn from estimation errors | Keep planned times, show both |
| No visual connection between splits | Splits look like separate tasks | Same color shade, linked badge |
| Forcing upfront decomposition | Extra work, doesn't match mental model | Ad-hoc splitting with retroactive grouping |
| No "remaining time" indicator | Users forget to block enough time | "X/Y hours scheduled" badge |
| Purely manual rescheduling | Plans become stale | Smart suggestions for missed slots |
| Past edits without audit trail | Data integrity issues | Lock after 24h grace period |

#### Competitive Reference: How Top Apps Handle This

**Sunsama** (Daily Planning Focus):
- Tasks have estimated durations, users "block time" on calendar multiple times
- Visual connection shows related blocks
- Daily shutdown ritual reviews planned vs. accomplished
- Automatic rollover of unfinished tasks

**Motion** (AI Automation):
- AI fragments tasks across multiple slots if needed
- Shows "estimated vs. scheduled" time on task cards
- Automatic re-shuffling when plans change
- Red warnings for "at risk" tasks past deadline

**Toggl Track** (Time Tracking):
- Clear split between planned (calendar) and tracked (timer) time
- Both exist simultaneously in UI
- Side-by-side comparison views
- "Copy event as time entry" to convert plan to actual

### 6.1 Time Slot Splitting

#### 6.1.1 Problem Statement

Users often have tasks that:
- Are too long for a single uninterrupted block (e.g., 3-hour study session)
- Need to be worked on across different parts of the day
- Have natural breakpoints (subtasks) that map to time blocks

Currently, a task with a 3-hour estimate must be scheduled as a single 3-hour block. Users need flexibility to split: "1 hour in the morning, 2 hours after lunch."

#### 6.1.2 Design Goals

1. **Intuitive**: Users should understand splitting immediately
2. **Flexible**: Split into any number of blocks, any durations
3. **Validated**: Total split time should equal estimated time
4. **Visual**: Clear indication of "scheduled" vs "remaining" time

#### 6.1.3 Data Model Changes

The existing `SignalTask` model already supports multiple `TimeSlot` entries. We need to track scheduling progress:

```dart
// Add to SignalTask model
class SignalTask extends HiveObject {
  // ... existing fields ...
  
  /// Total minutes already scheduled across all time slots
  int get scheduledMinutes {
    return timeSlots
        .where((slot) => !slot.isDiscarded)
        .fold<int>(0, (sum, slot) => sum + slot.plannedDuration.inMinutes);
  }
  
  /// Minutes remaining to be scheduled
  int get unscheduledMinutes {
    final remaining = estimatedMinutes - scheduledMinutes;
    return remaining > 0 ? remaining : 0;
  }
  
  /// Whether this task is fully scheduled
  bool get isFullyScheduled => unscheduledMinutes == 0;
  
  /// Whether this task is partially scheduled
  bool get isPartiallyScheduled => 
      timeSlots.isNotEmpty && unscheduledMinutes > 0;
  
  /// Percentage of estimated time that is scheduled
  double get scheduledPercentage {
    if (estimatedMinutes <= 0) return 0;
    return (scheduledMinutes / estimatedMinutes).clamp(0.0, 1.0);
  }
}
```

#### 6.1.4 UI Design: Split Scheduling Flow

**Scenario**: User has a 3-hour task "Study for CS Exam" and wants to schedule it across multiple blocks.

**Flow 1: Drag from Unscheduled List (Partial)**

1. User drags "Study for CS Exam (3h)" to 9:00 AM
2. **Split Dialog** appears:
   ```
   ┌─────────────────────────────────────────┐
   │  Schedule "Study for CS Exam"           │
   │                                         │
   │  Task total: 3h 0m                      │
   │  Already scheduled: 0m                  │
   │  Remaining: 3h 0m                       │
   │                                         │
   │  How long for this block?               │
   │  ┌─────────────────────────────────────┐│
   │  │  [1] hour  [0] minutes              ││
   │  └─────────────────────────────────────┘│
   │                                         │
   │  ○ Schedule remaining time (3h 0m)      │
   │  ● Schedule partial time               │
   │                                         │
   │  ┌─────────────┐  ┌───────────────────┐ │
   │  │   Cancel    │  │  Schedule 1h      │ │
   │  └─────────────┘  └───────────────────┘ │
   └─────────────────────────────────────────┘
   ```

3. User selects "1 hour" and confirms
4. Calendar shows 9:00-10:00 block
5. Task remains in "Needs Scheduling" with "(2h remaining)"

**Flow 2: Continue Scheduling Partially-Scheduled Task**

1. User drags "Study for CS Exam (2h remaining)" to 2:00 PM
2. **Split Dialog** shows:
   ```
   ┌─────────────────────────────────────────┐
   │  Schedule "Study for CS Exam"           │
   │                                         │
   │  Task total: 3h 0m                      │
   │  Already scheduled: 1h 0m (9:00-10:00)  │
   │  Remaining: 2h 0m                       │
   │                                         │
   │  How long for this block?               │
   │  ┌─────────────────────────────────────┐│
   │  │  [2] hour  [0] minutes              ││
   │  └─────────────────────────────────────┘│
   │                                         │
   │  ● Schedule remaining time (2h 0m)      │
   │  ○ Schedule partial time               │
   │                                         │
   │  ┌─────────────┐  ┌───────────────────┐ │
   │  │   Cancel    │  │  Schedule 2h      │ │
   │  └─────────────┘  └───────────────────┘ │
   └─────────────────────────────────────────┘
   ```

3. User confirms "Schedule remaining"
4. Task moves from "Needs Scheduling" to fully scheduled

#### 6.1.5 UI Design: Unscheduled Task Tile Updates

Update `_UnscheduledTaskTile` to show scheduling progress:

```dart
Widget _buildTileContent() {
  final isPartial = task.isPartiallyScheduled;
  final remainingText = isPartial 
      ? '${task.formattedUnscheduledTime} remaining'
      : task.formattedEstimatedTime;
  
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isPartial ? Colors.orange.shade200 : Colors.grey.shade200,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Color bar
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        remainingText,
                        style: TextStyle(
                          fontSize: 12,
                          color: isPartial 
                              ? Colors.orange.shade700 
                              : Colors.grey.shade500,
                          fontWeight: isPartial ? FontWeight.w500 : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.drag_indicator, color: Colors.grey.shade400),
          ],
        ),
        
        // Progress bar for partially scheduled tasks
        if (isPartial) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: task.scheduledPercentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(Colors.orange.shade400),
          ),
          const SizedBox(height: 4),
          Text(
            '${task.formattedScheduledTime} of ${task.formattedEstimatedTime} scheduled',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ],
    ),
  );
}
```

#### 6.1.6 Split Scheduling Dialog Widget

```dart
// lib/widgets/scheduling/split_schedule_dialog.dart

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
          Text(
            'Schedule "${widget.task.title}"',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
            title: Text('Schedule remaining time (${_formatMinutes(remaining)})'),
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
                    max: remaining ~/ 60,
                    onChanged: (val) => setState(() => _hours = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberPicker(
                    label: 'Minutes',
                    value: _minutes,
                    max: 59,
                    step: 15,
                    onChanged: (val) => setState(() => _minutes = val),
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
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isValidDuration
                      ? () => widget.onSchedule(Duration(minutes: _selectedMinutes))
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
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
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w600 : null,
              color: highlight ? Colors.black : Colors.grey.shade700,
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
        .map((s) => '${_formatTime(s.plannedStartTime)}-${_formatTime(s.plannedEndTime)}')
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
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
```

#### 6.1.7 Updated Initial Scheduling Screen Integration

```dart
// In _InitialSchedulingScreenState

Future<void> _scheduleTaskAt(SignalTask task, DateTime startTime) async {
  final roundedStart = _roundToNearestQuarterHour(startTime);
  
  // If task has remaining unscheduled time, show split dialog
  if (task.unscheduledMinutes > 0) {
    final duration = await _showSplitScheduleDialog(task, roundedStart);
    if (duration == null) return; // User cancelled
    
    await _createTimeSlot(task, roundedStart, duration);
  }
}

Future<Duration?> _showSplitScheduleDialog(
  SignalTask task,
  DateTime dropTime,
) async {
  return showModalBottomSheet<Duration>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SplitScheduleDialog(
        task: task,
        dropTime: dropTime,
        onCancel: () => Navigator.pop(context),
        onSchedule: (duration) => Navigator.pop(context, duration),
      ),
    ),
  );
}

Future<void> _createTimeSlot(
  SignalTask task,
  DateTime startTime,
  Duration duration,
) async {
  final provider = context.read<SignalTaskProvider>();
  final endTime = startTime.add(duration);
  
  final slot = TimeSlot(
    id: _uuid.v4(),
    plannedStartTime: startTime,
    plannedEndTime: endTime,
    linkedSubTaskIds: [],
  );
  
  await provider.addTimeSlotToTask(task.id, slot);
  _addEventToCalendar(task, startTime, endTime);
  setState(() {});
}
```

---

### 6.2 Predicted vs. Actual Time Handling

#### 6.2.1 Problem Statement

The current calendar system treats scheduled events as immutable predictions. In reality:

- Users don't always start exactly on time
- Sessions may run shorter or longer than planned
- The calendar should reflect what *actually happened*

This disconnect means:
- Google Calendar shows inaccurate historical data
- Users can't trust calendar history for time analysis
- The app feels "dumb" - it doesn't adapt to reality

#### 6.2.2 Design Philosophy

**Core Principle**: Future events are *predictions*; past events are *facts*.

| Time State | Event Behavior | Calendar Sync |
|------------|----------------|---------------|
| **Future** (hasn't started) | Freely movable, editable | Shows planned times (prediction) |
| **Active** (timer running) | Locked start time, live end | Updates on commitment threshold |
| **Past** (timer stopped) | Fully locked | Shows actual times (fact) |

#### 6.2.3 Commitment Threshold (Already Implemented)

The `TimeSlot` and `SignalTask` models already have:
- 5-minute threshold for tasks < 2 hours
- 10-minute threshold for tasks ≥ 2 hours

Only after crossing this threshold does the calendar event get created/updated.

#### 6.2.4 Enhanced TimeSlot Model

The current `TimeSlot` model is already well-designed with:
- `plannedStartTime` / `plannedEndTime` - The prediction
- `actualStartTime` / `actualEndTime` - The reality
- `sessionStartTime` - For calendar event spanning
- `hasSyncedToCalendar` - Track if we've synced

Add helper methods:

```dart
// Add to TimeSlot model

/// Whether this slot is in the future (not yet reached planned start time)
bool get isFuture => DateTime.now().isBefore(plannedStartTime);

/// Whether this slot is in the past (planned end time has passed)
bool get isPast => DateTime.now().isAfter(plannedEndTime) && !isActive;

/// Whether this slot is currently within its planned window
bool get isWithinPlannedWindow {
  final now = DateTime.now();
  return now.isAfter(plannedStartTime) && now.isBefore(plannedEndTime);
}

/// The times to show in calendar (actual if available, planned otherwise)
DateTime get calendarStartTime => actualStartTime ?? plannedStartTime;
DateTime get calendarEndTime => actualEndTime ?? plannedEndTime;

/// Whether actual times differ significantly from planned (> 5 min)
bool get actualDiffersFromPlanned {
  if (actualStartTime == null) return false;
  
  final startDiff = actualStartTime!.difference(plannedStartTime).abs();
  final endDiff = actualEndTime != null 
      ? actualEndTime!.difference(plannedEndTime).abs()
      : Duration.zero;
  
  return startDiff > const Duration(minutes: 5) || 
         endDiff > const Duration(minutes: 5);
}

/// Status for display purposes
TimeSlotStatus get displayStatus {
  if (isDiscarded) return TimeSlotStatus.discarded;
  if (isActive) return TimeSlotStatus.active;
  if (isCompleted) return TimeSlotStatus.completed;
  if (isFuture) return TimeSlotStatus.scheduled;
  if (isPast && !hasStarted) return TimeSlotStatus.missed;
  return TimeSlotStatus.scheduled;
}

enum TimeSlotStatus {
  scheduled,   // Future, not started
  active,      // Timer running
  completed,   // Timer stopped, has actual time
  missed,      // Past planned time, never started
  discarded,   // User discarded (didn't meet threshold)
}
```

#### 6.2.5 Calendar UI: Visual Distinction

Update the calendar event tile to show predicted vs. actual:

```dart
// In _buildEventTile for InitialSchedulingScreen

Widget _buildEventTile(
  List<CalendarEventData<SignalTask>> events,
  Rect boundary,
) {
  if (events.isEmpty) return const SizedBox.shrink();

  final event = events.first;
  final task = event.event;
  if (task == null) return const SizedBox.shrink();
  
  // Find the matching time slot
  final slot = task.timeSlots.firstWhere(
    (s) => s.plannedStartTime == event.startTime,
    orElse: () => task.timeSlots.first,
  );
  
  final status = slot.displayStatus;
  final color = event.color;
  final isSmallEvent = boundary.height < 30;
  
  // Visual indicators based on status
  final BorderSide leftBorder;
  final Color bgColor;
  
  switch (status) {
    case TimeSlotStatus.scheduled:
      // Future prediction - dashed border or lighter color
      bgColor = color.withOpacity(0.6);
      leftBorder = BorderSide(color: color, width: 3);
      break;
    case TimeSlotStatus.active:
      // Currently running - solid, bright
      bgColor = color.withOpacity(0.9);
      leftBorder = BorderSide(color: Colors.green, width: 4);
      break;
    case TimeSlotStatus.completed:
      // Past fact - solid, slightly muted
      bgColor = color.withOpacity(0.85);
      leftBorder = BorderSide(color: color, width: 3);
      break;
    case TimeSlotStatus.missed:
      // Missed - grayed out with warning indicator
      bgColor = Colors.grey.shade300;
      leftBorder = BorderSide(color: Colors.orange.shade400, width: 3);
      break;
    case TimeSlotStatus.discarded:
      // Shouldn't appear, but just in case
      return const SizedBox.shrink();
  }

  return GestureDetector(
    onTap: () => _onEventTap(events, event.date),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: leftBorder),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: isSmallEvent ? 2 : 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Status icon
              if (status == TimeSlotStatus.active)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              if (status == TimeSlotStatus.missed)
                Icon(
                  Icons.warning_amber_rounded,
                  size: 12,
                  color: Colors.orange.shade700,
                ),
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    color: _getContrastColor(bgColor),
                    fontSize: isSmallEvent ? 10 : 12,
                    fontWeight: FontWeight.w600,
                    decoration: status == TimeSlotStatus.missed 
                        ? TextDecoration.lineThrough 
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          // Show actual times if different from planned
          if (!isSmallEvent && slot.actualDiffersFromPlanned) ...[
            const SizedBox(height: 2),
            Text(
              'Actual: ${_formatTimeRange(slot.actualStartTime!, slot.actualEndTime!)}',
              style: TextStyle(
                color: _getContrastColor(bgColor).withOpacity(0.7),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

#### 6.2.6 Handling Missed Time Slots

When a user doesn't start a scheduled task, we need to handle it gracefully:

```dart
// In SignalTaskProvider

/// Check for missed time slots (past planned time, never started)
List<TimeSlot> getMissedTimeSlots(SignalTask task) {
  final now = DateTime.now();
  return task.timeSlots.where((slot) {
    return now.isAfter(slot.plannedEndTime) && 
           !slot.hasStarted && 
           !slot.isDiscarded;
  }).toList();
}

/// Handle a missed time slot
/// Options: Reschedule, Discard, or Keep (for later)
Future<void> handleMissedSlot(
  String taskId, 
  String slotId, 
  MissedSlotAction action,
) async {
  final task = getTask(taskId);
  if (task == null) return;
  
  final slotIndex = task.timeSlots.indexWhere((s) => s.id == slotId);
  if (slotIndex == -1) return;
  
  switch (action) {
    case MissedSlotAction.discard:
      // Mark as discarded, remove from calendar
      task.timeSlots[slotIndex] = task.timeSlots[slotIndex].copyWith(
        isDiscarded: true,
      );
      // Delete calendar event if exists
      if (task.timeSlots[slotIndex].googleCalendarEventId != null) {
        await _syncService.queueDeleteEvent(
          taskId: taskId,
          timeSlotId: slotId,
          googleCalendarEventId: task.timeSlots[slotIndex].googleCalendarEventId!,
        );
      }
      break;
      
    case MissedSlotAction.reschedule:
      // Remove the old slot (handled by UI showing reschedule dialog)
      task.timeSlots.removeAt(slotIndex);
      break;
      
    case MissedSlotAction.keepForLater:
      // Do nothing - slot stays, user will handle it
      break;
  }
  
  await saveTask(task);
  notifyListeners();
}

enum MissedSlotAction {
  discard,
  reschedule,
  keepForLater,
}
```

#### 6.2.7 Calendar Sync: Prediction to Reality Flow

```dart
// In SyncService - Enhanced event updates

/// Update calendar event from predicted to actual times
Future<void> syncActualTimesToCalendar({
  required SignalTask task,
  required TimeSlot slot,
}) async {
  if (!slot.hasSyncedToCalendar) return;
  if (slot.googleCalendarEventId == null) return;
  
  // Only sync if actual times are set and differ from planned
  if (!slot.actualDiffersFromPlanned) return;
  
  await queueUpdateEvent(
    task: task,
    slot: slot,
    googleCalendarEventId: slot.googleCalendarEventId!,
    // Use actual times instead of planned
    startTime: slot.actualStartTime!,
    endTime: slot.actualEndTime ?? DateTime.now(),
  );
}

/// Called when timer stops - syncs actual end time
Future<void> onTimerStopped({
  required SignalTask task,
  required TimeSlot slot,
}) async {
  // Check if we met commitment threshold
  if (!task.slotMeetsCommitmentThreshold(slot.id)) {
    // Discard - never sync to calendar
    return;
  }
  
  if (slot.googleCalendarEventId != null) {
    // Update existing event with actual times
    await syncActualTimesToCalendar(task: task, slot: slot);
  } else if (slot.hasSyncedToCalendar == false) {
    // Create event for first time (crossed threshold)
    await queueCreateEvent(
      task: task, 
      slot: slot,
      // Use actual times since that's what really happened
      startTime: slot.actualStartTime,
      endTime: slot.actualEndTime,
    );
    
    // Mark as synced
    slot.hasSyncedToCalendar = true;
  }
}
```

#### 6.2.8 Home Screen: Past Event Handling

Show a banner or section for missed scheduled tasks:

```dart
// In home_screen.dart

Widget _buildMissedTasksSection(List<SignalTask> tasksWithMissedSlots) {
  if (tasksWithMissedSlots.isEmpty) return const SizedBox.shrink();
  
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, size: 18, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(
              'Missed Time Slots',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tasksWithMissedSlots.map((task) {
          final missed = provider.getMissedTimeSlots(task);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(task.title),
            subtitle: Text(
              '${missed.length} slot${missed.length > 1 ? "s" : ""} missed',
            ),
            trailing: PopupMenuButton<MissedSlotAction>(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: MissedSlotAction.reschedule,
                  child: Text('Reschedule'),
                ),
                const PopupMenuItem(
                  value: MissedSlotAction.discard,
                  child: Text('Discard'),
                ),
                const PopupMenuItem(
                  value: MissedSlotAction.keepForLater,
                  child: Text('Keep for later'),
                ),
              ],
              onSelected: (action) {
                for (final slot in missed) {
                  provider.handleMissedSlot(task.id, slot.id, action);
                }
              },
            ),
          );
        }),
      ],
    ),
  );
}
```

---

### 6.3 Implementation Tasks

#### Phase 6.A: Time Slot Splitting (3-4 days)

- [ ] **6.A.1** Add `scheduledMinutes`, `unscheduledMinutes`, `isFullyScheduled`, `isPartiallyScheduled` to SignalTask model
- [ ] **6.A.2** Add `formattedScheduledTime`, `formattedUnscheduledTime` helper methods
- [ ] **6.A.3** Create `SplitScheduleDialog` widget
- [ ] **6.A.4** Update `_UnscheduledTaskTile` to show scheduling progress
- [ ] **6.A.5** Update `InitialSchedulingScreen._scheduleTaskAt` to show split dialog
- [ ] **6.A.6** Update "unscheduled" task filtering to include partially-scheduled tasks
- [ ] **6.A.7** Add validation that splits don't exceed remaining time
- [ ] **6.A.8** Run `build_runner` if model changes require it

**Testing Checkpoint**: 
- Can schedule a 3-hour task as 1h + 2h across different times
- Progress indicator shows on partially-scheduled tasks
- Can't schedule more than remaining time
- Task moves to "scheduled" only when fully allocated

#### Phase 6.B: Predicted vs. Actual Time (4-5 days)

- [ ] **6.B.1** Add `TimeSlotStatus` enum and `displayStatus` getter to TimeSlot
- [ ] **6.B.2** Add `isFuture`, `isPast`, `isWithinPlannedWindow` helpers
- [ ] **6.B.3** Add `calendarStartTime`, `calendarEndTime` helpers
- [ ] **6.B.4** Add `actualDiffersFromPlanned` helper
- [ ] **6.B.5** Update calendar event tile to show status-based styling
- [ ] **6.B.6** Implement missed slot detection in SignalTaskProvider
- [ ] **6.B.7** Create `handleMissedSlot` method with discard/reschedule options
- [ ] **6.B.8** Add missed tasks section to home screen
- [ ] **6.B.9** Update SyncService to sync actual times when timer stops
- [ ] **6.B.10** Update calendar event creation to use actual times when available

**Testing Checkpoint**:
- Future events appear with "scheduled" styling (lighter)
- Active events show green indicator
- Completed events show actual times if different
- Missed events show warning, offer reschedule/discard
- Calendar syncs actual times after timer stops

#### Phase 6.C: Integration & Polish (2 days)

- [ ] **6.C.1** End-to-end test: split scheduling → start timer → actual times sync
- [ ] **6.C.2** Edge case: day boundaries (task spans midnight)
- [ ] **6.C.3** Edge case: overlapping time slots
- [ ] **6.C.4** Accessibility review for new dialogs
- [ ] **6.C.5** Performance check with many split time slots
- [ ] **6.C.6** Update weekly stats to correctly count split tasks

---

### 6.4 Testing Checklist

#### Time Slot Splitting

- [ ] Can split a 3h task into 1h + 1h + 1h blocks
- [ ] Progress bar shows on partially-scheduled tasks
- [ ] Split dialog shows remaining time correctly
- [ ] Can't schedule more than remaining time
- [ ] Task shows in "unscheduled" until fully scheduled
- [ ] Multiple slots for same task appear correctly in calendar
- [ ] Deleting one slot updates remaining correctly
- [ ] Can reschedule individual split blocks

#### Predicted vs. Actual Time

- [ ] Future scheduled events are editable (drag to move)
- [ ] Active events are locked (can't move while timer runs)
- [ ] Past events show actual times if different from planned
- [ ] Missed slots show warning indicator
- [ ] Can discard, reschedule, or keep missed slots
- [ ] Calendar syncs actual start time when timer starts
- [ ] Calendar syncs actual end time when timer stops
- [ ] Event color/style changes based on status

---

### 6.5 Estimated Timeline

| Sub-task | Time |
|----------|------|
| 6.A.1-6.A.2 Model updates | 2 hours |
| 6.A.3 SplitScheduleDialog | 3 hours |
| 6.A.4-6.A.6 UI updates | 3 hours |
| 6.A.7-6.A.8 Validation & build | 1 hour |
| 6.B.1-6.B.4 TimeSlot model updates | 2 hours |
| 6.B.5 Calendar tile styling | 3 hours |
| 6.B.6-6.B.8 Missed slot handling | 4 hours |
| 6.B.9-6.B.10 Sync service updates | 3 hours |
| 6.C.1-6.C.6 Integration & polish | 4 hours |
| **Total** | **~25 hours** |
