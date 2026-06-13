import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
