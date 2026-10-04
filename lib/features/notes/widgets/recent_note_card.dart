import 'package:flutter/material.dart';

import '../models/note_workspace_models.dart';
import '../theme/note_card_colors.dart';
import '../theme/notebook_colors.dart';
import 'note_tag_chip.dart';

class RecentNoteCard extends StatelessWidget {
  const RecentNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onTogglePinned,
    this.onColorChanged,
    this.onTagColorChanged,
    this.compact = false,
  });

  final RecentNoteView note;
  final VoidCallback onTap;
  final VoidCallback? onTogglePinned;
  final Future<void> Function(NoteCardColor color)? onColorChanged;
  final Future<void> Function(String tag, NoteCardColor color)?
  onTagColorChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardAccent = noteCardAccentColor(theme, note.note.color);
    final notebookAccent = notebookAccentColor(theme, note.notebookColorValue);
    final borderRadius = BorderRadius.circular(18);

    return ClipRRect(
      key: ValueKey('recent-note-card-${note.note.id}'),
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: noteCardSurfaceColor(theme, note.note.color),
            borderRadius: borderRadius,
            border: Border.all(
              color: note.note.isPinned
                  ? colorScheme.primary.withValues(alpha: 0.32)
                  : note.note.color == NoteCardColor.standard
                  ? colorScheme.outlineVariant.withValues(alpha: 0.72)
                  : cardAccent.withValues(alpha: 0.48),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.note.isPinned) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 15,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      note.note.title.isEmpty
                          ? 'Untitled note'
                          : note.note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onTogglePinned != null || onColorChanged != null)
                    PopupMenuButton<String>(
                      tooltip: 'Note actions for ${note.note.title}',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                      iconSize: 19,
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (value) async {
                        if (value == 'pin') {
                          onTogglePinned?.call();
                        } else if (value == 'color' && onColorChanged != null) {
                          final selectedColor = await showNoteCardColorPicker(
                            context,
                            current: note.note.color,
                          );
                          if (selectedColor != null) {
                            await onColorChanged!(selectedColor);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (onColorChanged != null)
                          const PopupMenuItem<String>(
                            value: 'color',
                            child: Row(
                              children: [
                                Icon(Icons.palette_outlined),
                                SizedBox(width: 12),
                                Text('Change color'),
                              ],
                            ),
                          ),
                        if (onTogglePinned != null)
                          PopupMenuItem<String>(
                            value: 'pin',
                            child: Row(
                              children: [
                                Icon(
                                  note.note.isPinned
                                      ? Icons.push_pin_outlined
                                      : Icons.push_pin_rounded,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  note.note.isPinned
                                      ? 'Unpin note'
                                      : 'Pin note',
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  note.note.preview,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (note.note.projectMetadata?.tags.isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  children: [
                    for (
                      var index = 0;
                      index <
                          (note.note.projectMetadata!.tags.length > 2
                              ? 2
                              : note.note.projectMetadata!.tags.length);
                      index++
                    )
                      NoteTagChip(
                        label: note.note.projectMetadata!.tags[index],
                        color:
                            note.tagColors[note
                                .note
                                .projectMetadata!
                                .tags[index]
                                .trim()
                                .toLowerCase()] ??
                            selectableNoteCardColors[index %
                                selectableNoteCardColors.length],
                        onColorChange: onTagColorChanged == null
                            ? null
                            : () async {
                                final tag =
                                    note.note.projectMetadata!.tags[index];
                                final selected = await showNoteTagColorPicker(
                                  context,
                                  current:
                                      note.tagColors[tag
                                          .trim()
                                          .toLowerCase()] ??
                                      selectableNoteCardColors[index %
                                          selectableNoteCardColors.length],
                                );
                                if (selected != null) {
                                  await onTagColorChanged!(tag, selected);
                                }
                              },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (note.note.reminderId != null) ...[
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    flex: 3,
                    child: Container(
                      key: ValueKey('recent-note-notebook-${note.note.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: notebookSurfaceColor(
                          theme,
                          note.notebookColorValue,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: notebookAccent),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            notebookIconData(
                              note.notebookIcon,
                              note.notebookIconType,
                            ),
                            size: 13,
                            color: notebookAccent,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              note.notebookName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: notebookAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: Text(
                      MaterialLocalizations.of(context)
                          .formatShortDate(note.note.updatedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
