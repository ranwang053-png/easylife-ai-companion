import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.color = AppColors.surface,
    this.borderColor = AppColors.outline,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 1.2,
      shadowColor: AppColors.primaryDark.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: borderColor.withValues(alpha: .72)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primarySoft.withValues(alpha: .4),
        highlightColor: AppColors.primaryMist.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(28),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
