import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dear_diary/diary/diary_page.dart';

void main() {
  testWidgets('diary entries can be edited, searched, deleted and restored', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DiaryPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New entry'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'Morning coffee by the window');
    await tester.pumpAndSettle();

    await tester.enterText(fields.last, 'coffee');
    await tester.pumpAndSettle();
    expect(find.text('Morning coffee by the window'), findsNWidgets(2));
    expect(find.textContaining('small moments of joy'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();
    expect(find.text('Diary entry deleted'), findsOneWidget);
    expect(find.text('No matching diary entries.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Morning coffee by the window'), findsNWidgets(2));
  });
}
