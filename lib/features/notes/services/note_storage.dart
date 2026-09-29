import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

class NoteStorage {
  static const String _key = 'smarana_notes_v1';
  static Future<void> _operationQueue = Future<void>.value();

  Future<List<Note>> getNotes() {
    return _runSerialized(_readNotes);
  }

  Future<void> addNote(Note note) {
    return _runSerialized(() async {
      final notes = await _readNotes();
      if (note.id.isEmpty || notes.any((existing) => existing.id == note.id)) {
        throw ArgumentError.value(note.id, 'note.id');
      }
      notes.add(note);
      await _writeNotes(notes);
    });
  }

  Future<void> updateNote(Note note) {
    return _runSerialized(() async {
      final notes = await _readNotes();
      final index = notes.indexWhere((existing) => existing.id == note.id);
      if (index == -1) {
        return;
      }
      notes[index] = note;
      await _writeNotes(notes);
    });
  }

  Future<void> deleteNote(String id) {
    return _runSerialized(() async {
      final notes = await _readNotes();
      notes.removeWhere((note) => note.id == id);
      await _writeNotes(notes);
    });
  }

  Future<List<Note>> _readNotes() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.get(_key);
    if (raw is! String || raw.isEmpty) {
      return [];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return [];
    }
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['notes'] is! List) {
      return [];
    }

    final notes = <Note>[];
    final ids = <String>{};
    for (final value in decoded['notes'] as List) {
      if (value is! Map) {
        continue;
      }
      final json = <String, Object?>{
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
      final note = Note.fromJson(json);
      if (note.id.isNotEmpty && ids.add(note.id)) {
        notes.add(note);
      }
    }
    notes.sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    return notes;
  }

  Future<void> _writeNotes(List<Note> notes) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode({
        'version': 1,
        'notes': notes.map((note) => note.toJson()).toList(),
      }),
    );
    if (!saved) {
      throw StateError('Unable to save notes.');
    }
  }

  Future<T> _runSerialized<T>(Future<T> Function() operation) {
    final result = _operationQueue.then((_) => operation());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
