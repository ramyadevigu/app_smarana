import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../services/reminder_storage.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _storage = ReminderStorage();
  final _uuid = const Uuid();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  RecurrenceType _recurrence = RecurrenceType.none;

  int? _selectedDayOfWeek;

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (date == null) {
      return;
    }

    setState(() {
      _selectedDate = date;

      // If weekly recurrence is already selected,
      // update the weekday to match the selected date.
      if (_recurrence == RecurrenceType.weekly) {
        _selectedDayOfWeek = date.weekday;
      }
    });
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (time == null) {
      return;
    }

    setState(() {
      _selectedTime = time;
    });
  }

  Future<void> _selectRecurrence() async {
    final selected = await showModalBottomSheet<RecurrenceType>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: RecurrenceType.values.map((type) {
              return ListTile(
                leading: Icon(_recurrenceIcon(type)),
                title: Text(_recurrenceLabel(type)),
                trailing: type == _recurrence
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context, type);
                },
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _recurrence = selected;

      if (selected == RecurrenceType.weekly) {
        _selectedDayOfWeek = _selectedDayOfWeek ?? _selectedDate.weekday;
      }
    });

    if (selected == RecurrenceType.weekly) {
      await _selectWeekday();
    }
  }

  Future<void> _selectWeekday() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (index) {
              final day = index + 1;

              return ListTile(
                title: Text(_weekdayName(day)),
                trailing: day == _selectedDayOfWeek
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context, day);
                },
              );
            }),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedDayOfWeek = selected;
      });
    }
  }

  Future<void> _saveReminder() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reminder title.'),
        ),
      );
      return;
    }

    if (_recurrence == RecurrenceType.weekly &&
        _selectedDayOfWeek == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a weekday.'),
        ),
      );
      return;
    }

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    setState(() {
      _isSaving = true;
    });

    final reminder = Reminder(
      id: _uuid.v4(),
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dateTime: dateTime,
      recurrenceRule: RecurrenceRule(
        type: _recurrence,
        dayOfMonth: _recurrence == RecurrenceType.monthly
            ? _selectedDate.day
            : null,
        dayOfWeek: _recurrence == RecurrenceType.weekly
            ? _selectedDayOfWeek
            : null,
      ),
      enabled: true,
      createdAt: DateTime.now(),
    );

    await _storage.addReminder(reminder);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    Navigator.of(context).pop(reminder);
  }

  String _formatDate() {
    return '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';
  }

  String _formatTime() {
    return _selectedTime.format(context);
  }

  String _recurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return 'Does not repeat';

      case RecurrenceType.daily:
        return 'Every day';

      case RecurrenceType.weekly:
        final day = _selectedDayOfWeek ?? _selectedDate.weekday;
        return 'Every ${_weekdayName(day)}';

      case RecurrenceType.monthly:
        return 'Every month on the ${_ordinal(_selectedDate.day)}';

      case RecurrenceType.yearly:
        return 'Every year';
    }
  }

  IconData _recurrenceIcon(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return Icons.event;

      case RecurrenceType.daily:
        return Icons.today;

      case RecurrenceType.weekly:
        return Icons.view_week;

      case RecurrenceType.monthly:
        return Icons.calendar_month;

      case RecurrenceType.yearly:
        return Icons.date_range;
    }
  }

  String _weekdayName(int day) {
    switch (day) {
      case DateTime.monday:
        return 'Monday';

      case DateTime.tuesday:
        return 'Tuesday';

      case DateTime.wednesday:
        return 'Wednesday';

      case DateTime.thursday:
        return 'Thursday';

      case DateTime.friday:
        return 'Friday';

      case DateTime.saturday:
        return 'Saturday';

      case DateTime.sunday:
        return 'Sunday';

      default:
        return '';
    }
  }

  String _ordinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }

    switch (number % 10) {
      case 1:
        return '${number}st';

      case 2:
        return '${number}nd';

      case 3:
        return '${number}rd';

      default:
        return '${number}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Reminder'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Reminder',
                hintText: 'What do you want to remember?',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(_formatDate()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectDate,
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Time'),
              subtitle: Text(_formatTime()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectTime,
            ),

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: const Text('Repeat'),
              subtitle: Text(_recurrenceLabel(_recurrence)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectRecurrence,
            ),

            if (_recurrence == RecurrenceType.weekly) ...[
              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_view_week),
                title: const Text('Weekday'),
                subtitle: Text(
                  _weekdayName(
                    _selectedDayOfWeek ?? _selectedDate.weekday,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectWeekday,
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveReminder,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Reminder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}