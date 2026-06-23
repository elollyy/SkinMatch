import 'dart:async';

import '../models/user_model.dart';
import 'care_plan_transport.dart';

typedef CarePlanRequestExecutor =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

enum CarePlanSource { backend, mock }

enum CarePlanFetchStatus {
  success,
  backendNotConfigured,
  requestFailed,
  emptyResult,
}

class CarePlanFetchResult {
  const CarePlanFetchResult({
    required this.status,
    required this.configuredBackend,
    this.plan,
    this.source,
    this.error,
  });

  final CarePlanFetchStatus status;
  final bool configuredBackend;
  final CarePlan? plan;
  final CarePlanSource? source;
  final Object? error;

  bool get requestFailed => status == CarePlanFetchStatus.requestFailed;
  bool get emptyResult => status == CarePlanFetchStatus.emptyResult;
  bool get partial => plan?.isPartial ?? false;
  bool get hasCategories => (plan?.categories.isNotEmpty ?? false);
}

class CarePlanService {
  CarePlanService({
    CarePlanRequestExecutor? requestExecutor,
    String? apiUrl,
    bool? allowMockFallback,
  }) : _requestExecutor = requestExecutor,
       _apiUrl = apiUrl ?? _defaultApiUrl,
       _allowMockFallback = allowMockFallback ?? _defaultAllowMockFallback;

  static const String _defaultApiUrl = String.fromEnvironment(
    'CARE_PLAN_API_URL',
    defaultValue: '',
  );
  static const bool _defaultAllowMockFallback = bool.fromEnvironment(
    'CARE_PLAN_ALLOW_MOCK_FALLBACK',
    defaultValue: false,
  );
  static const String _carePlanPath = '/api/v1/care-plan';

  final CarePlanRequestExecutor? _requestExecutor;
  final String _apiUrl;
  final bool _allowMockFallback;

  static const List<String> _categoryOrder = <String>[
    'cleansing',
    'moisturizing',
    'intensive_renewal',
    'serums_masks',
    'eye_cream',
    'spf',
  ];

  static const Map<String, String> _categoryTitles = <String, String>{
    'cleansing': 'Очищение',
    'moisturizing': 'Увлажнение',
    'intensive_renewal': 'Интенсивное обновление',
    'serums_masks': 'Сыворотки и маски',
    'eye_cream': 'Крем для глаз',
    'spf': 'SPF',
  };

  static const Map<String, String> _categoryAliases = <String, String>{
    'cleaning': 'cleansing',
    'cleanser': 'cleansing',
    'hydrate': 'moisturizing',
    'hydration': 'moisturizing',
    'serum': 'serums_masks',
    'mask': 'serums_masks',
    'serums': 'serums_masks',
    'eye': 'eye_cream',
    'sun': 'spf',
    'sunscreen': 'spf',
  };

  static const Map<String, String> _skinTypeMapping = <String, String>{
    'комбинированная': 'Комбинированная',
    'сухая': 'Сухая кожа',
    'сухая кожа': 'Сухая кожа',
    'нормальная': 'Нормальная',
    'жирная': 'Жирная',
    'чувствительная': 'Чувствительная',
    'проблемная': 'Проблемная кожа',
    'проблемная кожа': 'Проблемная кожа',
  };

  static const Map<String, String> _priceRangeMapping = <String, String>{
    'бюджетный': 'масс-маркет',
    'масс-маркет': 'масс-маркет',
    'средний': 'миддл',
    'миддл': 'миддл',
    'премиум': 'миддл',
    'люкс': 'люкс',
  };

  static const Map<String, String> _mockPriceLabels = <String, String>{
    'масс-маркет': 'бюджетный',
    'миддл': 'средний',
    'люкс': 'люкс',
  };

  Future<CarePlan> fetchPlan(SkinProfile profile) async {
    final result = await fetchPlanResult(profile);
    final plan = result.plan;
    if (plan != null) {
      return plan;
    }

    if (result.status == CarePlanFetchStatus.backendNotConfigured) {
      throw const CarePlanNotConfiguredException();
    }

    throw CarePlanRequestException(result.error);
  }

  Future<CarePlanFetchResult> fetchPlanResult(SkinProfile profile) async {
    final payload = _buildPayload(profile);
    final requestTarget = _resolveRequestTarget();

    if (requestTarget == null) {
      return CarePlanFetchResult(
        status: CarePlanFetchStatus.backendNotConfigured,
        configuredBackend: false,
      );
    }

    try {
      final response = switch (requestTarget) {
        CarePlanSource.mock => _mockResponse(payload),
        CarePlanSource.backend =>
          await (_requestExecutor?.call(payload) ?? _request(payload)),
      };

      final plan = _parseCarePlan(response);
      if (plan.categories.isEmpty) {
        return CarePlanFetchResult(
          status: CarePlanFetchStatus.emptyResult,
          configuredBackend: _hasConfiguredBackend,
          plan: plan,
          source: requestTarget,
        );
      }

      return CarePlanFetchResult(
        status: CarePlanFetchStatus.success,
        configuredBackend: _hasConfiguredBackend,
        plan: plan,
        source: requestTarget,
      );
    } catch (error) {
      return CarePlanFetchResult(
        status: CarePlanFetchStatus.requestFailed,
        configuredBackend: _hasConfiguredBackend,
        source: requestTarget,
        error: error,
      );
    }
  }

  Map<String, dynamic> _buildPayload(SkinProfile profile) {
    return <String, dynamic>{
      'skinType': _mapSkinType(profile.skinType),
      'age': profile.age,
      'allergies': profile.allergies,
      'priceRange': _mapPriceRange(profile.priceRange),
    };
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> payload) async {
    final uri = _resolveApiUri(_apiUrl);
    return postJson(uri, payload);
  }

  bool get _hasConfiguredBackend =>
      _requestExecutor != null || _apiUrl.trim().isNotEmpty;

  CarePlanSource? _resolveRequestTarget() {
    if (_requestExecutor != null || _apiUrl.trim().isNotEmpty) {
      return CarePlanSource.backend;
    }

    if (_allowMockFallback) {
      return CarePlanSource.mock;
    }

    return null;
  }

  Uri _resolveApiUri(String apiUrl) {
    final parsedUri = Uri.parse(apiUrl.trim());
    final normalizedPath = parsedUri.path.endsWith('/')
        ? parsedUri.path.substring(0, parsedUri.path.length - 1)
        : parsedUri.path;

    if (normalizedPath.endsWith(_carePlanPath)) {
      return parsedUri.replace(path: normalizedPath);
    }

    final nextPath = normalizedPath.isEmpty
        ? _carePlanPath
        : '$normalizedPath$_carePlanPath';

    return parsedUri.replace(path: nextPath);
  }

  CarePlan _parseCarePlan(Map<String, dynamic> response) {
    var hasInvalidData = false;

    final rawCategories = _extractCategories(response);
    final parsedCategories = <CareCategory>[];

    for (final rawCategory in rawCategories) {
      final parsedCategory = _parseCategory(rawCategory);
      if (parsedCategory == null) {
        hasInvalidData = true;
        continue;
      }

      if (parsedCategory.products.isEmpty) {
        hasInvalidData = true;
        continue;
      }

      parsedCategories.add(parsedCategory);
    }

    parsedCategories.sort(_sortCategories);

    return CarePlan(
      categories: parsedCategories,
      isPartial: hasInvalidData || (response['partial'] == true),
      fetchedAt: DateTime.now(),
      meta: _parseMeta(response['meta']),
    );
  }

  CarePlanMeta _parseMeta(Object? rawMeta) {
    return CarePlanMeta.fromJson(rawMeta);
  }

  List<Map<String, dynamic>> _extractCategories(Map<String, dynamic> response) {
    final rawCategories = response['categories'];
    if (rawCategories is List) {
      return rawCategories
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  CareCategory? _parseCategory(Map<String, dynamic> rawCategory) {
    final rawCode = (rawCategory['categoryCode'] ?? rawCategory['code'] ?? '')
        .toString()
        .trim();
    final normalizedCode = _normalizeCategoryCode(rawCode);

    if (normalizedCode.isEmpty) {
      return null;
    }

    final displayName =
        (rawCategory['displayName'] ??
                rawCategory['title'] ??
                rawCategory['name'] ??
                _categoryTitles[normalizedCode] ??
                normalizedCode)
            .toString()
            .trim();

    final rawProducts = rawCategory['products'];
    if (rawProducts is! List) {
      return null;
    }

    final products = <ProductRecommendation>[];

    for (final rawProduct in rawProducts) {
      if (rawProduct is! Map) {
        continue;
      }

      final product = _parseProduct(Map<String, dynamic>.from(rawProduct));
      if (product != null) {
        products.add(product);
      }

      if (products.length == 3) {
        break;
      }
    }

    return CareCategory(
      categoryCode: normalizedCode,
      displayName: displayName,
      products: products,
    );
  }

  ProductRecommendation? _parseProduct(Map<String, dynamic> rawProduct) {
    final brand = (rawProduct['brand'] ?? '').toString().trim();
    final productName =
        (rawProduct['productName'] ??
                rawProduct['name'] ??
                rawProduct['title'] ??
                '')
            .toString()
            .trim();
    final url = (rawProduct['url'] ?? rawProduct['link'] ?? '')
        .toString()
        .trim();

    if (brand.isEmpty || productName.isEmpty || url.isEmpty) {
      return null;
    }

    return ProductRecommendation(
      productId: (rawProduct['productId'] ?? '').toString().trim().isNotEmpty
          ? rawProduct['productId'].toString().trim()
          : buildProductId(brand: brand, productName: productName),
      brand: brand,
      productName: productName,
      url: url,
      usageGuidance: UsageGuidance.fromJsonOrNull(rawProduct['usageGuidance']),
    );
  }

  String _normalizeCategoryCode(String code) {
    if (code.isEmpty) {
      return '';
    }

    final normalized = code
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    if (_categoryOrder.contains(normalized)) {
      return normalized;
    }

    return _categoryAliases[normalized] ?? normalized;
  }

  int _sortCategories(CareCategory a, CareCategory b) {
    final indexA = _categoryOrder.indexOf(a.categoryCode);
    final indexB = _categoryOrder.indexOf(b.categoryCode);

    if (indexA == -1 && indexB == -1) {
      return a.displayName.compareTo(b.displayName);
    }

    if (indexA == -1) {
      return 1;
    }

    if (indexB == -1) {
      return -1;
    }

    return indexA.compareTo(indexB);
  }

  String _mapSkinType(String value) {
    final normalized = value.trim().toLowerCase();
    return _skinTypeMapping[normalized] ?? 'Нормальная';
  }

  String _mapPriceRange(String value) {
    final normalized = value.trim().toLowerCase();
    return _priceRangeMapping[normalized] ?? 'миддл';
  }

  String _mockPriceLabel(String value) {
    final normalized = value.trim().toLowerCase();
    return _mockPriceLabels[normalized] ?? 'средний';
  }

  Map<String, dynamic> _mockResponse(Map<String, dynamic> payload) {
    final priceRange = _mockPriceLabel(
      payload['priceRange']?.toString() ?? 'миддл',
    );

    return <String, dynamic>{
      'categories': <Map<String, dynamic>>[
        <String, dynamic>{
          'categoryCode': 'cleansing',
          'displayName': 'Очищение',
          'products': <Map<String, dynamic>>[
            _mockProduct(
              brand: 'CeraVe',
              productName: 'Hydrating Cleanser',
              url: 'https://example.com/cerave-cleanser',
            ),
            _mockProduct(
              brand: 'La Roche-Posay',
              productName: 'Toleriane Caring Wash',
              url: 'https://example.com/lrp-cleanser',
            ),
            _mockProduct(
              brand: 'Avene',
              productName: 'Tolerance Cleansing Lotion',
              url: 'https://example.com/avene-cleanser',
            ),
          ],
        },
        <String, dynamic>{
          'categoryCode': 'moisturizing',
          'displayName': 'Увлажнение',
          'products': <Map<String, dynamic>>[
            _mockProduct(
              brand: 'Bioderma',
              productName: 'Hydrabio Gel-Creme ($priceRange)',
              url: 'https://example.com/hydrabio',
            ),
            _mockProduct(
              brand: 'Vichy',
              productName: 'Aqualia Thermal',
              url: 'https://example.com/aqualia',
            ),
          ],
        },
        <String, dynamic>{
          'categoryCode': 'intensive_renewal',
          'displayName': 'Интенсивное обновление',
          'products': <Map<String, dynamic>>[
            _mockProduct(
              brand: 'The Ordinary',
              productName: 'Retinol 0.2% in Squalane',
              url: 'https://example.com/retinol-course',
              usageGuidance: <String, dynamic>{
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
                      'note': 'Начинайте с двух вечеров в неделю.',
                    },
                    <String, dynamic>{
                      'weekStart': 3,
                      'weekEnd': null,
                      'dayStart': 15,
                      'dayEnd': null,
                      'allowedCycleDays': <int>[1, 3, 5],
                      'label': 'С 3 недели',
                      'note': 'Повышайте частоту постепенно.',
                    },
                  ],
                },
                'conflicts': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'label': 'Кислоты и пилинги',
                    'explanation':
                        'Не сочетайте с кислотами и агрессивными обновляющими средствами в один вечер.',
                    'categoryCodes': <String>[
                      'intensive_renewal',
                      'serums_masks',
                    ],
                    'activeFamilies': <String>['acid', 'spicule'],
                  },
                ],
                'applicationTips': <String>[
                  'Наносите вечером на сухую кожу.',
                  'На следующий день используйте SPF 30+.',
                ],
              },
            ),
          ],
        },
        <String, dynamic>{
          'categoryCode': 'spf',
          'displayName': 'SPF',
          'products': <Map<String, dynamic>>[
            _mockProduct(
              brand: 'Isntree',
              productName: 'Hyaluronic Acid Watery Sun Gel SPF50+',
              url: 'https://example.com/isntree-spf',
            ),
          ],
        },
      ],
      'partial': false,
      'meta': const <String, dynamic>{
        'totalCandidates': 3,
        'scoredCandidates': 3,
        'excludedByAllergy': 0,
      },
    };
  }

  Map<String, dynamic> _mockProduct({
    required String brand,
    required String productName,
    required String url,
    Map<String, dynamic>? usageGuidance,
  }) {
    return <String, dynamic>{
      'productId': buildProductId(brand: brand, productName: productName),
      'brand': brand,
      'productName': productName,
      'url': url,
      ...?usageGuidance == null
          ? null
          : <String, dynamic>{'usageGuidance': usageGuidance},
    };
  }
}

class CarePlanNotConfiguredException implements Exception {
  const CarePlanNotConfiguredException();
}

class CarePlanRequestException implements Exception {
  const CarePlanRequestException(this.cause);

  final Object? cause;
}
