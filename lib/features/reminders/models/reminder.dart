enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

class Reminder {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final RecurrenceType recurrence;
  final bool enabled;
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.recurrence = RecurrenceType.none,
    this.enabled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'recurrence': recurrence.name,
      'enabled': enabled,
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
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}