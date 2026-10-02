---
applyTo: "**/calendar/**/*.dart, **/calendar*.dart"
description: Modern multi-view Calendar workspace for the Smarana Flutter reminder app
name: Smarana Calendar Redesign
---

# Smaraṇa — Calendar Redesign System

## Objective

Completely redesign the existing Smaraṇa Calendar screen into a modern, professional productivity-calendar workspace.

The Calendar should feel like a combination of:

- Microsoft Teams Calendar
- Microsoft Planner
- Modern productivity applications
- Professional mobile scheduling applications

Do NOT copy Microsoft Teams or Microsoft Planner directly.

Use them only as visual and interaction inspiration.

The goal is to make Smaraṇa Calendar feel like a complete planning workspace rather than a simple date picker.

The Calendar must support three primary views:

1. Month + Week — DEFAULT
2. Next 3 Days
3. Month Only

The same existing Smaraṇa reminder/calendar data must power all three views.

Do not create a separate calendar data system.

Do not break existing reminder, alarm, notification, recurrence, or storage functionality.

---

# 1. IMPORTANT DESIGN PRINCIPLE — COLOR

DO NOT restrict the Calendar to a small fixed set of colors.

The Calendar should support a rich, multi-color productivity experience inspired by Microsoft Teams and Microsoft Planner.

Do NOT prescribe a specific list of colors such as:

- Blue
- Purple
- Green
- Orange

as the only available colors.

Instead, create a flexible Calendar color system that can support many visually distinct colors.

The exact colors should be selected based on:

- visual hierarchy
- readability
- accessibility
- Light Mode
- Dark Mode
- event categorization
- modern productivity UI aesthetics

The Calendar may use a broad range of colors including, but not limited to:

- blue
- cyan
- teal
- green
- lime
- yellow
- amber
- orange
- red
- coral
- pink
- magenta
- purple
- violet
- indigo
- gray
- neutral tones

These are examples only.

Do NOT limit the implementation to these colors.

The implementation must make it easy to add more colors later.

---

# 2. COLOR ARCHITECTURE

Create a centralized calendar color system.

For example:

lib/
  theme/
    calendar_colors.dart

or integrate into the existing theme architecture if an appropriate location already exists.

Do NOT create a second independent theme system.

The existing application theme remains the source of truth for:

- application background
- surfaces
- primary actions
- typography
- borders
- dialogs
- controls
- Light/Dark mode

The Calendar color system should specifically manage:

- event colors
- reminder category colors
- calendar markers
- event chips
- schedule blocks
- selected event states
- calendar indicators

Do not hard-code colors inside individual Calendar widgets.

Bad:

Color(0xFF123456)

inside:

calendar_day_cell.dart

Instead:

CalendarColors.someCategory

or an equivalent centralized mechanism.

---

# 3. COLOR ADAPTATION

Calendar colors must work in both Light and Dark modes.

Do not simply use the same color value unchanged in every situation.

For every calendar event color, consider:

Light Mode:
- background
- foreground/text
- border
- icon

Dark Mode:
- background
- foreground/text
- border
- icon

The event must remain clearly identifiable in both themes.

The existing application-wide theme already defines Light, Dark, and System modes. Integrate with that system rather than creating another theme mechanism.

Do not modify the application's existing theme architecture unless necessary.

---

# 4. COLOR CONTRAST

Accessibility and readability take priority over decorative color.

For every event color:

- text must remain readable
- icons must remain visible
- event boundaries must remain identifiable
- selected states must be obvious
- disabled states must remain understandable

Do not use extremely bright saturated backgrounds behind small text.

Prefer a relationship such as:

strong color identity
+
soft/tinted event surface
+
appropriate foreground color

The Calendar should feel colorful without becoming visually noisy.

---

# 5. EVENT COLOR VARIETY

The user should be able to visually distinguish different categories of reminders/events.

For example:

Work
Personal
Family
Health
Finance
Study
Travel
Meetings
Tasks
Important reminders

These categories are examples only.

Do not force users into these categories unless the existing application already supports categories.

The visual architecture should support future categories.

If the existing Reminder model has a category/color field, reuse it.

If it does not, do not unnecessarily modify the Reminder model as part of the UI redesign.

---

# 6. VISUAL DESIGN LANGUAGE

The Calendar should have:

- modern productivity-app aesthetics
- clean spacing
- strong hierarchy
- thin separators
- subtle surfaces
- rounded event cards
- soft event backgrounds
- compact controls
- readable typography
- information density without clutter
- minimal but purposeful shadows
- smooth transitions

Do NOT make the UI overly decorative.

Do NOT use gradients everywhere.

Do NOT use excessive glassmorphism.

Do NOT make every component colorful.

Use color primarily to communicate calendar information.

---

# 7. CALENDAR SCREEN STRUCTURE

The Calendar should occupy almost the entire available screen.

Do NOT use the previous narrow two-pane layout.

The calendar itself is the main workspace.

Overall structure:

------------------------------------------------
TOP HEADER
------------------------------------------------

------------------------------------------------
CALENDAR CONTENT
------------------------------------------------

------------------------------------------------
FLOATING ACTION BUTTON
------------------------------------------------

The bottom navigation, if already present in Smaraṇa, must remain compatible with the new Calendar design.

---

# 8. TOP HEADER

Create a clean modern calendar header.

Suggested structure:

[Calendar/Menu Icon]     September 2026       [View] [...]

The exact layout can be adapted to the available screen width.

The header should contain:

LEFT:
- Calendar/navigation icon

CENTER:
- Current month and year

RIGHT:
- View selector
- More options

Do not make the header excessively tall.

---

# 9. MONTH NAVIGATION

Support:

- Previous month
- Next month
- Today

Possible interaction:

<    September 2026    >

Do not make navigation controls visually dominant.

The current month/year should remain the primary header information.

If the application already has month navigation logic, reuse it.

---

# 10. VIEW SELECTOR

The top view icon must allow the user to change Calendar presentation.

Available views:

1. Month + Week
2. Next 3 Days
3. Month Only

Example:

Calendar View

✓ Month + Week

  Next 3 Days

  Month Only

The currently selected view must be clearly highlighted.

The interaction can be:

- Popup menu
- Dropdown
- Bottom sheet
- Compact menu

Use whichever best fits the existing Smaraṇa UI architecture.

Do not navigate to an unrelated settings screen.

Changing views should happen immediately.

---

# 11. VIEW ENUMERATION

Use a clean view state.

Example:

enum CalendarViewType {
  monthAndWeek,
  nextThreeDays,
  monthOnly,
}

Adapt this to the existing architecture if an equivalent already exists.

Do not create duplicate state systems.

---

# 12. DEFAULT VIEW — MONTH + WEEK

The default Calendar view is:

MONTH + WEEK

This view combines:

1. Full month grid
2. Detailed weekly agenda

The month grid should occupy the upper portion of the screen.

The weekly agenda should appear below it.

Conceptually:

------------------------------------------------
September 2026                       [View] [...]
------------------------------------------------

Mon   Tue   Wed   Thu   Fri   Sat   Sun
------------------------------------------------
 1     2     3     4     5     6     7

     •          •           •
------------------------------------------------
 8     9    10    11    12    13    14

 •          •          •
------------------------------------------------
15    16    17    18    19    20    21

      •     •
------------------------------------------------
22    23    24    25    26    27    28
------------------------------------------------
29    30

------------------------------------------------
THIS WEEK
------------------------------------------------

Mon 29

09:00   ● Team Meeting
11:30   ● Project Review
14:30   ● Client Call

Tue 30

10:00   ● Development
15:00   ● Planning

------------------------------------------------

The exact layout must adapt to the mobile screen.

---

# 13. MONTH GRID

The month grid is one of the most important components.

Requirements:

- 7 columns
- Monday/Sunday configuration should follow the existing application behavior
- thin grid lines
- clearly defined cells
- readable date numbers
- current date indicator
- selected date indicator
- previous/next month dates
- event/reminder indicators
- weekend differentiation where appropriate

Do not make grid lines heavy.

Use thin, subtle separators.

The grid should feel similar to a professional productivity application.

---

# 14. DATE CELL

Create a reusable:

CalendarDayCell

Each date cell should support:

- date number
- current-day state
- selected state
- event indicators
- reminder indicators
- recurrence indicators
- overflow indicator

Example:

15

● Meeting
● Workout
+2

Do not overcrowd cells.

If there are too many events:

15

● Meeting
● Workout
+3 more

Tapping the date should open the relevant daily schedule.

---

# 15. CURRENT DATE

The current day must be visually obvious.

Use a distinct treatment such as:

- circular highlight
- subtle filled background
- outline
- accent indicator

Do not rely only on color.

The current date should remain understandable in:

- Light Mode
- Dark Mode
- Month + Week
- Next 3 Days
- Month Only

---

# 16. SELECTED DATE

The selected date must be visually different from the current date.

Do not confuse:

CURRENT DATE

with:

SELECTED DATE

If today is selected, combine the two states elegantly.

Use:

- shape
- border
- background
- typography
- indicator

rather than relying on color alone.

---

# 17. WEEKLY AGENDA

The weekly section should show detailed reminders/events.

Each event may contain:

- time
- title
- description
- event color
- alarm indicator
- recurrence indicator

Example:

09:30

┌────────────────────────────┐
│ ● Morning Workout          │
│   Exercise                 │
└────────────────────────────┘

14:00

┌────────────────────────────┐
│ ● Project Review           │
│   Weekly recurrence        │
└────────────────────────────┘

Event colors should be visually meaningful.

Do not use one color for all events.

Do not hard-code event colors inside the event widget.

---

# 18. NEXT 3 DAYS VIEW

Create a dedicated:

NEXT 3 DAYS

view.

This is a focused planning view.

Display the next three calendar days.

Example:

------------------------------------------------
Tue 29        Wed 30        Thu 1
------------------------------------------------

09:00         09:00         09:00

Meeting       Coffee        Project

10:00         10:00         10:00

              Development

11:00                       Client Call

12:00

13:00         13:00

              Lunch

14:00         Review        Presentation

15:00

16:00                       Project

------------------------------------------------

Use a vertical time-based schedule.

Each day should be visually separated.

Events should appear as colored blocks.

The current day should receive stronger visual emphasis.

---

# 19. THREE-DAY TIME AXIS

The Next 3 Days view should support:

- hourly time labels
- event blocks
- current-time indicator
- scrolling
- overlapping events
- multiple events
- long-duration events

The view should automatically position itself near the current time when practical.

Do not force the user to scroll from midnight every time.

Use efficient Flutter rendering.

---

# 20. MONTH ONLY VIEW

Create a:

MONTH ONLY

view.

This view should maximize the month grid.

There should be no detailed weekly agenda competing for space.

Conceptually:

------------------------------------------------
September 2026                    [View] [...]
------------------------------------------------

Mon Tue Wed Thu Fri Sat Sun

------------------------------------------------
 1   2   3   4   5   6   7
     ●       ●       ●
------------------------------------------------
 8   9  10  11  12  13  14
 ●       ●       ●
------------------------------------------------
15  16  17  18  19  20  21
------------------------------------------------
22  23  24  25  26  27  28
------------------------------------------------
29  30

The grid should use almost the entire screen.

---

# 21. MONTH ONLY EVENT DISPLAY

Month Only mode should show high-level information.

For example:

15

● Meeting
● Workout
● Payment

If there are too many events:

15

● Meeting
● Workout
+3 more

Tapping the overflow should reveal the day's events.

Do not attempt to display complete descriptions inside the month grid.

---

# 22. EVENT CARDS

Create a reusable event component.

For example:

CalendarEventCard

The component should support:

- color
- title
- time
- description
- alarm
- recurrence
- selected state
- compact mode
- expanded mode

The component should work across:

- Month + Week
- Next 3 Days
- Month Only

where appropriate.

---

# 23. EVENT COLORS

Event colors must be independent from the application's primary brand color.

The application may use Smaraṇa's brand identity for:

- primary actions
- navigation
- selected controls
- FAB
- major UI elements

But events should have their own rich visual categorization.

Do NOT force every event to use Smaraṇa blue.

Do NOT force every event to use the same color.

Do NOT create a tiny palette solely because the brand has a small palette.

The Calendar should support a broad visual spectrum.

---

# 24. EVENT COLOR GENERATION

If the application does not currently have event colors, create a centralized color palette or category-color resolver.

For example:

CalendarColorResolver

It may expose functionality such as:

getEventColor(event)

or:

getCategoryColor(category)

The resolver must:

- return visually distinct colors
- work in Light Mode
- work in Dark Mode
- maintain contrast
- remain deterministic
- avoid random colors on every rebuild

Do not generate a different color every time the widget rebuilds.

---

# 25. ALARM INDICATORS

Smarana supports reminders and alarms.

Calendar events should visually communicate when an alarm or notification is enabled.

Example:

🔔 Team Meeting

or:

Team Meeting       [alarm icon]

The exact icon should follow the existing application iconography.

Do not create a second alarm system.

Use the existing alarm/reminder state.

---

# 26. RECURRENCE

Existing recurrence functionality must continue working.

Supported recurrence may include:

- none
- daily
- weekly
- biweekly
- alternate weeks
- monthly
- alternate months
- yearly

Do not modify recurrence business logic as part of this redesign unless absolutely necessary.

The Calendar should only change how recurring reminders are displayed.

Recurring events must appear correctly in all relevant views.

---

# 27. ADD REMINDER

Keep the existing floating "+" button.

The button should:

- remain easily accessible
- not cover calendar information
- open the existing Add Reminder flow

Do not rebuild Add Reminder functionality as part of this Calendar redesign.

When a user taps an empty date/time area, pre-fill the selected date/time where supported by the existing implementation.

---

# 28. EVENT INTERACTION

When the user taps an existing event:

Open the existing reminder/event details UI.

Do not create duplicate reminder logic.

When the user taps a date:

Select that date.

When the user taps an empty time:

Use the existing Add Reminder functionality where possible.

---

# 29. LIGHT MODE

The Calendar must integrate with the existing application Light Theme.

Use:

- light neutral background
- white or lightly tinted calendar surfaces
- subtle borders
- readable dark text
- colorful event surfaces
- appropriate selected states

Do not make the entire screen pure white.

Use visual hierarchy between:

Background
Calendar surface
Date cells
Event cards
Selected states

Do not introduce a separate Light Theme for Calendar.

---

# 30. DARK MODE

The Calendar must integrate with the existing application Dark Theme.

Do NOT simply invert the Light UI.

Use:

- dark neutral background
- slightly lighter calendar surface
- subtle separators
- readable light text
- adjusted event colors
- appropriate contrast

Event colors should remain visually distinct.

Avoid overly bright neon colors unless they are intentionally toned down for dark surfaces.

---

# 31. SYSTEM THEME

Use the application's existing System/Light/Dark theme mechanism.

Do not create independent Calendar theme switching.

The Calendar should automatically follow:

System
Light
Dark

according to the application's global theme.

---

# 32. RESPONSIVE DESIGN

The Calendar is primarily mobile-first.

Support:

- small Android phones
- large Android phones
- tablets where practical

Do not hard-code screen dimensions.

Use:

- LayoutBuilder
- MediaQuery
- Flexible
- Expanded
- Slivers
- CustomScrollView

where appropriate.

The Calendar must not overflow horizontally.

---

# 33. TYPOGRAPHY

Use the application's existing typography system.

Prioritize:

- clear date numbers
- readable month title
- compact event text
- clear time labels
- strong hierarchy
- appropriate font weights

Do not introduce a new font system just for Calendar.

---

# 34. GRID LINES

Grid lines should be:

- thin
- subtle
- visible
- consistent

Do not remove grid lines completely.

Do not make grid lines dark/heavy.

Grid lines should help the user understand the calendar structure without dominating the interface.

---

# 35. WEEKEND TREATMENT

Weekend cells can receive subtle visual differentiation.

Do not make weekends dramatically different.

Use:

- subtle surface tint
- typography treatment
- very light background distinction

The treatment must work in both Light and Dark modes.

---

# 36. TODAY BUTTON

Provide an easy way to return to today.

Possible location:

- month header
- More menu
- calendar navigation

Do not add unnecessary UI if the existing application already has Today functionality.

---

# 37. ANIMATION

Use subtle transitions when changing:

- calendar month
- selected date
- view mode
- event expansion

For view switching use:

AnimatedSwitcher

or another appropriate Flutter transition.

Animations should be:

- fast
- smooth
- professional

Do not use excessive animations.

---

# 38. PERFORMANCE

The Calendar may eventually contain many reminders.

Avoid:

- unnecessary rebuilds
- expensive operations inside build()
- repeated recurrence calculations
- repeated date conversions
- large unnecessary widget trees

Separate:

calendar data processing

from:

calendar rendering

If recurring events must be expanded, do so outside individual day cells.

Use efficient Flutter widgets.

---

# 39. DATA INTEGRATION

Before modifying the Calendar:

Inspect the existing application.

Identify:

- Reminder model
- Reminder storage
- Recurrence model
- Notification service
- Alarm service
- Calendar screen
- Navigation
- Theme system
- State management

Reuse existing implementations.

Do not create duplicate data models.

---

# 40. NO FAKE PERMANENT DATA

Do not replace the real Smaraṇa reminder data with mock data.

Temporary mock data may be used during UI development only.

If mock data is created:

- isolate it
- clearly identify it
- make it easy to remove

The final Calendar must use real application data.

---

# 41. ARCHITECTURE

Before creating files, inspect the existing project structure.

Do not blindly create a new architecture.

A possible structure is:

lib/

  calendar/

    calendar_screen.dart

    widgets/

      calendar_header.dart

      calendar_view_selector.dart

      month_calendar_grid.dart

      calendar_day_cell.dart

      calendar_event_chip.dart

      weekly_agenda.dart

      three_day_view.dart

      month_only_view.dart

      calendar_event_card.dart

      calendar_time_axis.dart

    models/

      calendar_view_type.dart

    theme/

      calendar_colors.dart

Adapt this to the existing Smaraṇa project structure.

Reuse existing widgets when appropriate.

---

# 42. STATE MANAGEMENT

Use the application's existing state-management approach.

If the project already uses:

- Provider
- Riverpod
- Bloc
- Cubit
- ChangeNotifier
- another established approach

continue using it.

Do not introduce another state-management package only for Calendar.

The selected Calendar view must have a single source of truth.

---

# 43. CALENDAR VIEW STATE

The selected view should be represented by a single state.

Example:

enum CalendarViewType {
  monthAndWeek,
  nextThreeDays,
  monthOnly,
}

The default must be:

monthAndWeek

The selected view should remain consistent while navigating within the Calendar.

---

# 44. VIEW SWITCHING

Switching between:

Month + Week
Next 3 Days
Month Only

must not reload the entire application.

Only the Calendar content should change.

Use smooth transitions where appropriate.

The top header should remain stable.

---

# 45. MONTH + WEEK VIEW BEHAVIOR

When Month + Week is selected:

1. Show the complete month grid.
2. Show high-level event information in the grid.
3. Show detailed weekly agenda below.
4. Selecting a date updates the weekly agenda.
5. Current week should be emphasized.
6. Current day should remain visible.
7. Existing reminders must be displayed.

The weekly section should correspond to the selected date.

---

# 46. NEXT 3 DAYS VIEW BEHAVIOR

When Next 3 Days is selected:

1. Determine the current/selected starting date.
2. Display three consecutive dates.
3. Show time-based events.
4. Display event duration.
5. Display alarms.
6. Display recurrence where appropriate.
7. Support vertical scrolling.
8. Highlight current time.
9. Keep the current day visually prominent.

---

# 47. MONTH ONLY VIEW BEHAVIOR

When Month Only is selected:

1. Maximize the month grid.
2. Display high-level events.
3. Do not show the detailed weekly agenda.
4. Keep the month navigation.
5. Keep the view selector.
6. Keep date selection.
7. Allow the user to open detailed day information.

---

# 48. CURRENT TIME INDICATOR

For time-based views such as Next 3 Days:

Display a current-time indicator when appropriate.

Example:

──────────── 11:42 AM ────────────

The indicator should be subtle but easy to find.

It should update appropriately.

Do not create unnecessary continuous rebuilds if the application does not require second-level precision.

---

# 49. OVERLAPPING EVENTS

The Next 3 Days view should account for overlapping events.

If two events overlap:

- display them side-by-side where practical
- preserve readable titles
- preserve event colors
- avoid one event completely covering another

Do not implement an unnecessarily complex scheduling engine if the current application does not require it.

---

# 50. ACCESSIBILITY

Verify:

- text contrast
- event contrast
- icon visibility
- selected states
- current-day state
- focus states
- disabled states
- alarm indicators

Do not rely on color alone to communicate important information.

For example:

An alarm-enabled event should not be distinguishable only because it is red.

Use:

- icon
- text
- shape
- position
- color

where appropriate.

---

# 51. COLOR ACCESSIBILITY

Because the Calendar intentionally supports many colors:

Do not assume every user can distinguish colors easily.

Important information must remain understandable without color perception.

For example:

Event:

[Alarm Icon] Project Review

should remain understandable even if the event color is not distinguishable.

Use icons, labels, patterns, borders, or text where necessary.

---

# 52. NO HARD-CODED UI COLORS

Avoid:

Colors.black
Colors.white
Colors.blue
Colors.red

when the value should be theme-aware or calendar-category-aware.

Prefer:

Theme.of(context).colorScheme

and:

CalendarColors

or an equivalent centralized system.

Hard-coded colors are acceptable only when they represent a deliberate semantic color that is centrally defined.

Do not scatter hexadecimal color values throughout widgets.

---

# 53. BRAND COLORS

Smaraṇa's existing application theme already defines the application's brand identity.

The Calendar should respect that system.

However:

DO NOT force the entire Calendar to use only the brand colors.

Use brand colors for:

- primary actions
- navigation
- FAB
- selected controls
- important UI controls

Use a broader calendar color system for:

- events
- reminders
- categories
- schedules

This separation is intentional.

---

# 54. NO COLOR RESTRICTION

This is a critical requirement.

The Calendar must NOT be implemented as:

Blue events
Purple events
Green events

only.

It must be architecturally capable of supporting a rich multi-color calendar.

The exact palette should remain configurable.

Do not hard-code the number of colors.

Do not hard-code the available categories.

The color system should be extensible.

---

# 55. MICROSOFT-STYLE VISUAL INSPIRATION

Take visual inspiration from Microsoft productivity applications:

- information-rich calendar cells
- colorful event categorization
- clean surfaces
- compact cards
- clear hierarchy
- subtle borders
- strong alignment
- professional typography
- efficient use of screen space

Do NOT clone Microsoft's UI.

Do NOT use Microsoft's branding.

Do NOT use Microsoft logos or proprietary assets.

Create a distinct Smaraṇa visual identity.

---

# 56. FLOATING ACTION BUTTON

Keep the existing Smaraṇa Add Reminder FAB.

Requirements:

- modern
- compact
- accessible
- visually connected to application branding
- does not obstruct important calendar content

Use the existing theme's primary color where appropriate.

---

# 57. BOTTOM NAVIGATION

If the application already has bottom navigation:

Preserve it.

Calendar should remain integrated with:

- Notes
- Alarms
- Stopwatch
- Timer

Do not redesign those screens as part of this task.

Only make the Calendar visually compatible with the existing application.

---

# 58. DO NOT CHANGE BUSINESS LOGIC

Do not modify:

- reminder storage
- recurrence calculations
- notification scheduling
- alarm scheduling
- reminder creation logic
- reminder editing logic
- reminder deletion logic

unless a very small compatibility change is absolutely required.

The primary task is UI/UX redesign.

---

# 59. IMPLEMENTATION PROCESS

Work in phases.

## PHASE 1 — INSPECT

Before making changes:

Inspect the existing project.

Identify:

1. Calendar screen
2. Reminder model
3. Recurrence model
4. Reminder storage
5. Notification service
6. Alarm service
7. Theme implementation
8. Navigation
9. State management

Do not modify code during this phase.

Report what you found.

---

## PHASE 2 — CALENDAR DESIGN SYSTEM

Create or integrate:

- Calendar view model/state
- Calendar color system
- Calendar event presentation model if necessary
- Calendar day cell
- Calendar event component
- Calendar header
- View selector

Do not duplicate existing models unnecessarily.

---

## PHASE 3 — MONTH + WEEK

Implement the default view.

Verify:

- month grid
- week agenda
- selected date
- current date
- event colors
- alarm indicators
- recurrence
- month navigation

---

## PHASE 4 — NEXT 3 DAYS

Implement:

- three-day columns
- time axis
- event blocks
- current-time indicator
- scrolling
- overlapping events
- event colors

---

## PHASE 5 — MONTH ONLY

Implement:

- large month grid
- high-level events
- overflow indicators
- date selection
- month navigation

---

## PHASE 6 — VIEW SELECTOR

Implement:

Month + Week
Next 3 Days
Month Only

The default is:

Month + Week

---

## PHASE 7 — REAL DATA

Connect every Calendar view to the existing Smaraṇa reminder data.

Verify recurring reminders.

Verify alarms.

Verify notifications.

Verify date selection.

---

## PHASE 8 — THEME

Verify the Calendar in:

- Light
- Dark
- System

Do not create a separate Calendar theme.

---

## PHASE 9 — RESPONSIVE TESTING

Test:

- small Android phone
- large Android phone
- tablet if available

Check:

- overflow
- spacing
- text truncation
- event cards
- grid
- time axis
- FAB

---

# 60. TESTING

Run:

flutter analyze

Fix all errors.

Fix warnings introduced by this work.

Then test:

### Month + Week

- month navigation
- date selection
- weekly agenda
- reminders
- alarms
- recurrence

### Next 3 Days

- correct dates
- time axis
- events
- current time
- scrolling
- overlapping events

### Month Only

- complete month
- event indicators
- selected date
- overflow events

### Colors

Test multiple event colors.

Test Light Mode.

Test Dark Mode.

Verify readable contrast.

### Existing functionality

Verify:

- create reminder
- edit reminder
- delete reminder
- alarm
- notification
- recurrence
- persistence
- navigation

---

# 61. PERFORMANCE TEST

Verify that:

- scrolling remains smooth
- changing months is responsive
- switching views is responsive
- large numbers of reminders do not cause obvious lag
- recurring reminders do not cause excessive rebuilds

Avoid unnecessary calculations inside build().

---

# 62. FINAL QUALITY REQUIREMENT

The Calendar should NOT look like:

- a basic date picker
- a generic Flutter calendar package
- a simple grid of numbers
- a single-color calendar
- a screen with excessive empty space

It should look like a professional productivity workspace.

The visual hierarchy should be:

Smaraṇa
↓
Month / Date
↓
Calendar Grid
↓
Events
↓
Detailed Schedule

---

# 63. FINAL USER EXPERIENCE

The user should be able to open Smaraṇa and immediately understand:

- What day is today?
- What month am I viewing?
- Which dates contain reminders?
- What is scheduled this week?
- What is coming in the next three days?
- Which reminders have alarms?
- Which reminders belong to different categories?

The three views provide three different planning modes:

DEFAULT:

Month + Week

For broad planning plus detailed weekly scheduling.

FOCUS:

Next 3 Days

For immediate upcoming work.

OVERVIEW:

Month Only

For seeing the entire month at a glance.

---

# 64. IMPORTANT IMPLEMENTATION RULE

Do not implement the design only as a visual mockup.

All views must use real Smaraṇa data.

Do not break existing functionality to achieve the visual design.

Do not replace working services unnecessarily.

Do not introduce duplicate models.

Do not introduce unnecessary dependencies.

Reuse the existing architecture wherever possible.

---

# 65. FINAL REPORT

After implementation report:

1. Files created
2. Files modified
3. Calendar architecture
4. View architecture
5. Color architecture
6. How Light/Dark/System themes are handled
7. How event colors are handled
8. How recurrence is displayed
9. How alarms are displayed
10. Any hard-coded colors remaining
11. `flutter analyze` result
12. Any warnings
13. Any limitations
14. Any recommended next steps

Do not declare the redesign complete until all three Calendar views work with the existing Smaraṇa reminder data.