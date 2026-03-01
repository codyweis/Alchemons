// lib/widgets/wilderness/landscape_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';

enum LandscapeDialogKind { info, success, warning, danger }

class LandscapeDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool typewriter;
  final LandscapeDialogKind kind;
  final IconData? icon;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const LandscapeDialog({
    super.key,
    required this.title,
    required this.message,
    this.typewriter = false,
    this.kind = LandscapeDialogKind.info,
    this.icon,
    this.primaryLabel = 'CONTINUE',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  Color _frameColor(BuildContext context) {
    switch (kind) {
      case LandscapeDialogKind.success:
        return const Color(0xFF9BE79B);
      case LandscapeDialogKind.warning:
        return const Color(0xFFFFE08A);
      case LandscapeDialogKind.danger:
        return const Color(0xFFFF9BA3);
      case LandscapeDialogKind.info:
        return Colors.white.withValues(alpha: 0.5);
    }
  }

  IconData? _iconForKind() {
    if (icon != null) return icon!;
    switch (kind) {
      case LandscapeDialogKind.success:
        return Icons.check_circle_outline;
      case LandscapeDialogKind.warning:
        return Icons.warning_amber_outlined;
      case LandscapeDialogKind.danger:
        return Icons.gpp_bad_outlined;
      case LandscapeDialogKind.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frameColor(context);
    final displayIcon = _iconForKind();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 600, // Limit width for landscape
          maxHeight: 280, // Compact height for landscape
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: frame, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: frame.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon + Title row for landscape
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (displayIcon != null) ...[
                  Icon(displayIcon, color: frame, size: 28),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Divider
            Container(
              width: 100,
              height: 1,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),

            // Message body (constrained for landscape)
            Flexible(
              child: SingleChildScrollView(
                child: typewriter
                    ? _TypewriterText(
                        message: message,
                        typingDelay: const Duration(milliseconds: 20),
                      )
                    : Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4,
                          fontFamily: 'monospace',
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (secondaryLabel != null) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        onSecondary?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      child: Text(
                        secondaryLabel!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: secondaryLabel != null ? 1 : 2,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onPrimary?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: frame, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Convenience static helper
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    bool typewriter = false,
    LandscapeDialogKind kind = LandscapeDialogKind.info,
    IconData? icon,
    String primaryLabel = 'CONTINUE',
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool barrierDismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => LandscapeDialog(
        title: title,
        message: message,
        typewriter: typewriter,
        kind: kind,
        icon: icon,
        primaryLabel: primaryLabel,
        onPrimary: onPrimary,
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
      ),
    );
  }
}

/// Typewriter text effect for landscape dialog
class _TypewriterText extends StatefulWidget {
  final String message;
  final Duration typingDelay;

  const _TypewriterText({
    required this.message,
    this.typingDelay = const Duration(milliseconds: 20),
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.typingDelay, (_) {
      if (!mounted) return;
      if (_i >= widget.message.length) {
        _timer?.cancel();
      } else {
        setState(() => _i++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _i >= widget.message.length;
    final cursor = done ? '' : '▌';
    return Text(
      widget.message.substring(0, _i) + cursor,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withValues(alpha: 0.85),
        height: 1.4,
        fontFamily: 'monospace',
        letterSpacing: 0.4,
      ),
    );
  }
}
