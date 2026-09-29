---
applyTo: "**/*.dart"
description: Application-wide light, dark, and system theme
  implementation for the Smarana Flutter reminder app
name: Smarana Theme System
---

# Smaraṇa --- Theme System Instructions

## Objective

Implement a complete, maintainable application-wide theme system for the
Smaraṇa Flutter reminder app.

The application must support:

-   System theme
-   Light theme
-   Dark theme
-   Automatic system-theme detection
-   User-controlled theme selection
-   Persistent theme preference
-   Immediate theme switching without restarting the app

Do not change reminder, recurrence, storage, or notification behavior as
part of this work.

------------------------------------------------------------------------

## 1. Brand Color System

Use these brand colors consistently.

### Primary Colors

  Name         Hex         Usage
  ------------ ----------- --------------------------------------
  Deep Black   `#0B0F14`   Typography, structure, dark surfaces
  Royal Blue   `#0066FF`   Primary brand and actions
  Azure Blue   `#008CFF`   Secondary blue and UI accents
  Cyan Blue    `#00AEEF`   Highlights and energy

### Brand Gradient

Use the gradient selectively:

`#0038B8 → #0066FF → #00AEEF`

Use it only for:

-   Branding
-   Logo/orbital elements
-   Selected decorative elements
-   Premium visual accents

Do not use the gradient throughout the entire UI.

------------------------------------------------------------------------

## 2. Theme Architecture

Create a centralized theme implementation.

Preferred structure:

``` text
lib/
  theme/
    app_colors.dart
    app_theme.dart
```

If the project already has a suitable theme structure, reuse it instead
of creating duplicate files.

All reusable colors must be centralized.

Do not hard-code brand colors throughout widgets.

------------------------------------------------------------------------

## 3. Material 3

Use Material 3:

``` dart
ThemeData(
  useMaterial3: true,
)
```

The application should provide:

``` dart
theme: lightTheme,
darkTheme: darkTheme,
themeMode: selectedThemeMode,
```

Do not manually determine light/dark mode inside every widget.

Use Flutter's global theme system.

------------------------------------------------------------------------

## 4. Light Theme

Create a clean, modern light theme.

### Background

Use a very light neutral or blue-white background.

Avoid using pure white for every surface.

### Surface

Use white or a very light neutral.

### Brand

``` text
Primary:   #0066FF
Secondary: #008CFF
Tertiary:  #00AEEF
```

### Text

Primary text:

``` text
#0B0F14
```

Secondary text should use a muted dark gray/blue with sufficient
contrast.

### Cards

Cards should use:

-   Light surface
-   Subtle border
-   Subtle elevation where appropriate
-   Clear text contrast

### Buttons

Primary buttons should use Royal Blue with readable white text.

------------------------------------------------------------------------

## 5. Dark Theme

Create a deliberately designed dark theme.

Do not simply invert the light theme.

### Main Background

``` text
#0B0F14
```

Do not use pure `#000000` as the primary application background.

### Surfaces

Use progressively lighter dark blue/gray surfaces for:

-   Cards
-   Dialogs
-   Bottom sheets
-   Input containers
-   Elevated content

### Text

Primary text should be near-white.

Secondary text should be muted light gray/blue.

### Brand

Retain:

``` text
Primary:   #0066FF
Secondary: #008CFF
Tertiary:  #00AEEF
```

Adjust surrounding surfaces and foreground colors for readability.

------------------------------------------------------------------------

## 6. Theme Modes

Support exactly three user-selectable modes:

``` text
System
Light
Dark
```

Default:

``` text
System
```

### System

When System is selected:

-   Follow the operating system theme.
-   React automatically when the OS changes between light and dark.

### Light

Always use the light theme.

### Dark

Always use the dark theme.

------------------------------------------------------------------------

## 7. Theme Preference Persistence

Persist the user's theme selection locally.

Reuse the existing SharedPreferences implementation if the project
already uses it.

Do not modify the existing reminder storage format.

Store a separate preference such as:

``` text
themeMode = system
themeMode = light
themeMode = dark
```

Requirements:

-   Fresh installation → System
-   Select Light → persist Light
-   Select Dark → persist Dark
-   Select System → persist System
-   Restart application → restore selected mode

Theme preference must remain independent of reminder data.

------------------------------------------------------------------------

## 8. Application Startup

At application startup:

1.  Load the saved theme preference.
2.  If no preference exists, use System.
3.  Convert the preference to Flutter `ThemeMode`.
4.  Apply the selected mode globally.
5.  Build the application.

Avoid unnecessary asynchronous complexity.

Do not allow startup logic to break reminder functionality.

------------------------------------------------------------------------

## 9. Application-Level Source of Truth

Theme state must exist at application level.

Do not keep independent theme state inside individual screens.

If the project already uses Provider, Riverpod, Bloc, or another
state-management solution, follow the existing architecture.

If no state-management framework exists, use the simplest maintainable
solution.

Do not add a state-management package solely for theme switching unless
there is a strong architectural reason.

------------------------------------------------------------------------

## 10. Settings

Provide a Theme setting in the application's Settings screen.

If Settings already exists, add the option there.

If Settings does not exist, create a simple Settings screen.

Use a clear UI such as:

``` text
Appearance

Theme

○ System
○ Light
○ Dark
```

The selected mode must be visually obvious.

The change must apply immediately.

Do not add unrelated settings.

------------------------------------------------------------------------

## 11. Theme-Aware Existing Screens

Update existing UI so it works correctly in both themes.

At minimum inspect:

-   `RemindersScreen`
-   `AddReminderScreen`
-   Settings screen
-   AppBar
-   Reminder cards
-   Buttons
-   Text fields
-   Date picker
-   Time picker
-   Dialogs
-   Empty states
-   Error states
-   Floating action button
-   Menus and selectors

Prefer theme-aware properties:

``` dart
Theme.of(context).colorScheme.primary
Theme.of(context).colorScheme.surface
Theme.of(context).colorScheme.onSurface
Theme.of(context).colorScheme.onPrimary
Theme.of(context).colorScheme.secondary
```

Avoid unnecessary direct references such as:

``` dart
Colors.black
Colors.white
Colors.blue
```

when the color should respond to the active theme.

------------------------------------------------------------------------

## 12. Material ColorScheme

Build the themes around Material 3 `ColorScheme`.

Light mode:

``` text
primary   = #0066FF
secondary = #008CFF
tertiary  = #00AEEF
```

Dark mode should retain the same brand identity while using appropriate
dark surfaces and readable foreground colors.

Do not randomly alter the brand colors between themes.

------------------------------------------------------------------------

## 13. Component Behavior

### AppBar

Light mode:

-   Light surface
-   Dark text/icons

Dark mode:

-   Dark surface
-   Light text/icons

### Reminder Cards

Light mode:

-   Light surface
-   Dark text
-   Subtle border/elevation

Dark mode:

-   Dark elevated surface
-   Light text
-   Subtle border

### Primary Buttons

Use the brand blue.

Ensure readable button text in both themes.

### Text Fields

Light mode:

-   Light surface
-   Dark text
-   Visible border

Dark mode:

-   Dark surface
-   Light text
-   Visible border

### Date/Time Pickers

They must automatically use the active application theme.

### Dialogs

They must automatically use the active application theme.

------------------------------------------------------------------------

## 14. Immediate Theme Switching

When the user changes:

``` text
System → Light
Light → Dark
Dark → System
```

the entire application must update immediately.

A restart must not be required.

------------------------------------------------------------------------

## 15. Accessibility

Verify:

-   Text contrast
-   Button contrast
-   Icon visibility
-   Selected/unselected states
-   Disabled states
-   Text-field readability
-   Focus states
-   Error states

The UI must remain usable in both light and dark modes.

------------------------------------------------------------------------

## 16. Restrictions

Do not:

-   Modify the Reminder model
-   Modify recurrence calculations
-   Modify notification scheduling
-   Modify reminder storage structure
-   Add unnecessary packages
-   Create duplicate theme systems
-   Put theme state inside individual screens
-   Hard-code brand colors throughout widgets
-   Redesign unrelated application functionality
-   Change reminder behavior

This implementation is specifically for the application-wide theme
system.

------------------------------------------------------------------------

## 17. Testing

After implementation run:

``` bash
flutter analyze
```

Fix all errors and warnings introduced by the theme implementation.

Test the following:

### Fresh installation

-   Theme defaults to System.

### Light

-   Select Light.
-   UI changes immediately.
-   Restart application.
-   Light remains selected.

### Dark

-   Select Dark.
-   UI changes immediately.
-   Restart application.
-   Dark remains selected.

### System

-   Select System.
-   Change operating system theme.
-   Application follows the OS theme.

### Existing functionality

Verify that:

-   Reminders still load.
-   Reminders can still be created.
-   Reminders can still be edited.
-   Reminders can still be deleted.
-   Recurrence behavior is unchanged.
-   Notification behavior is unchanged.
-   Local persistence is unchanged.

------------------------------------------------------------------------

## 18. Implementation Workflow

Before making changes:

1.  Inspect the existing project.
2.  Identify existing theme code.
3.  Identify existing settings implementation.
4.  Identify existing SharedPreferences usage.
5.  Identify existing state-management approach.
6.  Reuse existing architecture where possible.

Then implement the theme system.

After implementation:

1.  Run `flutter analyze`.
2.  Fix errors.
3.  Fix warnings introduced by this work.
4.  Test System mode.
5.  Test Light mode.
6.  Test Dark mode.
7.  Test persistence.
8.  Test existing reminder functionality.

------------------------------------------------------------------------

## 19. Final Report

After implementation, report:

1.  Files created.
2.  Files modified.
3.  Theme architecture.
4.  Theme persistence approach.
5.  How System/Light/Dark works.
6.  Any remaining hard-coded colors.
7.  `flutter analyze` result.
8.  Any limitations.

Do not declare the feature complete unless System, Light, and Dark modes
work correctly and the selected preference survives application restart.
