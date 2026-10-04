import 'dart:async';

import 'package:flutter/material.dart';

import '../reminders/models/reminder.dart';
import '../reminders/services/reminder_storage.dart';
import 'models/note_workspace_models.dart';
import 'screens/all_notes_screen.dart';
import 'screens/notebook_detail_screen.dart';
import 'theme/note_card_colors.dart';
import 'services/note_workspace_storage.dart';
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
  bool _isSearchExpanded = false;

  static const Duration _recentUpdateWindow = Duration(days: 7);

  static const List<Notebook> _emptyNotebookList = [];

  @override
  void initState() {
    super.initState();
    _workspaceStorage = widget.workspaceStorage ?? NoteWorkspaceStorage();
    _reminderStorage = ReminderStorage();
    _notebooks = List<Notebook>.of(
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
    final notebook = Notebook(
      id: _id('notebook'),
      name: name,
      iconType: NotebookIconType.general,
      sections: [defaultSection],
      notes: const [],
      createdAt: now,
      updatedAt: now,
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
        _selectedCategory =
            _notebooks.any((item) => item.iconType == _selectedCategory)
            ? _selectedCategory
            : null;
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
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Notebook name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
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
          IconButton(
            key: const ValueKey('notes-new-notebook-button'),
            tooltip: 'New notebook',
            onPressed: _createNotebook,
            icon: const Icon(Icons.create_new_folder_outlined),
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
    final colorScheme = Theme.of(context).colorScheme;

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
        children: [_buildCategoryStrip(context)],
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
            onTap: () => setState(() => _selectedCategory = null),
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
              onTap: () => setState(() => _selectedCategory = type),
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
