## 2026-01-27 18:45 UTC
### TASKS COMPLETED
- Improved tag selector accessibility by expanding dropdown height and padding for keyboard visibility.
- Added keyboard dismissal behavior for custom time inputs and scrollable forms.
- Simulated Add Signal Task flow on iPhone 17 simulator and verified tag dropdown visibility plus custom time inputs.
### IN PROGRESS
- None.
### BLOCKERS
- iOS simulator build timed out via Xcode MCP (app launched from existing build).
### NEXT STEPS
- Re-run iOS simulator build to confirm the latest changes are compiled and installed.
- Smoke-test tag selection and custom time keyboard dismissal in onboarding and daily planning flows.

## 2026-01-27 10:00 UTC
### TASKS COMPLETED
- Added an Add to Signal flow for external Google Calendar events in the initial scheduling screen, including create-new-task and add-to-existing-task options.
- Updated the external event detail sheet to show the calendar name and Add to Signal action.
- Refreshes the calendar and marks external events as Signal after import.
### IN PROGRESS
- None.
### BLOCKERS
- None.
### NEXT STEPS
- QA: tap a Google Calendar event on the initial scheduling screen and verify both Add to Signal flows.
- Review PR #3.

## 2026-01-23 21:01 UTC
### TASKS COMPLETED
- Bumped app version to `2.0.1+2` in `pubspec.yaml` and aligned iOS build settings so the widget extension version matches the parent app.
- Generated a fresh TestFlight IPA at `build/TestFlight/Zen 80.ipa`.
### IN PROGRESS
- TestFlight upload (requires App Store Connect credentials via Xcode Organizer/Transporter).
### BLOCKERS
- The automated export step was failing because Xcode invoked `rsync` via `PATH` and picked up Homebrew rsync (3.4.1), which doesn’t support the `--extended-attributes` option used by Xcode’s packaging pipeline. For export we forced `PATH=/usr/bin:...` so it uses the system rsync.
### NEXT STEPS
- Upload `build/TestFlight/Zen 80.ipa` to App Store Connect (Transporter or Xcode Organizer) and wait for processing, then install from TestFlight.

## 2026-01-23 18:46 UTC
### TASKS COMPLETED
- Fixed calendar-linked sessions incorrectly merging across large gaps by enforcing the 15-minute merge threshold in `smartStartTask`.
- Removed the model-level exception that allowed resuming calendar-linked slots after the merge window, which could produce a single long block spanning multiple distinct calendar events.
- Added regression tests to ensure `startTimeSlot` throws when attempting to resume after the merge window (even if external-calendar-linked) and still resumes correctly within the window.
### IN PROGRESS
- None.
### BLOCKERS
- None.
### NEXT STEPS
- Run `flutter test` and verify the new tests pass.
- Manual repro: map two external GCal events ~1 hour apart to the same Signal, start each at their times, and confirm they render as two distinct blocks (not one spanning block).

## 2026-01-22 22:31 UTC
### TASKS COMPLETED
- Disabled iPad multitasking and aligned iPad orientations to portrait-only in the app plist to satisfy TestFlight validation requirements.
- Flattened all iOS app icon PNGs to remove alpha and avoid invalid icon errors during upload.
- Re-archived the Release build and exported a fresh TestFlight IPA using the updated app-store-connect export method.
### IN PROGRESS
- None.
### BLOCKERS
- None.
### NEXT STEPS
- Upload `build/TestFlight/Zen 80.ipa` via Xcode Organizer or Transporter to activate the TestFlight build.

## 2026-01-22 22:18 UTC
### TASKS COMPLETED
- Fixed the widget extension bundle identifier to match the new Zen80 app ID so the archive can validate (`com.lukebrevoort.zen80.SignalNoiseWidget`).
- Created `ios/ExportOptions.plist`, archived the Release build, and exported a TestFlight-ready IPA to `build/TestFlight`.
### IN PROGRESS
- None.
### BLOCKERS
- None.
### NEXT STEPS
- Upload the exported IPA to App Store Connect (Transporter or Xcode Organizer) and create the TestFlight build entry.

## 2026-01-22 22:12 UTC
### TASKS COMPLETED
- Built the Runner scheme for Luke’s iPhone using the new team ID and confirmed successful device build.
- Installed the Debug build on the device and launched the app (bundle com.lukebrevoort.zen80).
### IN PROGRESS
- None.
### BLOCKERS
- None.
### NEXT STEPS
- Prepare a Release archive suitable for TestFlight upload.
- If needed, switch signing to distribution cert/profile and validate export settings.

## 2026-01-22 21:05 UTC
### TASKS COMPLETED
- Inspected the iOS workspace and device list, confirmed the Runner scheme, and verified current signing settings (team Q5T8FJNX57, bundle ID com.lukebrevoort.zen80).
- Attempted a device build with Xcode MCP to surface build issues; build timed out before error output returned.
### IN PROGRESS
- Resolving device build failures for iPhone deployment and preparing TestFlight-ready release build.
### BLOCKERS
- Need confirmation of the correct Apple Developer Team ID and signing identity for the new account before adjusting project signing.
### NEXT STEPS
- Confirm the signing team, then retry device build and capture any errors for fixes.

## 2026-01-14 12:00 UTC
## 2026-01-22 20:10 UTC
### TASKS COMPLETED
- Crafted a `launch_logo.png` asset rendered with Newsreader SemiBold/Bold so the launch screen text matches the logo’s large black serif treatment with just a touch of greenery.
- Updated `ios/Runner/Base.lproj/LaunchScreen.storyboard` to center the new asset, keeping the palette high-contrast white/black with the green accent from the graphic.
- Registered Newsreader weights in `pubspec.yaml` so Flutter code has the same font family available elsewhere and added the asset catalog entry so the launch image is packaged.
### IN PROGRESS
- None.
### BLOCKERS
- None.
### NEXT STEPS
- Validate the refreshed launch screen on an iOS simulator/device to confirm the new graphic renders crisply across scales.

## 2026-01-15 18:48 UTC
### TASKS COMPLETED
- Updated app text, config, and docs so the experience now identifies as Zen 80 across iOS, Android, and supporting asset pipelines.
- Built a fresh iOS release and installed it on Luke’s iPhone (installation succeeded after retrying once when the device tunnel temporarily dropped).
### IN PROGRESS
- None.
### BLOCKERS
- None.
### NEXT STEPS
- Ask Luke to verify the refreshed branding and confirm the staged install.

### TASKS COMPLETED
- Updated the iOS launcher assets to use the Zen 80 logo for every required size and refreshed `Info.plist` so the app identifies itself as Zen 80.
- Ran `flutter build ios --no-codesign` to confirm the project still compiles with the new assets.

### IN PROGRESS
- None.

### BLOCKERS
- Personal iPhone installation still requires a codesigned build and device connection, which isn’t possible from this environment.

### NEXT STEPS
- Coordinate a local codesign + install workflow for the user’s iPhone when ready.

## 2026-01-14 12:45 UTC
### TASKS COMPLETED
- Ran `flutter build ios --release` to produce a fully signed binary ready for device deployment via Xcode.
- Highlighted that installation still requires the Xcode MCP tool and a local device connection because this environment can’t deploy to personal hardware.

### IN PROGRESS
- None.

### BLOCKERS
- Physical device installation still blocked until Xcode MCP is run on a machine with the user’s iPhone attached.

### NEXT STEPS
- Use Xcode MCP on Luke’s Mac to install the generated release build to the iPhone when he’s ready.

## 2026-01-14 13:10 UTC
### TASKS COMPLETED
- Replaced every launcher icon using the freshly rasterized `LOGO.png` straight from the supplied 1024×1024 `LOGO.svg`, keeping all dimensions in sync with iOS requirements.
- Re-ran `flutter build ios --release` so the release binary now includes the proportional Zen 80 logo for final deployment.
- Noted the remaining install step still depends on a local device via Xcode MCP.

### IN PROGRESS
- None.

### BLOCKERS
- Device install still pending until the release build is installed via Xcode MCP with the user’s iPhone attached.

### NEXT STEPS
- Use Xcode MCP on Luke’s Mac to install the latest release onto the iPhone when ready.

## 2026-01-14 13:48 UTC
### TASKS COMPLETED
- Discovered Luke's iPhone (ID: 00008120-000858A422E2601E) wirelessly via `flutter devices`.
- Set device session default and installed the signed release build onto the device using `xcodebuild_install_app_device`; installation succeeded with bundleID com.lukebrevoort.signalNoise.

### IN PROGRESS
- None.

### BLOCKERS
- None.

  ### NEXT STEPS
  - No immediate steps; Zen 80 app with proper logo branding is live on device and ready for user verification.

## 2026-01-19
### TASKS COMPLETED
- **Implemented Comprehensive Color Mapping for Google Calendar Events**
  - **Research**: Investigated Google Calendar ColorID system (1-11) and Signal's tag color palette (18 colors)
  - **Analysis**: Found critical gaps in existing `_hexToGoogleColorId()` function - only ~16 colors mapped, unmapped defaulted to Blueberry (9)
  - **Implementation**: Created complete mapping for all 18 Tag.colorOptions to Google Calendar ColorIDs:
    - Reds → Tomato (11)
    - Oranges → Tangerine (6)
    - Yellows/Ambers → Banana (5)
    - Greens/Limes/Emerald → Basil (10)
    - Teals/Cyans → Peacock (7)
    - Blues/Sky → Blueberry (9)
    - Purples/Indigos → Grape (3)
    - Pinks/Fuchsias → Flamingo (4)
    - Gray/Stone → Graphite (8)
  - **Fallback Algorithm**: Implemented RGB-based color matching for unmapped colors using Euclidean distance in RGB space
  - **Testing**: Created comprehensive test suite with 8 test cases covering all 18 tag colors
  - **Verification**: All tests passing ✅
  - **Files Modified**: 
    - `lib/services/sync_service.dart` - Enhanced `_hexToGoogleColorId()` with complete mapping + RGB fallback
    - Added `dart:math` and `flutter/material.dart` imports
    - Added public `hexToGoogleColorId()` wrapper for testing
    - Created `test/color_mapping_test.dart` with comprehensive test coverage

### IN PROGRESS
- None immediately. This work provides the foundation for the multi-calendar feature by ensuring proper color mapping.

### BLOCKERS
- None.

### NEXT STEPS
- Continue with multi-calendar feature implementation:
  - Investigate multi-calendar systems in Google Calendar API
  - Determine calendar strategy (separate "Signal" calendar vs user's primary calendar)
  - Update UI for multi-calendar selection
  - Implement multi-account support investigation

## 2026-01-20 00:15 UTC
### TASKS COMPLETED
- **Fixed "Centralize Notifications" Bug (High Priority)**
  - **Problem**: Notifications were scheduled based on planned tasks, not actual activity. Users got notifications for scheduled tasks they weren't working on (e.g., getting "Work" notifications while doing "Working Out").
  - **Root Cause**: NotificationService scheduled notifications for time slots without considering what task the user was actually working on.
  - **Solution**: Implemented smart centralized notification system with:
    1. **Activity-aware notification management**: New methods in NotificationService to track actual work
    2. **Dynamic notification cancellation**: Cancel notifications for tasks user isn't working on
    3. **Smart nudge system**: Only send nudge notifications when user is NOT doing any Signal task
    4. **Accurate time reporting**: Show actual time spent on tasks (not 0m)
  - **Implementation Details**:
    - Added `onTimerStarted()` and `onTimerStopped()` methods to NotificationService
    - Added `cancelAllScheduledTaskNotificationsExcept()` for activity-based notification management
    - Added `onTimerStart` and `onTimerStop` callbacks to SignalTaskProvider
    - Wired up callbacks in main.dart to NotificationService
    - Updated both `startTimeSlot()` and `smartStartTask()` methods to trigger notifications
    - Added comprehensive test suite for new notification methods
  - **Files Modified**:
    - `lib/services/notification_service.dart` - Added smart centralized notification methods
    - `lib/providers/signal_task_provider.dart` - Added onTimerStart/onTimerStop callbacks  
    - `lib/main.dart` - Wired up notification callbacks
    - `test/notification_service_test.dart` - Added comprehensive test coverage
  - **Testing**: All tests passing ✅
  - **Notion**: Updated bug status to "Under Review"

### IN PROGRESS
- None. Bug fix implementation complete and ready for review.

### BLOCKERS
- None.

### NEXT STEPS
- Await review approval for centralized notifications fix
- Continue with multi-calendar feature implementation after approval
- Potentially add more comprehensive integration tests for the notification system

## 2026-01-20 01:15 UTC
### TASKS COMPLETED
- **Fixed Critical Review Issues for "Centralize Notifications" Bug**
  
  **Review Feedback Addressed:**
  
  1. **✅ Fixed Backwards Logic in Notification Cancellation**
     - **Problem**: `_cancelNotificationsForOtherTasks()` was cancelling notifications for the ACTIVE task instead of OTHER tasks
     - **Solution**: Removed flawed method and implemented proper architecture:
       - Added `cancelNotificationsForInactiveTasks(List<SignalTask>, String)` method to NotificationService
       - Updated SignalTaskProvider integration to pass all tasks and active task ID
       - Moved cancellation logic to main.dart where we have access to all tasks
  
  2. **✅ Fixed Productivity Notification Time Display**
     - **Problem**: Productivity notifications showed 0m because they only used `accumulatedSeconds` which is 0 when timer just starts
     - **Solution**: Calculate total time including current session:
       ```dart
       final currentSessionTime = slot.actualStartTime != null && slot.isActive
           ? DateTime.now().difference(slot.actualStartTime!)
           : Duration.zero;
       final totalTime = Duration(seconds: slot.accumulatedSeconds) + currentSessionTime;
       ```
  
  3. **✅ Fixed Notification ID Collision**
     - **Problem**: Using `_taskAutoEndedBaseId + 1` created collision risk with actual auto-ended notifications
     - **Solution**: Added dedicated notification ID constants:
       - `_productivityNotificationId = 50` for positive reinforcement notifications
       - `_smartNudgeNotificationId = 55` for smart nudge notifications
  
  4. **✅ Fixed Race Condition in Notification Rescheduling**
     - **Problem**: `_rescheduleNotificationsForActiveTask()` could cause duplicate notifications by scheduling without cancelling old ones first
     - **Solution**: Added `await cancelSlotNotifications(slot.id)` before rescheduling:
       ```dart
       await cancelSlotNotifications(slot.id); // Cancel existing first
       await _scheduleSlotNotifications(...); // Then reschedule
       ```
  
  5. **✅ Removed Duplicate Code**
     - Removed duplicate `cancelAllScheduledTaskNotificationsExcept()` method that had same flawed logic
     - Simplified `_checkForNudgeNotification()` to use existing `_checkInactivity()` system
  
  6. **✅ Added Comprehensive Integration Tests**
     - Enhanced test coverage with 10 tests covering:
       - Method signatures and functionality
       - Time calculation logic (current session + accumulated)
       - Task notification management with multiple tasks
       - Edge cases (empty task lists, active/inactive states)
     - All tests passing ✅

**Files Modified:**
- `lib/services/notification_service.dart` - Core notification logic fixes
- `lib/providers/signal_task_provider.dart` - Updated callback integration
- `lib/main.dart` - Fixed timer start/stop handlers for proper notification management
- `test/notification_service_test.dart` - Comprehensive test suite

### IN PROGRESS
- None. All review issues have been addressed.

### BLOCKERS
- None.

### NEXT STEPS
- Request re-review from @reviewer to verify all critical issues are resolved
- Consider additional real-world integration testing
- Merge to main branch after final review approval

## 2026-01-21 19:45 UTC
### TASKS COMPLETED
- **Fixed Critical Bug: Duplicated Block When Continuing Signal**
  
  **Problem Identified:**
  When a user creates a signal with a Google Calendar event, starts the timer, lets it end automatically, then tries to continue the timer, the app creates a new duplicated timeslot instead of extending the existing one. This was marked as Critical priority (Jan 20, 2026).
  
  **Initial Fix & Crash Discovery:**
  First attempt only modified `signal_task_provider.dart` to allow resuming slots with calendar events after the merge window. However, this caused a **crash** because `startTimeSlot()` in `signal_task.dart` still threw `StateError` for gaps >= 15 minutes.
  
  **Complete Solution - Updated Both Files:**
  
  1. **lib/models/signal_task.dart** - Modified `startTimeSlot()` method (lines 309-340):
     - Added `canResumeCalendarSlot` condition to check for calendar events
     - Added third branch to allow resuming after merge window if slot has calendar event
     - Preserved original error behavior for regular slots (correct: create new slot)
     
     ```dart
     final bool canResumeCalendarSlot = !isFirstStart &&
         (slot.googleCalendarEventId != null || slot.externalCalendarEventId != null);
     
     if (isFirstStart) { ... }
     else if (isResumingWithinSession) { ... }
     else if (canResumeCalendarSlot) {
       // Resume after merge window but has calendar event - allow resume
       timeSlots[slotIndex] = slot.copyWith(
         actualStartTime: now,
         clearActualEndTime: true,
         isActive: true,
       );
     } else {
       throw StateError('Cannot resume slot after session merge threshold...');
     }
     ```
  
  2. **lib/providers/signal_task_provider.dart** - Updated `smartStartTask()` method (lines 628-635):
     - Enhanced resume logic to check for calendar events alongside merge window
     - Ensures both files handle calendar slot resumption consistently
     
     ```dart
     final shouldResumeSlot = lastSlot != null &&
         (lastSlot.canMergeSession ||
             (lastSlot.googleCalendarEventId != null ||
                 lastSlot.externalCalendarEventId != null));
     ```
  
  **Key Benefits:**
  - ✅ **No More Crashes**: Both files handle calendar slots consistently
  - ✅ **Prevents Duplicates**: Existing calendar events are extended rather than duplicated
  - ✅ **Preserves Logic**: Regular slots still create new slots after merge window (correct behavior)
  - ✅ **Comprehensive**: Works for both Signal-created and imported calendar events
  
  **Behavior Matrix:**
  | Scenario | Before Fix | After Fix |
  |----------|------------|-----------|
  | Resume within 15 min | ✅ Resume existing | ✅ Resume existing |
  | Resume after 15 min (no calendar) | ❌ Create new slot | ❌ Create new slot (correct) |
  | Resume after 15 min (with calendar) | 💥 Crash | ✅ Resume existing |
  | Ad-hoc start (no slot) | ✅ Create new slot | ✅ Create new slot |
  
  **Workflow:**
  1. ✅ Pulled open bugs from Notion Projects Database for Zen80 project
  2. ✅ Selected highest priority bug: "Duplicated Block" (Critical, Jan 20)
  3. ✅ Analyzed bug details and reproduction steps
  4. ✅ Created git branch: `fix/duplicated-block-when-continuing-signal`
  5. ✅ Created PR: https://github.com/lukebrevoort/Zen80/pull/2
  6. ✅ Initial implementation + discovered crash issue
  7. ✅ Updated both signal_task.dart and signal_task_provider.dart
  8. ✅ Added progress comments to PR with fix details
  9. ✅ Updated Notion task status to "Under Review" with PR link
  
  **Notion Update:**
  ✅ Task "Duplicated Block" status changed from "Open" to "Under Review"
  ✅ Added PR link: https://github.com/lukebrevoort/Zen80/pull/2
  
### IN PROGRESS
- None. Complete bug fix implementation ready for review.

### BLOCKERS
- None.

### NEXT STEPS
- Await review approval for duplicated block fix
- Consider additional real-world integration testing with Google Calendar
- Merge to main branch after final review approval

## 2026-01-21 19:30 UTC
### TASKS COMPLETED
- **Fixed Codex-Identified Issue: Notification Cleanup for Early Session Termination**
  
  **Problem Identified:**
  When a session is discarded or reset for failing the commitment threshold, `stopTimeSlot` returns before reaching the `onTimerStop` callback, leaving `NotificationService.onTimerStopped` never called. This causes:
  - `_isTimerActive` remains true
  - `cancelSlotNotifications` is skipped  
  - Inactivity nudges are suppressed
  - Stale "ending soon" notifications can fire after short/aborted sessions
  
  **Root Cause:**
  Two early returns in `stopTimeSlot()` at lines 881 and 912 happen BEFORE the `onTimerStop` callback at lines 935-938:
  1. **Line 881**: Ad-hoc session discarded for failing commitment threshold
  2. **Line 912**: Pre-scheduled slot reset for failing commitment threshold
  
  **Solution Implemented:**
  Added `onTimerStop?.call(task, slot)` BEFORE both early returns to ensure notification cleanup always runs:
  
  ```dart
  // Clean up notification state BEFORE discarding the session
  // This ensures _isTimerActive is reset and stale notifications are cancelled
  onTimerStop?.call(task, slot);
  ```
  
  **Files Modified:**
  - `lib/providers/signal_task_provider.dart` (+6 lines) - Added notification cleanup before early returns
  
  **Testing:**
  ✅ All 61 signal_task tests passing
  ✅ All 10 notification_service tests passing
  ✅ Full Flutter test suite passing (no regressions)

### IN PROGRESS
- None. All Codex issues have been addressed.

## 2026-01-27 00:00 UTC
### TASKS COMPLETED
- Stopped sending the productivity congratulation notification on timer start to avoid 0-minute messages
- Ensured auto-end notifications compute duration from the updated slot data

### IN PROGRESS
- None.

### BLOCKERS
- None.

### NEXT STEPS
- Verify auto-end notification timing and duration on device
