import 'package:flutter/material.dart';

class DatabaseTypingAnimation extends StatefulWidget {
  final List<Widget> children;
  final bool startAnimation;
  final Duration delayBetweenItems;
  final Duration typingSpeed;
  final VoidCallback? onComplete; // Added callback

  const DatabaseTypingAnimation({
    super.key,
    required this.children,
    this.startAnimation = false,
    this.delayBetweenItems = const Duration(milliseconds: 300),
    this.typingSpeed = const Duration(milliseconds: 50),
    this.onComplete, // Added parameter
  });

  @override
  State<DatabaseTypingAnimation> createState() =>
      _DatabaseTypingAnimationState();
}

class _DatabaseTypingAnimationState extends State<DatabaseTypingAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  final List<bool> _itemVisible = [];

  @override
  void initState() {
    super.initState();

    // Initialize visibility states
    for (int i = 0; i < widget.children.length; i++) {
      _itemVisible.add(false);
    }

    // Create controllers for each item
    _controllers = List.generate(
      widget.children.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );

    // Create fade animations
    _fadeAnimations = _controllers
        .map(
          (controller) => Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut)),
        )
        .toList();
  }

  @override
  void didUpdateWidget(DatabaseTypingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startAnimation && !oldWidget.startAnimation) {
      _startTypingSequence();
    }
  }

  void _startTypingSequence() async {
    for (int i = 0; i < widget.children.length; i++) {
      await Future.delayed(widget.delayBetweenItems);
      if (mounted) {
        setState(() => _itemVisible[i] = true);
        await _controllers[i].forward(); // Wait for animation to complete
      }
    }

    // Call the completion callback after all animations are done
    if (mounted && widget.onComplete != null) {
      // Add a small delay to ensure all animations have fully completed
      await Future.delayed(const Duration(milliseconds: 200));
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.children.length, (index) {
        return AnimatedBuilder(
          animation: _fadeAnimations[index],
          builder: (context, child) {
            if (!_itemVisible[index]) {
              return const SizedBox.shrink();
            }

            return Opacity(
              opacity: _fadeAnimations[index].value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _fadeAnimations[index].value)),
                child: widget.children[index],
              ),
            );
          },
        );
      }),
    );
  }
}

class TypingTextAnimation extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration typingSpeed;
  final bool startTyping;

  const TypingTextAnimation({
    super.key,
    required this.text,
    this.style,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.startTyping = false,
  });

  @override
  State<TypingTextAnimation> createState() => _TypingTextAnimationState();
}

class _TypingTextAnimationState extends State<TypingTextAnimation> {
  String _displayedText = '';
  int _currentIndex = 0;

  @override
  void didUpdateWidget(TypingTextAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startTyping && !oldWidget.startTyping) {
      _startTyping();
    }
  }

  void _startTyping() async {
    _currentIndex = 0;
    _displayedText = '';

    while (_currentIndex < widget.text.length) {
      if (mounted) {
        setState(() {
          _displayedText = widget.text.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
        await Future.delayed(widget.typingSpeed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(_displayedText, style: widget.style)),
        if (_currentIndex < widget.text.length)
          Container(
            width: 2,
            height: 16,
            color: Colors.indigo.shade600,
            child: AnimatedOpacity(
              opacity: DateTime.now().millisecond % 1000 < 500 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Container(color: Colors.indigo.shade600),
            ),
          ),
      ],
    );
  }
}
