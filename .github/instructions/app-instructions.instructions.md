---
applyTo: "**"
description: "Project-wide instructions for the local-first Smaraṇa Flutter reminder app"
---

# Smaraṇa — Flutter Reminder App

## 1. Project Goal

Build a reliable, polished, local-first Flutter reminder application called **Smaraṇa**.

Smaraṇa is a personal planning application centered around:

- Calendar
- Reminders
- Alarms
- Notes
- Stopwatch
- Timer

The application must remain reliable and local-first while providing a modern productivity-app experience.

Core reminder capabilities:

- Create reminders
- Edit reminders
- Delete reminders
- View reminders
- Set a date and time
- Add optional descriptions
- Create recurring reminders
- Support daily, weekly, monthly and yearly recurrence
- Persist reminders locally
- Schedule notifications
- Trigger notifications when the application is closed
- Handle recurring reminders correctly
- Display the next occurrence of recurring reminders
- Avoid duplicate notifications
- Enable and disable reminders
- Provide a clean, modern, responsive UI

Do not sacrifice reliability or existing functionality for visual changes.

---

# 2. Technology

Use the technologies already established by the project whenever possible:

- Flutter
- Dart
- Material 3
- SharedPreferences for local persistence
- flutter_local_notifications for notifications
- timezone for timezone-aware scheduling
- uuid for reminder IDs

Do not add a package unless there is a clear requirement that cannot reasonably be implemented with the existing project.

Before adding a dependency:

1. Inspect the existing project.
2. Check whether an existing package already provides the required capability.
3. Prefer Flutter/Dart standard APIs when practical.
4. Explain why the dependency is necessary.

Do not perform broad package/dependency searches.

---

# 3. Architecture

Use a simple layered architecture.

A possible structure is:

```text
lib/
├── main.dart
├── models/
│   └── reminder.dart
├── screens/
│   ├── reminders_screen.dart
│   ├── add_reminder_screen.dart
│   ├── calendar/
│   ├── notes/
│   ├── alarms/
│   ├── stopwatch/
│   └── timer/
├── services/
│   ├── reminder_storage.dart
│   └── notification_service.dart
├── utils/
│   └── recurrence_utils.dart
└── theme/
    └── ...
```

Adapt this structure to the existing project.

Do not blindly create a new architecture.

Keep these responsibilities separate:

- UI
- Models
- Persistence
- Recurrence calculations
- Notification scheduling
- Theme management
- Navigation
- State management

Do not put storage, recurrence calculations, or notification scheduling directly inside widgets.

If the project already uses Provider, Riverpod, Bloc, Cubit, ChangeNotifier, or another established state-management approach, continue using it.

Do not introduce a second state-management system only for one feature.

---

# 4. Critical Development Rules

1. Do not rewrite working code unnecessarily.
2. Before modifying a file, inspect the existing implementation.
3. Preserve existing functionality.
4. Do not introduce duplicate models.
5. Do not introduce duplicate services.
6. Do not create competing implementations of the same feature.
7. Use null-safe Dart.
8. Avoid deprecated Flutter APIs.
9. Do not use `print()` for production logging.
10. Handle errors gracefully.
11. Keep business logic outside widgets.
12. Keep UI components reusable.
13. Do not add unnecessary packages.
14. Run `flutter analyze` after significant changes.
15. Run the application and test changed functionality.
16. Do not mark a feature complete until it has been tested.
17. When a requirement is ambiguous, inspect the existing project before making assumptions.
18. Prefer incremental changes over large rewrites.
19. Preserve existing navigation and data unless the requested feature explicitly changes them.
20. Do not replace real application data with permanent mock data.

---

# 5. Existing Functionality Must Be Preserved

When implementing a new UI or redesign:

- Reuse the existing reminder model.
- Reuse the existing reminder storage.
- Reuse existing recurrence logic.
- Reuse existing notification scheduling.
- Reuse existing alarm functionality.
- Reuse existing navigation where appropriate.
- Reuse the existing theme architecture.
- Reuse existing state management.

Do not rebuild a working service merely because the UI is being redesigned.

UI redesign must not silently change business logic.

---

# 6. Reminder Model

A reminder must support:

- `id`
- `title`
- `description`
- scheduled date/time
- recurrence type
- recurrence configuration
- enabled/active state

Supported recurrence types:

- none
- daily
- weekly
- monthly
- yearly

If the existing application already supports additional recurrence modes, preserve them.

Examples:

### One-time

15 October 2026 at 09:30 AM

### Daily

Every day at 09:30 AM

### Weekly

Every Monday at 09:30 AM

### Monthly

3rd day of every month at 09:30 AM

### Yearly

15 October every year at 09:30 AM

---

# 7. Recurrence Requirements

Recurrence logic must be centralized in one utility/service.

Do not duplicate recurrence calculations across screens.

Monthly recurrence must correctly handle months with different numbers of days.

For example:

```text
31st of every month
```

If a month does not contain day 31, do not create an invalid date.

The implementation must define and consistently apply the existing project's intended behavior for invalid recurrence dates.

Recurring reminders must:

- calculate the next valid occurrence
- remain stable across application restarts
- avoid duplicate occurrences
- display correctly in the Calendar
- schedule notifications correctly
- preserve their recurrence configuration when edited

Do not calculate recurring dates independently in every UI widget.

---

# 8. Persistence

All reminders must survive application restart.

Saving, loading, updating and deleting reminders must use the same storage service.

Storage must be:

- local-first
- versionable
- safely encoded/decoded
- resilient to corrupted data

Corrupted stored data must not crash the application.

If migration is required because the Reminder model changes:

1. Detect the stored version.
2. Migrate safely.
3. Preserve existing reminders whenever possible.
4. Avoid destructive migration without explicit justification.

Do not silently delete existing user data.

---

# 9. Notification Requirements

Notifications must:

- use a unique notification ID
- contain reminder title
- contain reminder description when available
- respect the selected date/time
- respect timezone
- work when the application is closed
- work for recurring reminders
- avoid duplicate scheduling
- be cancelled when a reminder is deleted
- be rescheduled when a reminder is edited
- be cancelled when a reminder is disabled
- be restored/rescheduled appropriately after application restart

The notification service must remain separate from UI code.

Do not create a second notification scheduling mechanism.

---

# 10. UI/UX Direction

Smaraṇa should feel like a modern productivity application.

Visual inspiration may come from applications such as:

- Microsoft Teams
- Microsoft Planner
- Google Calendar
- Google Keep
- modern productivity applications

Use these only as design inspiration.

Do not copy proprietary layouts, logos, branding, or assets.

Smaraṇa must have its own visual identity.

Prioritize:

- clear hierarchy
- excellent spacing
- readable typography
- thin separators
- subtle surfaces
- rounded components where appropriate
- compact controls
- smooth transitions
- accessible contrast
- useful information density
- minimal visual clutter

Do not make every component colorful.

Do not use excessive gradients.

Do not use excessive glassmorphism.

Do not introduce visual effects that reduce readability or performance.

---

# 11. Smaraṇa Theme System — Critical

The application must NOT be restricted to one brand color.

The user must be able to select their preferred application theme.

The user-facing theme palette consists of **exactly these seven colors**, matching the supplied design reference:

| Theme | Base Color |
|---|---|
| Blue | `#4773FA` |
| Cyan | `#93DCED` |
| Mint | `#9CE3D3` |
| Light Green | `#CAE0B9` |
| Peach / Amber | `#FBD6A1` |
| Pink | `#F7BED1` |
| Lavender | `#D0C6FA` |

These seven colors are the complete user-selectable theme palette.

## Theme Rules

The user can freely choose any of the seven themes.

Do NOT:

- add an eighth user-selectable theme
- remove any of the seven themes
- replace them with arbitrary colors
- restrict the application to Smaraṇa blue
- force every screen to use the same accent
- introduce the previous broad rainbow-style event palette
- add red, orange, purple, indigo, or other colors as additional user-selectable themes

The selected theme must be applied consistently throughout theme-aware application UI.

The seven base colors are theme identities.

The implementation may derive lighter/darker/tinted variants from the selected base color when required for:

- Light Mode
- Dark Mode
- surfaces
- borders
- selected states
- disabled states
- event backgrounds
- accessibility
- text contrast

Derived tonal variants are implementation details and are NOT additional user-selectable themes.

---

# 12. Theme Architecture

Use the existing application theme architecture as the source of truth.

Do not create an independent theme system for individual screens.

A centralized theme implementation may contain:

```text
lib/theme/
```

or integrate into the existing theme structure.

Use semantic theme roles instead of scattering hexadecimal values throughout widgets.

For example:

```dart
Theme.of(context).colorScheme
```

or an equivalent centralized Smaraṇa theme provider.

The selected theme should control appropriate semantic roles such as:

- primary
- secondary
- surface
- background
- selected state
- navigation selection
- FAB
- controls
- focus states
- calendar accents

Do not hard-code theme colors inside individual widgets.

---

# 13. Theme Selection

The theme selector should present the seven approved colors clearly.

Conceptually:

```text
○ Blue
○ Cyan
○ Mint
○ Light Green
○ Peach
○ Pink
● Lavender
```

The currently selected theme must be visually obvious.

Do not rely on color alone to communicate selection.

Use an appropriate indicator such as:

- check mark
- outline
- selected border
- shape
- elevation
- icon

The selected theme must persist according to the application's existing local settings architecture.

Do not create a separate storage mechanism if the project already has theme/settings persistence.

---

# 14. Light, Dark and System Themes

Smaraṇa must support the application's existing:

- Light
- Dark
- System

theme modes.

Do not create separate theme switching logic for individual screens.

The selected seven-color theme must work in all supported theme modes.

Do not simply invert Light Mode to create Dark Mode.

For each theme, ensure:

- readable text
- visible icons
- clear borders
- distinguishable surfaces
- visible selected states
- accessible event/reminder indicators

The selected theme identity should remain recognizable in both Light and Dark modes.

---

# 15. Color Accessibility

Color must never be the only way to communicate important information.

For example, an alarm-enabled reminder should not be identifiable only because it is a particular color.

Use combinations of:

- icon
- label
- typography
- shape
- border
- position
- color

The seven pastel theme colors must not be used behind text when contrast is insufficient.

Derive an appropriate semantic foreground color or tonal surface.

Do not add a new user-selectable color simply to solve a contrast problem.

---

# 16. No Scattered Hard-Coded Colors

Avoid code such as:

```dart
Colors.blue
Colors.red
Color(0xFF123456)
```

when the value should be theme-aware.

Prefer:

```dart
Theme.of(context).colorScheme
```

or the centralized Smaraṇa theme system.

Hard-coded hexadecimal values are acceptable when they represent:

- one of the seven approved base theme colors, or
- a deliberate centralized derived semantic variant.

Do not scatter arbitrary hexadecimal colors throughout the application.

---

# 17. Calendar

The Calendar is a major Smaraṇa workspace.

It must use real Smaraṇa reminder data.

The Calendar should support three primary views:

1. **Month + Week** — default
2. **Next 3 Days**
3. **Month Only**

All three views must use the same reminder/calendar data.

Do not create a separate Calendar data model when the existing Reminder model can be reused.

---

# 18. Calendar — Default Month + Week View

The default Calendar view is:

**Month + Week**

It should combine:

1. Full month grid
2. Detailed weekly agenda

The month grid should occupy the primary upper portion of the screen.

The weekly agenda should appear below it.

Selecting a date should update the detailed weekly/day information appropriately.

The Calendar should clearly communicate:

- current date
- selected date
- dates containing reminders
- current week
- alarms
- recurring reminders

---

# 19. Calendar — Month Grid

The month grid should support:

- 7 columns
- readable date numbers
- thin grid lines
- current date
- selected date
- previous/next month dates
- reminder indicators
- recurrence indicators
- event indicators
- overflow indicators
- subtle weekend differentiation

Grid lines must be:

- thin
- subtle
- visible
- consistent

Do not remove grid lines completely.

Do not make them heavy or visually dominant.

---

# 20. Calendar — Date States

Current date and selected date are different states.

Do not confuse:

- TODAY
- SELECTED DATE

Use shape, border, background, typography, or an indicator in addition to color.

If today is selected, combine the two states elegantly.

The date states must remain understandable in:

- Light Mode
- Dark Mode
- all Calendar views

---

# 21. Calendar — Events

Calendar events should use the existing reminder data.

An event may display:

- title
- time
- description
- alarm indicator
- recurrence indicator
- event accent
- selected state

Do not create fake permanent calendar data.

Temporary mock data may be used during UI development but must be isolated and removed or disabled before completion.

---

# 22. Calendar — Event Colors

Calendar event colors must use the Smaraṇa theme system.

Do NOT create an unlimited arbitrary event color palette.

Use the seven approved base colors as the source family:

- `#4773FA`
- `#93DCED`
- `#9CE3D3`
- `#CAE0B9`
- `#FBD6A1`
- `#F7BED1`
- `#D0C6FA`

Tonal variants may be derived when required for readable event surfaces.

The event color resolver must be:

- centralized
- deterministic
- theme-aware
- stable across rebuilds
- accessible

Do not generate random event colors on every widget rebuild.

If the existing Reminder model already contains a category/color, reuse it.

Do not unnecessarily modify the data model only to support the visual redesign.

---

# 23. Calendar — Next 3 Days

The Next 3 Days view is a focused time-based planning view.

It should support:

- three consecutive dates
- hourly time labels
- event blocks
- event duration
- alarms
- recurrence indicators
- scrolling
- overlapping events
- current-time indicator
- long-duration events
- multiple events

When practical, position the initial scroll near the current time instead of always starting at midnight.

Do not build an unnecessarily complex scheduling engine.

---

# 24. Calendar — Month Only

The Month Only view should maximize the month grid.

It should:

- display the complete month
- show high-level event/reminder indicators
- show overflow indicators
- support date selection
- retain month navigation
- retain the view selector
- allow detailed day information to be opened

Do not attempt to display complete event descriptions inside month cells.

---

# 25. Calendar — View State

Use a single Calendar view state.

For example:

```dart
enum CalendarViewType {
  monthAndWeek,
  nextThreeDays,
  monthOnly,
}
```

Adapt to the existing architecture if an equivalent already exists.

Do not create duplicate state systems.

Default:

```text
monthAndWeek
```

Switching views should not reload the entire application.

Use appropriate Flutter transitions such as `AnimatedSwitcher` when useful.

---

# 26. Calendar — Header

Use a clean, compact Calendar header.

It should provide:

- Calendar/navigation control
- current month/year
- view selector
- appropriate additional actions

Support:

- previous month
- next month
- Today

Do not make navigation controls visually dominant.

The header should remain stable when switching Calendar views.

---

# 27. Calendar — Reminder Interaction

When the user taps an existing reminder/event:

- open the existing reminder/event details or edit UI.

When the user taps a date:

- select the date.

When the user taps an appropriate empty time:

- use the existing Add Reminder functionality where practical.

Do not create duplicate reminder creation/editing logic.

---

# 28. Calendar — Add Reminder

Keep the existing Add Reminder flow.

The Calendar may provide an Add Reminder FAB or equivalent existing action.

Do not rebuild Add Reminder functionality merely because the Calendar UI changed.

When a date/time is selected before creating a reminder, pre-fill it where supported by the existing implementation.

---

# 29. Other Core Screens

The application should remain compatible with the broader Smaraṇa workspace:

1. Calendar
2. Notes
3. Alarms
4. Stopwatch
5. Timer

Do not redesign unrelated screens as part of a Calendar-only task unless explicitly requested.

Maintain consistent navigation and theme behavior across these screens.

---

# 30. Notes

If Notes functionality already exists, preserve it.

Notes should remain compatible with the Smaraṇa theme system.

Do not create a second theme architecture for Notes.

If Notes is being implemented in a separate task, inspect the existing project before making architectural decisions.

---

# 31. Reminders Screen

Display:

- application title
- list of reminders
- reminder title
- description when available
- scheduled date/time
- recurrence information
- enabled/disabled state
- add button

Tapping a reminder opens the edit screen.

Long press or an appropriate menu may provide delete functionality.

Use the existing reminder data source.

---

# 32. Add/Edit Reminder Screen

The same screen should support both creating and editing.

Fields should include:

- Title
- Description
- Date
- Time
- Recurrence

Use clear validation.

Title is required.

Preserve existing recurrence and notification behavior.

Do not duplicate reminder business logic inside the screen.

---

# 33. Alarms

Alarms must continue using the existing reminder/notification architecture where appropriate.

Do not create duplicate scheduling services.

If the existing application has a dedicated alarm implementation, inspect and reuse it.

Alarm state must remain synchronized with the reminder model and notification scheduling.

---

# 34. Stopwatch and Timer

Preserve existing Stopwatch and Timer functionality.

Do not modify unrelated logic during Calendar or reminder work.

If these screens need theme updates, use the centralized seven-color Smaraṇa theme system.

---

# 35. Responsive Design

The application is mobile-first.

Support:

- small Android phones
- large Android phones
- tablets where practical

Do not hard-code screen dimensions.

Prefer:

- `LayoutBuilder`
- `MediaQuery`
- `Flexible`
- `Expanded`
- `SafeArea`
- `CustomScrollView`
- Slivers where appropriate

Avoid horizontal overflow.

Design for different text lengths and screen sizes.

---

# 36. Typography

Use the application's existing typography system.

Prioritize:

- clear hierarchy
- readable date numbers
- readable month titles
- compact event text
- clear time labels
- appropriate font weights

Do not introduce a separate font system for individual screens.

---

# 37. Animation

Use subtle animations for:

- month changes
- date selection
- view switching
- event expansion
- theme selection

Animations should be:

- fast
- smooth
- purposeful
- accessible

Do not use excessive animation.

Avoid animations that interfere with interaction or reduce performance.

---

# 38. Performance

The Calendar and reminder system may eventually contain many reminders.

Avoid:

- unnecessary rebuilds
- expensive operations inside `build()`
- repeated recurrence calculations
- repeated date conversions
- large unnecessary widget trees

Separate:

```text
data processing
```

from:

```text
UI rendering
```

If recurring events must be expanded for a view, calculate them outside individual day cells.

Use efficient Flutter widgets.

---

# 39. Error Handling

Handle failures gracefully.

Potential failures include:

- corrupted local storage
- invalid dates
- notification scheduling errors
- timezone errors
- permission failures
- missing data
- malformed reminder records

The application should remain usable where possible.

Do not expose raw exceptions directly to users.

Use appropriate user-facing feedback.

Do not silently discard important user data.

---

# 40. Git Workflow

Make changes in small logical stages.

After each meaningful stage:

1. Run analysis.
2. Test the application.
3. Review changed files.
4. Review the diff.
5. Commit the completed logical change when Git is available and the project workflow expects commits.

Use meaningful commit messages.

Examples:

```text
feat: implement recurring reminder model
fix: correct monthly recurrence calculation
feat: add local notification scheduling
feat: add calendar month-week view
feat: add seven-color theme selector
fix: preserve selected theme across restart
```

Do not create meaningless commits.

Do not commit generated build artifacts.

---

# 41. Investigation Rules

Do not perform broad repository-wide searches.

Do not search:

- Flutter SDK
- Pub cache
- `.dart_tool`
- `build/`
- `node_modules/`
- system directories
- generated files

Focus on application source and configuration.

Inspect these locations first:

```text
lib/
test/
pubspec.yaml
android/
```

Start with these files if they exist:

```text
lib/main.dart
lib/models/reminder.dart
lib/screens/reminders_screen.dart
lib/screens/add_reminder_screen.dart
lib/services/reminder_storage.dart
lib/services/notification_service.dart
```

Also inspect:

- existing theme files
- navigation files
- recurrence utilities
- state-management files
- Calendar files
- notification initialization
- Android notification configuration

Do not run `rip_grep_packages`.

Do not perform a repository-wide dependency search.

---

# 42. Implementation Workflow

For every requested feature, follow this sequence.

## Phase 1 — Inspect

Before changing code:

1. Identify the relevant files.
2. Read the existing implementation.
3. Identify dependencies.
4. Identify existing models/services.
5. Identify state-management approach.
6. Identify theme architecture.
7. Identify navigation.
8. Identify related tests.

Do not modify unrelated files.

## Phase 2 — Plan

Determine:

- what must change
- what can be reused
- what must not change
- whether a model change is necessary
- whether a new service is necessary
- whether a new dependency is necessary

Prefer the smallest correct implementation.

## Phase 3 — Implement

Implement incrementally.

Reuse existing architecture.

Do not replace working services without a clear reason.

## Phase 4 — Analyze

Run:

```bash
flutter analyze
```

Fix errors introduced by the change.

Review warnings.

## Phase 5 — Test

Run the relevant application flow.

Test the actual user interaction rather than only checking compilation.

## Phase 6 — Review

Review:

- changed files
- data flow
- persistence
- notification behavior
- UI behavior
- theme behavior
- responsive layout
- performance

## Phase 7 — Report

Explain:

1. What changed
2. Files created
3. Files modified
4. Existing functionality preserved
5. Tests performed
6. `flutter analyze` result
7. Any remaining warnings
8. Any limitations

---

# 43. Testing Requirements

At minimum, verify:

## Reminder

- Create one-time reminder
- Edit reminder
- Delete reminder
- Enable reminder
- Disable reminder
- Persist reminder
- Restart application
- Verify reminder remains

## Recurrence

- Daily
- Weekly
- Monthly
- Yearly
- Invalid monthly dates
- Next occurrence calculation
- Application restart

## Notifications

- Notification scheduling
- Correct date/time
- Correct timezone
- Notification while app is closed
- Editing notification schedule
- Deleting notification
- Disabling notification
- Re-enabling notification
- No duplicate notifications

## Calendar

### Month + Week

- Month navigation
- Date selection
- Weekly agenda
- Reminder display
- Alarm indicator
- Recurrence display
- Current date
- Selected date

### Next 3 Days

- Correct dates
- Time axis
- Event blocks
- Current-time indicator
- Scrolling
- Overlapping events
- Alarm indicators

### Month Only

- Complete month
- Event indicators
- Selected date
- Overflow events
- Navigation

## Theme

Test all seven approved themes:

```text
#4773FA  Blue
#93DCED  Cyan
#9CE3D3  Mint
#CAE0B9  Light Green
#FBD6A1  Peach / Amber
#F7BED1  Pink
#D0C6FA  Lavender
```

For every theme, test:

- Light Mode
- Dark Mode
- System Mode
- Calendar
- Reminders
- Add/Edit Reminder
- navigation
- selected states
- FAB
- event indicators
- readable contrast

Do not add additional user-selectable theme colors.

---

# 44. Completion Criteria

Do not declare the application complete until all applicable requirements have been verified.

Minimum completion criteria:

1. Create one-time reminder
2. Edit reminder
3. Delete reminder
4. Persist reminder
5. Restart application and retain reminder
6. Create daily reminder
7. Create weekly reminder
8. Create monthly reminder
9. Create yearly reminder
10. Schedule notification
11. Receive notification when application is closed
12. Edit notification schedule
13. Delete notification
14. Disable notification
15. Re-enable notification
16. Handle invalid recurrence dates
17. Handle application restart
18. Handle corrupted local storage safely
19. Avoid duplicate notifications
20. Calendar uses real reminder data
21. Month + Week view works
22. Next 3 Days view works
23. Month Only view works
24. Seven theme colors are selectable
25. Selected theme persists appropriately
26. Light/Dark/System modes work
27. `flutter analyze` passes without errors

Do not claim completion based only on visual appearance or compilation.

---

# 45. Final Implementation Principles

Always prioritize:

**Reliability > unnecessary complexity**

**Existing architecture > duplicate architecture**

**Real data > mock data**

**User data safety > destructive migration**

**Accessibility > decorative color**

**Consistency > one-off UI implementations**

**Performance > unnecessary visual effects**

**Simple maintainable code > clever code**

Smaraṇa should ultimately feel like a polished, reliable personal productivity application while remaining technically simple, local-first, maintainable, and extensible.
