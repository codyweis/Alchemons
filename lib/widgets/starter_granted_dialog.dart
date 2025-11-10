// lib/ui/system_dialog.dart
import 'dart:async';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:flutter/material.dart';

enum SystemDialogKind { info, success, warning, danger }

class SystemDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool typewriter;
  final SystemDialogKind kind;
  final IconData? icon;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const SystemDialog({
    super.key,
    required this.title,
    required this.message,
    this.typewriter = false,
    this.kind = SystemDialogKind.info,
    this.icon,
    this.primaryLabel = 'ACKNOWLEDGE',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  Color _frameColor(BuildContext context) {
    switch (kind) {
      case SystemDialogKind.success:
        return const Color(0xFF9BE79B);
      case SystemDialogKind.warning:
        return const Color(0xFFFFE08A);
      case SystemDialogKind.danger:
        return const Color(0xFFFF9BA3);
      case SystemDialogKind.info:
      default:
        return Colors.white.withOpacity(0.4);
    }
  }

  IconData? _iconForKind() {
    if (icon != null) return icon!;
    switch (kind) {
      case SystemDialogKind.success:
        return null;
      case SystemDialogKind.warning:
        return Icons.warning_amber_outlined;
      case SystemDialogKind.danger:
        return Icons.gpp_bad_outlined;
      case SystemDialogKind.info:
      default:
        return null;
    }
  }

  static Future<void> playStory(
    BuildContext context,
    List<StoryPage> pages,
  ) async {
    for (final page in pages) {
      await SystemDialog.show(
        context,
        title: page.subtitle ?? '---',
        message: page.mainText,
        typewriter: page.useTypewriterEffect,
        kind: SystemDialogKind.info,
        primaryLabel: 'CONTINUE',
        barrierDismissible: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frameColor(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: frame, width: 1.5),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconForKind(), size: 42, color: Colors.white),
            ),
            const SizedBox(height: 24),

            // title
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 16),

            // divider
            Container(
              width: 80,
              height: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 20),

            // body
            if (typewriter)
              _TypewriterText(
                message: message,
                maxHeight: 96,
                typingDelay: const Duration(milliseconds: 20),
              )
            else
              SizedBox(
                height: 96,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // actions
            Row(
              children: [
                if (secondaryLabel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        onSecondary?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      child: Text(
                        secondaryLabel!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onPrimary?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2.0,
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

  // convenience static helper
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    bool typewriter = false,
    SystemDialogKind kind = SystemDialogKind.info,
    IconData? icon,
    String primaryLabel = 'ACKNOWLEDGE',
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool barrierDismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => SystemDialog(
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

/// Reusable typewriter text used by all system dialogs.
class _TypewriterText extends StatefulWidget {
  final String message;
  final Duration typingDelay;
  final double maxHeight;

  const _TypewriterText({
    required this.message,
    this.typingDelay = const Duration(milliseconds: 18),
    this.maxHeight = 96,
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
    return SizedBox(
      height: widget.maxHeight,
      child: Align(
        alignment: Alignment.topCenter,
        child: Text(
          widget.message.substring(0, _i) + cursor,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.9),
            height: 1.5,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
