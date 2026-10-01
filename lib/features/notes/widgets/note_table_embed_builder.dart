import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class NoteTableEmbedBuilder extends quill.EmbedBuilder {
  const NoteTableEmbedBuilder();

  static const embedType = 'smarana-table';
  static const defaultData =
      '[["Column 1","Column 2"],["Value","Value"]]';

  @override
  String get key => embedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final rows = _decodeRows(embedContext.node.value.data);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Table(
        border: TableBorder.all(color: colors.outlineVariant),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
            TableRow(
              decoration: rowIndex == 0
                  ? BoxDecoration(color: colors.surfaceContainerHighest)
                  : null,
              children: [
                for (final cell in rows[rowIndex])
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      cell,
                      style: rowIndex == 0
                          ? const TextStyle(fontWeight: FontWeight.w600)
                          : null,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<List<String>> _decodeRows(Object? data) {
    try {
      final decoded = jsonDecode(data as String);
      if (decoded is List && decoded.isNotEmpty) {
        final rows = decoded
            .whereType<List>()
            .map(
              (row) => row.map((cell) => cell.toString()).toList(),
            )
            .where((row) => row.isNotEmpty)
            .toList();
        if (rows.isNotEmpty) {
          final columnCount = rows
              .map((row) => row.length)
              .reduce((left, right) => left > right ? left : right);
          return [
            for (final row in rows)
              [...row, ...List<String>.filled(columnCount - row.length, '')],
          ];
        }
      }
    } on FormatException {
      // Fall through to a safe table shape for older or corrupted notes.
    }
    return const [
      ['Column 1', 'Column 2'],
      ['Value', 'Value'],
    ];
  }
}