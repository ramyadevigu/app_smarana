import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';

import '../models/note_workspace_models.dart';
import '../models/rich_note_draft.dart';
import '../services/note_attachment_storage.dart';
import '../services/note_editor_autosave_service.dart';

class RichNoteEditorScreen extends StatefulWidget {
  const RichNoteEditorScreen({
    super.key,
    this.note,
    required this.sections,
    required this.initialSectionId,
    this.onAutosave,
  });

  final NoteEntry? note;
  final List<NoteSection> sections;
  final String initialSectionId;
  final Future<void> Function(RichNoteDraft draft)? onAutosave;

  @override
  State<RichNoteEditorScreen> createState() => _RichNoteEditorScreenState();
}

class _RichNoteEditorScreenState extends State<RichNoteEditorScreen> {
  final _titleController = TextEditingController();
  final _autosaveService = NoteEditorAutosaveService();
  final _attachmentStorage = NoteAttachmentStorage();
  final _uuid = const Uuid();
  final _lastUpdated = ValueNotifier<DateTime?>(null);
  final _autosaveMessage = ValueNotifier<String>('');

  late final quill.QuillController _quillController;
  late String _selectedSectionId;
  late List<NoteAttachment> _attachments;
  bool _toolbarExpanded = true;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController.text = note?.title ?? '';
    _selectedSectionId = note?.sectionId ?? widget.initialSectionId;
    _attachments = List<NoteAttachment>.of(note?.attachments ?? const []);

    _quillController = quill.QuillController(
      document: _buildDocument(note),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: false,
    );

    _lastUpdated.value = note?.updatedAt;

    _titleController.addListener(_queueAutosave);
    _quillController.addListener(_queueAutosave);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_queueAutosave)
      ..dispose();
    _quillController
      ..removeListener(_queueAutosave)
      ..dispose();
    _autosaveService.dispose();
    _lastUpdated.dispose();
    _autosaveMessage.dispose();
    super.dispose();
  }

  quill.Document _buildDocument(NoteEntry? note) {
    final rawDelta = note?.richContentDelta;
    if (rawDelta != null && rawDelta.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDelta);
        if (decoded is List) {
          return quill.Document.fromJson(decoded.cast<Map<String, dynamic>>());
        }
      } on FormatException {
        // Fall back to plain text below.
      }
    }

    final doc = quill.Document();
    final content = note?.content.trim() ?? '';
    if (content.isNotEmpty) {
      doc.insert(0, '$content\n');
    }
    return doc;
  }

  RichNoteDraft _buildDraft() {
    final now = DateTime.now();
    return RichNoteDraft(
      title: _titleController.text.trim(),
      richContentDelta: jsonEncode(
        _quillController.document.toDelta().toJson(),
      ),
      plainContent: _quillController.document.toPlainText().trim(),
      sectionId: _selectedSectionId,
      attachments: List<NoteAttachment>.unmodifiable(_attachments),
      updatedAt: now,
    );
  }

  void _queueAutosave() {
    _autosaveMessage.value = 'Autosaving...';
    _autosaveService.queue(() async {
      await _performAutosave();
    });
  }

  Future<void> _performAutosave() async {
    final onAutosave = widget.onAutosave;
    final draft = _buildDraft();
    if (onAutosave != null) {
      await onAutosave(draft);
    }
    if (!mounted) {
      return;
    }
    _lastUpdated.value = draft.updatedAt;
    _autosaveMessage.value = 'Saved';
  }

  Future<void> _flushAutosave() async {
    await _autosaveService.flush(_performAutosave);
  }

  Future<void> _exitEditor() async {
    if (_isExiting) {
      return;
    }
    _isExiting = true;
    await _flushAutosave();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(_buildDraft());
  }

  Future<void> _addImages() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (picked == null || !mounted) {
      return;
    }

    final next = List<NoteAttachment>.of(_attachments);
    try {
      for (final file in picked.files) {
        final attachment = await _attachmentStorage.importFile(
          file: file,
          noteId: widget.note?.id ?? _uuid.v4(),
          type: NoteAttachmentType.image,
        );
        next.add(attachment);
      }
    } on Exception catch (error) {
      _showAttachmentError('Could not add image: $error');
    }

    setState(() {
      _attachments = next;
    });
    _queueAutosave();
  }

  Future<void> _addFiles() async {
    final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (picked == null || !mounted) {
      return;
    }

    final next = List<NoteAttachment>.of(_attachments);
    try {
      for (final file in picked.files) {
        final attachment = await _attachmentStorage.importFile(
          file: file,
          noteId: widget.note?.id ?? _uuid.v4(),
          type: NoteAttachmentType.file,
        );
        next.add(attachment);
      }
    } on Exception catch (error) {
      _showAttachmentError('Could not add file: $error');
    }

    setState(() {
      _attachments = next;
    });
    _queueAutosave();
  }

  Future<void> _insertHyperlink() async {
    final textController = TextEditingController();
    final urlController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Insert hyperlink'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(labelText: 'Text'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) {
      return;
    }

    final text = textController.text.trim();
    final url = urlController.text.trim();
    if (text.isEmpty || url.isEmpty) {
      return;
    }

    final index = _quillController.selection.baseOffset.clamp(
      0,
      _quillController.document.length - 1,
    );
    _quillController.document.insert(index, '[$text]($url) ');
    _queueAutosave();
  }

  void _insertTableTemplate() {
    const tableTemplate =
        '\n| Column 1 | Column 2 |\n| --- | --- |\n| Value | Value |\n';
    final index = _quillController.selection.baseOffset.clamp(
      0,
      _quillController.document.length - 1,
    );
    _quillController.document.insert(index, tableTemplate);
    _queueAutosave();
  }

  Future<void> _openAttachment(NoteAttachment attachment) async {
    try {
      final opened = await _attachmentStorage.open(attachment);
      if (!opened && mounted) {
        _showAttachmentError('This attachment is missing from device storage.');
      }
    } on Exception catch (error) {
      _showAttachmentError('Could not open attachment: $error');
    }
  }

  Future<void> _removeAttachment(NoteAttachment attachment) async {
    try {
      await _attachmentStorage.remove(attachment);
      if (!mounted) {
        return;
      }
      setState(() {
        _attachments = _attachments
            .where((item) => item.id != attachment.id)
            .toList();
      });
      _queueAutosave();
    } on Exception catch (error) {
      _showAttachmentError('Could not remove attachment: $error');
    }
  }

  void _showAttachmentError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleInlineAttribute(quill.Attribute attribute) {
    _quillController.formatSelection(attribute);
    _queueAutosave();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _exitEditor();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey('note-editor-back'),
            tooltip: 'Close editor',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _exitEditor,
          ),
          title: Text(widget.note == null ? 'New note' : 'Edit note'),
          actions: [
            IconButton(
              key: const ValueKey('note-editor-toggle-toolbar'),
              tooltip: _toolbarExpanded
                  ? 'Collapse formatting toolbar'
                  : 'Expand formatting toolbar',
              icon: Icon(
                _toolbarExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed: () {
                setState(() {
                  _toolbarExpanded = !_toolbarExpanded;
                });
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  key: const ValueKey('rich-note-title-field'),
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Note title',
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Text('Section'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey('rich-note-section-dropdown'),
                        initialValue: _selectedSectionId,
                        items: widget.sections
                            .map(
                              (section) => DropdownMenuItem<String>(
                                value: section.id,
                                child: Text(section.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedSectionId = value;
                          });
                          _queueAutosave();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_toolbarExpanded) _buildToolbar(context),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  ),
                  child: quill.QuillEditor.basic(
                    key: const ValueKey('rich-note-content-editor'),
                    controller: _quillController,
                    config: const quill.QuillEditorConfig(
                      autoFocus: true,
                      padding: EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),
              _buildAttachmentSection(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: _lastUpdated,
                      builder: (context, dateTime, _) {
                        if (dateTime == null) {
                          return const Text('Last updated: --');
                        }
                        final time = TimeOfDay.fromDateTime(dateTime);
                        return Text(
                          'Last updated ${localizations.formatShortDate(dateTime)} ${localizations.formatTimeOfDay(time)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    ),
                    const Spacer(),
                    ValueListenableBuilder<String>(
                      valueListenable: _autosaveMessage,
                      builder: (context, value, _) {
                        if (value.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value,
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('rich-note-formatting-toolbar'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Heading',
              onPressed: () => _toggleInlineAttribute(quill.Attribute.h1),
              icon: const Icon(Icons.title),
            ),
            IconButton(
              tooltip: 'Bold',
              onPressed: () => _toggleInlineAttribute(quill.Attribute.bold),
              icon: const Icon(Icons.format_bold),
            ),
            IconButton(
              tooltip: 'Italic',
              onPressed: () => _toggleInlineAttribute(quill.Attribute.italic),
              icon: const Icon(Icons.format_italic),
            ),
            IconButton(
              tooltip: 'Underline',
              onPressed: () =>
                  _toggleInlineAttribute(quill.Attribute.underline),
              icon: const Icon(Icons.format_underline),
            ),
            IconButton(
              tooltip: 'Bullet list',
              onPressed: () => _toggleInlineAttribute(quill.Attribute.ul),
              icon: const Icon(Icons.format_list_bulleted),
            ),
            IconButton(
              tooltip: 'Numbered list',
              onPressed: () => _toggleInlineAttribute(quill.Attribute.ol),
              icon: const Icon(Icons.format_list_numbered),
            ),
            IconButton(
              tooltip: 'Checklist',
              onPressed: () =>
                  _toggleInlineAttribute(quill.Attribute.unchecked),
              icon: const Icon(Icons.checklist),
            ),
            IconButton(
              tooltip: 'Insert table',
              onPressed: _insertTableTemplate,
              icon: const Icon(Icons.table_chart_outlined),
            ),
            IconButton(
              tooltip: 'Insert hyperlink',
              onPressed: _insertHyperlink,
              icon: const Icon(Icons.link_outlined),
            ),
            IconButton(
              tooltip: 'Insert image',
              onPressed: _addImages,
              icon: const Icon(Icons.image_outlined),
            ),
            IconButton(
              tooltip: 'Attach file',
              onPressed: _addFiles,
              icon: const Icon(Icons.attach_file),
            ),
            IconButton(
              tooltip: 'Undo',
              onPressed: () {
                _quillController.undo();
                _queueAutosave();
              },
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: () {
                _quillController.redo();
                _queueAutosave();
              },
              icon: const Icon(Icons.redo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    if (_attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _attachments.map((attachment) {
          final isImage = attachment.type == NoteAttachmentType.image;
          return InputChip(
            label: Text(attachment.name),
            avatar: Icon(isImage ? Icons.image_outlined : Icons.attach_file),
            onPressed: () => _openAttachment(attachment),
            onDeleted: () => _removeAttachment(attachment),
          );
        }).toList(),
      ),
    );
  }
}
