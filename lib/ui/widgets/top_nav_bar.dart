import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's top navigation bar: logo on the left, an optional pill-style
/// tab strip in the middle, and action buttons on the right. Deliberately
/// not a Flutter `AppBar` (which enforces a fixed toolbar layout) - this is
/// a plain container so the pill nav and generous spacing can match the
/// reference design exactly.
class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  const TopNavBar({
    super.key,
    required this.fileName,
    this.tabController,
    this.tabs,
    required this.actions,
  });

  final String? fileName;
  final TabController? tabController;
  final List<Widget>? tabs;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerTheme.color ?? AppColors.border;

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          _Logo(isDark: isDark),
          if (fileName != null) ...[
            const SizedBox(width: 14),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.pageBackground.withValues(alpha: isDark ? 0.08 : 1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: border),
                ),
                child: Text(
                  fileName!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          if (tabController != null && tabs != null)
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.pageBackground.withValues(alpha: isDark ? 0.06 : 1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: border),
                ),
                child: TabBar(
                  controller: tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: EdgeInsets.zero,
                  indicator: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  labelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  tabs: tabs!,
                ),
              ),
            ),
          const Spacer(),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.storage_rounded, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(
          'RDB Viewer',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// A round, muted-background icon button matching the reference's
/// notification/help/settings icons in the nav bar.
class NavIconButton extends StatelessWidget {
  const NavIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(icon: Icon(icon, size: 19), tooltip: tooltip, onPressed: onPressed),
    );
  }
}

/// The bold black pill CTA button, e.g. "RDB-Datei öffnen".
class NavPrimaryButton extends StatelessWidget {
  const NavPrimaryButton({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}
