import 'dart:ui'; // for BackdropFilter
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

class GlowingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final AnimationController controller;

  /// Optional tap override. If provided, we call this instead of showing the dialog.
  final VoidCallback? onPressed;

  /// If [onPressed] is null and [dialogTitle] is non-null, tapping will show a default dialog.
  final String? dialogTitle;
  final String? dialogMessage;

  /// Optional: fully custom dialog content. If set, it overrides [dialogTitle]/[dialogMessage].
  final WidgetBuilder? dialogBuilder;

  /// Styling knobs for the built-in dialog.
  final Color? dialogAccentColor; // defaults to [color]
  final Color? barrierColor; // defaults to semi-opaque black

  /// Hit target/icon sizing
  final double minTapSize;
  final double iconSize;
  final String? tooltip;

  const GlowingIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.controller,
    this.onPressed,
    this.dialogTitle,
    this.dialogMessage,
    this.dialogBuilder,
    this.dialogAccentColor,
    this.barrierColor,
    this.minTapSize = 40,
    this.iconSize = 18,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final core = AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final glow = 0.35 + controller.value * 0.4;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,

            border: Border.all(color: color.withValues(alpha: glow)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: glow * .4),
                blurRadius: 20 + controller.value * 14,
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: color),
        );
      },
    );

    final tappable = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minTapSize, minHeight: minTapSize),
      child: Center(child: core),
    );

    final wrapped = Material(
      type: MaterialType.transparency,
      child: InkResponse(
        onTap: () => _handleTap(context),
        radius: (minTapSize / 2) + 6,
        customBorder: const CircleBorder(),
        child: tappable,
      ),
    );

    return tooltip != null
        ? Tooltip(message: tooltip!, child: wrapped)
        : wrapped;
  }

  void _handleTap(BuildContext context) {
    if (onPressed != null) {
      onPressed!();
      return;
    }

    // If a custom builder is provided, show that
    if (dialogBuilder != null) {
      showDialog(
        context: context,
        barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.7),
        builder: dialogBuilder!,
      );
      return;
    }

    // If we have title/message, show the built-in glass dialog
    if (dialogTitle != null || dialogMessage != null) {
      final accent = dialogAccentColor ?? color;
      final forgeTheme = FactionTheme.scorchForge();
      final t = ForgeTokens(forgeTheme);
      showDialog(
        context: context,
        barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.7),
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.bg1.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: t.borderAccent.withValues(alpha: 0.9),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: accent.withValues(alpha: 0.14),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 24,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(icon, color: accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (dialogTitle ?? 'Info').toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 1, color: t.borderMid),
                      if ((dialogMessage ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogMessage!,
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  t.amberDim.withValues(alpha: 0.44),
                                  accent.withValues(alpha: 0.18),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              'GOT IT',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.amberBright,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }
}
