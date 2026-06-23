import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';
import 'app_shell.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = context.watch<UserService>();
    final user = userService.user;
    final profile = user.skinProfile;
    final body = AppPageBody(
      width: AppPageWidth.medium,
      topSafeArea: AppShell.maybeOf(context) == null,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            eyebrow: 'ПРОФИЛЬ',
            title: user.name ?? 'Пользователь',
            description: user.email ?? '',
          ),
          const SizedBox(height: 24),
          AppSurfaceCard(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.rose50Dark
                        : AppColors.rose50,
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 38,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.rose400Dark
                        : AppColors.rose400,
                  ),
                ),
                const SizedBox(height: 24),
                _ProfileStatRow(
                  label: 'Тип кожи',
                  value: _capitalize(profile?.skinType ?? 'Не указан'),
                ),
                _ProfileStatRow(
                  label: 'Возраст',
                  value: _ageLabel(profile?.age),
                ),
                _ProfileStatRow(
                  label: 'Аллергии',
                  value: profile == null || profile.allergies.isEmpty
                      ? 'Нет'
                      : profile.allergies.join(', '),
                ),
                _ProfileStatRow(
                  label: 'Ценовой сегмент',
                  value: _capitalize(profile?.priceRange ?? 'Средний'),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.history_outlined,
            label: 'История анкет',
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.settings_outlined,
            label: 'Настройки',
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.logout_rounded,
            label: 'Выйти из аккаунта',
            onTap: () async {
              await context.read<UserService>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/welcome',
                  (route) => false,
                );
              }
            },
            danger: true,
          ),
        ],
      ),
    );

    if (AppShell.maybeOf(context) != null) {
      return body;
    }

    return Scaffold(body: body);
  }
}

class _ProfileStatRow extends StatelessWidget {
  const _ProfileStatRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = danger
        ? const Color(0xFFC85B56)
        : (isDark ? AppColors.neutral900Dark : AppColors.neutral900);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AppSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        backgroundColor: danger
            ? (isDark ? const Color(0xFF332726) : const Color(0xFFFFFAF9))
            : null,
        borderColor: danger ? const Color(0xFFE8C0BE) : null,
        shadowOpacity: 0,
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: color),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

String _ageLabel(int? age) {
  if (age == null || age == 0) {
    return 'Не указан';
  }
  return '$age лет';
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}
