import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/services/backend_config_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('loads and saves backend URL in shared preferences', () async {
    final service = BackendConfigService();
    await service.load();

    expect(service.apiUrl, isEmpty);
    expect(service.isConfigured, isFalse);

    await service.saveApiUrl('http://127.0.0.1:8000');

    expect(service.apiUrl, 'http://127.0.0.1:8000');
    expect(service.isConfigured, isTrue);

    final reloadedService = BackendConfigService();
    await reloadedService.load();

    expect(reloadedService.apiUrl, 'http://127.0.0.1:8000');
    expect(reloadedService.isConfigured, isTrue);
  });

  test('clears saved backend URL', () async {
    final service = BackendConfigService();
    await service.load();
    await service.saveApiUrl('http://127.0.0.1:8000');

    await service.saveApiUrl('');

    expect(service.apiUrl, isEmpty);
    expect(service.isConfigured, isFalse);
  });

  test('uses local backend URL by default on linux in debug', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final service = BackendConfigService();
    await service.load();

    expect(service.apiUrl, 'http://127.0.0.1:8000');
    expect(service.isConfigured, isTrue);
  });
}
