# SkinMatch - Flutter приложение для подбора косметики

Приложение для персонального подбора уходовой косметики на основе типа кожи и предпочтений пользователя.

## Структура проекта

```
lib/
├── main.dart                 # Точка входа приложения
├── models/                   # Модели данных
│   └── user_model.dart      # Модель пользователя и профиля кожи
├── screens/                  # Экраны приложения
│   ├── welcome_screen.dart  # Экран приветствия
│   ├── register_screen.dart # Регистрация
│   ├── survey_screen.dart   # Опрос о типе кожи
│   ├── result_screen.dart   # Результаты опроса
│   ├── home_screen.dart     # Главный экран
│   ├── profile_screen.dart  # Профиль пользователя
│   ├── settings_screen.dart # Настройки
│   └── theme_screen.dart    # Настройка темы
├── services/                 # Сервисы
│   ├── user_service.dart    # Управление пользователем
│   └── theme_service.dart   # Управление темой
├── theme/                    # Темы приложения
│   ├── app_colors.dart      # Цветовая палитра
│   └── app_theme.dart       # Светлая и тёмная темы
└── widgets/                  # Переиспользуемые виджеты
```

## Функциональность

### Реализовано

1. **Аутентификация**
   - Экран приветствия
   - Регистрация пользователя
   - Сохранение данных в SharedPreferences

2. **Опрос**
   - 4 вопроса о типе кожи, возрасте, аллергиях и ценовом сегменте
   - Прогресс-бар
   - Валидация ответов

3. **Главный экран**
   - Персонализированное приветствие
   - Утренняя рутина ухода
   - Рекомендации продуктов

4. **Профиль**
   - Информация о пользователе
   - Данные о коже
   - Возможность пройти опрос заново

5. **Настройки**
   - Переключение темы (светлая/тёмная)
   - Настройки уведомлений
   - Выбор языка
   - Выход из аккаунта

6. **Темы**
   - Светлая тема с молочными и розовыми тонами
   - Тёмная тема
   - Переключение акцентного цвета
   - Настройка размера текста

7. **Навигация**
   - Bottom navigation для mobile
   - Адаптивная навигация
   - Правильная логика переходов

## Запуск приложения

### Требования

- Flutter SDK 3.10.8 или выше
- Dart SDK

### Установка зависимостей

```bash
flutter pub get
```

### Запуск Flutter с backend рекомендаций

1. Поднимите backend из корня репозитория:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

2. Проверьте health endpoint:

```bash
curl http://127.0.0.1:8000/health
```

3. Запустите Flutter с адресом backend:

```bash
flutter run --dart-define=CARE_PLAN_API_URL=http://127.0.0.1:8000
```

Для локальной разработки на Linux debug-сборка теперь использует
`http://127.0.0.1:8000` по умолчанию, поэтому достаточно:

```bash
flutter run -d linux
```

Для Android-эмулятора используйте:

```bash
flutter run --dart-define=CARE_PLAN_API_URL=http://10.0.2.2:8000
```

Если нужен встроенный demo-mock без backend, включите его явно:

```bash
flutter run --dart-define=CARE_PLAN_ALLOW_MOCK_FALLBACK=true
```

### Запуск на конкретной платформе

```bash
# Android
flutter run -d android --dart-define=CARE_PLAN_API_URL=http://10.0.2.2:8000

# iOS
flutter run -d ios --dart-define=CARE_PLAN_API_URL=http://127.0.0.1:8000

# Web
flutter run -d chrome --dart-define=CARE_PLAN_API_URL=http://127.0.0.1:8000

# Desktop (Linux)
flutter run -d linux --dart-define=CARE_PLAN_API_URL=http://127.0.0.1:8000

# Desktop (macOS)
flutter run -d macos --dart-define=CARE_PLAN_API_URL=http://127.0.0.1:8000

# Desktop (Windows)
flutter run -d windows --dart-define=CARE_PLAN_API_URL=http://127.0.0.1:8000
```

## Зависимости

- `provider: ^6.1.2` - управление состоянием
- `shared_preferences: ^2.2.3` - локальное хранилище

## Цветовая палитра

### Светлая тема
- Фон: `#FDF8F5` (milk)
- Акцент: `#F472A0` (rose400)
- Вторичный: `#6AB4FF` (blue400)
- Текст: `#1C1A18` (neutral900)

### Тёмная тема
- Фон: `#1E1B1A` (milkDark)
- Акцент: `#C4527A` (rose400Dark)
- Вторичный: `#3B8FE8` (blue400Dark)
- Текст: `#F0ECE8` (neutral900Dark)

## Логика работы приложения

1. При первом запуске пользователь видит экран приветствия
2. После регистрации пользователь проходит опрос о типе кожи
3. На основе ответов формируется профиль и рекомендации
4. При повторном запуске пользователь сразу попадает на главный экран
5. Пользователь может в любой момент пройти опрос заново

## Адаптивность

Приложение использует mobile-first подход:
- На мобильных устройствах: bottom navigation
- Готово к расширению для tablet/desktop с sidebar navigation

## Дальнейшая разработка

### Приоритет 1
- [ ] Интеграция с ML-моделью для подбора косметики
- [ ] База данных продуктов
- [ ] Детальные карточки продуктов
- [ ] Избранное

### Приоритет 2
- [ ] Календарь ухода
- [ ] Напоминания о процедурах
- [ ] История использования продуктов
- [ ] Отзывы и рейтинги

### Приоритет 3
- [ ] Социальные функции
- [ ] Интеграция с магазинами
- [ ] AR примерка
- [ ] Персональный дневник кожи

## Тестирование

```bash
# Запуск тестов
flutter test

# Анализ кода
flutter analyze
```

## Сборка

```bash
# Android APK
flutter build apk

# Android App Bundle
flutter build appbundle

# iOS
flutter build ios

# Web
flutter build web
```

## Автор

Проект создан на основе HTML-макета `skincare_app_mockup.html`
