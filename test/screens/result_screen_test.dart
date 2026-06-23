import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/screens/result_screen.dart';
import 'package:skinmatch/services/care_plan_service.dart';
import 'package:skinmatch/services/user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'result screen shows loading and then renders categories with products',
    (tester) async {
      final userService = await _createReadyUserService(
        allergies: const <String>['на спирт'],
      );

      final carePlanService = CarePlanService(
        requestExecutor: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return <String, dynamic>{
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
              <String, dynamic>{
                'categoryCode': 'moisturizing',
                'displayName': 'Увлажнение',
                'products': <Map<String, dynamic>>[],
              },
            ],
          };
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: carePlanService,
        ),
      );

      expect(find.byKey(const Key('result_loading')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 70));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category_cleansing')), findsOneWidget);
      expect(find.byKey(const Key('category_moisturizing')), findsNothing);
      expect(find.text('Hydrating Cleanser'), findsOneWidget);
      expect(find.text('Тип кожи: Нормальная'), findsOneWidget);
      expect(find.text('Возраст: 28 лет'), findsOneWidget);
      expect(find.text('Исключено: спирт'), findsOneWidget);
      expect(find.text('Сохранить план ухода'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    },
  );

  testWidgets(
    'result screen shows empty state when API returns no valid categories',
    (tester) async {
      final userService = await _createReadyUserService();

      final carePlanService = CarePlanService(
        requestExecutor: (_) async => <String, dynamic>{
          'categories': <Map<String, dynamic>>[
            <String, dynamic>{
              'categoryCode': 'cleansing',
              'displayName': 'Очищение',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{'brand': '', 'productName': '', 'url': ''},
              ],
            },
          ],
          'meta': <String, dynamic>{
            'totalCandidates': 4,
            'scoredCandidates': 0,
            'excludedByAllergy': 2,
          },
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: carePlanService,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('result_empty')), findsOneWidget);
      expect(
        find.text(
          'Кандидаты нашлись, но были исключены по ограничениям, например из-за аллергий.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('result_retry_button')), findsOneWidget);
      expect(
        find.byKey(const Key('result_restart_survey_button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'result screen shows partial banner and link tap triggers callback',
    (tester) async {
      final userService = await _createReadyUserService();
      String? tappedUrl;

      final carePlanService = CarePlanService(
        requestExecutor: (_) async => <String, dynamic>{
          'categories': <Map<String, dynamic>>[
            <String, dynamic>{
              'categoryCode': 'serums_masks',
              'displayName': 'Сыворотки и маски',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'brand': 'Mask Brand',
                  'productName': 'Mask Product',
                  'url': 'https://example.com/mask',
                },
              ],
            },
            <String, dynamic>{
              'categoryCode': 'spf',
              'displayName': 'SPF',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'brand': 'Brand SPF',
                  'productName': 'SPF 50',
                  'url': 'https://example.com/spf',
                },
              ],
            },
            <String, dynamic>{
              'categoryCode': 'moisturizing',
              'displayName': 'Увлажнение',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'brand': '',
                  'productName': 'Broken',
                  'url': 'https://example.com/broken',
                },
              ],
            },
          ],
          'partial': true,
          'meta': <String, dynamic>{
            'totalCandidates': 5,
            'scoredCandidates': 2,
            'excludedByAllergy': 1,
          },
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: carePlanService,
          onOpenProductUrl: (url) async {
            tappedUrl = url;
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('result_partial')), findsOneWidget);
      expect(find.byKey(const Key('category_serums_masks')), findsOneWidget);
      expect(find.byKey(const Key('category_spf')), findsOneWidget);
      expect(find.text('Mask Product'), findsOneWidget);
      expect(
        find.text(
          'Часть кандидатов исключена из-за аллергий, поэтому показаны только совместимые рекомендации.',
        ),
        findsOneWidget,
      );

      final openButton = tester.widget<TextButton>(
        find.byKey(const Key('open_spf_0')),
      );
      openButton.onPressed?.call();
      await tester.pump();

      expect(tappedUrl, 'https://example.com/spf');
    },
  );

  testWidgets(
    'result screen renders intensive renewal block in sorted position',
    (tester) async {
      final userService = await _createReadyUserService();

      final carePlanService = CarePlanService(
        requestExecutor: (_) async => <String, dynamic>{
          'categories': <Map<String, dynamic>>[
            <String, dynamic>{
              'categoryCode': 'serums_masks',
              'displayName': 'Сыворотки и маски',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'brand': 'Mask Brand',
                  'productName': 'Mask Product',
                  'url': 'https://example.com/mask',
                },
              ],
            },
            <String, dynamic>{
              'categoryCode': 'intensive_renewal',
              'displayName': 'Интенсивное обновление',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'brand': 'Renew Brand',
                  'productName': 'Renew Product',
                  'url': 'https://example.com/renew',
                },
              ],
            },
            <String, dynamic>{
              'categoryCode': 'moisturizing',
              'displayName': 'Увлажнение',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'brand': 'Moist Brand',
                  'productName': 'Moist Product',
                  'url': 'https://example.com/moist',
                },
              ],
            },
          ],
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: carePlanService,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('category_intensive_renewal')),
        findsOneWidget,
      );
      expect(find.textContaining('ИНТЕНСИВНОЕ ОБНОВЛЕНИЕ'), findsOneWidget);
      expect(find.byIcon(Icons.autorenew_rounded), findsOneWidget);

      final moisturizingTop = tester.getTopLeft(
        find.byKey(const Key('category_moisturizing')),
      );
      final renewalTop = tester.getTopLeft(
        find.byKey(const Key('category_intensive_renewal')),
      );
      final serumsTop = tester.getTopLeft(
        find.byKey(const Key('category_serums_masks')),
      );

      expect(moisturizingTop.dy, lessThan(renewalTop.dy));
      expect(renewalTop.dy, lessThan(serumsTop.dy));
    },
  );

  testWidgets('result hero scrolls away with the recommendations list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userService = await _createReadyUserService();

    final carePlanService = CarePlanService(
      requestExecutor: (_) async => <String, dynamic>{
        'categories': List<Map<String, dynamic>>.generate(8, (index) {
          return <String, dynamic>{
            'categoryCode': 'cleansing_$index',
            'displayName': 'Категория $index',
            'products': <Map<String, dynamic>>[
              <String, dynamic>{
                'brand': 'Brand $index',
                'productName': 'Product $index',
                'url': 'https://example.com/$index',
              },
            ],
          };
        }),
      },
    );

    await tester.pumpWidget(
      _buildTestApp(userService: userService, carePlanService: carePlanService),
    );
    await tester.pumpAndSettle();

    final heroFinder = find.byKey(const Key('result_hero'));
    final initialTop = tester.getTopLeft(heroFinder).dy;

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(heroFinder).dy, lessThan(initialTop));
  });

  testWidgets(
    'result hero matches the content width and category titles omit steps',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final userService = await _createReadyUserService();
      final carePlanService = CarePlanService(
        requestExecutor: (_) async => <String, dynamic>{
          'categories': <Map<String, dynamic>>[
            <String, dynamic>{
              'categoryCode': 'cleansing',
              'displayName': 'Очищение',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'brand': 'Brand One',
                  'productName': 'Product One',
                  'url': 'https://example.com/1',
                },
                <String, dynamic>{
                  'brand': 'Brand Two',
                  'productName': 'Product Two',
                  'url': 'https://example.com/2',
                },
              ],
            },
          ],
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: carePlanService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('result_hero')), findsOneWidget);
      expect(find.byKey(const Key('category_cleansing')), findsOneWidget);
      expect(find.text('ОЧИЩЕНИЕ'), findsOneWidget);
      expect(find.textContaining('ОЧИЩЕНИЕ ·'), findsNothing);
      expect(find.textContaining('2 шага'), findsNothing);

      final heroWidth = tester
          .getSize(find.byKey(const Key('result_hero')))
          .width;
      final categoryWidth = tester
          .getSize(find.byKey(const Key('category_cleansing')))
          .width;

      expect(heroWidth, categoryWidth);
    },
  );

  testWidgets(
    'result screen falls back to cached plan when backend request fails',
    (tester) async {
      final userService = await _createReadyUserService();
      await userService.saveCarePlan(
        CarePlan(
          categories: const <CareCategory>[
            CareCategory(
              categoryCode: 'cleansing',
              displayName: 'Очищение',
              products: <ProductRecommendation>[
                ProductRecommendation(
                  productId: 'cached-brand-cached-product',
                  brand: 'Cached Brand',
                  productName: 'Cached Product',
                  url: 'https://example.com/cached',
                ),
              ],
            ),
          ],
          isPartial: false,
          fetchedAt: DateTime(2026, 6, 3),
        ),
      );

      final carePlanService = CarePlanService(
        requestExecutor: (_) async {
          throw Exception('network error');
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: carePlanService,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('result_cached_warning')), findsOneWidget);
      expect(find.text('Cached Product'), findsOneWidget);
      expect(find.byKey(const Key('category_cleansing')), findsOneWidget);
      expect(find.byKey(const Key('result_retry_button')), findsOneWidget);
      expect(
        find.byKey(const Key('result_restart_survey_button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'result screen shows backend not configured state when API url is missing',
    (tester) async {
      final userService = await _createReadyUserService();

      final carePlanService = CarePlanService(
        apiUrl: '',
        allowMockFallback: false,
      );

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: carePlanService,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('result_backend_not_configured')),
        findsOneWidget,
      );
      expect(find.text('Сервис рекомендаций не подключён'), findsOneWidget);
    },
  );

  testWidgets('result screen shows backend unavailable state without cache', (
    tester,
  ) async {
    final userService = await _createReadyUserService();

    final carePlanService = CarePlanService(
      apiUrl: 'http://127.0.0.1:8000',
      requestExecutor: (_) async {
        throw Exception('network error');
      },
    );

    await tester.pumpWidget(
      _buildTestApp(userService: userService, carePlanService: carePlanService),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('result_backend_unavailable')), findsOneWidget);
    expect(find.text('Сервис рекомендаций недоступен'), findsOneWidget);
  });

  testWidgets('retry button triggers care plan reload', (tester) async {
    final userService = await _createReadyUserService();
    var requestCount = 0;

    final carePlanService = CarePlanService(
      requestExecutor: (_) async {
        requestCount++;
        if (requestCount == 1) {
          return <String, dynamic>{
            'categories': <Map<String, dynamic>>[],
            'meta': <String, dynamic>{
              'totalCandidates': 0,
              'scoredCandidates': 0,
              'excludedByAllergy': 0,
            },
          };
        }

        return <String, dynamic>{
          'categories': <Map<String, dynamic>>[
            <String, dynamic>{
              'categoryCode': 'spf',
              'displayName': 'SPF',
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'brand': 'Retry Brand',
                  'productName': 'Retry Product',
                  'url': 'https://example.com/retry',
                },
              ],
            },
          ],
          'meta': <String, dynamic>{
            'totalCandidates': 1,
            'scoredCandidates': 1,
            'excludedByAllergy': 0,
          },
        };
      },
    );

    await tester.pumpWidget(
      _buildTestApp(userService: userService, carePlanService: carePlanService),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('result_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('result_retry_button')));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.byKey(const Key('category_spf')), findsOneWidget);
    expect(find.text('Retry Product'), findsOneWidget);
  });

  testWidgets('restart survey button navigates to survey route', (
    tester,
  ) async {
    final userService = await _createReadyUserService();

    await tester.pumpWidget(
      _buildTestApp(
        userService: userService,
        carePlanService: CarePlanService(apiUrl: '', allowMockFallback: false),
        routes: <String, WidgetBuilder>{
          '/survey': (_) =>
              const Scaffold(body: Center(child: Text('survey route'))),
        },
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('result_restart_survey_button')));
    await tester.pumpAndSettle();

    expect(find.text('survey route'), findsOneWidget);
  });

  testWidgets(
    'intensive course CTA opens course route and preselects product',
    (tester) async {
      final userService = await _createReadyUserService();
      final carePlanService = _buildIntensiveResultCarePlanService();

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: carePlanService,
          routes: <String, WidgetBuilder>{
            '/course': (_) =>
                const Scaffold(body: Center(child: Text('course route'))),
          },
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('track_retino-brand-retinol-serum')),
      );
      await tester.pumpAndSettle();

      expect(find.text('course route'), findsOneWidget);
      expect(
        userService.user.activeIntensiveCourseProductId,
        'retino-brand-retinol-serum',
      );
    },
  );

  testWidgets(
    'intensive course CTA for active product just opens current course',
    (tester) async {
      final userService = await _createReadyUserService();
      await userService.saveCarePlan(_buildTwoProductIntensiveCarePlan());
      await userService.selectActiveIntensiveCourse(
        'retino-brand-retinol-serum',
        startedAt: DateTime(2026, 6, 4),
      );
      final initialStartedAt = userService.user.intensiveCourseStartedAt;

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: _buildIntensiveResultCarePlanService(
            twoProducts: true,
          ),
          routes: <String, WidgetBuilder>{
            '/course': (_) =>
                const Scaffold(body: Center(child: Text('course route'))),
          },
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('track_retino-brand-retinol-serum')),
      );
      await tester.pumpAndSettle();

      expect(find.text('course route'), findsOneWidget);
      expect(
        userService.user.activeIntensiveCourseProductId,
        'retino-brand-retinol-serum',
      );
      expect(userService.user.intensiveCourseStartedAt, initialStartedAt);
    },
  );

  testWidgets(
    'intensive course CTA for another product shows warning and keeps active course',
    (tester) async {
      final userService = await _createReadyUserService();
      await userService.saveCarePlan(_buildTwoProductIntensiveCarePlan());
      await userService.selectActiveIntensiveCourse(
        'retino-brand-retinol-serum',
        startedAt: DateTime(2026, 6, 4),
      );

      await tester.pumpWidget(
        _buildTestApp(
          userService: userService,
          carePlanService: _buildIntensiveResultCarePlanService(
            twoProducts: true,
          ),
          routes: <String, WidgetBuilder>{
            '/course': (_) =>
                const Scaffold(body: Center(child: Text('course route'))),
          },
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('track_acid-brand-aha-peel')));
      await tester.pumpAndSettle();

      expect(find.text('course route'), findsNothing);
      expect(
        find.textContaining('Сейчас активен курс "Retinol Serum"'),
        findsOneWidget,
      );
      expect(
        userService.user.activeIntensiveCourseProductId,
        'retino-brand-retinol-serum',
      );
    },
  );
}

Widget _buildTestApp({
  required UserService userService,
  required CarePlanService carePlanService,
  Future<void> Function(String url)? onOpenProductUrl,
  Map<String, WidgetBuilder> routes = const <String, WidgetBuilder>{},
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserService>.value(value: userService),
      Provider<CarePlanService>.value(value: carePlanService),
    ],
    child: MaterialApp(
      home: ResultScreen(onOpenProductUrl: onOpenProductUrl),
      routes: routes,
    ),
  );
}

Future<UserService> _createReadyUserService({
  List<String> allergies = const <String>[],
}) async {
  final userService = UserService();
  await userService.saveUser(
    UserModel(
      name: 'Test User',
      email: 'test@example.com',
      isRegistered: true,
      authToken: 'test-token',
    ),
  );
  await userService.completeSurvey(
    SkinProfile(
      skinType: 'нормальная',
      age: 28,
      allergies: allergies,
      priceRange: 'средний',
    ),
  );
  return userService;
}

CarePlanService _buildIntensiveResultCarePlanService({
  bool twoProducts = false,
}) {
  return CarePlanService(
    requestExecutor: (_) async => <String, dynamic>{
      'categories': <Map<String, dynamic>>[
        <String, dynamic>{
          'categoryCode': 'intensive_renewal',
          'displayName': 'Интенсивное обновление',
          'products': <Map<String, dynamic>>[
            _intensiveProductJson(
              productId: 'retino-brand-retinol-serum',
              brand: 'Retino Brand',
              productName: 'Retinol Serum',
              url: 'https://example.com/retinol',
            ),
            if (twoProducts)
              _intensiveProductJson(
                productId: 'acid-brand-aha-peel',
                brand: 'Acid Brand',
                productName: 'AHA Peel',
                url: 'https://example.com/aha',
              ),
          ],
        },
      ],
    },
  );
}

Map<String, dynamic> _intensiveProductJson({
  required String productId,
  required String brand,
  required String productName,
  required String url,
}) {
  return <String, dynamic>{
    'productId': productId,
    'brand': brand,
    'productName': productName,
    'url': url,
    'usageGuidance': <String, dynamic>{
      'activeFamily': productId.contains('acid') ? 'acid' : 'retinoid',
      'displayLabel': productId.contains('acid')
          ? 'Кислотный курс'
          : 'Ретиноид',
      'introductionScheme': <String, dynamic>{
        'cycleLengthDays': 7,
        'startWithEveningOnly': true,
        'phases': <Map<String, dynamic>>[
          <String, dynamic>{
            'weekStart': 1,
            'weekEnd': 2,
            'dayStart': 1,
            'dayEnd': 14,
            'allowedCycleDays': productId.contains('acid')
                ? <int>[2, 5]
                : <int>[1, 4],
            'label': 'Недели 1-2',
          },
        ],
      },
      'conflicts': <Map<String, dynamic>>[],
      'applicationTips': <String>['Используйте вечером.'],
    },
  };
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
