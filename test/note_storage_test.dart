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
}
