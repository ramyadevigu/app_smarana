import 'dart:convert';

import 'package:app_smarana/features/notes/models/note_workspace_models.dart';
import 'package:app_smarana/features/notes/notes_screen.dart';
import 'package:app_smarana/features/notes/theme/notebook_colors.dart';
import 'package:app_smarana/features/notes/widgets/notebook_list_tile.dart';
import 'package:app_smarana/features/notes/widgets/recent_note_card.dart';
import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows individual notebooks alongside category filters', (
    tester,
  ) async {
    final now = DateTime.now();
    final notebook = Notebook(
      id: 'folder-notebook',
      name: 'app',
      iconType: NotebookIconType.general,
      sections: [
        NoteSection(id: 'folder-section', name: 'General', createdAt: now),
      ],
      notes: const [],
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
    );
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Notebooks'), findsOneWidget);
    expect(find.text('app'), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-add-note-fab')), findsOneWidget);
  });

  testWidgets('tapping a notebook opens it and keeps it selected', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 1);
    final notebook = Notebook(
      id: 'open-notebook',
      name: 'Open this notebook',
      iconType: NotebookIconType.general,
      sections: [
        NoteSection(id: 'open-section', name: 'General', createdAt: now),
      ],
      notes: const [],
      createdAt: now,
      updatedAt: now,
    );
    final notebookFinder = find.byKey(
      const ValueKey('notebook-card-open-notebook'),
    );

    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
    );
    await tester.pumpAndSettle();

    await tester.tap(notebookFinder);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notebook-add-section')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notebook-save-and-close')));
    await tester.pumpAndSettle();

    expect(tester.widget<NotebookListTile>(notebookFinder).selected, isTrue);
  });

  testWidgets('long-press notebook options edit its settings', (tester) async {
    final now = DateTime(2026, 10, 1);
    final notebook = Notebook(
      id: 'customize-notebook',
      name: 'Reading',
      iconType: NotebookIconType.journal,
      sections: [
        NoteSection(id: 'reading-section', name: 'Books', createdAt: now),
      ],
      notes: const [],
      createdAt: now,
      updatedAt: now,
    );
    final notebookFinder = find.byKey(
      const ValueKey('notebook-card-customize-notebook'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: NotesScreen(initialNotebooks: [notebook]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(notebookFinder);
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Change Icon'), findsOneWidget);
    expect(find.text('Change Color'), findsOneWidget);
    expect(find.text('Edit Description'), findsOneWidget);
    expect(find.text('Delete Notebook'), findsOneWidget);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Reading list');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Reading list'), findsOneWidget);

    await tester.longPress(notebookFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Description'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Books to explore');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Books to explore'), findsOneWidget);

    await tester.longPress(notebookFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change Color'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Purple'));
    await tester.pumpAndSettle();

    final notebookTile = tester.widget<NotebookListTile>(notebookFinder);
    expect(notebookTile.notebook.colorValue, NotebookBaseColor.purple.value);
    expect(notebookTile.notebook.description, 'Books to explore');

    await tester.longPress(notebookFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change Icon'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('School'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NotebookListTile>(notebookFinder).notebook.icon,
      NotebookIcon.school,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('notebook colors remain solid in light and dark themes', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 1);
    const colorValue = 0xFF78C4BB;
    final notebook = Notebook(
      id: 'theme-notebook',
      name: 'Theme colors',
      iconType: NotebookIconType.general,
      colorValue: colorValue,
      sections: [
        NoteSection(id: 'theme-section', name: 'General', createdAt: now),
      ],
      notes: const [],
      createdAt: now,
      updatedAt: now,
    );
    final tileFinder = find.byKey(
      const ValueKey('notebook-card-theme-notebook'),
    );

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          home: NotesScreen(initialNotebooks: [notebook]),
        ),
      );
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(tileFinder));
      final tile = tester.widget<NotebookListTile>(tileFinder);
      final materialFinder = find
          .descendant(of: tileFinder, matching: find.byType(Material))
          .first;
      expect(
        tester.widget<Material>(materialFinder).color,
        notebookSurfaceColor(theme, colorValue),
      );
      expect(notebookSurfaceColor(theme, colorValue).a, 1);
      expect(notebookAccentColor(theme, colorValue).a, 1);
      expect(tile.notebook.colorValue, colorValue);
      for (final paletteColor in NotebookBaseColor.values) {
        expect(
          _contrastRatio(
            notebookSurfaceColor(theme, paletteColor.value),
            notebookAccentColor(theme, paletteColor.value),
          ),
          greaterThanOrEqualTo(4.5),
          reason:
              '${paletteColor.label} notebook text should be readable in '
              '${theme.brightness.name} mode.',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('starts with a real empty workspace instead of demo notes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(
      find.text('No recent notes yet. Open a notebook and start writing.'),
      findsOneWidget,
    );
    expect(find.text('Notebooks'), findsOneWidget);
    expect(find.byType(NotebookListTile), findsNothing);
    expect(find.text('Plans & Goals'), findsNothing);
    expect(find.text('Weekly Review'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'smarana_note_workspace_v1',
      ),
      isNull,
    );
  });

  testWidgets('home displays multicolor notes across theme modes and sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    final createdAt = DateTime(2026, 10, 1);
    final colors = NoteCardColor.values
        .where((color) => color != NoteCardColor.standard)
        .toList();
    final notebook = Notebook(
      id: 'palette-notebook',
      name: 'Colorful notes',
      iconType: NotebookIconType.ideas,
      sections: [
        NoteSection(id: 'palette-section', name: 'Ideas', createdAt: createdAt),
      ],
      notes: [
        for (final color in colors)
          NoteEntry(
            id: 'note-${color.name}',
            notebookId: 'palette-notebook',
            sectionId: 'palette-section',
            title: 'Palette ${color.name}',
            content: 'A note using the ${color.name} color.',
            color: color,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt,
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
          home: NotesScreen(initialNotebooks: [notebook]),
        ),
      );
      await tester.pumpAndSettle();

      final expectedBrightness = mode == ThemeMode.system
          ? systemBrightness
          : mode == ThemeMode.dark
          ? Brightness.dark
          : Brightness.light;
      expect(find.byKey(const ValueKey('notes-search-button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notes-workspace-search')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('notes-search-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notes-workspace-search')),
        findsOneWidget,
      );
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('notes-workspace-search'))),
        ).brightness,
        expectedBrightness,
      );
      await tester.tap(find.byKey(const ValueKey('notes-search-button')));
      await tester.pumpAndSettle();

      final finalColorNote = find.text('Palette lavender');
      await tester.ensureVisible(finalColorNote);
      expect(finalColorNote, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('opens notebook and manages sections with notes', (tester) async {
    final notebook = Notebook(
      id: 'book-1',
      name: 'Engineering',
      iconType: NotebookIconType.work,
      sections: [
        NoteSection(
          id: 'sec-roadmap',
          name: 'Roadmap',
          createdAt: DateTime(2026, 9, 1),
        ),
        NoteSection(
          id: 'sec-retro',
          name: 'Retrospective',
          createdAt: DateTime(2026, 9, 2),
        ),
      ],
      notes: [
        NoteEntry(
          id: 'note-1',
          notebookId: 'book-1',
          sectionId: 'sec-retro',
          title: 'Sprint Review',
          content: 'Document lessons learned.',
          createdAt: DateTime(2026, 9, 15),
          updatedAt: DateTime(2026, 9, 15, 10),
        ),
      ],
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 15),
    );

    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
    );

    await tester.tap(find.text('Sprint Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-editor-back')));
    await tester.pumpAndSettle();

    expect(find.text('Roadmap'), findsNWidgets(2));
    expect(find.text('Retrospective'), findsOneWidget);
    expect(find.text('No notes in this section yet'), findsOneWidget);

    await tester.tap(find.text('Retrospective'));
    await tester.pumpAndSettle();
    expect(find.text('Sprint Review'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notebook-add-section')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ideas');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Ideas'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('section-actions-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename section'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Concepts');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Concepts'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('section-new-note-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rich-note-title-field')),
      'Draft launch brief',
    );
    await tester.tap(find.byKey(const ValueKey('note-editor-back')));
    await tester.pumpAndSettle();

    expect(find.text('Draft launch brief'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('section-actions-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete section'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Concepts'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('notebook-save-and-close')));
    await tester.pumpAndSettle();
    expect(find.text('Engineering'), findsNWidgets(2));
  });

  testWidgets('search filters recent notes while retaining notebook cards', (
    tester,
  ) async {
    final notebooks = [
      Notebook(
        id: 'notebook-workout',
        name: 'Health & Fitness',
        iconType: NotebookIconType.health,
        sections: [
          NoteSection(
            id: 'section-workouts',
            name: 'Workouts',
            createdAt: DateTime(2026, 9, 4, 7),
          ),
        ],
        notes: [
          NoteEntry(
            id: 'note-workout',
            notebookId: 'notebook-workout',
            sectionId: 'section-workouts',
            title: 'Workout Split',
            content: 'Upper body, lower body, mobility, and recovery notes.',
            createdAt: DateTime(2026, 9, 29, 6, 30),
            updatedAt: DateTime(2026, 9, 29, 7, 5),
          ),
        ],
        createdAt: DateTime(2026, 8, 1, 9),
        updatedAt: DateTime(2026, 9, 29, 7, 5),
      ),
      Notebook(
        id: 'notebook-plans',
        name: 'Plans & Goals',
        iconType: NotebookIconType.goals,
        sections: [
          NoteSection(
            id: 'section-focus',
            name: 'Focus',
            createdAt: DateTime(2026, 9, 1, 8),
          ),
        ],
        notes: const [],
        createdAt: DateTime(2026, 8, 1, 9),
        updatedAt: DateTime(2026, 9, 1, 8),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: notebooks)),
    );

    expect(find.text('Notebooks'), findsOneWidget);
    expect(find.text('Plans & Goals'), findsOneWidget);
    expect(find.text('Workout Split'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notes-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('notes-workspace-search')),
      'workout',
    );
    await tester.pump();

    expect(find.text('Health & Fitness'), findsNWidgets(2));
    expect(find.text('Workout Split'), findsOneWidget);
    expect(find.text('Plans & Goals'), findsOneWidget);
  });

  testWidgets('pins and unpins a note from the recent notes menu', (
    tester,
  ) async {
    final notebook = Notebook(
      id: 'book-pins',
      name: 'Ideas',
      iconType: NotebookIconType.ideas,
      sections: [
        NoteSection(
          id: 'section-pins',
          name: 'Campaigns',
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
      notes: [
        NoteEntry(
          id: 'note-pin-target',
          notebookId: 'book-pins',
          sectionId: 'section-pins',
          title: 'Launch ideas',
          content: 'Collect the strongest campaign concepts.',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 2),
        ),
      ],
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 2),
    );

    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
    );

    await tester.tap(find.byTooltip('Note actions for Launch ideas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin note'));
    await tester.pumpAndSettle();

    expect(find.text('Pinned'), findsNothing);
    expect(find.text('Launch ideas'), findsOneWidget);

    await tester.tap(find.byTooltip('Note actions for Launch ideas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin note'));
    await tester.pumpAndSettle();

    expect(find.text('Pinned'), findsNothing);
    expect(find.text('Launch ideas'), findsOneWidget);

    await tester.tap(find.text('Launch ideas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rich-note-title-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('See all opens every note with the requested card styling', (
    tester,
  ) async {
    final now = DateTime.now();
    final notebook = Notebook(
      id: 'all-notes-notebook',
      name: 'Planning Notebook',
      iconType: NotebookIconType.general,
      sections: [
        NoteSection(id: 'all-notes-section', name: 'Plans', createdAt: now),
      ],
      notes: [
        for (var index = 0; index < 9; index++)
          NoteEntry(
            id: 'recent-note-$index',
            notebookId: 'all-notes-notebook',
            sectionId: 'all-notes-section',
            title: 'Recent planning note $index',
            content: 'A recent note for the home page.',
            createdAt: now.subtract(Duration(hours: index + 1)),
            updatedAt: now.subtract(Duration(hours: index + 1)),
          ),
        NoteEntry(
          id: 'older-note',
          notebookId: 'all-notes-notebook',
          sectionId: 'all-notes-section',
          title: 'Older planning note',
          content: 'This older note is still part of all notes.',
          createdAt: now.subtract(const Duration(days: 60)),
          updatedAt: now.subtract(const Duration(days: 45)),
        ),
      ],
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent Notes'), findsOneWidget);
    expect(find.text('Older planning note'), findsNothing);
    final seeAllButton = find.byKey(const ValueKey('notes-see-all-button'));
    await tester.ensureVisible(seeAllButton);
    await tester.tap(seeAllButton);
    await tester.pumpAndSettle();

    expect(find.text('All Notes'), findsOneWidget);
    final olderNoteCard = find.byKey(
      const ValueKey('recent-note-card-older-note'),
    );
    await tester.scrollUntilVisible(
      olderNoteCard,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    final titleFinder = find.descendant(
      of: olderNoteCard,
      matching: find.text('Older planning note'),
    );
    final title = tester.widget<Text>(titleFinder);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(title.style?.decoration, isNot(TextDecoration.underline));

    final notebookName = tester.widget<Text>(
      find.descendant(
        of: olderNoteCard,
        matching: find.text('Planning Notebook'),
      ),
    );
    expect(
      find.descendant(
        of: olderNoteCard,
        matching: find.byKey(const ValueKey('recent-note-notebook-older-note')),
      ),
      findsOneWidget,
    );
    expect(notebookName.style?.decoration, isNot(TextDecoration.underline));

    await tester.tap(find.byTooltip('Note actions for Older planning note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Note actions for Older planning note'));
    await tester.pumpAndSettle();
    expect(find.text('Unpin note'), findsOneWidget);
    await tester.tap(find.text('Unpin note'));
    await tester.pumpAndSettle();

    await tester.tap(titleFinder);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rich-note-title-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'orders note cards by pin, recent update, reminder, then others',
    (tester) async {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'sort-reminder',
        title: 'Follow up',
        dateTime: now.add(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 60)),
      );
      SharedPreferences.setMockInitialValues({
        'reminders': jsonEncode([reminder.toJson()]),
      });

      final notebook = Notebook(
        id: 'sorting-notebook',
        name: 'Planning',
        iconType: NotebookIconType.general,
        sections: [
          NoteSection(
            id: 'sorting-section',
            name: 'General',
            createdAt: now.subtract(const Duration(days: 90)),
          ),
        ],
        notes: [
          NoteEntry(
            id: 'pinned-note',
            notebookId: 'sorting-notebook',
            sectionId: 'sorting-section',
            title: 'Pinned note',
            content: 'Pinned',
            isPinned: true,
            createdAt: now.subtract(const Duration(days: 90)),
            updatedAt: now.subtract(const Duration(days: 60)),
          ),
          NoteEntry(
            id: 'updated-note',
            notebookId: 'sorting-notebook',
            sectionId: 'sorting-section',
            title: 'Recently updated',
            content: 'Updated',
            createdAt: now.subtract(const Duration(days: 90)),
            updatedAt: now.subtract(const Duration(days: 1)),
          ),
          NoteEntry(
            id: 'reminder-note',
            notebookId: 'sorting-notebook',
            sectionId: 'sorting-section',
            title: 'Reminder note',
            content: 'Reminder',
            reminderId: reminder.id,
            createdAt: now.subtract(const Duration(days: 90)),
            updatedAt: now.subtract(const Duration(days: 60)),
          ),
          NoteEntry(
            id: 'other-note',
            notebookId: 'sorting-notebook',
            sectionId: 'sorting-section',
            title: 'Other note',
            content: 'Other',
            createdAt: now.subtract(const Duration(days: 90)),
            updatedAt: now.subtract(const Duration(days: 60)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
      );
      await tester.pumpAndSettle();

      final titles = tester
          .widgetList<RecentNoteCard>(find.byType(RecentNoteCard))
          .map((card) => card.note.note.title)
          .toList();
      expect(titles, [
        'Pinned note',
        'Recently updated',
        'Reminder note',
        'Other note',
      ]);
    },
  );

  testWidgets('updates note card color from its home card menu', (
    tester,
  ) async {
    final now = DateTime.now();
    final notebook = Notebook(
      id: 'color-notebook',
      name: 'Color tests',
      iconType: NotebookIconType.ideas,
      sections: [
        NoteSection(id: 'color-section', name: 'Ideas', createdAt: now),
      ],
      notes: [
        NoteEntry(
          id: 'color-note',
          notebookId: 'color-notebook',
          sectionId: 'color-section',
          title: 'Color target',
          content: 'Change this note color.',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Note actions for Color target'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change color'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-color-blue')));
    await tester.pumpAndSettle();

    final card = tester.widget<RecentNoteCard>(find.byType(RecentNoteCard));
    expect(card.note.note.color, NoteCardColor.blue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add note button opens the existing rich note editor', (
    tester,
  ) async {
    final notebook = Notebook(
      id: 'book-create',
      name: 'Quick Ideas',
      iconType: NotebookIconType.ideas,
      sections: [
        NoteSection(
          id: 'section-create',
          name: 'Campaigns',
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
      notes: const [],
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
    );

    await tester.tap(find.byKey(const ValueKey('notes-add-note-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rich-note-title-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('rich-note-title-field')),
      'Campaign draft',
    );
    await tester.tap(find.byKey(const ValueKey('note-editor-back')));
    await tester.pumpAndSettle();

    expect(find.text('Campaign draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches between notebook views and updates kanban status', (
    tester,
  ) async {
    final notebook = Notebook(
      id: 'book-kanban',
      name: 'Project Board',
      iconType: NotebookIconType.work,
      sections: [
        NoteSection(
          id: 'sec-main',
          name: 'Main',
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
      notes: [
        NoteEntry(
          id: 'note-kanban',
          notebookId: 'book-kanban',
          sectionId: 'sec-main',
          title: 'Task A',
          content: 'Initial task',
          projectMetadata: NoteProjectMetadata(status: NoteProjectStatus.toDo),
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2, 8),
        ),
      ],
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 2, 8),
    );

    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(initialNotebooks: [notebook])),
    );

    await tester.tap(find.text('Task A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-editor-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to In Progress'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('list-note-note-kanban')),
        matching: find.textContaining('In Progress'),
      ),
      findsNWidgets(2),
    );

    await tester.tap(find.text('Kanban'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('kanban-column-inProgress')),
      findsOneWidget,
    );
    expect(find.text('Task A'), findsOneWidget);
  });
}

double _contrastRatio(Color first, Color second) {
  final luminance = [first.computeLuminance(), second.computeLuminance()]
    ..sort((a, b) => b.compareTo(a));
  return (luminance.first + 0.05) / (luminance.last + 0.05);
}
