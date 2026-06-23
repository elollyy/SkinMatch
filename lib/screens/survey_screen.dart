import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _currentQuestion = 0;
  final Map<String, dynamic> _answers = <String, dynamic>{};
  final TextEditingController _ageController = TextEditingController();

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Какой у вас тип кожи?',
      'key': 'skinType',
      'type': 'options',
      'options': [
        'нормальная',
        'жирная',
        'сухая',
        'комбинированная',
        'чувствительная',
        'проблемная кожа',
      ],
    },
    {'question': 'Сколько вам лет?', 'key': 'age', 'type': 'ageInput'},
    {
      'question': 'Есть ли у вас аллергии?',
      'key': 'allergies',
      'type': 'options',
      'options': ['нет', 'на отдушки', 'на спирт', 'на масла', 'другое'],
    },
    {
      'question': 'Какой ценовой сегмент вас интересует?',
      'key': 'priceRange',
      'type': 'options',
      'options': ['бюджетный', 'средний', 'люкс'],
    },
  ];

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _selectOption(String option) {
    setState(() {
      _answers[_questions[_currentQuestion]['key']] = option;
    });
  }

  void _updateAge(String value) {
    final parsedAge = int.tryParse(value.trim());
    setState(() {
      if (parsedAge != null && parsedAge > 0) {
        _answers['age'] = parsedAge;
      } else {
        _answers.remove('age');
      }
    });
  }

  void _goBack() {
    if (_currentQuestion > 0) {
      setState(() {
        _currentQuestion--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
      });
      return;
    }
    _completeSurvey();
  }

  Future<void> _completeSurvey() async {
    final profile = SkinProfile(
      skinType: _answers['skinType'] ?? 'нормальная',
      age: (_answers['age'] as int?) ?? 25,
      allergies: _answers['allergies'] == null || _answers['allergies'] == 'нет'
          ? <String>[]
          : <String>[_answers['allergies'].toString()],
      priceRange: _answers['priceRange'] ?? 'средний',
    );

    await context.read<UserService>().completeSurvey(profile);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/care');
    }
  }

  bool _isCurrentAnswerValid(Map<String, dynamic> question) {
    if (question['type'] == 'ageInput') {
      final age = _answers['age'];
      return age is int && age > 0;
    }
    return _answers[question['key']] != null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).height < 700;
    final question = _questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / _questions.length;
    final selectedAnswer = _answers[question['key']];
    final isCurrentAnswerValid = _isCurrentAnswerValid(question);

    return AppPageScaffold(
      width: AppPageWidth.narrow,
      child: Stack(
        children: [
          Center(
            child: AppSurfaceCard(
          padding: EdgeInsets.fromLTRB(18, compact ? 16 : 24, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Опрос', style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  Text(
                    '${_currentQuestion + 1} из ${_questions.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
              SizedBox(height: compact ? 14 : 28),
              Text(
                question['question'] as String,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                question['type'] == 'ageInput'
                    ? 'Введите возраст числом, чтобы мы подобрали уход точнее.'
                    : 'Выберите один вариант. Ответ можно изменить перед переходом дальше.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.neutral500Dark
                      : AppColors.neutral500,
                ),
              ),
              SizedBox(height: compact ? 12 : 22),
              SizedBox(
                height: question['type'] == 'ageInput'
                    ? (compact ? 82 : 92)
                    : (compact ? 186 : 320),
                child: _buildQuestionBody(
                  context,
                  question,
                  isDark,
                  selectedAnswer,
                ),
              ),
              SizedBox(height: compact ? 12 : 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isCurrentAnswerValid ? _nextQuestion : null,
                  child: const Text('далее'),
                ),
              ),
            ],
          ),
        ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _goBack,
              tooltip: 'Назад',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionBody(
    BuildContext context,
    Map<String, dynamic> question,
    bool isDark,
    dynamic selectedAnswer,
  ) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    if (question['type'] == 'ageInput') {
      final hasText = _ageController.text.trim().isNotEmpty;
      final showError = hasText && !_isCurrentAnswerValid(question);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('survey_age_input'),
            controller: _ageController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: _updateAge,
            onSubmitted: (_) {
              if (_isCurrentAnswerValid(question)) {
                _nextQuestion();
              }
            },
            decoration: InputDecoration(
              hintText: 'Например, 29',
              errorText: showError ? 'Введите корректный возраст' : null,
            ),
          ),
        ],
      );
    }

    final options = question['options'] as List<dynamic>;

    if (compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final optionValue in options)
                SizedBox(
                  width: itemWidth,
                  child: _OptionButton(
                    option: optionValue.toString(),
                    isSelected: selectedAnswer == optionValue.toString(),
                    onTap: () => _selectOption(optionValue.toString()),
                    isDark: isDark,
                  ),
                ),
            ],
          );
        },
      );
    }

    return Column(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          _OptionButton(
            option: options[index].toString(),
            isSelected: selectedAnswer == options[index].toString(),
            onTap: () => _selectOption(options[index].toString()),
            isDark: isDark,
          ),
          if (index != options.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String option;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? AppColors.rose400Dark : AppColors.rose400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.rose50Dark : AppColors.rose50)
                : (isDark ? AppColors.neutral100Dark : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? AppColors.neutral300Dark : AppColors.neutral100),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? activeColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? activeColor
                        : (isDark
                              ? AppColors.neutral500Dark
                              : AppColors.neutral500),
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? (isDark
                              ? AppColors.neutral900Dark
                              : AppColors.neutral900)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
