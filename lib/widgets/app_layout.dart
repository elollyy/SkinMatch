import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppPageWidth { narrow, medium, wide }

class AppLayout {
  const AppLayout._();

  static double maxWidthFor(AppPageWidth width) {
    switch (width) {
      case AppPageWidth.narrow:
        return 520;
      case AppPageWidth.medium:
        return 760;
      case AppPageWidth.wide:
        return 1080;
    }
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth >= 1280) {
      return const EdgeInsets.symmetric(horizontal: 40, vertical: 32);
    }
    if (screenWidth >= 840) {
      return const EdgeInsets.symmetric(horizontal: 28, vertical: 28);
    }
    return const EdgeInsets.symmetric(horizontal: 18, vertical: 20);
  }

  static bool useDesktopShell(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 840;
  }
}

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.child,
    this.width = AppPageWidth.medium,
    this.scrollable = false,
    this.padding,
    this.backgroundColor,
  });

  final Widget child;
  final AppPageWidth width;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: AppPageBody(
        width: width,
        scrollable: scrollable,
        padding: padding,
        child: child,
      ),
    );
  }
}

class AppPageBody extends StatelessWidget {
  const AppPageBody({
    super.key,
    required this.child,
    this.width = AppPageWidth.medium,
    this.scrollable = false,
    this.padding,
    this.topSafeArea = true,
    this.bottomSafeArea = true,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final AppPageWidth width;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final bool topSafeArea;
  final bool bottomSafeArea;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: topSafeArea,
      bottom: bottomSafeArea,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolvedPadding = padding ?? AppLayout.pagePadding(context);
          final content = Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppLayout.maxWidthFor(width),
                minHeight: constraints.maxHeight,
              ),
              child: Padding(padding: resolvedPadding, child: child),
            ),
          );

          if (scrollable) {
            return SingleChildScrollView(child: content);
          }

          return SizedBox.expand(child: content);
        },
      ),
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.backgroundColor,
    this.borderColor,
    this.radius = 28,
    this.shadowOpacity,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double radius;
  final double? shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark
                ? AppColors.neutral50Dark.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.92)),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              borderColor ??
              (isDark
                  ? AppColors.neutral100Dark.withValues(alpha: 0.9)
                  : AppColors.neutral100.withValues(alpha: 0.9)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: shadowOpacity ?? (isDark ? 0.12 : 0.045),
            ),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.trailing,
    this.centered = false,
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final Widget? trailing;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final crossAxisAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!, style: textTheme.labelMedium, textAlign: textAlign),
          const SizedBox(height: 10),
        ],
        Text(title, style: textTheme.headlineMedium, textAlign: textAlign),
        if (description != null) ...[
          const SizedBox(height: 10),
          Text(description!, style: textTheme.bodyMedium, textAlign: textAlign),
        ],
        if (trailing != null) ...[const SizedBox(height: 18), trailing!],
      ],
    );
  }
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text(label),
    );
  }
}

class AppInfoChip extends StatelessWidget {
  const AppInfoChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBackground = isDark
        ? AppColors.neutral100Dark.withValues(alpha: 0.9)
        : AppColors.neutral50;
    final defaultForeground = isDark
        ? AppColors.neutral700Dark
        : AppColors.neutral700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: foregroundColor ?? defaultForeground,
        ),
      ),
    );
  }
}
