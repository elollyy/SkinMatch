import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppPageScaffold(
      width: AppPageWidth.narrow,
      scrollable: true,
      child: AppSurfaceCard(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        backgroundColor: isDark
            ? const Color(0xFF2B2624)
            : const Color(0xFFFFFCFA),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.rose50Dark : AppColors.rose50,
                border: Border.all(
                  color: isDark ? AppColors.rose200Dark : AppColors.rose200,
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 38,
                color: isDark ? AppColors.rose400Dark : AppColors.rose400,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'SkinMatch',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: isDark ? AppColors.neutral900Dark : AppColors.neutral900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Минималистичный подбор ухода на основе анкеты и ML-анализа.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Персональные рекомендации, история анкет и аккуратное ведение интенсивного курса в одном интерфейсе.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Войти'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Создать аккаунт'),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Подбор косметики на основе ML-анализа',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? AppColors.neutral500Dark : AppColors.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
