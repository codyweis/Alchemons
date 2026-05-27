import 'package:flutter/material.dart';

/// Mobile-first design tokens for Alchemons.
///
/// Use these instead of inline `fontSize:`, padding numbers, or hardcoded
/// widths/heights on tap targets. The goal: one place to tune readability
/// and tap ergonomics across the whole game.
///
/// Floors:
///   - No text smaller than [AppType.caption] (12px).
///   - No tap target smaller than [AppTap.min] (44px, Apple HIG).
class AppType {
  AppType._();

  /// Smallest allowed body text. Use for sparse, low-priority labels only.
  static const double caption = 12;

  /// Default in-game body text (stat values, list rows, pill amounts).
  static const double body = 14;

  /// Slightly larger body, for primary readable copy in dialogs and panels.
  static const double bodyLg = 16;

  /// Section titles, dialog titles, prominent counters.
  static const double title = 18;

  /// Secondary headings (sheet titles, dialog headers with hierarchy).
  static const double h2 = 22;

  /// Page-level headings — sparingly.
  static const double h1 = 28;
}

class AppWeight {
  AppWeight._();
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppIcon {
  AppIcon._();
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}

class AppTap {
  AppTap._();

  /// Apple HIG minimum tap target. Hard floor — enforce on all
  /// interactive widgets via [SizedBox], [ConstrainedBox], or
  /// [IconButton]'s default size.
  static const double min = 44;

  /// Comfortable tap target for primary actions on mobile.
  static const double comfort = 48;
}

class AppRadius {
  AppRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double pill = 999;
}

/// Convenience: wraps any interactive child so it meets the 44px tap floor
/// even if its visual content is smaller.
///
/// Example:
/// ```dart
/// TapTarget(
///   onTap: _close,
///   child: const Icon(AppIcons.close, size: AppIcon.md),
/// )
/// ```
class TapTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final BorderRadius? borderRadius;

  const TapTarget({
    super.key,
    required this.child,
    this.onTap,
    this.size = AppTap.min,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}
