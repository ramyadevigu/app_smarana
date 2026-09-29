import 'package:flutter/material.dart';

import '../../reminders/models/reminder.dart';
import '../models/note.dart';

class NoteDraft {
  const NoteDraft({
    required this.title,
    required this.content,
    this.reminderDateTime,
  });

  final String title;
  final String content;
  final DateTime? reminderDateTime;
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note, this.reminder});

  final Note? note;
  final Reminder? reminder;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late DateTime _reminderDateTime;
  late bool _setReminder;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _setReminder = widget.reminder != null;
    _reminderDateTime =
        widget.reminder?.dateTime.toLocal() ??
        DateTime.now().add(const Duration(minutes: 5));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickReminderDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderDateTime,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      _reminderDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _reminderDateTime.hour,
        _reminderDateTime.minute,
      );
    });
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderDateTime),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _reminderDateTime = DateTime(
        _reminderDateTime.year,
        _reminderDateTime.month,
        _reminderDateTime.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      NoteDraft(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        reminderDateTime: _setReminder ? _reminderDateTime : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New note' : 'Edit note'),
        actions: [
          IconButton(
            key: const ValueKey('save-note'),
            tooltip: 'Save note',
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              TextFormField(
                key: const ValueKey('note-title'),
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleLarge,
                validator: (_) {
                  if (_titleController.text.trim().isEmpty &&
                      _contentController.text.trim().isEmpty) {
                    return 'Add a title or note text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('note-content'),
                controller: _contentController,
                minLines: 8,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Write a note...',
                  border: InputBorder.none,
                ),
              ),
              const Divider(height: 28),
              SwitchListTile(
                key: const ValueKey('note-reminder-toggle'),
                contentPadding: EdgeInsets.zero,
                value: _setReminder,
                onChanged: (value) => setState(() => _setReminder = value),
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Set a reminder'),
                subtitle: const Text('Also add it to Alarms'),
              ),
              if (_setReminder) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('note-reminder-date'),
                      onPressed: _pickReminderDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        localizations.formatMediumDate(_reminderDateTime),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('note-reminder-time'),
                      onPressed: _pickReminderTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        localizations.formatTimeOfDay(
                          TimeOfDay.fromDateTime(_reminderDateTime),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
