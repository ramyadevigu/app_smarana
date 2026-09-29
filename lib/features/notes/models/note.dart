class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.reminderId,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reminderId;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reminderId': reminderId,
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
    );
  }

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    String? reminderId,
    bool clearReminder = false,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderId: clearReminder ? null : reminderId ?? this.reminderId,
    );
  }
}

DateTime? _readDate(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}
