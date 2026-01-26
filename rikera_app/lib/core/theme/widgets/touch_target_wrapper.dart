import 'package:flutter/material.dart';
import 'package:rikera_app/core/theme/app_theme.dart';

/// Wrapper widget that ensures minimum touch target size for driving safety.
///
/// This widget wraps any child widget and ensures it meets the minimum
/// 48dp touch target size requirement for car-optimized UI.
///
/// Requirements: 9.1
class TouchTargetWrapper extends StatelessWidget {
  const TouchTargetWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.minSize = AppSizes.minTouchTarget,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: Center(child: child),
            )
          : Center(child: child),
    );
  }
}

/// Icon button with guaranteed minimum touch target size
class CarOptimizedIconButton extends StatelessWidget {
  const CarOptimizedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = AppSizes.iconLarge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      tooltip: tooltip,
      color: color,
      iconSize: size,
      constraints: const BoxConstraints(
        minWidth: AppSizes.minTouchTarget,
        minHeight: AppSizes.minTouchTarget,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
    );

    return button;
  }
}

/// Text button with guaranteed minimum touch target size
class CarOptimizedTextButton extends StatelessWidget {
  const CarOptimizedTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppSizes.iconMedium),
                const SizedBox(width: AppSpacing.sm),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}

/// Elevated button with guaranteed minimum touch target size
class CarOptimizedElevatedButton extends StatelessWidget {
  const CarOptimizedElevatedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLarge = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(
          AppSizes.minTouchTarget,
          isLarge ? AppSizes.buttonHeightLarge : AppSizes.buttonHeight,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isLarge ? AppSpacing.xl : AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        textStyle: isLarge
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.titleMedium,
      ),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: isLarge ? AppSizes.iconLarge : AppSizes.iconMedium,
                ),
                SizedBox(width: isLarge ? AppSpacing.md : AppSpacing.sm),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}

/// List tile with guaranteed minimum touch target size
class CarOptimizedListTile extends StatelessWidget {
  const CarOptimizedListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
