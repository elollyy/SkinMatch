import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/main.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/services/user_service.dart';
import 'package:skinmatch/services/theme_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('App loads welcome screen', (WidgetTester tester) async {
    final userService = UserService();
    final themeService = ThemeService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userService),
          ChangeNotifierProvider.value(value: themeService),
        ],
        child: const SkinMatchApp(),
      ),
    );

    await tester.pump();

    expect(find.text('SkinMatch'), findsOneWidget);
  });

  testWidgets('App shows welcome when authenticated user has no survey', (
    WidgetTester tester,
  ) async {
    final userService = UserService();
    await userService.saveUser(
      UserModel(
        name: 'Test User',
        email: 'test@example.com',
        isRegistered: true,
        authToken: 'valid-token',
        hasCompletedSurvey: false,
      ),
    );
    final themeService = ThemeService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userService),
          ChangeNotifierProvider.value(value: themeService),
        ],
        child: const SkinMatchApp(),
      ),
    );

    await tester.pump();

    expect(find.text('SkinMatch'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Создать аккаунт'), findsOneWidget);
    expect(find.text('Опрос'), findsNothing);
  });
}
