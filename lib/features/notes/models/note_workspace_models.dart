enum NotebookIconType { work, goals, journal, health, ideas, general }

class Notebook {
  const Notebook({
    required this.id,
    required this.name,
    required this.iconType,
    required this.sections,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final NotebookIconType iconType;
  final List<NoteSection> sections;
  final List<NoteEntry> notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get noteCount => notes.length;

  Notebook copyWith({
    String? name,
    NotebookIconType? iconType,
    List<NoteSection>? sections,
    List<NoteEntry>? notes,
    DateTime? updatedAt,
  }) {
    return Notebook(
      id: id,
      name: name ?? this.name,
      iconType: iconType ?? this.iconType,
      sections: sections ?? this.sections,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NoteSection {
  const NoteSection({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  NoteSection copyWith({String? name}) {
    return NoteSection(id: id, name: name ?? this.name, createdAt: createdAt);
  }
}

class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.notebookId,
    required this.sectionId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String notebookId;
  final String sectionId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get preview {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return 'No additional text';
    }
    return trimmed;
  }

  NoteEntry copyWith({
    String? sectionId,
    String? title,
    String? content,
    DateTime? updatedAt,
  }) {
    return NoteEntry(
      id: id,
      notebookId: notebookId,
      sectionId: sectionId ?? this.sectionId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RecentNoteView {
  const RecentNoteView({
    required this.note,
    required this.notebookName,
    required this.sectionName,
  });

  final NoteEntry note;
  final String notebookName;
  final String sectionName;
}
