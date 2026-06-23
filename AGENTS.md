# Repository Guidelines

## Project Structure & Module Organization
Core app code lives in `lib/`:
- `main.dart` bootstraps providers and app theme.
- `screens/` contains UI pages (for example `welcome_screen.dart`, `home_screen.dart`).
- `services/` contains state/business logic (`user_service.dart`, `theme_service.dart`).
- `models/` contains data models such as `user_model.dart`.
- `theme/` centralizes colors and theme definitions.

Tests are in `test/` (currently `widget_test.dart`). Platform runners are in `android/`, `ios/`, `web/`, `linux/`, `macos/`, and `windows/`. Add static assets under `assets/` and register them in `pubspec.yaml`.

## Build, Test, and Development Commands
- `flutter pub get` installs dependencies.
- `flutter run` runs the app on the default device.
- `flutter run -d chrome` runs the web target locally.
- `flutter analyze` runs static analysis using `analysis_options.yaml`.
- `flutter test` runs unit/widget tests in `test/`.
- `flutter build apk` or `flutter build web` creates production artifacts.

## Coding Style & Naming Conventions
Use 2-space indentation and keep files formatted with `dart format .`. Linting is enforced via `flutter_lints` (`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`).

Naming rules:
- Files: `snake_case.dart`
- Classes/enums: `PascalCase`
- Variables/methods: `lowerCamelCase`
- Constants: `lowerCamelCase` (use `const` where possible)

Keep widgets focused, move reusable logic to `services/`, and avoid duplicating theme values outside `lib/theme/`.

## Testing Guidelines
Use `flutter_test` for widget and unit tests. Name test files `*_test.dart` and group scenarios with clear `test`/`testWidgets` descriptions (for example, `App loads welcome screen`).

For UI changes, add or update widget tests for navigation, rendering, and state changes. Run `flutter test` and `flutter analyze` before opening a PR.

## Commit & Pull Request Guidelines
Git history is not available in this workspace snapshot, so follow a consistent convention:
- Commit format: `type(scope): short imperative summary` (for example, `feat(survey): add age validation`).
- Keep commits small and single-purpose.

PRs should include:
- What changed and why
- Linked issue/task ID
- Test evidence (`flutter test`, `flutter analyze`)
- Screenshots/video for UI changes (mobile + web when relevant)
