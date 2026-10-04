import 'dart:async';

import 'package:flutter/material.dart';

import '../reminders/services/reminder_storage.dart';
import 'models/note_workspace_models.dart';
import 'screens/notebook_detail_screen.dart';
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
  late final NoteWorkspaceStorage _workspaceStorage;
  late List<Notebook> _notebooks;
  bool _isLoading = true;
  String? _storageError;
  NotebookIconType? _selectedCategory;
  bool _showAllPinned = false;
  bool _showAllRecent = false;
  bool _oldestFirst = false;

  static final List<Notebook> _defaultNotebooks = [
    Notebook(
      id: 'nb-plans',
      name: 'Plans & Goals',
      iconType: NotebookIconType.goals,
      sections: [
        NoteSection(
          id: 'section-plans-focus',
          name: 'Focus',
          createdAt: DateTime(2026, 9, 1, 8),
        ),
        NoteSection(
          id: 'section-plans-review',
          name: 'Review',
          createdAt: DateTime(2026, 9, 1, 8, 10),
        ),
      ],
      notes: [
        NoteEntry(
          id: 'note-weekly-review',
          notebookId: 'nb-plans',
          sectionId: 'section-plans-review',
          title: 'Weekly Review',
          content:
              'Capture wins, blockers, and next focus areas for this week.',
          createdAt: DateTime(2026, 9, 30, 9, 0),
          updatedAt: DateTime(2026, 9, 30, 9, 12),
        ),
      ],
      createdAt: DateTime(2026, 8, 1, 9),
      updatedAt: DateTime(2026, 9, 30, 9, 12),
    ),
    Notebook(
      id: 'nb-work',
      name: 'Work Notes',
      iconType: NotebookIconType.work,
      sections: [
        NoteSection(
          id: 'section-work-meetings',
          name: 'Meetings',
          createdAt: DateTime(2026, 9, 2, 10),
        ),
        NoteSection(
          id: 'section-work-action-items',
          name: 'Action Items',
          createdAt: DateTime(2026, 9, 2, 10, 5),
        ),
      ],
      notes: [
        NoteEntry(
          id: 'note-client-call-highlights',
          notebookId: 'nb-work',
          sectionId: 'section-work-meetings',
          title: 'Client Call Highlights',
          content: 'Action items, deadlines, and follow-up topics from Tuesday call.',
          createdAt: DateTime(2026, 9, 29, 18, 20),
          updatedAt: DateTime(2026, 9, 29, 18, 42),
        ),
      ],
      createdAt: DateTime(2026, 8, 1, 9),
      updatedAt: DateTime(2026, 9, 29, 18, 42),
    ),
    Notebook(
      id: 'nb-journal',
      name: 'Journal',
      iconType: NotebookIconType.journal,
      sections: [
        NoteSection(
          id: 'section-journal-daily',
          name: 'Daily',
          createdAt: DateTime(2026, 9, 1, 6),
        ),
      ],
      notes: const [],
      createdAt: DateTime(2026, 8, 1, 9),
      updatedAt: DateTime(2026, 9, 1, 6),
    ),
    Notebook(
      id: 'nb-health',
      name: 'Health & Fitness',
      iconType: NotebookIconType.health,
      sections: [
        NoteSection(
          id: 'section-health-workouts',
          name: 'Workouts',
          createdAt: DateTime(2026, 9, 4, 7),
        ),
      ],
      notes: [
        NoteEntry(
          id: 'note-workout-split',
          notebookId: 'nb-health',
          sectionId: 'section-health-workouts',
          title: 'Workout Split',
          content: 'Upper body, lower body, mobility, and recovery notes.',
          createdAt: DateTime(2026, 9, 29, 6, 30),
          updatedAt: DateTime(2026, 9, 29, 7, 5),
        ),
      ],
      createdAt: DateTime(2026, 8, 1, 9),
      updatedAt: DateTime(2026, 9, 29, 7, 5),
    ),
    Notebook(
      id: 'nb-ideas',
      name: 'Quick Ideas',
      iconType: NotebookIconType.ideas,
      sections: [
        NoteSection(
          id: 'section-ideas-campaigns',
          name: 'Campaigns',
          createdAt: DateTime(2026, 9, 5, 12),
        ),
      ],
      notes: [
        NoteEntry(
          id: 'note-festival-campaign',
          notebookId: 'nb-ideas',
          sectionId: 'section-ideas-campaigns',
          title: 'Festival Campaign Concepts',
          content: 'Headline options and social story hooks for the upcoming campaign.',
          createdAt: DateTime(2026, 9, 28, 21, 45),
          updatedAt: DateTime(2026, 9, 28, 22, 30),
        ),
      ],
      createdAt: DateTime(2026, 8, 1, 9),
      updatedAt: DateTime(2026, 9, 28, 22, 30),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _workspaceStorage = widget.workspaceStorage ?? NoteWorkspaceStorage();
    _notebooks = List<Notebook>.of(
      widget.initialNotebooks ?? _defaultNotebooks,
    );
    if (widget.initialNotebooks != null) {
      _isLoading = false;
    } else {
      unawaited(_loadWorkspace());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _query => _searchController.text.trim().toLowerCase();

  Future<void> _loadWorkspace() async {
    try {
      final saved = await _workspaceStorage.loadWorkspace();
      final notebooks = saved.isEmpty
          ? List<Notebook>.of(_defaultNotebooks)
          : saved;
      if (!mounted) {
        return;
      }
      setState(() {
        _notebooks = notebooks;
        _isLoading = false;
      });
      if (saved.isEmpty) {
        await _workspaceStorage.saveWorkspace(notebooks);
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _notebooks = List<Notebook>.of(_defaultNotebooks);
        _isLoading = false;
        _storageError = 'Notes could not be restored. Changes may not persist.';
      });
      debugPrint('Notes workspace restore failed: $error');
    }
  }

  Future<void> _persistWorkspace() async {
    try {
      await _workspaceStorage.saveWorkspace(_notebooks);
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

  List<Notebook> get _filteredNotebooks {
    final query = _query;
    return _notebooks.where((notebook) {
      if (_selectedCategory != null &&
          notebook.iconType != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      if (notebook.name.toLowerCase().contains(query)) {
        return true;
      }
      if (notebook.sections.any(
        (section) => section.name.toLowerCase().contains(query),
      )) {
        return true;
      }
      return notebook.notes.any(
        (note) =>
            note.title.toLowerCase().contains(query) ||
            note.content.toLowerCase().contains(query),
      );
    }).toList();
  }

  List<RecentNoteView> get _filteredRecentNotes {
    final notes = _recentNotes();
    final query = _query;
    return notes.where((note) {
      if (note.note.isPinned ||
          (_selectedCategory != null &&
              note.notebookIconType != _selectedCategory)) {
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

  List<RecentNoteView> get _filteredPinnedNotes {
    final query = _query;
    return _recentNotes().where((note) {
      if (!note.note.isPinned ||
          (_selectedCategory != null &&
              note.notebookIconType != _selectedCategory)) {
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
          ),
        );
      }
    }
    views.sort(
      (a, b) => _oldestFirst
          ? a.note.updatedAt.compareTo(b.note.updatedAt)
          : b.note.updatedAt.compareTo(a.note.updatedAt),
    );
    return views;
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

  Future<void> _renameNotebook(Notebook notebook) async {
    final name = await _showNotebookNameDialog(
      title: 'Rename notebook',
      actionLabel: 'Save',
      initialValue: notebook.name,
    );
    if (name == null || !mounted) {
      return;
    }
    final now = DateTime.now();
    setState(() {
      _notebooks = _notebooks.map((item) {
        if (item.id != notebook.id) {
          return item;
        }
        return item.copyWith(name: name, updatedAt: now);
      }).toList();
    });
    await _persistWorkspace();
  }

  Future<void> _deleteNotebook(Notebook notebook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete notebook?'),
        content: Text(
          'Delete "${notebook.name}" with its sections and notes? This cannot be undone.',
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
    final reminderStorage = ReminderStorage();
    for (final note in notebook.notes) {
      final reminderId = note.reminderId;
      if (reminderId != null) {
        await reminderStorage.deleteReminder(reminderId);
      }
    }
    setState(() {
      _notebooks = _notebooks.where((item) => item.id != notebook.id).toList();
      if (_selectedCategory != null &&
          !_notebooks.any((item) => item.iconType == _selectedCategory)) {
        _selectedCategory = null;
      }
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
        _selectedCategory = _notebooks.any(
          (item) => item.iconType == _selectedCategory,
        )
            ? _selectedCategory
            : null;
        _selectedCategory = _notebooks.any(
          (item) => item.iconType == _selectedCategory,
        )
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
        title: Text(
          'Notes',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('notes-new-notebook-button'),
            tooltip: 'New notebook',
            onPressed: _createNotebook,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          if (widget.appMenu != null) widget.appMenu!,
        ],
      ),
      body: _isLoading
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
                          _buildCategoryStrip(context),
                          const SizedBox(height: 14),
                          _buildSearchBar(context),
                          const SizedBox(height: 22),
                          _buildPinnedSection(context),
                          const SizedBox(height: 20),
                          _buildRecentNotesSection(context, isWide: isWide),
                          const SizedBox(height: 24),
                          _buildNotebookSection(context),
                        ],
                      ),
                    );
                  },
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
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label, $count notes',
        child: Material(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: 82,
              height: 78,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.primary,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      key: const ValueKey('notes-workspace-search'),
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search notes...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
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
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              )
            : PopupMenuButton<bool>(
                tooltip: 'Sort notes',
                initialValue: _oldestFirst,
                onSelected: (oldestFirst) {
                  setState(() => _oldestFirst = oldestFirst);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<bool>(
                    value: false,
                    child: Text('Newest first'),
                  ),
                  PopupMenuItem<bool>(
                    value: true,
                    child: Text('Oldest first'),
                  ),
                ],
                icon: const Icon(Icons.tune_rounded),
              ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPinnedSection(BuildContext context) {
    final notes = _filteredPinnedNotes;
    final visibleNotes = _showAllPinned ? notes : notes.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeading(
          context,
          title: 'Pinned',
          icon: Icons.push_pin_rounded,
          totalCount: notes.length,
          visibleCount: 2,
          showAll: _showAllPinned,
          onShowAll: () => setState(() => _showAllPinned = !_showAllPinned),
        ),
        if (visibleNotes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pin notes to keep them close at hand.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...visibleNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                button: true,
                label: 'Open ${note.note.title} in ${note.notebookName}',
                child: SizedBox(
                  height: 132,
                  child: RecentNoteCard(
                    note: note,
                    onTap: () => _openRecentNote(note),
                    onTogglePinned: () => _togglePinnedNote(note),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeading(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int totalCount,
    required int visibleCount,
    required bool showAll,
    required VoidCallback onShowAll,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (totalCount > visibleCount)
          TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(showAll ? 'Show less' : 'See all'),
          ),
      ],
    );
  }

  Widget _buildNotebookSection(BuildContext context) {
    final notebooks = _filteredNotebooks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Notebooks',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (notebooks.isEmpty)
          _SectionEmptyState(
            message: _query.isEmpty
                ? 'No notebooks yet. Create your first notebook.'
                : 'No notebooks match your search.',
          )
        else
          ...notebooks.map(
            (notebook) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NotebookListTile(
                notebook: notebook,
                onOpen: () => _openNotebook(notebook),
                onRename: () => _renameNotebook(notebook),
                onDelete: () => _deleteNotebook(notebook),
              ),
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
    final visibleNotes = _showAllRecent ? notes : notes.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeading(
          context,
          title: 'Recent Notes',
          icon: Icons.notes_rounded,
          totalCount: notes.length,
          visibleCount: 8,
          showAll: _showAllRecent,
          onShowAll: () => setState(() => _showAllRecent = !_showAllRecent),
        ),
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
              mainAxisExtent: 152,
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
