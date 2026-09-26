---
applyTo: "**"
description: "Project-wide instructions for the local-first Flutter reminder app"
---

# Smarana Reminder App

Build this Android-first Flutter app as a simple, reliable, offline-first reminder
and calendar application. The highest-priority product requirement is that an
active reminder triggers at its intended local date and time.

## Scope

Implement only these Version 1 capabilities unless the user explicitly expands
the scope:

- Calendar with month navigation, date selection, today, reminder indicators, and
  reminders for the selected date
- Create, read, edit, delete, enable/disable, and complete reminders
- One-time, daily, weekly, monthly, yearly, and custom recurrence
- Monthly recurrence on a specific day or the last day of the month
- Normal notifications, alarm-style reminders, sound, vibration, permissions,
  and snooze (5, 10, 15, 30 minutes, 1 hour, or custom)
- Upcoming reminders grouped as Today, Tomorrow, and Upcoming
- Local search over title and description
- Basic notification, appearance (light/dark/system), and about settings

Do not add accounts, cloud sync, backends, calendar integrations, AI, social
features, payments, advertising, web support, or iOS support unless explicitly
requested.

## Technology and Structure

Use the existing Flutter/Dart project and conventions. Prefer:

- Riverpod for focused state providers
- Drift/SQLite as the local source of truth
- `flutter_local_notifications` where appropriate
- Isolated Android APIs for exact alarms, full-screen intents, and reboot recovery

Keep responsibilities separate:

```text
UI -> Riverpod/ViewModel -> domain/services -> repository -> database
```

Do not put business logic or recurrence calculations in widgets. Keep
notification and alarm scheduling in dedicated services. Do not add a dependency
unless the SDK or an existing dependency cannot solve the problem.

Follow the existing feature-oriented layout:

```text
lib/
  main.dart
  app/
  core/
  features/
    calender/
    reminders/
    settings/
```

The current shell already contains Calendar, Reminders, and Settings, with
Calendar as the initial screen. Preserve it unless the requested change requires
otherwise.

## Data and Reliability Rules

The database is the source of truth; scheduled notifications and alarms are
derived state. Store canonical `DateTime` values, never formatted date strings.
A reminder model should include:

```text
id, title, description, startDateTime, reminderType, recurrenceType,
recurrenceData, isEnabled, isCompleted, createdAt, updatedAt
```

Repositories must keep persistence separate from UI and support create, read by
ID, list, update, and delete.

When a reminder is created, edited, deleted, enabled, disabled, completed, or
snoozed, synchronize its schedule. Editing cancels the old schedule before
creating the new one; deletion cancels it. Never leave obsolete schedules active.

Recurrence must correctly handle month lengths, leap years, local time, past
occurrences, and clock/time-zone changes. A missing monthly date must follow one
consistent, tested product rule. Keep recurrence rules unchanged by snooze.
Completing a recurring reminder completes only the current occurrence and
calculates the next one; it must not permanently complete the rule.

Account for app foreground/background/termination, locked devices, reboot,
timezone changes, clock changes, notification permission, exact-alarm permission,
and battery restrictions. Do not use a continuously running Flutter timer.
After reboot, load active reminders from the database and reschedule them.

## Implementation Order

Work incrementally and avoid jumping ahead without an explicit request:

1. Local database
2. Reminder model and repository CRUD
3. Create/edit reminder UI
4. Calendar and selected-date reminders
5. Recurrence engine
6. Notification/alarm scheduling
7. Completion, recurring completion, and snooze
8. Upcoming reminders and search
9. Settings, reboot recovery, and timezone/clock handling
10. Tests and UI refinement

## Coding and UX Standards

- Follow the applicable Dart/Flutter instructions and existing project style.
- Prefer strong types, immutable models, `const`, small widgets, meaningful
  names, async/await, and clear error handling.
- Avoid unnecessary abstractions, duplicate logic, giant widgets, and `dynamic`.
- Keep the UI practical, uncluttered, and consistent with the existing shell.
- Show simple user-facing errors; never silently discard database, scheduling,
  permission, or validation failures, and never show stack traces.
- Ask for clarification only when an ambiguity changes user-visible behavior;
  otherwise make a conservative decision and test it.
- Do not rewrite unrelated working code or remove existing user changes.

## Validation

After meaningful changes:

1. Format changed Dart files with `dart format`.
2. Run `flutter analyze`.
3. Run focused tests, then `flutter test` when appropriate.

Prioritize tests for CRUD, daily/weekly/monthly/yearly recurrence, specific and
last-day monthly recurrence, leap years, recurring completion, snooze, past
occurrences, and scheduling synchronization. Test notification/alarm behavior on
a real Android device when practical.

Before finishing, confirm that the change is within scope, business logic is out
of widgets, old schedules are cancelled, and the relevant validation passes.
