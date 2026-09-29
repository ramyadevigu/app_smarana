enum NoteColor { standard, blue, teal, amber, red }

class NoteChecklistItem {
  const NoteChecklistItem({
    required this.id,
    required this.text,
    this.isChecked = false,
  });

  final String id;
  final String text;
  final bool isChecked;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'isChecked': isChecked,
  };

  factory NoteChecklistItem.fromJson(Map<String, Object?> json) {
    return NoteChecklistItem(
      id: json['id'] is String ? json['id']! as String : '',
      text: json['text'] is String ? json['text']! as String : '',
      isChecked: json['isChecked'] is bool ? json['isChecked']! as bool : false,
    );
  }

  NoteChecklistItem copyWith({String? text, bool? isChecked}) {
    return NoteChecklistItem(
      id: id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.reminderId,
    this.isChecklist = false,
    this.checklistItems = const [],
    this.isPinned = false,
    this.isArchived = false,
    this.labels = const [],
    this.color = NoteColor.standard,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reminderId;
  final bool isChecklist;
  final List<NoteChecklistItem> checklistItems;
  final bool isPinned;
  final bool isArchived;
  final List<String> labels;
  final NoteColor color;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reminderId': reminderId,
    'isChecklist': isChecklist,
    'checklistItems': checklistItems.map((item) => item.toJson()).toList(),
    'isPinned': isPinned,
    'isArchived': isArchived,
    'labels': labels,
    'color': color.name,
  };

  factory Note.fromJson(Map<String, Object?> json) {
    final createdAt =
        _readDate(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return Note(
      id: json['id'] is String ? json['id']! as String : '',
      title: json['title'] is String ? json['title']! as String : '',
      content: json['content'] is String ? json['content']! as String : '',
      createdAt: createdAt,
      updatedAt: _readDate(json['updatedAt']) ?? createdAt,
      reminderId: json['reminderId'] is String
          ? json['reminderId']! as String
          : null,
      isChecklist: json['isChecklist'] is bool
          ? json['isChecklist']! as bool
          : false,
      checklistItems: _readChecklistItems(json['checklistItems']),
      isPinned: json['isPinned'] is bool ? json['isPinned']! as bool : false,
      isArchived: json['isArchived'] is bool
          ? json['isArchived']! as bool
          : false,
      labels: json['labels'] is List
          ? (json['labels']! as List)
                .whereType<String>()
                .map((label) => label.trim())
                .where((label) => label.isNotEmpty)
                .toList()
          : const [],
      color: _readNoteColor(json['color']),
    );
  }

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    String? reminderId,
    bool clearReminder = false,
    bool? isChecklist,
    List<NoteChecklistItem>? checklistItems,
    bool? isPinned,
    bool? isArchived,
    List<String>? labels,
    NoteColor? color,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderId: clearReminder ? null : reminderId ?? this.reminderId,
      isChecklist: isChecklist ?? this.isChecklist,
      checklistItems: checklistItems ?? this.checklistItems,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      labels: labels ?? this.labels,
      color: color ?? this.color,
    );
  }
}

List<NoteChecklistItem> _readChecklistItems(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is Map) NoteChecklistItem.fromJson(_stringKeyedMap(item)),
  ];
}

Map<String, Object?> _stringKeyedMap(Map<dynamic, dynamic> value) => {
  for (final entry in value.entries)
    if (entry.key is String) entry.key as String: entry.value,
};

NoteColor _readNoteColor(Object? value) {
  if (value is! String) {
    return NoteColor.standard;
  }
  return NoteColor.values.firstWhere(
    (color) => color.name == value,
    orElse: () => NoteColor.standard,
  );
}

DateTime? _readDate(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}
