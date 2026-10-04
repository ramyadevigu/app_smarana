import 'dart:async';

import 'package:flutter/material.dart';

import '../../reminders/services/reminder_storage.dart';
import '../models/note_workspace_models.dart';
import '../models/rich_note_draft.dart';
import '../services/note_attachment_storage.dart';
import 'rich_note_editor_screen.dart';

enum NotebookViewMode { notes, list, kanban }

class NotebookDetailResult {
  const NotebookDetailResult({this.updatedNotebook, this.isDeleted = false});

  final Notebook? updatedNotebook;
  final bool isDeleted;
}

class NotebookDetailScreen extends StatefulWidget {
  const NotebookDetailScreen({
    super.key,
    required this.notebook,
    this.onNotebookChanged,
    this.reminderStorage,
    this.createNoteOnOpen = false,
    this.initialNoteId,
  });

  final Notebook notebook;
  final Future<void> Function(Notebook notebook)? onNotebookChanged;
  final ReminderStorage? reminderStorage;
  final bool createNoteOnOpen;
  final String? initialNoteId;

  @override
  State<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<NotebookDetailScreen> {
  late Notebook _notebook;
  late String _selectedSectionId;
  late final ReminderStorage _reminderStorage;
  late final NoteAttachmentStorage _attachmentStorage;
  NotebookViewMode _viewMode = NotebookViewMode.notes;

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
    _selectedSectionId = _notebook.sections.first.id;
    _reminderStorage = widget.reminderStorage ?? ReminderStorage();
    _attachmentStorage = NoteAttachmentStorage();
    if (widget.createNoteOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_createNote());
        }
      });
    } else if (widget.initialNoteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final matches = _notebook.notes.where(
          (note) => note.id == widget.initialNoteId,
        );
        if (matches.isNotEmpty) {
          unawaited(_editNote(matches.first));
        }
      });
    }
  }

  List<NoteEntry> get _sectionNotes {
    final notes = _notebook.notes
        .where((note) => note.sectionId == _selectedSectionId)
        .toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  NoteSection get _selectedSection {
    return _notebook.sections.firstWhere(
      (section) => section.id == _selectedSectionId,
    );
  }

  Future<void> _createSection() async {
    final name = await _showNameDialog(
      title: 'New section',
      hint: 'Section name',
      actionLabel: 'Create',
    );
    if (name == null || !mounted) {
      return;
    }
    final now = DateTime.now();
    final section = NoteSection(id: _id('section'), name: name, createdAt: now);
    await _publishNotebook(
      _notebook.copyWith(
        sections: [..._notebook.sections, section],
        updatedAt: now,
      ),
    );
    setState(() {
      _selectedSectionId = section.id;
    });
  }

  Future<void> _renameSection() async {
    final current = _selectedSection;
    final name = await _showNameDialog(
      title: 'Rename section',
      hint: 'Section name',
      actionLabel: 'Save',
      initialValue: current.name,
    );
    if (name == null || !mounted) {
      return;
    }
    final now = DateTime.now();
    final updatedSections = _notebook.sections
        .map(
          (section) =>
              section.id == current.id ? section.copyWith(name: name) : section,
        )
        .toList();
    await _publishNotebook(
      _notebook.copyWith(sections: updatedSections, updatedAt: now),
    );
  }

  Future<void> _deleteSection() async {
    if (_notebook.sections.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one section is required.')),
      );
      return;
    }

    final section = _selectedSection;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete section?'),
        content: Text(
          'Delete "${section.name}" and its notes in this notebook?',
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

    final now = DateTime.now();
    final remainingSections = _notebook.sections
        .where((item) => item.id != section.id)
        .toList();
    final remainingNotes = _notebook.notes
        .where((note) => note.sectionId != section.id)
        .toList();

    await _publishNotebook(
      _notebook.copyWith(
        sections: remainingSections,
        notes: remainingNotes,
        updatedAt: now,
      ),
    );
    setState(() {
      _selectedSectionId = remainingSections.first.id;
    });
  }

  Future<void> _createNote() async {
    final now = DateTime.now();
    final note = NoteEntry(
      id: _id('note'),
      notebookId: _notebook.id,
      sectionId: _selectedSectionId,
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
    );

    var wasInserted = false;
    final draft = await Navigator.of(context).push<RichNoteDraft>(
      MaterialPageRoute<RichNoteDraft>(
        builder: (_) => RichNoteEditorScreen(
          note: note,
          notebookName: _notebook.name,
          sections: _notebook.sections,
          initialSectionId: _selectedSectionId,
          reminderStorage: _reminderStorage,
          onDuplicate: _duplicateDraft,
          onDelete: (draft) async {
            if (draft.reminderId != null) {
              await _reminderStorage.deleteReminder(draft.reminderId!);
            }
            if (wasInserted) {
              await _publishNotebook(
                _notebook.copyWith(
                  notes: _notebook.notes
                      .where((existing) => existing.id != note.id)
                      .toList(),
                  updatedAt: DateTime.now(),
                ),
              );
            }
          },
          onAutosave: (snapshot) async {
            if (!_hasMeaningfulContent(snapshot) || !mounted) {
              return;
            }
            await _publishNotebook(
              _notebook.copyWith(
                notes: _upsertNote(
                  _notebook.notes,
                  _noteFromDraft(base: note, draft: snapshot),
                ),
                updatedAt: snapshot.updatedAt,
              ),
            );
            wasInserted = true;
          },
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (draft == null || !_hasMeaningfulContent(draft)) {
      if (wasInserted) {
        await _publishNotebook(
          _notebook.copyWith(
            notes: _notebook.notes
                .where((existing) => existing.id != note.id)
                .toList(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      final orphanedReminderId = draft?.reminderId;
      if (orphanedReminderId != null) {
        await _reminderStorage.deleteReminder(orphanedReminderId);
      }
      return;
    }

    final updated = _noteFromDraft(base: note, draft: draft);
    await _publishNotebook(
      _notebook.copyWith(
        notes: _upsertNote(_notebook.notes, updated),
        updatedAt: draft.updatedAt,
      ),
    );
  }

  Future<void> _editNote(NoteEntry note) async {
    final draft = await Navigator.of(context).push<RichNoteDraft>(
      MaterialPageRoute<RichNoteDraft>(
        builder: (_) => RichNoteEditorScreen(
          note: note,
          notebookName: _notebook.name,
          sections: _notebook.sections,
          initialSectionId: note.sectionId,
          reminderStorage: _reminderStorage,
          onDuplicate: _duplicateDraft,
          onDelete: (draft) async {
            if (draft.reminderId != null) {
              await _reminderStorage.deleteReminder(draft.reminderId!);
            }
            await _publishNotebook(
              _notebook.copyWith(
                notes: _notebook.notes
                    .where((existing) => existing.id != note.id)
                    .toList(),
                updatedAt: DateTime.now(),
              ),
            );
          },
          onAutosave: (snapshot) async {
            if (!mounted) {
              return;
            }
            final updated = _noteFromDraft(base: note, draft: snapshot);
            await _publishNotebook(
              _notebook.copyWith(
                notes: _upsertNote(_notebook.notes, updated),
                updatedAt: snapshot.updatedAt,
              ),
            );
          },
        ),
      ),
    );

    if (!mounted || draft == null) {
      return;
    }

    final updated = _noteFromDraft(base: note, draft: draft);
    await _publishNotebook(
      _notebook.copyWith(
        notes: _upsertNote(_notebook.notes, updated),
        updatedAt: draft.updatedAt,
      ),
    );
  }

  Future<void> _duplicateDraft(RichNoteDraft draft) async {
    final id = _id('note');
    final attachments = await _attachmentStorage.duplicateAttachments(
      attachments: draft.attachments,
      noteId: id,
    );
    final now = DateTime.now();
    final title = draft.title.trim().isEmpty ? 'Untitled' : draft.title.trim();
    final duplicate = NoteEntry(
      id: id,
      notebookId: _notebook.id,
      sectionId: draft.sectionId,
      title: '$title copy',
      content: draft.plainContent,
      richContentDelta: draft.richContentDelta,
      attachments: attachments,
      projectMetadata: draft.projectMetadata,
      createdAt: now,
      updatedAt: now,
      color: draft.color,
    );
    await _publishNotebook(
      _notebook.copyWith(
        notes: _upsertNote(_notebook.notes, duplicate),
        updatedAt: now,
      ),
    );
  }

  Future<void> _publishNotebook(Notebook updated) async {
    setState(() {
      _notebook = updated;
    });
    await widget.onNotebookChanged?.call(updated);
  }

  NoteEntry _noteFromDraft({
    required NoteEntry base,
    required RichNoteDraft draft,
  }) {
    return base.copyWith(
      sectionId: draft.sectionId,
      title: draft.title,
      content: draft.plainContent,
      richContentDelta: draft.richContentDelta,
      attachments: draft.attachments,
      projectMetadata: draft.projectMetadata,
      clearProjectMetadata: draft.projectMetadata == null,
      updatedAt: draft.updatedAt,
      reminderId: draft.reminderId,
      clearReminderId: draft.reminderId == null,
      color: draft.color,
    );
  }

  Future<void> _moveNoteToStatus(
    NoteEntry note,
    NoteProjectStatus status,
  ) async {
    final now = DateTime.now();
    final currentMetadata = note.projectMetadata;
    final updatedMetadata = (currentMetadata ?? const NoteProjectMetadata())
        .copyWith(status: status);
    final updatedNote = note.copyWith(
      projectMetadata: updatedMetadata,
      updatedAt: now,
    );
    await _publishNotebook(
      _notebook.copyWith(
        notes: _upsertNote(_notebook.notes, updatedNote),
        updatedAt: now,
      ),
    );
  }

  List<NoteEntry> _upsertNote(List<NoteEntry> notes, NoteEntry note) {
    final next = List<NoteEntry>.of(notes);
    final index = next.indexWhere((entry) => entry.id == note.id);
    if (index == -1) {
      next.add(note);
    } else {
      next[index] = note;
    }
    return next;
  }

  bool _hasMeaningfulContent(RichNoteDraft draft) {
    return draft.title.trim().isNotEmpty ||
        draft.plainContent.trim().isNotEmpty;
  }

  Future<void> _deleteNote(NoteEntry note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete note?'),
        content: Text(
          'Delete "${note.title.isEmpty ? 'Untitled note' : note.title}"? '
          'This cannot be undone.',
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

    final reminderId = note.reminderId;
    if (reminderId != null) {
      await _reminderStorage.deleteReminder(reminderId);
    }

    await _publishNotebook(
      _notebook.copyWith(
        notes: _notebook.notes.where((item) => item.id != note.id).toList(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<String?> _showNameDialog({
    required String title,
    required String hint,
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
          decoration: InputDecoration(hintText: hint),
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
        title: Text(_notebook.name),
        actions: [
          IconButton(
            key: const ValueKey('notebook-add-section'),
            tooltip: 'Add section',
            onPressed: _createSection,
            icon: const Icon(Icons.add_circle_outline),
          ),
          PopupMenuButton<String>(
            key: const ValueKey('section-actions-menu'),
            tooltip: 'Section actions',
            onSelected: (value) {
              if (value == 'rename') {
                _renameSection();
              }
              if (value == 'delete') {
                _deleteSection();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_rename_outline),
                    SizedBox(width: 12),
                    Text('Rename section'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 12),
                    Text('Delete section'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surfaceContainerLowest, colorScheme.surface],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _notebook.sections.map((section) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('section-tab-${section.id}'),
                      label: Text(section.name),
                      selected: _selectedSectionId == section.id,
                      onSelected: (_) {
                        setState(() {
                          _selectedSectionId = section.id;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedSection.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('section-new-note-button'),
                        onPressed: _createNote,
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('New Note'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<NotebookViewMode>(
                      key: const ValueKey('notebook-view-segmented-button'),
                      segments: const [
                        ButtonSegment<NotebookViewMode>(
                          value: NotebookViewMode.notes,
                          icon: Icon(Icons.notes_outlined),
                          label: Text('Document'),
                        ),
                        ButtonSegment<NotebookViewMode>(
                          value: NotebookViewMode.list,
                          icon: Icon(Icons.view_list_outlined),
                          label: Text('List'),
                        ),
                        ButtonSegment<NotebookViewMode>(
                          value: NotebookViewMode.kanban,
                          icon: Icon(Icons.view_kanban_outlined),
                          label: Text('Kanban'),
                        ),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) {
                          return;
                        }
                        setState(() {
                          _viewMode = selection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: switch (_viewMode) {
                NotebookViewMode.notes => _buildDocumentView(
                  theme,
                  colorScheme,
                ),
                NotebookViewMode.list => _buildListView(theme, colorScheme),
                NotebookViewMode.kanban => _buildKanbanView(theme, colorScheme),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('notebook-save-and-close'),
        onPressed: () {
          Navigator.of(context)
              .pop(NotebookDetailResult(updatedNotebook: _notebook));
        },
        icon: const Icon(Icons.check),
        label: const Text('Done'),
      ),
    );
  }

  Widget _buildDocumentView(ThemeData theme, ColorScheme colorScheme) {
    final notes = _sectionNotes;
    if (notes.isEmpty) {
      return Center(
        child: Text(
          'No notes in this section yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemBuilder: (context, index) {
        final note = notes[index];
        final metadata = note.projectMetadata;
        return Card(
          child: ListTile(
            onTap: () => _editNote(note),
            leading: note.reminderId != null
                ? Icon(
                    Icons.notifications_active_outlined,
                    color: colorScheme.primary,
                  )
                : null,
            title: Text(note.title.isEmpty ? 'Untitled note' : note.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metadata != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _statusChip(metadata.status),
                      if (metadata.priority != null)
                        Chip(
                          label: Text(_priorityLabel(metadata.priority!)),
                          visualDensity: VisualDensity.compact,
                        ),
                      if ((metadata.owner ?? '').trim().isNotEmpty)
                        Chip(
                          label: Text('Owner: ${metadata.owner!.trim()}'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              key: ValueKey('delete-note-${note.id}'),
              tooltip: 'Delete note',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteNote(note),
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemCount: notes.length,
    );
  }

  Widget _buildListView(ThemeData theme, ColorScheme colorScheme) {
    final notes = _sectionNotes;
    if (notes.isEmpty) {
      return Center(
        child: Text(
          'No notes in this section yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemBuilder: (context, index) {
        final note = notes[index];
        final metadata = note.projectMetadata;
        final status = metadata?.status ?? NoteProjectStatus.toDo;
        return Card(
          child: ListTile(
            key: ValueKey('list-note-${note.id}'),
            onTap: () => _editNote(note),
            title: Text(note.title.isEmpty ? 'Untitled note' : note.title),
            subtitle: Text(
              metadata?.owner == null
                  ? _statusLabel(status)
                  : 'Owner: ${metadata!.owner} · ${_statusLabel(status)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: _statusChip(status),
            trailing: PopupMenuButton<NoteProjectStatus>(
              tooltip: 'Move status',
              onSelected: (value) {
                _moveNoteToStatus(note, value);
              },
              itemBuilder: (context) => const [
                PopupMenuItem<NoteProjectStatus>(
                  value: NoteProjectStatus.toDo,
                  child: Text('Move to To Do'),
                ),
                PopupMenuItem<NoteProjectStatus>(
                  value: NoteProjectStatus.inProgress,
                  child: Text('Move to In Progress'),
                ),
                PopupMenuItem<NoteProjectStatus>(
                  value: NoteProjectStatus.done,
                  child: Text('Move to Done'),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemCount: notes.length,
    );
  }

  Widget _buildKanbanView(ThemeData theme, ColorScheme colorScheme) {
    final notes = _sectionNotes;
    if (notes.isEmpty) {
      return Center(
        child: Text(
          'No notes in this section yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final grouped = <NoteProjectStatus, List<NoteEntry>>{
      NoteProjectStatus.toDo: [],
      NoteProjectStatus.inProgress: [],
      NoteProjectStatus.done: [],
    };

    for (final note in notes) {
      final status = note.projectMetadata?.status ?? NoteProjectStatus.toDo;
      grouped[status]!.add(note);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final columns = NoteProjectStatus.values
            .map(
              (status) => _buildKanbanColumn(
                status: status,
                notes: grouped[status]!,
                theme: theme,
                colorScheme: colorScheme,
              ),
            )
            .toList();

        if (compact) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemBuilder: (context, index) => columns[index],
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: columns.length,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              Expanded(child: columns[i]),
              if (i != columns.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKanbanColumn({
    required NoteProjectStatus status,
    required List<NoteEntry> notes,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return DragTarget<NoteEntry>(
      onWillAcceptWithDetails: (details) {
        return details.data.projectMetadata?.status != status;
      },
      onAcceptWithDetails: (details) {
        _moveNoteToStatus(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final hasCandidate = candidateData.isNotEmpty;
        return Container(
          key: ValueKey('kanban-column-${status.name}'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hasCandidate
                ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_statusLabel(status)} (${notes.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (notes.isEmpty)
                Text(
                  'Drop notes here',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...notes.map((note) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LongPressDraggable<NoteEntry>(
                      data: note,
                      feedback: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: _kanbanCard(
                            note: note,
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _kanbanCard(
                          note: note,
                          theme: theme,
                          colorScheme: colorScheme,
                        ),
                      ),
                      child: _kanbanCard(
                        note: note,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _kanbanCard({
    required NoteEntry note,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final metadata = note.projectMetadata;
    return Card(
      child: ListTile(
        dense: true,
        onTap: () => _editNote(note),
        title: Text(
          note.title.isEmpty ? 'Untitled note' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          metadata?.owner == null ? note.preview : 'Owner: ${metadata!.owner}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(NoteProjectStatus status) {
    return Chip(
      label: Text(_statusLabel(status)),
      visualDensity: VisualDensity.compact,
    );
  }

  String _statusLabel(NoteProjectStatus status) {
    return switch (status) {
      NoteProjectStatus.toDo => 'To Do',
      NoteProjectStatus.inProgress => 'In Progress',
      NoteProjectStatus.done => 'Done',
    };
  }

  String _priorityLabel(NoteProjectPriority priority) {
    return switch (priority) {
      NoteProjectPriority.low => 'Low',
      NoteProjectPriority.medium => 'Medium',
      NoteProjectPriority.high => 'High',
    };
  }
}
