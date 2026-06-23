class UserModel {
  final int? userId;
  final String? name;
  final String? email;
  final String? authToken;
  final bool isRegistered;
  final bool hasCompletedSurvey;
  final SkinProfile? skinProfile;
  final CarePlan? carePlan;
  final DateTime? lastSurveyCompletedAt;
  final List<SurveyHistoryEntry> surveyHistory;
  final String? activeIntensiveCourseProductId;
  final DateTime? intensiveCourseStartedAt;
  final Map<String, List<String>> intensiveApplicationLog;

  UserModel({
    this.userId,
    this.name,
    this.email,
    this.authToken,
    this.isRegistered = false,
    this.hasCompletedSurvey = false,
    this.skinProfile,
    this.carePlan,
    this.lastSurveyCompletedAt,
    this.surveyHistory = const [],
    this.activeIntensiveCourseProductId,
    this.intensiveCourseStartedAt,
    this.intensiveApplicationLog = const <String, List<String>>{},
  });

  UserModel copyWith({
    int? userId,
    String? name,
    String? email,
    String? authToken,
    bool? isRegistered,
    bool? hasCompletedSurvey,
    SkinProfile? skinProfile,
    CarePlan? carePlan,
    DateTime? lastSurveyCompletedAt,
    List<SurveyHistoryEntry>? surveyHistory,
    String? activeIntensiveCourseProductId,
    DateTime? intensiveCourseStartedAt,
    Map<String, List<String>>? intensiveApplicationLog,
    bool clearCarePlan = false,
    bool clearIntensiveCourse = false,
    bool clearAuth = false,
  }) {
    return UserModel(
      userId: clearAuth ? null : (userId ?? this.userId),
      name: name ?? this.name,
      email: email ?? this.email,
      authToken: clearAuth ? null : (authToken ?? this.authToken),
      isRegistered: isRegistered ?? this.isRegistered,
      hasCompletedSurvey: hasCompletedSurvey ?? this.hasCompletedSurvey,
      skinProfile: skinProfile ?? this.skinProfile,
      carePlan: clearCarePlan ? null : (carePlan ?? this.carePlan),
      lastSurveyCompletedAt:
          lastSurveyCompletedAt ?? this.lastSurveyCompletedAt,
      surveyHistory: surveyHistory ?? this.surveyHistory,
      activeIntensiveCourseProductId: clearIntensiveCourse
          ? null
          : (activeIntensiveCourseProductId ??
                this.activeIntensiveCourseProductId),
      intensiveCourseStartedAt: clearIntensiveCourse
          ? null
          : (intensiveCourseStartedAt ?? this.intensiveCourseStartedAt),
      intensiveApplicationLog: clearIntensiveCourse
          ? const <String, List<String>>{}
          : (intensiveApplicationLog ?? this.intensiveApplicationLog),
    );
  }

  List<ProductRecommendation> get intensiveProducts =>
      carePlan?.intensiveProducts ?? const <ProductRecommendation>[];

  ProductRecommendation? get activeIntensiveProduct {
    final productId = activeIntensiveCourseProductId;
    if (productId == null) {
      return null;
    }

    return carePlan?.findProductById(productId);
  }

  IntensiveCourseState? get intensiveCourseState {
    final productId = activeIntensiveCourseProductId;
    final startedAt = intensiveCourseStartedAt;
    if (productId == null || startedAt == null) {
      return null;
    }

    return IntensiveCourseState(
      productId: productId,
      startedAt: startedAt,
      applicationDates: intensiveApplicationLog[productId] ?? const <String>[],
    );
  }

  bool isIntensiveApplicationLogged(String productId, DateTime date) {
    final dayKey = formatCourseDayKey(date);
    final entries = intensiveApplicationLog[productId] ?? const <String>[];
    return entries.contains(dayKey);
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'authToken': authToken,
      'isRegistered': isRegistered,
      'hasCompletedSurvey': hasCompletedSurvey,
      'skinProfile': skinProfile?.toJson(),
      'carePlan': carePlan?.toJson(),
      'lastSurveyCompletedAt': lastSurveyCompletedAt?.toIso8601String(),
      'surveyHistory': surveyHistory.map((entry) => entry.toJson()).toList(),
      'activeIntensiveCourseProductId': activeIntensiveCourseProductId,
      'intensiveCourseStartedAt': intensiveCourseStartedAt?.toIso8601String(),
      'intensiveApplicationLog': intensiveApplicationLog,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: _readNullableInt(json['userId']),
      name: json['name'] as String?,
      email: json['email'] as String?,
      authToken: json['authToken'] as String?,
      isRegistered: _readBool(json['isRegistered']),
      hasCompletedSurvey: _readBool(json['hasCompletedSurvey']),
      skinProfile: json['skinProfile'] != null
          ? SkinProfile.fromJson(
              Map<String, dynamic>.from(json['skinProfile'] as Map),
            )
          : null,
      carePlan: json['carePlan'] != null
          ? CarePlan.fromJson(
              Map<String, dynamic>.from(json['carePlan'] as Map),
            )
          : null,
      lastSurveyCompletedAt: DateTime.tryParse(
        (json['lastSurveyCompletedAt'] ?? '').toString(),
      ),
      surveyHistory: (json['surveyHistory'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                SurveyHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      activeIntensiveCourseProductId:
          json['activeIntensiveCourseProductId'] as String?,
      intensiveCourseStartedAt: DateTime.tryParse(
        (json['intensiveCourseStartedAt'] ?? '').toString(),
      ),
      intensiveApplicationLog: _readStringListMap(
        json['intensiveApplicationLog'],
      ),
    );
  }
}

class SurveyHistoryEntry {
  final DateTime completedAt;
  final SkinProfile profileSnapshot;

  const SurveyHistoryEntry({
    required this.completedAt,
    required this.profileSnapshot,
  });

  Map<String, dynamic> toJson() {
    return {
      'completedAt': completedAt.toIso8601String(),
      'profileSnapshot': profileSnapshot.toJson(),
    };
  }

  factory SurveyHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SurveyHistoryEntry(
      completedAt:
          DateTime.tryParse((json['completedAt'] ?? '').toString()) ??
          DateTime.now(),
      profileSnapshot: SkinProfile.fromJson(
        Map<String, dynamic>.from(json['profileSnapshot'] ?? const {}),
      ),
    );
  }
}

class SkinProfile {
  final String skinType;
  final int age;
  final List<String> allergies;
  final String priceRange;

  const SkinProfile({
    required this.skinType,
    required this.age,
    this.allergies = const [],
    this.priceRange = 'средний',
  });

  Map<String, dynamic> toJson() {
    return {
      'skinType': skinType,
      'age': age,
      'allergies': allergies,
      'priceRange': priceRange,
    };
  }

  factory SkinProfile.fromJson(Map<String, dynamic> json) {
    return SkinProfile(
      skinType: (json['skinType'] ?? '').toString(),
      age: _readInt(json['age']),
      allergies: (json['allergies'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      priceRange: (json['priceRange'] ?? 'средний').toString(),
    );
  }
}

class CarePlan {
  final List<CareCategory> categories;
  final bool isPartial;
  final DateTime fetchedAt;
  final CarePlanMeta meta;

  const CarePlan({
    required this.categories,
    required this.isPartial,
    required this.fetchedAt,
    this.meta = const CarePlanMeta(),
  });

  bool get isEmpty => categories.isEmpty;

  List<ProductRecommendation> get intensiveProducts {
    final intensiveCategory = getCategoryByCode('intensive_renewal');
    return intensiveCategory?.products ?? const <ProductRecommendation>[];
  }

  CareCategory? getCategoryByCode(String categoryCode) {
    for (final category in categories) {
      if (category.categoryCode == categoryCode) {
        return category;
      }
    }
    return null;
  }

  ProductRecommendation? findProductById(String productId) {
    for (final category in categories) {
      for (final product in category.products) {
        if (product.productId == productId) {
          return product;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((category) => category.toJson()).toList(),
      'isPartial': isPartial,
      'fetchedAt': fetchedAt.toIso8601String(),
      'meta': meta.toJson(),
    };
  }

  factory CarePlan.fromJson(Map<String, dynamic> json) {
    return CarePlan(
      categories: (json['categories'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => CareCategory.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      isPartial: _readBool(json['isPartial']),
      fetchedAt:
          DateTime.tryParse((json['fetchedAt'] ?? '').toString()) ??
          DateTime.now(),
      meta: CarePlanMeta.fromJson(json['meta']),
    );
  }
}

class CarePlanMeta {
  final int totalCandidates;
  final int scoredCandidates;
  final int excludedByAllergy;

  const CarePlanMeta({
    this.totalCandidates = 0,
    this.scoredCandidates = 0,
    this.excludedByAllergy = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalCandidates': totalCandidates,
      'scoredCandidates': scoredCandidates,
      'excludedByAllergy': excludedByAllergy,
    };
  }

  factory CarePlanMeta.fromJson(Object? json) {
    if (json is! Map) {
      return const CarePlanMeta();
    }

    final data = Map<String, dynamic>.from(json);
    return CarePlanMeta(
      totalCandidates: _readInt(data['totalCandidates']),
      scoredCandidates: _readInt(data['scoredCandidates']),
      excludedByAllergy: _readInt(data['excludedByAllergy']),
    );
  }
}

class CareCategory {
  final String categoryCode;
  final String displayName;
  final List<ProductRecommendation> products;

  const CareCategory({
    required this.categoryCode,
    required this.displayName,
    required this.products,
  });

  Map<String, dynamic> toJson() {
    return {
      'categoryCode': categoryCode,
      'displayName': displayName,
      'products': products.map((product) => product.toJson()).toList(),
    };
  }

  factory CareCategory.fromJson(Map<String, dynamic> json) {
    return CareCategory(
      categoryCode: (json['categoryCode'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      products: (json['products'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                ProductRecommendation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class ProductRecommendation {
  final String productId;
  final String brand;
  final String productName;
  final String url;
  final UsageGuidance? usageGuidance;

  const ProductRecommendation({
    required this.productId,
    required this.brand,
    required this.productName,
    required this.url,
    this.usageGuidance,
  });

  bool get hasValidUrl {
    final parsedUrl = Uri.tryParse(url);
    return parsedUrl != null && parsedUrl.hasScheme && parsedUrl.hasAuthority;
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'brand': brand,
      'productName': productName,
      'url': url,
      'usageGuidance': usageGuidance?.toJson(),
    };
  }

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) {
    final brand = (json['brand'] ?? '').toString();
    final productName = (json['productName'] ?? json['name'] ?? '').toString();
    return ProductRecommendation(
      productId: (json['productId'] ?? '').toString().trim().isNotEmpty
          ? (json['productId'] as String).trim()
          : buildProductId(brand: brand, productName: productName),
      brand: brand,
      productName: productName,
      url: (json['url'] ?? '').toString(),
      usageGuidance: UsageGuidance.fromJsonOrNull(json['usageGuidance']),
    );
  }
}

class UsageGuidance {
  final String activeFamily;
  final String displayLabel;
  final IntroductionScheme introductionScheme;
  final List<CompatibilityConflict> conflicts;
  final List<String> applicationTips;

  const UsageGuidance({
    required this.activeFamily,
    required this.displayLabel,
    required this.introductionScheme,
    this.conflicts = const <CompatibilityConflict>[],
    this.applicationTips = const <String>[],
  });

  bool isPlannedDate({
    required DateTime courseStartedAt,
    required DateTime date,
  }) {
    return introductionScheme.isPlannedDate(
      courseStartedAt: courseStartedAt,
      date: date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeFamily': activeFamily,
      'displayLabel': displayLabel,
      'introductionScheme': introductionScheme.toJson(),
      'conflicts': conflicts.map((item) => item.toJson()).toList(),
      'applicationTips': applicationTips,
    };
  }

  static UsageGuidance? fromJsonOrNull(Object? json) {
    if (json is! Map) {
      return null;
    }

    final data = Map<String, dynamic>.from(json);
    final activeFamily = (data['activeFamily'] ?? '').toString().trim();
    final displayLabel = (data['displayLabel'] ?? '').toString().trim();
    if (activeFamily.isEmpty || displayLabel.isEmpty) {
      return null;
    }

    return UsageGuidance(
      activeFamily: activeFamily,
      displayLabel: displayLabel,
      introductionScheme: IntroductionScheme.fromJson(
        Map<String, dynamic>.from(data['introductionScheme'] ?? const {}),
      ),
      conflicts: (data['conflicts'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                CompatibilityConflict.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      applicationTips: (data['applicationTips'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class IntroductionScheme {
  final int cycleLengthDays;
  final List<IntroductionPhase> phases;
  final bool startWithEveningOnly;

  const IntroductionScheme({
    required this.cycleLengthDays,
    required this.phases,
    this.startWithEveningOnly = true,
  });

  IntroductionPhase? phaseForDate({
    required DateTime courseStartedAt,
    required DateTime date,
  }) {
    final normalizedStart = normalizeCourseDate(courseStartedAt);
    final normalizedDate = normalizeCourseDate(date);
    if (normalizedDate.isBefore(normalizedStart)) {
      return null;
    }

    final dayNumber = normalizedDate.difference(normalizedStart).inDays + 1;
    final weekNumber = ((dayNumber - 1) ~/ 7) + 1;

    for (final phase in phases) {
      if (phase.matches(dayNumber: dayNumber, weekNumber: weekNumber)) {
        return phase;
      }
    }

    return null;
  }

  bool isPlannedDate({
    required DateTime courseStartedAt,
    required DateTime date,
  }) {
    final phase = phaseForDate(courseStartedAt: courseStartedAt, date: date);
    if (phase == null) {
      return false;
    }

    final normalizedStart = normalizeCourseDate(courseStartedAt);
    final normalizedDate = normalizeCourseDate(date);
    final dayNumber = normalizedDate.difference(normalizedStart).inDays + 1;
    final cycleDay = ((dayNumber - 1) % cycleLengthDays) + 1;
    return phase.allowedCycleDays.contains(cycleDay);
  }

  Map<String, dynamic> toJson() {
    return {
      'cycleLengthDays': cycleLengthDays,
      'phases': phases.map((phase) => phase.toJson()).toList(),
      'startWithEveningOnly': startWithEveningOnly,
    };
  }

  factory IntroductionScheme.fromJson(Map<String, dynamic> json) {
    final cycleLength = _readInt(json['cycleLengthDays']);
    return IntroductionScheme(
      cycleLengthDays: cycleLength > 0 ? cycleLength : 7,
      phases: (json['phases'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                IntroductionPhase.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      startWithEveningOnly: json['startWithEveningOnly'] != false,
    );
  }
}

class IntroductionPhase {
  final int weekStart;
  final int? weekEnd;
  final int dayStart;
  final int? dayEnd;
  final List<int> allowedCycleDays;
  final String label;
  final String? note;

  const IntroductionPhase({
    required this.weekStart,
    required this.weekEnd,
    required this.dayStart,
    required this.dayEnd,
    required this.allowedCycleDays,
    required this.label,
    this.note,
  });

  bool matches({required int dayNumber, required int weekNumber}) {
    final isWeekMatch =
        weekNumber >= weekStart && (weekEnd == null || weekNumber <= weekEnd!);
    final isDayMatch =
        dayNumber >= dayStart && (dayEnd == null || dayNumber <= dayEnd!);
    return isWeekMatch && isDayMatch;
  }

  Map<String, dynamic> toJson() {
    return {
      'weekStart': weekStart,
      'weekEnd': weekEnd,
      'dayStart': dayStart,
      'dayEnd': dayEnd,
      'allowedCycleDays': allowedCycleDays,
      'label': label,
      'note': note,
    };
  }

  factory IntroductionPhase.fromJson(Map<String, dynamic> json) {
    return IntroductionPhase(
      weekStart: _readInt(json['weekStart']) == 0
          ? 1
          : _readInt(json['weekStart']),
      weekEnd: _readNullableInt(json['weekEnd']),
      dayStart: _readInt(json['dayStart']) == 0
          ? 1
          : _readInt(json['dayStart']),
      dayEnd: _readNullableInt(json['dayEnd']),
      allowedCycleDays: (json['allowedCycleDays'] as List<dynamic>? ?? [])
          .map(_readInt)
          .where((day) => day > 0)
          .toList(),
      label: (json['label'] ?? '').toString(),
      note: json['note']?.toString(),
    );
  }
}

class CompatibilityConflict {
  final String label;
  final String explanation;
  final List<String> categoryCodes;
  final List<String> activeFamilies;

  const CompatibilityConflict({
    required this.label,
    required this.explanation,
    this.categoryCodes = const <String>[],
    this.activeFamilies = const <String>[],
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'explanation': explanation,
      'categoryCodes': categoryCodes,
      'activeFamilies': activeFamilies,
    };
  }

  factory CompatibilityConflict.fromJson(Map<String, dynamic> json) {
    return CompatibilityConflict(
      label: (json['label'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString(),
      categoryCodes: (json['categoryCodes'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      activeFamilies: (json['activeFamilies'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class IntensiveCourseState {
  final String productId;
  final DateTime startedAt;
  final List<String> applicationDates;

  const IntensiveCourseState({
    required this.productId,
    required this.startedAt,
    this.applicationDates = const <String>[],
  });

  bool isAppliedOn(DateTime date) {
    return applicationDates.contains(formatCourseDayKey(date));
  }
}

String buildProductId({required String brand, required String productName}) {
  final base =
      '${brand.trim().toLowerCase()} ${productName.trim().toLowerCase()}';
  final normalized = base.replaceAll(RegExp(r'[^0-9a-zа-яё]+'), '-');
  final compact = normalized
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return compact.isEmpty ? 'product' : compact;
}

DateTime normalizeCourseDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String formatCourseDayKey(DateTime date) {
  final normalizedDate = normalizeCourseDate(date);
  final month = normalizedDate.month.toString().padLeft(2, '0');
  final day = normalizedDate.day.toString().padLeft(2, '0');
  return '${normalizedDate.year}-$month-$day';
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

int? _readNullableInt(Object? value) {
  final parsed = _readInt(value);
  return parsed == 0 ? null : parsed;
}

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is String) {
    return value.toLowerCase() == 'true';
  }

  return false;
}

Map<String, List<String>> _readStringListMap(Object? value) {
  if (value is! Map) {
    return const <String, List<String>>{};
  }

  final result = <String, List<String>>{};
  for (final entry in value.entries) {
    final key = entry.key.toString();
    final rawList = entry.value;
    if (rawList is! List) {
      continue;
    }

    final items =
        rawList
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    result[key] = items;
  }

  return result;
}
