import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/reminder.dart';
import 'services/reminder_storage.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final ReminderStorage _storage = ReminderStorage();
  late Future<List<Reminder>> _reminders;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _loadReminders() {
    _reminders = _storage.getReminders();
  }

  Future<void> _openAddReminder() async {
    final Reminder? reminder = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute<Reminder>(builder: (_) => const AddReminderScreen()),
    );

    if (reminder != null && mounted) {
      setState(_loadReminders);
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    await _storage.deleteReminder(reminder.id);

    if (mounted) {
      setState(_loadReminders);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: FutureBuilder<List<Reminder>>(
        future: _reminders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading reminders...'));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load reminders.'));
          }

          final reminders = snapshot.data ?? [];
          if (reminders.isEmpty) {
            return const Center(child: Text('No reminders yet.'));
          }

          return ListView.builder(
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              return Dismissible(
                key: ValueKey(reminder.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _deleteReminder(reminder),
                background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: ListTile(
                  title: Text(reminder.title),
                  subtitle: Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(reminder.dateTime)} '
                    '${TimeOfDay.fromDateTime(reminder.dateTime).format(context)}',
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddReminder,
        tooltip: 'Add reminder',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;

  const AddReminderScreen({super.key, this.reminder});

  bool get isEditing => reminder != null;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final ReminderStorage _storage = ReminderStorage();

  final Uuid _uuid = const Uuid();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  RecurrenceType _recurrence = RecurrenceType.none;

  bool _enabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final reminder = widget.reminder;

    if (reminder != null) {
      // Editing an existing reminder.
      _titleController.text = reminder.title;
      _descriptionController.text = reminder.description ?? '';

      _selectedDate = reminder.dateTime;

      _selectedTime = TimeOfDay.fromDateTime(reminder.dateTime);

      _recurrence = reminder.recurrence;
      _enabled = reminder.enabled;
    } else {
      // Creating a new reminder.
      final now = DateTime.now();
      final defaultDateTime = now.add(const Duration(minutes: 5));

      _selectedDate = DateTime(
        defaultDateTime.year,
        defaultDateTime.month,
        defaultDateTime.day,
      );

      _selectedTime = TimeOfDay.fromDateTime(defaultDateTime);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // DATE
  // ------------------------------------------------------------

  Future<void> _selectDate() async {
    final DateTime today = DateTime.now();
    final DateTime firstDate = widget.isEditing
        ? DateTime(2000)
        : DateTime(today.year, today.month, today.day);

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (date == null) {
      return;
    }

    setState(() {
      _selectedDate = date;
    });
  }

  // ------------------------------------------------------------
  // TIME
  // ------------------------------------------------------------

  Future<void> _selectTime() async {
    final TimeOfDay? time = await showTimePicker(
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

  // ------------------------------------------------------------
  // RECURRENCE
  // ------------------------------------------------------------

  String _recurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return 'Does not repeat';

      case RecurrenceType.daily:
        return 'Every day';

      case RecurrenceType.weekly:
        return 'Every week';

      case RecurrenceType.monthly:
        return 'Every month';

      case RecurrenceType.yearly:
        return 'Every year';
    }
  }

  Future<void> _selectRecurrence() async {
    final RecurrenceType? selected = await showModalBottomSheet<RecurrenceType>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: RecurrenceType.values.map((type) {
              return ListTile(
                title: Text(_recurrenceLabel(type)),
                trailing: type == _recurrence ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(context).pop(type);
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
    });
  }

  // ------------------------------------------------------------
  // SAVE
  // ------------------------------------------------------------

  Future<void> _saveReminder() async {
    final String title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder title.')),
      );

      return;
    }

    final DateTime dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    setState(() {
      _isSaving = true;
    });

    final Reminder reminder = Reminder(
      id: widget.reminder?.id ?? _uuid.v4(),
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dateTime: dateTime,
      recurrence: _recurrence,
      enabled: _enabled,
      createdAt: widget.reminder?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.isEditing) {
        await _storage.updateReminder(reminder);
      } else {
        await _storage.addReminder(reminder);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(reminder);
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

  // ------------------------------------------------------------
  // FORMATTING
  // ------------------------------------------------------------

  String _formatDate() {
    return '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';
  }

  String _formatTime() {
    return _selectedTime.format(context);
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final String screenTitle = widget.isEditing
        ? 'Edit Reminder'
        : 'Add Reminder';

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // TITLE
            // --------------------------------------------------

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

            // --------------------------------------------------
            // DESCRIPTION
            // --------------------------------------------------
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

            // --------------------------------------------------
            // DATE
            // --------------------------------------------------
            ListTile(
              contentPadding: EdgeInsets.zero,

              leading: const Icon(Icons.calendar_today),

              title: const Text('Date'),

              subtitle: Text(_formatDate()),

              trailing: const Icon(Icons.chevron_right),

              onTap: _selectDate,
            ),

            const Divider(),

            // --------------------------------------------------
            // TIME
            // --------------------------------------------------
            ListTile(
              contentPadding: EdgeInsets.zero,

              leading: const Icon(Icons.access_time),

              title: const Text('Time'),

              subtitle: Text(_formatTime()),

              trailing: const Icon(Icons.chevron_right),

              onTap: _selectTime,
            ),

            const Divider(),

            // --------------------------------------------------
            // RECURRENCE
            // --------------------------------------------------
            ListTile(
              contentPadding: EdgeInsets.zero,

              leading: const Icon(Icons.repeat),

              title: const Text('Repeat'),

              subtitle: Text(_recurrenceLabel(_recurrence)),

              trailing: const Icon(Icons.chevron_right),

              onTap: _selectRecurrence,
            ),

            const Divider(),

            // --------------------------------------------------
            // ENABLED
            // --------------------------------------------------
            SwitchListTile(
              contentPadding: EdgeInsets.zero,

              title: const Text('Enabled'),

              subtitle: const Text('Enable or disable this reminder'),

              value: _enabled,

              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),

            const SizedBox(height: 32),

            // --------------------------------------------------
            // SAVE BUTTON
            // --------------------------------------------------
            SizedBox(
              width: double.infinity,
              height: 52,

              child: FilledButton(
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
          ],
        ),
      ),
    );
  }
}
