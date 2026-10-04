import 'dart:async';

import 'package:flutter/material.dart';

import '../reminders/models/reminder.dart';
import '../reminders/services/reminder_storage.dart';
import 'models/note_workspace_models.dart';
import 'screens/all_notes_screen.dart';
import 'screens/notebook_detail_screen.dart';
import '../../../theme/app_colors.dart';
import 'theme/note_card_colors.dart';
import 'theme/notebook_colors.dart';
import 'services/note_workspace_storage.dart';
import 'widgets/notebook_list_tile.dart';
import 'widgets/recent_note_card.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    this.appMenu,
    this.onBackToSmarana,
    this.initialNotebooks,
    this.workspaceStorage,
  });

  final Widget? appMenu;
  final VoidCallback? onBackToSmarana;
  final List<Notebook>? initialNotebooks;
  final NoteWorkspaceStorage? workspaceStorage;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final NoteWorkspaceStorage _workspaceStorage;
  late final ReminderStorage _reminderStorage;
  late List<Notebook> _notebooks;
  Map<String, Reminder> _remindersById = const {};
  Map<String, NoteCardColor> _tagColors = const {};
  bool _isLoading = true;
  String? _storageError;
  NotebookIconType? _selectedCategory;
  String? _selectedNotebookId;
  bool _isSearchExpanded = false;

  static const Duration _recentUpdateWindow = Duration(days: 7);

  static const List<Notebook> _emptyNotebookList = [];

  @override
  void initState() {
    super.initState();
    _workspaceStorage = widget.workspaceStorage ?? NoteWorkspaceStorage();
    _reminderStorage = ReminderStorage();
    _notebooks = ensureDistinctNotebookColors(
      widget.initialNotebooks ?? _emptyNotebookList,
    );
    unawaited(_loadReminderIndex());
    if (widget.initialNotebooks != null) {
      _isLoading = false;
    } else {
      unawaited(_loadWorkspace());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _query => _searchController.text.trim().toLowerCase();

  Future<void> _loadWorkspace() async {
    try {
      final saved = await _workspaceStorage.loadWorkspace();
      final tagColors = await _workspaceStorage.loadTagColors();
      if (!mounted) {
        return;
      }
      setState(() {
        _notebooks = saved;
        _tagColors = tagColors;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _notebooks = List<Notebook>.of(_emptyNotebookList);
        _isLoading = false;
        _storageError = 'Notes could not be restored. Changes may not persist.';
      });
      debugPrint('Notes workspace restore failed: $error');
    }
  }

  Future<void> _persistWorkspace() async {
    try {
      await _workspaceStorage.saveWorkspace(_notebooks, tagColors: _tagColors);
      if (mounted && _storageError != null) {
        setState(() {
          _storageError = null;
        });
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _storageError = 'Notes could not be saved. Check device storage.';
      });
      debugPrint('Notes workspace save failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes could not be saved.')),
      );
    }
  }

  Future<void> _updateTagColors(Map<String, NoteCardColor> tagColors) async {
    setState(() {
      _tagColors = Map<String, NoteCardColor>.unmodifiable(tagColors);
    });
    if (widget.initialNotebooks == null) {
      await _persistWorkspace();
    }
  }

  Future<void> _changeTagColor(String tag, NoteCardColor color) {
    final updated = Map<String, NoteCardColor>.of(_tagColors)
      ..[tag.trim().toLowerCase()] = color;
    return _updateTagColors(updated);
  }

  Future<void> _updateNotebook(Notebook updated) async {
    setState(() {
      _notebooks = _notebooks.map((item) {
        return item.id == updated.id ? updated : item;
      }).toList();
    });
    if (widget.initialNotebooks == null) {
      await _persistWorkspace();
    }
  }

  List<RecentNoteView> get _filteredRecentNotes {
    final query = _query;
    return _recentNotes().where((note) {
      if (_selectedNotebookId != null &&
          note.notebookId != _selectedNotebookId) {
        return false;
      }
      if (_selectedCategory != null &&
          note.notebookIconType != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return note.note.title.toLowerCase().contains(query) ||
          note.notebookName.toLowerCase().contains(query) ||
          note.sectionName.toLowerCase().contains(query) ||
          note.note.preview.toLowerCase().contains(query);
    }).toList();
  }

  List<RecentNoteView> _recentNotes() {
    final views = <RecentNoteView>[];
    for (final notebook in _notebooks) {
      for (final note in notebook.notes) {
        final section = notebook.sections.where(
          (item) => item.id == note.sectionId,
        );
        final sectionName = section.isEmpty ? 'General' : section.first.name;
        views.add(
          RecentNoteView(
            note: note,
            notebookId: notebook.id,
            notebookIconType: notebook.iconType,
            notebookName: notebook.name,
            notebookIcon: notebook.icon,
            notebookColorValue: notebook.colorValue,
            sectionName: sectionName,
            tagColors: _tagColors,
          ),
        );
      }
    }
    final now = DateTime.now();
    views.sort((first, second) => _compareNotes(first, second, now));
    return views;
  }

  int _compareNotes(RecentNoteView first, RecentNoteView second, DateTime now) {
    final firstPriority = _notePriority(first, now);
    final secondPriority = _notePriority(second, now);
    final priorityComparison = firstPriority.compareTo(secondPriority);
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    if (firstPriority == 2) {
      final firstReminder = _activeReminderFor(first);
      final secondReminder = _activeReminderFor(second);
      if (firstReminder != null && secondReminder != null) {
        final reminderComparison = firstReminder.dateTime.compareTo(
          secondReminder.dateTime,
        );
        if (reminderComparison != 0) {
          return reminderComparison;
        }
      }
    }

    return second.note.updatedAt.compareTo(first.note.updatedAt);
  }

  int _notePriority(RecentNoteView note, DateTime now) {
    if (note.note.isPinned) {
      return 0;
    }
    if (note.note.updatedAt.isAfter(now.subtract(_recentUpdateWindow))) {
      return 1;
    }
    if (_activeReminderFor(note) != null) {
      return 2;
    }
    return 3;
  }

  Reminder? _activeReminderFor(RecentNoteView note) {
    final reminderId = note.note.reminderId;
    if (reminderId == null) {
      return null;
    }
    final reminder = _remindersById[reminderId];
    if (reminder == null || !reminder.enabled || reminder.isCompleted) {
      return null;
    }
    return reminder;
  }

  Future<void> _loadReminderIndex() async {
    try {
      final reminders = await _reminderStorage.getReminders();
      if (!mounted) {
        return;
      }
      setState(() {
        _remindersById = {
          for (final reminder in reminders) reminder.id: reminder,
        };
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _storageError ??= 'Reminder dates could not be loaded. Notes are sorted by update time.';
      });
      debugPrint('Notes reminder index restore failed: $error');
    }
  }

  Future<void> _createNotebook() async {
    final name = await _showNotebookNameDialog(
      title: 'New notebook',
      actionLabel: 'Create',
    );
    if (name == null || !mounted) {
      return;
    }
    final now = DateTime.now();
    final defaultSection = NoteSection(
      id: _id('section'),
      name: 'General',
      createdAt: now,
    );
    final colorValue = nextNotebookColorValue(
      _notebooks.map((notebook) => notebook.colorValue),
    );
    final notebook = Notebook(
      id: _id('notebook'),
      name: name,
      iconType: NotebookIconType.general,
      sections: [defaultSection],
      notes: const [],
      createdAt: now,
      updatedAt: now,
      colorValue: colorValue,
    );
    setState(() {
      _notebooks = [..._notebooks, notebook];
    });
    await _persistWorkspace();
  }

  Future<void> _openNotebook(
    Notebook notebook, {
    bool createNoteOnOpen = false,
    String? initialNoteId,
  }) async {
    if (_selectedNotebookId != notebook.id || _selectedCategory != null) {
      setState(() {
        _selectedNotebookId = notebook.id;
        _selectedCategory = null;
      });
    }
    final result = await Navigator.of(context).push<NotebookDetailResult>(
      MaterialPageRoute<NotebookDetailResult>(
        builder: (_) => NotebookDetailScreen(
          notebook: notebook,
          onNotebookChanged: _updateNotebook,
          tagColors: _tagColors,
          onTagColorsChanged: _updateTagColors,
          createNoteOnOpen: createNoteOnOpen,
          initialNoteId: initialNoteId,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.isDeleted) {
      setState(() {
        _notebooks = _notebooks
            .where((item) => item.id != notebook.id)
            .toList();
        _selectedCategory =
            _notebooks.any((item) => item.iconType == _selectedCategory)
            ? _selectedCategory
            : null;
        if (_selectedNotebookId == notebook.id) {
          _selectedNotebookId = null;
        }
      });
      await _persistWorkspace();
      return;
    }
    final updated = result.updatedNotebook;
    if (updated == null) {
      return;
    }
    await _updateNotebook(updated);
  }

  Future<void> _selectAndOpenNotebook(Notebook notebook) async {
    setState(() {
      _selectedNotebookId = notebook.id;
      _selectedCategory = null;
    });
    await _openNotebook(notebook);
  }

  Future<void> _showNotebookOptions(Notebook notebook) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final accentColor = notebookAccentColor(theme, notebook.colorValue);
        final surfaceColor = notebookSurfaceColor(theme, notebook.colorValue);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            notebookIconData(notebook.icon, notebook.iconType),
                            color: accentColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notebook.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  notebook.description.trim().isEmpty
                                      ? '${notebook.noteCount} notes'
                                      : notebook.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _notebookOptionTile(
                      context,
                      icon: Icons.edit_outlined,
                      label: 'Rename',
                      value: 'rename',
                    ),
                    _notebookOptionTile(
                      context,
                      icon: Icons.grid_view_rounded,
                      label: 'Change Icon',
                      value: 'icon',
                    ),
                    _notebookOptionTile(
                      context,
                      icon: Icons.palette_outlined,
                      label: 'Change Color',
                      value: 'color',
                    ),
                    _notebookOptionTile(
                      context,
                      icon: Icons.notes_rounded,
                      label: 'Edit Description',
                      value: 'description',
                    ),
                    const Divider(height: 12),
                    _notebookOptionTile(
                      context,
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete Notebook',
                      value: 'delete',
                      destructive: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'rename':
        await _renameNotebook(notebook);
        break;
      case 'icon':
        await _changeNotebookIcon(notebook);
        break;
      case 'color':
        await _changeNotebookColor(notebook);
        break;
      case 'description':
        await _editNotebookDescription(notebook);
        break;
      case 'delete':
        await _deleteNotebook(notebook);
        break;
    }
  }

  Widget _notebookOptionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool destructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = destructive ? colorScheme.error : null;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: foregroundColor),
      title: Text(label, style: TextStyle(color: foregroundColor)),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  Future<void> _renameNotebook(Notebook notebook) async {
    final name = await _showNotebookNameDialog(
      title: 'Rename notebook',
      actionLabel: 'Save',
      initialValue: notebook.name,
    );
    if (name == null || !mounted) {
      return;
    }
    await _updateNotebook(
      notebook.copyWith(name: name, updatedAt: DateTime.now()),
    );
  }

  Future<void> _editNotebookDescription(Notebook notebook) async {
    final description = await _showNotebookDescriptionDialog(
      initialValue: notebook.description,
    );
    if (description == null || !mounted) {
      return;
    }
    await _updateNotebook(
      notebook.copyWith(description: description, updatedAt: DateTime.now()),
    );
  }

  Future<void> _changeNotebookIcon(Notebook notebook) async {
    final selected = await showDialog<NotebookIcon>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final currentIcon =
            notebook.icon ?? defaultNotebookIcon(notebook.iconType);
        return AlertDialog(
          title: const Text('Change icon'),
          content: SizedBox(
            width: 320,
            height: 300,
            child: GridView.builder(
              itemCount: NotebookIcon.values.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final icon = NotebookIcon.values[index];
                final isSelected = icon == currentIcon;
                return Tooltip(
                  message: _iconLabel(icon),
                  child: Material(
                    color: isSelected
                        ? notebookSurfaceColor(theme, notebook.colorValue)
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(icon),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            notebookIconData(icon, notebook.iconType),
                            color: isSelected
                                ? notebookAccentColor(
                                    theme,
                                    notebook.colorValue,
                                  )
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: notebookAccentColor(
                                theme,
                                notebook.colorValue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    await _updateNotebook(
      notebook.copyWith(icon: selected, updatedAt: DateTime.now()),
    );
  }

  Future<void> _changeNotebookColor(Notebook notebook) async {
    final selectedColor = await showDialog<int>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final usedColors = _notebooks
            .where((item) => item.id != notebook.id)
            .map((item) => item.colorValue | 0xFF000000)
            .toSet();
        return AlertDialog(
          title: const Text('Change color'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (final color in NotebookBaseColor.values)
                      _notebookColorChoice(
                        context,
                        value: color.value,
                        label: color.label,
                        currentValue: notebook.colorValue,
                        enabled:
                            !usedColors.contains(color.value) ||
                            color.value == notebook.colorValue,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await _pickCustomNotebookColor(
                      context,
                      notebook.colorValue,
                    );
                    if (value != null && context.mounted) {
                      Navigator.of(context).pop(value);
                    }
                  },
                  icon: Icon(
                    Icons.colorize_rounded,
                    color: notebookAccentColor(theme, notebook.colorValue),
                  ),
                  label: const Text('Choose a custom color'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (selectedColor == null || !mounted) {
      return;
    }

    final isInUse = _notebooks.any(
      (item) =>
          item.id != notebook.id &&
          (item.colorValue | 0xFF000000) == (selectedColor | 0xFF000000),
    );
    if (isInUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That color is already used.')),
      );
      return;
    }
    await _updateNotebook(
      notebook.copyWith(
        colorValue: selectedColor | 0xFF000000,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Widget _notebookColorChoice(
    BuildContext context, {
    required int value,
    required String label,
    required int currentValue,
    required bool enabled,
  }) {
    final selected = (value | 0xFF000000) == (currentValue | 0xFF000000);
    return Tooltip(
      message: enabled ? label : '$label is already in use',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? () => Navigator.of(context).pop(value) : null,
        child: Container(
          decoration: BoxDecoration(
            color: Color(value | 0xFF000000),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    color: AppColors.highContrastForeground(
                      Color(value | 0xFF000000),
                    ),
                  )
                : enabled
                ? null
                : Icon(
                    Icons.lock_outline_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }

  Future<int?> _pickCustomNotebookColor(
    BuildContext context,
    int currentValue,
  ) {
    final current = HSLColor.fromColor(Color(currentValue | 0xFF000000));
    var hue = current.hue;
    var selected = HSLColor.fromAHSL(1, hue, 0.48, 0.74).toColor();
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          selected = HSLColor.fromAHSL(1, hue, 0.48, 0.74).toColor();
          return AlertDialog(
            title: const Text('Custom notebook color'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: selected,
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.highContrastForeground(selected),
                  ),
                ),
                const SizedBox(height: 14),
                Slider(
                  min: 0,
                  max: 360,
                  divisions: 360,
                  value: hue,
                  onChanged: (value) => setDialogState(() => hue = value),
                ),
                const Text('Choose a soft hue for this notebook.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selected.toARGB32()),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteNotebook(Notebook notebook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete notebook?'),
        content: Text(
          'Delete "${notebook.name}" and its notes? This cannot be undone.',
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
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _notebooks = _notebooks.where((item) => item.id != notebook.id).toList();
      if (_selectedNotebookId == notebook.id) {
        _selectedNotebookId = null;
      }
      if (!_notebooks.any((item) => item.iconType == _selectedCategory)) {
        _selectedCategory = null;
      }
    });
    if (widget.initialNotebooks == null) {
      await _persistWorkspace();
    }
  }

  Future<void> _openRecentNote(RecentNoteView recentNote) async {
    final matchingNotebook = _notebooks.where(
      (item) => item.id == recentNote.notebookId,
    );
    if (matchingNotebook.isEmpty) {
      return;
    }
    await _openNotebook(
      matchingNotebook.first,
      initialNoteId: recentNote.note.id,
    );
  }

  Future<void> _showAllNotes() async {
    final selectedNote = await Navigator.of(context).push<RecentNoteView>(
      MaterialPageRoute<RecentNoteView>(
        builder: (_) => AllNotesScreen(
          notes: _recentNotes(),
          onTogglePinned: _togglePinnedNote,
          onColorChanged: _changeNoteColor,
          onTagColorChanged: _changeTagColor,
        ),
      ),
    );
    if (!mounted || selectedNote == null) {
      return;
    }
    await _openRecentNote(selectedNote);
  }

  Future<void> _togglePinnedNote(RecentNoteView recentNote) async {
    final notebookIndex = _notebooks.indexWhere(
      (notebook) => notebook.id == recentNote.notebookId,
    );
    if (notebookIndex == -1) {
      return;
    }
    final notebook = _notebooks[notebookIndex];
    final updated = notebook.copyWith(
      notes: notebook.notes
          .map(
            (note) => note.id == recentNote.note.id
                ? note.copyWith(isPinned: !note.isPinned)
                : note,
          )
          .toList(),
      updatedAt: DateTime.now(),
    );
    await _updateNotebook(updated);
  }

  Future<void> _changeNoteColor(
    RecentNoteView recentNote,
    NoteCardColor color,
  ) async {
    final notebookIndex = _notebooks.indexWhere(
      (notebook) => notebook.id == recentNote.notebookId,
    );
    if (notebookIndex == -1) {
      return;
    }
    final notebook = _notebooks[notebookIndex];
    final now = DateTime.now();
    final updated = notebook.copyWith(
      notes: notebook.notes
          .map(
            (note) => note.id == recentNote.note.id
                ? note.copyWith(color: color, updatedAt: now)
                : note,
          )
          .toList(),
      updatedAt: now,
    );
    await _updateNotebook(updated);
  }

  void _expandSearch() {
    setState(() => _isSearchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _isSearchExpanded = false);
  }

  Future<void> _createNote() async {
    if (_notebooks.isEmpty) {
      await _createNotebook();
      if (!mounted || _notebooks.isEmpty) {
        return;
      }
    }
    final selectedNotebook = _selectedNotebookId == null
        ? null
        : _notebooks.where((book) => book.id == _selectedNotebookId);
    if (selectedNotebook != null && selectedNotebook.isNotEmpty) {
      await _openNotebook(selectedNotebook.first, createNoteOnOpen: true);
      return;
    }
    final matching = _selectedCategory == null
        ? _notebooks
        : _notebooks.where((book) => book.iconType == _selectedCategory);
    final notebook = matching.isEmpty ? _notebooks.first : matching.first;
    await _openNotebook(notebook, createNoteOnOpen: true);
  }

  Future<String?> _showNotebookNameDialog({
    required String title,
    required String actionLabel,
    String initialValue = '',
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _NotebookTextDialog(
        title: title,
        hint: 'Notebook name',
        actionLabel: actionLabel,
        initialValue: initialValue,
      ),
    );
  }

  Future<String?> _showNotebookDescriptionDialog({
    required String initialValue,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NotebookTextDialog(
        title: 'Notebook description',
        hint: 'Add a short description',
        actionLabel: 'Save',
        initialValue: initialValue,
        allowEmpty: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 120,
      ),
    );
  }

  String _iconLabel(NotebookIcon icon) {
    final words = icon.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return words[0].toUpperCase() + words.substring(1);
  }

  String _id(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.88),
        title: Text(
          'Notes',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('notes-search-button'),
            tooltip: _isSearchExpanded ? 'Close search' : 'Search notes',
            onPressed: _isSearchExpanded ? _closeSearch : _expandSearch,
            icon: Icon(
              _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
          if (widget.appMenu != null) widget.appMenu!,
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              Color.lerp(
                theme.colorScheme.surface,
                theme.colorScheme.primaryContainer,
                theme.brightness == Brightness.light ? 0.12 : 0.08,
              )!,
            ],
          ),
        ),
        child: _isLoading
            ? _buildLoadingState(context)
            : SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_storageError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: MaterialBanner(
                                  content: Text(_storageError!),
                                  leading: const Icon(
                                    Icons.warning_amber_rounded,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: _loadWorkspace,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: _isSearchExpanded
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _buildSearchBar(context),
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),
                            _buildNotebookPanel(context),
                            const SizedBox(height: 16),
                            _buildRecentNotesSection(context, isWide: isWide),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('notes-add-note-fab'),
        tooltip: 'Create note',
        onPressed: _createNote,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('Loading notes workspace...', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildNotebookPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('notes-notebook-panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notebooks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_notebooks.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('notes-new-notebook-button'),
                tooltip: 'New notebook',
                visualDensity: VisualDensity.compact,
                onPressed: _createNotebook,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
            ],
          ),
          if (_notebooks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Create a notebook to organize your notes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 185)
                    .floor()
                    .clamp(1, 4)
                    .toInt();
                final tileWidth =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final notebook in _notebooks)
                      SizedBox(
                        width: tileWidth,
                        height: 76,
                        child: NotebookListTile(
                          key: ValueKey('notebook-card-${notebook.id}'),
                          notebook: notebook,
                          selected: _selectedNotebookId == notebook.id,
                          onOpen: () => _selectAndOpenNotebook(notebook),
                          onOptions: () => _showNotebookOptions(notebook),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 6),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 8),
          _buildCategoryStrip(context),
        ],
      ),
    );
  }

  Widget _buildCategoryStrip(BuildContext context) {
    final categories = NotebookIconType.values
        .where((type) => _notebooks.any((book) => book.iconType == type))
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCategoryTile(
            context,
            label: 'All',
            icon: Icons.folder_copy_outlined,
            noteColor: NoteCardColor.blue,
            count: _notebooks.fold<int>(
              0,
              (total, notebook) => total + notebook.noteCount,
            ),
            selected: _selectedCategory == null,
            onTap: () => setState(() {
              _selectedCategory = null;
              _selectedNotebookId = null;
            }),
          ),
          for (final type in categories)
            _buildCategoryTile(
              context,
              label: _categoryLabel(type),
              icon: _categoryIcon(type),
              noteColor: _categoryColor(type),
              count: _notebooks
                  .where((notebook) => notebook.iconType == type)
                  .fold<int>(
                    0,
                    (total, notebook) => total + notebook.noteCount,
                  ),
              selected: _selectedCategory == type,
              onTap: () => setState(() {
                _selectedCategory = type;
                _selectedNotebookId = null;
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required NoteCardColor noteColor,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = colorScheme.onSurface;
    final tileColor = Color.lerp(
      colorScheme.surface,
      noteCardSwatchColor(theme, noteColor),
      selected ? 0.26 : 0.13,
    )!;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label, $count notes',
        child: Material(
          color: tileColor,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.outlineVariant,
                ),
              ),
              child: SizedBox(
                width: 76,
                height: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: iconColor),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(NotebookIconType type) {
    return switch (type) {
      NotebookIconType.work => 'Work',
      NotebookIconType.goals => 'Goals',
      NotebookIconType.journal => 'Journal',
      NotebookIconType.health => 'Health',
      NotebookIconType.ideas => 'Ideas',
      NotebookIconType.general => 'General',
    };
  }

  IconData _categoryIcon(NotebookIconType type) {
    return switch (type) {
      NotebookIconType.work => Icons.work_outline_rounded,
      NotebookIconType.goals => Icons.flag_outlined,
      NotebookIconType.journal => Icons.auto_stories_outlined,
      NotebookIconType.health => Icons.favorite_border_rounded,
      NotebookIconType.ideas => Icons.lightbulb_outline_rounded,
      NotebookIconType.general => Icons.menu_book_outlined,
    };
  }

  NoteCardColor _categoryColor(NotebookIconType type) {
    return switch (type) {
      NotebookIconType.work => NoteCardColor.pink,
      NotebookIconType.goals => NoteCardColor.mint,
      NotebookIconType.journal => NoteCardColor.lavender,
      NotebookIconType.health => NoteCardColor.green,
      NotebookIconType.ideas => NoteCardColor.orange,
      NotebookIconType.general => NoteCardColor.cyan,
    };
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      key: const ValueKey('notes-workspace-search'),
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search notes...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
        suffixIcon: IconButton(
          tooltip: _query.isEmpty ? 'Close search' : 'Clear search',
          onPressed: _query.isEmpty
              ? _closeSearch
              : () {
                  _searchController.clear();
                  setState(() {});
                },
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildRecentNotesHeading(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Recent Notes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('notes-see-all-button'),
          onPressed: _showAllNotes,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See all',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentNotesSection(
    BuildContext context, {
    required bool isWide,
  }) {
    final notes = _filteredRecentNotes;
    final visibleNotes = notes.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRecentNotesHeading(context),
        const SizedBox(height: 8),
        if (visibleNotes.isEmpty)
          _SectionEmptyState(
            message: _query.isEmpty
                ? 'No recent notes yet. Open a notebook and start writing.'
                : 'No recent notes match your search.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleNotes.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : 2,
              mainAxisExtent: 176,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final note = visibleNotes[index];
              return Semantics(
                button: true,
                label: 'Open ${note.note.title} in ${note.notebookName}',
                child: RecentNoteCard(
                  note: note,
                  compact: true,
                  onTap: () => _openRecentNote(note),
                  onTogglePinned: () => _togglePinnedNote(note),
                  onColorChanged: (color) => _changeNoteColor(note, color),
                  onTagColorChanged: _changeTagColor,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _NotebookTextDialog extends StatefulWidget {
  const _NotebookTextDialog({
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.initialValue,
    this.allowEmpty = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
  });

  final String title;
  final String hint;
  final String actionLabel;
  final String initialValue;
  final bool allowEmpty;
  final int minLines;
  final int maxLines;
  final int? maxLength;

  @override
  State<_NotebookTextDialog> createState() => _NotebookTextDialogState();
}

class _NotebookTextDialogState extends State<_NotebookTextDialog> {
  late final TextEditingController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: _hasError ? 'A notebook name is required.' : null,
        ),
        onChanged: (value) {
          if (_hasError && value.trim().isNotEmpty) {
            setState(() => _hasError = false);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (!widget.allowEmpty && value.isEmpty) {
              setState(() => _hasError = true);
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
