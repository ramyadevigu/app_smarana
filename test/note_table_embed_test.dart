import 'package:app_smarana/features/notes/models/note_workspace_models.dart';
import 'package:app_smarana/features/notes/screens/rich_note_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits table cells and adds rows and columns', (tester) async {
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

    await tester.tap(find.byTooltip('Insert table'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add row'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(5));

    await tester.enterText(find.byType(TextField).at(1), 'Updated header');
    await tester.tap(find.byTooltip('Add row'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(7));

    await tester.tap(find.byTooltip('Add column'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(10));
    expect(find.text('Updated header'), findsOneWidget);
  });
}