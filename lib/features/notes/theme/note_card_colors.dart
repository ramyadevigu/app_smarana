import 'package:flutter/material.dart';

import '../models/note_workspace_models.dart';

Color noteCardSurfaceColor(ThemeData theme, NoteCardColor noteColor) {
  final colorScheme = theme.colorScheme;
  final paletteColor = _paletteColor(noteColor);
  if (paletteColor == null) {
    return colorScheme.surfaceContainerLow;
  }

  final blend = theme.brightness == Brightness.light ? 0.18 : 0.24;
  return Color.lerp(colorScheme.surfaceContainerLow, paletteColor, blend)!;
}

Color noteCardAccentColor(ThemeData theme, NoteCardColor noteColor) {
  return _paletteColor(noteColor) ?? theme.colorScheme.primary;
}

String noteCardColorLabel(NoteCardColor noteColor) {
  return switch (noteColor) {
    NoteCardColor.standard => 'Default',
    NoteCardColor.blue => 'Blue',
    NoteCardColor.cyan => 'Cyan',
    NoteCardColor.mint => 'Mint',
    NoteCardColor.lightGreen => 'Light Green',
    NoteCardColor.peach => 'Peach',
    NoteCardColor.pink => 'Pink',
    NoteCardColor.lavender => 'Lavender',
  };
}

Color noteCardSwatchColor(ThemeData theme, NoteCardColor noteColor) {
  return _paletteColor(noteColor) ?? theme.colorScheme.surfaceContainerHighest;
}

Color? _paletteColor(NoteCardColor noteColor) {
  return switch (noteColor) {
    NoteCardColor.standard => null,
    NoteCardColor.blue => const Color(0xFF4773FA),
    NoteCardColor.cyan => const Color(0xFF93DCED),
    NoteCardColor.mint => const Color(0xFF9CE3D3),
    NoteCardColor.lightGreen => const Color(0xFFCAE0B9),
    NoteCardColor.peach => const Color(0xFFFBD6A1),
    NoteCardColor.pink => const Color(0xFFF7BED1),
    NoteCardColor.lavender => const Color(0xFFD0C6FA),
  };
}
