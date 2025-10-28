import 'package:flutter/material.dart';
import 'package:alchemons/utils/faction_util.dart';

class SideDockFloating extends StatelessWidget {
  final FactionTheme theme;
  final VoidCallback onEnhance;
  final VoidCallback onHarvest;
  final VoidCallback onCompetitions;

  const SideDockFloating({
    super.key,
    required this.theme,
    required this.onEnhance,
    required this.onHarvest,
    required this.onCompetitions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
        ),
        const SizedBox(height: 16),
        _FloatingSideButton(
          theme: theme,
          label: 'Compete',
          assetPath: 'assets/images/ui/competeicon.png',
          onTap: onCompetitions,
          size: 80,
        ),
      ],
    );
  }
}

class _FloatingSideButton extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final String assetPath;
  final VoidCallback onTap;
  final double size;

  const _FloatingSideButton({
    required this.theme,
    required this.label,
    required this.assetPath,
    required this.onTap,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // circular "badge" button
          SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Image.asset(
                assetPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
