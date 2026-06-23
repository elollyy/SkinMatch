import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/screens/history_screen.dart';
import 'package:skinmatch/services/user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('history screen shows empty state when there are no entries', (
    tester,
  ) async {
    final userService = await _createUserService();

    await tester.pumpWidget(_buildTestApp(userService));

    expect(find.byKey(const Key('history_empty_state')), findsOneWidget);
    expect(find.text('История пока пуста'), findsOneWidget);
    expect(
      find.byKey(const Key('history_start_survey_button')),
      findsOneWidget,
    );
  });

  testWidgets('history screen renders saved survey entries', (tester) async {
    final userService = await _createUserService(
      surveyHistory: [
        SurveyHistoryEntry(
          completedAt: DateTime(2026, 5, 14, 9, 30),
          profileSnapshot: SkinProfile(skinType: 'жирная', age: 31),
        ),
        SurveyHistoryEntry(
          completedAt: DateTime(2026, 5, 10, 18, 5),
          profileSnapshot: SkinProfile(skinType: 'сухая', age: 31),
        ),
      ],
    );

    await tester.pumpWidget(_buildTestApp(userService));

    expect(find.byKey(const Key('history_entry_0')), findsOneWidget);
    expect(find.byKey(const Key('history_entry_1')), findsOneWidget);
    expect(find.text('14 мая 2026, 09:30'), findsOneWidget);
    expect(find.text('10 мая 2026, 18:05'), findsOneWidget);
    expect(find.text('Тип кожи: жирная'), findsOneWidget);
    expect(find.text('Тип кожи: сухая'), findsOneWidget);
  });
}

Widget _buildTestApp(UserService userService) {
  return ChangeNotifierProvider<UserService>.value(
    value: userService,
    child: MaterialApp(
      home: const HistoryScreen(),
      routes: {
        '/survey': (_) =>
            const Scaffold(body: Center(child: Text('survey route'))),
      },
    ),
  );
}

Future<UserService> _createUserService({
  List<SurveyHistoryEntry> surveyHistory = const [],
}) async {
  final userService = UserService();
  await userService.saveUser(
    UserModel(
      name: 'Алина Иванова',
      email: 'alina@example.com',
      isRegistered: true,
      hasCompletedSurvey: true,
      skinProfile: const SkinProfile(skinType: 'комбинированная', age: 29),
      surveyHistory: surveyHistory,
      lastSurveyCompletedAt: surveyHistory.isEmpty
          ? null
          : surveyHistory.first.completedAt,
    ),
  );
  return userService;
}
