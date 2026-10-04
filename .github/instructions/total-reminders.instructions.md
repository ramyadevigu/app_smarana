---
applyTo: "**"
description: "Project-wide instructions for the Total Reminders Flutter application"
---

# Total Reminders — Project Instructions

## 1. Product Vision

Total Reminders is a premium personal productivity application built with Flutter.

Core areas:

- Calendar
- Notes
- Reminders
- Alarms
- Stopwatch
- Timer
- Settings

The application should feel like a polished first-party mobile productivity application.

Target qualities:

**Premium · Smooth · Elegant · Modern · Responsive · Intuitive · Reliable**

Use applications such as Apple Calendar, Apple Notes, Google Calendar, Google Keep, Microsoft Teams, and Microsoft Planner only as UX inspiration. Do not copy proprietary layouts, branding, logos, or assets.

Total Reminders must maintain its own visual identity.

---

# 2. PRIMARY DEVELOPMENT PRINCIPLE

Before changing code:

1. Inspect the existing implementation.
2. Understand the architecture.
3. Identify reusable components.
4. Identify state management.
5. Identify theme architecture.
6. Identify existing models and services.
7. Identify navigation.
8. Identify persistence.
9. Identify notification and alarm behavior.
10. Identify relevant tests.

Do not make assumptions when the existing project can answer the question.

Understand first. Modify second.

---

# 3. PRESERVE EXISTING FUNCTIONALITY

UI redesign must not unnecessarily change business logic.

Preserve existing:

- Reminder model
- Reminder storage
- Recurrence logic
- Notification scheduling
- Alarm functionality
- Persistence
- Navigation
- State management
- Timer functionality
- Stopwatch functionality
- Notes functionality
- Calendar data
- User data

Do not create duplicate:

- Models
- Services
- Storage systems
- Notification systems
- State-management systems
- Theme systems

If existing functionality works, prefer improving or extending it rather than replacing it.

---

# 4. FLEXIBLE DESIGN SYSTEM

The design system must remain flexible.

Do NOT impose a fixed global color palette.

Do NOT require the application to use only:

- blue
- purple
- green
- pastel colors
- a predefined number of colors
- any older palette specified in previous instructions

Colors are a design tool, not an architectural restriction.

The application may use:

- Primary colors
- Secondary colors
- Accent colors
- Semantic colors
- Category colors
- Surface colors
- Tonal variants
- Gradients
- Highlights
- Contextual colors
- Light-mode-specific colors
- Dark-mode-specific colors

Use colors according to the design objective and context.

### Important

There is **NO global restriction on colors**.

However, unrestricted color usage does not mean random color usage.

Colors must remain:

- Harmonious
- Intentional
- Professional
- Accessible
- Consistent
- Contextually meaningful

---

# 5. THEME ARCHITECTURE

Maintain one centralized theme architecture.

Use semantic theme roles instead of scattering arbitrary colors across widgets.

Possible roles include:

- primary
- secondary
- tertiary
- accent
- background
- surface
- surfaceVariant
- elevatedSurface
- card
- textPrimary
- textSecondary
- divider
- border
- success
- warning
- error
- info
- selected
- disabled
- focus

These names are examples. Adapt them to the existing project.

Do not create separate theme implementations for individual screens.

---

# 6. LIGHT MODE

Light Mode must be intentionally designed.

Do not make every surface pure white.

Use appropriate:

- surface hierarchy
- tonal variation
- borders
- shadows
- elevation
- typography
- accent colors

Light Mode should feel bright, clean, elegant, and easy to read.

---

# 7. DARK MODE

Dark Mode must be designed independently.

Do NOT simply invert Light Mode.

Do not blindly replace:

`white → black`

or:

`black → white`

Dark Mode should have its own:

- surface hierarchy
- tonal elevation
- contrast strategy
- accent treatment
- border treatment
- typography hierarchy
- selected states

---

# 8. COLOR USAGE

Avoid arbitrary hard-coded colors when a value represents a theme role.

Prefer:

```dart
Theme.of(context).colorScheme
```

or the project's centralized theme system.

Hard-coded colors are acceptable when they represent:

- deliberate illustrations
- fixed semantic indicators
- icon assets
- centralized design tokens
- category colors
- controlled gradients
- design-specific visual elements

Do not turn the "no hard-coded colors" principle into a restriction that prevents legitimate design work.

---

# 9. PREMIUM UI/UX STANDARD

Every major screen should have:

### Clear hierarchy

The user should immediately understand:

- where they are
- what is important
- what they can do
- what the primary action is

### Excellent spacing

Avoid:

- cramped layouts
- excessive empty space
- inconsistent margins
- inconsistent padding

### Strong typography

Maintain clear hierarchy between:

- page titles
- section titles
- body text
- metadata
- captions
- actions

### Reusable components

Create reusable components when they improve consistency.

Do not create abstractions merely for abstraction's sake.

---

# 10. ANIMATION AND INTERACTION

The application should feel fluid.

Use appropriate animations for:

- navigation
- page transitions
- tab changes
- date selection
- calendar navigation
- note creation
- note editing
- expanding/collapsing sections
- dialogs
- bottom sheets
- menus
- selection states
- theme changes
- list insertion/removal

Animations should generally be:

- smooth
- responsive
- purposeful
- short enough to feel immediate
- accessible

Do not animate everything.

Do not use animations that interfere with typing, scrolling, or accessibility.

---

# 11. NOTES

Notes should feel like a premium first-party note-taking application.

Prioritize:

- clean note list
- note cards
- note previews
- search
- filtering
- pinning
- creation
- editing
- deletion
- empty states
- smooth transitions
- focused editing

Notes may use richer color expression where appropriate.

Do not make every note visually identical.

Do not make every note visually loud.

---

# 12. NOTE EDITOR

The editor should prioritize the user's content.

Avoid unnecessary labels and visual clutter.

The title should feel naturally integrated into the editor.

Formatting controls should be lightweight and contextual.

Possible formatting controls include:

- bold
- italic
- underline
- text formatting
- bullets
- numbered lists

A floating or contextual formatting toolbar is acceptable when it improves the editing experience.

Do not make the editor unnecessarily resemble a desktop word processor.

---

# 13. CALENDAR

The Calendar should feel like a professional planning workspace rather than a basic date picker.

Calendar views must use the existing reminder/calendar data.

Do not create a parallel Calendar data system.

Prioritize:

- readability
- information hierarchy
- smooth navigation
- useful event visualization
- clear date states
- responsive layout
- fast interactions

Calendar colors are NOT restricted to a fixed palette.

Use event/category colors according to context, accessibility, and visual hierarchy.

---

# 14. REMINDERS AND ALARMS

Preserve existing reminder and alarm behavior.

Reminder UI should clearly communicate:

- title
- date
- time
- recurrence
- enabled/disabled state
- alarm/notification state

Do not rely on color alone to communicate important states.

Do not create duplicate scheduling services.

---

# 15. ACCESSIBILITY

Important information must never depend only on color.

Use combinations of:

- icon
- text
- typography
- shape
- border
- position
- color

Maintain appropriate contrast in both Light and Dark modes.

Maintain comfortable touch targets.

Support readable text sizes.

---

# 16. RESPONSIVE DESIGN

The application is mobile-first.

Support:

- small Android phones
- large Android phones
- tablets where practical

Avoid unnecessary fixed dimensions.

Prefer:

- `LayoutBuilder`
- `MediaQuery`
- `Flexible`
- `Expanded`
- `SafeArea`
- `CustomScrollView`
- Slivers

where appropriate.

Avoid horizontal overflow.

Design for different text lengths and screen sizes.

---

# 17. PERFORMANCE

Premium visual design must remain performant.

Avoid:

- unnecessary rebuilds
- expensive work inside `build()`
- repeated recurrence calculations
- repeated date conversions
- unnecessary widget trees
- excessive blur
- excessive shadows
- excessive animations

Separate data processing from UI rendering where practical.

---

# 18. ARCHITECTURE

Keep these responsibilities separated:

- UI
- Models
- Services
- Persistence
- Recurrence
- Notifications
- Theme
- Navigation
- State management

Keep business logic outside widgets whenever practical.

Do not rebuild working services merely because the UI is being redesigned.

---

# 19. DEPENDENCIES

Before adding a package:

1. Inspect the existing project.
2. Check whether the capability already exists.
3. Prefer existing dependencies.
4. Prefer Flutter/Dart standard APIs when practical.
5. Add a dependency only when clearly justified.

Do not introduce a package merely for a visual effect that can reasonably be implemented with Flutter.

---

# 20. INVESTIGATION RULES

Do not perform broad repository-wide searches.

Focus on application source and configuration.

Inspect these locations first:

```text
lib/
test/
pubspec.yaml
android/
```

Also inspect relevant:

- theme files
- navigation files
- recurrence utilities
- state-management files
- Calendar files
- notification initialization
- Android notification configuration

Avoid searching:

- Flutter SDK
- Pub cache
- `.dart_tool/`
- `build/`
- generated files
- `node_modules/`
- system directories

---

# 21. IMPLEMENTATION WORKFLOW

For every requested feature, follow this sequence.

## Phase 1 — Inspect

Before changing code:

1. Identify relevant files.
2. Read the existing implementation.
3. Identify dependencies.
4. Identify models and services.
5. Identify state management.
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
- whether a service is necessary
- whether a dependency is necessary

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

Review warnings introduced by the change.

## Phase 5 — Test

Run the relevant application flow.

Test actual user interaction, not only compilation.

## Phase 6 — Visual Review

Review:

- Light Mode
- Dark Mode
- spacing
- typography
- colors
- animations
- transitions
- responsiveness
- accessibility
- empty states
- loading states
- error states

## Phase 7 — Final Review

Confirm:

- existing functionality still works
- no duplicate architecture was introduced
- no unnecessary dependency was added
- the design remains coherent
- the implementation remains maintainable

---

# 22. AGENT BEHAVIOR

Any coding agent operating in this repository must behave like a senior Flutter engineer and product designer.

The agent must:

- inspect before modifying
- understand before rewriting
- preserve working functionality
- reuse existing architecture
- use design judgment
- avoid rigid interpretations
- prefer reusable components
- consider Light and Dark modes
- consider accessibility
- consider responsiveness
- consider performance
- test affected functionality
- review visual consistency

The agent must NOT behave like a mechanical instruction executor.

When instructions provide principles rather than exact implementation details, use engineering and product-design judgment.

---

# 23. FLEXIBILITY RULE

These instructions define principles, not immutable UI specifications.

Future development may improve:

- colors
- layouts
- typography
- spacing
- animations
- component design
- navigation
- visual hierarchy

provided that:

1. The result remains coherent.
2. Existing functionality is preserved.
3. Accessibility is maintained.
4. Performance remains acceptable.
5. Architecture remains maintainable.
6. The user experience improves.

Do not preserve an old design decision merely because it appears in an older instruction.

When requirements conflict, prefer the newest explicit user requirement.

---

# 24. NO BLIND COMPLIANCE

If an instruction conflicts with:

- a newer user requirement
- the existing architecture
- accessibility
- performance
- platform conventions

resolve the conflict using engineering judgment.

Do not blindly follow outdated instructions.

---

# 25. GIT WORKFLOW

Make changes in small logical stages.

After each meaningful stage:

1. Run analysis.
2. Test the application.
3. Review changed files.
4. Review the diff.
5. Commit the completed logical change when the project workflow expects commits.

Use meaningful commit messages.

Examples:

```text
feat: improve calendar month navigation
feat: add floating note editor toolbar
fix: preserve reminder recurrence when editing
fix: correct calendar selected-date state
feat: improve dark mode surfaces
```

Do not create meaningless commits.

Do not commit generated build artifacts.

---

# 26. COMPLETION STANDARD

Do not consider a feature complete merely because:

- the code compiles
- `flutter analyze` passes
- the screen appears once
- a mockup looks correct

Completion requires applicable verification of:

- functional correctness
- visual consistency
- responsive behavior
- Light Mode
- Dark Mode
- interaction behavior
- persistence where applicable
- regression safety
- acceptable performance

---

# 27. FINAL PRODUCT STANDARD

The final application should feel:

**Premium**

**Smooth**

**Modern**

**Elegant**

**Intuitive**

**Fast**

**Reliable**

**Cohesive**

**Maintainable**

The design system must remain flexible enough for the application to evolve.

Never turn a temporary design decision into a permanent architectural restriction.
