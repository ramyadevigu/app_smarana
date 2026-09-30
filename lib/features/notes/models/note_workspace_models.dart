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

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'type': type.name,
    'addedAt': addedAt.toIso8601String(),
  };

  factory NoteAttachment.fromJson(Map<String, Object?> json) {
    return NoteAttachment(
      id: json['id'] is String ? json['id']! as String : '',
      name: json['name'] is String ? json['name']! as String : 'Attachment',
      path: json['path'] is String ? json['path']! as String : '',
      type: NoteAttachmentType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => NoteAttachmentType.file,
      ),
      addedAt:
          _readDate(json['addedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

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

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'iconType': iconType.name,
    'sections': sections.map((section) => section.toJson()).toList(),
    'notes': notes.map((note) => note.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Notebook.fromJson(Map<String, Object?> json) {
    final createdAt = _readDate(json['createdAt']) ?? DateTime.now();
    return Notebook(
      id: json['id'] is String ? json['id']! as String : '',
      name: json['name'] is String ? json['name']! as String : 'Notebook',
      iconType: NotebookIconType.values.firstWhere(
        (value) => value.name == json['iconType'],
        orElse: () => NotebookIconType.general,
      ),
      sections: _readObjects(json['sections'], NoteSection.fromJson),
      notes: _readObjects(json['notes'], NoteEntry.fromJson),
      createdAt: createdAt,
      updatedAt: _readDate(json['updatedAt']) ?? createdAt,
    );
  }

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

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory NoteSection.fromJson(Map<String, Object?> json) {
    return NoteSection(
      id: json['id'] is String ? json['id']! as String : '',
      name: json['name'] is String ? json['name']! as String : 'General',
      createdAt: _readDate(json['createdAt']) ?? DateTime.now(),
    );
  }

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
    this.reminderId,
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
  final String? reminderId;

  Map<String, Object?> toJson() => {
    'id': id,
    'notebookId': notebookId,
    'sectionId': sectionId,
    'title': title,
    'content': content,
    'richContentDelta': richContentDelta,
    'attachments': attachments
        .map((attachment) => attachment.toJson())
        .toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reminderId': reminderId,
  };

  factory NoteEntry.fromJson(Map<String, Object?> json) {
    final createdAt = _readDate(json['createdAt']) ?? DateTime.now();
    return NoteEntry(
      id: json['id'] is String ? json['id']! as String : '',
      notebookId: json['notebookId'] is String
          ? json['notebookId']! as String
          : '',
      sectionId: json['sectionId'] is String
          ? json['sectionId']! as String
          : '',
      title: json['title'] is String ? json['title']! as String : '',
      content: json['content'] is String ? json['content']! as String : '',
      richContentDelta: json['richContentDelta'] is String
          ? json['richContentDelta']! as String
          : null,
      attachments: _readObjects(json['attachments'], NoteAttachment.fromJson),
      createdAt: createdAt,
      updatedAt: _readDate(json['updatedAt']) ?? createdAt,
      reminderId: json['reminderId'] is String
          ? json['reminderId']! as String
          : null,
    );
  }

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
    String? reminderId,
    bool clearReminderId = false,
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
      reminderId: clearReminderId ? null : reminderId ?? this.reminderId,
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

List<T> _readObjects<T>(Object? value, T Function(Map<String, Object?>) parse) {
  if (value is! List) {
    return [];
  }
  return [
    for (final item in value)
      if (item is Map) parse(_stringKeyedMap(item)),
  ];
}

Map<String, Object?> _stringKeyedMap(Map<dynamic, dynamic> value) => {
  for (final entry in value.entries)
    if (entry.key is String) entry.key as String: entry.value,
};

DateTime? _readDate(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}
