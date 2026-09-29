---
applyTo: "**"
description: "Project-wide instructions for the local-first Flutter reminder app"
---
# Smaraṇa — Flutter Reminder App

## Project Goal

Build a reliable Flutter reminder application called **Smaraṇa**.

The application allows users to:

* Create reminders
* Edit reminders
* Delete reminders
* View reminders
* Set a date and time
* Add optional descriptions
* Create recurring reminders
* Support daily, weekly, monthly and yearly recurrence
* Persist reminders locally
* Schedule notifications
* Trigger notifications even when the application is closed
* Handle recurring reminders correctly
* Display the next occurrence of recurring reminders
* Avoid duplicate notifications
* Provide a simple, clean and reliable UI

## Technology

* Flutter
* Dart
* Material 3
* SharedPreferences for local persistence
* flutter_local_notifications for notifications
* timezone for timezone-aware scheduling
* uuid for reminder IDs

## Architecture

Use a simple layered architecture:

lib/
main.dart
models/
reminder.dart
screens/
reminders_screen.dart
add_reminder_screen.dart
services/
reminder_storage.dart
notification_service.dart
utils/
recurrence_utils.dart

Keep UI, models, persistence, recurrence calculations and notification scheduling separate.

## Important Rules

1. Do not rewrite working code unnecessarily.
2. Before modifying a file, inspect the existing implementation.
3. Preserve existing functionality.
4. Do not introduce duplicate models or services.
5. Do not create multiple competing implementations of the same feature.
6. Use null-safe Dart.
7. Avoid deprecated Flutter APIs.
8. Do not use `print()` for production logging.
9. Handle errors gracefully.
10. Keep the UI simple.
11. Do not add unnecessary packages.
12. Run `flutter analyze` after significant changes.
13. Run the application and test the changed functionality.
14. Do not mark a feature complete until it has been tested.
15. When a requirement is ambiguous, inspect the existing project before making assumptions.

## Reminder Model

A reminder must have:

* id
* title
* description
* scheduled date/time
* recurrence type
* recurrence configuration
* enabled/active state

Supported recurrence types:

* none
* daily
* weekly
* monthly
* yearly

Examples:

One-time:

15 October 2026 at 09:30 AM

Daily:

Every day at 09:30 AM

Weekly:

Every Monday at 09:30 AM

Monthly:

3rd day of every month at 09:30 AM

Yearly:

15 October every year at 09:30 AM

## Recurrence Requirements

Monthly recurrence must correctly handle months with different numbers of days.

For example:

31st of every month

If a month does not contain day 31, do not create an invalid date.

The recurrence logic must be centralized in one utility/service.

## Persistence

All reminders must survive application restart.

Saving, loading, updating and deleting reminders must use the same storage service.

Storage format must be versionable and safely decoded.

Corrupted stored data must not crash the application.

## Notification Requirements

Notifications must:

* use a unique notification ID
* contain reminder title
* contain reminder description when available
* respect the selected date/time
* work when the application is closed
* work for recurring reminders
* avoid duplicate scheduling
* be cancelled when a reminder is deleted
* be rescheduled when a reminder is edited
* be cancelled when a reminder is disabled

## UI Requirements

The application should have:

### Reminders Screen

Display:

* application title
* list of reminders
* reminder title
* description if available
* scheduled date/time
* recurrence information
* enabled/disabled state
* add button

Tapping a reminder opens the edit screen.

Long press or an appropriate menu can provide delete functionality.

### Add/Edit Reminder Screen

Fields:

* Title
* Description
* Date
* Time
* Recurrence

The same screen should support both creating and editing.

Use clear validation.

Title is required.

## Code Quality

Prefer small functions with one responsibility.

Do not put storage, recurrence calculations or notification scheduling directly inside widgets.

Before completing a task:

1. Run `flutter analyze`.
2. Fix all errors.
3. Review warnings.
4. Test the relevant user flow.
5. Explain what changed.

## Git Workflow

Make changes in small logical stages.

After each completed stage:

* run analysis
* test the application
* review changed files
* commit the changes

Use meaningful commit messages.

Example:

feat: implement recurring reminder model

fix: correct monthly recurrence calculation

feat: add local notification scheduling

## Completion Criteria

The application is complete only when the following work:

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
11. Receive notification when app is closed
12. Edit notification schedule
13. Delete notification
14. Disable notification
15. Re-enable notification
16. Handle invalid recurrence dates
17. Handle application restart
18. Handle corrupted local storage safely
19. No duplicate notifications
20. `flutter analyze` passes without errors

Do not declare the project complete until all applicable requirements have been verified.

Do not perform a broad package/dependency search.

Do not search:

* Flutter SDK
* Pub cache
* .dart_tool
* build/
* generated files
* node_modules
* system directories

Only inspect the application's source code under:

lib/
test/
pubspec.yaml
android/

Start with these files if they exist:

lib/main.dart
lib/models/reminder.dart
lib/screens/reminders_screen.dart
lib/screens/add_reminder_screen.dart
lib/services/reminder_storage.dart

Do not modify any files.

Do not run rip_grep_packages.

Do not perform a repository-wide dependency search.

Run only:

flutter analyze

Then report:

1. Current architecture
2. Existing reminder model
3. Existing storage implementation
4. Existing AddReminderScreen
5. Existing RemindersScreen
6. Existing notification implementation
7. Current errors
8. What should be implemented next

Keep the investigation focused and finish quickly.
