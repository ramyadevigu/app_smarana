import 'package:flutter/material.dart';

import '../models/note_workspace_models.dart';
import '../theme/note_card_colors.dart';

class RecentNoteCard extends StatelessWidget {
  const RecentNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onTogglePinned,
    this.compact = false,
  });

  final RecentNoteView note;
  final VoidCallback onTap;
  final VoidCallback? onTogglePinned;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardAccent = noteCardAccentColor(theme, note.note.color);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: noteCardSurfaceColor(theme, note.note.color),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: note.note.isPinned
                ? colorScheme.primary.withValues(alpha: 0.24)
                : note.note.color == NoteCardColor.standard
                ? colorScheme.outlineVariant.withValues(alpha: 0.68)
                : cardAccent.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (note.note.isPinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 15,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    note.note.title.isEmpty ? 'Untitled note' : note.note.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onTogglePinned != null)
                  PopupMenuButton<String>(
                    tooltip: 'Note actions for ${note.note.title}',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40),
                    iconSize: 19,
                    onSelected: (value) {
                      if (value == 'pin') {
                        onTogglePinned!();
                      }
                    },
                    itemBuilder: (context) => [
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
                              note.note.isPinned ? 'Unpin note' : 'Pin note',
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
                Expanded(
                  child: Text(
                    note.sectionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
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
    );
  }
}
