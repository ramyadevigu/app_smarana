import '../../reminders/models/reminder.dart';

/// Repeat choices offered when attaching a reminder to a note.
///
/// Biweekly and alternate weeks (and alternate months vs. monthly) map to the
/// same underlying [RecurrenceRule] shape, just with different labels for
/// clarity in the note editor.
enum NoteRepeatOption {
  doesNotRepeat,
  daily,
  weekly,
  biweekly,
  monthly,
  alternateWeeks,
  alternateMonths,
  yearly;

  String get label => switch (this) {
    NoteRepeatOption.doesNotRepeat => 'Does not repeat',
    NoteRepeatOption.daily => 'Daily',
    NoteRepeatOption.weekly => 'Weekly',
    NoteRepeatOption.biweekly => 'Biweekly',
    NoteRepeatOption.monthly => 'Monthly',
    NoteRepeatOption.alternateWeeks => 'Alternate weeks',
    NoteRepeatOption.alternateMonths => 'Alternate months',
    NoteRepeatOption.yearly => 'Yearly',
  };

  RecurrenceRule toRecurrenceRule(DateTime dateTime) => switch (this) {
    NoteRepeatOption.doesNotRepeat => const RecurrenceRule(
      type: RecurrenceType.none,
    ),
    NoteRepeatOption.daily => const RecurrenceRule(type: RecurrenceType.daily),
    NoteRepeatOption.weekly => RecurrenceRule(
      type: RecurrenceType.weekly,
      dayOfWeek: dateTime.weekday,
    ),
    NoteRepeatOption.biweekly => RecurrenceRule(
      type: RecurrenceType.weekly,
      dayOfWeek: dateTime.weekday,
      interval: 2,
    ),
    NoteRepeatOption.alternateWeeks => RecurrenceRule(
      type: RecurrenceType.weekly,
      dayOfWeek: dateTime.weekday,
      interval: 2,
    ),
    NoteRepeatOption.monthly => RecurrenceRule(
      type: RecurrenceType.monthly,
      dayOfMonth: dateTime.day,
    ),
    NoteRepeatOption.alternateMonths => RecurrenceRule(
      type: RecurrenceType.monthly,
      dayOfMonth: dateTime.day,
      interval: 2,
    ),
    NoteRepeatOption.yearly => RecurrenceRule(
      type: RecurrenceType.yearly,
      dayOfMonth: dateTime.day,
      monthOfYear: dateTime.month,
    ),
  };

  static NoteRepeatOption fromRecurrenceRule(RecurrenceRule rule) {
    return switch (rule.type) {
      RecurrenceType.none => NoteRepeatOption.doesNotRepeat,
      RecurrenceType.daily => NoteRepeatOption.daily,
      RecurrenceType.weekly => rule.interval >= 2
          ? NoteRepeatOption.biweekly
          : NoteRepeatOption.weekly,
      RecurrenceType.monthly => rule.interval >= 2
          ? NoteRepeatOption.alternateMonths
          : NoteRepeatOption.monthly,
      RecurrenceType.yearly => NoteRepeatOption.yearly,
    };
  }
}
