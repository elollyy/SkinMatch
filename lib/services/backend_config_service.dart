import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackendConfigService extends ChangeNotifier {
  static const String _apiUrlKey = 'care_plan_api_url';
  static const String _defaultApiUrl = String.fromEnvironment(
    'CARE_PLAN_API_URL',
    defaultValue: '',
  );

  String _apiUrl = '';

  String get apiUrl => _apiUrl;
  bool get isConfigured => _apiUrl.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApiUrl = prefs.getString(_apiUrlKey)?.trim();
    _apiUrl = (savedApiUrl?.isNotEmpty ?? false)
        ? savedApiUrl!
        : _resolveDefaultApiUrl();
    notifyListeners();
  }

  Future<void> saveApiUrl(String value) async {
    final normalizedValue = value.trim();
    final prefs = await SharedPreferences.getInstance();

    if (normalizedValue.isEmpty) {
      await prefs.remove(_apiUrlKey);
      _apiUrl = _resolveDefaultApiUrl();
    } else {
      await prefs.setString(_apiUrlKey, normalizedValue);
      _apiUrl = normalizedValue;
    }

    notifyListeners();
  }

  String _resolveDefaultApiUrl() {
    final compileTimeApiUrl = _defaultApiUrl.trim();
    if (compileTimeApiUrl.isNotEmpty) {
      return compileTimeApiUrl;
    }

    // Keep release builds explicit, but make local Linux development zero-config.
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000';
    }

    return '';
  }
}
