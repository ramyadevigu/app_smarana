import 'package:app_smarana/features/notes/models/note_workspace_models.dart';
import 'package:app_smarana/features/notes/notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('creates, renames, and deletes notebooks', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('notes-new-notebook-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Project Launch');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Project Launch'), findsOneWidget);

    await tester.ensureVisible(
      find.byTooltip('Notebook actions for Project Launch'),
    );
    await tester.tap(find.byTooltip('Notebook actions for Project Launch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Project X');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Project X'), findsOneWidget);

    await tester.ensureVisible(
      find.byTooltip('Notebook actions for Project X'),
    );
    await tester.tap(find.byTooltip('Notebook actions for Project X'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Project X'), findsNothing);
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

    await tester.tap(find.text('Engineering'));
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
    expect(find.text('Engineering'), findsOneWidget);
  });

  testWidgets('search filters notebook and recent note lists', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Plans & Goals'), findsOneWidget);
    expect(find.text('Weekly Review'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('notes-workspace-search')),
      'workout',
    );
    await tester.pump();

    expect(find.text('Health & Fitness'), findsOneWidget);
    expect(find.text('Workout Split'), findsOneWidget);
    expect(find.text('Plans & Goals'), findsNothing);
  });
}
