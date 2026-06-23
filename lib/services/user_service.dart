import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'api_http_exception.dart';
import 'care_plan_transport.dart';

typedef AuthRequestExecutor =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, dynamic> payload,
    );

typedef AuthMeExecutor =
    Future<Map<String, dynamic>> Function(String accessToken);

typedef AuthProfileExecutor =
    Future<Map<String, dynamic>> Function(
      String accessToken,
      SkinProfile profile,
    );

class AuthException implements Exception {
  const AuthException([this.message = 'Authentication request failed']);

  final String message;

  @override
  String toString() => message;
}

class AuthNotConfiguredException extends AuthException {
  const AuthNotConfiguredException() : super('Auth API URL is not configured');
}

class UserNotFoundException extends AuthException {
  const UserNotFoundException() : super('Пользователь с таким email не найден');
}

class UserService extends ChangeNotifier {
  UserService({
    String? apiUrl,
    AuthRequestExecutor? authRequestExecutor,
    AuthMeExecutor? authMeExecutor,
    AuthProfileExecutor? authProfileExecutor,
  }) : _apiUrl = apiUrl ?? _defaultApiUrl,
       _authRequestExecutor = authRequestExecutor,
       _authMeExecutor = authMeExecutor,
       _authProfileExecutor = authProfileExecutor;

  static const String _userKey = 'user_data';
  static const String _authTokenKey = 'auth_token';
  static const String _defaultApiUrl = String.fromEnvironment(
    'CARE_PLAN_API_URL',
    defaultValue: '',
  );
  static const String _registerPath = '/api/v1/auth/register';
  static const String _loginPath = '/api/v1/auth/login';
  static const String _mePath = '/api/v1/auth/me';
  static const String _profilePath = '/api/v1/auth/profile';

  String _apiUrl;
  final AuthRequestExecutor? _authRequestExecutor;
  final AuthMeExecutor? _authMeExecutor;
  final AuthProfileExecutor? _authProfileExecutor;
  UserModel _user = UserModel();

  UserModel get user => _user;
  bool get isAuthenticated =>
      _user.isRegistered && (_user.authToken?.isNotEmpty ?? false);
  String? get accessToken => _user.authToken;
  bool get hasCompletedSurvey => _user.hasCompletedSurvey;
  bool get hasActiveIntensiveCourse =>
      _user.activeIntensiveCourseProductId != null &&
      _user.intensiveCourseStartedAt != null;

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData == null) {
      return;
    }

    final authToken = prefs.getString(_authTokenKey);
    _user = UserModel.fromJson(
      Map<String, dynamic>.from(json.decode(userData) as Map),
    );
    if (authToken != null && authToken.isNotEmpty) {
      _user = _user.copyWith(authToken: authToken);
    }
    await _validateStoredSession();
    notifyListeners();
  }

  Future<void> saveUser(UserModel user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user.toJson()));
    final token = user.authToken;
    if (token == null || token.isEmpty) {
      await prefs.remove(_authTokenKey);
    } else {
      await prefs.setString(_authTokenKey, token);
    }
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final response = await _requestAuth(_registerPath, <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    });
    await saveUser(
      _mergeAuthenticatedUser(
        response,
        fallbackName: name,
        fallbackEmail: email,
      ),
    );
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _requestAuth(_loginPath, <String, dynamic>{
        'email': email,
        'password': password,
      });
      await saveUser(_mergeAuthenticatedUser(response, fallbackEmail: email));
    } on ApiHttpException catch (e) {
      if (e.statusCode == 404) {
        throw const UserNotFoundException();
      }
      rethrow;
    }
  }

  Future<void> loadCurrentUser() async {
    final token = _user.authToken;
    if (token == null || token.isEmpty) {
      throw const AuthException('No access token is stored');
    }

    final response = await _requestMe(token);
    await saveUser(
      _user.copyWith(
        userId: _readOptionalInt(response['id']),
        name: (response['name'] ?? _user.name)?.toString(),
        email: (response['email'] ?? _user.email)?.toString(),
        hasCompletedSurvey: _readBool(
          response['hasCompletedSurvey'],
          fallback: _user.hasCompletedSurvey,
        ),
        skinProfile:
            _readSkinProfile(response['skinProfile']) ?? _user.skinProfile,
        isRegistered: true,
      ),
    );
  }

  void updateApiUrl(String apiUrl) {
    _apiUrl = apiUrl;
  }

  Future<void> completeSurvey(
    SkinProfile profile, {
    DateTime? completedAt,
  }) async {
    final surveyCompletedAt = completedAt ?? DateTime.now();
    final updatedHistory = [
      SurveyHistoryEntry(
        completedAt: surveyCompletedAt,
        profileSnapshot: profile,
      ),
      ..._user.surveyHistory,
    ];
    final updatedUser = _user.copyWith(
      hasCompletedSurvey: true,
      skinProfile: profile,
      lastSurveyCompletedAt: surveyCompletedAt,
      surveyHistory: updatedHistory,
      clearCarePlan: true,
      clearIntensiveCourse: true,
    );
    if (_shouldSyncProfile()) {
      await _requestProfile(profile);
    }
    await saveUser(updatedUser);
  }

  Future<void> saveCarePlan(CarePlan carePlan) async {
    final activeProductId = _user.activeIntensiveCourseProductId;
    final validProductIds = carePlan.intensiveProducts
        .map((product) => product.productId)
        .toSet();
    final sanitizedLog = <String, List<String>>{};
    if (activeProductId != null && validProductIds.contains(activeProductId)) {
      final activeLog = _user.intensiveApplicationLog[activeProductId];
      if (activeLog != null) {
        sanitizedLog[activeProductId] = List<String>.from(activeLog)..sort();
      }
    }

    final shouldResetCourse =
        activeProductId != null && !validProductIds.contains(activeProductId);

    final updatedUser = _user.copyWith(
      carePlan: carePlan,
      intensiveApplicationLog: sanitizedLog,
      clearIntensiveCourse: shouldResetCourse,
    );
    await saveUser(updatedUser);
  }

  Future<void> selectActiveIntensiveCourse(
    String productId, {
    DateTime? startedAt,
  }) async {
    if (!canStartIntensiveCourse(productId)) {
      return;
    }

    final existingDates = _user.intensiveApplicationLog[productId];
    final existingLog = <String, List<String>>{
      productId: List<String>.from(existingDates ?? const <String>[])..sort(),
    };
    final shouldReuseStartDate =
        _user.activeIntensiveCourseProductId == productId;

    final updatedUser = _user.copyWith(
      activeIntensiveCourseProductId: productId,
      intensiveCourseStartedAt:
          startedAt ??
          (shouldReuseStartDate ? _user.intensiveCourseStartedAt : null) ??
          DateTime.now(),
      intensiveApplicationLog: existingLog,
    );
    await saveUser(updatedUser);
  }

  Future<void> clearActiveIntensiveCourse() async {
    await saveUser(_user.copyWith(clearIntensiveCourse: true));
  }

  bool canStartIntensiveCourse(String productId) {
    final activeProductId = _user.activeIntensiveCourseProductId;
    return activeProductId == null || activeProductId == productId;
  }

  Future<void> toggleIntensiveApplication(
    String productId,
    DateTime date,
  ) async {
    if (_user.activeIntensiveCourseProductId != productId) {
      return;
    }

    final log = <String, List<String>>{
      productId: List<String>.from(
        _user.intensiveApplicationLog[productId] ?? const <String>[],
      ),
    };
    final dates = log.putIfAbsent(productId, () => <String>[]);
    final dayKey = formatCourseDayKey(date);
    if (dates.contains(dayKey)) {
      dates.remove(dayKey);
    } else {
      dates.add(dayKey);
      dates.sort();
    }

    final updatedUser = _user.copyWith(intensiveApplicationLog: log);
    await saveUser(updatedUser);
  }

  ProductRecommendation? getActiveIntensiveCourseProduct() {
    final productId = _user.activeIntensiveCourseProductId;
    if (productId == null) {
      return null;
    }
    return _user.carePlan?.findProductById(productId);
  }

  DateTime? getNextPlannedIntensiveDate() {
    final product = getActiveIntensiveCourseProduct();
    final startedAt = _user.intensiveCourseStartedAt;
    final guidance = product?.usageGuidance;
    if (product == null || startedAt == null || guidance == null) {
      return null;
    }

    final today = normalizeCourseDate(DateTime.now());
    for (var offset = 0; offset < 60; offset++) {
      final candidate = today.add(Duration(days: offset));
      if (guidance.isPlannedDate(courseStartedAt: startedAt, date: candidate)) {
        return candidate;
      }
    }

    return null;
  }

  Future<void> logout() async {
    _user = UserModel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_authTokenKey);
    notifyListeners();
  }

  Future<void> _clearStoredSession({bool notify = true}) async {
    _user = UserModel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_authTokenKey);
    if (notify) {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _requestAuth(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final executor = _authRequestExecutor;
    if (executor != null) {
      return executor(path, payload);
    }

    final uri = _resolveApiUri(path);
    return requestJson('POST', uri, payload: payload);
  }

  Future<Map<String, dynamic>> _requestMe(String token) async {
    final executor = _authMeExecutor;
    if (executor != null) {
      return executor(token);
    }

    final uri = _resolveApiUri(_mePath);
    return getJson(
      uri,
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> _requestProfile(SkinProfile profile) async {
    final token = _user.authToken;
    if (token == null || token.isEmpty) {
      throw const AuthException('No access token is stored');
    }

    final executor = _authProfileExecutor;
    if (executor != null) {
      return executor(token, profile);
    }

    final uri = _resolveApiUri(_profilePath);
    return requestJson(
      'POST',
      uri,
      payload: profile.toJson(),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
  }

  Future<void> _validateStoredSession() async {
    final token = _user.authToken;
    if (token == null || token.isEmpty) {
      return;
    }

    if (_authMeExecutor == null && _apiUrl.trim().isEmpty) {
      await _clearStoredSession(notify: false);
      return;
    }

    try {
      final response = await _requestMe(token);
      _user = _mergeUserData(response).copyWith(authToken: token);
    } catch (_) {
      await _clearStoredSession(notify: false);
    }
  }

  bool _shouldSyncProfile() {
    final token = _user.authToken;
    if (token == null || token.isEmpty) {
      return false;
    }

    return _authProfileExecutor != null || _apiUrl.trim().isNotEmpty;
  }

  Uri _resolveApiUri(String path) {
    final trimmedApiUrl = _apiUrl.trim();
    if (trimmedApiUrl.isEmpty) {
      throw const AuthNotConfiguredException();
    }

    final parsedUri = Uri.parse(trimmedApiUrl);
    final normalizedPath = parsedUri.path.endsWith('/')
        ? parsedUri.path.substring(0, parsedUri.path.length - 1)
        : parsedUri.path;

    if (normalizedPath.endsWith(path)) {
      return parsedUri.replace(path: normalizedPath);
    }

    final nextPath = normalizedPath.isEmpty ? path : '$normalizedPath$path';
    return parsedUri.replace(path: nextPath);
  }

  UserModel _mergeAuthenticatedUser(
    Map<String, dynamic> response, {
    String? fallbackName,
    String? fallbackEmail,
  }) {
    final token = (response['accessToken'] ?? response['access_token'] ?? '')
        .toString();
    if (token.isEmpty) {
      throw const AuthException(
        'Auth response does not contain an access token',
      );
    }

    final rawUser = response['user'];
    final userData = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : const <String, dynamic>{};

    return _mergeUserData(
      userData,
      fallbackName: fallbackName,
      fallbackEmail: fallbackEmail,
    ).copyWith(authToken: token, isRegistered: true);
  }

  UserModel _mergeUserData(
    Map<String, dynamic> userData, {
    String? fallbackName,
    String? fallbackEmail,
  }) {
    return _user.copyWith(
      userId: _readOptionalInt(userData['id']),
      name: (userData['name'] ?? fallbackName ?? _user.name)?.toString(),
      email: (userData['email'] ?? fallbackEmail ?? _user.email)?.toString(),
      hasCompletedSurvey: _readBool(
        userData['hasCompletedSurvey'],
        fallback: _user.hasCompletedSurvey,
      ),
      skinProfile:
          _readSkinProfile(userData['skinProfile']) ?? _user.skinProfile,
      isRegistered: true,
    );
  }
}

int? _readOptionalInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

bool _readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }

  if (value is String) {
    return value.toLowerCase() == 'true';
  }

  return fallback;
}

SkinProfile? _readSkinProfile(Object? value) {
  if (value is! Map) {
    return null;
  }

  return SkinProfile.fromJson(Map<String, dynamic>.from(value));
}
