import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note_workspace_models.dart';

class NoteWorkspaceStorage {
  NoteWorkspaceStorage({SharedPreferences? preferences})
    : _providedPreferences = preferences;

  static const String _key = 'smarana_note_workspace_v1';
  static const int _schemaVersion = 1;
  Future<void> _operationQueue = Future<void>.value();

  final SharedPreferences? _providedPreferences;

  Future<List<Notebook>> loadWorkspace() {
    return _runSerialized(_readWorkspace);
  }

  Future<void> saveWorkspace(List<Notebook> notebooks) {
    return _runSerialized(() async {
      final preferences =
          _providedPreferences ?? await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _key,
        jsonEncode({
          'version': _schemaVersion,
          'notebooks': notebooks.map((notebook) => notebook.toJson()).toList(),
        }),
      );
      if (!saved) {
        throw StateError('Unable to save the Notes workspace.');
      }
    });
  }

  Future<List<Notebook>> _readWorkspace() async {
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
        decoded['version'] != _schemaVersion ||
        decoded['notebooks'] is! List) {
      return [];
    }

    final notebooks = <Notebook>[];
    final notebookIds = <String>{};
    for (final value in decoded['notebooks'] as List) {
      if (value is! Map) {
        continue;
      }
      final notebook = Notebook.fromJson(_stringKeyedMap(value));
      if (notebook.id.isNotEmpty && notebookIds.add(notebook.id)) {
        final noteIds = <String>{};
        final notes = notebook.notes
            .where((note) => note.id.isNotEmpty && noteIds.add(note.id))
            .map(
              (note) => note.copyWith(
                sectionId:
                    notebook.sections.any(
                      (section) => section.id == note.sectionId,
                    )
                    ? note.sectionId
                    : notebook.sections.firstOrNull?.id ?? '',
              ),
            )
            .toList();
        notebooks.add(notebook.copyWith(notes: notes));
      }
    }
    return notebooks;
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
