import 'package:flutter/material.dart';

import '../models/note_workspace_models.dart';

class NotebookDetailResult {
  const NotebookDetailResult({this.updatedNotebook, this.isDeleted = false});

  final Notebook? updatedNotebook;
  final bool isDeleted;
}

class NotebookDetailScreen extends StatefulWidget {
  const NotebookDetailScreen({super.key, required this.notebook});

  final Notebook notebook;

  @override
  State<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<NotebookDetailScreen> {
  late Notebook _notebook;
  late String _selectedSectionId;

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
    _selectedSectionId = _notebook.sections.first.id;
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
    setState(() {
      _notebook = _notebook.copyWith(
        sections: [..._notebook.sections, section],
        updatedAt: now,
      );
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
    setState(() {
      _notebook = _notebook.copyWith(sections: updatedSections, updatedAt: now);
    });
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

    setState(() {
      _notebook = _notebook.copyWith(
        sections: remainingSections,
        notes: remainingNotes,
        updatedAt: now,
      );
      _selectedSectionId = remainingSections.first.id;
    });
  }

  Future<void> _createNote() async {
    final draft = await showDialog<_NoteDraft>(
      context: context,
      builder: (context) => const _NoteDraftDialog(),
    );
    if (draft == null || !mounted) {
      return;
    }

    final now = DateTime.now();
    final note = NoteEntry(
      id: _id('note'),
      notebookId: _notebook.id,
      sectionId: _selectedSectionId,
      title: draft.title,
      content: draft.content,
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _notebook = _notebook.copyWith(
        notes: [..._notebook.notes, note],
        updatedAt: now,
      );
    });
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
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.drive_file_rename_outline),
                  title: Text('Rename section'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete section'),
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
              child: Row(
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
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _sectionNotes.isEmpty
                  ? Center(
                      child: Text(
                        'No notes in this section yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemBuilder: (context, index) {
                        final note = _sectionNotes[index];
                        return Card(
                          child: ListTile(
                            title: Text(note.title),
                            subtitle: Text(
                              note.preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemCount: _sectionNotes.length,
                    ),
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
}

class _NoteDraft {
  const _NoteDraft({required this.title, required this.content});

  final String title;
  final String content;
}

class _NoteDraftDialog extends StatefulWidget {
  const _NoteDraftDialog();

  @override
  State<_NoteDraftDialog> createState() => _NoteDraftDialogState();
}

class _NoteDraftDialogState extends State<_NoteDraftDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('new-note-title-field'),
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Title'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('new-note-content-field'),
            controller: _contentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Note content'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _NoteDraft(title: title, content: _contentController.text.trim()),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
