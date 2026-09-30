import 'note_workspace_models.dart';

class RichNoteDraft {
  const RichNoteDraft({
    required this.title,
    required this.richContentDelta,
    required this.plainContent,
    required this.sectionId,
    required this.attachments,
    required this.updatedAt,
  });

  final String title;
  final String richContentDelta;
  final String plainContent;
  final String sectionId;
  final List<NoteAttachment> attachments;
  final DateTime updatedAt;
}
