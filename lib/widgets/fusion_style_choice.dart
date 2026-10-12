// lib/widgets/fusion_style_choice.dart
//
// The fusion styles owned (the Athanor's), each a small still of two
// fusing in that style, and the plain fusion; the one worn lit from below.
// One style for the whole game: the profile's COSMETICS section holds this,
// as a strip that scrolls sideways.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/choice_strip.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_previews.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class FusionStyleChoice extends StatelessWidget {
  const FusionStyleChoice({
    super.key,
    required this.palette,
    required this.accent,
    this.padding = EdgeInsets.zero,
  });

  final BracketPalette palette;
  final Color accent;

  /// Around the strip, inside its scroll: the tiles run out to its edges.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final wear = context.watch<CosmeticWearService?>();
    if (wear == null) return const SizedBox.shrink();
    final worn = wear.fusionStyle;
    final styles = <FusionStyle?>[null, ...wear.ownedFusionStyles];
    return ChoiceStrip(
      selected: styles.indexOf(worn),
      padding: padding,
      children: [
        for (final f in styles)
          GestureDetector(
            key: ValueKey('fusion-style-${f?.id ?? 'plain'}'),
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(() {
              if (f == worn) return;
              HapticFeedback.selectionClick();
              wear.wearFusionStyle(f);
            }),
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: f == worn ? accent : palette.line,
                strokeWidth: 1.2,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 76,
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                color: f == worn
                    ? palette.accentWash(accent, darkAlpha: 0.18)
                    : palette.bg0,
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: 56,
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _FusionStill(f)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        (f == null
                                ? 'Plain'
                                : f.title.replaceAll(' Fusion', ''))
                            .toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: f == worn ? palette.ink : palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FusionStill extends CustomPainter {
  const _FusionStill(this.style);

  final FusionStyle? style;

  @override
  void paint(Canvas canvas, Size size) => paintFusionStylePreview(
    canvas,
    style,
    Offset.zero & size,
    fusionStyleShowcaseTime(style),
  );

  @override
  bool shouldRepaint(_FusionStill old) => old.style != style;
}
