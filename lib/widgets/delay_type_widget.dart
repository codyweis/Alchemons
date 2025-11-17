// Helper widget for delayed typing
import 'package:alchemons/widgets/animations/database_typing_animation.dart';
import 'package:flutter/material.dart';

class DelayedTypingText extends StatefulWidget {
  final String text;
  final Duration delay;
  final TextStyle? style;

  const DelayedTypingText({
    super.key,
    required this.text,
    this.delay = Duration.zero,
    this.style,
  });

  @override
  State<DelayedTypingText> createState() => _DelayedTypingTextState();
}

class _DelayedTypingTextState extends State<DelayedTypingText> {
  bool _startTyping = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() => _startTyping = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TypingTextAnimation(
      text: widget.text,
      style: widget.style,
      startTyping: _startTyping,
      typingSpeed: const Duration(milliseconds: 10),
    );
  }
}
