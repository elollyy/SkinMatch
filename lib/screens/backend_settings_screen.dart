import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backend_config_service.dart';
import '../widgets/app_layout.dart';

class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiUrlController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(
      text: context.read<BackendConfigService>().apiUrl,
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await context.read<BackendConfigService>().saveApiUrl(
      _apiUrlController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Адрес backend сохранён')));
    }
  }

  Future<void> _clear() async {
    _apiUrlController.clear();
    await context.read<BackendConfigService>().saveApiUrl('');

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Адрес backend очищен')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final backendConfig = context.watch<BackendConfigService>();

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
            eyebrow: 'BACKEND',
            title: 'Подключение к сервису рекомендаций',
            description:
                'Укажите базовый адрес API. Путь `/api/v1/care-plan` приложение добавит само.',
          ),
          const SizedBox(height: 24),
          AppSurfaceCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Адрес backend',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('backend_url_field'),
                    controller: _apiUrlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'http://127.0.0.1:8000',
                    ),
                    validator: _validateApiUrl,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    backendConfig.isConfigured
                        ? 'Сейчас используется: ${backendConfig.apiUrl}'
                        : 'Сейчас backend не настроен.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('backend_save_button'),
                      onPressed: _save,
                      child: const Text('Сохранить'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('backend_clear_button'),
                      onPressed: _clear,
                      child: const Text('Очистить'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _BackendHintCard(
                    title: 'Локальный запуск',
                    message: _buildLocalHint(),
                  ),
                  const SizedBox(height: 12),
                  const _BackendHintCard(
                    title: 'Web',
                    message:
                        'Для запуска в браузере backend должен отвечать по CORS, иначе запрос будет блокироваться.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateApiUrl(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Введите полный URL, например http://127.0.0.1:8000';
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Поддерживаются только http и https';
    }

    return null;
  }

  String _buildLocalHint() {
    if (kIsWeb) {
      return 'Для локального сервера обычно подходит `http://127.0.0.1:8000`, если backend открыт для CORS.';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'В Android emulator используйте `http://10.0.2.2:8000`, а не `localhost`.';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 'Для локального сервера обычно подходит `http://127.0.0.1:8000`.';
      case TargetPlatform.fuchsia:
        return 'Проверьте адрес сервера в вашей среде выполнения.';
    }
  }
}

class _BackendHintCard extends StatelessWidget {
  const _BackendHintCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      shadowOpacity: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
