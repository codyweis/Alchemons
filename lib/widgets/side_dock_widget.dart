import 'package:flutter/material.dart';
import 'package:alchemons/utils/faction_util.dart';

class SideDockFloating extends StatelessWidget {
  final FactionTheme theme;
  final VoidCallback onEnhance;
  final VoidCallback onHarvest;
  final VoidCallback onCompetitions;
  final VoidCallback onBattle;
  final VoidCallback onField;
  final bool highlightField; // NEW: Add highlight parameter
  final bool showHarvestDot; // NEW

  const SideDockFloating({
    super.key,
    required this.theme,
    required this.onEnhance,
    required this.onHarvest,
    required this.onCompetitions,
    required this.onBattle,
    required this.onField,
    this.highlightField = false, // NEW: Default to false
    this.showHarvestDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _FloatingSideButton(
          theme: theme,
          label: 'Field',
          assetPath: 'assets/images/ui/fieldicon.png',
          onTap: onField,
          size: 60,
          highlight: highlightField, // NEW: Pass highlight state
        ),

        const SizedBox(height: 16),
        _FloatingSideButton(
          theme: theme,
          label: 'Enhance',
          assetPath: 'assets/images/ui/enhanceicon.png',
          onTap: onEnhance,
        ),
        const SizedBox(height: 16),
        _FloatingSideButton(
          theme: theme,
          label: 'Extract',
          assetPath: 'assets/images/ui/extracticon.png',
          onTap: onHarvest,
          showDot: showHarvestDot,
        ),
        const SizedBox(height: 16),
        _FloatingSideButton(
          theme: theme,
          label: 'Compete',
          assetPath: 'assets/images/ui/competeicon.png',
          onTap: onBattle,
          size: 80,
        ),
      ],
    );
  }
}

class _FloatingSideButton extends StatefulWidget {
  final FactionTheme theme;
  final String label;
  final String assetPath;
  final VoidCallback onTap;
  final double size;
  final bool highlight; // NEW: Add highlight parameter
  final bool showDot;

  const _FloatingSideButton({
    required this.theme,
    required this.label,
    required this.assetPath,
    required this.onTap,
    this.size = 60,
    this.highlight = false, // NEW: Default to false
    this.showDot = false,
  });

  @override
  State<_FloatingSideButton> createState() => _FloatingSideButtonState();
}

class _FloatingSideButtonState extends State<_FloatingSideButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.highlight) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_FloatingSideButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight != oldWidget.highlight) {
      if (widget.highlight) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageWithBadge = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Image.asset(
              widget.assetPath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          ),
          if (widget.showDot)
            const Positioned(
              right: -2, // tweak if your asset has extra padding
              top: -2,
              child: _RedDotTiny(),
            ),
        ],
      ),
    );

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          imageWithBadge,
          Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              color: widget.theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    if (widget.highlight) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // glow ring
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.accent.withOpacity(0.6),
                          blurRadius: 25,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: widget.theme.accent.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ),
                // pulsing border
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.theme.accent.withOpacity(0.8),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                button,
              ],
            ),
          );
        },
      );
    }

    return button;
  }
}

class _RedDotTiny extends StatelessWidget {
  const _RedDotTiny();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
