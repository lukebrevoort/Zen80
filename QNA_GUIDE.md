Okay, for my new APP, I need some help figuring out specifics and getting information on building an IOS app. I am building the app in Flutter and mainly making it with IOS in mind. The goal of the app is to have a way to be more productive using the 80/20 Signal Noise method, where at the start of your day, you designate 3-5 Signal mission-critical tasks and spend 80% of your time on those tasks. Anything other than your 3-5 tasks is considered noise, and only 20% of your time should be spent on those. The idea is to build the app to be as minimalistic as possible, here is the user Flow:

User downloads app -> User gets to understand the philosophy -> User is given the option to sign in with Google Calendar (Token stored in Local Phone Storage for privacy) -> User then designates 3-5 Signal Tasks for the day and assesses their Estimated time of Completion, the tasks can also be given Tags (Personal, School, Work and the ability to create your own tags) -> Then the app will layout on your daily calendar when you should work on completing these Signal Tasks, the user can then drag and drop the time slots to best fit when they would like to finish the tasks. This will sync with their google calendar to work around their schedule, also enabling them to include their current scheduled work into their signal. EX: My signal is to study for my CS Exam which should take 3 hours and I have a CS Class for an hour at 9am. I can click on this in the UI and designate it as Signal and attach it to this specific Class -> After the user has laid our their schedule, the app will notify them when they should begin on their signal task and when that timeslot has ended. Also enabling the user to manually change this as well.

How does this plan sound for the app and is it all possible? Ask me any follow up quewstions and lets get into the system design details!

-- Follow-up questions:

Reviewed 20 sources
How To Create Your First iOS Flutter App On MacOS trailer
How To Create Your First iOS Flutter App On MacOS Flutterflow Project: Build A Custom Calendar App trailer
Flutterflow Project: Build A Custom Calendar App
Daily Tasks Planner | Built an App Using Flutter Framework ... trailer
Daily Tasks Planner | Built an App Using Flutter Framework ...
Your app concept sounds very feasible and well-thought-out! The 80/20 Signal/Noise productivity method translates nicely into a mobile app, and Flutter is an excellent choice for building this with iOS as your primary target. All the core features you've outlined—Google Calendar integration, local token storage, drag-and-drop scheduling, notifications, and tagging—are completely achievable with Flutter's ecosystem.
​
​

Technical Feasibility
The Google Calendar API integration is well-supported in Flutter through the googleapis package, and you can implement OAuth2 authentication to allow users to sign in and sync their calendars. For secure token storage, the flutter_secure_storage package uses iOS Keychain (and Android Keystore) to encrypt and store sensitive data like OAuth tokens locally on the device, which aligns perfectly with your privacy goals.
​
​

For the calendar UI, packages like Syncfusion Flutter Calendar or custom implementations can handle the drag-and-drop functionality, displaying Signal tasks alongside existing Google Calendar events. The ability to designate existing calendar events as "Signal" (like your CS class example) can be implemented by linking those events to specific Signal tasks through metadata.
​

Follow-up Questions
Before diving into system design, I have a few clarifying questions:

Data persistence: Beyond Google Calendar sync, do you want Signal tasks and user preferences (tags, task history, completion stats) stored locally on the device, in a cloud database, or both? This affects offline functionality and cross-device sync.

Notification logic: Should the app send reminders at the start of each Signal time block, or also include warnings (e.g., "5 minutes until your Signal task ends")? Do you want tracking features to measure actual time spent vs. estimated time?

Calendar write permissions: When users schedule Signal tasks, should the app create actual Google Calendar events, or just display them in the app's UI? Writing to Google Calendar would make tasks visible in other calendar apps but requires additional permissions.

Onboarding flow: For the philosophy explanation step, are you thinking of interactive tutorials, static screens with illustrations, or a brief video? This impacts the initial user experience design.

Tags and categorization: You mentioned Personal, School, Work tags. Should these have different visual treatments (colors, icons) in the calendar view? Can multiple tags be applied to a single task?

Let me know your thoughts on these, and we can start mapping out the system architecture, data models, and component breakdown!

-- Answers to the follow up questions:

These are just fantastic questions. Let me answer them:

Data: For data, we will store all data on the device. Remember, this app should be minimalist. We will do a week in review, so at the end of the week or in a history menu, you can see your average ratio (Signal to Noise), how many tasks you completed in Signal this week, as well as for specific tags, how much time you spent on each tag.g
Notification: The app should send reminders at the start and close to the end. The idea was that before a task begins, the user must physically click a start button to begin the task. The task will automatically end when the time slot has concluded, but the user can manually begin this signal task again if they so desire. We will also have settings like "Auto Start" and "Auto Stop" for users if they so wish, but by default, we want a user to be very intentional when starting a signal task and continuing it.
Calendar Write: Yes, we would write to the calendar and also make changes to the calendar if a user is continuing their task. So, let's say from 8-9 am I had planned to study for my Exam. I start the task at 8:03 am and then continue the task until 10 am. Once I officially end the timer, we will update the calendar event in their Google Calendar to be from 8:03 am to 10 am instead of 8 am to 9 am.
Onboarding: It should be a philosophy explanation and then an initial walkthrough of how each step works, something pretty simple with illustrations
Tags: The tags would have colors and would be visible to the user as colors. Something similar to the Notion Status Tags, where you can add multiple tags. Instead of doing something like sub tags, let's say I have a School tag but also a CS Class Tag, my task is studying for the CS Exam, so both would be added to this signal. It would also count for both the total time in our weekly review.s

Another feature could also be adding sub-signal tasks, which would just be there to organize things for a user. The idea of the app is to give users options to stay organized, but never require anything

Let me know if there are any more questions

-- More Questions to clarify before system design:
1 step completed
Perfect! Your answers clarify a lot and confirm this is a very achievable scope. The minimalist, intentional design philosophy is strong—especially the manual start/stop by default and the flexible organization features. Let me address a few more critical technical and design questions before we dive into system architecture:

Technical Clarifications
Google Calendar event management: When you write Signal tasks to Google Calendar, should they be created as a specific type (like using a custom calendar, or color-coding them)? This would help users visually distinguish Signal tasks from regular events in other calendar apps. Also, when a user marks an existing calendar event (like your CS class) as Signal, should that modify the original event or create a linked reference?

Local database structure: Since everything is stored locally, what should happen if a user uninstalls/reinstalls the app? Should they lose all historical data, or would you want a backup/export feature (like exporting weekly reviews as PDFs or CSV)? Also, for the weekly review ratio calculations—should "Noise" time be manually logged by users, or automatically calculated as "everything outside Signal tasks"?

Time tracking edge cases: If a user starts a Signal task late (8:03 instead of 8:00) but then switches to a different Signal task before the original ends, how should the app handle this? Should it auto-stop the first task, prompt the user, or allow overlapping Signal tasks?

Multi-day Signal tasks: Can a Signal task span multiple days (e.g., "Work on project: 3 hours" split across Monday and Tuesday), or are all Signal tasks scoped to a single day? This affects how you handle task creation and scheduling.

Tag time allocation: For the weekly review showing time spent per tag—if a task has multiple tags (School + CS Class), does the full task duration count toward both tags' totals? Just want to confirm the counting logic.

Design & UX Questions
Philosophy explanation screen: Should this be shown every time the app opens until dismissed, or just once during first launch? Some users might want to revisit the methodology explanation later.

Sub-signal tasks: You mentioned these are optional organizational tools. Should sub-tasks have their own time estimates that roll up into the parent Signal task, or are they just checklist items without time tracking?

Calendar view flexibility: Should users see a daily view by default, or have options for weekly/monthly views? For drag-and-drop rescheduling, I'm assuming daily view makes most sense—confirm?

Noise tasks: You mentioned 20% should be spent on Noise. Should the app have a dedicated "Noise task" feature where users can log non-Signal work, or is Noise simply "any time not in Signal" calculated passively?

Once you clarify these, I can lay out the complete system design including data models, component architecture, state management approach, and API integration flow!

-- Answers to the follow up questions:

Google Calendar event management: I would ideally just color-code, but a custom calendar would be really convenient if possible. We want the user to easily differentiate them visually since anything else in their calendar is considered Noise. Then, when we mark something in my calendar as Signal, we would just change the color or create a reference. Whatever we differentiate, we would change the event, just edit the thought, not rewrite

Local database structure: We can add a backup/export feature for sure, just incase for sure. Then for the ratio calculation let's from, Steve Jobs.For we want trust, from the 9ust system. Unless you have designated something as a signal, it is noise. This will also be taken into account for when the user considers their "Working Hours. or Focus" By default it is 18 hours for steve jobs, but we will be more generous and say 16 hours (8 for sleep). This can be changed for users if they so please

Time tracking edge cases: It should prompt the user that their signal for the first task is about to end, then the user, if they want to continue on task 1, can manually continue the task. From, let's from,want trust, from 9 am,11 am2 pmit's,auto-end, Let's atthe Let'sat,,0-trust example lets say I have two signal tasks back to back, at 9am to 11 am I want to work on fixing a bug on my website and from 11am to 2p, 11 amm I need to study for my CS Exam. If I am on a roll on fixing this bug and its 11 am, the user can manually continue this task and cut into the CS Exam time. If the user manually continues a task the task will NOT auto end. Then when the user does complete this time, they can end and start the CS Exam. Lets say the user is done with the bug as 11:30 and starts the CS Exam, which cuts into their time, then it is on the user to make up that time.

Multi-day Signal task: YES! So if the user doesn't mark the task as complete OR the time the user spent on the task is not close to the ETC, then that task will ROLL OVER to the next day as a suggestion with the time remaining. In our example before, since we only spent 1.5 hours studying for the CS Exam instead of 2 hours, I didn't fully study. So the next day, the app will suggest adding CS Exam for 30 minutes to make up the sum to complete the task. I could, deny this suggestion and say I forgot to mark as complete, or take the suggestion and change it, maybe I actually want an hour instead of 30 minutes.

Tag time allocation: Yes it will count towards both. So school maybe has 5 hours this week and CS is 0, then we study for the exam with both tags for 2 hours, then numbers bump to School with 7 hours and CS with 2.

Philosophy explanation screen: Just on front launch, but you can always have the methodology explained in the settings

Sub-signal tasks: They are seen purely as checklist items that can be assigned to time slots. So if I have a big task like FINISH WEBSITE this is a big task that will take 5 hours today. I can create sub tasks (finish hero section, add user login, fix UI bug, ect.) Then when choosing where I want to place this into my calendar, I can attach a subtask (or multiple) to a certian time.

Calendar view flexibility: Steve Jobs beleived in the short-term high-leverage focus, you only get to see today. So just daily view, if a user wants to see their full schedule they can check their calendar app. But the goal is to fucus really hard on a single day.

Noise tasks: I thought about this a lot but realized its not worth it and not reliable, Users won't admit that they spent a lot of time binging youtube or netflix in a day. Just always assume anything not signal is just noise.

-- More Follow Up questions:
Reviewed 20 sources
System Architecture Overview
Based on your requirements, here's the complete technical breakdown:

Data Layer
Local Database: Isar or Hive
​
For your use case, I recommend Isar (or Hive as a close second) over SQLite because:

Performance: Isar and Hive are significantly faster for read-heavy operations, which is critical for displaying daily schedules and calculating weekly stats
​

Schemaless flexibility: Perfect for your tag system and sub-tasks where structure might evolve
​

Type-safe: Both offer strong typing without SQL boilerplate ​

Lightweight: Minimal overhead for a minimalist app philosophy
​

SQLite would be overkill since you don't need complex relational queries or transactions.
​

Core Data Models
text
SignalTask {
id: String (UUID)
title: String
estimatedDuration: int (minutes)
actualDuration: int (minutes, tracked)
tags: List<Tag>
subTasks: List<SubTask>
status: enum (NotStarted, InProgress, Completed, Rolled)
scheduledDate: DateTime
timeSlots: List<TimeSlot>
googleCalendarEventId: String? (for sync)
isComplete: bool
createdAt: DateTime
}

TimeSlot {
id: String
startTime: DateTime
endTime: DateTime
actualStartTime: DateTime?
actualEndTime: DateTime?
isActive: bool
autoEnd: bool (default true per user settings)
}

Tag {
id: String
name: String
color: Color (hex)
isDefault: bool (Personal, School, Work)
}

SubTask {
id: String
title: String
isChecked: bool
linkedTimeSlotIds: List<String>
}

WeeklyStats {
weekStartDate: DateTime
totalSignalMinutes: int
totalNoiseMinutes: int (calculated: focusHours*60*7 - totalSignalMinutes)
signalNoiseRatio: double
completedTasksCount: int
tagBreakdown: Map<String, int> (tagId -> minutes)
}

UserSettings {
focusHoursPerDay: int (default 16)
autoStartTasks: bool (default false)
autoEndTasks: bool (default true)
notificationBeforeEnd: int (minutes, default 5)
hasCompletedOnboarding: bool
}
State Management
Riverpod
​
I strongly recommend Riverpod over Bloc for this project because:

Simpler for your scope: Your app doesn't need the heavy event-driven architecture Bloc provides
​

Better for UI reactivity: Calendar drag-and-drop, live timers, and dynamic task updates benefit from Riverpod's fine-grained reactivity
​

Easier testing: Riverpod's provider-based system is cleaner for unit testing task logic
​

Less boilerplate: You'll write significantly less code for state management
​

Bloc would be better for complex apps with intricate business logic flows, but Riverpod fits your minimalist philosophy better.
​

Google Calendar Integration
Package: googleapis (for Calendar API) + google_sign_in (for OAuth)

Flow:

User authenticates via Google Sign-In

Store OAuth refresh token using flutter_secure_storage (iOS Keychain)
​

Fetch user's primary calendar events on app launch

Create a custom calendar named "Signal Tasks" for visual separation:

Use calendar.insert() to create a dedicated calendar

All Signal tasks written as events to this calendar with custom color-coding

When user marks existing event as Signal, update event's calendar reference or color via calendar.events.patch()

Sync changes bidirectionally:

When user drags/drops in app → update Google Calendar event times

When user continues/extends task → patch event with new start/end times

Listen for external calendar changes (optional: periodic polling or webhooks)

Notifications
Package: flutter_local_notifications
​

Implementation:
​

Schedule notifications when user finalizes daily schedule

Start notification: "Time to begin [Task Name]" → Tapping opens app to manual start button

End warning: "[Task Name] ending in 5 minutes" → User can continue or let auto-end

Background handling: Use iOS background modes for notification scheduling even when app is closed
​

Key iOS permissions needed:

Calendar read/write

Notification permissions

Background fetch (for notification scheduling)

UI Components
Core Screens
Onboarding Flow:

Philosophy explanation (3-4 illustrated slides)

Interactive walkthrough (mock Signal task creation)

Google Calendar connection prompt

Main Daily View:

Top: Date header, Signal/Noise ratio indicator (ring chart showing 80/20 target)

Middle: Vertical timeline (8am-midnight) with:

Signal tasks (color-coded by tags, draggable)

Grayed-out existing calendar events (tappable to convert to Signal)

Empty slots (implicit Noise time)

Bottom: Floating action button to add new Signal task

Task Creation/Edit:

Title input

Time estimate slider (15min increments)

Multi-tag selector (Notion-style chips)

Optional sub-tasks (expandable section)

"Schedule" button → returns to daily view with task added

Active Task View (when Signal is running):

Full-screen timer display

Current sub-tasks checklist

"Continue Task" and "End Task" buttons

Pause/resume functionality

Weekly Review:

Bar chart: Daily Signal vs Noise breakdown

Stats cards: Total Signal hours, completed tasks, average ratio

Tag breakdown: Horizontal bars showing time per tag

Export button (CSV/PDF with weekly summary)

Technical Implementation Details
Time Tracking Logic
Task Continuation Flow:

text

1. User has Task A (9-11am) and Task B (11am-2pm)
2. At 11am, notification fires: "Task A ending in 5 min"
3. If user clicks "Continue":
   - Disable auto-end for Task A
   - Keep timer running past 11am
   - Task B remains scheduled but inactive
4. User manually ends Task A at 11:30am:
   - Update actualEndTime in TimeSlot
   - Patch Google Calendar event (9am → 11:30am)
   - User can now start Task B (with 30min deficit)
     Rollover Logic
     Daily Calculation (runs at midnight or on app open next day):

text
For each SignalTask from previous day:
if status != Completed AND actualDuration < estimatedDuration \* 0.9:
remainingTime = estimatedDuration - actualDuration
Create suggestion: "Continue [Task] for [remainingTime]?"
User can: - Accept → Add to today's Signal with remainingTime - Adjust → Modify time and add - Mark Complete → Archive task - Dismiss → Archive as incomplete
Weekly Stats Calculation
Runs every Sunday at midnight or on-demand:

text
totalSignalMinutes = sum(all actualDuration for week)
focusMinutes = userSettings.focusHoursPerDay _ 60 _ 7
totalNoiseMinutes = focusMinutes - totalSignalMinutes
signalNoiseRatio = totalSignalMinutes / focusMinutes

For each tag:
tagMinutes[tag] = sum(actualDuration for tasks with tag)
// If task has multiple tags, full duration counts for each
Architecture Layers
text
Presentation Layer (UI)
↓
Riverpod Providers (State Management)
↓
Repository Layer (Business Logic)
↓
Data Sources:

- Local DB (Isar/Hive)
- Google Calendar API
- Secure Storage (tokens)
- Local Notifications
  Key Technical Challenges & Solutions
  Challenge 1: Keeping Google Calendar in sync with local changes

Solution: Implement optimistic updates (update local DB first, then sync to Calendar in background). Queue failed syncs for retry.

Challenge 2: Accurate background notifications when app is terminated

Solution: Schedule all day's notifications when user finalizes schedule. Use iOS notification scheduling with precise delivery times.
​

Challenge 3: Drag-and-drop calendar UI performance

Solution: Use flutter_calendar_view or custom DragTarget/Draggable widgets with Riverpod for reactive updates. Debounce Google Calendar writes until user releases drag.

Challenge 4: Handling timezone changes (user travels)

Solution: Store all times in UTC, convert to local timezone on display. Google Calendar handles timezone conversion automatically.

Development Roadmap
Phase 1: Core MVP (3-4 weeks)

Local task creation/storage (Isar)

Daily calendar view with manual scheduling

Basic timer/tracking functionality

Local notifications

Phase 2: Calendar Integration (2-3 weeks)

Google Sign-In + OAuth

Calendar read/write functionality

Sync logic for Signal tasks

Marking existing events as Signal

Phase 3: Advanced Features (2-3 weeks)

Drag-and-drop UI

Sub-tasks functionality

Tag system with custom colors

Task rollover logic

Phase 4: Analytics & Polish (1-2 weeks)

Weekly review calculations

Data export (CSV/PDF)

Backup/restore functionality

Onboarding flow with illustrations

Total estimated timeline: 8-12 weeks for full MVP

Questions for Next Steps
Custom calendar vs color-coding: Creating a custom "Signal Tasks" calendar is definitely possible and would provide the cleanest separation. Should users be able to toggle whether Signal tasks appear in their primary calendar too, or only in the custom calendar?

Backup/export timing: Should backup be automatic (daily/weekly to device storage) or manual only? For export, would you want a simple JSON backup file, or formatted reports (PDF with charts for weekly reviews)?

Onboarding skip: Should users be able to skip Google Calendar integration initially and use the app as a standalone scheduler, then add Calendar sync later in settings?

Let me know if you want me to dive deeper into any specific component—like the exact Riverpod provider structure, detailed Google Calendar API calls, or UI wireframes for the main screens!
