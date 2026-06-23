import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/screens/app_shell.dart';
import 'package:skinmatch/services/care_plan_service.dart';
import 'package:skinmatch/services/user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('app shell shows bottom navigation on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userService = await _createReadyUserService();

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);

    expect(find.byKey(const Key('shell_nav_mobile')), findsOneWidget);
    expect(find.byKey(const Key('shell_nav_desktop')), findsNothing);
    expect(find.text('SkinMatch'), findsOneWidget);
    expect(scaffold.bottomNavigationBar, isNotNull);
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_nav_mobile'))).dy,
      greaterThan(600),
    );

    await tester.tap(find.byKey(const Key('shell_nav_3')));
    await tester.pumpAndSettle();

    expect(find.text('alina@example.com'), findsOneWidget);
  });

  testWidgets('app shell keeps top navigation on wide layout', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userService = await _createReadyUserService();

    await tester.pumpWidget(_buildTestApp(userService));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);

    expect(find.byKey(const Key('shell_nav_desktop')), findsOneWidget);
    expect(find.byKey(const Key('shell_nav_mobile')), findsNothing);
    expect(scaffold.bottomNavigationBar, isNull);

    await tester.tap(find.byKey(const Key('shell_nav_3')));
    await tester.pumpAndSettle();

    expect(find.text('alina@example.com'), findsOneWidget);
  });
}

Widget _buildTestApp(UserService userService) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserService>.value(value: userService),
      Provider<CarePlanService>.value(
        value: CarePlanService(
          requestExecutor: (_) async => <String, dynamic>{
            'categories': <Map<String, dynamic>>[
              <String, dynamic>{
                'categoryCode': 'cleansing',
                'displayName': 'Очищение',
                'products': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'brand': 'CeraVe',
                    'productName': 'Hydrating Cleanser',
                    'url': 'https://example.com/1',
                  },
                ],
              },
            ],
          },
        ),
      ),
    ],
    child: const MaterialApp(home: AppShell()),
  );
}

Future<UserService> _createReadyUserService() async {
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
      lastSurveyCompletedAt: DateTime(2026, 5, 14, 9, 30),
    ),
  );
  return userService;
}
