import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';

import '../../reminders/models/reminder.dart';
import '../../reminders/services/reminder_storage.dart';
import '../models/note_repeat_option.dart';
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
    this.reminderStorage,
  });

  final NoteEntry? note;
  final List<NoteSection> sections;
  final String initialSectionId;
  final Future<void> Function(RichNoteDraft draft)? onAutosave;
  final ReminderStorage? reminderStorage;

  @override
  State<RichNoteEditorScreen> createState() => _RichNoteEditorScreenState();
}

class _RichNoteEditorScreenState extends State<RichNoteEditorScreen> {
  final _titleController = TextEditingController();
  final _projectOwnerController = TextEditingController();
  final _projectTagsController = TextEditingController();
  final _autosaveService = NoteEditorAutosaveService();
  final _attachmentStorage = NoteAttachmentStorage();
  final _uuid = const Uuid();
  final _lastUpdated = ValueNotifier<DateTime?>(null);
  final _autosaveMessage = ValueNotifier<String>('');

  late final quill.QuillController _quillController;
  late final ReminderStorage _reminderStorage;
  late String _selectedSectionId;
  late List<NoteAttachment> _attachments;
  bool _toolbarExpanded = true;
  bool _isExiting = false;
  bool _projectMetadataVisible = false;

  DateTime? _projectStartDate;
  DateTime? _projectEndDate;
  NoteProjectPriority? _projectPriority;
  NoteProjectStatus _projectStatus = NoteProjectStatus.toDo;
  String? _relatedCalendarEventId;
  List<Reminder> _availableCalendarReminders = const [];

  bool _reminderSectionVisible = false;
  bool _loadingReminder = false;
  String? _reminderId;
  bool _reminderEnabled = true;
  DateTime _reminderDateTime = DateTime.now().add(const Duration(minutes: 5));
  DateTime _reminderCreatedAt = DateTime.now();
  NoteRepeatOption _repeatOption = NoteRepeatOption.doesNotRepeat;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController.text = note?.title ?? '';
    _selectedSectionId = note?.sectionId ?? widget.initialSectionId;
    _attachments = List<NoteAttachment>.of(note?.attachments ?? const []);
    _reminderStorage = widget.reminderStorage ?? ReminderStorage();
    final metadata = note?.projectMetadata;
    _projectMetadataVisible = metadata != null;
    _projectOwnerController.text = metadata?.owner ?? '';
    _projectTagsController.text = metadata?.tags.join(', ') ?? '';
    _projectStartDate = metadata?.startDate;
    _projectEndDate = metadata?.endDate;
    _projectPriority = metadata?.priority;
    _projectStatus = metadata?.status ?? NoteProjectStatus.toDo;
    _relatedCalendarEventId = metadata?.relatedCalendarEventId;

    _quillController = quill.QuillController(
      document: _buildDocument(note),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: false,
    );

    _lastUpdated.value = note?.updatedAt;

    _titleController.addListener(_queueAutosave);
    _quillController.addListener(_queueAutosave);

    final reminderId = note?.reminderId;
    if (reminderId != null && reminderId.isNotEmpty) {
      _reminderId = reminderId;
      _reminderSectionVisible = true;
      _loadingReminder = true;
      unawaited(_loadReminder(reminderId));
    }
    unawaited(_loadAvailableCalendarReminders());
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_queueAutosave)
      ..dispose();
    _projectOwnerController.dispose();
    _projectTagsController.dispose();
    _quillController
      ..removeListener(_queueAutosave)
      ..dispose();
    _autosaveService.dispose();
    _lastUpdated.dispose();
    _autosaveMessage.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableCalendarReminders() async {
    try {
      final reminders = await _reminderStorage.getReminders();
      reminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (!mounted) {
        return;
      }
      setState(() {
        _availableCalendarReminders = reminders;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableCalendarReminders = const [];
      });
    }
  }

  Future<void> _loadReminder(String reminderId) async {
    try {
      final reminders = await _reminderStorage.getReminders();
      final match = reminders.where((item) => item.id == reminderId);
      if (!mounted) {
        return;
      }
      if (match.isEmpty) {
        setState(() {
          _reminderId = null;
          _reminderSectionVisible = false;
          _loadingReminder = false;
        });
        return;
      }
      final reminder = match.first;
      setState(() {
        _reminderEnabled = reminder.enabled;
        _reminderDateTime = reminder.dateTime;
        _reminderCreatedAt = reminder.createdAt;
        _repeatOption = NoteRepeatOption.fromRecurrenceRule(
          reminder.recurrenceRule,
        );
        _loadingReminder = false;
      });
    } on Exception {
      if (mounted) {
        setState(() => _loadingReminder = false);
      }
    }
  }

  Future<void> _addReminder() async {
    setState(() {
      _reminderSectionVisible = true;
      _reminderEnabled = true;
      _reminderDateTime = DateTime.now().add(const Duration(minutes: 5));
      _reminderCreatedAt = DateTime.now();
      _repeatOption = NoteRepeatOption.doesNotRepeat;
    });
    await _persistReminder();
    _queueAutosave();
  }

  Future<void> _removeReminder() async {
    final reminderId = _reminderId;
    try {
      if (reminderId != null) {
        await _reminderStorage.deleteReminder(reminderId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _reminderId = null;
        _reminderSectionVisible = false;
        _reminderEnabled = true;
        _repeatOption = NoteRepeatOption.doesNotRepeat;
      });
      _queueAutosave();
    } on Exception catch (error) {
      _showAttachmentError('Could not remove the reminder: $error');
    }
  }

  void _toggleReminderEnabled(bool value) {
    setState(() => _reminderEnabled = value);
    _persistReminder();
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
    _persistReminder();
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
    _persistReminder();
  }

  void _selectRepeatOption(NoteRepeatOption option) {
    setState(() => _repeatOption = option);
    _persistReminder();
  }

  Future<void> _persistReminder() async {
    final reminderId = _reminderId;
    if (reminderId == null && !_reminderSectionVisible) {
      return;
    }

    final title = _titleController.text.trim();
    final description = _quillController.document.toPlainText().trim();
    final reminder = Reminder(
      id: reminderId ?? _uuid.v4(),
      title: title.isEmpty ? 'Note reminder' : title,
      description: description.isEmpty
          ? null
          : description.length > 300
          ? description.substring(0, 300)
          : description,
      dateTime: _reminderDateTime,
      recurrenceRule: _repeatOption.toRecurrenceRule(_reminderDateTime),
      enabled: _reminderEnabled,
      createdAt: _reminderCreatedAt,
    );

    try {
      if (reminderId == null) {
        await _reminderStorage.addReminder(reminder);
        if (mounted) {
          setState(() => _reminderId = reminder.id);
        }
      } else {
        await _reminderStorage.updateReminder(reminder);
      }
    } on Exception catch (error) {
      if (mounted) {
        _showAttachmentError('Could not save the reminder: $error');
      }
    }
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
    final projectMetadata = _buildProjectMetadata();
    return RichNoteDraft(
      title: _titleController.text.trim(),
      richContentDelta: jsonEncode(
        _quillController.document.toDelta().toJson(),
      ),
      plainContent: _quillController.document.toPlainText().trim(),
      sectionId: _selectedSectionId,
      attachments: List<NoteAttachment>.unmodifiable(_attachments),
      projectMetadata: projectMetadata,
      updatedAt: now,
      reminderId: _reminderId,
    );
  }

  NoteProjectMetadata? _buildProjectMetadata() {
    if (!_projectMetadataVisible) {
      return null;
    }
    final ownerText = _projectOwnerController.text.trim();
    final owner = ownerText.isEmpty ? null : ownerText;
    final tags = <String>[];
    final seen = <String>{};
    for (final raw in _projectTagsController.text.split(',')) {
      final tag = raw.trim();
      if (tag.isNotEmpty && seen.add(tag.toLowerCase())) {
        tags.add(tag);
      }
    }
    final metadata = NoteProjectMetadata(
      owner: owner,
      tags: tags,
      startDate: _projectStartDate,
      endDate: _projectEndDate,
      priority: _projectPriority,
      status: _projectStatus,
      relatedCalendarEventId: _relatedCalendarEventId,
    );
    return metadata.isEmpty ? null : metadata;
  }

  Future<void> _pickProjectStartDate() async {
    final initialDate = _projectStartDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      _projectStartDate = date;
      final endDate = _projectEndDate;
      if (endDate != null && endDate.isBefore(date)) {
        _projectEndDate = date;
      }
    });
    _queueAutosave();
  }

  Future<void> _pickProjectEndDate() async {
    final initialDate = _projectEndDate ?? _projectStartDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      _projectEndDate = date;
      final startDate = _projectStartDate;
      if (startDate != null && startDate.isAfter(date)) {
        _projectStartDate = date;
      }
    });
    _queueAutosave();
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
    if (_reminderId != null) {
      await _persistReminder();
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

  Widget _buildReminderSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loadingReminder) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (!_reminderSectionVisible) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: OutlinedButton.icon(
          key: const ValueKey('note-add-reminder-button'),
          onPressed: _addReminder,
          icon: const Icon(Icons.notifications_outlined),
          label: const Text('Add Reminder'),
        ),
      );
    }

    final localizations = MaterialLocalizations.of(context);
    final time = TimeOfDay.fromDateTime(_reminderDateTime);

    return Container(
      key: const ValueKey('note-reminder-section'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reminder',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                key: const ValueKey('note-reminder-enabled-switch'),
                value: _reminderEnabled,
                onChanged: _toggleReminderEnabled,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _reminderStatusText(localizations, time),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('note-reminder-date-button'),
                  onPressed: _pickReminderDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    localizations.formatMediumDate(_reminderDateTime),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('note-reminder-time-button'),
                  onPressed: _pickReminderTime,
                  icon: const Icon(Icons.access_time_outlined, size: 18),
                  label: Text(localizations.formatTimeOfDay(time)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<NoteRepeatOption>(
            key: const ValueKey('note-reminder-repeat-dropdown'),
            initialValue: _repeatOption,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: NoteRepeatOption.values
                .map(
                  (option) => DropdownMenuItem<NoteRepeatOption>(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                _selectRepeatOption(value);
              }
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('note-remove-reminder-button'),
              onPressed: _removeReminder,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove reminder'),
            ),
          ),
        ],
      ),
    );
  }

  String _reminderStatusText(
    MaterialLocalizations localizations,
    TimeOfDay time,
  ) {
    final dateLabel = localizations.formatMediumDate(_reminderDateTime);
    final timeLabel = localizations.formatTimeOfDay(time);
    final repeatLabel = _repeatOption == NoteRepeatOption.doesNotRepeat
        ? ''
        : ' · ${_repeatOption.label}';
    final statusLabel = _reminderEnabled ? '' : ' · Disabled';
    return 'Reminds on $dateLabel at $timeLabel$repeatLabel$statusLabel';
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
              _buildReminderSection(),
              _buildProjectMetadataSection(),
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

  Widget _buildProjectMetadataSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final hasLinkedReminder = _availableCalendarReminders.any(
      (item) => item.id == _relatedCalendarEventId,
    );
    final selectedCalendarEventId = hasLinkedReminder
        ? _relatedCalendarEventId
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              key: const ValueKey('note-project-metadata-toggle'),
              value: _projectMetadataVisible,
              contentPadding: EdgeInsets.zero,
              title: const Text('Project mode'),
              subtitle: const Text('Add optional project fields'),
              onChanged: (value) {
                setState(() {
                  _projectMetadataVisible = value;
                });
                _queueAutosave();
              },
            ),
          ),
          if (_projectMetadataVisible) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('note-project-owner-field'),
              controller: _projectOwnerController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Owner',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => _queueAutosave(),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('note-project-tags-field'),
              controller: _projectTagsController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Design, Sprint 3',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              onChanged: (_) => _queueAutosave(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('note-project-start-date-button'),
                  onPressed: _pickProjectStartDate,
                  icon: const Icon(Icons.play_arrow_outlined, size: 18),
                  label: Text(
                    _projectStartDate == null
                        ? 'Start date'
                        : localizations.formatMediumDate(_projectStartDate!),
                  ),
                ),
                if (_projectStartDate != null)
                  IconButton(
                    tooltip: 'Clear start date',
                    onPressed: () {
                      setState(() {
                        _projectStartDate = null;
                      });
                      _queueAutosave();
                    },
                    icon: const Icon(Icons.close),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('note-project-end-date-button'),
                  onPressed: _pickProjectEndDate,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(
                    _projectEndDate == null
                        ? 'End date'
                        : localizations.formatMediumDate(_projectEndDate!),
                  ),
                ),
                if (_projectEndDate != null)
                  IconButton(
                    tooltip: 'Clear end date',
                    onPressed: () {
                      setState(() {
                        _projectEndDate = null;
                      });
                      _queueAutosave();
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<NoteProjectPriority?>(
              key: const ValueKey('note-project-priority-dropdown'),
              initialValue: _projectPriority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem<NoteProjectPriority?>(
                  value: null,
                  child: Text('Not set'),
                ),
                DropdownMenuItem<NoteProjectPriority?>(
                  value: NoteProjectPriority.low,
                  child: Text('Low'),
                ),
                DropdownMenuItem<NoteProjectPriority?>(
                  value: NoteProjectPriority.medium,
                  child: Text('Medium'),
                ),
                DropdownMenuItem<NoteProjectPriority?>(
                  value: NoteProjectPriority.high,
                  child: Text('High'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _projectPriority = value;
                });
                _queueAutosave();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<NoteProjectStatus>(
              key: const ValueKey('note-project-status-dropdown'),
              initialValue: _projectStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem<NoteProjectStatus>(
                  value: NoteProjectStatus.toDo,
                  child: Text('To Do'),
                ),
                DropdownMenuItem<NoteProjectStatus>(
                  value: NoteProjectStatus.inProgress,
                  child: Text('In Progress'),
                ),
                DropdownMenuItem<NoteProjectStatus>(
                  value: NoteProjectStatus.done,
                  child: Text('Done'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _projectStatus = value;
                });
                _queueAutosave();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: const ValueKey('note-project-calendar-link-dropdown'),
              initialValue: selectedCalendarEventId,
              decoration: const InputDecoration(
                labelText: 'Related calendar event',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not linked'),
                ),
                ..._availableCalendarReminders.map((reminder) {
                  final formatted = localizations.formatMediumDate(
                    reminder.dateTime,
                  );
                  return DropdownMenuItem<String?>(
                    value: reminder.id,
                    child: Text('${reminder.title} ($formatted)'),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _relatedCalendarEventId = value;
                });
                _queueAutosave();
              },
            ),
          ],
        ],
      ),
    );
  }
}
