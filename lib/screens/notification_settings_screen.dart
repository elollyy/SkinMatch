import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifService = context.watch<NotificationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? AppColors.neutral900Dark : AppColors.neutral900;
    final subtleColor =
        isDark ? AppColors.neutral500Dark : AppColors.neutral500;
    final dividerColor =
        isDark ? AppColors.neutral100Dark : AppColors.neutral100;

    return AppPageScaffold(
      width: AppPageWidth.narrow,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBackButton(
            label: 'Назад',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(
            eyebrow: 'УВЕДОМЛЕНИЯ',
            title: 'Напоминания',
            description: 'Настройте уведомления об уходе за кожей.',
          ),
          const SizedBox(height: 24),

          // ── Ежедневное напоминание ──────────────────────────────────────────
          _SectionLabel(label: 'Ежедневный уход'),
          const SizedBox(height: 8),
          AppSurfaceCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: iconColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Включить напоминания',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Switch(
                        value: notifService.enabled,
                        onChanged: (value) => notifService.setEnabled(value),
                      ),
                    ],
                  ),
                ),
                if (notifService.enabled) ...[
                  Divider(height: 1, color: dividerColor),
                  _TimeRow(
                    time: notifService.time,
                    iconColor: iconColor,
                    subtleColor: subtleColor,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: notifService.time,
                      );
                      if (picked != null && context.mounted) {
                        context.read<NotificationService>().setTime(picked);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Курс интенсивного обновления ────────────────────────────────────
          _SectionLabel(label: 'Курс интенсивного обновления'),
          const SizedBox(height: 8),
          AppSurfaceCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_outlined,
                        size: 20,
                        color: iconColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Напоминать о нанесении',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Уведомление придёт только в дни нанесения по расписанию курса.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: subtleColor),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: notifService.courseEnabled,
                        onChanged: (value) async {
                          await notifService.setCourseEnabled(value);
                          if (context.mounted) {
                            final us = context.read<UserService>();
                            notifService.updateCourseNotifications(
                              guidance: us
                                  .getActiveIntensiveCourseProduct()
                                  ?.usageGuidance,
                              courseStartedAt:
                                  us.user.intensiveCourseStartedAt,
                              productName:
                                  us.getActiveIntensiveCourseProduct()?.productName,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                if (notifService.courseEnabled) ...[
                  Divider(height: 1, color: dividerColor),
                  _TimeRow(
                    time: notifService.courseTime,
                    iconColor: iconColor,
                    subtleColor: subtleColor,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: notifService.courseTime,
                      );
                      if (picked != null && context.mounted) {
                        final ns = context.read<NotificationService>();
                        final us = context.read<UserService>();
                        await ns.setCourseTime(picked);
                        ns.updateCourseNotifications(
                          guidance: us
                              .getActiveIntensiveCourseProduct()
                              ?.usageGuidance,
                          courseStartedAt: us.user.intensiveCourseStartedAt,
                          productName:
                              us.getActiveIntensiveCourseProduct()?.productName,
                        );
                      }
                    },
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.time,
    required this.iconColor,
    required this.subtleColor,
    required this.onTap,
  });

  final TimeOfDay time;
  final Color iconColor;
  final Color subtleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Время напоминания',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              time.format(context),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: subtleColor),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: subtleColor),
          ],
        ),
      ),
    );
  }
}
