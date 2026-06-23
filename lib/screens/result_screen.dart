import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/care_plan_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';
import 'app_shell.dart';

enum _ResultViewState {
  loading,
  noProfile,
  backendNotConfigured,
  backendUnavailable,
  backendUnavailableWithCache,
  emptyResult,
  ready,
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, this.onOpenProductUrl});

  final Future<void> Function(String url)? onOpenProductUrl;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isLoading = true;
  bool _usedCachedPlan = false;
  CarePlan? _carePlan;
  _ResultViewState _viewState = _ResultViewState.loading;

  @override
  void initState() {
    super.initState();
    _loadCarePlan();
  }

  Future<void> _loadCarePlan() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final userService = context.read<UserService>();
    final skinProfile = userService.user.skinProfile;

    if (skinProfile == null) {
      setState(() {
        _isLoading = false;
        _viewState = _ResultViewState.noProfile;
        _carePlan = null;
        _usedCachedPlan = false;
      });
      return;
    }

    final cachedPlan = userService.user.carePlan;

    final carePlanService = context.read<CarePlanService>();
    final result = await carePlanService.fetchPlanResult(skinProfile);

    if (!mounted) {
      return;
    }

    switch (result.status) {
      case CarePlanFetchStatus.success:
        final carePlan = result.plan!;
        await userService.saveCarePlan(carePlan);
        if (!mounted) {
          return;
        }

        setState(() {
          _carePlan = carePlan;
          _usedCachedPlan = false;
          _isLoading = false;
          _viewState = _ResultViewState.ready;
        });
      case CarePlanFetchStatus.emptyResult:
        final carePlan = result.plan!;
        await userService.saveCarePlan(carePlan);
        if (!mounted) {
          return;
        }

        setState(() {
          _carePlan = carePlan;
          _usedCachedPlan = false;
          _isLoading = false;
          _viewState = _ResultViewState.emptyResult;
        });
      case CarePlanFetchStatus.backendNotConfigured:
        setState(() {
          _carePlan = null;
          _usedCachedPlan = false;
          _isLoading = false;
          _viewState = _ResultViewState.backendNotConfigured;
        });
      case CarePlanFetchStatus.requestFailed:
        final hasCachedCategories =
            cachedPlan?.categories.any(
              (category) => category.products.isNotEmpty,
            ) ??
            false;

        setState(() {
          _carePlan = hasCachedCategories ? cachedPlan : null;
          _usedCachedPlan = hasCachedCategories;
          _isLoading = false;
          _viewState = hasCachedCategories
              ? _ResultViewState.backendUnavailableWithCache
              : _ResultViewState.backendUnavailable;
        });
    }
  }

  Future<void> _handleProductTap(String url) async {
    if (widget.onOpenProductUrl != null) {
      await widget.onOpenProductUrl!(url);
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Открыть ссылку: $url'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openCourse(ProductRecommendation product) async {
    final userService = context.read<UserService>();
    final activeProductId = userService.user.activeIntensiveCourseProductId;
    if (activeProductId == null) {
      await userService.selectActiveIntensiveCourse(product.productId);
    } else if (activeProductId != product.productId) {
      if (!mounted) {
        return;
      }

      final activeProductName =
          userService.user.activeIntensiveProduct?.productName ??
          'текущий интенсивный курс';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сейчас активен курс "$activeProductName". Сначала завершите или сбросьте его на экране курса.',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final shell = AppShell.maybeOf(context);
    if (shell != null) {
      await shell.openIntensiveCourse();
      return;
    }

    await Navigator.pushNamed(context, '/course');
  }

  void _openBackendSettings() {
    Navigator.pushNamed(context, '/backend');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<UserService>().user;
    final profile = user.skinProfile;
    final content = AppPageBody(
      width: AppPageWidth.wide,
      topSafeArea: AppShell.maybeOf(context) == null,
      child: _buildContent(context, isDark, profile),
    );

    if (AppShell.maybeOf(context) != null) {
      return content;
    }

    return Scaffold(body: content);
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    SkinProfile? profile,
  ) {
    if (_isLoading) {
      return _buildScrollableLayout(
        context,
        isDark,
        profile,
        child: const SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(key: Key('result_loading')),
          ),
        ),
      );
    }

    switch (_viewState) {
      case _ResultViewState.noProfile:
        return _buildScrollableLayout(
          context,
          isDark,
          profile,
          child: _DiagnosticState(
            key: const Key('result_no_profile'),
            isDark: isDark,
            icon: Icons.assignment_outlined,
            title: 'Сначала пройдите опрос',
            message:
                'Без анкеты мы не сможем подобрать уход и отправить запрос в сервис рекомендаций.',
            onRetry: _loadCarePlan,
            onRestartSurvey: _openSurvey,
          ),
        );
      case _ResultViewState.backendNotConfigured:
        return _buildScrollableLayout(
          context,
          isDark,
          profile,
          child: _DiagnosticState(
            key: const Key('result_backend_not_configured'),
            isDark: isDark,
            icon: Icons.settings_ethernet_outlined,
            title: 'Сервис рекомендаций не подключён',
            message:
                'Приложение запущено без конфигурации backend. Укажите адрес сервиса рекомендаций и повторите загрузку.',
            onRetry: _loadCarePlan,
            onRestartSurvey: _openSurvey,
            onConfigureBackend: _openBackendSettings,
          ),
        );
      case _ResultViewState.backendUnavailable:
        return _buildScrollableLayout(
          context,
          isDark,
          profile,
          child: _DiagnosticState(
            key: const Key('result_backend_unavailable'),
            isDark: isDark,
            icon: Icons.wifi_off_rounded,
            title: 'Сервис рекомендаций недоступен',
            message:
                'Не удалось получить план ухода с backend. Проверьте, что сервис запущен, и повторите попытку.',
            onRetry: _loadCarePlan,
            onRestartSurvey: _openSurvey,
            onConfigureBackend: _openBackendSettings,
          ),
        );
      case _ResultViewState.emptyResult:
        return _buildScrollableLayout(
          context,
          isDark,
          profile,
          child: _EmptyState(
            isDark: isDark,
            carePlan: _carePlan,
            onRetry: _loadCarePlan,
            onRestartSurvey: _openSurvey,
          ),
        );
      case _ResultViewState.ready:
      case _ResultViewState.backendUnavailableWithCache:
        break;
      case _ResultViewState.loading:
        return const SizedBox.shrink();
    }

    final carePlan = _carePlan;
    final categories =
        carePlan?.categories
            .where((category) => category.products.isNotEmpty)
            .toList() ??
        <CareCategory>[];

    if (categories.isEmpty) {
      return _buildScrollableLayout(
        context,
        isDark,
        profile,
        child: _EmptyState(
          isDark: isDark,
          carePlan: carePlan,
          onRetry: _loadCarePlan,
          onRestartSurvey: _openSurvey,
        ),
      );
    }

    final hasPartial = (carePlan?.isPartial ?? false) || _usedCachedPlan;

    return _buildScrollableLayout(
      context,
      isDark,
      profile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_viewState == _ResultViewState.backendUnavailableWithCache)
            _CachedPlanBanner(
              key: const Key('result_cached_warning'),
              isDark: isDark,
            )
          else if (hasPartial)
            _PartialStateBanner(
              key: const Key('result_partial'),
              isDark: isDark,
              message: _buildPartialMessage(carePlan),
            ),
          for (final category in categories) ...[
            _CategorySection(
              key: Key('category_${category.categoryCode}'),
              category: category,
              isDark: isDark,
              onProductTap: _handleProductTap,
              onStartCourse: category.categoryCode == 'intensive_renewal'
                  ? _openCourse
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          _CautionBanner(isDark: isDark, profile: profile),
          if (_viewState == _ResultViewState.backendUnavailableWithCache) ...[
            const SizedBox(height: 16),
            _ResultActions(
              isDark: isDark,
              onRetry: _loadCarePlan,
              onRestartSurvey: _openSurvey,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrollableLayout(
    BuildContext context,
    bool isDark,
    SkinProfile? profile, {
    required Widget child,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: _ResultHero(
              key: const Key('result_hero'),
              isDark: isDark,
              profile: profile,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _openSurvey() async {
    if (!mounted) {
      return;
    }

    await Navigator.pushNamed(context, '/survey');
  }

  String _buildPartialMessage(CarePlan? carePlan) {
    final meta = carePlan?.meta ?? const CarePlanMeta();
    if (meta.excludedByAllergy > 0) {
      return 'Часть кандидатов исключена из-за аллергий, поэтому показаны только совместимые рекомендации.';
    }

    if (meta.totalCandidates > meta.scoredCandidates &&
        meta.scoredCandidates > 0) {
      return 'Backend вернул неполный результат: часть кандидатов не прошла фильтрацию или не была оценена.';
    }

    return 'Часть рекомендаций недоступна, поэтому показаны только валидные категории и товары.';
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({super.key, required this.isDark, required this.profile});

  final bool isDark;
  final SkinProfile? profile;

  @override
  Widget build(BuildContext context) {
    final eyebrowColor = AppColors.warmBrownForegroundMuted.withValues(
      alpha: isDark ? 0.86 : 0.78,
    );

    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      backgroundColor: isDark
          ? AppColors.warmBrownSurfaceDark
          : AppColors.warmBrownSurface,
      borderColor: isDark
          ? AppColors.warmBrownBorderDark
          : AppColors.warmBrownBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ВАШИ РЕЗУЛЬТАТЫ',
            style: TextStyle(
              fontSize: 15,
              letterSpacing: 0.9,
              color: eyebrowColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Персональный план ухода',
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: AppColors.warmBrownForeground,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProfileChip(
                text:
                    'Тип кожи: ${_capitalize(profile?.skinType ?? 'не указан')}',
                isDark: isDark,
              ),
              _ProfileChip(
                text: 'Возраст: ${_profileAgeText(profile)}',
                isDark: isDark,
              ),
              _ProfileChip(
                text: 'Исключено: ${_excludedIngredientsText(profile)}',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warmBrownChipDark : AppColors.warmBrownChip,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? AppColors.warmBrownChipBorderDark
              : AppColors.warmBrownChipBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: AppColors.warmBrownChipText),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    super.key,
    required this.category,
    required this.isDark,
    required this.onProductTap,
    this.onStartCourse,
  });

  final CareCategory category;
  final bool isDark;
  final Future<void> Function(String url) onProductTap;
  final Future<void> Function(ProductRecommendation product)? onStartCourse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.displayName.toUpperCase(),
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 0.5,
            color: isDark ? AppColors.neutral500Dark : AppColors.neutral700,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < category.products.length; index++) ...[
          _ProductCard(
            key: Key('product_${category.categoryCode}_$index'),
            product: category.products[index],
            isDark: isDark,
            categoryCode: category.categoryCode,
            index: index,
            onTap: onProductTap,
            onStartCourse: onStartCourse,
          ),
          if (index != category.products.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    super.key,
    required this.product,
    required this.isDark,
    required this.categoryCode,
    required this.index,
    required this.onTap,
    this.onStartCourse,
  });

  final ProductRecommendation product;
  final bool isDark;
  final String categoryCode;
  final int index;
  final Future<void> Function(String url) onTap;
  final Future<void> Function(ProductRecommendation product)? onStartCourse;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _iconBackground(isDark, categoryCode),
                ),
                child: Icon(
                  _iconForCategory(categoryCode),
                  size: 24,
                  color: _iconColor(isDark, categoryCode),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.neutral500Dark
                            : AppColors.neutral500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.productName,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.neutral900Dark
                            : AppColors.neutral900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '✓ Подходит',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF94D0BC)
                      : const Color(0xFF74B59F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TagChip(
                text: product.brand.isEmpty ? 'Бренд' : product.brand,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        key: Key('open_${categoryCode}_$index'),
                        onPressed: product.hasValidUrl
                            ? () => onTap(product.url)
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.rose400Dark
                              : const Color(0xFFD6608D),
                          backgroundColor: isDark
                              ? AppColors.neutral100Dark
                              : const Color(0xFFF6EFF3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          product.hasValidUrl ? 'Ссылка' : 'Без ссылки',
                        ),
                      ),
                      if (onStartCourse != null)
                        TextButton(
                          key: Key('track_${product.productId}'),
                          onPressed: () => onStartCourse!(product),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? const Color(0xFFFFC68F)
                                : const Color(0xFFC96A1A),
                            backgroundColor: isDark
                                ? const Color(0xFF3D3025)
                                : const Color(0xFFF6E5D6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Вести курс'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String categoryCode) {
    switch (categoryCode) {
      case 'cleansing':
        return Icons.water_drop_outlined;
      case 'moisturizing':
        return Icons.spa_outlined;
      case 'intensive_renewal':
        return Icons.autorenew_rounded;
      case 'serums_masks':
        return Icons.bolt_outlined;
      case 'eye_cream':
        return Icons.remove_red_eye_outlined;
      case 'spf':
        return Icons.wb_sunny_outlined;
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  Color _iconBackground(bool isDark, String categoryCode) {
    switch (categoryCode) {
      case 'cleansing':
        return isDark ? AppColors.rose50Dark : const Color(0xFFF7DCE8);
      case 'moisturizing':
        return isDark ? AppColors.blue50Dark : const Color(0xFFEAF4FF);
      case 'intensive_renewal':
        return isDark ? const Color(0xFF3D3025) : const Color(0xFFF6E5D6);
      case 'spf':
        return isDark ? const Color(0xFF30402A) : const Color(0xFFEAF5D8);
      default:
        return isDark ? AppColors.neutral100Dark : const Color(0xFFF1ECE8);
    }
  }

  Color _iconColor(bool isDark, String categoryCode) {
    switch (categoryCode) {
      case 'cleansing':
        return isDark ? AppColors.rose400Dark : const Color(0xFFD6608D);
      case 'moisturizing':
      case 'serums_masks':
        return isDark ? AppColors.blue400Dark : AppColors.blue500;
      case 'intensive_renewal':
        return isDark ? const Color(0xFFFFC68F) : const Color(0xFFC96A1A);
      case 'spf':
        return isDark ? const Color(0xFFCBEA8A) : const Color(0xFF7FA047);
      default:
        return isDark ? AppColors.neutral700Dark : AppColors.neutral700;
    }
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral100Dark : const Color(0xFFF2EFF4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.neutral700Dark : AppColors.neutral700,
        ),
      ),
    );
  }
}

class _CautionBanner extends StatelessWidget {
  const _CautionBanner({required this.isDark, required this.profile});

  final bool isDark;
  final SkinProfile? profile;

  @override
  Widget build(BuildContext context) {
    final hasSensitiveHints =
        profile?.allergies.isNotEmpty == true ||
        (profile?.skinType.toLowerCase().contains('чувств') ?? false);

    final text = hasSensitiveHints
        ? 'Активные кислоты и ретинол вводите постепенно. Следите за реакцией кожи.'
        : 'Ретинол и кислоты лучше использовать вечером и не сочетать с витамином C в один уход.';

    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: isDark
          ? const Color(0xFF3B342F)
          : const Color(0xFFEFE1D0),
      shadowOpacity: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: isDark ? const Color(0xFFE8D1B7) : const Color(0xFF756355),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark
                    ? const Color(0xFFF4E8DA)
                    : const Color(0xFF5D4D42),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartialStateBanner extends StatelessWidget {
  const _PartialStateBanner({
    super.key,
    required this.isDark,
    required this.message,
  });

  final bool isDark;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: isDark ? AppColors.blue50Dark : const Color(0xFFEAF4FF),
      shadowOpacity: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: isDark ? AppColors.blue400Dark : AppColors.blue500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: isDark ? AppColors.blue400Dark : AppColors.blue500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CachedPlanBanner extends StatelessWidget {
  const _CachedPlanBanner({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: isDark
          ? const Color(0xFF3C312E)
          : const Color(0xFFF4E7D7),
      shadowOpacity: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: isDark ? const Color(0xFFF2D0A5) : const Color(0xFF8B644A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Backend сейчас недоступен, поэтому показываем последний сохранённый план ухода.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: isDark
                    ? const Color(0xFFFFE6C7)
                    : const Color(0xFF7A5944),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticState extends StatelessWidget {
  const _DiagnosticState({
    super.key,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onRestartSurvey,
    this.onConfigureBackend,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRestartSurvey;
  final VoidCallback? onConfigureBackend;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 30,
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _ResultActions(
              isDark: isDark,
              onRetry: onRetry,
              onRestartSurvey: onRestartSurvey,
              onConfigureBackend: onConfigureBackend,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isDark,
    required this.carePlan,
    required this.onRetry,
    required this.onRestartSurvey,
  });

  final bool isDark;
  final CarePlan? carePlan;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRestartSurvey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppSurfaceCard(
        key: const Key('result_empty'),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 30,
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
            ),
            const SizedBox(height: 12),
            Text(
              'Подходящие товары не найдены',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _buildEmptyMessage(carePlan?.meta ?? const CarePlanMeta()),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _ResultActions(
              isDark: isDark,
              onRetry: onRetry,
              onRestartSurvey: onRestartSurvey,
            ),
          ],
        ),
      ),
    );
  }

  String _buildEmptyMessage(CarePlanMeta meta) {
    if (meta.totalCandidates == 0) {
      return 'После фильтрации по типу кожи, возрасту и ценовому сегменту не осталось подходящих кандидатов.';
    }

    if (meta.scoredCandidates == 0) {
      if (meta.excludedByAllergy > 0) {
        return 'Кандидаты нашлись, но были исключены по ограничениям, например из-за аллергий.';
      }

      return 'Кандидаты нашлись, но backend не смог отобрать совместимые рекомендации по текущим фильтрам.';
    }

    return 'Backend ответил без валидных категорий. Попробуйте повторить запрос или пройти опрос заново.';
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.isDark,
    required this.onRetry,
    required this.onRestartSurvey,
    this.onConfigureBackend,
  });

  final bool isDark;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRestartSurvey;
  final VoidCallback? onConfigureBackend;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        if (onConfigureBackend != null)
          OutlinedButton(
            key: const Key('result_backend_settings_button'),
            onPressed: onConfigureBackend,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.neutral900Dark
                  : AppColors.neutral900,
              side: BorderSide(
                color: isDark
                    ? AppColors.neutral100Dark
                    : const Color(0xFFD9D2CC),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Настроить backend'),
          ),
        OutlinedButton(
          key: const Key('result_retry_button'),
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark
                ? AppColors.neutral900Dark
                : AppColors.neutral900,
            side: BorderSide(
              color: isDark
                  ? AppColors.neutral100Dark
                  : const Color(0xFFD9D2CC),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Повторить'),
        ),
        ElevatedButton(
          key: const Key('result_restart_survey_button'),
          onPressed: onRestartSurvey,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.rose400Dark
                : const Color(0xFFD6608D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Пройти опрос заново'),
        ),
      ],
    );
  }
}

String _profileAgeText(SkinProfile? profile) {
  if (profile == null || profile.age <= 0) {
    return 'не указан';
  }

  final age = profile.age;
  final mod100 = age % 100;
  final mod10 = age % 10;
  if (mod10 == 1 && mod100 != 11) {
    return '$age год';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$age года';
  }
  return '$age лет';
}

String _excludedIngredientsText(SkinProfile? profile) {
  if (profile == null || profile.allergies.isEmpty) {
    return 'ничего';
  }

  return profile.allergies.map(_normalizeAllergyLabel).join(', ');
}

String _normalizeAllergyLabel(String value) {
  return value.replaceFirst(RegExp(r'^на\s+', caseSensitive: false), '');
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}
