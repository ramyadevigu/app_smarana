import 'note_workspace_models.dart';

class RichNoteDraft {
  const RichNoteDraft({
    required this.title,
    required this.richContentDelta,
    required this.plainContent,
    required this.notebookId,
    required this.attachments,
    this.projectMetadata,
    required this.updatedAt,
    this.reminderId,
    this.color = NoteCardColor.yellow,
  });

  final String title;
  final String richContentDelta;
  final String plainContent;
  final String notebookId;
  final List<NoteAttachment> attachments;
  final NoteProjectMetadata? projectMetadata;
  final DateTime updatedAt;
  final String? reminderId;
  final NoteCardColor color;
}
