import 'package:flutter/material.dart';

import '../models/note_workspace_models.dart';

const List<NoteCardColor> selectableNoteCardColors = [
  NoteCardColor.yellow,
  NoteCardColor.blue,
  NoteCardColor.green,
  NoteCardColor.pink,
  NoteCardColor.purple,
  NoteCardColor.orange,
  NoteCardColor.teal,
  NoteCardColor.lavender,
];

const List<NoteCardColor> selectableNoteTextColors = [
  NoteCardColor.yellow,
  NoteCardColor.pink,
  NoteCardColor.purple,
  NoteCardColor.blue,
  NoteCardColor.green,
  NoteCardColor.cyan,
  NoteCardColor.mint,
  NoteCardColor.orange,
  NoteCardColor.lavender,
  NoteCardColor.sky,
];

const Map<NoteCardColor, Color> _legacyNoteTextColorSwatches = {
  NoteCardColor.cyan: Color(0xFFDDF5F7),
  NoteCardColor.sky: Color(0xFFE3F2FF),
  NoteCardColor.mint: Color(0xFFE3F7EF),
};

@immutable
class NoteCardPalette {
  const NoteCardPalette({
    required this.noteYellow,
    required this.noteBlue,
    required this.noteGreen,
    required this.notePink,
    required this.notePurple,
    required this.noteOrange,
    required this.noteTeal,
    required this.noteLavender,
  });

  final Color noteYellow;
  final Color noteBlue;
  final Color noteGreen;
  final Color notePink;
  final Color notePurple;
  final Color noteOrange;
  final Color noteTeal;
  final Color noteLavender;

  Color colorFor(NoteCardColor color) {
    return switch (_canonicalNoteColor(color)) {
      NoteCardColor.yellow => noteYellow,
      NoteCardColor.blue => noteBlue,
      NoteCardColor.green => noteGreen,
      NoteCardColor.pink => notePink,
      NoteCardColor.purple => notePurple,
      NoteCardColor.orange => noteOrange,
      NoteCardColor.teal => noteTeal,
      NoteCardColor.lavender => noteLavender,
      _ => Colors.transparent,
    };
  }
}

const NoteCardPalette lightNoteCardPalette = NoteCardPalette(
  noteYellow: Color(0xFFFFF8D6),
  noteBlue: Color(0xFFE3F2FD),
  noteGreen: Color(0xFFE6F4EA),
  notePink: Color(0xFFFCE8E6),
  notePurple: Color(0xFFF3E8FD),
  noteOrange: Color(0xFFFEEED8),
  noteTeal: Color(0xFFE0F2F1),
  noteLavender: Color(0xFFE8EAF6),
);

const NoteCardPalette darkNoteCardPalette = NoteCardPalette(
  noteYellow: Color(0xFF4A4224),
  noteBlue: Color(0xFF263F52),
  noteGreen: Color(0xFF294334),
  notePink: Color(0xFF4A3030),
  notePurple: Color(0xFF3E304D),
  noteOrange: Color(0xFF4A3825),
  noteTeal: Color(0xFF264442),
  noteLavender: Color(0xFF30334D),
);

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
  if (noteColor == NoteCardColor.standard) {
    return theme.colorScheme.surfaceContainerLow;
  }
  final palette = theme.brightness == Brightness.light
      ? lightNoteCardPalette
      : darkNoteCardPalette;
  return palette.colorFor(noteColor);
}

Color noteCardForegroundColor(ThemeData theme, NoteCardColor noteColor) {
  return theme.brightness == Brightness.light
      ? const Color(0xFF202124)
      : const Color(0xFFF1F3F4);
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
    NoteCardColor.green => 'Green',
    NoteCardColor.orange => 'Orange',
    NoteCardColor.teal => 'Teal',
    NoteCardColor.cyan => 'Cyan',
    NoteCardColor.lavender => 'Lavender',
    NoteCardColor.sky => 'Sky',
    NoteCardColor.mint => 'Mint',
  };
}

Color noteCardSwatchColor(ThemeData theme, NoteCardColor noteColor) {
  final legacyTextColor = _legacyNoteTextColorSwatches[noteColor];
  if (legacyTextColor != null) {
    return legacyTextColor;
  }
  return noteCardSurfaceColor(theme, noteColor);
}

Color? _paletteColor(NoteCardColor noteColor) {
  if (noteColor == NoteCardColor.standard) {
    return null;
  }
  return lightNoteCardPalette.colorFor(noteColor);
}

NoteCardColor _canonicalNoteColor(NoteCardColor color) {
  return switch (color) {
    NoteCardColor.cyan => NoteCardColor.teal,
    NoteCardColor.sky => NoteCardColor.blue,
    NoteCardColor.mint => NoteCardColor.green,
    _ => color,
  };
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
