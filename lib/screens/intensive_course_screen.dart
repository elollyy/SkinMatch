import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';
import 'app_shell.dart';

class IntensiveCourseScreen extends StatefulWidget {
  const IntensiveCourseScreen({super.key});

  @override
  State<IntensiveCourseScreen> createState() => _IntensiveCourseScreenState();
}

class _IntensiveCourseScreenState extends State<IntensiveCourseScreen> {
  late DateTime _displayMonth;
  late DateTime _selectedDate;
  bool _isGuidanceExpanded = false;

  @override
  void initState() {
    super.initState();
    final today = normalizeCourseDate(DateTime.now());
    _displayMonth = DateTime(today.year, today.month);
    _selectedDate = today;
  }

  Future<void> _selectCourse(UserService userService, String productId) async {
    final today = normalizeCourseDate(DateTime.now());
    setState(() {
      _selectedDate = today;
      _displayMonth = DateTime(today.year, today.month);
    });
    await userService.selectActiveIntensiveCourse(productId, startedAt: today);
  }

  Future<void> _clearCourse(UserService userService) async {
    await userService.clearActiveIntensiveCourse();
    if (!mounted) {
      return;
    }

    final today = normalizeCourseDate(DateTime.now());
    setState(() {
      _selectedDate = today;
      _displayMonth = DateTime(today.year, today.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userService = context.watch<UserService>();
    final user = userService.user;
    final content = AppPageBody(
      width: AppPageWidth.wide,
      topSafeArea: AppShell.maybeOf(context) == null,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _CourseHero(isDark: isDark),
          const SizedBox(height: 16),
          _buildBody(context, isDark, userService, user),
        ],
      ),
    );

    if (AppShell.maybeOf(context) != null) {
      return content;
    }

    return Scaffold(body: content);
  }

  Widget _buildBody(
    BuildContext context,
    bool isDark,
    UserService userService,
    UserModel user,
  ) {
    final intensiveProducts = user.intensiveProducts;
    if (intensiveProducts.isEmpty) {
      return _EmptyCourseState(isDark: isDark);
    }

    final activeProduct = user.activeIntensiveProduct;
    if (activeProduct == null) {
      return _CourseChooser(
        isDark: isDark,
        products: intensiveProducts,
        onSelect: (product) => _selectCourse(userService, product.productId),
      );
    }

    final startedAt =
        user.intensiveCourseStartedAt ?? normalizeCourseDate(DateTime.now());
    final guidance = activeProduct.usageGuidance;
    final isPlannedDay =
        guidance?.isPlannedDate(
          courseStartedAt: startedAt,
          date: _selectedDate,
        ) ??
        false;
    final phase = guidance?.introductionScheme.phaseForDate(
      courseStartedAt: startedAt,
      date: _selectedDate,
    );

    return _CourseDashboard(
      isDark: isDark,
      product: activeProduct,
      startedAt: startedAt,
      alternativeProducts: intensiveProducts
          .where((product) => product.productId != activeProduct.productId)
          .toList(),
      guidance: guidance,
      selectedDate: _selectedDate,
      phase: phase,
      isGuidanceExpanded: _isGuidanceExpanded,
      onToggleGuidance: () {
        setState(() {
          _isGuidanceExpanded = !_isGuidanceExpanded;
        });
      },
      onResetCourse: () => _clearCourse(userService),
      calendar: _CalendarCard(
        isDark: isDark,
        displayMonth: _displayMonth,
        selectedDate: _selectedDate,
        product: activeProduct,
        startedAt: startedAt,
        appliedDays:
            user.intensiveApplicationLog[activeProduct.productId] ??
            const <String>[],
        onSelectDate: (date) {
          setState(() {
            _selectedDate = date;
            _displayMonth = DateTime(date.year, date.month);
          });
        },
        onPreviousMonth: () {
          setState(() {
            _displayMonth = DateTime(
              _displayMonth.year,
              _displayMonth.month - 1,
            );
          });
        },
        onNextMonth: () {
          setState(() {
            _displayMonth = DateTime(
              _displayMonth.year,
              _displayMonth.month + 1,
            );
          });
        },
        onToggleSelectedDay: () async {
          final messenger = ScaffoldMessenger.of(context);
          await userService.toggleIntensiveApplication(
            activeProduct.productId,
            _selectedDate,
          );
          if (!mounted || isPlannedDay) {
            return;
          }
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Отметка сохранена. Этот день вне базовой схемы введения.',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CourseHero extends StatelessWidget {
  const _CourseHero({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
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
            'КУРС',
            style: TextStyle(
              fontSize: 15,
              letterSpacing: 0.9,
              color: AppColors.warmBrownForegroundMuted.withValues(
                alpha: isDark ? 0.86 : 0.78,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Интенсивное обновление',
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
            children: const [
              _HeroInfoChip(label: '1 активный курс'),
              _HeroInfoChip(label: 'Календарь + отметки'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCourseState extends StatelessWidget {
  const _EmptyCourseState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      key: const Key('course_empty_state'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('В текущем плане ухода нет категории "Интенсивное обновление".'),
          SizedBox(height: 8),
          Text(
            'Пройдите опрос заново или дождитесь рекомендаций с активным курсом, чтобы вести календарь нанесений.',
          ),
        ],
      ),
    );
  }
}

class _CourseChooser extends StatelessWidget {
  const _CourseChooser({
    required this.isDark,
    required this.products,
    required this.onSelect,
  });

  final bool isDark;
  final List<ProductRecommendation> products;
  final ValueChanged<ProductRecommendation> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      key: const Key('course_selector'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Режим курса',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 0.5,
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            products.length == 1
                ? 'Подключите продукт к курсу'
                : 'Выберите один активный курс',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Параллельно можно вести только один интенсивный продукт. Смена станет доступна после сброса текущего курса.',
            style: TextStyle(
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
            ),
          ),
          const SizedBox(height: 14),
          for (final product in products) ...[
            _ChooserProductCard(
              isDark: isDark,
              product: product,
              onTap: () => onSelect(product),
            ),
            if (product != products.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ChooserProductCard extends StatelessWidget {
  const _ChooserProductCard({
    required this.isDark,
    required this.product,
    required this.onTap,
  });

  final bool isDark;
  final ProductRecommendation product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('select_course_${product.productId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.warmBrownInsetDark
              : AppColors.warmBrownInset,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.warmBrownInsetBorderDark
                : AppColors.warmBrownInsetBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.warmBrownSurfaceDark.withValues(alpha: 0.72)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.autorenew_rounded,
                color: isDark
                    ? AppColors.warmBrownForeground
                    : AppColors.warmBrownSurface,
              ),
            ),
            const SizedBox(width: 12),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (product.usageGuidance != null) ...[
                    const SizedBox(height: 4),
                    _InfoPill(
                      label: product.usageGuidance!.displayLabel,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Выбрать',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.neutral900Dark : AppColors.neutral900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseDashboard extends StatelessWidget {
  const _CourseDashboard({
    required this.isDark,
    required this.product,
    required this.startedAt,
    required this.alternativeProducts,
    required this.guidance,
    required this.selectedDate,
    required this.phase,
    required this.isGuidanceExpanded,
    required this.onToggleGuidance,
    required this.onResetCourse,
    required this.calendar,
  });

  final bool isDark;
  final ProductRecommendation product;
  final DateTime startedAt;
  final List<ProductRecommendation> alternativeProducts;
  final UsageGuidance? guidance;
  final DateTime selectedDate;
  final IntroductionPhase? phase;
  final bool isGuidanceExpanded;
  final VoidCallback onToggleGuidance;
  final Future<void> Function() onResetCourse;
  final Widget calendar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = constraints.maxWidth >= 820;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (useSplitLayout)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 10,
                    child: _CourseProductCard(
                      isDark: isDark,
                      product: product,
                      startedAt: startedAt,
                      alternativeProducts: alternativeProducts,
                      onResetCourse: onResetCourse,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 11,
                    child: _CourseInformationCard(
                      isDark: isDark,
                      guidance: guidance,
                      selectedDate: selectedDate,
                      phase: phase,
                      isGuidanceExpanded: isGuidanceExpanded,
                      onToggleGuidance: onToggleGuidance,
                    ),
                  ),
                ],
              )
            else ...[
              _CourseProductCard(
                isDark: isDark,
                product: product,
                startedAt: startedAt,
                alternativeProducts: alternativeProducts,
                onResetCourse: onResetCourse,
              ),
              const SizedBox(height: 14),
              _CourseInformationCard(
                isDark: isDark,
                guidance: guidance,
                selectedDate: selectedDate,
                phase: phase,
                isGuidanceExpanded: isGuidanceExpanded,
                onToggleGuidance: onToggleGuidance,
              ),
            ],
            const SizedBox(height: 14),
            calendar,
          ],
        );
      },
    );
  }
}

class _CourseProductCard extends StatelessWidget {
  const _CourseProductCard({
    required this.isDark,
    required this.product,
    required this.startedAt,
    required this.alternativeProducts,
    required this.onResetCourse,
  });

  final bool isDark;
  final ProductRecommendation product;
  final DateTime startedAt;
  final List<ProductRecommendation> alternativeProducts;
  final Future<void> Function() onResetCourse;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      key: const Key('course_product_card'),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useWideHeader = constraints.maxWidth >= 560;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Активный продукт',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.4,
                  color: isDark
                      ? AppColors.neutral500Dark
                      : AppColors.neutral700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.productName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Курс привязан к одному продукту. После сброса можно сразу переключиться на альтернативу.',
                style: TextStyle(
                  height: 1.4,
                  color: isDark
                      ? AppColors.neutral500Dark
                      : AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(label: product.brand, isDark: isDark),
                  _InfoPill(
                    label:
                        product.usageGuidance?.displayLabel ??
                        'Интенсивный актив',
                    isDark: isDark,
                  ),
                  _InfoPill(
                    label: 'Старт ${_formatDate(startedAt)}',
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (useWideHeader)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CourseMetaBlock(
                        isDark: isDark,
                        product: product,
                        startedAt: startedAt,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _ResetCourseButton(onResetCourse: onResetCourse),
                  ],
                )
              else ...[
                _CourseMetaBlock(
                  isDark: isDark,
                  product: product,
                  startedAt: startedAt,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: _ResetCourseButton(onResetCourse: onResetCourse),
                ),
              ],
              if (alternativeProducts.isNotEmpty) ...[
                const SizedBox(height: 16),
                _InformationInset(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Альтернативы после сброса',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.neutral900Dark
                              : AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final alternative in alternativeProducts) ...[
                        _AlternativeProductRow(
                          isDark: isDark,
                          product: alternative,
                        ),
                        if (alternative != alternativeProducts.last)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CourseInformationCard extends StatelessWidget {
  const _CourseInformationCard({
    required this.isDark,
    required this.guidance,
    required this.selectedDate,
    required this.phase,
    required this.isGuidanceExpanded,
    required this.onToggleGuidance,
  });

  final bool isDark;
  final UsageGuidance? guidance;
  final DateTime selectedDate;
  final IntroductionPhase? phase;
  final bool isGuidanceExpanded;
  final VoidCallback onToggleGuidance;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      key: const Key('course_information_card'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Схема и ограничения',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 0.4,
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Сначала сверяйтесь с фазой курса, затем проверяйте сочетания и технику нанесения.',
            style: TextStyle(
              height: 1.4,
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
            ),
          ),
          const SizedBox(height: 14),
          guidance == null
              ? _InformationInset(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SectionLabel(title: 'Как вводить'),
                      SizedBox(height: 8),
                      Text('Для этого курса нет детализированной схемы.'),
                    ],
                  ),
                )
              : _UsageGuidanceAccordion(
                  isDark: isDark,
                  guidance: guidance!,
                  selectedDate: selectedDate,
                  phase: phase,
                  isExpanded: isGuidanceExpanded,
                  onToggle: onToggleGuidance,
                ),
          const SizedBox(height: 12),
          _InformationInset(
            key: const Key('course_notes_card'),
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel(title: 'С чем не сочетать'),
                const SizedBox(height: 10),
                if (guidance == null)
                  const Text(
                    'Ориентируйтесь на общее правило: не совмещать с другими сильными активами.',
                  )
                else if (guidance!.conflicts.isEmpty)
                  const Text('Явные конфликты для этого курса не указаны.')
                else
                  for (final conflict in guidance!.conflicts)
                    _ConflictRow(isDark: isDark, conflict: conflict),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark
                      ? AppColors.neutral100Dark
                      : AppColors.neutral100,
                ),
                const SizedBox(height: 12),
                const _SectionLabel(title: 'Рекомендации по нанесению'),
                const SizedBox(height: 10),
                if (guidance == null)
                  const Text('Наносите вечером и отслеживайте реакцию кожи.')
                else if (guidance!.applicationTips.isEmpty)
                  const Text(
                    'Следуйте базовой вечерней схеме и отслеживайте реакцию кожи.',
                  )
                else
                  for (final tip in guidance!.applicationTips)
                    _TipRow(isDark: isDark, text: tip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.warmBrownChip,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warmBrownChipBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.warmBrownChipText,
        ),
      ),
    );
  }
}

class _CourseMetaBlock extends StatelessWidget {
  const _CourseMetaBlock({
    required this.isDark,
    required this.product,
    required this.startedAt,
  });

  final bool isDark;
  final ProductRecommendation product;
  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    return _InformationInset(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CourseMetaItem(label: 'Бренд', value: product.brand),
          const SizedBox(height: 10),
          _CourseMetaItem(
            label: 'Тип актива',
            value: product.usageGuidance?.displayLabel ?? 'Интенсивный актив',
          ),
          const SizedBox(height: 10),
          _CourseMetaItem(label: 'Дата старта', value: _formatDate(startedAt)),
        ],
      ),
    );
  }
}

class _CourseMetaItem extends StatelessWidget {
  const _CourseMetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.neutral500Dark
                  : AppColors.neutral500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ResetCourseButton extends StatelessWidget {
  const _ResetCourseButton({required this.onResetCourse});

  final Future<void> Function() onResetCourse;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('course_reset_button'),
      onPressed: onResetCourse,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: const Text('Сбросить курс'),
    );
  }
}

class _InformationInset extends StatelessWidget {
  const _InformationInset({
    super.key,
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.warmBrownInsetDark : AppColors.warmBrownInset,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? AppColors.warmBrownInsetBorderDark
              : AppColors.warmBrownInsetBorder,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    );
  }
}

class _AlternativeProductRow extends StatelessWidget {
  const _AlternativeProductRow({required this.isDark, required this.product});

  final bool isDark;
  final ProductRecommendation product;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('course_alternative_${product.productId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neutral100Dark.withValues(alpha: 0.72)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.neutral100Dark : AppColors.neutral100,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  product.brand,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.neutral500Dark
                        : AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'После сброса',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.warmBrownChipText,
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.isDark,
    required this.phase,
    required this.cycleLengthDays,
  });

  final bool isDark;
  final IntroductionPhase phase;
  final int cycleLengthDays;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFD6608D),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _buildPhaseRule(phase, cycleLengthDays),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (phase.label.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    phase.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.neutral500Dark
                          : AppColors.neutral500,
                    ),
                  ),
                ],
                if (phase.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    phase.note!,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.neutral500Dark
                          : AppColors.neutral500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({required this.isDark, required this.conflict});

  final bool isDark;
  final CompatibilityConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conflict.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            conflict.explanation,
            style: TextStyle(
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.isDark, required this.text});

  final bool isDark;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: isDark ? AppColors.rose400Dark : const Color(0xFFD6608D),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.isDark,
    required this.displayMonth,
    required this.selectedDate,
    required this.product,
    required this.startedAt,
    required this.appliedDays,
    required this.onSelectDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToggleSelectedDay,
  });

  final bool isDark;
  final DateTime displayMonth;
  final DateTime selectedDate;
  final ProductRecommendation product;
  final DateTime startedAt;
  final List<String> appliedDays;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToggleSelectedDay;

  @override
  Widget build(BuildContext context) {
    final guidance = product.usageGuidance;
    final firstDay = DateTime(displayMonth.year, displayMonth.month, 1);
    final daysInMonth = DateTime(
      displayMonth.year,
      displayMonth.month + 1,
      0,
    ).day;
    final firstWeekday = firstDay.weekday;
    final leadingEmpty = firstWeekday - 1;
    final totalSlots = leadingEmpty + daysInMonth;
    final trailingEmpty = (7 - (totalSlots % 7)) % 7;
    final totalCells = totalSlots + trailingEmpty;
    final isSelectedPlanned =
        guidance?.isPlannedDate(
          courseStartedAt: startedAt,
          date: selectedDate,
        ) ??
        false;
    final isSelectedApplied = appliedDays.contains(
      formatCourseDayKey(selectedDate),
    );

    return AppSurfaceCard(
      key: const Key('course_calendar'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Календарь курса',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _monthLabel(displayMonth),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.neutral500Dark
                            : AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
              _CalendarNavButton(
                key: const Key('course_prev_month'),
                onPressed: onPreviousMonth,
                icon: Icons.chevron_left_rounded,
              ),
              const SizedBox(width: 4),
              _CalendarNavButton(
                key: const Key('course_next_month'),
                onPressed: onNextMonth,
                icon: Icons.chevron_right_rounded,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final weekday in const [
                'Пн',
                'Вт',
                'Ср',
                'Чт',
                'Пт',
                'Сб',
                'Вс',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.neutral500Dark
                            : AppColors.neutral500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var weekStart = 0; weekStart < totalCells; weekStart += 7) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var weekdayIndex = 0;
                  weekdayIndex < 7;
                  weekdayIndex++
                ) ...[
                  Expanded(
                    child: _buildCalendarCell(
                      slotIndex: weekStart + weekdayIndex,
                      leadingEmpty: leadingEmpty,
                      daysInMonth: daysInMonth,
                    ),
                  ),
                  if (weekdayIndex < 6) const SizedBox(width: 4),
                ],
              ],
            ),
            if (weekStart + 7 < totalCells) const SizedBox(height: 4),
          ],
          const SizedBox(height: 8),
          _CalendarSelectionFooter(
            isDark: isDark,
            selectedDate: selectedDate,
            isPlannedDay: isSelectedPlanned,
            isApplied: isSelectedApplied,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCell({
    required int slotIndex,
    required int leadingEmpty,
    required int daysInMonth,
  }) {
    final dayNumber = slotIndex - leadingEmpty + 1;
    if (dayNumber <= 0 || dayNumber > daysInMonth) {
      return const SizedBox(height: 42);
    }

    final date = DateTime(displayMonth.year, displayMonth.month, dayNumber);
    final normalizedDate = normalizeCourseDate(date);
    final isSelected = normalizeCourseDate(selectedDate) == normalizedDate;
    final isApplied = appliedDays.contains(formatCourseDayKey(date));
    final isPlanned =
        product.usageGuidance?.isPlannedDate(
          courseStartedAt: startedAt,
          date: date,
        ) ??
        false;

    return _CalendarDayCell(
      isDark: isDark,
      date: date,
      dayNumber: dayNumber,
      isSelected: isSelected,
      isApplied: isApplied,
      isPlanned: isPlanned,
      onTap: () => onSelectDate(date),
      onToggle: onToggleSelectedDay,
    );
  }
}

class _CalendarSelectionFooter extends StatelessWidget {
  const _CalendarSelectionFooter({
    required this.isDark,
    required this.selectedDate,
    required this.isPlannedDay,
    required this.isApplied,
  });

  final bool isDark;
  final DateTime selectedDate;
  final bool isPlannedDay;
  final bool isApplied;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warmBrownInsetDark : AppColors.warmBrownInset,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.warmBrownInsetBorderDark
              : AppColors.warmBrownInsetBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                size: 16,
                color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_formatDate(selectedDate)} · ${_buildSelectedDayStatusLabel(isPlannedDay, isApplied)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _DayStatusChip(
                label: isApplied
                    ? 'Отмечено'
                    : isPlannedDay
                    ? 'По плану'
                    : 'Вне схемы',
                color: isApplied
                    ? (isDark
                          ? const Color(0xFF304333)
                          : const Color(0xFFE3F1E5))
                    : isPlannedDay
                    ? (isDark
                          ? const Color(0xFF342C3A)
                          : const Color(0xFFF4E9F1))
                    : (isDark
                          ? const Color(0xFF3D3025)
                          : const Color(0xFFF6E5D6)),
                textColor: isApplied
                    ? (isDark ? Colors.white : const Color(0xFF31543A))
                    : isPlannedDay
                    ? (isDark ? Colors.white : const Color(0xFF704C66))
                    : (isDark
                          ? const Color(0xFFFFC68F)
                          : const Color(0xFF9B5D1E)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isPlannedDay
                ? isApplied
                      ? 'Нанесение отмечено в плановый день.'
                      : 'Плановый день по схеме введения.'
                : isApplied
                ? 'Нанесение отмечено вне базовой схемы.'
                : 'День вне базовой схемы.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
            ),
          ),
          if (!isPlannedDay) ...[
            const SizedBox(height: 4),
            Text(
              'Отметить всё равно можно, но учитывайте риск перегрузить кожу.',
              key: const Key('course_out_of_scheme_warning'),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFFFFC68F)
                    : const Color(0xFF9B5D1E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.isDark,
    required this.date,
    required this.dayNumber,
    required this.isSelected,
    required this.isApplied,
    required this.isPlanned,
    required this.onTap,
    required this.onToggle,
  });

  final bool isDark;
  final DateTime date;
  final int dayNumber;
  final bool isSelected;
  final bool isApplied;
  final bool isPlanned;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 56;
        final selectedHeight = isCompact ? 56.0 : 60.0;

        late final Color backgroundColor;
        late final Color borderColor;
        late final Color textColor;

        if (isSelected && isApplied) {
          backgroundColor = isDark
              ? const Color(0xFF31503B)
              : const Color(0xFF4A8C58);
          borderColor = isDark
              ? const Color(0xFF86C392)
              : const Color(0xFF4A8C58);
          textColor = Colors.white;
        } else if (isSelected) {
          backgroundColor = const Color(0xFFD6608D);
          borderColor = const Color(0xFFD6608D);
          textColor = Colors.white;
        } else if (isApplied) {
          backgroundColor = isDark
              ? const Color(0xFF304333)
              : const Color(0xFFE3F1E5);
          borderColor = isDark
              ? const Color(0xFF557B5E)
              : const Color(0xFFA5C7AE);
          textColor = isDark ? Colors.white : const Color(0xFF31543A);
        } else if (isPlanned) {
          backgroundColor = isDark
              ? const Color(0xFF342C3A)
              : const Color(0xFFF4E9F1);
          borderColor = isDark
              ? const Color(0xFF6A5475)
              : const Color(0xFFD7BED0);
          textColor = isDark ? Colors.white : const Color(0xFF704C66);
        } else {
          backgroundColor = isDark ? AppColors.neutral100Dark : Colors.white;
          borderColor = isDark
              ? AppColors.neutral100Dark
              : const Color(0xFFE6DFD9);
          textColor = isDark ? AppColors.neutral900Dark : AppColors.neutral900;
        }

        return InkWell(
          key: Key('course_day_${formatCourseDayKey(date)}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: isSelected ? selectedHeight : 42,
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: isSelected ? 12 : 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (isApplied)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: textColor,
                          ),
                        )
                      else if (isPlanned)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : (isDark
                                        ? const Color(0xFFF1D6B7)
                                        : const Color(0xFF8E5E7A)),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: double.infinity,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.12 : 0.18,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        key: const Key('course_inline_toggle_selected_day'),
                        onTap: onToggle,
                        borderRadius: BorderRadius.circular(10),
                        child: Center(
                          child: Icon(
                            isApplied
                                ? Icons.remove_circle_outline_rounded
                                : Icons.add_circle_outline_rounded,
                            size: isCompact ? 13 : 14,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UsageGuidanceAccordion extends StatelessWidget {
  const _UsageGuidanceAccordion({
    required this.isDark,
    required this.guidance,
    required this.selectedDate,
    required this.phase,
    required this.isExpanded,
    required this.onToggle,
  });

  final bool isDark;
  final UsageGuidance guidance;
  final DateTime selectedDate;
  final IntroductionPhase? phase;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final summaryLine = _buildGuidanceSummary(
      selectedDate: selectedDate,
      phase: phase,
      cycleLengthDays: guidance.introductionScheme.cycleLengthDays,
    );

    return Container(
      key: const Key('course_guidance_accordion'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warmBrownInsetDark : AppColors.warmBrownInset,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.warmBrownInsetBorderDark
              : AppColors.warmBrownInsetBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('course_guidance_toggle'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Как вводить',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(selectedDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.neutral500Dark
                                : AppColors.neutral500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summaryLine,
                          key: const Key('course_guidance_summary'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (phase?.note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            phase!.note!,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.neutral500Dark
                                  : AppColors.neutral500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text(
                        isExpanded ? 'Скрыть' : 'Схема',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.neutral500Dark
                              : AppColors.neutral500,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            for (final phase in guidance.introductionScheme.phases) ...[
              _PhaseRow(
                isDark: isDark,
                phase: phase,
                cycleLengthDays: guidance.introductionScheme.cycleLengthDays,
              ),
              if (phase != guidance.introductionScheme.phases.last)
                const SizedBox(height: 2),
            ],
          ],
        ],
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    super.key,
    required this.onPressed,
    required this.icon,
  });

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
      ),
    );
  }
}

class _DayStatusChip extends StatelessWidget {
  const _DayStatusChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

String _buildSelectedDayStatusLabel(bool isPlannedDay, bool isApplied) {
  if (isApplied && isPlannedDay) {
    return 'отмечено по плану';
  }
  if (isApplied) {
    return 'отмечено вне схемы';
  }
  if (isPlannedDay) {
    return 'плановый день';
  }
  return 'вне схемы';
}

String _buildGuidanceSummary({
  required DateTime selectedDate,
  required IntroductionPhase? phase,
  required int cycleLengthDays,
}) {
  if (phase == null) {
    return 'На ${_formatDate(selectedDate)} отдельная фаза не задана.';
  }

  final prefix =
      normalizeCourseDate(selectedDate) == normalizeCourseDate(DateTime.now())
      ? 'Сейчас'
      : 'На ${_formatDate(selectedDate)}';
  return '$prefix: ${_buildPhaseRule(phase, cycleLengthDays)}.';
}

String _buildPhaseRule(IntroductionPhase phase, int cycleLengthDays) {
  final count = phase.allowedCycleDays.length;
  final cadence = cycleLengthDays == 7
      ? '$count ${_weeklyCadenceLabel(count)}'
      : '$count ${_cycleCadenceLabel(count)}';
  return '$cadence, ${_cycleDaysLabel(phase.allowedCycleDays)}';
}

String _weeklyCadenceLabel(int count) {
  if (count == 1) {
    return 'вечер в неделю';
  }
  if (count >= 2 && count <= 4) {
    return 'вечера в неделю';
  }
  return 'вечеров в неделю';
}

String _cycleCadenceLabel(int count) {
  if (count == 1) {
    return 'вечер за цикл';
  }
  if (count >= 2 && count <= 4) {
    return 'вечера за цикл';
  }
  return 'вечеров за цикл';
}

String _cycleDaysLabel(List<int> days) {
  if (days.isEmpty) {
    return 'дни цикла уточняйте отдельно';
  }
  if (days.length == 1) {
    return 'день ${days.first} цикла';
  }
  if (days.length == 2) {
    return 'дни ${days.first} и ${days.last} цикла';
  }
  final leading = days.take(days.length - 1).join(', ');
  return 'дни $leading и ${days.last} цикла';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _monthLabel(DateTime date) {
  const months = <String>[
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
