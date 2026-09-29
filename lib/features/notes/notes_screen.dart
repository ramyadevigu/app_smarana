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
  final _searchController = TextEditingController();
  late final NoteStorage _noteStorage;
  late final ReminderStorage _reminderStorage;
  List<Note> _notes = [];
  List<Reminder> _reminders = [];
  String? _selectedLabel;
  bool _isSearching = false;
  bool _showArchived = false;
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _noteStorage = widget.noteStorage ?? NoteStorage();
    _reminderStorage = widget.reminderStorage ?? ReminderStorage();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<Note> get _visibleNotes {
    final query = _searchController.text.trim().toLowerCase();
    final notes = _notes.where((note) {
      if (note.isArchived != _showArchived) {
        return false;
      }
      if (_selectedLabel != null && !note.labels.contains(_selectedLabel)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.labels.any((label) => label.toLowerCase().contains(query)) ||
          note.checklistItems.any(
            (item) => item.text.toLowerCase().contains(query),
          );
    }).toList();
    notes.sort((first, second) {
      if (first.isPinned != second.isPinned) {
        return first.isPinned ? -1 : 1;
      }
      return second.updatedAt.compareTo(first.updatedAt);
    });
    return notes;
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
        final checklistDescription = draft.checklistItems
            .map((item) => '${item.isChecked ? '[x]' : '[ ]'} ${item.text}')
            .join('\n');
        final reminderTitle = draft.title.isNotEmpty
            ? draft.title
            : draft.isChecklist
            ? draft.checklistItems.isEmpty
                  ? 'Checklist reminder'
                  : draft.checklistItems.first.text
            : draft.content;
        final reminder = Reminder(
          id: reminderId,
          title: reminderTitle,
          description: draft.isChecklist ? checklistDescription : draft.content,
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
        isChecklist: draft.isChecklist,
        checklistItems: draft.checklistItems,
        isPinned: draft.isPinned,
        isArchived: draft.isArchived,
        labels: draft.labels,
        color: draft.color,
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
              : 'Delete "${note.title}"? Its reminder will remain in Alarms.',
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

  Future<void> _updateNote(Note updatedNote) async {
    setState(() {
      final index = _notes.indexWhere((note) => note.id == updatedNote.id);
      if (index >= 0) {
        _notes[index] = updatedNote;
      }
    });
    try {
      await _noteStorage.updateNote(updatedNote);
    } on Exception {
      if (!mounted) {
        return;
      }
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update the note.')),
      );
    }
  }

  Future<void> _toggleChecklistItem(
    Note note,
    NoteChecklistItem item,
    bool isChecked,
  ) async {
    final updatedItems = note.checklistItems
        .map(
          (current) => current.id == item.id
              ? current.copyWith(isChecked: isChecked)
              : current,
        )
        .toList();
    final sortedItems = [
      ...updatedItems.where((item) => !item.isChecked),
      ...updatedItems.where((item) => item.isChecked),
    ];
    await _updateNote(
      note.copyWith(checklistItems: sortedItems, updatedAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                key: const ValueKey('notes-search-field'),
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search notes',
                  border: InputBorder.none,
                ),
              )
            : Text(_showArchived ? 'Archived notes' : 'Notes'),
        actions: [
          IconButton(
            key: const ValueKey('notes-search-toggle'),
            tooltip: _isSearching ? 'Close search' : 'Search notes',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
            icon: Icon(_isSearching ? Icons.close : Icons.search),
          ),
          IconButton(
            key: const ValueKey('notes-archive-toggle'),
            tooltip: _showArchived ? 'Show notes' : 'Show archived notes',
            onPressed: () => setState(() {
              _showArchived = !_showArchived;
              _selectedLabel = null;
            }),
            icon: Icon(
              _showArchived ? Icons.note_alt_outlined : Icons.archive_outlined,
            ),
          ),
          ?widget.appMenu,
        ],
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
            Text(
              _showArchived ? 'No archived notes' : 'No notes yet',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    final visibleNotes = _visibleNotes;
    if (visibleNotes.isEmpty) {
      return Center(
        child: Text(
          _showArchived
              ? 'No archived notes'
              : _searchController.text.trim().isNotEmpty ||
                    _selectedLabel != null
              ? 'No matching notes'
              : 'No notes yet',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    return Column(
      children: [
        _buildLabelFilters(),
        Expanded(
          child: GridView.builder(
            key: const ValueKey('notes-grid'),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: 260,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: visibleNotes.length,
            itemBuilder: (context, index) =>
                _buildNoteCard(context, visibleNotes[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelFilters() {
    final labels =
        _notes
            .where((note) => note.isArchived == _showArchived)
            .expand((note) => note.labels)
            .toSet()
            .toList()
          ..sort();
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('All labels'),
              selected: _selectedLabel == null,
              onSelected: (_) => setState(() => _selectedLabel = null),
            ),
          ),
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                key: ValueKey('note-label-filter-$label'),
                label: Text(label),
                selected: _selectedLabel == label,
                onSelected: (_) => setState(() {
                  _selectedLabel = _selectedLabel == label ? null : label;
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reminder = _reminderFor(note);
    final noteBackground = _noteBackground(note.color, colorScheme);
    final noteForeground = _noteForeground(note.color, colorScheme);
    return Card(
      key: ValueKey('note-card-${note.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: noteBackground,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: noteForeground,
                      ),
                    ),
                  ),
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.push_pin,
                        size: 18,
                        color: noteForeground,
                      ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'More actions for ${note.title}',
                    onSelected: (action) {
                      if (action == 'edit') {
                        _openEditor(note: note);
                      } else if (action == 'pin') {
                        _updateNote(
                          note.copyWith(
                            isPinned: !note.isPinned,
                            updatedAt: DateTime.now(),
                          ),
                        );
                      } else if (action == 'archive') {
                        _updateNote(
                          note.copyWith(
                            isArchived: !note.isArchived,
                            updatedAt: DateTime.now(),
                          ),
                        );
                      } else if (action == 'delete') {
                        _deleteNote(note);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: ListTile(
                          leading: Icon(
                            note.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin,
                          ),
                          title: Text(note.isPinned ? 'Unpin' : 'Pin'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(
                            note.isArchived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                          ),
                          title: Text(
                            note.isArchived ? 'Unarchive' : 'Archive',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
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
              if (note.isChecklist)
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in note.checklistItems.take(3))
                          SizedBox(
                            height: 30,
                            child: Row(
                              children: [
                                Checkbox(
                                  key: ValueKey(
                                    'note-check-${note.id}-${item.id}',
                                  ),
                                  value: item.isChecked,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (value) {
                                    if (value != null) {
                                      _toggleChecklistItem(note, item, value);
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    item.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: noteForeground,
                                      decoration: item.isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (note.checklistItems.length > 3)
                          Text(
                            '+${note.checklistItems.length - 3} more',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: noteForeground,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else if (note.content.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      note.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: noteForeground.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (note.labels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      for (final label in note.labels.take(3))
                        ActionChip(
                          key: ValueKey('note-label-${note.id}-$label'),
                          label: Text(label),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _selectedLabel = label),
                        ),
                    ],
                  ),
                ),
              if (reminder != null)
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: noteForeground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${MaterialLocalizations.of(context).formatMediumDate(reminder.dateTime)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(reminder.dateTime))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: noteForeground,
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
                    color: noteForeground.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _noteBackground(NoteColor color, ColorScheme colorScheme) {
    return switch (color) {
      NoteColor.standard => colorScheme.surfaceContainerLow,
      NoteColor.blue => colorScheme.primaryContainer,
      NoteColor.teal => colorScheme.secondaryContainer,
      NoteColor.amber => colorScheme.tertiaryContainer,
      NoteColor.red => colorScheme.errorContainer,
    };
  }

  Color _noteForeground(NoteColor color, ColorScheme colorScheme) {
    return switch (color) {
      NoteColor.standard => colorScheme.onSurface,
      NoteColor.blue => colorScheme.onPrimaryContainer,
      NoteColor.teal => colorScheme.onSecondaryContainer,
      NoteColor.amber => colorScheme.onTertiaryContainer,
      NoteColor.red => colorScheme.onErrorContainer,
    };
  }
}
