import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/screens/profile_screen.dart';
import 'package:skinmatch/services/user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('profile screen opens settings from action list', (tester) async {
    final userService = await _createUserService();

    await tester.pumpWidget(_buildTestApp(userService));

    expect(find.text('История анкет'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);

    await tester.ensureVisible(find.text('Настройки'));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    expect(find.text('settings route'), findsOneWidget);
  });
}

Widget _buildTestApp(UserService userService) {
  return ChangeNotifierProvider<UserService>.value(
    value: userService,
    child: MaterialApp(
      home: const ProfileScreen(),
      routes: {
        '/history': (_) =>
            const Scaffold(body: Center(child: Text('history route'))),
        '/settings': (_) =>
            const Scaffold(body: Center(child: Text('settings route'))),
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
