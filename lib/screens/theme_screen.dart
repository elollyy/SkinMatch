import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return AppPageScaffold(
      width: AppPageWidth.narrow,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBackButton(
            label: 'Настройки',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(
            eyebrow: 'ТЕМА',
            title: 'Оформление',
            description:
                'Выберите спокойную светлую или тёмную тему приложения.',
          ),
          const SizedBox(height: 24),
          AppSurfaceCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ThemePreview(
                        isLight: true,
                        isSelected: !themeService.isDarkMode,
                        onTap: () => themeService.setTheme(ThemeMode.light),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ThemePreview(
                        isLight: false,
                        isSelected: themeService.isDarkMode,
                        onTap: () => themeService.setTheme(ThemeMode.dark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Применить'),
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

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.isLight,
    required this.isSelected,
    required this.onTap,
  });

  final bool isLight;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? (isLight ? AppColors.rose400 : AppColors.rose400Dark)
        : (isLight ? AppColors.neutral100 : AppColors.neutral300Dark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 112,
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFFFFCFA)
                    : const Color(0xFF252220),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isLight
                          ? AppColors.rose200
                          : AppColors.rose200Dark,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : AppColors.neutral50Dark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 84,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isLight
                          ? AppColors.neutral100
                          : AppColors.neutral300Dark,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  isLight ? 'Светлая' : 'Тёмная',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: isLight ? AppColors.rose400 : AppColors.rose400Dark,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
