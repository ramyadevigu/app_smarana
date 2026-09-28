import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../services/reminder_storage.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;

  const AddReminderScreen({super.key, this.reminder});

  bool get isEditing => reminder != null;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _storage = ReminderStorage();
  final _uuid = const Uuid();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  RecurrenceType _recurrence = RecurrenceType.none;
  bool _enabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final reminder = widget.reminder;
    if (reminder != null) {
      _titleController.text = reminder.title;
      _descriptionController.text = reminder.description ?? '';
      _selectedDate = DateTime(
        reminder.dateTime.year,
        reminder.dateTime.month,
        reminder.dateTime.day,
      );
      _selectedTime = TimeOfDay.fromDateTime(reminder.dateTime);
      _recurrence = reminder.recurrenceRule.type;
      _enabled = reminder.enabled;
      return;
    }

    final initialDateTime = DateTime.now().add(const Duration(minutes: 5));
    _selectedDate = DateTime(
      initialDateTime.year,
      initialDateTime.month,
      initialDateTime.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(FormFieldState<DateTime> field) async {
    final today = DateTime.now();
    final firstDate = widget.isEditing
        ? DateTime(1900)
        : DateTime(today.year, today.month, today.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (date == null) {
      return;
    }

    setState(() {
      _selectedDate = date;
    });
    field.didChange(date);
  }

  Future<void> _selectTime(FormFieldState<TimeOfDay> field) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _selectedTime = time;
    });
    field.didChange(time);
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
                key: ValueKey('repeat-${type.name}'),
                leading: Icon(_recurrenceIcon(type)),
                title: Text(_recurrenceOptionLabel(type)),
                trailing: type == _recurrence ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(type),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _recurrence = selected;
    });
  }

  Future<void> _saveReminder() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final title = _titleController.text.trim();
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) {
      return;
    }

    final existing = widget.reminder;
    final reminder = Reminder(
      id: existing?.id ?? _uuid.v4(),
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dateTime: DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
      recurrenceRule: RecurrenceRule(
        type: _recurrence,
        dayOfMonth: _recurrence == RecurrenceType.monthly ? date.day : null,
        dayOfWeek: _recurrence == RecurrenceType.weekly ? date.weekday : null,
      ),
      enabled: _enabled,
      isCompleted: existing?.isCompleted ?? false,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditing) {
        await _storage.updateReminder(reminder);
      } else {
        await _storage.addReminder(reminder);
      }

      if (mounted) {
        Navigator.of(context).pop(reminder);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the reminder.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(BuildContext context, DateTime? date) {
    return date == null
        ? 'Select a date'
        : MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _formatTime(BuildContext context, TimeOfDay? time) {
    return time?.format(context) ?? 'Select a time';
  }

  String _recurrenceOptionLabel(RecurrenceType type) {
    return switch (type) {
      RecurrenceType.none => 'Does not repeat',
      RecurrenceType.daily => 'Every day',
      RecurrenceType.weekly => 'Every week',
      RecurrenceType.monthly => 'Every month',
      RecurrenceType.yearly => 'Every year',
    };
  }

  String _recurrenceSummary(BuildContext context) {
    final time = _selectedTime?.format(context);
    final timeSuffix = time == null ? '' : ' at $time';

    return switch (_recurrence) {
      RecurrenceType.none => 'Does not repeat',
      RecurrenceType.daily => 'Every day$timeSuffix',
      RecurrenceType.weekly =>
        'Every ${_weekdayName(_selectedDate?.weekday ?? DateTime.now().weekday)}'
            '$timeSuffix',
      RecurrenceType.monthly =>
        '${_ordinal(_selectedDate?.day ?? DateTime.now().day)} of every month'
            '$timeSuffix',
      RecurrenceType.yearly => _yearlySummary(timeSuffix),
    };
  }

  String _yearlySummary(String timeSuffix) {
    final date = _selectedDate ?? DateTime.now();
    return 'Every year on ${date.day} ${_monthNames[date.month - 1]}'
        '$timeSuffix';
  }

  IconData _recurrenceIcon(RecurrenceType type) {
    return switch (type) {
      RecurrenceType.none => Icons.event,
      RecurrenceType.daily => Icons.today,
      RecurrenceType.weekly => Icons.view_week,
      RecurrenceType.monthly => Icons.calendar_month,
      RecurrenceType.yearly => Icons.date_range,
    };
  }

  String _weekdayName(int day) {
    return switch (day) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => '',
    };
  }

  String _ordinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }

    return switch (number % 10) {
      1 => '${number}st',
      2 => '${number}nd',
      3 => '${number}rd',
      _ => '${number}th',
    };
  }

  Widget _fieldError(String? message) {
    if (message == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle = widget.isEditing ? 'Edit Reminder' : 'Add Reminder';

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('title-field'),
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What do you want to remember?',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Title is required.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('description-field'),
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional details',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FormField<DateTime>(
                initialValue: _selectedDate,
                validator: (value) =>
                    value == null ? 'Date is required.' : null,
                builder: (field) => Column(
                  children: [
                    ListTile(
                      key: const ValueKey('date-field'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text(_formatDate(context, field.value)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectDate(field),
                    ),
                    _fieldError(field.errorText),
                  ],
                ),
              ),
              const Divider(),
              FormField<TimeOfDay>(
                initialValue: _selectedTime,
                validator: (value) =>
                    value == null ? 'Time is required.' : null,
                builder: (field) => Column(
                  children: [
                    ListTile(
                      key: const ValueKey('time-field'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text('Time'),
                      subtitle: Text(_formatTime(context, field.value)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectTime(field),
                    ),
                    _fieldError(field.errorText),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                key: const ValueKey('repeat-field'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat),
                title: const Text('Repeat'),
                subtitle: Text(_recurrenceSummary(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectRecurrence,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('save-reminder'),
                  onPressed: _isSaving ? null : _saveReminder,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.isEditing ? 'Save Changes' : 'Save Reminder',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
