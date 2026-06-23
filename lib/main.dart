import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/backend_config_service.dart';
import 'services/user_service.dart';
import 'services/theme_service.dart';
import 'services/care_plan_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/survey_screen.dart';
import 'screens/app_shell.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/backend_settings_screen.dart';
import 'screens/theme_screen.dart';
import 'screens/notification_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeService = ThemeService();
  final backendConfigService = BackendConfigService();
  final notificationService = NotificationService();

  await themeService.loadTheme();
  await backendConfigService.load();
  final userService = UserService(apiUrl: backendConfigService.apiUrl);
  await Future.wait([
    userService.loadUser(),
    notificationService.load(),
  ]);

  void syncCourseNotifications() {
    final product = userService.getActiveIntensiveCourseProduct();
    notificationService.updateCourseNotifications(
      guidance: product?.usageGuidance,
      courseStartedAt: userService.user.intensiveCourseStartedAt,
      productName: product?.productName,
    );
  }

  userService.addListener(syncCourseNotifications);
  syncCourseNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userService),
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: backendConfigService),
        ChangeNotifierProvider.value(value: notificationService),
        ProxyProvider<BackendConfigService, CarePlanService>(
          update: (_, backendConfig, previous) =>
              CarePlanService(apiUrl: backendConfig.apiUrl),
        ),
      ],
      child: const SkinMatchApp(),
    ),
  );
}

class SkinMatchApp extends StatelessWidget {
  const SkinMatchApp({super.key});

  static final Map<String, WidgetBuilder> _routeBuilders = {
    '/welcome': (context) => const WelcomeScreen(),
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/survey': (context) => const SurveyScreen(),
    '/care': (context) => const AppShell(initialIndex: 1),
    '/result': (context) => const AppShell(initialIndex: 1),
    '/home': (context) => const AppShell(initialIndex: 0),
    '/history': (context) => const HistoryScreen(),
    '/profile': (context) => const AppShell(initialIndex: 3),
    '/settings': (context) => const SettingsScreen(),
    '/backend': (context) => const BackendSettingsScreen(),
    '/theme': (context) => const ThemeScreen(),
    '/notifications': (context) => const NotificationSettingsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final userService = context.watch<UserService>();

    return MaterialApp(
      title: 'SkinMatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      home: _getInitialScreen(userService),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    if (settings.name == '/course') {
      final productId = settings.arguments is String
          ? settings.arguments as String
          : null;

      return PageRouteBuilder<void>(
        settings: settings,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            AppShell(initialIndex: 2, initialCourseProductId: productId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      );
    }

    final builder = _routeBuilders[settings.name];
    if (builder == null) {
      return null;
    }

    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  Widget _getInitialScreen(UserService userService) {
    if (!userService.isAuthenticated || !userService.hasCompletedSurvey) {
      return const WelcomeScreen();
    }

    return const AppShell(initialIndex: 0);
  }
}
