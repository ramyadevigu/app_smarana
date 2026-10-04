import 'package:flutter/material.dart';

import '../models/note_workspace_models.dart';

const List<NoteCardColor> selectableNoteCardColors = [
  NoteCardColor.yellow,
  NoteCardColor.pink,
  NoteCardColor.purple,
  NoteCardColor.blue,
  NoteCardColor.green,
  NoteCardColor.cyan,
  NoteCardColor.orange,
  NoteCardColor.lavender,
  NoteCardColor.sky,
  NoteCardColor.mint,
];

const Map<NoteCardColor, Color> noteCardPalette = {
  NoteCardColor.yellow: Color(0xFFFFF4CC),
  NoteCardColor.pink: Color(0xFFFFE4EC),
  NoteCardColor.purple: Color(0xFFEEE5FF),
  NoteCardColor.blue: Color(0xFFE3EDFF),
  NoteCardColor.green: Color(0xFFE3F7E9),
  NoteCardColor.cyan: Color(0xFFDDF5F7),
  NoteCardColor.orange: Color(0xFFFFE9D5),
  NoteCardColor.lavender: Color(0xFFF0E8FF),
  NoteCardColor.sky: Color(0xFFE3F2FF),
  NoteCardColor.mint: Color(0xFFE3F7EF),
};

const List<NoteCardColor> noteTextHighlightColors = [
  NoteCardColor.yellow,
  NoteCardColor.pink,
  NoteCardColor.purple,
  NoteCardColor.blue,
  NoteCardColor.green,
  NoteCardColor.cyan,
  NoteCardColor.orange,
];

Color noteCardSurfaceColor(ThemeData theme, NoteCardColor noteColor) {
  final colorScheme = theme.colorScheme;
  final paletteColor = _paletteColor(noteColor);
  if (paletteColor == null) {
    return colorScheme.surfaceContainerLow;
  }

  final blend = theme.brightness == Brightness.light ? 0.9 : 0.18;
  return Color.lerp(colorScheme.surfaceContainerLow, paletteColor, blend)!;
}

Color noteCardAccentColor(ThemeData theme, NoteCardColor noteColor) {
  final paletteColor = _paletteColor(noteColor);
  if (paletteColor == null) {
    return theme.colorScheme.primary;
  }
  final hsl = HSLColor.fromColor(paletteColor);
  return hsl
      .withSaturation(hsl.saturation < 0.55 ? 0.55 : hsl.saturation)
      .withLightness(theme.brightness == Brightness.light ? 0.42 : 0.72)
      .toColor();
}

Color noteTagSurfaceColor(ThemeData theme, NoteCardColor noteColor) {
  final color = _paletteColor(noteColor);
  if (color == null) {
    return theme.colorScheme.secondaryContainer;
  }
  final blend = theme.brightness == Brightness.light ? 0.62 : 0.18;
  return Color.lerp(theme.colorScheme.surfaceContainerLow, color, blend)!;
}

String noteCardColorLabel(NoteCardColor noteColor) {
  return switch (noteColor) {
    NoteCardColor.standard => 'Default',
    NoteCardColor.yellow => 'Yellow',
    NoteCardColor.pink => 'Pink',
    NoteCardColor.purple => 'Purple',
    NoteCardColor.blue => 'Blue',
    NoteCardColor.cyan => 'Cyan',
    NoteCardColor.green => 'Green',
    NoteCardColor.orange => 'Orange',
    NoteCardColor.sky => 'Sky',
    NoteCardColor.mint => 'Mint',
    NoteCardColor.lavender => 'Lavender',
  };
}

Color noteCardSwatchColor(ThemeData theme, NoteCardColor noteColor) {
  return _paletteColor(noteColor) ?? theme.colorScheme.surfaceContainerHighest;
}

Color? _paletteColor(NoteCardColor noteColor) {
  return noteCardPalette[noteColor];
}

NoteCardColor nextBalancedNoteColor(Iterable<NoteEntry> notes) {
  final usage = {for (final color in selectableNoteCardColors) color: 0};
  for (final note in notes) {
    if (usage.containsKey(note.color)) {
      usage[note.color] = usage[note.color]! + 1;
    }
  }
  return selectableNoteCardColors.reduce(
    (first, second) => usage[first]! <= usage[second]! ? first : second,
  );
}

NoteCardColor nextBalancedTagColor(Iterable<NoteCardColor> colors) {
  final usage = {for (final color in selectableNoteCardColors) color: 0};
  for (final color in colors) {
    if (usage.containsKey(color)) {
      usage[color] = usage[color]! + 1;
    }
  }
  return selectableNoteCardColors.reduce(
    (first, second) => usage[first]! <= usage[second]! ? first : second,
  );
}
