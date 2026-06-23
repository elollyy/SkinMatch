import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/screens/intensive_course_screen.dart';
import 'package:skinmatch/services/user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('course screen shows empty state without intensive renewal', (
    tester,
  ) async {
    final userService = await _createUserService();

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('course_empty_state')), findsOneWidget);
  });

  testWidgets(
    'course screen keeps single active course and shows alternatives as read-only',
    (tester) async {
      final userService = await _createUserService(
        carePlan: _buildIntensiveCarePlan(productCount: 2),
      );

      await tester.pumpWidget(_buildTestApp(userService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('course_selector')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('select_course_retino-brand-retinol-serum')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('course_product_card')), findsOneWidget);
      expect(find.byKey(const Key('course_information_card')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('course_product_card')),
          matching: find.text('Retinol Serum'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('course_reset_button')), findsOneWidget);
      expect(
        find.byKey(const Key('course_alternative_acid-brand-aha-peel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('course_switch_acid-brand-aha-peel')),
        findsNothing,
      );
    },
  );

  testWidgets('course reset clears active course and returns chooser', (
    tester,
  ) async {
    final userService = await _createUserService(
      carePlan: _buildIntensiveCarePlan(productCount: 2),
    );
    await userService.selectActiveIntensiveCourse(
      'retino-brand-retinol-serum',
      startedAt: DateTime(2026, 6, 4),
    );

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('course_reset_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('course_selector')), findsOneWidget);
    expect(userService.user.activeIntensiveCourseProductId, isNull);
  });

  testWidgets('course screen shows compact guidance summary and expands phases', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userService = await _createUserService(
      carePlan: _buildIntensiveCarePlan(productCount: 1),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final phaseTwoDate = today.add(const Duration(days: 14));
    await userService.selectActiveIntensiveCourse(
      'retino-brand-retinol-serum',
      startedAt: today,
    );

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    expect(find.text('Как вводить'), findsOneWidget);
    expect(find.byKey(const Key('course_information_card')), findsOneWidget);
    expect(find.byKey(const Key('course_guidance_summary')), findsOneWidget);
    expect(
      find.text('Сейчас: 2 вечера в неделю, дни 1 и 4 цикла.'),
      findsOneWidget,
    );
    expect(find.text('Недели 1-2'), findsNothing);

    if (phaseTwoDate.month != today.month) {
      await tester.tap(find.byKey(const Key('course_next_month')));
      await tester.pumpAndSettle();
    }

    final phaseTwoFinder = find.byKey(
      Key('course_day_${formatCourseDayKey(phaseTwoDate)}'),
    );
    await tester.ensureVisible(phaseTwoFinder);
    await tester.tap(phaseTwoFinder);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'На ${_formatTestDate(phaseTwoDate)}: 3 вечера в неделю, дни 1, 3 и 5 цикла.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('course_guidance_toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Недели 1-2'), findsOneWidget);
    expect(find.text('Недели 3-4'), findsOneWidget);
    expect(find.text('3 вечера в неделю, дни 1, 3 и 5 цикла'), findsOneWidget);
    expect(find.byKey(const Key('course_notes_card')), findsOneWidget);
    expect(find.text('С чем не сочетать'), findsOneWidget);
    expect(find.text('Кислоты и пилинги'), findsOneWidget);
    expect(find.text('Рекомендации по нанесению'), findsOneWidget);
    expect(find.text('Используйте вечером.'), findsOneWidget);
  });

  testWidgets('course calendar inline toggle marks and unmarks selected day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final userService = await _createUserService(
      carePlan: _buildIntensiveCarePlan(productCount: 1),
    );
    await userService.selectActiveIntensiveCourse(
      'retino-brand-retinol-serum',
      startedAt: today,
    );

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    final tomorrowFinder = find.byKey(
      Key('course_day_${formatCourseDayKey(tomorrow)}'),
    );
    await tester.ensureVisible(tomorrowFinder);
    await tester.tap(tomorrowFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('course_inline_toggle_selected_day')),
      findsOneWidget,
    );

    final inlineToggleFinder = find.byKey(
      const Key('course_inline_toggle_selected_day'),
    );
    await tester.ensureVisible(inlineToggleFinder);
    await tester.tap(inlineToggleFinder);
    await tester.pumpAndSettle();
    expect(
      userService.user.isIntensiveApplicationLogged(
        'retino-brand-retinol-serum',
        tomorrow,
      ),
      isTrue,
    );

    await tester.ensureVisible(inlineToggleFinder);
    await tester.tap(inlineToggleFinder);
    await tester.pumpAndSettle();
    expect(
      userService.user.isIntensiveApplicationLogged(
        'retino-brand-retinol-serum',
        tomorrow,
      ),
      isFalse,
    );
  });

  testWidgets('course calendar toggle persists after reload', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final userService = await _createUserService(
      carePlan: _buildIntensiveCarePlan(productCount: 1),
    );
    await userService.selectActiveIntensiveCourse(
      'retino-brand-retinol-serum',
      startedAt: today,
    );

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    final tomorrowFinder = find.byKey(
      Key('course_day_${formatCourseDayKey(tomorrow)}'),
    );
    await tester.ensureVisible(tomorrowFinder);
    await tester.tap(tomorrowFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('course_out_of_scheme_warning')),
      findsOneWidget,
    );

    final inlineToggleFinder = find.byKey(
      const Key('course_inline_toggle_selected_day'),
    );
    await tester.ensureVisible(inlineToggleFinder);
    await tester.tap(inlineToggleFinder);
    await tester.pumpAndSettle();

    final reloadedService = UserService();
    await reloadedService.loadUser();

    await tester.pumpWidget(_buildTestApp(reloadedService));
    await tester.pumpAndSettle();

    final reloadedTomorrowFinder = find.byKey(
      Key('course_day_${formatCourseDayKey(tomorrow)}'),
    );
    await tester.ensureVisible(reloadedTomorrowFinder);
    await tester.tap(reloadedTomorrowFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('course_inline_toggle_selected_day')),
      findsOneWidget,
    );
    expect(
      reloadedService.user.isIntensiveApplicationLogged(
        'retino-brand-retinol-serum',
        tomorrow,
      ),
      isTrue,
    );
  });

  testWidgets('course calendar stays compact and action is visible on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userService = await _createUserService(
      carePlan: _buildIntensiveCarePlan(productCount: 1),
    );
    await userService.selectActiveIntensiveCourse(
      'retino-brand-retinol-serum',
      startedAt: DateTime.now(),
    );

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    final calendarSize = tester.getSize(
      find.byKey(const Key('course_calendar')),
    );
    expect(calendarSize.height, lessThan(560));
    await tester.ensureVisible(find.byKey(const Key('course_calendar')));
    expect(
      find.byKey(const Key('course_inline_toggle_selected_day')),
      findsOneWidget,
    );
  });
}

Widget _buildTestApp(UserService userService) {
  return ChangeNotifierProvider<UserService>.value(
    value: userService,
    child: const MaterialApp(home: IntensiveCourseScreen()),
  );
}

Future<UserService> _createUserService({CarePlan? carePlan}) async {
  final userService = UserService();
  await userService.saveUser(
    UserModel(
      name: 'Алина Иванова',
      email: 'alina@example.com',
      isRegistered: true,
      hasCompletedSurvey: true,
      skinProfile: const SkinProfile(
        skinType: 'комбинированная',
        age: 29,
        allergies: <String>[],
        priceRange: 'средний',
      ),
      carePlan: carePlan,
      lastSurveyCompletedAt: DateTime(2026, 6, 1),
    ),
  );
  return userService;
}

CarePlan _buildIntensiveCarePlan({required int productCount}) {
  final products = <ProductRecommendation>[
    ProductRecommendation(
      productId: 'retino-brand-retinol-serum',
      brand: 'Retino Brand',
      productName: 'Retinol Serum',
      url: 'https://example.com/retinol',
      usageGuidance: _retinoidGuidance(),
    ),
    ProductRecommendation(
      productId: 'acid-brand-aha-peel',
      brand: 'Acid Brand',
      productName: 'AHA Peel',
      url: 'https://example.com/aha',
      usageGuidance: const UsageGuidance(
        activeFamily: 'acid',
        displayLabel: 'Кислотный курс',
        introductionScheme: IntroductionScheme(
          cycleLengthDays: 7,
          phases: <IntroductionPhase>[
            IntroductionPhase(
              weekStart: 1,
              weekEnd: 2,
              dayStart: 1,
              dayEnd: 14,
              allowedCycleDays: <int>[2, 5],
              label: 'Недели 1-2',
            ),
          ],
        ),
      ),
    ),
  ];

  return CarePlan(
    categories: <CareCategory>[
      CareCategory(
        categoryCode: 'intensive_renewal',
        displayName: 'Интенсивное обновление',
        products: products.take(productCount).toList(),
      ),
    ],
    isPartial: false,
    fetchedAt: DateTime(2026, 6, 1),
  );
}

UsageGuidance _retinoidGuidance() {
  return const UsageGuidance(
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
          note: 'Начинайте с двух вечеров в неделю.',
        ),
        IntroductionPhase(
          weekStart: 3,
          weekEnd: 4,
          dayStart: 15,
          dayEnd: 28,
          allowedCycleDays: <int>[1, 3, 5],
          label: 'Недели 3-4',
          note: 'Если кожа спокойна, можно добавить третий вечер.',
        ),
      ],
    ),
    conflicts: <CompatibilityConflict>[
      CompatibilityConflict(
        label: 'Кислоты и пилинги',
        explanation: 'Не сочетайте в один вечер.',
      ),
    ],
    applicationTips: <String>['Используйте вечером.'],
  );
}

String _formatTestDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
