import 'package:flutter/material.dart';

import '../../rdb/rdb_model.dart';
import '../theme/app_theme.dart';

IconData iconForKind(RdbValueKind kind) {
  switch (kind) {
    case RdbValueKind.string:
      return Icons.short_text;
    case RdbValueKind.list:
      return Icons.reorder;
    case RdbValueKind.hash:
      return Icons.view_column_outlined;
    case RdbValueKind.set:
      return Icons.scatter_plot_outlined;
    case RdbValueKind.zset:
      return Icons.sort;
  }
}

/// Foreground/background pair for a value kind, in the pastel palette used
/// throughout the redesign (list-row icon tiles, filter chips, stat cards).
(Color fg, Color bg) colorsForKind(RdbValueKind kind) {
  switch (kind) {
    case RdbValueKind.string:
      return (AppColors.info, AppColors.infoBg);
    case RdbValueKind.list:
      return (AppColors.success, AppColors.successBg);
    case RdbValueKind.hash:
      return (const Color(0xFF7C5CFC), const Color(0xFFEFEAFE));
    case RdbValueKind.set:
      return (AppColors.warning, AppColors.warningBg);
    case RdbValueKind.zset:
      return (AppColors.danger, AppColors.dangerBg);
  }
}

/// A small rounded-square icon tile identifying a value's type - mirrors
/// the colored app-icon tiles in the reference design's key/table rows.
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.kind, this.size = 36});
  final RdbValueKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = colorsForKind(kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      alignment: Alignment.center,
      child: Icon(iconForKind(kind), size: size * 0.5, color: fg),
    );
  }
}
