import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<UserService>().user.surveyHistory;

    return AppPageScaffold(
      width: AppPageWidth.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBackButton(
            label: 'Назад',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(
            eyebrow: 'ИСТОРИЯ',
            title: 'Все сохранённые прохождения',
          ),
          const SizedBox(height: 24),
          Expanded(
            child: history.isEmpty
                ? const _EmptyHistoryState()
                : ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _HistoryCard(entry: history[index], index: index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppSurfaceCard(
        key: const Key('history_empty_state'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 40,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 14),
            Text(
              'История пока пуста',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'После следующего прохождения здесь появятся сохранённые результаты.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('history_start_survey_button'),
                onPressed: () => Navigator.pushNamed(context, '/survey'),
                child: const Text('Пройти опрос'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.index});

  final SurveyHistoryEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSurfaceCard(
      key: Key('history_entry_$index'),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.blue50Dark : AppColors.blue50,
            ),
            child: Icon(
              Icons.assignment_turned_in_outlined,
              color: isDark ? AppColors.blue400Dark : AppColors.blue400,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTime(entry.completedAt),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Тип кожи: ${entry.profileSnapshot.skinType}',
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

String _formatDateTime(DateTime value) {
  const months = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  final day = value.day.toString().padLeft(2, '0');
  final month = months[value.month - 1];
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day $month ${value.year}, $hour:$minute';
}
