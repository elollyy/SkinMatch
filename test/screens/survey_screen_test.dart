import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/screens/survey_screen.dart';
import 'package:skinmatch/services/user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('survey requires a valid numeric age before continuing', (
    tester,
  ) async {
    final userService = UserService();

    await tester.pumpWidget(_buildTestApp(userService));

    await tester.tap(find.text('нормальная'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'далее'));
    await tester.pumpAndSettle();

    expect(find.text('Сколько вам лет?'), findsOneWidget);

    var nextButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'далее'),
    );
    expect(nextButton.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('survey_age_input')), '0');
    await tester.pump();

    nextButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'далее'),
    );
    expect(nextButton.onPressed, isNull);
    expect(find.text('Введите корректный возраст'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('survey_age_input')), '29');
    await tester.pump();

    nextButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'далее'),
    );
    expect(nextButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'далее'));
    await tester.pumpAndSettle();

    expect(find.text('Есть ли у вас аллергии?'), findsOneWidget);
  });

  testWidgets('survey shows updated options and saves numeric age', (
    tester,
  ) async {
    final userService = UserService();

    await tester.pumpWidget(_buildTestApp(userService));

    expect(find.text('проблемная кожа'), findsOneWidget);

    await tester.tap(find.text('проблемная кожа'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'далее'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('survey_age_input')), '31');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'далее'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('нет'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'далее'));
    await tester.pumpAndSettle();

    expect(find.text('бюджетный'), findsOneWidget);
    expect(find.text('средний'), findsOneWidget);
    expect(find.text('люкс'), findsOneWidget);
    expect(find.text('премиум'), findsNothing);

    await tester.tap(find.text('бюджетный'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'далее'));
    await tester.pumpAndSettle();

    expect(find.text('care route'), findsOneWidget);
    expect(userService.user.hasCompletedSurvey, isTrue);
    expect(userService.user.skinProfile?.skinType, 'проблемная кожа');
    expect(userService.user.skinProfile?.age, 31);
    expect(userService.user.skinProfile?.priceRange, 'бюджетный');
  });
}

Widget _buildTestApp(UserService userService) {
  return ChangeNotifierProvider<UserService>.value(
    value: userService,
    child: MaterialApp(
      home: const SurveyScreen(),
      routes: {
        '/care': (_) => const Scaffold(body: Center(child: Text('care route'))),
      },
    ),
  );
}
