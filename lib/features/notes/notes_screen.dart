import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../reminders/models/reminder.dart';
import '../reminders/services/reminder_storage.dart';
import 'models/note.dart';
import 'screens/note_editor_screen.dart';
import 'services/note_storage.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    this.noteStorage,
    this.reminderStorage,
    this.appMenu,
  });

  final NoteStorage? noteStorage;
  final ReminderStorage? reminderStorage;
  final Widget? appMenu;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _uuid = const Uuid();
  late final NoteStorage _noteStorage;
  late final ReminderStorage _reminderStorage;
  List<Note> _notes = [];
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _noteStorage = widget.noteStorage ?? NoteStorage();
    _reminderStorage = widget.reminderStorage ?? ReminderStorage();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _hasLoadError = false;
      });
    }
    try {
      final notes = await _noteStorage.getNotes();
      final reminders = await _reminderStorage.getReminders();
      if (!mounted) {
        return;
      }
      setState(() {
        _notes = notes;
        _reminders = reminders;
        _isLoading = false;
        _hasLoadError = false;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasLoadError = true;
      });
    }
  }

  Reminder? _reminderFor(Note note) {
    final reminderId = note.reminderId;
    if (reminderId == null) {
      return null;
    }
    for (final reminder in _reminders) {
      if (reminder.id == reminderId) {
        return reminder;
      }
    }
    return null;
  }

  Future<void> _openEditor({Note? note}) async {
    final draft = await Navigator.of(context).push<NoteDraft>(
      MaterialPageRoute<NoteDraft>(
        builder: (_) => NoteEditorScreen(
          note: note,
          reminder: note == null ? null : _reminderFor(note),
        ),
      ),
    );
    if (draft != null && mounted) {
      await _saveDraft(note, draft);
    }
  }

  Future<void> _saveDraft(Note? existing, NoteDraft draft) async {
    final now = DateTime.now();
    final linkedReminder = existing == null ? null : _reminderFor(existing);
    var reminderId = existing?.reminderId;
    try {
      if (draft.reminderDateTime case final dateTime?) {
        reminderId ??= _uuid.v4();
        final reminder = Reminder(
          id: reminderId,
          title: draft.title.isEmpty ? draft.content : draft.title,
          description: draft.title.isEmpty ? null : draft.content,
          dateTime: dateTime,
          recurrenceRule:
              linkedReminder?.recurrenceRule ??
              const RecurrenceRule(type: RecurrenceType.none),
          enabled: true,
          isCompleted: false,
          createdAt: linkedReminder?.createdAt ?? now,
        );
        if (linkedReminder == null) {
          await _reminderStorage.addReminder(reminder);
        } else {
          await _reminderStorage.updateReminder(reminder);
        }
      } else if (reminderId != null) {
        await _reminderStorage.deleteReminder(reminderId);
        reminderId = null;
      }

      final note = Note(
        id: existing?.id ?? _uuid.v4(),
        title: draft.title,
        content: draft.content,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        reminderId: reminderId,
      );
      if (existing == null) {
        await _noteStorage.addNote(note);
      } else {
        await _noteStorage.updateNote(note);
      }
      await _loadData();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the note or reminder.')),
        );
      }
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete note?'),
        content: Text(
          note.reminderId == null
              ? 'Delete "${note.title}"? This cannot be undone.'
              : 'Delete "${note.title}" and its reminder?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      if (note.reminderId != null) {
        await _reminderStorage.deleteReminder(note.reminderId!);
      }
      await _noteStorage.deleteNote(note.id);
      await _loadData();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete the note.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [?widget.appMenu],
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('create-note'),
        tooltip: 'Create note',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasLoadError) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => _loadData(showLoading: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }
    if (_notes.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('No notes yet', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        key: const ValueKey('notes-grid'),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 184,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _notes.length,
        itemBuilder: (context, index) => _buildNoteCard(context, _notes[index]),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reminder = _reminderFor(note);
    return Card(
      key: ValueKey('note-card-${note.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => _openEditor(note: note),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled note' : note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More actions for ${note.title}',
                    onSelected: (action) {
                      if (action == 'edit') {
                        _openEditor(note: note);
                      } else if (action == 'delete') {
                        _deleteNote(note);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (note.content.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      note.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (reminder != null)
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${MaterialLocalizations.of(context).formatMediumDate(reminder.dateTime)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(reminder.dateTime))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(note.updatedAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
