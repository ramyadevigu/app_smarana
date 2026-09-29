---
applyTo: "**"
description: "Calender instruction"
---

# Smaraṇa Calendar Feature — Implementation Instructions

## 1. Purpose

Implement a complete **Calendar module** for the Smaraṇa Flutter reminder application.

The Calendar should provide a familiar calendar experience inspired by Google Calendar and Microsoft Teams Calendar:

* Monthly calendar grid
* Highlight dates containing reminders/events
* Highlight today's date
* Select a date
* Show the selected day's agenda
* Display reminders/events chronologically
* Display a continuously updating "NOW" line for the current time
* Allow navigation between months
* Allow returning to today
* Work correctly in both light and dark themes
* Reuse the application's existing reminder data
* Do not break existing reminder creation, editing, recurrence, or storage functionality

The Calendar is the first module of a larger Time Management section that will eventually contain:

1. Calendar
2. Alarm
3. World Clock
4. Timer
5. Stopwatch

Only implement the **Calendar** functionality in this task unless explicitly instructed otherwise.

---

# 2. Existing Application Context

The application is a Flutter Android application named **Smaraṇa**.

Existing functionality includes:

* Reminder creation
* Reminder editing
* Reminder deletion
* Reminder storage
* Recurring reminders
* Date and time selection
* SharedPreferences-based persistence
* Light/dark theme support

Existing models/services may already exist.

Before modifying code:

1. Inspect the existing project structure.
2. Inspect the existing `Reminder` model.
3. Inspect `ReminderStorage`.
4. Inspect the existing navigation structure.
5. Inspect the existing theme implementation.
6. Inspect the existing reminder screens.
7. Reuse existing functionality whenever possible.
8. Do not create duplicate reminder models or storage systems.

Do not assume the existing implementation exactly matches these instructions. Adapt to the actual codebase.

---

# 3. Important Development Rule

## Do not rewrite existing working functionality

The current reminder functionality must continue to work.

Do not:

* Replace the existing `Reminder` model unnecessarily.
* Replace `ReminderStorage` unnecessarily.
* Remove existing recurrence support.
* Remove existing reminder editing.
* Remove existing reminder deletion.
* Introduce a second storage mechanism for reminders.
* Change unrelated screens.
* Change the existing theme architecture unless required.
* Introduce a state-management framework solely for Calendar.

Prefer small, isolated changes.

---

# 4. Calendar Architecture

Create a dedicated Calendar feature.

Preferred structure:

```text
lib/
├── models/
│   ├── reminder.dart
│   ├── calendar_event.dart
│   └── recurrence_rule.dart
│
├── screens/
│   └── calendar/
│       ├── calendar_screen.dart
│       ├── calendar_month_view.dart
│       ├── calendar_day_agenda.dart
│       └── calendar_event_details.dart
│
├── widgets/
│   └── calendar/
│       ├── calendar_header.dart
│       ├── calendar_grid.dart
│       ├── calendar_day_cell.dart
│       ├── agenda_timeline.dart
│       ├── agenda_event_card.dart
│       └── current_time_indicator.dart
│
└── services/
    └── calendar_service.dart
```

The exact structure may be adapted to the existing project.

Do not create unnecessary files if the current architecture already provides suitable reusable components.

---

# 5. Calendar Screen

Create:

```text
CalendarScreen
```

The Calendar screen should be the primary calendar interface.

It should contain:

```text
App Bar
    ↓
Month Header
    ↓
Weekday Header
    ↓
Monthly Calendar Grid
    ↓
Selected Date
    ↓
Day Agenda
```

Example:

```text
┌──────────────────────────────────────┐
│ September 2026              ⋮        │
│                                      │
│       <     September 2026     >     │
│                                      │
│ Mon Tue Wed Thu Fri Sat Sun          │
│                                      │
│  31   1   2   3   4   5   6          │
│       •       ••                      │
│   7   8   9  10  11  12  13          │
│              •                       │
│  14  15  16  17  18  19  20          │
│                                      │
│  21  22  23  24  25  26  27          │
│          ••                          │
│                                      │
│  28  29  30   1   2   3   4          │
│      TODAY                            │
├──────────────────────────────────────┤
│ Tuesday, September 29                │
│                                      │
│ 09:00  ─── Team Meeting              │
│                                      │
│ 10:30  ─── Submit Report             │
│                                      │
│ 11:54  ───────── NOW                 │
│                                      │
│ 13:00  ─── Lunch                     │
└──────────────────────────────────────┘
```

The actual UI should be polished and modern, not a literal reproduction of this diagram.

---

# 6. Month Navigation

The user must be able to navigate between months.

Provide:

* Previous month button
* Next month button
* Current month/year label
* Today button

Example:

```text
<        September 2026        >
```

Tapping:

```text
<
```

shows the previous month.

Tapping:

```text
>
```

shows the next month.

The calendar must update without rebuilding unrelated application state.

---

# 7. Today Button

Provide a clear way to return to today's date.

When the user taps **Today**:

1. Set the displayed month to the current month.
2. Select today's date.
3. Show today's agenda.
4. Scroll the agenda toward the current time.
5. Display the current-time indicator.

Do not hard-code today's date.

Use:

```dart
DateTime.now()
```

or an appropriate centralized time abstraction if the project already has one.

---

# 8. Monthly Calendar Grid

The month view must contain a standard 7-column calendar.

Columns:

```text
Monday
Tuesday
Wednesday
Thursday
Friday
Saturday
Sunday
```

Use a consistent first-day-of-week policy throughout the application.

Prefer Monday as the first day because the application is intended for an Indian/international calendar experience.

The grid should include adjacent-month dates when required to complete the calendar rows.

For example:

```text
August 31 | September 1 | September 2 | ...
```

Adjacent-month dates should be visually de-emphasized.

---

# 9. Date Cell Design

Each calendar date cell should display:

* Day number
* Today indicator
* Selected-date indicator
* Reminder/event indicators

Example:

```text
┌─────────┐
│    29   │
│    •    │
│   • •   │
└─────────┘
```

A date containing reminders should have a small visual indicator.

Do not display large amounts of event text inside the month grid.

Use compact indicators such as:

* dots
* small bars
* colored markers

The exact styling should follow the application's existing theme.

---

# 10. Today's Date

Today's date must be visually distinct.

The design should work in both themes.

For example:

```text
       ┌─────┐
       │  29 │
       └─────┘
```

Use the application's theme colors instead of hard-coded colors.

Do not assume today's date is also the selected date.

These are two separate states:

```text
isToday
isSelected
```

A date can be:

```text
today + selected
```

or:

```text
today + not selected
```

or:

```text
not today + selected
```

---

# 11. Selected Date

When the user taps a date:

1. Update the selected date.
2. Update the agenda.
3. Display reminders/events for that date.
4. Preserve the currently displayed month.

Do not automatically navigate to another screen unless required by the existing UX.

The selected date should have a clear visual state.

---

# 12. Reminder Integration

The Calendar must reuse existing reminders.

Do not create duplicate reminder storage.

Use the existing:

```text
ReminderStorage
```

or equivalent service.

The Calendar should read the existing reminder data and determine which reminders belong to each date.

For example:

```text
Reminder:
    title = "Pay electricity bill"
    date = 2026-09-29
    time = 18:00
```

The September 29 calendar cell should display an indicator.

The September 29 agenda should display:

```text
18:00
Pay electricity bill
```

---

# 13. Recurring Reminders

Recurring reminders must appear on the appropriate dates.

For example:

```text
3rd day of every month
```

must appear on:

```text
September 3
October 3
November 3
December 3
...
```

Do not permanently create hundreds of reminder records.

Calculate occurrences when displaying the calendar, or use an appropriate recurrence service.

Reuse the existing recurrence model if one already exists.

Existing recurrence types may include:

```text
none
daily
weekly
monthly
yearly
```

Do not create another incompatible recurrence enum.

---

# 14. Calendar Service

Create a calendar-related service if useful.

Responsibilities may include:

```text
getEventsForDate()
getRemindersForDate()
getEventsForMonth()
hasEventsOnDate()
getRecurringOccurrences()
```

The service should contain date-related logic instead of putting complex date calculations directly into UI widgets.

Example conceptual API:

```dart
List<Reminder> getRemindersForDate(
  DateTime date,
);
```

and:

```dart
bool hasRemindersOnDate(
  DateTime date,
);
```

Keep UI widgets focused on presentation.

---

# 15. Day Agenda

When a date is selected, show an agenda for that date.

The agenda should resemble a modern calendar application.

Example:

```text
Tuesday, September 29

08:00 ─────────────────────

09:00 ─── Team Meeting
          └────────────────

10:00 ─────────────────────

11:00 ─── Submit Report
          └────────────────

11:54 ─────────────── NOW ─

12:00 ─────────────────────

13:00 ─── Lunch
```

The exact visual design can differ.

The important requirements are:

* Time scale
* Chronological ordering
* Event placement
* Current-time indicator
* Scrollable content

---

# 16. Agenda Time Scale

Use an hourly timeline.

Example:

```text
08:00
09:00
10:00
11:00
12:00
13:00
14:00
...
```

Support scrolling through the day.

Do not create one enormous fixed-height widget unnecessarily.

Use a `ListView`, `CustomScrollView`, or an appropriate layout.

---

# 17. Event Positioning

Events should be positioned according to their time.

For example:

```text
09:00 - 10:00
```

should occupy the corresponding one-hour region.

A future calendar event model should support:

```text
startTime
endTime
```

If existing reminders only have a single time, display them as point-in-time reminders rather than artificially assigning an end time.

---

# 18. Current Time Indicator

This is a core requirement.

For today's date only, display a horizontal current-time indicator.

Example:

```text
11:00 ─────────────────────

11:54 🔴 ───────────────── NOW

12:00 ─────────────────────
```

Requirements:

* Only show it when selected date is today.
* Position it according to the current time.
* Update automatically.
* Do not require the user to refresh the screen.
* Use a timer that updates efficiently.
* Stop the timer when the screen is disposed.

The indicator should move naturally as time progresses.

---

# 19. Current Time Calculation

Do not hard-code pixel positions.

Calculate the vertical position from:

```text
current hour
current minute
minutes since midnight
```

Conceptually:

```dart
minutesSinceMidnight =
    current.hour * 60 + current.minute;
```

Then convert minutes into pixels according to the timeline scale.

For example:

```text
60 minutes = 60 logical pixels
```

or another scale chosen for the UI.

Make the scale configurable rather than scattering magic numbers throughout the code.

---

# 20. Current Time Updates

Use a periodic timer.

A one-minute update interval is sufficient for the current-time line.

Do not update the entire application every second.

Preferred behavior:

```text
Timer.periodic(
    const Duration(minutes: 1),
    ...
)
```

Ensure:

```dart
timer.cancel();
```

is called when the widget is disposed.

Avoid memory leaks.

---

# 21. Agenda Auto Scroll

When viewing today's date:

* Automatically position the agenda near the current time.
* The user should not have to scroll from midnight to find the current time.

For example, at 11:54 AM:

```text
09:00
10:00
11:00
11:54 ← visible
12:00
13:00
```

When viewing a different date:

* Do not automatically scroll to the current time.
* Start at a sensible position such as 08:00.

Do not force-scroll repeatedly while the user is interacting with the agenda.

---

# 22. Event Ordering

Events/reminders must be sorted chronologically.

Example:

```text
09:00 Doctor Appointment
10:30 Team Meeting
13:00 Lunch
18:00 Pay Electricity Bill
```

Do not rely on insertion order.

Sort by date/time.

If two items have the same time, use a stable secondary ordering such as creation order or title.

---

# 23. Empty Day

If the selected date has no reminders/events, display a clean empty state.

Example:

```text
Tuesday, September 29

No events or reminders

                 + Add Reminder
```

Do not leave the screen completely blank.

---

# 24. Adding a Reminder from Calendar

The Calendar should provide an obvious way to create a reminder for the selected date.

For example:

```text
+ Add Reminder
```

When the user chooses this action:

1. Open the existing Add Reminder screen.
2. Pre-populate the selected calendar date.
3. Preserve existing reminder creation behavior.
4. After saving, return to Calendar.
5. Refresh the calendar.
6. Show the new reminder immediately.

Do not create a second Add Reminder implementation.

---

# 25. Editing a Reminder

When the user taps an existing reminder in the agenda:

* Open the existing edit functionality.
* Do not duplicate the reminder editing UI.
* After saving, refresh Calendar.

---

# 26. Deleting a Reminder

Use the existing reminder deletion functionality.

After deletion:

* Remove the item from the agenda.
* Remove its calendar indicator if no other reminder/event exists on that date.

---

# 27. Light and Dark Theme

Calendar must fully support the existing application theme.

Never hard-code:

```dart
Colors.white
Colors.black
```

for major UI surfaces.

Use:

```dart
Theme.of(context)
```

and:

```dart
colorScheme
```

where appropriate.

The Calendar should automatically follow:

```text
System
Light
Dark
```

if the application already supports these settings.

If the application has a theme service/settings implementation, reuse it.

Do not introduce a second theme manager.

---

# 28. Theme Requirements

Verify all of the following in both themes:

### Light mode

* Calendar background
* Date numbers
* Weekday labels
* Selected date
* Today indicator
* Event indicators
* Agenda background
* Timeline
* Event cards
* Current-time indicator
* App bar
* Buttons
* Empty states

### Dark mode

Everything above must remain readable.

Avoid:

* dark text on dark background
* light text on light background
* invisible borders
* low-contrast event indicators

Use the application's defined color system.

---

# 29. Responsive Layout

The Calendar must work on common Android screen sizes.

Avoid:

```dart
width: 400
height: 800
```

style fixed dimensions.

Use:

* `Expanded`
* `Flexible`
* `LayoutBuilder`
* responsive constraints

where appropriate.

The calendar grid must remain usable on smaller devices.

---

# 30. Navigation Integration

The application will eventually contain five primary tabs:

```text
Calendar
Alarm
World Clock
Timer
Stopwatch
```

For this implementation:

* Add the Calendar tab.
* Preserve existing screens and navigation.
* Do not implement Alarm, World Clock, Timer, or Stopwatch unless explicitly requested.
* Placeholder screens may be used for future tabs only if the current navigation architecture requires them.

Preferred navigation:

```text
┌─────────────────────────────────────────────┐
│                                             │
│              Calendar Screen                │
│                                             │
├─────────────────────────────────────────────┤
│ Calendar │ Alarm │ World Clock │ Timer │ SW │
└─────────────────────────────────────────────┘
```

Use appropriate Material icons.

---

# 31. State Management

Do not introduce Riverpod, Bloc, Provider, GetX, or another state-management framework unless the existing project already uses it.

Prefer Flutter's existing state-management approach.

The Calendar may use:

```dart
StatefulWidget
```

with:

* selected date
* displayed month
* current time
* loaded reminders

If the application already uses another state-management architecture, follow that architecture.

---

# 32. Date Handling

Normalize dates when comparing them.

Do not compare full `DateTime` values when only the date matters.

For example, these should represent the same calendar day:

```text
2026-09-29 08:00
2026-09-29 18:30
```

Use a date-only comparison strategy.

Avoid timezone-related bugs.

Do not convert dates to UTC merely for comparison unless the application has an explicit UTC-based architecture.

---

# 33. Locale

Use the device/application locale where practical.

Month names should be generated dynamically.

Do not hard-code:

```text
January
February
March
...
```

Use Flutter's date formatting facilities or an existing date-formatting dependency.

---

# 34. Accessibility

Ensure:

* Sufficient contrast
* Adequate tap targets
* Semantic labels for navigation buttons
* Screen-reader-friendly date cells
* Meaningful labels for event indicators

Date cells should have a sufficiently large touch target.

---

# 35. Performance

The calendar should remain responsive.

Avoid:

* Re-reading SharedPreferences for every date cell.
* Performing expensive recurrence calculations repeatedly during every build.
* Creating timers inside every calendar cell.
* Rebuilding the entire application every minute.

Load reminder data once and derive the month/date presentation from that data.

Use efficient date filtering.

---

# 36. Error Handling

If reminder storage fails:

* Do not crash the Calendar screen.
* Display a safe error state.
* Log useful diagnostic information during development.

Do not expose raw exceptions to the user.

---

# 37. Testing Requirements

Before considering the Calendar complete, test:

### Month navigation

* Previous month
* Next month
* Today

### Date selection

* Select current date
* Select another date
* Select previous-month date
* Select next-month date

### Reminder display

* One reminder
* Multiple reminders
* Different reminder times
* Same-time reminders
* Recurring reminder

### Current-time indicator

* Today's date
* Previous date
* Future date
* Midnight
* Noon
* Near end of day

### Theme

* Light mode
* Dark mode
* System theme if supported

### Persistence

* Create reminder
* Restart application
* Open Calendar
* Verify reminder remains visible

### Editing

* Edit reminder
* Verify calendar refreshes

### Deletion

* Delete reminder
* Verify calendar indicator updates

---

# 38. Do Not Over-Engineer

The Calendar should be implemented incrementally.

Do not initially add:

* Google Calendar integration
* Microsoft Calendar integration
* Outlook synchronization
* Cloud synchronization
* Authentication
* Calendar sharing
* Multiple accounts
* Complex drag-and-drop scheduling
* External calendar APIs

Those can be future features.

The current goal is a robust local Calendar experience based on Smaraṇa's existing reminder data.

---

# 39. Implementation Sequence

Implement the feature in this exact order.

## Step 1 — Inspect

Inspect:

```text
Reminder model
ReminderStorage
AddReminderScreen
Reminder list screen
Navigation
Theme implementation
```

Do not modify anything yet.

---

## Step 2 — Calendar navigation

Add:

```text
CalendarScreen
```

and integrate it into the application's navigation.

Verify that the existing reminder functionality still works.

---

## Step 3 — Month grid

Implement:

* Month header
* Previous month
* Next month
* Today
* Weekday header
* Calendar grid
* Date selection

Do not implement the agenda yet.

Verify this independently.

---

## Step 4 — Reminder indicators

Connect Calendar to existing reminder storage.

Display indicators on dates containing reminders.

Verify recurring reminders.

---

## Step 5 — Day agenda

Implement the selected-date agenda.

Display:

* Hourly timeline
* Reminder cards
* Chronological ordering
* Empty state

---

## Step 6 — Current-time indicator

Implement:

* NOW line
* Current-time calculation
* One-minute updates
* Automatic scroll for today
* Timer disposal

---

## Step 7 — Existing reminder actions

Connect:

* Add reminder
* Edit reminder
* Delete reminder

Do not duplicate existing functionality.

---

## Step 8 — Theme and polish

Verify:

* Light mode
* Dark mode
* Typography
* Spacing
* Contrast
* Selected states
* Today state
* Event indicators
* Navigation

---

## Step 9 — Testing

Run:

```bash
flutter analyze
```

Then:

```bash
flutter test
```

if tests exist.

Finally:

```bash
flutter run
```

Test on a real Android device/emulator.

---

# 40. Coding Standards

Follow the existing project's Dart style.

Use:

```dart
const
```

where possible.

Avoid unnecessary `dynamic`.

Prefer strongly typed models.

Use meaningful names.

Avoid:

```dart
var x;
var y;
var data;
```

when a more descriptive name is appropriate.

Avoid excessive comments.

Comments should explain **why**, not obvious code behavior.

---

# 41. Copilot Behavior

When implementing this instruction file:

1. First inspect the existing project.
2. Do not immediately generate large amounts of code.
3. Identify the existing navigation architecture.
4. Identify the existing reminder model.
5. Identify existing theme architecture.
6. Identify existing storage architecture.
7. Make the smallest required changes.
8. Compile after each major step.
9. Fix analyzer errors before continuing.
10. Do not rewrite unrelated files.
11. Do not remove existing functionality.
12. Do not create duplicate services/models unnecessarily.

When an existing implementation differs from these instructions, prefer the existing architecture unless there is a clear technical reason to change it.

---

# 42. Definition of Done

The Calendar feature is complete when:

* [ ] Calendar is accessible from the primary navigation.
* [ ] Month grid is displayed.
* [ ] Previous/next month works.
* [ ] Today works.
* [ ] Today's date is highlighted.
* [ ] Selected date is highlighted.
* [ ] Dates containing reminders have indicators.
* [ ] Existing reminders appear in Calendar.
* [ ] Recurring reminders appear on their applicable dates.
* [ ] Selecting a date displays its agenda.
* [ ] Agenda is chronologically ordered.
* [ ] Agenda is scrollable.
* [ ] Today's agenda displays a current-time indicator.
* [ ] Current-time indicator updates automatically.
* [ ] Current-time indicator is absent for non-today dates.
* [ ] Today's agenda initially scrolls near the current time.
* [ ] Empty dates display an appropriate empty state.
* [ ] Existing Add Reminder functionality works.
* [ ] Existing Edit Reminder functionality works.
* [ ] Existing Delete Reminder functionality works.
* [ ] Calendar updates after reminder changes.
* [ ] Light mode works correctly.
* [ ] Dark mode works correctly.
* [ ] No existing reminder functionality is broken.
* [ ] `flutter analyze` completes without new errors.
* [ ] Application runs successfully on Android.

---

# 43. Future Architecture

The Calendar implementation must leave room for the following future modules:

```text
Calendar
Alarm
World Clock
Timer
Stopwatch
```

Do not tightly couple Calendar code to the future modules.

The eventual application structure should conceptually become:

```text
Smaraṇa
│
├── Calendar
│   ├── Month View
│   ├── Day Agenda
│   ├── Reminders
│   └── Events
│
├── Alarm
│
├── World Clock
│
├── Timer
│
└── Stopwatch
```

Calendar is the first implementation target.

Do not implement future modules unless specifically instructed.
