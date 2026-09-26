enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

class RecurrenceRule {
  final RecurrenceType type;

  /// Used for monthly recurrence.
  ///
  /// Example:
  /// 3 = 3rd day of every month.
  final int? dayOfMonth;

  /// Used for weekly recurrence.
  ///
  /// DateTime.monday = 1
  /// DateTime.tuesday = 2
  /// ...
  /// DateTime.sunday = 7
  final int? dayOfWeek;

  const RecurrenceRule({
    required this.type,
    this.dayOfMonth,
    this.dayOfWeek,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
    };
  }

  factory RecurrenceRule.fromJson(
    Map<String, dynamic> json,
  ) {
    final typeName = json['type'] as String?;

    final type = RecurrenceType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => RecurrenceType.none,
    );

    return RecurrenceRule(
      type: type,
      dayOfMonth: json['dayOfMonth'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
    );
  }

  RecurrenceRule copyWith({
    RecurrenceType? type,
    int? dayOfMonth,
    int? dayOfWeek,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    );
  }
}

class Reminder {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final RecurrenceRule recurrenceRule;
  final bool enabled;
  final bool isCompleted;
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.recurrenceRule = const RecurrenceRule(
      type: RecurrenceType.none,
    ),
    this.enabled = true,
    this.isCompleted = false,
    required this.createdAt,
  });

  Reminder copyWith({
    DateTime? dateTime,
    RecurrenceRule? recurrenceRule,
    bool? enabled,
    bool? isCompleted,
  }) {
    return Reminder(
      id: id,
      title: title,
      description: description,
      dateTime: dateTime ?? this.dateTime,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      enabled: enabled ?? this.enabled,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'recurrenceRule': recurrenceRule.toJson(),
      'enabled': enabled,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json,
  ) {
    final recurrenceJson = json['recurrenceRule'];

    RecurrenceRule recurrenceRule;

    if (recurrenceJson is Map) {
      recurrenceRule = RecurrenceRule.fromJson(
        Map<String, dynamic>.from(recurrenceJson),
      );
    } else {
      // Backward compatibility with reminders
      // saved using the old recurrence format.
      final oldRecurrence = json['recurrence'] as String?;

      final oldType = RecurrenceType.values.firstWhere(
        (value) => value.name == oldRecurrence,
        orElse: () => RecurrenceType.none,
      );

      recurrenceRule = RecurrenceRule(
        type: oldType,
      );
    }

    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dateTime: DateTime.parse(
        json['dateTime'] as String,
      ),
      recurrenceRule: recurrenceRule,
      enabled: json['enabled'] as bool? ?? true,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] as String,
      ),
    );
  }
}