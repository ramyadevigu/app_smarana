import 'dart:convert';

enum NotebookIconType { work, goals, journal, health, ideas, general }

enum NoteAttachmentType { image, file }

class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.addedAt,
  });

  final String id;
  final String name;
  final String path;
  final NoteAttachmentType type;
  final DateTime addedAt;

  NoteAttachment copyWith({String? name, String? path, DateTime? addedAt}) {
    return NoteAttachment(
      id: id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

class Notebook {
  const Notebook({
    required this.id,
    required this.name,
    required this.iconType,
    required this.sections,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final NotebookIconType iconType;
  final List<NoteSection> sections;
  final List<NoteEntry> notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get noteCount => notes.length;

  Notebook copyWith({
    String? name,
    NotebookIconType? iconType,
    List<NoteSection>? sections,
    List<NoteEntry>? notes,
    DateTime? updatedAt,
  }) {
    return Notebook(
      id: id,
      name: name ?? this.name,
      iconType: iconType ?? this.iconType,
      sections: sections ?? this.sections,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NoteSection {
  const NoteSection({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  NoteSection copyWith({String? name}) {
    return NoteSection(id: id, name: name ?? this.name, createdAt: createdAt);
  }
}

class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.notebookId,
    required this.sectionId,
    required this.title,
    required this.content,
    this.richContentDelta,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String notebookId;
  final String sectionId;
  final String title;
  final String content;
  final String? richContentDelta;
  final List<NoteAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get preview {
    final trimmed = _richPlainText.trim().isNotEmpty
        ? _richPlainText.trim()
        : content.trim();
    if (trimmed.isEmpty) {
      return 'No additional text';
    }
    return trimmed;
  }

  String get _richPlainText {
    final raw = richContentDelta;
    if (raw == null || raw.trim().isEmpty) {
      return '';
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return '';
    }

    if (decoded is! List) {
      return '';
    }

    final buffer = StringBuffer();
    for (final op in decoded) {
      if (op is! Map) {
        continue;
      }
      final insert = op['insert'];
      if (insert is String) {
        buffer.write(insert);
      }
    }
    return buffer.toString();
  }

  NoteEntry copyWith({
    String? sectionId,
    String? title,
    String? content,
    String? richContentDelta,
    List<NoteAttachment>? attachments,
    DateTime? updatedAt,
  }) {
    return NoteEntry(
      id: id,
      notebookId: notebookId,
      sectionId: sectionId ?? this.sectionId,
      title: title ?? this.title,
      content: content ?? this.content,
      richContentDelta: richContentDelta ?? this.richContentDelta,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RecentNoteView {
  const RecentNoteView({
    required this.note,
    required this.notebookName,
    required this.sectionName,
  });

  final NoteEntry note;
  final String notebookName;
  final String sectionName;
}
