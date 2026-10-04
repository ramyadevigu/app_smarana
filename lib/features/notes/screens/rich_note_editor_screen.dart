import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../reminders/models/reminder.dart';
import '../../reminders/services/reminder_storage.dart';
import '../models/note_repeat_option.dart';
import '../models/note_workspace_models.dart';
import '../models/rich_note_draft.dart';
import '../services/note_attachment_storage.dart';
import '../services/note_editor_autosave_service.dart';
import '../widgets/note_table_embed_builder.dart';
import '../../../services/notification_service.dart';

enum _NoteEditorAction {
  addToNotebook,
  addTags,
  addAttachment,
  duplicate,
  share,
  delete,
}

class RichNoteEditorScreen extends StatefulWidget {
  const RichNoteEditorScreen({
    super.key,
    this.note,
    this.notebookName,
    required this.sections,
    required this.initialSectionId,
    this.onAutosave,
    this.onDuplicate,
    this.onDelete,
    this.reminderStorage,
  });

  final NoteEntry? note;
  final String? notebookName;
  final List<NoteSection> sections;
  final String initialSectionId;
  final Future<void> Function(RichNoteDraft draft)? onAutosave;
  final Future<void> Function(RichNoteDraft draft)? onDuplicate;
  final Future<void> Function(RichNoteDraft draft)? onDelete;
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
  Future<void> _reminderSaveQueue = Future<void>.value();

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
  String? _reminderSoundUri;
  String _reminderSoundName = 'Default';
  List<ReminderSoundOption> _availableAlarmSounds = const [];

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController.text = note?.title ?? '';
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = 'Untitled';
    }
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
    unawaited(_loadAvailableAlarmSounds());
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

  Future<void> _loadAvailableAlarmSounds() async {
    final sounds = await NotificationService.instance.availableAlarmSounds();
    if (mounted) {
      setState(() {
        _availableAlarmSounds = sounds;
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
        _reminderSoundUri = reminder.soundUri;
        _reminderSoundName = reminder.soundName;
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
    _activateReminder();
    await _persistReminderQueued();
  }

  void _activateReminder() {
    setState(() {
      if (!_reminderSectionVisible) {
        _reminderCreatedAt = DateTime.now();
      }
      _reminderSectionVisible = true;
      _reminderEnabled = true;
    });
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
    if (!_reminderSectionVisible && value) {
      unawaited(_addReminder());
      return;
    }
    setState(() => _reminderEnabled = value);
    unawaited(_persistReminderQueued());
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
    if (!_reminderSectionVisible) {
      _activateReminder();
    }
    unawaited(_persistReminderQueued());
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
    if (!_reminderSectionVisible) {
      _activateReminder();
    }
    unawaited(_persistReminderQueued());
  }

  void _selectRepeatOption(NoteRepeatOption option) {
    setState(() => _repeatOption = option);
    if (!_reminderSectionVisible) {
      _activateReminder();
    }
    unawaited(_persistReminderQueued());
  }

  Future<void> _selectReminderSound() async {
    final sounds = <ReminderSoundOption>[
      const ReminderSoundOption(name: 'Default', uri: null),
      ..._availableAlarmSounds,
    ];
    if (!sounds.any(
      (sound) =>
          sound.uri == _reminderSoundUri &&
          sound.name == _reminderSoundName,
    )) {
      sounds.add(
        ReminderSoundOption(
          name: _reminderSoundName,
          uri: _reminderSoundUri,
        ),
      );
    }

    final selection = await showModalBottomSheet<ReminderSoundOption>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Alert sound',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final sound in sounds)
            ListTile(
              leading: Icon(
                _reminderSoundUri == sound.uri &&
                        _reminderSoundName == sound.name
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(sound.name),
              onTap: () => Navigator.of(context).pop(sound),
            ),
          if (_availableAlarmSounds.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('No additional alarm sounds are available.'),
            ),
        ],
      ),
    );

    if (selection == null || !mounted) {
      return;
    }
    setState(() {
      _reminderSoundUri = selection.uri;
      _reminderSoundName = selection.name;
      if (!_reminderSectionVisible) {
        _reminderCreatedAt = DateTime.now();
      }
      _reminderSectionVisible = true;
    });
    unawaited(_persistReminderQueued());
  }

  Future<void> _persistReminderQueued() {
    final save = _reminderSaveQueue.then((_) => _persistReminder());
    _reminderSaveQueue = save.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return save;
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
      soundUri: _reminderSoundUri,
      soundName: _reminderSoundName,
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
    try {
      final onAutosave = widget.onAutosave;
      final draft = _buildDraft();
      if (onAutosave != null) {
        await onAutosave(draft);
      }
      if (_reminderId != null) {
        await _persistReminderQueued();
      }
      if (!mounted) {
        return;
      }
      _lastUpdated.value = draft.updatedAt;
      _autosaveMessage.value = 'Saved';
    } on Exception {
      if (!mounted) {
        return;
      }
      _autosaveMessage.value = 'Autosave failed';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Autosave failed. Your latest changes are still on screen.',
          ),
        ),
      );
    }
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
    final index = _quillController.selection.baseOffset.clamp(
      0,
      _quillController.document.length - 1,
    );
    _quillController.replaceText(
      index,
      0,
      quill.BlockEmbed(
        NoteTableEmbedBuilder.embedType,
        NoteTableEmbedBuilder.defaultData,
      ),
      TextSelection.collapsed(offset: index + 1),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Remove attachment?'),
        content: Text('Remove "${attachment.name}" from this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
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

  Future<void> _showReminderSettings() async {
    if (_loadingReminder) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refreshSheet) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.62,
            minChildSize: 0.42,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text(
                    'Reminder',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildReminderSection(() => refreshSheet(() {})),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReminderSection(VoidCallback refreshSheet) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final time = TimeOfDay.fromDateTime(_reminderDateTime);
    final isEnabled = _reminderSectionVisible && _reminderEnabled;

    return Column(
      key: const ValueKey('note-reminder-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const ValueKey('note-reminder-enabled-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            _reminderSectionVisible ? 'Reminder enabled' : 'Set a reminder',
          ),
          subtitle: _reminderSectionVisible
              ? Text(
                  _reminderStatusText(localizations, time),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : const Text('Choose a date and time for this note.'),
          value: isEnabled,
          onChanged: (value) {
            _toggleReminderEnabled(value);
            refreshSheet();
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Set Date & Time',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('note-reminder-date-button'),
                onPressed: () async {
                  await _pickReminderDate();
                  refreshSheet();
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  localizations.formatMediumDate(_reminderDateTime),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('note-reminder-time-button'),
                onPressed: () async {
                  await _pickReminderTime();
                  refreshSheet();
                },
                icon: const Icon(Icons.access_time_outlined, size: 18),
                label: Text(localizations.formatTimeOfDay(time)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<NoteRepeatOption>(
          key: const ValueKey('note-reminder-repeat-dropdown'),
          initialValue: _repeatOption,
          decoration: const InputDecoration(
            labelText: 'Repeat',
            prefixIcon: Icon(Icons.repeat_rounded),
          ),
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
              refreshSheet();
            }
          },
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.volume_up_outlined),
          title: const Text('Alert sound'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _reminderSoundName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          onTap: () async {
            await _selectReminderSound();
            refreshSheet();
          },
        ),
        SwitchListTile.adaptive(
          key: const ValueKey('note-project-mode-switch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.lightbulb_outline_rounded),
          title: const Text('Project Mode'),
          subtitle: const Text('Add dates, priority, owner and project tags.'),
          value: _projectMetadataVisible,
          onChanged: (value) {
            setState(() {
              _projectMetadataVisible = value;
            });
            _queueAutosave();
            refreshSheet();
          },
        ),
        if (_projectMetadataVisible)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('note-project-details-button'),
              onPressed: _showProjectDetails,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Project details'),
            ),
          ),
        if (_reminderSectionVisible)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('note-remove-reminder-button'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    icon: const Icon(Icons.delete_outline),
                    title: const Text('Remove reminder?'),
                    content: const Text(
                      'This removes the reminder schedule linked to this note.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _removeReminder();
                  refreshSheet();
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove reminder'),
            ),
          ),
      ],
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

  String get _selectedSectionName {
    for (final section in widget.sections) {
      if (section.id == _selectedSectionId) {
        return section.name;
      }
    }
    return 'Choose section';
  }

  Future<void> _openSectionPicker() async {
    if (widget.sections.isEmpty) {
      return;
    }
    final sectionId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              widget.notebookName == null
                  ? 'Move to section'
                  : 'Move within ${widget.notebookName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final section in widget.sections)
            ListTile(
              leading: Icon(
                section.id == _selectedSectionId
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
              ),
              title: Text(section.name),
              onTap: () => Navigator.of(context).pop(section.id),
            ),
        ],
      ),
    );
    if (sectionId == null || !mounted || sectionId == _selectedSectionId) {
      return;
    }
    setState(() {
      _selectedSectionId = sectionId;
    });
    _queueAutosave();
  }

  Future<void> _showTagsDialog() async {
    final controller = TextEditingController(
      text: _projectTagsController.text,
    );
    final tags = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add tags'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Ideas, Campaigns, Work',
            helperText: 'Separate tags with commas.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (tags == null || !mounted) {
      return;
    }
    setState(() {
      _projectTagsController.text = tags;
      _projectMetadataVisible = true;
    });
    _queueAutosave();
  }

  Future<void> _showAttachmentOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Add image'),
              onTap: () => Navigator.of(context).pop('image'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Add file'),
              onTap: () => Navigator.of(context).pop('file'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (option == 'image') {
      await _addImages();
    } else if (option == 'file') {
      await _addFiles();
    }
  }

  Future<void> _duplicateCurrentNote() async {
    final onDuplicate = widget.onDuplicate;
    if (onDuplicate == null) {
      _showAttachmentError('Duplicate is unavailable from this screen.');
      return;
    }
    try {
      await _flushAutosave();
      await onDuplicate(_buildDraft());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note duplicated.')),
        );
      }
    } on Exception catch (error) {
      _showAttachmentError('Could not duplicate note: $error');
    }
  }

  Future<void> _shareNote() async {
    final content = _quillController.document.toPlainText().trim();
    final title = _titleController.text.trim();
    final text = content.isEmpty ? title : '$title\n\n$content';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } on Exception catch (error) {
      _showAttachmentError('Could not share note: $error');
    }
  }

  Future<void> _deleteCurrentNote() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) {
      _showAttachmentError('Delete is unavailable from this screen.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete note?'),
        content: Text(
          'Delete "${_titleController.text.trim().isEmpty ? 'Untitled' : _titleController.text.trim()}"? '
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
    try {
      await _flushAutosave();
      await onDelete(_buildDraft());
      if (mounted) {
        _isExiting = true;
        Navigator.of(context).pop();
      }
    } on Exception catch (error) {
      _showAttachmentError('Could not delete note: $error');
    }
  }

  void _handleMoreAction(_NoteEditorAction action) {
    switch (action) {
      case _NoteEditorAction.addToNotebook:
        unawaited(_openSectionPicker());
        break;
      case _NoteEditorAction.addTags:
        unawaited(_showTagsDialog());
        break;
      case _NoteEditorAction.addAttachment:
        unawaited(_showAttachmentOptions());
        break;
      case _NoteEditorAction.duplicate:
        unawaited(_duplicateCurrentNote());
        break;
      case _NoteEditorAction.share:
        unawaited(_shareNote());
        break;
      case _NoteEditorAction.delete:
        unawaited(_deleteCurrentNote());
        break;
    }
  }

  Future<void> _showProjectDetails() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refreshSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.94,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Project details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _buildProjectMetadataSection(
                onRefresh: () => refreshSheet(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInsertionOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Highlight color'),
              onTap: () => Navigator.of(context).pop('highlight'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Add attachment'),
              onTap: () => Navigator.of(context).pop('attachment'),
            ),
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text('Undo'),
              onTap: () => Navigator.of(context).pop('undo'),
            ),
            ListTile(
              leading: const Icon(Icons.redo_rounded),
              title: const Text('Redo'),
              onTap: () => Navigator.of(context).pop('redo'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    switch (option) {
      case 'highlight':
        await _showHighlightColors();
        break;
      case 'attachment':
        await _showAttachmentOptions();
        break;
      case 'undo':
        _quillController.undo();
        _queueAutosave();
        break;
      case 'redo':
        _quillController.redo();
        _queueAutosave();
        break;
      default:
        return;
    }
  }

  Future<void> _showHighlightColors() async {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
      colorScheme.surfaceContainerHighest,
    ];
    final selectedColor = await showModalBottomSheet<Color>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < colors.length; index++)
              ActionChip(
                avatar: CircleAvatar(backgroundColor: colors[index]),
                label: Text('Accent ${index + 1}'),
                onPressed: () => Navigator.of(context).pop(colors[index]),
              ),
          ],
        ),
      ),
    );
    if (selectedColor == null || !mounted) {
      return;
    }
    final color = selectedColor.toARGB32().toRadixString(16).substring(2);
    _toggleInlineAttribute(quill.BackgroundAttribute('#$color'));
  }

  void _insertDivider() {
    final selection = _quillController.selection;
    final start = selection.start.clamp(
      0,
      _quillController.document.length - 1,
    );
    final end = selection.end.clamp(
      start,
      _quillController.document.length - 1,
    );
    const divider = '\n────────────\n';
    _quillController.replaceText(
      start,
      end - start,
      divider,
      TextSelection.collapsed(offset: start + divider.length),
    );
    _queueAutosave();
  }

  Widget _toolbarButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildFloatingToolbar(double availableHeight) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = math.min(
      availableHeight,
      math.max(48.0, availableHeight * 0.78),
    );
    final buttons = [
      _toolbarButton(
        tooltip: 'Heading',
        icon: Icons.title_rounded,
        onPressed: () => _toggleInlineAttribute(quill.Attribute.h1),
      ),
      _toolbarButton(
        tooltip: 'Bold',
        icon: Icons.format_bold_rounded,
        onPressed: () => _toggleInlineAttribute(quill.Attribute.bold),
      ),
      _toolbarButton(
        tooltip: 'Italic',
        icon: Icons.format_italic_rounded,
        onPressed: () => _toggleInlineAttribute(quill.Attribute.italic),
      ),
      _toolbarButton(
        tooltip: 'Underline',
        icon: Icons.format_underlined_rounded,
        onPressed: () => _toggleInlineAttribute(quill.Attribute.underline),
      ),
      _toolbarButton(
        tooltip: 'Checklist',
        icon: Icons.check_box_outlined,
        onPressed: () => _toggleInlineAttribute(quill.Attribute.unchecked),
      ),
      _toolbarButton(
        tooltip: 'Bullet list',
        icon: Icons.format_list_bulleted_rounded,
        onPressed: () => _toggleInlineAttribute(quill.Attribute.ul),
      ),
      _toolbarButton(
        tooltip: 'Numbered list',
        icon: Icons.format_list_numbered_rounded,
        onPressed: () => _toggleInlineAttribute(quill.Attribute.ol),
      ),
      _toolbarButton(
        tooltip: 'Insert image',
        icon: Icons.image_outlined,
        onPressed: _addImages,
      ),
      _toolbarButton(
        tooltip: 'Insert hyperlink',
        icon: Icons.link_rounded,
        onPressed: _insertHyperlink,
      ),
      _toolbarButton(
        tooltip: 'Insert table',
        icon: Icons.table_chart_outlined,
        onPressed: _insertTableTemplate,
      ),
      _toolbarButton(
        tooltip: 'Code block',
        icon: Icons.code_rounded,
        onPressed: () => _toggleInlineAttribute(quill.Attribute.codeBlock),
      ),
      _toolbarButton(
        tooltip: 'Insert divider',
        icon: Icons.horizontal_rule_rounded,
        onPressed: _insertDivider,
      ),
      _toolbarButton(
        tooltip: 'Add formatting or content',
        icon: Icons.add_rounded,
        onPressed: _showInsertionOptions,
      ),
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: Material(
        key: const ValueKey('rich-note-formatting-toolbar'),
        color: colorScheme.surface,
        elevation: 5,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: _toolbarExpanded
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 44),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolbarButton(
                      tooltip: 'Collapse formatting toolbar',
                      icon: Icons.tune_rounded,
                      onPressed: () {
                        setState(() => _toolbarExpanded = false);
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 9,
                      endIndent: 9,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: buttons,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _toolbarButton(
                tooltip: 'Expand formatting toolbar',
                icon: Icons.tune_rounded,
                onPressed: () {
                  setState(() => _toolbarExpanded = true);
                },
              ),
      ),
    );
  }

  Widget _buildNotebookHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final tags = _projectTagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final tagColors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ActionChip(
                key: const ValueKey('rich-note-section-dropdown'),
                avatar: Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: colorScheme.primary,
                ),
                label: Text(_selectedSectionName),
                labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: colorScheme.primaryContainer.withValues(
                  alpha: 0.72,
                ),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: _openSectionPicker,
              ),
              if (widget.notebookName != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.notebookName!,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              ValueListenableBuilder<String>(
                valueListenable: _autosaveMessage,
                builder: (context, value, _) {
                  if (value.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (var index = 0; index < tags.length; index++)
                  Chip(
                    label: Text(tags[index]),
                    labelStyle: Theme.of(context).textTheme.labelSmall,
                    backgroundColor: tagColors[index % tagColors.length],
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _exitEditor();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leadingWidth: 48,
          titleSpacing: 0,
          leading: IconButton(
            key: const ValueKey('note-editor-back'),
            tooltip: 'Close editor',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _exitEditor,
          ),
          title: TextField(
            key: const ValueKey('rich-note-title-field'),
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            maxLines: 1,
            decoration: const InputDecoration(
              hintText: 'Untitled',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              key: const ValueKey('note-editor-reminder-button'),
              tooltip: 'Set reminder',
              onPressed: _showReminderSettings,
              icon: Icon(
                _reminderSectionVisible && _reminderEnabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
              ),
            ),
            PopupMenuButton<_NoteEditorAction>(
              key: const ValueKey('note-editor-more-menu'),
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: _handleMoreAction,
              itemBuilder: (context) => const [
                PopupMenuItem<_NoteEditorAction>(
                  value: _NoteEditorAction.addToNotebook,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.drive_file_move_outline),
                    title: Text('Add to Notebook / Move'),
                  ),
                ),
                PopupMenuItem<_NoteEditorAction>(
                  value: _NoteEditorAction.addTags,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.sell_outlined),
                    title: Text('Add Tags'),
                  ),
                ),
                PopupMenuItem<_NoteEditorAction>(
                  value: _NoteEditorAction.addAttachment,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.attach_file_rounded),
                    title: Text('Add Attachment'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem<_NoteEditorAction>(
                  value: _NoteEditorAction.duplicate,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.copy_all_outlined),
                    title: Text('Duplicate'),
                  ),
                ),
                PopupMenuItem<_NoteEditorAction>(
                  value: _NoteEditorAction.share,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.ios_share_rounded),
                    title: Text('Share'),
                  ),
                ),
                PopupMenuItem<_NoteEditorAction>(
                  value: _NoteEditorAction.delete,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildNotebookHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: quill.QuillEditor.basic(
                          key: const ValueKey('rich-note-content-editor'),
                          controller: _quillController,
                          config: quill.QuillEditorConfig(
                            autoFocus: true,
                            padding: const EdgeInsets.fromLTRB(
                              60,
                              16,
                              18,
                              24,
                            ),
                            embedBuilders: const [NoteTableEmbedBuilder()],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _buildFloatingToolbar(constraints.maxHeight),
                      ),
                    ],
                  ),
                ),
              ),
              if (_attachments.isNotEmpty) _buildAttachmentSection(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: ValueListenableBuilder<DateTime?>(
                  valueListenable: _lastUpdated,
                  builder: (context, dateTime, _) {
                    if (dateTime == null) {
                      return const SizedBox(height: 12);
                    }
                    final time = TimeOfDay.fromDateTime(dateTime);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Last updated ${localizations.formatShortDate(dateTime)} '
                        '${localizations.formatTimeOfDay(time)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: _attachments.map((attachment) {
            final isImage = attachment.type == NoteAttachmentType.image;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(attachment.name),
                avatar: Icon(
                  isImage ? Icons.image_outlined : Icons.attach_file,
                  size: 16,
                ),
                onPressed: () => _openAttachment(attachment),
                onDeleted: () => _removeAttachment(attachment),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProjectMetadataSection({required VoidCallback onRefresh}) {
    final localizations = MaterialLocalizations.of(context);
    final hasLinkedReminder = _availableCalendarReminders.any(
      (item) => item.id == _relatedCalendarEventId,
    );
    final selectedCalendarEventId = hasLinkedReminder
        ? _relatedCalendarEventId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          onChanged: (_) {
            _queueAutosave();
            onRefresh();
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('note-project-start-date-button'),
              onPressed: () async {
                await _pickProjectStartDate();
                onRefresh();
              },
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
                  onRefresh();
                },
                icon: const Icon(Icons.close),
              ),
            OutlinedButton.icon(
              key: const ValueKey('note-project-end-date-button'),
              onPressed: () async {
                await _pickProjectEndDate();
                onRefresh();
              },
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
                  onRefresh();
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
    );
  }
}
