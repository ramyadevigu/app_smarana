import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../reminders/models/reminder.dart';
import '../models/note.dart';

class NoteDraft {
  const NoteDraft({
    required this.title,
    required this.content,
    required this.isChecklist,
    required this.checklistItems,
    required this.labels,
    required this.isPinned,
    required this.isArchived,
    required this.color,
    this.reminderDateTime,
  });

  final String title;
  final String content;
  final bool isChecklist;
  final List<NoteChecklistItem> checklistItems;
  final List<String> labels;
  final bool isPinned;
  final bool isArchived;
  final NoteColor color;
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
  final _uuid = const Uuid();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _labelsController;
  late final TextEditingController _newChecklistItemController;
  late List<NoteChecklistItem> _checklistItems;
  late bool _isChecklist;
  late bool _isPinned;
  late bool _isArchived;
  late NoteColor _color;
  late DateTime _reminderDateTime;
  late bool _setReminder;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _labelsController = TextEditingController(
      text: widget.note?.labels.join(', ') ?? '',
    );
    _newChecklistItemController = TextEditingController();
    _checklistItems = List.of(widget.note?.checklistItems ?? const []);
    _isChecklist = widget.note?.isChecklist ?? false;
    _isPinned = widget.note?.isPinned ?? false;
    _isArchived = widget.note?.isArchived ?? false;
    _color = widget.note?.color ?? NoteColor.standard;
    _setReminder = widget.reminder != null;
    _reminderDateTime =
        widget.reminder?.dateTime.toLocal() ??
        DateTime.now().add(const Duration(minutes: 5));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _labelsController.dispose();
    _newChecklistItemController.dispose();
    super.dispose();
  }

  void _addChecklistItem() {
    final text = _newChecklistItemController.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _checklistItems = [
        ..._checklistItems,
        NoteChecklistItem(id: _uuid.v4(), text: text),
      ];
      _newChecklistItemController.clear();
    });
  }

  void _toggleChecklistItem(NoteChecklistItem item, bool isChecked) {
    final updated = _checklistItems
        .map(
          (current) => current.id == item.id
              ? current.copyWith(isChecked: isChecked)
              : current,
        )
        .toList();
    setState(() {
      _checklistItems = [
        ...updated.where((item) => !item.isChecked),
        ...updated.where((item) => item.isChecked),
      ];
    });
  }

  void _updateChecklistItem(NoteChecklistItem item, String text) {
    _checklistItems = _checklistItems
        .map(
          (current) =>
              current.id == item.id ? current.copyWith(text: text) : current,
        )
        .toList();
  }

  void _removeChecklistItem(NoteChecklistItem item) {
    setState(() {
      _checklistItems = _checklistItems
          .where((current) => current.id != item.id)
          .toList();
    });
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
    final labels = <String>[];
    final seenLabels = <String>{};
    for (final rawLabel in _labelsController.text.split(',')) {
      final label = rawLabel.trim();
      if (label.isNotEmpty && seenLabels.add(label.toLowerCase())) {
        labels.add(label);
      }
    }
    Navigator.of(context).pop(
      NoteDraft(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        isChecklist: _isChecklist,
        checklistItems: _checklistItems
            .where((item) => item.text.trim().isNotEmpty)
            .toList(),
        labels: labels,
        isPinned: _isPinned,
        isArchived: _isArchived,
        color: _color,
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
                  final hasContent = _isChecklist
                      ? _checklistItems.any(
                          (item) => item.text.trim().isNotEmpty,
                        )
                      : _contentController.text.trim().isNotEmpty;
                  if (_titleController.text.trim().isEmpty && !hasContent) {
                    return 'Add a title or note text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                key: const ValueKey('note-type-selector'),
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.notes_outlined),
                    label: Text('Text'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.checklist_outlined),
                    label: Text('Checklist'),
                  ),
                ],
                selected: {_isChecklist},
                onSelectionChanged: (selection) {
                  setState(() => _isChecklist = selection.first);
                },
              ),
              const SizedBox(height: 16),
              if (_isChecklist)
                ..._buildChecklistEditor(context)
              else
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
              const Divider(height: 28),
              Text(
                'Organization',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('note-labels'),
                controller: _labelsController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Labels',
                  hintText: 'Work, Personal',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final color in NoteColor.values)
                    ChoiceChip(
                      key: ValueKey('note-color-${color.name}'),
                      tooltip: _colorLabel(color),
                      label: const SizedBox(width: 18, height: 18),
                      selected: _color == color,
                      selectedColor: _colorSurface(
                        color,
                        Theme.of(context).colorScheme,
                      ),
                      backgroundColor: _colorSurface(
                        color,
                        Theme.of(context).colorScheme,
                      ),
                      onSelected: (_) => setState(() => _color = color),
                    ),
                ],
              ),
              SwitchListTile(
                key: const ValueKey('note-pinned-toggle'),
                contentPadding: EdgeInsets.zero,
                value: _isPinned,
                onChanged: (value) => setState(() => _isPinned = value),
                secondary: const Icon(Icons.push_pin_outlined),
                title: const Text('Pin note'),
              ),
              SwitchListTile(
                key: const ValueKey('note-archived-toggle'),
                contentPadding: EdgeInsets.zero,
                value: _isArchived,
                onChanged: (value) => setState(() => _isArchived = value),
                secondary: const Icon(Icons.archive_outlined),
                title: const Text('Archive note'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChecklistEditor(BuildContext context) {
    return [
      for (final item in _checklistItems)
        Row(
          key: ValueKey('checklist-row-${item.id}'),
          children: [
            Checkbox(
              key: ValueKey('checklist-toggle-${item.id}'),
              value: item.isChecked,
              onChanged: (value) {
                if (value != null) {
                  _toggleChecklistItem(item, value);
                }
              },
            ),
            Expanded(
              child: TextFormField(
                key: ValueKey('checklist-text-${item.id}'),
                initialValue: item.text,
                onChanged: (value) => _updateChecklistItem(item, value),
                decoration: const InputDecoration(
                  hintText: 'List item',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove item',
              onPressed: () => _removeChecklistItem(item),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('new-checklist-item'),
              controller: _newChecklistItemController,
              onSubmitted: (_) => _addChecklistItem(),
              decoration: const InputDecoration(
                hintText: 'Add an item',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add checklist item',
            onPressed: _addChecklistItem,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ];
  }

  Color _colorSurface(NoteColor color, ColorScheme colorScheme) {
    return switch (color) {
      NoteColor.standard => colorScheme.surfaceContainerLow,
      NoteColor.blue => colorScheme.primaryContainer,
      NoteColor.teal => colorScheme.secondaryContainer,
      NoteColor.amber => colorScheme.tertiaryContainer,
      NoteColor.red => colorScheme.errorContainer,
    };
  }

  String _colorLabel(NoteColor color) {
    return switch (color) {
      NoteColor.standard => 'Default',
      NoteColor.blue => 'Blue',
      NoteColor.teal => 'Teal',
      NoteColor.amber => 'Amber',
      NoteColor.red => 'Rose',
    };
  }
}
