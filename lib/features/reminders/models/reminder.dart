enum RecurrenceType { none, daily, weekly, monthly, yearly }

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

  const RecurrenceRule({required this.type, this.dayOfMonth, this.dayOfWeek});

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
    };
  }

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      type: _recurrenceTypeFromJson(json['type']),
      dayOfMonth: _readInteger(json['dayOfMonth'], minimum: 1, maximum: 31),
      dayOfWeek: _readInteger(json['dayOfWeek'], minimum: 1, maximum: 7),
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
    this.recurrenceRule = const RecurrenceRule(type: RecurrenceType.none),
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

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final recurrenceJson = json['recurrenceRule'];
    final dateTime = _dateTimeFromJson(json['dateTime']) ?? DateTime(1970);
    final recurrenceRule = recurrenceJson is Map
        ? RecurrenceRule.fromJson(_stringKeyedMap(recurrenceJson))
        : RecurrenceRule(type: _recurrenceTypeFromJson(json['recurrence']));

    return Reminder(
      id: json['id'] is String ? json['id'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      description: json['description'] is String
          ? json['description'] as String
          : null,
      dateTime: dateTime,
      recurrenceRule: recurrenceRule,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      isCompleted: json['isCompleted'] is bool
          ? json['isCompleted'] as bool
          : false,
      createdAt: _dateTimeFromJson(json['createdAt']) ?? dateTime,
    );
  }
}

RecurrenceType _recurrenceTypeFromJson(Object? value) {
  if (value is! String) {
    return RecurrenceType.none;
  }

  return RecurrenceType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => RecurrenceType.none,
  );
}

int? _readInteger(Object? value, {required int minimum, required int maximum}) {
  if (value is! num || !value.isFinite || value != value.roundToDouble()) {
    return null;
  }

  final integer = value.toInt();
  return integer >= minimum && integer <= maximum ? integer : null;
}

DateTime? _dateTimeFromJson(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}

Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> value) {
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}
