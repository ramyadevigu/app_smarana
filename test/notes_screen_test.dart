import 'package:app_smarana/features/notes/models/note.dart';
import 'package:app_smarana/features/notes/notes_screen.dart';
import 'package:app_smarana/features/notes/services/note_storage.dart';
import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryNoteStorage notes;
  late _MemoryReminderStorage reminders;

  setUp(() {
    notes = _MemoryNoteStorage();
    reminders = _MemoryReminderStorage();
  });

  testWidgets('creates, edits, and deletes notes', (tester) async {
    await _pumpNotes(tester, notes, reminders);

    await tester.tap(find.byTooltip('Create note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Groceries',
    );
    await tester.enterText(find.byKey(const ValueKey('note-content')), 'Oats');
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();
    expect(notes.values.single.title, 'Groceries');
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-title')), 'Market');
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();
    expect(notes.values.single.title, 'Market');

    await tester.tap(find.byTooltip('More actions for Market'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(notes.values, isEmpty);
  });

  testWidgets('creates and clears a linked alarm for a note', (tester) async {
    await _pumpNotes(tester, notes, reminders);

    await tester.tap(find.byTooltip('Create note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Call Mum',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      'Ask about Sunday.',
    );
    await tester.tap(find.byKey(const ValueKey('note-reminder-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();

    expect(reminders.values, hasLength(1));
    expect(reminders.values.single.title, 'Call Mum');
    expect(reminders.values.single.description, 'Ask about Sunday.');
    expect(notes.values.single.reminderId, reminders.values.single.id);
    expect(find.textContaining('Call Mum'), findsOneWidget);

    await tester.tap(find.text('Call Mum'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-reminder-toggle')));
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();
    expect(reminders.values, isEmpty);
    expect(notes.values.single.reminderId, isNull);
  });
}

Future<void> _pumpNotes(
  WidgetTester tester,
  NoteStorage notes,
  ReminderStorage reminders,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NotesScreen(noteStorage: notes, reminderStorage: reminders),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryNoteStorage extends NoteStorage {
  final List<Note> values = [];

  @override
  Future<List<Note>> getNotes() async => List.of(values);

  @override
  Future<void> addNote(Note note) async => values.add(note);

  @override
  Future<void> updateNote(Note note) async {
    final index = values.indexWhere((item) => item.id == note.id);
    if (index >= 0) {
      values[index] = note;
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    values.removeWhere((note) => note.id == id);
  }
}

class _MemoryReminderStorage extends ReminderStorage {
  final List<Reminder> values = [];

  @override
  Future<List<Reminder>> getReminders() async => List.of(values);

  @override
  Future<void> addReminder(Reminder reminder) async => values.add(reminder);

  @override
  Future<void> updateReminder(Reminder reminder) async {
    final index = values.indexWhere((item) => item.id == reminder.id);
    if (index >= 0) {
      values[index] = reminder;
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    values.removeWhere((reminder) => reminder.id == id);
  }
}
