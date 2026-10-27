// lib/screens/cosmic/widgets/planet_action_button.dart
//
// A planet-surface action — DESCEND, ENTER RAID, SUMMON RAID, UNSEAL GATE —
// on the placard that floats over a planet in space.
//
// It was a full-width plate washed in the accent, a small mark beside a word
// in the console's type: on a fiery planet the gold wash went to olive, and
// the button read as a bar from an older screen (user, 2026-10-27). Now there
// is no plate at all: a round lens of dark glass with the light pooled in it
// and the action's mark inside, the word beneath in the app's own serif.

import 'package:alchemons/audio/audio.dart';
import 'package:flutter/material.dart';

import 'cosmic_panel_kit.dart';

/// A planet-surface action: a lens of dark glass with [light] pooled in it
/// and a soft ring of the same light round it, [glyph] (or [icon]) inside,
/// [label] beneath. A [sublabel] — a level, a timer — sits under the word in
/// small muted type. [compact] is the lesser action beside the main one.
///
/// Give [glyph] at [glyphSize] (or [compact]'s [compactGlyphSize]): it fills
/// the lens.
class PlanetActionButton extends StatefulWidget {
  const PlanetActionButton({
    super.key,
    required this.label,
    required this.light,
    required this.onTap,
    this.sublabel,
    this.icon,
    this.glyph,
    this.compact = false,
  });

  /// The size a [glyph] should be built at to fill the lens.
  static const double glyphSize = 44;
  static const double compactGlyphSize = 26;

  final String label;
  final Color light;
  final VoidCallback onTap;
  final String? sublabel;
  final IconData? icon;
  final Widget? glyph;
  final bool compact;

  @override
  State<PlanetActionButton> createState() => _PlanetActionButtonState();
}

class _PlanetActionButtonState extends State<PlanetActionButton> {
  /// A finger is on it: the light in the lens wells up.
  bool _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final lens = compact ? 44.0 : 66.0;
    final halo = compact ? 18.0 : 26.0;
    final light = widget.light;
    final pool = _down ? 0.52 : 0.35;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: context.soundAction(widget.onTap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The ring of light round the lens: a soft band, never a stroke.
          Container(
            width: lens + halo,
            height: lens + halo,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  light.withValues(alpha: 0),
                  light.withValues(alpha: 0),
                  light.withValues(alpha: _down ? 0.34 : 0.22),
                  light.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.66, 0.74, 1.0],
              ),
            ),
            child: AnimatedScale(
              scale: _down ? 0.95 : 1,
              duration: const Duration(milliseconds: 90),
              // The lens: the light pooled low in dark glass, where the
              // mark's planet face sits.
              child: Container(
                width: lens,
                height: lens,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(0, 0.45),
                    radius: 0.9,
                    colors: [
                      Color.alphaBlend(
                        light.withValues(alpha: pool),
                        panelPalette.bg0,
                      ),
                      panelPalette.bg0.withValues(alpha: 0.96),
                    ],
                  ),
                ),
                child:
                    widget.glyph ??
                    (widget.icon == null
                        ? null
                        : Icon(
                            widget.icon,
                            color: Color.lerp(light, Colors.white, 0.25),
                            size: compact ? 20 : 30,
                          )),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.label,
            maxLines: 1,
            style: TextStyle(
              color: panelPalette.ink,
              fontSize: compact ? 12 : 16,
              letterSpacing: compact ? 3 : 4,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
          if (widget.sublabel case final sub?) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              style: TextStyle(
                color: panelPalette.muted,
                fontSize: compact ? 9.5 : 10.5,
                letterSpacing: 2,
                shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The placard's backing over a bright planet: a pool of dark, fitted to the
/// placard as an oval so it fades to nothing before any edge. (A circle on
/// the placard's short side ran past its top and bottom and cut a hard line
/// across the planet behind.)
const BoxDecoration placardVignette = BoxDecoration(
  gradient: RadialGradient(
    radius: 0.5,
    transform: _FitOval(),
    colors: [Color(0x99000000), Color(0x66000000), Color(0x00000000)],
    stops: [0.0, 0.55, 1.0],
  ),
);

/// Stretches a radial gradient on the box's short side into the oval that
/// fits the box.
class _FitOval extends GradientTransform {
  const _FitOval();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final c = bounds.center;
    final sx = bounds.width / bounds.shortestSide;
    final sy = bounds.height / bounds.shortestSide;
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}
