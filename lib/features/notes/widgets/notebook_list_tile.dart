import 'package:flutter/material.dart';

import '../models/note_workspace_models.dart';

class NotebookListTile extends StatelessWidget {
  const NotebookListTile({
    super.key,
    required this.notebook,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final Notebook notebook;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  IconData get _icon {
    return switch (notebook.iconType) {
      NotebookIconType.work => Icons.work_outline,
      NotebookIconType.goals => Icons.flag_outlined,
      NotebookIconType.journal => Icons.auto_stories_outlined,
      NotebookIconType.health => Icons.favorite_border,
      NotebookIconType.ideas => Icons.lightbulb_outline,
      NotebookIconType.general => Icons.menu_book_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notebook.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Notebook actions for ${notebook.name}',
              onSelected: (value) {
                if (value == 'rename') {
                  onRename();
                }
                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.drive_file_rename_outline),
                      SizedBox(width: 12),
                      Text('Rename'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 12),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              '${notebook.noteCount} notes',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
