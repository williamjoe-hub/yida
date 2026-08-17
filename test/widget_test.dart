import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dressfit_app/home_page.dart';
import 'package:dressfit_app/onboarding_page.dart';
import 'package:dressfit_app/profile_settings.dart';
import 'package:dressfit_app/settings_page.dart';

void main() {
  testWidgets('first launch asks for the real display name', (tester) async {
    OnboardingResult? result;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingPage(onComplete: (value) => result = value)),
    );
    await tester.pumpAndSettle();
    expect(find.text('每天少想一点'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('衣服真正属于你'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '小林');
    await tester.tap(find.text('开始使用'));
    await tester.pump();
    expect(result?.displayName, '小林');
    expect(result?.gender, UserGender.male);
  });

  testWidgets('opens on daily recommendation and enters fitting room', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(gender: UserGender.male, displayName: '小林'),
      ),
    );
    await tester.pump();
    expect(find.textContaining(RegExp(r'^(早上|中午|下午|晚上)好，小林$')), findsOneWidget);
    expect(find.text('今日推荐'), findsWidgets);
    await tester.tap(find.text('搭配'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('试衣间'), findsOneWidget);
    expect(find.text('鞋子'), findsOneWidget);
  });

  testWidgets('editing the display name closes without a controller crash', (
    tester,
  ) async {
    String? updatedName;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            gender: UserGender.male,
            displayName: '小林',
            onGenderChanged: (_) {},
            onDisplayNameChanged: (value) => updatedName = value,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('小林'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '小王');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(updatedName, '小王');
    expect(tester.takeException(), isNull);
  });
}
