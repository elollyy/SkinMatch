import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/services/user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('register calls backend auth API and stores user token', () async {
    final requests = <String, Map<String, dynamic>>{};
    final userService = UserService(
      authRequestExecutor: (path, payload) async {
        requests[path] = payload;
        return <String, dynamic>{
          'accessToken': 'register-token',
          'tokenType': 'bearer',
          'user': <String, dynamic>{
            'id': 7,
            'name': 'Test User',
            'email': 'test@example.com',
          },
        };
      },
    );

    await userService.register('Test User', 'test@example.com', 'password123');

    expect(requests.keys.single, '/api/v1/auth/register');
    expect(requests['/api/v1/auth/register']!['password'], 'password123');
    expect(userService.user.userId, 7);
    expect(userService.user.authToken, 'register-token');
    expect(userService.user.isRegistered, isTrue);

    final reloadedService = UserService(
      authMeExecutor: (_) async => <String, dynamic>{
        'id': 7,
        'name': 'Test User',
        'email': 'test@example.com',
        'hasCompletedSurvey': false,
      },
    );
    await reloadedService.loadUser();

    expect(reloadedService.user.authToken, 'register-token');
    expect(reloadedService.user.email, 'test@example.com');
  });

  test(
    'login calls backend auth API and surfaces invalid credentials',
    () async {
      final userService = UserService(
        authRequestExecutor: (path, payload) async {
          expect(path, '/api/v1/auth/login');
          expect(payload['email'], 'test@example.com');
          throw const AuthException('Invalid email or password');
        },
      );

      expect(
        () => userService.login('test@example.com', 'bad-password'),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('login stores backend user and logout clears token', () async {
    final userService = UserService(
      authRequestExecutor: (path, payload) async {
        return <String, dynamic>{
          'accessToken': 'login-token',
          'user': <String, dynamic>{
            'id': 8,
            'name': 'Login User',
            'email': payload['email'],
          },
        };
      },
    );

    await userService.login('login@example.com', 'password123');

    expect(userService.user.authToken, 'login-token');
    expect(userService.user.email, 'login@example.com');

    await userService.logout();

    expect(userService.user.authToken, isNull);
    expect(userService.isAuthenticated, isFalse);

    final reloadedService = UserService();
    await reloadedService.loadUser();

    expect(reloadedService.user.authToken, isNull);
    expect(reloadedService.isAuthenticated, isFalse);
  });

  test('legacy local user without token is not authenticated', () async {
    final userService = UserService();

    await userService.saveUser(
      UserModel(
        name: 'Legacy User',
        email: 'legacy@example.com',
        isRegistered: true,
        hasCompletedSurvey: true,
      ),
    );

    expect(userService.user.isRegistered, isTrue);
    expect(userService.isAuthenticated, isFalse);
  });

  test('loadUser clears stored token when backend rejects session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_data':
          '{"name":"Stale User","email":"stale@example.com","isRegistered":true,"authToken":"stale-token"}',
      'auth_token': 'stale-token',
    });
    final userService = UserService(
      authMeExecutor: (_) async {
        throw const AuthException('Invalid token');
      },
    );

    await userService.loadUser();

    expect(userService.isAuthenticated, isFalse);
    expect(userService.user.authToken, isNull);
  });

  test('login restores completed survey profile from backend user', () async {
    final userService = UserService(
      authRequestExecutor: (path, payload) async {
        return <String, dynamic>{
          'accessToken': 'login-token',
          'user': <String, dynamic>{
            'id': 8,
            'name': 'Login User',
            'email': payload['email'],
            'hasCompletedSurvey': true,
            'skinProfile': <String, dynamic>{
              'skinType': 'комбинированная',
              'age': 31,
              'allergies': <String>['на спирт'],
              'priceRange': 'средний',
            },
          },
        };
      },
    );

    await userService.login('login@example.com', 'password123');

    expect(userService.hasCompletedSurvey, isTrue);
    expect(userService.user.skinProfile?.skinType, 'комбинированная');
    expect(userService.user.skinProfile?.age, 31);
  });

  test(
    'completeSurvey syncs profile to backend when token is available',
    () async {
      String? syncedToken;
      SkinProfile? syncedProfile;
      final userService = UserService(
        authProfileExecutor: (token, profile) async {
          syncedToken = token;
          syncedProfile = profile;
          return <String, dynamic>{
            'id': 7,
            'name': 'Test User',
            'email': 'test@example.com',
            'hasCompletedSurvey': true,
            'skinProfile': profile.toJson(),
          };
        },
      );
      await userService.saveUser(
        UserModel(
          name: 'Test User',
          email: 'test@example.com',
          isRegistered: true,
          authToken: 'survey-token',
        ),
      );

      await userService.completeSurvey(
        const SkinProfile(
          skinType: 'сухая',
          age: 32,
          allergies: <String>['на масла'],
          priceRange: 'люкс',
        ),
      );

      expect(syncedToken, 'survey-token');
      expect(syncedProfile?.skinType, 'сухая');
      expect(userService.hasCompletedSurvey, isTrue);
    },
  );

  test(
    'completeSurvey updates last completion time and prepends history',
    () async {
      final userService = UserService();
      await userService.saveUser(
        UserModel(
          name: 'Test User',
          email: 'test@example.com',
          isRegistered: true,
          hasCompletedSurvey: true,
          skinProfile: const SkinProfile(skinType: 'нормальная', age: 28),
          carePlan: CarePlan(
            categories: const [],
            isPartial: false,
            fetchedAt: DateTime(2026, 5, 1, 8),
          ),
        ),
      );

      await userService.completeSurvey(
        const SkinProfile(skinType: 'сухая', age: 32),
        completedAt: DateTime(2026, 5, 10, 9),
      );
      await userService.completeSurvey(
        const SkinProfile(skinType: 'жирная', age: 33),
        completedAt: DateTime(2026, 5, 12, 18, 45),
      );

      expect(userService.user.hasCompletedSurvey, isTrue);
      expect(
        userService.user.lastSurveyCompletedAt,
        DateTime(2026, 5, 12, 18, 45),
      );
      expect(userService.user.carePlan, isNull);
      expect(userService.user.surveyHistory, hasLength(2));
      expect(
        userService.user.surveyHistory[0].profileSnapshot.skinType,
        'жирная',
      );
      expect(
        userService.user.surveyHistory[1].profileSnapshot.skinType,
        'сухая',
      );

      final reloadedService = UserService();
      await reloadedService.loadUser();

      expect(reloadedService.user.surveyHistory, hasLength(2));
      expect(
        reloadedService.user.lastSurveyCompletedAt,
        DateTime(2026, 5, 12, 18, 45),
      );
      expect(
        reloadedService.user.surveyHistory[0].completedAt,
        DateTime(2026, 5, 12, 18, 45),
      );
      expect(
        reloadedService.user.surveyHistory[1].completedAt,
        DateTime(2026, 5, 10, 9),
      );
    },
  );

  test('loadUser reads legacy carePlan json without meta', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_data':
          '{"name":"Legacy User","email":"legacy@example.com","isRegistered":true,"hasCompletedSurvey":true,"skinProfile":{"skinType":"нормальная","age":28,"allergies":[],"priceRange":"средний"},"carePlan":{"categories":[{"categoryCode":"spf","displayName":"SPF","products":[{"brand":"Brand","productName":"Product","url":"https://example.com"}]}],"isPartial":false,"fetchedAt":"2026-06-01T10:00:00.000"}}',
    });

    final userService = UserService();
    await userService.loadUser();

    expect(userService.user.carePlan, isNotNull);
    expect(userService.user.carePlan!.categories, hasLength(1));
    expect(userService.user.carePlan!.meta.totalCandidates, 0);
    expect(userService.user.carePlan!.meta.scoredCandidates, 0);
    expect(userService.user.carePlan!.meta.excludedByAllergy, 0);
  });

  test(
    'toggleIntensiveApplication persists selected course and logs',
    () async {
      final userService = UserService();
      await userService.saveUser(
        UserModel(
          name: 'Test User',
          email: 'test@example.com',
          isRegistered: true,
          hasCompletedSurvey: true,
          carePlan: CarePlan(
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
        ),
      );

      await userService.selectActiveIntensiveCourse(
        'retino-brand-retinol-serum',
        startedAt: DateTime(2026, 6, 4),
      );
      await userService.toggleIntensiveApplication(
        'retino-brand-retinol-serum',
        DateTime(2026, 6, 5),
      );

      expect(
        userService.user.activeIntensiveCourseProductId,
        'retino-brand-retinol-serum',
      );
      expect(userService.user.intensiveCourseStartedAt, DateTime(2026, 6, 4));
      expect(
        userService.user.isIntensiveApplicationLogged(
          'retino-brand-retinol-serum',
          DateTime(2026, 6, 5, 16),
        ),
        isTrue,
      );

      final reloadedService = UserService();
      await reloadedService.loadUser();

      expect(
        reloadedService.user.isIntensiveApplicationLogged(
          'retino-brand-retinol-serum',
          DateTime(2026, 6, 5),
        ),
        isTrue,
      );
    },
  );

  test(
    'selectActiveIntensiveCourse keeps current course when another is already active',
    () async {
      final userService = UserService();
      await userService.saveUser(
        UserModel(
          isRegistered: true,
          hasCompletedSurvey: true,
          carePlan: _buildTwoProductIntensiveCarePlan(),
        ),
      );

      await userService.selectActiveIntensiveCourse(
        'retino-brand-retinol-serum',
        startedAt: DateTime(2026, 6, 4),
      );
      await userService.selectActiveIntensiveCourse(
        'acid-brand-aha-peel',
        startedAt: DateTime(2026, 6, 10),
      );

      expect(
        userService.user.activeIntensiveCourseProductId,
        'retino-brand-retinol-serum',
      );
      expect(userService.user.intensiveCourseStartedAt, DateTime(2026, 6, 4));
      expect(
        userService.canStartIntensiveCourse('acid-brand-aha-peel'),
        isFalse,
      );
    },
  );

  test(
    'clearActiveIntensiveCourse clears state and allows another product',
    () async {
      final userService = UserService();
      await userService.saveUser(
        UserModel(
          isRegistered: true,
          hasCompletedSurvey: true,
          carePlan: _buildTwoProductIntensiveCarePlan(),
        ),
      );

      await userService.selectActiveIntensiveCourse(
        'retino-brand-retinol-serum',
        startedAt: DateTime(2026, 6, 4),
      );
      await userService.toggleIntensiveApplication(
        'retino-brand-retinol-serum',
        DateTime(2026, 6, 5),
      );

      await userService.clearActiveIntensiveCourse();

      expect(userService.user.activeIntensiveCourseProductId, isNull);
      expect(userService.user.intensiveCourseStartedAt, isNull);
      expect(userService.user.intensiveApplicationLog, isEmpty);

      await userService.selectActiveIntensiveCourse(
        'acid-brand-aha-peel',
        startedAt: DateTime(2026, 6, 10),
      );

      expect(
        userService.user.activeIntensiveCourseProductId,
        'acid-brand-aha-peel',
      );
      expect(userService.user.intensiveCourseStartedAt, DateTime(2026, 6, 10));
    },
  );

  test(
    'saveCarePlan resets active intensive course if product disappears',
    () async {
      final userService = UserService();
      await userService.saveUser(
        UserModel(
          isRegistered: true,
          hasCompletedSurvey: true,
          carePlan: CarePlan(
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
          activeIntensiveCourseProductId: 'retino-brand-retinol-serum',
          intensiveCourseStartedAt: DateTime(2026, 6, 2),
          intensiveApplicationLog: const <String, List<String>>{
            'retino-brand-retinol-serum': <String>['2026-06-03'],
          },
        ),
      );

      await userService.saveCarePlan(
        CarePlan(
          categories: const <CareCategory>[
            CareCategory(
              categoryCode: 'spf',
              displayName: 'SPF',
              products: <ProductRecommendation>[
                ProductRecommendation(
                  productId: 'spf-brand-spf-50',
                  brand: 'SPF Brand',
                  productName: 'SPF 50',
                  url: 'https://example.com/spf',
                ),
              ],
            ),
          ],
          isPartial: false,
          fetchedAt: DateTime(2026, 6, 6),
        ),
      );

      expect(userService.user.activeIntensiveCourseProductId, isNull);
      expect(userService.user.intensiveCourseStartedAt, isNull);
      expect(userService.user.intensiveApplicationLog, isEmpty);
    },
  );
}

CarePlan _buildTwoProductIntensiveCarePlan() {
  return CarePlan(
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
          ProductRecommendation(
            productId: 'acid-brand-aha-peel',
            brand: 'Acid Brand',
            productName: 'AHA Peel',
            url: 'https://example.com/aha',
          ),
        ],
      ),
    ],
    isPartial: false,
    fetchedAt: DateTime(2026, 6, 1),
  );
}
