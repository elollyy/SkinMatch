import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';
import 'app_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = context.watch<UserService>();
    final user = userService.user;
    final firstName = user.name?.split(' ').first ?? 'Пользователь';
    final activeCourseProduct = user.activeIntensiveProduct;
    final nextPlannedDate = userService.getNextPlannedIntensiveDate();
    final today = normalizeCourseDate(DateTime.now());
    final courseStartedAt = user.intensiveCourseStartedAt ?? today;
    final isTodayApplied = activeCourseProduct == null
        ? false
        : user.isIntensiveApplicationLogged(
            activeCourseProduct.productId,
            today,
          );
    final isTodayPlanned =
        activeCourseProduct?.usageGuidance?.isPlannedDate(
          courseStartedAt: courseStartedAt,
          date: today,
        ) ??
        false;

    final body = AppPageBody(
      width: AppPageWidth.wide,
      topSafeArea: AppShell.maybeOf(context) == null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final surveyTile = _ActionTile(
            key: const Key('home_start_survey_button'),
            icon: Icons.assignment_outlined,
            title: 'Пройти анкету',
            subtitle: 'Освежить профиль кожи',
            accent: true,
            onTap: () => Navigator.pushNamed(context, '/survey'),
          );
          final historyTile = _ActionTile(
            key: const Key('home_history_button'),
            icon: Icons.access_time_outlined,
            title: 'История',
            subtitle: _buildHistoryLabel(user),
            onTap: () => Navigator.pushNamed(context, '/history'),
          );

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeroCard(firstName: firstName, user: user),
              const SizedBox(height: 16),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _StatusCard(user: user)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: activeCourseProduct != null
                          ? _IntensiveCourseCard(
                              product: activeCourseProduct,
                              nextPlannedDate: nextPlannedDate,
                              isTodayApplied: isTodayApplied,
                              isTodayPlanned: isTodayPlanned,
                            )
                          : const _AdviceCard(compact: true),
                    ),
                  ],
                )
              else ...[
                _StatusCard(user: user),
                if (activeCourseProduct != null) ...[
                  const SizedBox(height: 16),
                  _IntensiveCourseCard(
                    product: activeCourseProduct,
                    nextPlannedDate: nextPlannedDate,
                    isTodayApplied: isTodayApplied,
                    isTodayPlanned: isTodayPlanned,
                  ),
                ],
              ],
              const SizedBox(height: 16),
              if (constraints.maxWidth >= 720)
                Row(
                  children: [
                    Expanded(child: surveyTile),
                    const SizedBox(width: 12),
                    Expanded(child: historyTile),
                  ],
                )
              else ...[
                surveyTile,
                const SizedBox(height: 12),
                historyTile,
              ],
              const SizedBox(height: 16),
              if (!isWide || activeCourseProduct != null) const _AdviceCard(),
            ],
          );
        },
      ),
    );

    if (AppShell.maybeOf(context) != null) {
      return body;
    }

    return Scaffold(body: body);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.firstName, required this.user});

  final String firstName;
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      backgroundColor: isDark
          ? const Color(0xFF2B2524)
          : const Color(0xFFFFFCFA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _buildGreeting(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Text(firstName, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            'Сегодня у вас ${user.activeIntensiveProduct == null ? 'спокойный уход' : 'активный курс и персональные рекомендации'} в одной ленте.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _IntensiveCourseCard extends StatelessWidget {
  const _IntensiveCourseCard({
    required this.product,
    required this.nextPlannedDate,
    required this.isTodayApplied,
    required this.isTodayPlanned,
  });

  final ProductRecommendation product;
  final DateTime? nextPlannedDate;
  final bool isTodayApplied;
  final bool isTodayPlanned;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = normalizeCourseDate(DateTime.now());
    final subtitle = nextPlannedDate == null
        ? 'Есть активный курс'
        : isTodayApplied
        ? 'Сегодняшнее нанесение уже отмечено'
        : normalizeCourseDate(nextPlannedDate!) == today
        ? 'Сегодня плановый день нанесения'
        : 'Следующий плановый день: ${_formatCompactDate(nextPlannedDate!)}';
    final statusLabel = isTodayApplied
        ? 'Сегодня отмечено'
        : isTodayPlanned
        ? 'Сегодня по плану'
        : 'Сегодня вне схемы';
    final actionLabel = isTodayApplied ? 'Отмечено' : 'Отметить';
    final userService = context.read<UserService>();

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: isDark
          ? const Color(0xFF312924)
          : const Color(0xFFFFF8F2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('home_intensive_course_card'),
            onTap: () {
              final shell = AppShell.maybeOf(context);
              if (shell != null) {
                shell.openIntensiveCourse();
                return;
              }
              Navigator.pushNamed(context, '/course');
            },
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF45362D)
                        : const Color(0xFFF9E9D8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.calendar_month_outlined),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'АКТИВНЫЙ КУРС',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.productName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.neutral100Dark.withValues(alpha: 0.75)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сегодня',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  key: const Key('home_toggle_today_course_day'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await userService.toggleIntensiveApplication(
                      product.productId,
                      today,
                    );
                    if (!context.mounted || isTodayPlanned) {
                      return;
                    }
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Отметка сохранена. Сегодняшний день вне базовой схемы.',
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isTodayApplied
                          ? (isDark
                                ? const Color(0xFF31503B)
                                : const Color(0xFFE3F1E5))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isTodayApplied
                            ? (isDark
                                  ? const Color(0xFF86C392)
                                  : const Color(0xFFA5C7AE))
                            : (isDark
                                  ? AppColors.neutral300Dark
                                  : AppColors.neutral100),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isTodayApplied
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            'ВАШ СТАТУС',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.warmBrownForegroundMuted.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Анкета заполнена',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.warmBrownForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Рекомендации актуальны · ${_buildSurveyStatusText(user)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.warmBrownForegroundMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            key: const Key('home_view_results_button'),
            onPressed: () => Navigator.pushNamed(context, '/care'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmBrownChip,
              foregroundColor: AppColors.warmBrownChipText,
            ),
            child: const Text('Смотреть результаты'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(20),
        backgroundColor: accent
            ? (isDark ? AppColors.rose50Dark : AppColors.rose50)
            : null,
        borderColor: accent
            ? (isDark ? AppColors.rose200Dark : AppColors.rose200)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: accent
                  ? (isDark ? AppColors.rose400Dark : AppColors.rose400)
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark ? AppColors.blue50Dark : AppColors.blue50,
            ),
            child: Icon(
              Icons.water_drop_outlined,
              color: isDark ? AppColors.blue400Dark : AppColors.blue400,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compact ? 'Совет дня' : 'Гидратация — основа ухода',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Наносите увлажнитель на влажную кожу — это помогает удерживать воду и смягчает действие активов.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _buildGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Доброе утро';
  }
  if (hour < 18) {
    return 'Добрый день';
  }
  return 'Добрый вечер';
}

String _buildHistoryLabel(UserModel user) {
  final count = user.surveyHistory.length;
  if (count == 0) {
    return 'Пока пусто';
  }
  final mod100 = count % 100;
  final mod10 = count % 10;
  if (mod10 == 1 && mod100 != 11) {
    return '$count анкета';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$count анкеты';
  }
  return '$count анкет';
}

String _buildSurveyStatusText(UserModel user) {
  final completedAt = user.lastSurveyCompletedAt;
  if (completedAt == null) {
    return 'опрос уже пройден';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final surveyDay = DateTime(
    completedAt.year,
    completedAt.month,
    completedAt.day,
  );
  final daysAgo = today.difference(surveyDay).inDays;

  if (daysAgo <= 0) {
    return 'сегодня';
  }

  final mod100 = daysAgo % 100;
  final mod10 = daysAgo % 10;
  if (mod10 == 1 && mod100 != 11) {
    return '$daysAgo день назад';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$daysAgo дня назад';
  }
  return '$daysAgo дней назад';
}

String _formatCompactDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month';
}
