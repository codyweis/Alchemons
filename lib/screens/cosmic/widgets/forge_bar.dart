import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'cosmic_screen_styles.dart';

class ForgeBar extends StatelessWidget {
  const ForgeBar({
    super.key,
    required this.label,
    required this.value,
    required this.pct,
    required this.barColor,
  });

  final String label;
  final String value;
  final double pct;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: CosmicScreenStyles.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: barColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 5,
          decoration: BoxDecoration(
            color: CosmicScreenStyles.bg0,
            borderRadius: BorderRadius.circular(1),
            border: Border.all(color: CosmicScreenStyles.borderDim, width: 0.5),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: pct.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// VIRTUAL JOYSTICK
// ─────────────────────────────────────────────────────────
