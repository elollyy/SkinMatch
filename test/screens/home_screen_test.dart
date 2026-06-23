import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/screens/home_screen.dart';
import 'package:skinmatch/services/user_service.dart';
import 'package:skinmatch/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home screen renders greeting for user', (tester) async {
    final userService = await _createUserService();

    await tester.pumpWidget(_buildTestApp(userService));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            <String>[
              'Доброе утро',
              'Добрый день',
              'Добрый вечер',
            ].contains(widget.data),
      ),
      findsOneWidget,
    );
    expect(find.text('Алина'), findsOneWidget);
    expect(find.text('ВАШ СТАТУС'), findsOneWidget);
  });

  testWidgets('home screen results button opens care route', (tester) async {
    final userService = await _createUserService();

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.tap(find.byKey(const Key('home_view_results_button')));
    await tester.pumpAndSettle();

    expect(find.text('care route'), findsOneWidget);
  });

  testWidgets('home screen survey button opens survey route', (tester) async {
    final userService = await _createUserService();

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.tap(find.byKey(const Key('home_start_survey_button')));
    await tester.pumpAndSettle();

    expect(find.text('survey route'), findsOneWidget);
  });

  testWidgets('home screen history button opens history route', (tester) async {
    final userService = await _createUserService();

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.tap(find.byKey(const Key('home_history_button')));
    await tester.pumpAndSettle();

    expect(find.text('history route'), findsOneWidget);
  });

  testWidgets('home screen keeps status card and user name visible on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userService = await _createUserService();

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    expect(find.text('Алина'), findsOneWidget);
    expect(find.text('ВАШ СТАТУС'), findsOneWidget);
    expect(find.byKey(const Key('home_view_results_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen shows active intensive course shortcut', (
    tester,
  ) async {
    final userService = await _createUserService();
    await userService.saveCarePlan(
      CarePlan(
        categories: const <CareCategory>[
          CareCategory(
            categoryCode: 'intensive_renewal',
            displayName: 'Интенсивное обновление',
            products: <ProductRecommendation>[
              ProductRecommendation(
                productId: 'retino-brand-retinol-serum',
                brand: 'Retino Brand',
                productName: 'Retinol Serum',
                url: 'https://example.com/retinol',
                usageGuidance: UsageGuidance(
                  activeFamily: 'retinoid',
                  displayLabel: 'Ретиноид',
                  introductionScheme: IntroductionScheme(
                    cycleLengthDays: 7,
                    phases: <IntroductionPhase>[
                      IntroductionPhase(
                        weekStart: 1,
                        weekEnd: 2,
                        dayStart: 1,
                        dayEnd: 14,
                        allowedCycleDays: <int>[1, 4],
                        label: 'Недели 1-2',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
        isPartial: false,
        fetchedAt: DateTime(2026, 6, 1),
      ),
    );
    await userService.selectActiveIntensiveCourse(
      'retino-brand-retinol-serum',
      startedAt: DateTime.now(),
    );

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_intensive_course_card')), findsOneWidget);
    expect(
      find.byKey(const Key('home_toggle_today_course_day')),
      findsOneWidget,
    );
    expect(find.text('Retinol Serum'), findsOneWidget);
  });

  testWidgets('home screen active course shortcut opens course route', (
    tester,
  ) async {
    final userService = await _createUserService();
    await userService.saveCarePlan(
      CarePlan(
        categories: const <CareCategory>[
          CareCategory(
            categoryCode: 'intensive_renewal',
            displayName: 'Интенсивное обновление',
            products: <ProductRecommendation>[
              ProductRecommendation(
                productId: 'retino-brand-retinol-serum',
                brand: 'Retino Brand',
                productName: 'Retinol Serum',
                url: 'https://example.com/retinol',
              ),
            ],
          ),
        ],
        isPartial: false,
        fetchedAt: DateTime(2026, 6, 1),
      ),
    );
    await userService.selectActiveIntensiveCourse('retino-brand-retinol-serum');

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_intensive_course_card')));
    await tester.pumpAndSettle();

    expect(find.text('course route'), findsOneWidget);
  });

  testWidgets('home screen allows toggling today for active course', (
    tester,
  ) async {
    final userService = await _createUserService();
    final today = normalizeCourseDate(DateTime.now());
    await userService.saveCarePlan(
      CarePlan(
        categories: const <CareCategory>[
          CareCategory(
            categoryCode: 'intensive_renewal',
            displayName: 'Интенсивное обновление',
            products: <ProductRecommendation>[
              ProductRecommendation(
                productId: 'retino-brand-retinol-serum',
                brand: 'Retino Brand',
                productName: 'Retinol Serum',
                url: 'https://example.com/retinol',
                usageGuidance: UsageGuidance(
                  activeFamily: 'retinoid',
                  displayLabel: 'Ретиноид',
                  introductionScheme: IntroductionScheme(
                    cycleLengthDays: 7,
                    phases: <IntroductionPhase>[
                      IntroductionPhase(
                        weekStart: 1,
                        weekEnd: 2,
                        dayStart: 1,
                        dayEnd: 14,
                        allowedCycleDays: <int>[1, 4],
                        label: 'Недели 1-2',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
        isPartial: false,
        fetchedAt: DateTime(2026, 6, 1),
      ),
    );
    await userService.selectActiveIntensiveCourse(
      'retino-brand-retinol-serum',
      startedAt: today,
    );

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    final toggleFinder = find.byKey(const Key('home_toggle_today_course_day'));
    expect(toggleFinder, findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(
      userService.user.isIntensiveApplicationLogged(
        'retino-brand-retinol-serum',
        today,
      ),
      isTrue,
    );
    expect(find.text('Отмечено'), findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(
      userService.user.isIntensiveApplicationLogged(
        'retino-brand-retinol-serum',
        today,
      ),
      isFalse,
    );
  });
}

Widget _buildTestApp(UserService userService) {
  return ChangeNotifierProvider<UserService>.value(
    value: userService,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const HomeScreen(),
      routes: {
        '/care': (_) => const Scaffold(body: Center(child: Text('care route'))),
        '/course': (_) =>
            const Scaffold(body: Center(child: Text('course route'))),
        '/survey': (_) =>
            const Scaffold(body: Center(child: Text('survey route'))),
        '/history': (_) =>
            const Scaffold(body: Center(child: Text('history route'))),
      },
    ),
  );
}

Future<UserService> _createUserService() async {
  final userService = UserService();
  await userService.saveUser(
    UserModel(
      name: 'Алина Иванова',
      email: 'alina@example.com',
      isRegistered: true,
      hasCompletedSurvey: true,
      skinProfile: const SkinProfile(skinType: 'комбинированная', age: 29),
      lastSurveyCompletedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  );
  return userService;
}
