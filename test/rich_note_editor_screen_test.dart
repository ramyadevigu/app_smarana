import 'package:app_smarana/features/notes/models/note_workspace_models.dart';
import 'package:app_smarana/features/notes/models/rich_note_draft.dart';
import 'package:app_smarana/features/notes/screens/rich_note_editor_screen.dart';
import 'package:app_smarana/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the inline title and compact notebook section chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: RichNoteEditorScreen(
          notebookName: 'Quick Ideas',
          sections: [
            NoteSection(
              id: 'section-campaigns',
              name: 'Campaigns',
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          initialSectionId: 'section-campaigns',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleField = tester.widget<TextField>(
      find.byKey(const ValueKey('rich-note-title-field')),
    );
    expect(titleField.controller?.text, 'Untitled');
    expect(titleField.style?.fontSize, 24);
    expect(titleField.style?.fontWeight, FontWeight.w700);
    expect(titleField.decoration?.filled, isFalse);
    expect(titleField.decoration?.border, InputBorder.none);
    expect(titleField.decoration?.enabledBorder, InputBorder.none);
    expect(titleField.decoration?.focusedBorder, InputBorder.none);
    expect(titleField.decoration?.disabledBorder, InputBorder.none);
    expect(titleField.decoration?.errorBorder, InputBorder.none);
    expect(titleField.decoration?.focusedErrorBorder, InputBorder.none);
    expect(find.text('Edit note'), findsNothing);
    expect(find.text('Campaigns'), findsOneWidget);
    expect(find.text('Quick Ideas'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rich-note-formatting-toolbar')),
      findsOneWidget,
    );
    expect(find.byTooltip('Heading'), findsOneWidget);
  });

  testWidgets('opens compact reminder settings from the bell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RichNoteEditorScreen(
          sections: [
            NoteSection(
              id: 'section-1',
              name: 'General',
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          initialSectionId: 'section-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-editor-reminder-button')));
    await tester.pumpAndSettle();

    expect(find.text('Set Reminder'), findsOneWidget);
    expect(find.text('Date & Time'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Alert sound'), findsOneWidget);
    expect(find.text('Project Mode'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formatting rail collapses and More exposes note actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RichNoteEditorScreen(
          sections: [
            NoteSection(
              id: 'section-1',
              name: 'General',
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          initialSectionId: 'section-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collapse formatting toolbar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Heading'), findsNothing);

    await tester.tap(find.byTooltip('Expand formatting toolbar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Heading'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-editor-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Add to Notebook / Move'), findsOneWidget);
    expect(find.text('Add Tags'), findsOneWidget);
    expect(find.text('Add Attachment'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('note color picker uses the approved theme palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RichNoteEditorScreen(
          sections: [
            NoteSection(
              id: 'section-color',
              name: 'General',
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          initialSectionId: 'section-color',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-editor-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note color'));
    await tester.pumpAndSettle();

    expect(find.text('Note Colors'), findsOneWidget);
    await tester.tap(find.byTooltip('Pink'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-editor-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note color'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Pink note color, selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all ten note colors can be selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RichNoteEditorScreen(
          sections: [
            NoteSection(
              id: 'section-palette',
              name: 'General',
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          initialSectionId: 'section-palette',
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final color in [
      'Yellow',
      'Pink',
      'Purple',
      'Blue',
      'Green',
      'Cyan',
      'Mint',
      'Orange',
      'Lavender',
      'Sky',
    ]) {
      await tester.tap(find.byKey(const ValueKey('note-editor-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note color'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(color));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('note-editor-more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note color'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('$color note color, selected'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag colors can be changed and persisted by tag key', (
    tester,
  ) async {
    Map<String, NoteCardColor>? savedTagColors;
    final now = DateTime(2026, 10, 1);
    final note = NoteEntry(
      id: 'tagged-note',
      notebookId: 'notebook',
      sectionId: 'section-tags',
      title: 'Campaign',
      content: '',
      projectMetadata: const NoteProjectMetadata(tags: ['Campaigns']),
      createdAt: now,
      updatedAt: now,
      color: NoteCardColor.yellow,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RichNoteEditorScreen(
          note: note,
          sections: [
            NoteSection(id: 'section-tags', name: 'General', createdAt: now),
          ],
          initialSectionId: 'section-tags',
          onTagColorsChanged: (colors) async {
            savedTagColors = colors;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Change Campaigns tag color'));
    await tester.pumpAndSettle();
    expect(find.text('Tag Color'), findsOneWidget);
    await tester.tap(find.byTooltip('Lavender'));
    await tester.pumpAndSettle();

    expect(savedTagColors, containsPair('campaigns', NoteCardColor.lavender));
    expect(find.byTooltip('Change Campaigns tag color'), findsOneWidget);
    await tester.tap(find.byTooltip('Change Campaigns tag color'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Lavender tag color, selected'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('category chip has no icon and opens its seven colors', (
    tester,
  ) async {
    NoteCardColor? savedColor;
    String? savedSectionId;
    final now = DateTime(2026, 10, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: RichNoteEditorScreen(
          sections: [
            NoteSection(id: 'section-general', name: 'General', createdAt: now),
          ],
          initialSectionId: 'section-general',
          onSectionColorChanged: (sectionId, color) async {
            savedSectionId = sectionId;
            savedColor = color;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.folder_outlined), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rich-note-section-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Category Color'), findsOneWidget);
    for (final color in [
      NoteCardColor.blue,
      NoteCardColor.cyan,
      NoteCardColor.mint,
      NoteCardColor.green,
      NoteCardColor.orange,
      NoteCardColor.pink,
      NoteCardColor.lavender,
    ]) {
      expect(
        find.byKey(ValueKey('section-color-${color.name}')),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('section-color-pink')));
    await tester.pumpAndSettle();

    expect(savedSectionId, 'section-general');
    expect(savedColor, NoteCardColor.pink);
    await tester.tap(find.byKey(const ValueKey('rich-note-section-dropdown')));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Pink category color, selected'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected text highlight is saved as a rich-text attribute', (
    tester,
  ) async {
    RichNoteDraft? savedDraft;
    await tester.pumpWidget(
      MaterialApp(
        home: RichNoteEditorScreen(
          sections: [
            NoteSection(
              id: 'section-highlight',
              name: 'General',
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          initialSectionId: 'section-highlight',
          onAutosave: (draft) async {
            savedDraft = draft;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<quill.QuillEditor>(
      find.byKey(const ValueKey('rich-note-content-editor')),
    );
    final controller = editor.controller;
    const noteText = 'Campaign goals';
    controller.document.insert(0, '$noteText\n');
    controller.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: noteText.length),
      quill.ChangeSource.local,
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Text and section colors'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Text highlight Yellow'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    final delta = controller.document.toDelta().toJson();
    expect(
      delta.whereType<Map>().any(
        (operation) =>
            operation['attributes'] is Map &&
            (operation['attributes'] as Map).containsKey('background'),
      ),
      isTrue,
    );
    expect(savedDraft?.richContentDelta, contains('background'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple text colors remain readable in both theme modes', (
    tester,
  ) async {
    const words = ['One', 'two', 'three', 'four', 'five', 'six', 'seven'];
    const colorNames = [
      'Yellow',
      'Pink',
      'Purple',
      'Blue',
      'Green',
      'Cyan',
      'Orange',
    ];
    final content = '${words.join(' ')}\n';

    for (final brightness in [Brightness.light, Brightness.dark]) {
      RichNoteDraft? savedDraft;
      final mode = brightness == Brightness.light
          ? ThemeMode.light
          : ThemeMode.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          home: RichNoteEditorScreen(
            key: ValueKey('editor-${brightness.name}'),
            sections: [
              NoteSection(
                id: 'section-colors',
                name: 'General',
                createdAt: DateTime(2026, 10, 1),
              ),
            ],
            initialSectionId: 'section-colors',
            onAutosave: (draft) async {
              savedDraft = draft;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editor = tester.widget<quill.QuillEditor>(
        find.byKey(const ValueKey('rich-note-content-editor')),
      );
      final controller = editor.controller;
      expect(
        Theme.of(
          tester.element(
            find.byKey(const ValueKey('rich-note-content-editor')),
          ),
        ).brightness,
        brightness,
      );
      controller.document.insert(0, content);

      for (var index = 0; index < words.length; index++) {
        final start = content.indexOf(words[index]);
        controller.updateSelection(
          TextSelection(
            baseOffset: start,
            extentOffset: start + words[index].length,
          ),
          quill.ChangeSource.local,
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Text and section colors'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Text highlight ${colorNames[index]}'));
        await tester.pumpAndSettle();
      }

      for (var index = 0; index < words.length; index++) {
        final start = content.indexOf(words[index]);
        controller.updateSelection(
          TextSelection(
            baseOffset: start,
            extentOffset: start + words[index].length,
          ),
          quill.ChangeSource.local,
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Text and section colors'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Text color ${colorNames[index]}'));
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      final delta = controller.document.toDelta().toJson();
      final highlightColors = <String>{};
      final textColors = <String>{};
      final runs = <String, Map>{};
      for (final operation in delta.whereType<Map>()) {
        final insertedText = operation['insert'];
        final attributes = operation['attributes'];
        if (insertedText is! String || attributes is! Map) {
          continue;
        }
        final background = attributes['background'];
        final foreground = attributes['color'];
        if (background is String) {
          highlightColors.add(background);
        }
        if (foreground is String) {
          textColors.add(foreground);
        }
        for (final word in words) {
          if (insertedText.contains(word)) {
            runs[word] = attributes;
          }
        }
      }

      expect(
        highlightColors,
        hasLength(words.length),
        reason: 'Serialized delta: $delta',
      );
      expect(textColors, hasLength(words.length));
      for (final word in words) {
        final attributes = runs[word]!;
        final foreground = _colorFromHex(attributes['color']! as String);
        final background = _colorFromHex(attributes['background']! as String);
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(savedDraft?.richContentDelta, contains('background'));
      expect(savedDraft?.richContentDelta, contains('color'));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('editor and reminder sheet render across theme modes and sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    final cases = [
      (ThemeMode.light, Brightness.light, const Size(320, 640)),
      (ThemeMode.dark, Brightness.light, const Size(375, 812)),
      (ThemeMode.system, Brightness.light, const Size(800, 1024)),
      (ThemeMode.system, Brightness.dark, const Size(320, 640)),
    ];

    for (final (mode, systemBrightness, size) in cases) {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          systemBrightness;
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          home: RichNoteEditorScreen(
            sections: [
              NoteSection(
                id: 'section-theme',
                name: 'General',
                createdAt: DateTime(2026, 10, 1),
              ),
            ],
            initialSectionId: 'section-theme',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expectedBrightness = mode == ThemeMode.system
          ? systemBrightness
          : mode == ThemeMode.dark
          ? Brightness.dark
          : Brightness.light;
      expect(
        Theme.of(
          tester.element(
            find.byKey(const ValueKey('rich-note-content-editor')),
          ),
        ).brightness,
        expectedBrightness,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey('note-editor-reminder-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Set Reminder'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Set Reminder'))).brightness,
        expectedBrightness,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('note-reminder-done-button')),
      );
      await tester.tap(find.byKey(const ValueKey('note-reminder-done-button')));
      await tester.pumpAndSettle();
    }
  });
}

Color _colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(0xFF000000 | int.parse(value, radix: 16));
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
