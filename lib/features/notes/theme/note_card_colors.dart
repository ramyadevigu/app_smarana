import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
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
  if (noteColor == NoteCardColor.standard) {
    return 'Default';
  }
  return SmaranaColorTheme.values
      .firstWhere((colorTheme) => colorTheme.name == noteColor.name)
      .label;
}

Color noteCardSwatchColor(
  ThemeData theme,
  NoteCardColor noteColor,
) {
  return _paletteColor(noteColor) ?? theme.colorScheme.surfaceContainerHighest;
}

Color? _paletteColor(NoteCardColor noteColor) {
  if (noteColor == NoteCardColor.standard) {
    return null;
  }
  return SmaranaColorTheme.values
      .firstWhere((colorTheme) => colorTheme.name == noteColor.name)
      .color;
}
