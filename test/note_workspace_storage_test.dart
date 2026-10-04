import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_smarana/features/notes/models/note_workspace_models.dart';
import 'package:app_smarana/features/notes/services/note_attachment_storage.dart';
import 'package:app_smarana/features/notes/services/note_workspace_storage.dart';
import 'package:app_smarana/features/notes/theme/note_card_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late NoteWorkspaceStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = NoteWorkspaceStorage();
  });

  test(
    'persists notebook, section, note, rich content, and timestamps',
    () async {
      final createdAt = DateTime(2026, 9, 1, 10);
      final updatedAt = DateTime(2026, 9, 30, 14, 25);
      final notebook = Notebook(
        id: 'notebook-1',
        name: 'Work',
        description: 'Project planning and team notes.',
        iconType: NotebookIconType.work,
        icon: NotebookIcon.science,
        colorValue: 0xFFE06E91,
        sections: [
          NoteSection(id: 'section-1', name: 'Meetings', createdAt: createdAt),
        ],
        notes: [
          NoteEntry(
            id: 'note-1',
            notebookId: 'notebook-1',
            sectionId: 'section-1',
            title: 'Review',
            content: 'Review agenda',
            richContentDelta: '[{"insert":"Review agenda\\n"}]',
            attachments: [
              NoteAttachment(
                id: 'attachment-1',
                name: 'agenda.pdf',
                path: '/local/agenda.pdf',
                type: NoteAttachmentType.file,
                addedAt: updatedAt,
              ),
            ],
            projectMetadata: NoteProjectMetadata(
              owner: 'Ramya',
              tags: ['Launch', 'Q4'],
              startDate: DateTime(2026, 9, 1),
              endDate: DateTime(2026, 10, 1),
              priority: NoteProjectPriority.high,
              status: NoteProjectStatus.inProgress,
              relatedCalendarEventId: 'event-42',
            ),
            isPinned: true,
            color: NoteCardColor.pink,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        ],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      await storage.saveWorkspace([notebook]);
      final restored = (await storage.loadWorkspace()).single;

      expect(restored.name, notebook.name);
      expect(restored.description, notebook.description);
      expect(restored.icon, notebook.icon);
      expect(restored.colorValue, notebook.colorValue);
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
      expect(restored.sections.single.name, 'Meetings');
      expect(restored.notes.single.title, 'Review');
      expect(restored.notes.single.content, 'Review agenda');
      expect(
        restored.notes.single.richContentDelta,
        notebook.notes.single.richContentDelta,
      );
      expect(restored.notes.single.attachments.single.name, 'agenda.pdf');
      expect(
        restored.notes.single.attachments.single.type,
        NoteAttachmentType.file,
      );
      expect(restored.notes.single.projectMetadata?.owner, 'Ramya');
      expect(restored.notes.single.projectMetadata?.tags, ['Launch', 'Q4']);
      expect(
        restored.notes.single.projectMetadata?.priority,
        NoteProjectPriority.high,
      );
      expect(
        restored.notes.single.projectMetadata?.status,
        NoteProjectStatus.inProgress,
      );
      expect(
        restored.notes.single.projectMetadata?.relatedCalendarEventId,
        'event-42',
      );
      expect(restored.notes.single.isPinned, isTrue);
      expect(restored.notes.single.color, NoteCardColor.pink);
      expect(restored.notes.single.content, 'Review agenda');
      expect(restored.notes.single.createdAt, createdAt);
      expect(restored.notes.single.updatedAt, updatedAt);
    },
  );

  test('returns an empty workspace for corrupted data', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('smarana_note_workspace_v1', '{invalid');

    expect(await storage.loadWorkspace(), isEmpty);
  });

  test(
    'assigns and persists colors for existing uncolored notes once',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'smarana_note_workspace_v1',
        jsonEncode({
          'version': 1,
          'notebooks': [
            {
              'id': 'notebook-legacy',
              'name': 'Legacy',
              'sections': [
                {'id': 'section-legacy', 'name': 'General'},
              ],
              'notes': [
                {
                  'id': 'note-legacy-1',
                  'notebookId': 'notebook-legacy',
                  'sectionId': 'section-legacy',
                  'title': 'First',
                  'projectMetadata': {
                    'tags': ['Campaigns'],
                  },
                },
                {
                  'id': 'note-legacy-2',
                  'notebookId': 'notebook-legacy',
                  'sectionId': 'section-legacy',
                  'title': 'Second',
                },
              ],
            },
            {
              'id': 'notebook-legacy-2',
              'name': 'Existing',
              'sections': [],
              'notes': [],
            },
          ],
        }),
      );

      final firstLoad = await storage.loadWorkspace();
      expect(
        firstLoad.map((notebook) => notebook.colorValue).toSet().length,
        2,
      );
      expect(firstLoad.first.description, isEmpty);
      expect(firstLoad.first.icon, isNull);
      final migratedColors = firstLoad.first.notes
          .map((note) => note.color)
          .toList();
      expect(migratedColors, [NoteCardColor.yellow, NoteCardColor.pink]);

      final persisted = jsonDecode(
        preferences.getString('smarana_note_workspace_v1')!,
      ) as Map;
      expect(persisted['version'], 3);
      final persistedNotebooks = persisted['notebooks'] as List;
      expect(persistedNotebooks.first['description'], isEmpty);
      expect(persistedNotebooks.first['icon'], isNull);
      expect(persistedNotebooks.first['colorValue'], isA<int>());
      expect(
        persistedNotebooks.first['notes'].map((note) => note['color']).toList(),
        ['yellow', 'pink'],
      );
      expect(
        (await storage.loadWorkspace()).first.notes
            .map((note) => note.color)
            .toList(),
        migratedColors,
      );
      expect(await storage.loadTagColors(), {
        'campaigns': NoteCardColor.yellow,
      });
    },
  );

  test('persists shared tag colors in the Notes workspace', () async {
    final now = DateTime(2026, 10, 1);
    final notebook = Notebook(
      id: 'tag-notebook',
      name: 'Work',
      iconType: NotebookIconType.work,
      sections: [
        NoteSection(
          id: 'tag-section',
          name: 'General',
          createdAt: now,
          color: NoteCardColor.lavender,
        ),
      ],
      notes: const [],
      createdAt: now,
      updatedAt: now,
    );

    await storage.saveWorkspace(
      [notebook],
      tagColors: {'campaigns': NoteCardColor.lavender},
    );

    expect(await storage.loadTagColors(), {
      'campaigns': NoteCardColor.lavender,
    });
    expect(
      (await storage.loadWorkspace()).single.sections.single.color,
      NoteCardColor.lavender,
    );
  });

  test('assigns new note colors with a balanced palette', () {
    final notes = <NoteEntry>[];
    final selected = <NoteCardColor>[];
    final now = DateTime(2026, 10, 1);
    for (var index = 0; index < selectableNoteCardColors.length; index++) {
      final color = nextBalancedNoteColor(notes);
      selected.add(color);
      notes.add(
        NoteEntry(
          id: 'note-$index',
          notebookId: 'notebook',
          sectionId: 'section',
          title: 'Note $index',
          content: '',
          createdAt: now,
          updatedAt: now,
          color: color,
        ),
      );
    }

    expect(selected, selectableNoteCardColors);
  });

  test(
    'copies attachments locally, handles missing files, and removes files',
    () async {
      final root = await Directory.systemTemp.createTemp('smarana-notes-');
      addTearDown(() => root.delete(recursive: true));
      final attachmentStorage = NoteAttachmentStorage(rootDirectory: root);
      final attachment = await attachmentStorage.importFile(
        file: PlatformFile(
          name: 'photo.png',
          size: 3,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        noteId: 'note-1',
        type: NoteAttachmentType.image,
      );

      expect(await attachmentStorage.exists(attachment), isTrue);
      expect(await File(attachment.path).readAsBytes(), [1, 2, 3]);
      expect(
        await attachmentStorage.open(
          attachment.copyWith(path: '${attachment.path}.missing'),
        ),
        isFalse,
      );

      await attachmentStorage.remove(attachment);
      expect(await attachmentStorage.exists(attachment), isFalse);
      await attachmentStorage.remove(attachment);
    },
  );
}
