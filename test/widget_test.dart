import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dear_diary/main.dart';
import 'package:dear_diary/auth/dev_auth.dart';

void main() {
  testWidgets('PIN gate is visible on the first app frame', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DearDiaryApp());

    expect(find.text('Enter your PIN'), findsOneWidget);
  });

  testWidgets('normal PIN opens diary and invalid PIN stays locked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DearDiaryApp());
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('2'));
      await tester.pump();
    }
    expect(find.text('Please try again'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('0'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  });
  testWidgets('backgrounding closes settings and requires PIN', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DearDiaryApp());
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('0'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Dear Diary'));
      await tester.pump();
    }
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
  testWidgets(
    'conversation PIN requires account access while diary stays separate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const DearDiaryApp());
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text('1'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.textContaining('Supabase'), findsNothing);
      if (DevAuth.usernameOnly) {
        expect(
          find.text('Sign in with your username and password.'),
          findsOneWidget,
        );
      }
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
    },
  );
}
