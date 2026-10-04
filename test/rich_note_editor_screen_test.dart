import 'package:app_smarana/features/notes/models/note_workspace_models.dart';
import 'package:app_smarana/features/notes/screens/rich_note_editor_screen.dart';
import 'package:flutter/material.dart';
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

    expect(find.text('Set Date & Time'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Alert sound'), findsOneWidget);
    expect(find.text('Project Mode'), findsOneWidget);
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

    expect(find.text('Note colors'), findsOneWidget);
    await tester.tap(find.byTooltip('Pink'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-editor-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note color'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Pink note color, selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
