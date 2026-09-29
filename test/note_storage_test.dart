import 'package:app_smarana/features/notes/models/note.dart';
import 'package:app_smarana/features/notes/services/note_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late NoteStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = NoteStorage();
  });

  test('persists, updates, and deletes notes', () async {
    final createdAt = DateTime(2026, 9, 29, 10);
    final note = Note(
      id: 'note-1',
      title: 'Planning',
      content: 'Review the next release.',
      createdAt: createdAt,
      updatedAt: createdAt,
      isChecklist: true,
      checklistItems: const [
        NoteChecklistItem(id: 'task-1', text: 'Review', isChecked: true),
        NoteChecklistItem(id: 'task-2', text: 'Ship'),
      ],
      isPinned: true,
      labels: const ['Work', 'Planning'],
      color: NoteColor.teal,
    );
    await storage.addNote(note);
    expect((await storage.getNotes()).single.toJson(), note.toJson());

    final updated = note.copyWith(
      title: 'Release planning',
      updatedAt: DateTime(2026, 9, 29, 11),
    );
    await storage.updateNote(updated);
    expect((await storage.getNotes()).single.title, 'Release planning');

    await storage.deleteNote(note.id);
    expect(await storage.getNotes(), isEmpty);
  });

  test('returns an empty list for corrupted stored data', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('smarana_notes_v1', '{invalid');

    expect(await storage.getNotes(), isEmpty);
  });

  test('reads existing version 1 notes with defaults for new fields', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'smarana_notes_v1',
      '{"version":1,"notes":[{"id":"legacy","title":"Old note",'
          '"content":"Keep this text",'
          '"createdAt":"2026-09-29T10:00:00.000",'
          '"updatedAt":"2026-09-29T10:00:00.000"}]}',
    );

    final note = (await storage.getNotes()).single;
    expect(note.title, 'Old note');
    expect(note.content, 'Keep this text');
    expect(note.isChecklist, isFalse);
    expect(note.checklistItems, isEmpty);
    expect(note.isPinned, isFalse);
    expect(note.labels, isEmpty);
    expect(note.color, NoteColor.standard);
  });
}
