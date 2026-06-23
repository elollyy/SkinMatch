import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_layout.dart';
import 'home_screen.dart';
import 'intensive_course_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialIndex = 0,
    this.initialCourseProductId,
  });

  final int initialIndex;
  final String? initialCourseProductId;

  static AppShellState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<AppShellState>();
  }

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  static const int homeTabIndex = 0;
  static const int careTabIndex = 1;
  static const int courseTabIndex = 2;
  static const int profileTabIndex = 3;

  static final List<_ShellDestination> _destinations = [
    _ShellDestination(
      label: 'Главная',
      icon: Icons.home_outlined,
      screen: HomeScreen(),
    ),
    _ShellDestination(
      label: 'Уход',
      icon: Icons.auto_awesome_outlined,
      screen: ResultScreen(
        onOpenProductUrl: (url) async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    ),
    _ShellDestination(
      label: 'Курс',
      icon: Icons.calendar_month_outlined,
      screen: IntensiveCourseScreen(),
    ),
    _ShellDestination(
      label: 'Профиль',
      icon: Icons.person_outline,
      screen: ProfileScreen(),
    ),
  ];

  late int _currentIndex = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    _applyInitialCourseSelection();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
    if (oldWidget.initialCourseProductId != widget.initialCourseProductId) {
      _applyInitialCourseSelection();
    }
  }

  void switchTab(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> openIntensiveCourse([String? productId]) async {
    final userService = context.read<UserService>();
    if (productId != null && userService.canStartIntensiveCourse(productId)) {
      await userService.selectActiveIntensiveCourse(productId);
      if (!mounted) {
        return;
      }
    }

    switchTab(courseTabIndex);
  }

  void _applyInitialCourseSelection() {
    final productId = widget.initialCourseProductId;
    if (productId == null || productId.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        openIntensiveCourse(productId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = AppLayout.useDesktopShell(context);
    final borderColor = isDark
        ? AppColors.neutral100Dark
        : AppColors.neutral100;
    final shellBackgroundColor = Theme.of(
      context,
    ).scaffoldBackgroundColor.withValues(alpha: 0.94);

    return Scaffold(
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: BoxDecoration(
                color: shellBackgroundColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: Row(
                    key: const Key('shell_nav_mobile'),
                    children: [
                      for (
                        var index = 0;
                        index < _destinations.length;
                        index++
                      ) ...[
                        Expanded(
                          child: _NavButton(
                            key: Key('shell_nav_$index'),
                            destination: _destinations[index],
                            isActive: _currentIndex == index,
                            isDark: isDark,
                            onTap: () => switchTab(index),
                            compact: true,
                          ),
                        ),
                        if (index != _destinations.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              decoration: BoxDecoration(
                color: shellBackgroundColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppLayout.maxWidthFor(AppPageWidth.wide),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 28 : 18,
                      18,
                      isDesktop ? 28 : 18,
                      isDesktop ? 18 : 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ShellBrand(
                            isDark: isDark,
                            currentLabel: _destinations[_currentIndex].label,
                            isDesktop: isDesktop,
                          ),
                        ),
                        if (isDesktop)
                          Row(
                            key: const Key('shell_nav_desktop'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var index = 0;
                                index < _destinations.length;
                                index++
                              ) ...[
                                _NavButton(
                                  key: Key('shell_nav_$index'),
                                  destination: _destinations[index],
                                  isActive: _currentIndex == index,
                                  isDark: isDark,
                                  onTap: () => switchTab(index),
                                ),
                                if (index != _destinations.length - 1)
                                  const SizedBox(width: 10),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: !isDesktop,
              child: IndexedStack(
                index: _currentIndex,
                children: _destinations.map((tab) => tab.screen).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final Widget screen;
}

class _ShellBrand extends StatelessWidget {
  const _ShellBrand({
    required this.isDark,
    required this.currentLabel,
    required this.isDesktop,
  });

  final bool isDark;
  final String currentLabel;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SkinMatch',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.neutral900Dark : AppColors.neutral900,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.destination,
    required this.isActive,
    required this.onTap,
    required this.isDark,
    this.compact = false,
  });

  final _ShellDestination destination;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? AppColors.rose400Dark : AppColors.rose400;
    final inactiveColor = isDark
        ? AppColors.neutral700Dark
        : AppColors.neutral700;
    final backgroundColor = isActive
        ? (isDark ? AppColors.rose50Dark : AppColors.rose50)
        : (isDark
              ? AppColors.neutral100Dark.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.5));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 18 : 999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(compact ? 18 : 999),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.4)
                : (isDark ? AppColors.neutral100Dark : AppColors.neutral100),
          ),
        ),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    destination.icon,
                    size: 20,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    destination.icon,
                    size: 18,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    destination.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
