---
name: app-developer
target: vscode
model: GPT-6 Luna (copilot)
tools: [execute, read, agent, Dart-Code.dart-code/get_dtd_uri, Dart-Code.dart-code/dart_format, Dart-Code.dart-code/dart_fix, edit, search, web, browser, 'dart-sdk-mcp-server/*', todo]
applyTo: "**"
description: "Project-wide instructions for the Total Reminders Flutter application"
---

# Total Reminders — Copilot Instructions

## 1. Project

This is a Flutter-based Android reminder and calendar application.

The app is local-first and should work without an internet connection.

Primary goals:

- Simple UI
- Reliable reminders
- Reliable recurring reminders
- Reliable Android notifications and alarms
- Clean and maintainable Flutter code

Do not over-engineer the application.


## 2. Version 1 Features

Implement only the following features unless explicitly requested otherwise:

- Calendar
- Create reminder
- Edit reminder
- Delete reminder
- Complete reminder
- Enable/disable reminder
- One-time reminders
- Daily recurrence
- Weekly recurrence
- Monthly recurrence
- Yearly recurrence
- Custom recurrence where required
- Monthly specific date, e.g. 3rd of every month
- Monthly last-day recurrence
- Notifications
- Alarm-style reminders
- Snooze
- Upcoming reminders
- Search
- Basic settings
- Light/dark/system theme

Do not add unrelated features.


## 3. Out of Scope

Do not implement these unless explicitly requested:

- User accounts
- Cloud sync
- Backend
- Google Calendar integration
- Microsoft Calendar integration
- AI features
- Social features
- Payments
- Subscriptions
- Advertising
- Web application
- iOS application


## 4. Technology

Use:

- Flutter
- Dart
- Riverpod
- Drift/SQLite for local storage
- `flutter_local_notifications` for notifications where appropriate

Use Android APIs when Flutter plugins cannot provide the required reliability.

Do not add dependencies unless they are genuinely required.


## 5. Architecture

Use a simple feature-oriented architecture.

Preferred structure:

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── theme.dart
├── core/
│   ├── services/
│   ├── constants/
│   └── utils/
├── database/
└── features/
    ├── calendar/
    ├── reminders/
    └── settings/
````

Keep:

* UI
* Business logic
* Database
* Notification scheduling

separate.

Do not put business logic directly inside widgets.


## 6. State Management

Use Riverpod.

Keep providers focused on a specific responsibility.

Avoid creating a single global provider containing the entire application state.


## 7. Reminder Model

A reminder should contain, as required:

```text
id
title
description
date/time
reminder type
recurrence rule
enabled
status
createdAt
updatedAt
```

Scheduling information should be managed separately where practical.

The database is the source of truth.

Android scheduled notifications/alarms are derived from the database.


## 8. Recurrence

Recurrence is a core part of the application.

Support:

```text
None
Daily
Weekly
Monthly
Yearly
Custom
```

Monthly recurrence must support:

```text
Specific day
Last day of month
```

Example:

```text
3rd of every month
```

should produce:

```text
January 3
February 3
March 3
...
```

Example:

```text
Last day of every month
```

must correctly handle:

```text
28 days
29 days
30 days
31 days
```

Leap years must be handled correctly.

Keep recurrence calculation in a dedicated service/domain component.

Do not calculate recurrence inside UI widgets.


## 9. Recurring Completion

Completing a recurring reminder completes the current occurrence only.

It must calculate and schedule the next occurrence.

Example:

```text
Every month on the 3rd

September 3 → Completed
October 3 → Scheduled
```

Do not mark the entire recurring reminder as permanently completed.


## 10. Scheduling

Notification/alarm scheduling must stay synchronized with the database.

When a reminder is:

* Created
* Edited
* Deleted
* Disabled
* Completed
* Snoozed

the corresponding scheduled notification/alarm must be updated.

Never leave an old notification/alarm active after a reminder is edited or deleted.


## 11. Android Requirements

The application must account for Android-specific behavior including:

* Notification permission
* Exact alarms where required
* Alarm scheduling
* Device reboot
* Timezone changes
* Device clock changes
* Battery restrictions

Do not assume that scheduled alarms always survive device restart.

After reboot, active reminders should be loaded and rescheduled when necessary.

Do not use a continuously running background timer for reminders.


## 12. Snooze

Support:

```text
5 minutes
10 minutes
15 minutes
30 minutes
1 hour
Custom
```

Snooze must not modify the original recurrence rule.

Example:

```text
Every day at 8:00 AM

Snooze → 15 minutes

Current trigger → 8:15 AM
Original recurrence → 8:00 AM
```

## 13. Date and Time

Use proper Dart date/time handling.

Do not store formatted display strings as the canonical date/time.

Consider:

* Month boundaries
* Leap years
* Timezones
* Device clock changes
* Past occurrences

Recurring rules should remain the source for calculating future occurrences.

## 14. UI

Keep the UI simple and practical.

Primary navigation:

```text
Calendar
Reminders
Settings
```

The calendar should be the main entry point.

Reminder creation should be straightforward:

```text
Title
Description
Date
Time
Repeat
Reminder Type
Sound
Vibration
Save
```

Use reusable widgets for common components.

Avoid unnecessary animations, complex navigation, and visual clutter.


## 15. Coding Standards

Follow standard Dart and Flutter practices.

Use:

* Strong typing
* `const` where appropriate
* Small reusable widgets
* Async/await
* Meaningful names
* Clear error handling

Avoid:

* `dynamic` unless necessary
* Giant widgets
* Business logic in UI
* Duplicate logic
* Unnecessary abstractions
* Unnecessary dependencies

Run:

```bash
dart format .
flutter analyze
flutter test
```

after meaningful changes.

## 16. Testing

Prioritize tests for the reminder engine.

At minimum, test:

* Daily recurrence
* Weekly recurrence
* Monthly recurrence
* Yearly recurrence
* Monthly specific dates
* Last day of month
* Leap years
* Recurring completion
* Snooze
* Reminder CRUD

Notification/alarm behavior should also be tested on an Android device when practical.


## 17. Copilot Agent Workflow

Before implementing a feature:

1. Inspect the existing code.
2. Understand the current architecture.
3. Identify affected files.
4. Implement the smallest reliable change.
5. Format the code.
6. Run analyzer/tests.
7. Fix errors.
8. Summarize what changed.

Do not rewrite working code unnecessarily.

Do not create large amounts of code before understanding the existing implementation.


## 18. Requirements

If a requirement is ambiguous and could change user-visible behavior, ask for clarification.

Examples:

* What should happen when a monthly date does not exist?
* What should happen to missed reminders?
* What should happen after a timezone change?
* What should happen when notification permission is denied?

For minor implementation details, make a sensible engineering decision rather than unnecessarily asking.


## 19. Development Principle

Prioritize:

```text
Correctness
Reliability
Simplicity
Maintainability
User experience
```

Do not optimize for the amount of code produced.

Build the application incrementally.

A small, reliable implementation is preferred over a large, over-engineered implementation.

```

**This is the version I would actually use** for `.github/copilot-instructions.md`. It gives Copilot enough product context to make good decisions without burying the Agent under dozens of rules.
```
