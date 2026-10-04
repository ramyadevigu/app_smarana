import 'dart:io';

import 'package:app_smarana/features/notes/models/note_workspace_models.dart';
import 'package:app_smarana/features/notes/services/note_attachment_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late NoteAttachmentStorage storage;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'smarana-notes-attachments-',
    );
    storage = NoteAttachmentStorage(rootDirectory: temporaryDirectory);
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('duplicates attachments into a separate note folder', () async {
    final source = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}source.txt',
    );
    await source.writeAsString('Keep these attachment contents.');
    final attachment = NoteAttachment(
      id: 'attachment-1',
      name: 'source.txt',
      path: source.path,
      type: NoteAttachmentType.file,
      addedAt: DateTime(2026, 10, 4),
    );

    final copies = await storage.duplicateAttachments(
      attachments: [attachment],
      noteId: 'duplicate-note',
    );

    expect(copies, hasLength(1));
    expect(copies.single.id, isNot(attachment.id));
    expect(copies.single.path, isNot(attachment.path));
    expect(await File(copies.single.path).readAsString(), contains('contents'));
    expect(await source.exists(), isTrue);
  });
}
