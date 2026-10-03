# Total Reminders Calendar — Complete UI/UX Redesign Instructions

## Objective

Completely redesign the existing Total Reminders Calendar screen.

The new Calendar experience should closely follow the interaction flow, spacing, hierarchy, visual simplicity, and transition behavior shown in the provided reference screenshots.

The goal is:

- Simple
- Clean
- Space-efficient
- Modern
- Premium
- Minimal visual noise
- Very smooth interactions
- Excellent use of the available mobile screen
- Calendar remains the primary focus
- Countdown/reminder information remains secondary
- No unnecessary cards, borders, panels, or decorative elements

Do NOT preserve the existing calendar layout if it conflicts with these requirements.

---

# 1. Overall Calendar Structure

The Calendar screen should have this structure:

```text
┌─────────────────────────────────────────────┐
│                                             │
│  October                    [View] [View] ⋮ │
│                                             │
│  Sun    Mon    Tue    Wed    Thu    Fri Sat│
│                                             │
│   27     28     29     30      1      2   3│
│    4      5      6      7      8      9  10│
│   11     12     13     14     15     16  17│
│   18     19     20     21     22     23  24│
│   25     26     27     28     29     30  31│
│    1      2      3      4      5      6   7│
│                                             │
│                                             │
│              Calendar / events              │
│                                             │
│                                             │
│                                             │
│                         ┌──────────┐        │
│                         │    +     │        │
│                         └──────────┘        │
│                                             │
│  Bottom navigation                          │
└─────────────────────────────────────────────┘
```

The calendar grid should occupy most of the available vertical space.

Do not unnecessarily constrain the calendar into a small card.

Do not use a two-pane calendar layout.

Do not place a large permanent right-side timeline next to the month grid.

The month calendar itself should be the dominant visual element.

---

# 2. Header

The header must be extremely clean.

## Left side

Display the current displayed month name.

Example:

```text
October
```

The month name must be clickable.

Do NOT make the month name look like a traditional button.

It should visually appear as simple text with a subtle interaction state.

When the user taps the month name:

- Open month/year navigation.
- Allow navigating to another month.
- Keep the interaction lightweight.
- Use a smooth animated transition.
- Do not open an unnecessarily large full-screen dialog.

The month name should remain visually dominant compared with secondary controls.

---

# 3. Header — Right Side

Place exactly three primary controls on the top-right.

Conceptually:

```text
October                         [View 1] [View 2] ⋮
```

The three controls are:

### Control 1 — Calendar/List View

Used to change the calendar presentation.

### Control 2 — Alternate Calendar View

Used to switch between the supported calendar modes.

### Control 3 — More

Use a vertical three-dot icon.

The More button should contain secondary calendar actions/settings.

Examples:

- Go to Today
- Calendar settings
- Manage calendars
- Other secondary actions

Do not clutter the header with text labels.

Use icons.

---

# 4. Month Grid

The month grid is the most important component on the screen.

Use a clean 7-column layout:

```text
Sun   Mon   Tue   Wed   Thu   Fri   Sat
```

The seven columns should use the available width efficiently.

The grid should feel spacious without wasting vertical space.

## Weekday labels

Weekday labels should be:

- Small
- Secondary
- Low visual emphasis
- Center aligned

Do not use large bold weekday labels.

---

# 5. Date Numbers

Date numbers should be:

- Clear
- Center aligned
- Easy to tap
- Consistent in size
- Visually lightweight

Do not put every date inside a bordered box.

Do not create visible heavy grid borders.

The calendar should feel open and clean.

Maintain enough spacing to make each date an individual tappable target.

---

# 6. Current Date vs Selected Date

This behavior is VERY IMPORTANT.

There are two independent states:

1. Today's date
2. Currently selected date

They must not be treated as the same state.

## Initial state

When the calendar opens:

Today's date is selected.

Therefore:

```text
Today = blue filled circle
```

Example:

```text
                 1      [2]      3
```

Use a blue circular background.

The date number should use the appropriate contrasting foreground color.

---

# 7. Selecting Another Date

When the user taps another date:

The selected date becomes blue.

The current date loses its blue selection background and becomes white/neutral.

Example:

```text
Today:
     2 = white/neutral

Selected:
    15 = blue circle
```

More explicitly:

```text
October

     1     2     3
           ↑
        neutral

    14   [15]   16
          ↑
       selected
```

Never display two blue selected circles simply because one is Today and one is selected.

There must always be ONE primary blue selection.

Today's date can be visually distinguished when another date is selected, but it should not compete with the selected date.

---

# 8. Selected Date Animation

When the user taps another date:

Do NOT instantly switch the blue circle.

Animate the transition.

The blue selection indicator should smoothly move from the previous date to the new date.

Preferred behavior:

```text
Old selected date
      ↓
Blue circle smoothly moves
      ↓
New selected date
```

Use a polished Material-style animation.

Recommended:

- 180–250 ms
- Curved animation
- Ease-out / emphasized deceleration
- No abrupt flashing

The date text should transition smoothly as well.

---

# 9. Today State

If the user selects another date:

Today's date should become neutral.

Example:

```text
              October

Sun Mon Tue Wed Thu Fri Sat

27  28  29  30   1   2   3
                         ↑
                      neutral

4   5   6   7    8   9  10

11  12  13  14  [15] 16 17
                  ↑
               blue selected
```

If the user selects Today again:

Today becomes the blue selected circle.

---

# 10. Dates From Adjacent Months

Dates belonging to the previous or next month should remain visible when necessary to complete the calendar grid.

Example:

```text
27  28  29  30   1   2   3
```

The 27–30 belong to the previous month.

Adjacent-month dates should have reduced visual emphasis:

- Lower opacity
- Secondary text color
- Still tappable

Prefer a stable 6-row month grid when that produces smoother layout consistency.

---

# 11. Calendar Height

The calendar should use the screen efficiently.

Do not leave a large amount of empty space immediately below the calendar unless the content area is genuinely empty.

The calendar should remain visually anchored toward the top.

The vertical rhythm should feel similar to the reference screenshots.

---

# 12. Countdown Section

The Countdown section must be expandable/collapsible.

It should NOT always consume a fixed large amount of space.

The user must be able to drag it vertically.

Conceptually:

```text
Calendar
──────────────
      Countdown
         ↕
   draggable area
Countdown content
```

The Countdown area should behave like a bottom sheet / expandable panel.

---

# 13. Countdown Drag Behavior

The Countdown panel must support:

### Collapsed

```text
Calendar
Calendar
Calendar
────────────
Countdown
```

### Partially expanded

```text
Calendar
Calendar
────────────
Countdown
Countdown item
Countdown item
```

### Fully expanded

```text
Calendar
──────

Countdown
Countdown items
Countdown items
Countdown items
```

The panel must respond smoothly to vertical dragging.

Do not make the user drag a tiny invisible area.

Provide a clear draggable region.

---

# 14. Countdown Handle

Add a subtle drag handle at the top of the Countdown panel.

Example:

```text
────────
   ━━━
Countdown
```

The handle should be:

- Small
- Subtle
- Rounded
- Low contrast

Do not use a large heavy divider.

---

# 15. Countdown Animation

The Countdown panel should use smooth physics.

Recommended:

- Spring-based animation
- Natural deceleration
- Snap points
- No abrupt jumps

Suggested snap positions:

```text
Collapsed
    ↓
Half
    ↓
Expanded
```

When the user releases the panel, it should naturally settle into the nearest appropriate snap point.

---

# 16. Countdown and Calendar Relationship

The calendar must remain visually stable while the Countdown panel moves.

Do NOT allow the Countdown panel to permanently distort the calendar layout.

The calendar should smoothly resize or be visually revealed/covered depending on the panel state.

Avoid:

- Sudden jumps
- Layout flickering
- Text repositioning
- Calendar rebuilding visibly during drag

Use animated layout changes.

---

# 17. Empty Calendar State

If the selected date contains no reminders/events:

Show a clean empty state.

Use the style shown in the reference:

```text
        [small calendar illustration]

             You have a free day

                Take it easy
```

The empty state should be centered within the available content area.

Do not make the illustration excessively large.

Do not introduce unnecessary cards.

---

# 18. Event/Reminder State

If the selected date contains reminders:

Replace the empty-state message with the day's reminders.

Example:

```text
08:00   Morning Exercise
09:30   Team Meeting
12:30   Lunch
18:00   Project Review
```

Use a clean timeline/list.

Avoid large cards for every reminder.

Use compact rows with:

- Time
- Reminder title
- Optional category/color indicator
- Optional recurrence indicator

---

# 19. Floating Action Button

Keep a floating `+` button.

It should remain accessible regardless of calendar state.

Position: bottom-right.

The button should:

- Be circular
- Have strong visual contrast
- Use the application's primary color
- Have subtle elevation/shadow
- Maintain a comfortable touch target

Tap behavior:

```text
+
 ↓
Create Reminder / Quick Reminder / Event
```

Use a smooth scale/fade animation when opening the creation UI.

---

# 20. Bottom Navigation

Keep the existing Total Reminders bottom navigation architecture.

Calendar must be highlighted when active.

The active icon should use the application's primary/accent color.

Inactive icons should use a muted neutral color.

Do not redesign the entire bottom navigation unless required for consistency.

The Calendar screen should integrate naturally with:

- Notes
- Alarms
- Stopwatch
- Timer

---

# 21. Dark Theme

Implement a polished dark theme.

Use:

- Near-black background
- White primary text
- Muted gray secondary text
- Blue primary selection
- Subtle gray surfaces
- No excessive borders

Avoid pure white surfaces in dark mode.

Avoid excessive gradients.

---

# 22. Light Theme

Light theme should be equally polished.

Use:

- Very light neutral background
- Dark primary text
- Gray secondary text
- Blue selected date
- Subtle surfaces
- Minimal shadows

Do not simply invert the dark theme.

Light mode should be intentionally designed.

---

# 23. Color System

Do NOT hard-code arbitrary colors throughout the Calendar widgets.

Use the existing Total Reminders theme system.

Create/use semantic colors such as:

```dart
primary
onPrimary
surface
surfaceContainer
background
onBackground
onSurface
secondaryText
mutedText
selectedDate
todayDate
divider
eventColor
```

Do not introduce a new unrelated color palette.

The selected date should use the existing application primary/accent color.

---

# 24. Typography

Use the application's existing typography.

Hierarchy:

### Month

Large / prominent.

### Weekdays

Small / muted.

### Dates

Medium / clear.

### Event titles

Medium weight.

### Secondary information

Small / muted.

Do not use oversized typography except where intentionally used for empty-state messaging.

---

# 25. Responsive Layout

The Calendar must work across:

- Small Android phones
- Large Android phones
- Different aspect ratios
- Different font scales
- Light mode
- Dark mode

Do not hard-code absolute screen coordinates.

Use:

- LayoutBuilder
- MediaQuery
- Flexible
- Expanded
- Slivers where appropriate
- SafeArea

---

# 26. Smooth Navigation Between Months

When the user changes month:

Do not instantly replace the calendar.

Use a subtle horizontal transition.

Swipe left:

```text
October → November
```

Swipe right:

```text
October ← September
```

Use a short, smooth transition.

Do not use excessive animation.

---

# 27. Swipe Gesture

Support horizontal swipe gestures on the calendar.

```text
Swipe left  → Next month
Swipe right → Previous month
```

The gesture should feel natural.

Avoid conflicts between:

- Horizontal month swipe
- Vertical Countdown drag
- Date tap

Gesture handling must be carefully separated.

---

# 28. Today Navigation

Provide a quick way to return to Today.

When the user navigates away from the current month/date:

The UI should make "Today" accessible through the More menu or existing calendar controls.

When Today is selected:

- Restore current month
- Restore current date
- Select today
- Smoothly animate the transition

---

# 29. Date Selection Behavior

When tapping a date:

1. Update `selectedDate`.
2. Animate selection indicator.
3. Update the content below the calendar.
4. Display reminders for the selected date.
5. If there are no reminders, show the empty state.
6. Preserve the current month unless an adjacent-month date was selected.
7. If an adjacent-month date is selected, automatically navigate to that month using a smooth transition.

Example:

```text
October calendar
November 1

Tap November 1
       ↓
November 2026
November 1 becomes selected
```

Do not create an abrupt page reload.

---

# 30. State Architecture

Separate these states:

```dart
DateTime displayedMonth;
DateTime selectedDate;
DateTime today;

bool isCountdownExpanded;

double countdownPanelExtent;

CalendarViewMode calendarViewMode;
```

Do NOT use one variable for:

- displayed month
- selected date
- today

These are different concepts.

---

# 31. Critical State Rule

The following is valid:

```dart
today != selectedDate
```

Example:

```text
today = October 2
selectedDate = October 15
```

Visual result:

```text
October 2  → neutral
October 15 → blue selected circle
```

If:

```dart
selectedDate == today
```

then Today receives the blue selected circle.

There must only be one primary blue selected-date indicator.

---

# 32. Animation Architecture

Use Flutter's animation framework properly.

Prefer:

- AnimatedContainer
- AnimatedAlign
- AnimatedPositioned
- AnimatedSize
- AnimatedSwitcher
- TweenAnimationBuilder
- PageView / custom page transition
- DraggableScrollableSheet where appropriate
- AnimationController where precise control is required

Do not use unnecessary animation packages unless already present in the project.

All animations must remain performant.

---

# 33. Animation Timing

Use consistent animation timing.

Suggested values:

```dart
dateSelectionDuration = 200ms;
monthTransitionDuration = 250ms;
countdownSnapDuration = 300ms;
contentTransitionDuration = 200ms;
```

Use appropriate curves:

```dart
Curves.easeOutCubic
Curves.easeInOutCubic
```

For draggable/spring interactions use physics-based behavior where appropriate.

---

# 34. Avoid Rebuild Problems

Do not rebuild the entire Calendar screen on every small interaction.

Changing:

```text
selectedDate
```

should not unnecessarily rebuild:

- Bottom navigation
- unrelated screens
- application shell
- reminder database
- Countdown data

Use localized state management.

---

# 35. Accessibility

Every interactive control must have:

- Semantic label
- Adequate touch target
- Visible selected state
- Sufficient contrast

Dates must be individually accessible.

Example:

```text
October 15, 2026, Thursday, selected
```

Today:

```text
October 2, 2026, Friday, today
```

Both:

```text
October 2, 2026, Friday, today, selected
```

---

# 36. Visual Rules

The Calendar must NOT contain:

- Heavy borders
- Excessive cards
- Excessive rounded rectangles
- Large decorative headers
- Unnecessary gradients
- Excessive shadows
- Oversized icons
- Large permanent timeline panels
- Excessive spacing
- Random colors

Visual language:

```text
Minimal
Modern
Clean
Calm
Dense but readable
Premium
```

---

# 37. Exact Interaction Flow

## Step 1 — Calendar opens

```text
October

Sun Mon Tue Wed Thu Fri Sat

27 28 29 30 1 [2] 3
4  5  6  7  8  9 10
11 12 13 14 15 16 17
18 19 20 21 22 23 24
25 26 27 28 29 30 31

Countdown
```

Today is selected.

## Step 2 — User taps October 15

Before:

```text
2 = blue
15 = normal
```

After:

```text
2 = neutral
15 = blue
```

The blue selection indicator moves smoothly.

## Step 3 — User drags Countdown upward

Countdown expands.

Calendar smoothly gives way to the expanded Countdown content.

No abrupt jump.

## Step 4 — User drags Countdown downward

Countdown collapses.

Calendar becomes dominant again.

## Step 5 — User taps month name

Month navigation appears.

User can select another month/year.

Transition must be smooth.

## Step 6 — User swipes left

Navigate to next month:

```text
October → November
```

## Step 7 — User taps adjacent-month date

Tap November 1 from the October grid.

Automatically navigate to November and select November 1.

---

# 38. Match the Reference Interaction, Not Just the Screenshot

Do not merely reproduce the visual appearance.

Reproduce the interaction model:

- Minimal header
- Month name on left
- Three compact controls on right
- Large clean calendar grid
- Single blue selection indicator
- Today becomes neutral when another date is selected
- Smooth selection movement
- Expandable Countdown
- Draggable Countdown
- Smooth month navigation
- Clean empty state
- Floating action button
- Bottom navigation
- Dark/light theme
- No unnecessary UI chrome

The application should feel like the same class of polished productivity calendar shown in the reference images.

---

# 39. Code Quality Requirements

Before modifying code:

1. Inspect the existing Calendar implementation.
2. Identify existing models.
3. Identify existing reminder/event storage.
4. Identify existing theme implementation.
5. Identify existing navigation.
6. Identify existing bottom navigation.
7. Reuse existing data models wherever possible.
8. Do not duplicate reminder models.
9. Do not break existing reminder functionality.
10. Do not modify unrelated screens.

Suggested structure:

```text
calendar/
├── calendar_screen.dart
├── widgets/
│   ├── calendar_header.dart
│   ├── calendar_grid.dart
│   ├── calendar_day_cell.dart
│   ├── countdown_panel.dart
│   ├── calendar_empty_state.dart
│   └── calendar_event_list.dart
├── models/
│   └── calendar_view_mode.dart
└── utils/
    └── calendar_utils.dart
```

Adapt this to the existing project architecture rather than blindly creating duplicate files.

---

# 40. Do Not Break Existing Functionality

Existing functionality must continue to work:

- Create reminder
- Edit reminder
- Delete reminder
- Recurring reminders
- Daily reminders
- Weekly reminders
- Monthly reminders
- Yearly reminders
- Reminder notifications
- Alarm functionality
- Existing persistence
- Existing navigation
- Dark/light mode

Do not replace working business logic just to redesign the UI.

---

# 41. Final Acceptance Criteria

### Header

- [ ] Month name appears on the left.
- [ ] Month name is clickable.
- [ ] Three compact controls appear on the right.
- [ ] Header is clean and compact.

### Calendar

- [ ] Calendar occupies most of the screen.
- [ ] 7-column month grid.
- [ ] Adjacent month dates are visible.
- [ ] Date numbers are easy to tap.
- [ ] No heavy grid borders.
- [ ] No unnecessary cards.

### Selection

- [ ] Today is initially blue.
- [ ] Selecting another date moves blue selection.
- [ ] Previous selection becomes neutral.
- [ ] Today becomes neutral when another date is selected.
- [ ] Selecting Today restores blue Today selection.
- [ ] Selection animation is smooth.

### Navigation

- [ ] Month navigation works.
- [ ] Horizontal swipe works.
- [ ] Adjacent-month date selection works.
- [ ] Today navigation works.
- [ ] No abrupt transitions.

### Countdown

- [ ] Countdown is draggable.
- [ ] Countdown supports collapsed state.
- [ ] Countdown supports intermediate state.
- [ ] Countdown supports expanded state.
- [ ] Dragging feels natural.
- [ ] Calendar responds smoothly.

### Empty State

- [ ] Empty selected dates show a clean empty state.
- [ ] Empty state does not dominate the screen.

### Theme

- [ ] Dark mode is polished.
- [ ] Light mode is polished.
- [ ] Existing application theme is respected.
- [ ] No arbitrary hard-coded colors.

### Performance

- [ ] No visible flicker.
- [ ] No unnecessary full-screen rebuilds.
- [ ] Month transition is smooth.
- [ ] Date selection is smooth.
- [ ] Countdown drag is smooth.

### Existing Functionality

- [ ] Existing reminder functionality remains intact.
- [ ] Existing alarm functionality remains intact.
- [ ] Existing persistence remains intact.
- [ ] Bottom navigation remains intact.

---

# 42. Most Important Design Principle

DO NOT make the calendar look like a generic Flutter calendar package.

It should feel like a purpose-built premium productivity application.

Visual hierarchy:

```text
1. Month / Calendar
2. Selected Date
3. Events / Reminders
4. Countdown
5. Secondary controls
```

The interface should immediately answer:

- Where am I in the calendar?
- Which date is selected?
- What do I have on that date?
- How do I add a reminder?

without requiring the user to learn the interface.

---

# 43. Implementation Priority

Implement in this order:

1. Calendar screen structure
2. Header
3. Month grid
4. Today/selected-date state
5. Smooth selection animation
6. Month navigation and swipe
7. Empty/event states
8. Draggable Countdown
9. Floating action button
10. Theme integration
11. Accessibility
12. Performance optimization

After each major step, verify that existing reminder functionality still works.

Do not proceed by creating a mock-only UI. The redesigned Calendar must remain connected to the application's real reminder/event data.
