import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skinmatch/models/user_model.dart';
import 'package:skinmatch/services/care_plan_service.dart';

void main() {
  group('CarePlanService', () {
    const profile = SkinProfile(
      skinType: 'комбинированная',
      age: 30,
      allergies: <String>['на спирт'],
      priceRange: 'средний',
    );

    test('makes POST request to backend and parses response meta', () async {
      final payloads = <Map<String, dynamic>>[];
      late final HttpServer server;

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((HttpRequest request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/care-plan');

        final rawBody = await utf8.decoder.bind(request).join();
        payloads.add(json.decode(rawBody) as Map<String, dynamic>);

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          json.encode(<String, dynamic>{
            'categories': <Map<String, dynamic>>[
              <String, dynamic>{
                'categoryCode': 'serums_masks',
                'displayName': 'Сыворотки и маски',
                'products': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'productId': 'mask-brand-mask-product',
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
                    'brand': 'Sun Brand',
                    'productName': 'Sun Product',
                    'url': 'https://example.com/spf',
                  },
                ],
              },
            ],
            'partial': false,
            'meta': <String, dynamic>{
              'totalCandidates': 4,
              'scoredCandidates': 2,
              'excludedByAllergy': 1,
            },
          }),
        );
        await request.response.close();
      });

      final service = CarePlanService(
        apiUrl: 'http://${server.address.address}:${server.port}',
      );

      final plan = await service.fetchPlan(profile);

      expect(payloads, hasLength(1));
      expect(payloads.single['skinType'], 'Комбинированная');
      expect(payloads.single['age'], 30);
      expect(payloads.single['allergies'], <String>['на спирт']);
      expect(payloads.single['priceRange'], 'миддл');
      expect(plan.isPartial, isFalse);
      expect(
        plan.categories.map((category) => category.categoryCode).toList(),
        <String>['serums_masks', 'spf'],
      );
      expect(
        plan.categories.first.products.first.productId,
        'mask-brand-mask-product',
      );
      expect(plan.meta.totalCandidates, 4);
      expect(plan.meta.scoredCandidates, 2);
      expect(plan.meta.excludedByAllergy, 1);
    });

    test(
      'parses response, limits products to 3, and marks plan as partial',
      () async {
        final service = CarePlanService(
          requestExecutor: (_) async => <String, dynamic>{
            'categories': <Map<String, dynamic>>[
              <String, dynamic>{
                'categoryCode': 'cleansing',
                'displayName': 'Очищение',
                'products': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'brand': 'A',
                    'productName': 'P1',
                    'url': 'https://example.com/1',
                  },
                  <String, dynamic>{
                    'brand': 'B',
                    'productName': 'P2',
                    'url': 'https://example.com/2',
                  },
                  <String, dynamic>{
                    'brand': 'C',
                    'productName': 'P3',
                    'url': 'https://example.com/3',
                  },
                  <String, dynamic>{
                    'brand': 'D',
                    'productName': 'P4',
                    'url': 'https://example.com/4',
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
              <String, dynamic>{
                'displayName': 'Без кода',
                'products': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'brand': 'Brand',
                    'productName': 'Product',
                    'url': 'https://example.com/x',
                  },
                ],
              },
              <String, dynamic>{
                'categoryCode': 'spf',
                'displayName': 'SPF',
                'products': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'brand': 'SPF Brand',
                    'productName': 'SPF Product',
                    'url': 'https://example.com/spf',
                  },
                ],
              },
            ],
          },
        );

        final plan = await service.fetchPlan(profile);

        expect(plan.isPartial, isTrue);
        expect(plan.categories.length, 2);
        expect(plan.categories.first.categoryCode, 'cleansing');
        expect(plan.categories.first.products.length, 3);
        expect(plan.categories.last.categoryCode, 'spf');
      },
    );

    test(
      'parses intensive renewal category and sorts it after moisturizing',
      () async {
        final service = CarePlanService(
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

        final plan = await service.fetchPlan(profile);

        expect(
          plan.categories.map((category) => category.categoryCode).toList(),
          <String>['moisturizing', 'intensive_renewal', 'serums_masks'],
        );
        expect(plan.categories[1].displayName, 'Интенсивное обновление');
      },
    );

    test(
      'parses productId and usage guidance for intensive products',
      () async {
        final service = CarePlanService(
          requestExecutor: (_) async => <String, dynamic>{
            'categories': <Map<String, dynamic>>[
              <String, dynamic>{
                'categoryCode': 'intensive_renewal',
                'displayName': 'Интенсивное обновление',
                'products': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'productId': 'retino-brand-retinol-serum',
                    'brand': 'Retino Brand',
                    'productName': 'Retinol Serum',
                    'url': 'https://example.com/retinol',
                    'usageGuidance': <String, dynamic>{
                      'activeFamily': 'retinoid',
                      'displayLabel': 'Ретиноид',
                      'introductionScheme': <String, dynamic>{
                        'cycleLengthDays': 7,
                        'startWithEveningOnly': true,
                        'phases': <Map<String, dynamic>>[
                          <String, dynamic>{
                            'weekStart': 1,
                            'weekEnd': 2,
                            'dayStart': 1,
                            'dayEnd': 14,
                            'allowedCycleDays': <int>[1, 4],
                            'label': 'Недели 1-2',
                          },
                        ],
                      },
                      'conflicts': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'label': 'Кислоты и пилинги',
                          'explanation': 'Не сочетайте в один вечер.',
                          'categoryCodes': <String>['serums_masks'],
                          'activeFamilies': <String>['acid'],
                        },
                      ],
                      'applicationTips': <String>['Используйте вечером.'],
                    },
                  },
                ],
              },
            ],
          },
        );

        final plan = await service.fetchPlan(profile);

        final product = plan.categories.first.products.first;
        expect(product.productId, 'retino-brand-retinol-serum');
        expect(product.usageGuidance, isNotNull);
        expect(product.usageGuidance!.activeFamily, 'retinoid');
        expect(product.usageGuidance!.introductionScheme.cycleLengthDays, 7);
        expect(
          product.usageGuidance!.conflicts.first.label,
          'Кислоты и пилинги',
        );
      },
    );

    test(
      'normalizes survey values before sending payload to backend',
      () async {
        final payloads = <Map<String, dynamic>>[];
        final service = CarePlanService(
          requestExecutor: (payload) async {
            payloads.add(Map<String, dynamic>.from(payload));
            return <String, dynamic>{
              'categories': <Map<String, dynamic>>[],
              'partial': true,
            };
          },
        );

        await service.fetchPlan(
          const SkinProfile(
            skinType: 'проблемная кожа',
            age: 27,
            allergies: <String>[],
            priceRange: 'бюджетный',
          ),
        );

        await service.fetchPlan(
          const SkinProfile(
            skinType: 'нормальная',
            age: 35,
            allergies: <String>[],
            priceRange: 'люкс',
          ),
        );

        expect(payloads, hasLength(2));
        expect(payloads[0]['skinType'], 'Проблемная кожа');
        expect(payloads[0]['priceRange'], 'масс-маркет');
        expect(payloads[1]['skinType'], 'Нормальная');
        expect(payloads[1]['priceRange'], 'люкс');
      },
    );

    test(
      'keeps product with invalid url string but marks link as invalid',
      () async {
        final service = CarePlanService(
          requestExecutor: (_) async => <String, dynamic>{
            'categories': <Map<String, dynamic>>[
              <String, dynamic>{
                'categoryCode': 'eye_cream',
                'displayName': 'Крем для глаз',
                'products': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'brand': 'Brand X',
                    'productName': 'Product Y',
                    'url': 'not-a-url',
                  },
                ],
              },
            ],
          },
        );

        final plan = await service.fetchPlan(profile);

        expect(plan.isPartial, isFalse);
        expect(plan.categories, hasLength(1));
        expect(plan.categories.first.products, hasLength(1));
        expect(plan.categories.first.products.first.hasValidUrl, isFalse);
      },
    );

    test(
      'returns backend not configured when API url is missing and mock fallback is disabled',
      () async {
        final service = CarePlanService(apiUrl: '', allowMockFallback: false);

        final result = await service.fetchPlanResult(profile);

        expect(result.status, CarePlanFetchStatus.backendNotConfigured);
        expect(result.configuredBackend, isFalse);
        expect(result.plan, isNull);
      },
    );

    test('returns empty result and preserves backend meta', () async {
      final service = CarePlanService(
        apiUrl: 'http://127.0.0.1:8000',
        requestExecutor: (_) async => <String, dynamic>{
          'categories': <Map<String, dynamic>>[],
          'partial': false,
          'meta': <String, dynamic>{
            'totalCandidates': 3,
            'scoredCandidates': 0,
            'excludedByAllergy': 2,
          },
        },
      );

      final result = await service.fetchPlanResult(profile);

      expect(result.status, CarePlanFetchStatus.emptyResult);
      expect(result.plan, isNotNull);
      expect(result.plan!.categories, isEmpty);
      expect(result.plan!.meta.totalCandidates, 3);
      expect(result.plan!.meta.scoredCandidates, 0);
      expect(result.plan!.meta.excludedByAllergy, 2);
    });

    test('returns request failed status on transport error', () async {
      final service = CarePlanService(
        apiUrl: 'http://127.0.0.1:8000',
        requestExecutor: (_) async {
          throw const SocketException('backend unavailable');
        },
      );

      final result = await service.fetchPlanResult(profile);

      expect(result.status, CarePlanFetchStatus.requestFailed);
      expect(result.requestFailed, isTrue);
      expect(result.plan, isNull);
    });

    test(
      'does not replace empty backend response with mock data when backend is configured',
      () async {
        final service = CarePlanService(
          apiUrl: 'http://127.0.0.1:8000',
          requestExecutor: (_) async => <String, dynamic>{
            'categories': <Map<String, dynamic>>[],
            'partial': false,
            'meta': <String, dynamic>{
              'totalCandidates': 0,
              'scoredCandidates': 0,
              'excludedByAllergy': 0,
            },
          },
        );

        final result = await service.fetchPlanResult(profile);

        expect(result.status, CarePlanFetchStatus.emptyResult);
        expect(result.plan!.categories, isEmpty);
      },
    );
  });
}
