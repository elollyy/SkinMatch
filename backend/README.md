# SkinMatch Backend

Локальный backend для генерации care plan из `cosmetics.csv` и PMML-модели `SANN_PMML_Code_cosmetics-2.xml`.

## Что делает сервис

- читает canonical-каталог косметики из корня репозитория в `utf-8`;
- пытается загрузить PMML-модель через `pypmml`;
- фильтрует кандидатов по типу кожи, возрасту, ценовому сегменту и аллергиям;
- ранжирует результаты и отдает JSON, совместимый с Flutter `CarePlanService`.

Если `pypmml` недоступен или модель не загрузилась, сервис продолжает отвечать, но помечает ответ как `partial=true`.

## Структура

```text
backend/
  app/
    catalog.py
    config.py
    main.py
    model.py
    recommendation.py
    schemas.py
  tests/
  requirements.txt
```

## Установка

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
```

## Запуск

Из корня репозитория:

```bash
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

Проверка health:

```bash
curl http://127.0.0.1:8000/health
```

Пример запроса:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/care-plan \
  -H "Content-Type: application/json" \
  -d '{
    "skinType": "комбинированная",
    "age": 30,
    "allergies": ["на спирт"],
    "priceRange": "средний"
  }'
```

## Интеграция с Flutter

Основной сценарий интеграции: Flutter должен быть запущен с `CARE_PLAN_API_URL`.
Можно передать либо base URL, либо полный endpoint:

```bash
flutter run --dart-define=CARE_PLAN_API_URL=http://127.0.0.1:8000
```

или

```bash
flutter run --dart-define=CARE_PLAN_API_URL=http://127.0.0.1:8000/api/v1/care-plan
```

Для Android-эмулятора обычно нужен `http://10.0.2.2:8000`.

Для локальной разработки на Linux debug-сборка Flutter может обойтись без
`CARE_PLAN_API_URL`: приложение по умолчанию использует
`http://127.0.0.1:8000`.

Если нужно временно включить встроенный demo-mock без backend, делайте это явно:

```bash
flutter run \
  --dart-define=CARE_PLAN_ALLOW_MOCK_FALLBACK=true
```

Для Flutter Web backend теперь по умолчанию принимает локальные origin'ы вида
`http://localhost:<port>` и `http://127.0.0.1:<port>`.
Если нужен другой frontend origin, задайте его через переменные окружения:

```bash
export CORS_ALLOWED_ORIGINS=https://your-frontend.example
export CORS_ALLOWED_ORIGIN_REGEX='^https://preview-[0-9]+\.example\.com$'
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

## Быстрая диагностика

1. Убедитесь, что backend поднят:

```bash
curl http://127.0.0.1:8000/health
```

2. Проверьте, что `CARE_PLAN_API_URL` указывает на тот же backend.

3. Для Android-эмулятора замените `127.0.0.1` на `10.0.2.2`.
4. Для Flutter Web убедитесь, что frontend открыт с `localhost` или `127.0.0.1`, либо настройте `CORS_ALLOWED_ORIGINS`/`CORS_ALLOWED_ORIGIN_REGEX`.

## Тесты

Без дополнительных зависимостей доступны доменные unit-тесты:

```bash
python3 -m unittest discover -s backend/tests
```

Если установлен `fastapi`, дополнительно выполнится тест API-контракта.
