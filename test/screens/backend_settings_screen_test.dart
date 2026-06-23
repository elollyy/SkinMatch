import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/screens/backend_settings_screen.dart';
import 'package:skinmatch/services/backend_config_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('backend settings screen validates and saves URL', (
    tester,
  ) async {
    final backendConfig = BackendConfigService();
    await backendConfig.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<BackendConfigService>.value(
        value: backendConfig,
        child: const MaterialApp(home: BackendSettingsScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('backend_url_field')),
      '127.0.0.1:8000',
    );
    await tester.tap(find.byKey(const Key('backend_save_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Введите полный URL, например http://127.0.0.1:8000'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('backend_url_field')),
      'http://127.0.0.1:8000',
    );
    await tester.tap(find.byKey(const Key('backend_save_button')));
    await tester.pumpAndSettle();

    expect(backendConfig.apiUrl, 'http://127.0.0.1:8000');
    expect(find.text('Адрес backend сохранён'), findsOneWidget);
    expect(
      find.text('Сейчас используется: http://127.0.0.1:8000'),
      findsOneWidget,
    );
  });
}
