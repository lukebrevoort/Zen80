# Signal/Noise Calendar Sync & Timing Design

> **Purpose:** This document defines how time tracking, Google Calendar sync, and session management work in Signal/Noise. All agents should reference this for timing-related decisions.

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Calendar Sync Lifecycle](#calendar-sync-lifecycle)
3. [Session Management](#session-management)
4. [Edge Cases & Handling](#edge-cases--handling)
5. [Key Decision Log](#key-decision-log)

---

## Core Concepts

### The Two Truths

Signal/Noise tracks two different "truths" about time:

| Truth       | What It Represents                        | Fields                                                 |
| ----------- | ----------------------------------------- | ------------------------------------------------------ |
| **Plan**    | User's intention (what they scheduled)    | `plannedStartTime`, `plannedEndTime`                   |
| **Reality** | What actually happened (when they worked) | `actualStartTime`, `actualEndTime`, `sessionStartTime` |

**Key Principle:** Google Calendar shows what the user **accomplished**, not what they planned. Planning history is preserved in the app's analytics tab.

### Time Fields Glossary

| Field                | Set When                  | Purpose                                               |
| -------------------- | ------------------------- | ----------------------------------------------------- |
| `plannedStartTime`   | Slot created (scheduling) | The intended start time                               |
| `plannedEndTime`     | Slot created (scheduling) | The intended end time                                 |
| `actualStartTime`    | Timer starts              | When user began the current work segment              |
| `actualEndTime`      | Timer stops               | When user ended the current work segment              |
| `sessionStartTime`   | First timer start         | Start of the entire session (preserved across merges) |
| `lastStopTime`       | Timer stops               | Used to calculate merge window                        |
| `accumulatedSeconds` | Timer stops               | Total seconds worked across all segments              |

### Key Constants

```dart
sessionMergeThreshold = Duration(minutes: 15);     // Gaps < 15 min = same session
shortTaskCommitmentThreshold = Duration(minutes: 5);   // Tasks < 2 hours
longTaskCommitmentThreshold = Duration(minutes: 10);   // Tasks >= 2 hours
```

---

## Calendar Sync Lifecycle

### Phase 1: Morning Planning (Initial Scheduling Screen)

**Trigger:** User clicks "Start My Day" after scheduling all tasks

**Action:** Batch sync all scheduled time slots to Google Calendar

**Event Created:**

```
Start: plannedStartTime
End: plannedEndTime
Title: Task title
Status: PLANNED
```

**Rules:**

- Events are only created when user commits via "Start My Day"
- Reschedules during planning don't trigger individual syncs
- Each slot stores `googleCalendarEventId` after creation

---

### Phase 2: During Work (Active Session)

**Calendar Event Display Rules:**

| State                       | Calendar Shows                        | When                                         |
| --------------------------- | ------------------------------------- | -------------------------------------------- |
| Active, within planned time | `actualStartTime` → `plannedEndTime`  | User is working, hasn't exceeded planned end |
| Active, overtime            | `actualStartTime` → `DateTime.now()`  | User is working past `plannedEndTime`        |
| Paused, within merge window | `sessionStartTime` → `plannedEndTime` | User stopped but could resume (< 15 min)     |

**Update Triggers:**

- On timer start: Update event start to `actualStartTime`
- On crossing `plannedEndTime` while active: Switch to overtime mode
- On timer stop: Update end time (but keep blended until finalized)

**Overtime Updates:**

- Update end time periodically (every 1-5 min) or only on stop
- Avoid hammering API with per-second updates

---

### Phase 3: Session Finalization

**A session is "finalized" when BOTH conditions are true:**

1. `now > plannedEndTime + 15 minutes`
2. `now > lastStopTime + 15 minutes` (merge window expired)

**Why both?**

- Condition 1 alone would finalize while user is still working overtime
- Condition 2 alone would finalize a session that ended early, even if there's still planned time

**On Finalization:**

```
Start: sessionStartTime (captures full session including merged segments)
End: actualEndTime (the real end time)
```

---

### Phase 4: Missed Slots

**Definition:** A slot is "missed" when:

- `now > plannedEndTime + 15 minutes`
- User never started working (`sessionStartTime == null`)
- Slot is not discarded

**Action:** DELETE the Google Calendar event

**Rationale:** Calendar should show what user accomplished, not what they missed. Planning history is preserved in app analytics.

---

### Phase 5: Ad-hoc Sessions (Unscheduled Work)

**Definition:** User starts a timer without a pre-scheduled slot

**Calendar Sync Rules:**

- Do NOT create calendar event immediately
- Create event only after commitment threshold is met:
  - 5 minutes for tasks < 2 hours estimated
  - 10 minutes for tasks >= 2 hours estimated
- If user stops before threshold: no calendar event created (session discarded)

**Event Created:**

```
Start: sessionStartTime
End: actualEndTime (or now if still active)
```

---

## Session Management

### Session Merging

**Rule:** If user resumes within 15 minutes of stopping, it's the same session.

**What gets preserved:**

- `sessionStartTime` (original start of the session)
- `accumulatedSeconds` (total work time)

**What gets updated:**

- `actualStartTime` (new segment start)
- `isActive` (set to true)

**Calendar Impact:**

- Single event spans from `sessionStartTime` to `actualEndTime`
- Breaks < 15 min are "hidden" in the calendar (shows continuous block)

### Session States

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TIME SLOT STATES                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SCHEDULED ──────► ACTIVE ──────► COMPLETED ──────► FINALIZED      │
│      │                │               │                             │
│      │                │               ▼                             │
│      │                │         (within merge)                      │
│      │                │               │                             │
│      │                ◄───────────────┘                             │
│      │                      resume                                  │
│      │                                                              │
│      ▼                                                              │
│   MISSED ─────────────────────────────────────────► (deleted)      │
│  (never started,                                                    │
│   past planned end)                                                 │
│                                                                     │
│   DISCARDED                                                         │
│  (user cancelled,                                                   │
│   or didn't meet threshold)                                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Commitment Threshold

**Purpose:** Prevent "calendar pollution" from abandoned sessions

**Rules:**

- Short tasks (< 2 hours): Must work at least 5 minutes
- Long tasks (>= 2 hours): Must work at least 10 minutes
- Sessions under threshold are DISCARDED (no calendar event)

**Applies to:**

- Ad-hoc sessions (unscheduled work)
- Does NOT apply to pre-scheduled slots (they already have calendar events from "Start My Day")

---

## Edge Cases & Handling

### 1. Early Start

**Scenario:** Plan is 2-3 PM, user starts at 1:30 PM

**Calendar Evolution:**

- Morning: `2:00 → 3:00` (planned)
- 1:30 PM start: `1:30 → 3:00` (actual start, planned end)
- 2:30 PM stop: `1:30 → 3:00` (still blended, merge window open)
- 3:15 PM finalize: `1:30 → 2:30` (actual times)

---

### 2. Late Start + Overtime

**Scenario:** Plan is 2-3 PM, user starts at 2:30 PM, works until 3:30 PM

**Calendar Evolution:**

- Morning: `2:00 → 3:00` (planned)
- 2:30 PM start: `2:30 → 3:00` (actual start, planned end)
- 3:00 PM (overtime): `2:30 → now` (growing)
- 3:30 PM stop: `2:30 → 3:30` (actual)
- 3:45 PM finalize: `2:30 → 3:30` (confirmed actual)

**Important:** Do NOT finalize at 3:15 (planned+15) because user is still working!

---

### 3. Merged Session

**Scenario:** Plan is 2-3 PM, user works 1:30-2:00, pauses, resumes 2:10-3:00

**Calendar Evolution:**

- Morning: `2:00 → 3:00`
- 1:30 PM start: `1:30 → 3:00`
- 2:00 PM pause: `1:30 → 3:00` (merge window open until 2:15)
- 2:10 PM resume: `1:30 → 3:00` (same session continues)
- 3:00 PM stop: `1:30 → 3:00`
- 3:15 PM finalize: `1:30 → 3:00` (actual times - break is hidden)

**Note:** The 10-minute break is not visible in calendar. This is intentional - we show "presence window" not individual segments.

---

### 4. Multiple Sessions (Gap > 15 min)

**Scenario:** Plan is 2-3 PM, user works 2:00-2:15, gap, works 2:40-3:00

**Calendar Evolution:**

- Morning: `2:00 → 3:00`
- 2:00 PM start: `2:00 → 3:00`
- 2:15 PM stop: `2:00 → 3:00` (merge window open until 2:30)
- 2:30 PM merge expires: `2:00 → 2:15` (first session finalized, but wait for planned end)
- 2:40 PM start: This is a NEW session (gap > 15 min)
  - First slot now finalized: `2:00 → 2:15`
  - But what about 2:40? This work happens within the PLANNED slot timeframe...

**Design Decision Needed:** When user starts work after merge window expired but still within planned slot:

- Option A: Create new ad-hoc calendar event (requires commitment threshold)
- Option B: Re-activate the original slot's calendar event
- **Current Choice: Option A** - The first session is done, new work is ad-hoc

---

### 5. Slot Missed Entirely

**Scenario:** Plan is 2-3 PM, it's now 3:30 PM, user never started

**Calendar Evolution:**

- Morning: `2:00 → 3:00`
- 3:15 PM (planned + 15): Event DELETED from Google Calendar
- App shows slot as "missed" in UI

---

### 6. Partial Work Then Abandoned

**Scenario:** Plan is 2-3 PM, user works 2:00-2:15, never resumes, now 4:00 PM

**Calendar Evolution:**

- Morning: `2:00 → 3:00`
- 2:00 PM start: `2:00 → 3:00`
- 2:15 PM stop: `2:00 → 3:00` (merge window open)
- 2:30 PM merge expires: Could finalize first session, but planned end not reached yet
- 3:15 PM (planned + 15, merge + 15 both passed): `2:00 → 2:15` (finalized)

---

### 7. Overlapping Tasks

**Scenario:** Task A 2-3 PM, Task B 3-4 PM. User starts A at 2:45, works until 3:15

**Calendar:**

- Morning: A = `2:00 → 3:00`, B = `3:00 → 4:00`
- 2:45 PM start A: A = `2:45 → 3:00`
- 3:00 PM overtime: A = `2:45 → now`
- 3:15 PM stop A: A = `2:45 → 3:15`

**Task B:** Remains `3:00 → 4:00` until user interacts with it

- If user starts B later: Normal flow
- If user never starts B: Deleted at 4:15 PM (missed)

**Rule:** NEVER auto-reschedule other tasks. Allow overlaps in calendar.

---

### 8. Day Rollover

**Scenario:** Plan is 11:00-11:45 PM, user starts 11:50 PM, works until 12:30 AM

**Rules:**

- Use absolute timestamps (UTC internally, display in local time)
- Session can span midnight - not a problem
- Finalization happens based on actual times, not "day boundaries"
- Analytics may attribute to the day the session STARTED

---

### 9. External Calendar Edits

**Scenario:** User edits the event directly in Google Calendar while Signal/Noise is tracking

**Current Approach:**

- Detect via sync that event was modified externally
- Update local `plannedStartTime`/`plannedEndTime` to match
- Continue tracking with new times

**Potential Issue:** "Tug of war" if both sides update

**Future Enhancement:** Mark as "externally modified" and stop auto-updating times

---

## Key Decision Log

| Decision                                           | Choice                                  | Rationale                                                        |
| -------------------------------------------------- | --------------------------------------- | ---------------------------------------------------------------- |
| When to create calendar events for scheduled slots | On "Start My Day" (batch)               | Avoids churn during planning; "Start My Day" is commitment point |
| What to show in calendar                           | Actual work accomplished                | Calendar = work log, not plan. Planning history in app analytics |
| Missed slots                                       | DELETE from calendar                    | Clean calendar showing only accomplishments                      |
| Finalization timing                                | BOTH planned+15 AND lastActive+15       | Prevents finalizing while still working overtime                 |
| Session merge window                               | 15 minutes                              | Balance between continuity and recognizing new sessions          |
| Commitment threshold                               | 5 min (short) / 10 min (long)           | Prevents calendar pollution from abandoned sessions              |
| Multiple segments in one slot                      | Single event showing first-to-last span | Calendar can't show gaps; segments tracked internally            |
| Overlapping tasks                                  | Allow overlap, don't auto-reschedule    | User is in control; don't make assumptions                       |
| Ad-hoc sessions                                    | Only sync after threshold               | Consistent with anti-pollution philosophy                        |

---

## Implementation Notes

### Files to Modify

| File                                         | Changes Needed                              |
| -------------------------------------------- | ------------------------------------------- |
| `lib/screens/initial_scheduling_screen.dart` | Add calendar sync on "Start My Day"         |
| `lib/providers/signal_task_provider.dart`    | Update finalization logic (both conditions) |
| `lib/models/time_slot.dart`                  | Update `isSessionFinalized` getter          |
| `lib/services/sync_service.dart`             | Add method for batch creating events        |

### Calendar Event States (Internal Tracking)

Consider adding a `CalendarEventState` enum to track:

```dart
enum CalendarEventState {
  planned,      // Created on "Start My Day", not yet worked
  inProgress,   // User is currently working
  paused,       // User stopped, merge window open
  finalized,    // Actual times locked in
  missed,       // Never started, to be deleted
}
```

---

## Open Questions

_Add questions here as they arise. Update with answers._

1. ~~Should missed slots be deleted or marked?~~ **ANSWERED: Delete**
2. ~~When should calendar events be created for scheduled slots?~~ **ANSWERED: On "Start My Day"**
3. If user works on a slot after merge window expired but before planned end, is it a new session? **ANSWERED: Yes, treated as ad-hoc**

---

_Last Updated: January 6, 2026_
_Document Owner: Architect Agent_
