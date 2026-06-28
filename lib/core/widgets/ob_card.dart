import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// ===============================================================
/// OpenBackup
/// File : ob_card.dart
/// Version : 1.0.0
/// Layer : Widgets/Base
/// Description : Global reusable application card.
/// Author : OpenBackup Contributors
/// License : Apache 2.0
/// ===============================================================

class OBCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? borderRadius;

  const OBCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      borderRadius ?? AppSizes.radiusL,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.card,
            borderRadius: radius,
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Padding(
            padding: padding ??
                const EdgeInsets.all(
                  AppSizes.cardPadding,
                ),
            child: child,
          ),
        ),
      ),
    );
  }
}