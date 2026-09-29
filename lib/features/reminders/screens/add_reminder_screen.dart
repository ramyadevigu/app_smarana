import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../services/reminder_storage.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;
  final ReminderStorage? storage;
  final DateTime? initialDate;

  const AddReminderScreen({
    super.key,
    this.reminder,
    this.storage,
    this.initialDate,
  });

  bool get isEditing => reminder != null;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();
  late final ReminderStorage _storage;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();

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
      return;
    }

    final initialDateTime = DateTime.now().add(const Duration(minutes: 5));
    final today = DateUtils.dateOnly(DateTime.now());
    final requestedDate = widget.initialDate ?? initialDateTime;
    final initialDate = requestedDate.isBefore(today) ? today : requestedDate;
    _selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
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
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = widget.isEditing ? DateTime(1900) : today;
    final selectedDate = _selectedDate ?? today;
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(firstDate) ? firstDate : selectedDate,
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
      initialEntryMode: TimePickerEntryMode.dial,
    );

    if (time == null) {
      return;
    }

    setState(() {
      _selectedTime = time;
    });
    field.didChange(time);
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
      recurrenceRule:
          existing?.recurrenceRule ??
          const RecurrenceRule(type: RecurrenceType.none),
      enabled: existing?.enabled ?? true,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(
          height: 54,
          child: FilledButton(
            key: const ValueKey('save-reminder'),
            onPressed: _isSaving ? null : _saveReminder,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? 'Save Changes' : 'Save Reminder'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  prefixIcon: Icon(Icons.edit_outlined),
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
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'DATE & TIME',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              Material(
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    FormField<DateTime>(
                      initialValue: _selectedDate,
                      validator: (value) =>
                          value == null ? 'Date is required.' : null,
                      builder: (field) => Column(
                        children: [
                          ListTile(
                            key: const ValueKey('date-field'),
                            leading: Icon(
                              Icons.calendar_month_outlined,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Date'),
                            subtitle: Text(_formatDate(context, field.value)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectDate(field),
                          ),
                          _fieldError(field.errorText),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    FormField<TimeOfDay>(
                      initialValue: _selectedTime,
                      validator: (value) =>
                          value == null ? 'Time is required.' : null,
                      builder: (field) => Column(
                        children: [
                          ListTile(
                            key: const ValueKey('time-field'),
                            leading: Icon(
                              Icons.schedule_outlined,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Time'),
                            subtitle: Text(_formatTime(context, field.value)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectTime(field),
                          ),
                          _fieldError(field.errorText),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
