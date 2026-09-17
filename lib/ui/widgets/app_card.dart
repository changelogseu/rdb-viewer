import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A white, rounded, softly-shadowed surface - the base "floating card"
/// building block used throughout the redesigned UI (panels, stat tiles,
/// dialogs-within-content).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.radius = AppRadius.xl});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? AppColors.border),
        boxShadow: AppShadows.card(Theme.of(context).brightness),
      ),
      child: child,
    );
  }
}
