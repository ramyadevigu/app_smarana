import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/note_workspace_models.dart';

class NoteAttachmentStorage {
  NoteAttachmentStorage({this.rootDirectory});

  final Directory? rootDirectory;
  final Uuid _uuid = const Uuid();

  Future<NoteAttachment> importFile({
    required PlatformFile file,
    required String noteId,
    required NoteAttachmentType type,
  }) async {
    final root = await _attachmentsDirectory(noteId);
    await root.create(recursive: true);

    final id = _uuid.v4();
    final name = _safeFilename(file.name);
    final destination = File(
      '${root.path}${Platform.pathSeparator}${id}_$name',
    );
    final sourcePath = file.path;
    if (sourcePath != null) {
      await File(sourcePath).copy(destination.path);
    } else if (file.bytes != null) {
      await destination.writeAsBytes(file.bytes!, flush: true);
    } else {
      throw const FileSystemException('Selected file is not readable.');
    }

    return NoteAttachment(
      id: id,
      name: file.name,
      path: destination.path,
      type: type,
      addedAt: DateTime.now(),
    );
  }

  Future<List<NoteAttachment>> duplicateAttachments({
    required List<NoteAttachment> attachments,
    required String noteId,
  }) async {
    if (attachments.isEmpty) {
      return const [];
    }
    final root = await _attachmentsDirectory(noteId);
    await root.create(recursive: true);
    final copies = <NoteAttachment>[];
    try {
      for (final attachment in attachments) {
        final id = _uuid.v4();
        final destination = File(
          '${root.path}${Platform.pathSeparator}'
          '${id}_${_safeFilename(attachment.name)}',
        );
        await File(attachment.path).copy(destination.path);
        copies.add(
          NoteAttachment(
            id: id,
            name: attachment.name,
            path: destination.path,
            type: attachment.type,
            addedAt: DateTime.now(),
          ),
        );
      }
    } on Exception {
      for (final copy in copies) {
        await remove(copy);
      }
      rethrow;
    }
    return copies;
  }

  Future<bool> exists(NoteAttachment attachment) async {
    if (kIsWeb) {
      return false;
    }
    try {
      return await File(attachment.path).exists();
    } on FileSystemException {
      return false;
    }
  }

  Future<bool> open(NoteAttachment attachment) async {
    if (!await exists(attachment)) {
      return false;
    }
    await OpenFilex.open(attachment.path);
    return true;
  }

  Future<void> remove(NoteAttachment attachment) async {
    if (kIsWeb) {
      return;
    }
    final file = File(attachment.path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _attachmentsDirectory(String noteId) async {
    final root = rootDirectory ?? await getApplicationSupportDirectory();
    final safeNoteId = noteId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return Directory(
      '${root.path}${Platform.pathSeparator}notes'
      '${Platform.pathSeparator}attachments'
      '${Platform.pathSeparator}$safeNoteId',
    );
  }

  String _safeFilename(String filename) {
    final basename = filename.split(RegExp(r'[/\\]')).last;
    final safeName = basename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safeName.isEmpty ? 'attachment' : safeName;
  }
}
