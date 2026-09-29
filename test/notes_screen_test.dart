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

  testWidgets('creates checklists and moves completed items to the bottom', (
    tester,
  ) async {
    await _pumpNotes(tester, notes, reminders);

    await tester.tap(find.byTooltip('Create note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-title')), 'Today');
    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('new-checklist-item')),
      'Call clinic',
    );
    await tester.tap(find.byTooltip('Add checklist item'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-checklist-item')),
      'Pick up mail',
    );
    await tester.tap(find.byTooltip('Add checklist item'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();

    final note = notes.values.single;
    expect(note.isChecklist, isTrue);
    expect(note.checklistItems.map((item) => item.text), [
      'Call clinic',
      'Pick up mail',
    ]);

    await tester.tap(
      find.byKey(
        ValueKey('note-check-${note.id}-${note.checklistItems.first.id}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(notes.values.single.checklistItems.map((item) => item.text), [
      'Pick up mail',
      'Call clinic',
    ]);
    expect(notes.values.single.checklistItems.last.isChecked, isTrue);
  });

  testWidgets('searches, filters, pins, colors, and archives notes', (
    tester,
  ) async {
    await _pumpNotes(tester, notes, reminders);

    await tester.tap(find.byTooltip('Create note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Work update',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-content')),
      'Meet the team',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-labels')),
      'Work, Weekly',
    );
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('note-pinned-toggle')),
      find.byType(ListView).last,
      const Offset(0, -360),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-pinned-toggle')));
    await tester.tap(find.byKey(const ValueKey('note-color-teal')));
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();

    expect(notes.values.single.isPinned, isTrue);
    expect(notes.values.single.labels, ['Work', 'Weekly']);
    expect(notes.values.single.color, NoteColor.teal);

    await tester.tap(find.byTooltip('Search notes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('notes-search-field')),
      'team',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('note-card-${notes.values.single.id}')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('notes-search-field')),
      'not found',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching notes'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-label-filter-Work')));
    await tester.pumpAndSettle();
    expect(find.text('Work update'), findsOneWidget);

    await tester.tap(find.byTooltip('More actions for Work update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Work update'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('notes-archive-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Work update'), findsOneWidget);
    expect(notes.values.single.isArchived, isTrue);
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

  testWidgets('deleting a note keeps its linked alarm', (tester) async {
    await _pumpNotes(tester, notes, reminders);

    await tester.tap(find.byTooltip('Create note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Keep the alarm',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('note-reminder-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('note-reminder-toggle')));
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();
    expect(reminders.values, hasLength(1));

    await tester.tap(find.byTooltip('More actions for Keep the alarm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(notes.values, isEmpty);
    expect(reminders.values, hasLength(1));
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
