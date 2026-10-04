import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note_workspace_models.dart';
import '../theme/note_card_colors.dart';
import '../theme/notebook_colors.dart';

class NoteWorkspaceStorage {
  NoteWorkspaceStorage({SharedPreferences? preferences})
    : _providedPreferences = preferences;

  static const String _key = 'smarana_note_workspace_v1';
  static const int _schemaVersion = 4;
  Future<void> _operationQueue = Future<void>.value();
  bool _migrationRequired = false;

  final SharedPreferences? _providedPreferences;

  Future<List<Notebook>> loadWorkspace() {
    return _runSerialized(() async {
      final savedNotebooks = await _readWorkspace();
      final seededNotebooks = ensureQuickNotesNotebook(savedNotebooks);
      final notebooks = ensureDistinctNotebookColors(seededNotebooks);
      final savedNotebookColors = {
        for (final notebook in savedNotebooks) notebook.id: notebook.colorValue,
      };
      final savedNotebookNames = {
        for (final notebook in savedNotebooks) notebook.id: notebook.name,
      };
      final assignedNotebookColor = notebooks.any(
        (notebook) =>
            savedNotebookColors[notebook.id] != notebook.colorValue ||
            savedNotebookNames[notebook.id] != notebook.name,
      );
      final hasUncoloredNotes = notebooks.any(
        (notebook) =>
            notebook.notes.any((note) => note.color == NoteCardColor.standard),
      );

      final assignedNotes = [
        for (final notebook in notebooks)
          for (final note in notebook.notes)
            if (note.color != NoteCardColor.standard) note,
      ];
      final migrated = notebooks.map((notebook) {
        return notebook.copyWith(
          notes: notebook.notes.map((note) {
            if (note.color != NoteCardColor.standard) {
              return note;
            }
            final updated = note.copyWith(
              color: nextBalancedNoteColor(assignedNotes),
            );
            assignedNotes.add(updated);
            return updated;
          }).toList(),
        );
      }).toList();

      final tagColors = await _readTagColors();
      var assignedTagColor = false;
      for (final notebook in migrated) {
        for (final note in notebook.notes) {
          for (final tag in note.projectMetadata?.tags ?? const <String>[]) {
            final key = tag.trim().toLowerCase();
            if (key.isNotEmpty && !tagColors.containsKey(key)) {
              tagColors[key] = nextBalancedTagColor(tagColors.values);
              assignedTagColor = true;
            }
          }
        }
      }
      if (hasUncoloredNotes ||
          assignedTagColor ||
          assignedNotebookColor ||
          seededNotebooks.length != savedNotebooks.length ||
          _migrationRequired) {
        await _writeWorkspace(migrated, tagColors);
      }
      return migrated;
    });
  }

  Future<Map<String, NoteCardColor>> loadTagColors() {
    return _runSerialized(_readTagColors);
  }

  Future<void> saveWorkspace(
    List<Notebook> notebooks, {
    Map<String, NoteCardColor>? tagColors,
  }) {
    return _runSerialized(() async {
      await _writeWorkspace(
        ensureQuickNotesNotebook(notebooks),
        tagColors ?? await _readTagColors(),
      );
    });
  }

  Future<List<Notebook>> _readWorkspace() async {
    _migrationRequired = false;
    final preferences =
        _providedPreferences ?? await SharedPreferences.getInstance();
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
        (decoded['version'] != 1 &&
            decoded['version'] != 2 &&
            decoded['version'] != 3 &&
            decoded['version'] != _schemaVersion) ||
        decoded['notebooks'] is! List) {
      return [];
    }
    _migrationRequired = decoded['version'] != _schemaVersion;

    final notebooks = <Notebook>[];
    final notebookIds = <String>{};
    for (final value in decoded['notebooks'] as List) {
      if (value is! Map) {
        continue;
      }
      final json = _stringKeyedMap(value);
      final colorValue = json['colorValue'];
      if (json['description'] is! String ||
          !json.containsKey('icon') ||
          colorValue is! int ||
          colorValue < 0 ||
          colorValue > 0xFFFFFFFF ||
          (colorValue & 0xFF000000) != 0xFF000000) {
        _migrationRequired = true;
      }
      final notebook = Notebook.fromJson(json);
      if (notebook.id.isNotEmpty && notebookIds.add(notebook.id)) {
        final noteIds = <String>{};
        final notes = <NoteEntry>[];
        for (final note in notebook.notes) {
          if (note.id.isEmpty || !noteIds.add(note.id)) {
            continue;
          }
          if (note.notebookId != notebook.id) {
            _migrationRequired = true;
          }
          notes.add(note.copyWith(notebookId: notebook.id));
        }
        notebooks.add(notebook.copyWith(notes: notes));
      }
    }
    return notebooks;
  }

  Future<Map<String, NoteCardColor>> _readTagColors() async {
    final preferences =
        _providedPreferences ?? await SharedPreferences.getInstance();
    final raw = preferences.get(_key);
    if (raw is! String || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          (decoded['version'] != 1 &&
              decoded['version'] != 2 &&
              decoded['version'] != 3 &&
              decoded['version'] != _schemaVersion) ||
          decoded['tagColors'] is! Map) {
        return {};
      }
      final colors = <String, NoteCardColor>{};
      for (final entry in (decoded['tagColors'] as Map).entries) {
        if (entry.key is! String) {
          continue;
        }
        final key = (entry.key as String).trim().toLowerCase();
        final color = noteCardColorFromName(entry.value);
        if (key.isNotEmpty && color != NoteCardColor.standard) {
          colors[key] = color;
        }
      }
      return colors;
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeWorkspace(
    List<Notebook> notebooks,
    Map<String, NoteCardColor> tagColors,
  ) async {
    final preferences =
        _providedPreferences ?? await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode({
        'version': _schemaVersion,
        'notebooks': notebooks.map((notebook) => notebook.toJson()).toList(),
        'tagColors': {
          for (final entry in tagColors.entries)
            if (entry.key.trim().isNotEmpty)
              entry.key.trim().toLowerCase(): entry.value.name,
        },
      }),
    );
    if (!saved) {
      throw StateError('Unable to save the Notes workspace.');
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

Map<String, Object?> _stringKeyedMap(Map<dynamic, dynamic> value) => {
  for (final entry in value.entries)
    if (entry.key is String) entry.key as String: entry.value,
};
