import 'dart:ui'; // for BackdropFilter
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

            border: Border.all(color: color.withOpacity(glow)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(glow * .4),
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
        barrierColor: barrierColor ?? Colors.black.withOpacity(0.7),
        builder: dialogBuilder!,
      );
      return;
    }

    // If we have title/message, show the built-in glass dialog
    if (dialogTitle != null || dialogMessage != null) {
      final accent = dialogAccentColor ?? color;
      showDialog(
        context: context,
        barrierColor: barrierColor ?? Colors.black.withOpacity(0.7),
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0F14).withOpacity(0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogTitle ?? 'Info',
                              style: const TextStyle(
                                color: Color(0xFFE8EAED),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFFE8EAED),
                            ),
                          ),
                        ],
                      ),
                      if ((dialogMessage ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          dialogMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB6C0CC),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Got it',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
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
