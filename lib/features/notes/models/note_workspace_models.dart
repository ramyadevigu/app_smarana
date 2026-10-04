import 'dart:convert';

enum NotebookIconType { work, goals, journal, health, ideas, general }

enum NoteAttachmentType { image, file }

enum NoteCardColor { standard, blue, cyan, mint, lightGreen, peach, pink, lavender }

enum NoteProjectPriority { low, medium, high }

enum NoteProjectStatus { toDo, inProgress, done }

class NoteProjectMetadata {
  const NoteProjectMetadata({
    this.owner,
    this.tags = const [],
    this.startDate,
    this.endDate,
    this.priority,
    this.status = NoteProjectStatus.toDo,
    this.relatedCalendarEventId,
  });

  final String? owner;
  final List<String> tags;
  final DateTime? startDate;
  final DateTime? endDate;
  final NoteProjectPriority? priority;
  final NoteProjectStatus status;
  final String? relatedCalendarEventId;

  bool get isEmpty {
    return (owner == null || owner!.trim().isEmpty) &&
        tags.isEmpty &&
        startDate == null &&
        endDate == null &&
        priority == null &&
        status == NoteProjectStatus.toDo &&
        relatedCalendarEventId == null;
  }

  Map<String, Object?> toJson() => {
    'owner': owner,
    'tags': tags,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'priority': priority?.name,
    'status': status.name,
    'relatedCalendarEventId': relatedCalendarEventId,
  };

  factory NoteProjectMetadata.fromJson(Map<String, Object?> json) {
    final tags = json['tags'] is List
        ? (json['tags']! as List)
              .whereType<String>()
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList()
        : const <String>[];

    return NoteProjectMetadata(
      owner: json['owner'] is String ? json['owner']! as String : null,
      tags: tags,
      startDate: _readDate(json['startDate']),
      endDate: _readDate(json['endDate']),
      priority: _readProjectPriority(json['priority']),
      status: _readProjectStatus(json['status']),
      relatedCalendarEventId: json['relatedCalendarEventId'] is String
          ? json['relatedCalendarEventId']! as String
          : null,
    );
  }

  NoteProjectMetadata copyWith({
    String? owner,
    List<String>? tags,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    NoteProjectPriority? priority,
    bool clearPriority = false,
    NoteProjectStatus? status,
    String? relatedCalendarEventId,
    bool clearRelatedCalendarEventId = false,
  }) {
    return NoteProjectMetadata(
      owner: owner ?? this.owner,
      tags: tags ?? this.tags,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      priority: clearPriority ? null : priority ?? this.priority,
      status: status ?? this.status,
      relatedCalendarEventId: clearRelatedCalendarEventId
          ? null
          : relatedCalendarEventId ?? this.relatedCalendarEventId,
    );
  }
}

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
    this.projectMetadata,
    required this.createdAt,
    required this.updatedAt,
    this.reminderId,
    this.isPinned = false,
    this.color = NoteCardColor.standard,
  });

  final String id;
  final String notebookId;
  final String sectionId;
  final String title;
  final String content;
  final String? richContentDelta;
  final List<NoteAttachment> attachments;
  final NoteProjectMetadata? projectMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reminderId;
  final bool isPinned;
  final NoteCardColor color;

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
    'projectMetadata': projectMetadata?.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reminderId': reminderId,
    'isPinned': isPinned,
    'color': color.name,
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
      projectMetadata: _readProjectMetadata(json['projectMetadata']),
      createdAt: createdAt,
      updatedAt: _readDate(json['updatedAt']) ?? createdAt,
      reminderId: json['reminderId'] is String
          ? json['reminderId']! as String
          : null,
      isPinned: json['isPinned'] is bool ? json['isPinned']! as bool : false,
      color: _readNoteCardColor(json['color']),
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
    NoteProjectMetadata? projectMetadata,
    bool clearProjectMetadata = false,
    DateTime? updatedAt,
    String? reminderId,
    bool clearReminderId = false,
    bool? isPinned,
    NoteCardColor? color,
  }) {
    return NoteEntry(
      id: id,
      notebookId: notebookId,
      sectionId: sectionId ?? this.sectionId,
      title: title ?? this.title,
      content: content ?? this.content,
      richContentDelta: richContentDelta ?? this.richContentDelta,
      attachments: attachments ?? this.attachments,
      projectMetadata: clearProjectMetadata
          ? null
          : projectMetadata ?? this.projectMetadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderId: clearReminderId ? null : reminderId ?? this.reminderId,
      isPinned: isPinned ?? this.isPinned,
      color: color ?? this.color,
    );
  }
}

NoteProjectMetadata? _readProjectMetadata(Object? value) {
  if (value is! Map) {
    return null;
  }
  final metadata = NoteProjectMetadata.fromJson(_stringKeyedMap(value));
  return metadata.isEmpty ? null : metadata;
}

NoteProjectPriority? _readProjectPriority(Object? value) {
  if (value is! String) {
    return null;
  }
  for (final item in NoteProjectPriority.values) {
    if (item.name == value) {
      return item;
    }
  }
  return null;
}

NoteProjectStatus _readProjectStatus(Object? value) {
  if (value is String) {
    for (final item in NoteProjectStatus.values) {
      if (item.name == value) {
        return item;
      }
    }
  }
  return NoteProjectStatus.toDo;
}

NoteCardColor _readNoteCardColor(Object? value) {
  if (value is String) {
    for (final color in NoteCardColor.values) {
      if (color.name == value) {
        return color;
      }
    }
  }
  return NoteCardColor.standard;
}

class RecentNoteView {
  const RecentNoteView({
    required this.note,
    required this.notebookId,
    required this.notebookIconType,
    required this.notebookName,
    required this.sectionName,
  });

  final NoteEntry note;
  final String notebookId;
  final NotebookIconType notebookIconType;
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
