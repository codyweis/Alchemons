import 'package:alchemons/utils/app_font_family.dart';
import 'package:flutter/material.dart';

import 'package:alchemons/widgets/app_icons.dart';

import 'cosmic_screen_styles.dart';

class CosmicOverlayBackdrop extends StatelessWidget {
  const CosmicOverlayBackdrop({
    super.key,
    required this.child,
    this.onTap,
    this.alpha = 0.94,
    this.safeArea = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double alpha;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: CosmicScreenStyles.bg0.withValues(alpha: alpha),
      child: safeArea ? SafeArea(child: child) : child,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class CosmicPlate extends StatelessWidget {
  const CosmicPlate({
    super.key,
    required this.child,
    this.accent = CosmicScreenStyles.textMuted,
    this.padding = const EdgeInsets.all(16),
    this.background = CosmicScreenStyles.bg1,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CosmicBracketPainter(
        color: accent.withValues(alpha: 0.55),
        strokeWidth: 1.4,
        bracketSize: 22,
      ),
      child: Container(color: background, padding: padding, child: child),
    );
  }
}

class CosmicPanelHeader extends StatelessWidget {
  const CosmicPanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = CosmicScreenStyles.amber,
    this.leading,
    this.trailing,
    this.center = false,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? leading;
  final Widget? trailing;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CosmicTag(label: title, color: accent),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontFamily: appFontFamily(context),
              color: CosmicScreenStyles.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ],
    );

    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Align(
            alignment: center ? Alignment.center : Alignment.centerLeft,
            child: titleWidget,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class CosmicTag extends StatelessWidget {
  const CosmicTag({
    super.key,
    required this.label,
    this.color = CosmicScreenStyles.amber,
    this.small = false,
  });

  final String label;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: small ? 12 : 16,
          color: color.withValues(alpha: 0.82),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: appFontFamily(context),
            color: color,
            fontSize: small ? 9 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: small ? 1.3 : 1.8,
          ),
        ),
      ],
    );
  }
}

class CosmicEtchedDivider extends StatelessWidget {
  const CosmicEtchedDivider({
    super.key,
    this.accent = CosmicScreenStyles.amber,
  });

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: CosmicScreenStyles.textMuted.withValues(alpha: 0.28),
          ),
        ),
        const SizedBox(width: 7),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.62),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Container(
            height: 1,
            color: CosmicScreenStyles.textMuted.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class CosmicIconButton extends StatelessWidget {
  const CosmicIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.accent = CosmicScreenStyles.textSecondary,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: CosmicScreenStyles.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, color: accent, size: 18),
      ),
    );
  }
}

class _CosmicBracketPainter extends CustomPainter {
  const _CosmicBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.bracketSize,
  });

  final Color color;
  final double strokeWidth;
  final double bracketSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final s = bracketSize;
    canvas.drawLine(Offset.zero, Offset(s, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, s), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - s, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, s), paint);
    canvas.drawLine(Offset(0, size.height), Offset(s, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - s), paint);
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - s, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - s),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CosmicBracketPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        bracketSize != oldDelegate.bracketSize;
  }
}


/// The dismiss control every cosmic panel uses.
///
/// One widget so the panels cannot drift apart visually. Note that X means
/// *close the panel stack entirely* — a panel that also has a parent carries a
/// separate docked BACK for stepping up one level.
class CosmicCloseButton extends StatelessWidget {
  const CosmicCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(AppIcons.close_rounded),
      color: CosmicScreenStyles.textSecondary,
      splashRadius: 20,
      tooltip: 'Close',
    );
  }
}
