enum RecurrenceType { none, daily, weekly, monthly, yearly }

class Reminder {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final RecurrenceType recurrence;
  final bool enabled;
  final bool isCompleted;
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.recurrence = RecurrenceType.none,
    this.enabled = true,
    this.isCompleted = false,
    required this.createdAt,
  });

  Reminder copyWith({DateTime? dateTime, bool? enabled, bool? isCompleted}) {
    return Reminder(
      id: id,
      title: title,
      description: description,
      dateTime: dateTime ?? this.dateTime,
      recurrence: recurrence,
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
      'recurrence': recurrence.name,
      'enabled': enabled,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dateTime: DateTime.parse(json['dateTime']),
      recurrence: RecurrenceType.values.firstWhere(
        (value) => value.name == json['recurrence'],
        orElse: () => RecurrenceType.none,
      ),
      enabled: json['enabled'] ?? true,
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
