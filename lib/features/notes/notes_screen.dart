import 'dart:async';

import 'package:flutter/material.dart';

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
    if (query.isEmpty) {
      return _notebooks;
    }
    return _notebooks.where((notebook) {
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
    if (query.isEmpty) {
      return notes;
    }
    return notes.where((note) {
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
            notebookName: notebook.name,
            sectionName: sectionName,
          ),
        );
      }
    }
    views.sort((a, b) => b.note.updatedAt.compareTo(a.note.updatedAt));
    return views.take(8).toList();
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
    setState(() {
      _notebooks = _notebooks.where((item) => item.id != notebook.id).toList();
    });
    await _persistWorkspace();
  }

  Future<void> _openNotebook(Notebook notebook) async {
    final result = await Navigator.of(context).push<NotebookDetailResult>(
      MaterialPageRoute<NotebookDetailResult>(
        builder: (_) => NotebookDetailScreen(
          notebook: notebook,
          onNotebookChanged: _updateNotebook,
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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('notes-back-to-smarana'),
          tooltip: 'Back to Smarana',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed:
              widget.onBackToSmarana ??
              () {
                Navigator.of(context).maybePop();
              },
        ),
        title: const Text('Notes'),
        actions: [if (widget.appMenu != null) widget.appMenu!],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surfaceContainerLowest,
                    colorScheme.surface,
                  ],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 920;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_storageError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: MaterialBanner(
                              content: Text(_storageError!),
                              leading: const Icon(Icons.warning_amber_rounded),
                              actions: [
                                TextButton(
                                  onPressed: _loadWorkspace,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        _buildSearchAndCreate(context),
                        const SizedBox(height: 16),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildNotebookSection(context)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildRecentNotesSection(context),
                              ),
                            ],
                          )
                        else ...[
                          _buildNotebookSection(context),
                          const SizedBox(height: 16),
                          _buildRecentNotesSection(context),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSearchAndCreate(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your Workspace',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search notebooks or notes, then continue where you left off.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('notes-workspace-search'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notebooks and notes',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('notes-new-notebook-button'),
                onPressed: _createNotebook,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('New Notebook'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotebookSection(BuildContext context) {
    final notebooks = _filteredNotebooks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Notebooks',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (notebooks.isEmpty)
              _SectionEmptyState(message: 'No notebooks match your search.')
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
        ),
      ),
    );
  }

  Widget _buildRecentNotesSection(BuildContext context) {
    final notes = _filteredRecentNotes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent Notes',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (notes.isEmpty)
              _SectionEmptyState(message: 'No recent notes match your search.')
            else
              ...notes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RecentNoteCard(note: note),
                ),
              ),
          ],
        ),
      ),
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
