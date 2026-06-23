import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final notifService = context.watch<NotificationService>();

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
            eyebrow: 'НАСТРОЙКИ',
            title: 'Параметры приложения',
          ),
          const SizedBox(height: 24),
          AppSurfaceCard(
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  label: 'Оформление',
                  value: themeService.isDarkMode ? 'Тёмная' : 'Светлая',
                  onTap: () => Navigator.pushNamed(context, '/theme'),
                ),

                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  label: 'Уведомления',
                  value: notifService.enabled
                      ? 'Вкл · ${_formatTime(notifService.time)}'
                      : 'Выкл',
                  onTap: () => Navigator.pushNamed(context, '/notifications'),
                ),
                _SettingsRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Поддержка',
                  onTap: () => _showSupportDialog(context),
                ),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  label: 'Выйти из аккаунта',
                  onTap: () => _showLogoutDialog(context),
                  isLast: true,
                  isDanger: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showSupportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Поддержка'),
        content: const Text(
          'Если у вас возникли вопросы или проблемы, напишите нам:\n\nskinmatch@support.ru',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<UserService>().logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                Navigator.pushReplacementNamed(context, '/welcome');
              }
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.isLast = false,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isLast;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDanger
        ? const Color(0xFFC85B56)
        : (isDark ? AppColors.neutral900Dark : AppColors.neutral900);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(
                    color: isDark
                        ? AppColors.neutral100Dark
                        : AppColors.neutral100,
                  ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
            if (value != null) ...[
              Text(value!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
