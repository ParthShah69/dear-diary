import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dear_diary/main.dart';

void main() {
  testWidgets('normal PIN opens diary and invalid PIN stays locked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DearDiaryApp());
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) { await tester.tap(find.text('2')); await tester.pump(); }
    expect(find.text('Please try again'), findsOneWidget);
    for (var i = 0; i < 6; i++) { await tester.tap(find.text('0')); await tester.pump(); }
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  });
  testWidgets('backgrounding closes settings and requires PIN', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DearDiaryApp());
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) { await tester.tap(find.text('0')); await tester.pump(); }
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) { await tester.tap(find.text('Dear Diary')); await tester.pump(); }
    await tester.pumpAndSettle();
    expect(find.text('PIN settings'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('PIN settings'), findsNothing);
    expect(find.text('Enter your PIN'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('private PIN opens preview and instant lock returns to diary', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DearDiaryApp());
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) { await tester.tap(find.text('1')); await tester.pump(); }
    await tester.pumpAndSettle();
    expect(find.text('LOCAL PREVIEW'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Write a message…'), 'Draft stays');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Instant lock'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) { await tester.tap(find.text('1')); await tester.pump(); }
    await tester.pumpAndSettle();
    expect(find.text('Draft stays'), findsOneWidget);
  });
}







