// lib/games/cosmic_survival/components/survival_hud.dart
//
// The run's HUD, in the ship console's language: plain dark glass, lit from
// below when it is the live thing, readings in spaced monospace, and gauges
// as glass tubes with matter settled in them (the space HUD's meter tube)
// rather than flat bars. The orb's gauge is lit in the core's own light, the
// same color as the ring of cells round the core in the arena.
//
// Under the top bar, the run's main progress: the SURGE tube, full width,
// filling toward the next draft. The party is a row of small cases along the
// bottom edge (survival_party_slot.dart), so the field stays clear.

import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

/// Ink and glass for the HUD.
class HudInk {
  static const glass = Color(0xFF0B0B10);
  static const line = Color(0xFF3A3A48);
  static const ink = Color(0xFFF4EEDF);
  static const muted = Color(0xFF9A93A6);
  static const amber = Color(0xFFE4B356);
  static const danger = Color(0xFFFF6B5E);

  /// A held shield: pale brass glass, the same as the shield on the orb.
  static const shield = Color(0xFFEDE4C8);

  /// The ship's own color: the pale steel of its hull's lit edge.
  static const ship = Color(0xFF8FC9D6);
}

/// The kit's ink and pale brass (BracketPalette.dark, ForgeTokens dark), for
/// the surge tube, the party row and the draft.
abstract final class SurvivalInk {
  static const bg0 = Color(0xFF09090B);
  static const bg1 = Color(0xFF131316);
  static const ink = Color(0xFFE6E2DA);
  static const muted = Color(0xFF8E8C88);

  /// BracketPalette.dark.line: a frame in it draws nothing (unlit).
  static const plain = Color(0xFF5A5852);
  static const brass = Color(0xFFB89656);
  static const brassBright = Color(0xFFCDB07A);
  static const brassGlow = Color(0xFFE2C98F);

  /// The Alchemon the ship tows.
  static const follow = Color(0xFF7FD6C4);
  static const danger = HudInk.danger;

  /// The alchemical surge: the violet of the meter round the core.
  static const surge = Color(0xFF9A7CEB);
  static const surgeDeep = Color(0xFF5B48C8);
  static const surgeHot = Color(0xFFD99BF5);
}

TextStyle hudMono(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w800,
  double spacing = 1.2,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: 1.1,
);

/// A pane of the HUD's dark glass, lit from below in [accent] when that is
/// a color of its own (the plain [HudInk.line] draws nothing).
class HudGlass extends StatelessWidget {
  const HudGlass({
    super.key,
    required this.child,
    this.accent = HudInk.line,
    this.padding = EdgeInsets.zero,
    this.bracket = 7,
    this.alpha = 0.86,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double bracket;
  final double alpha;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: BracketFramePainter(
      color: accent,
      bracketSize: bracket,
      strokeWidth: 1.1,
    ),
    child: Container(
      padding: padding,
      color: HudInk.glass.withValues(alpha: alpha),
      child: child,
    ),
  );
}

/// A square key on the console. [lit] when what it toggles is on.
class HudKey extends StatelessWidget {
  const HudKey({
    super.key,
    required this.icon,
    required this.onTap,
    this.lit = false,
    this.size = 44,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool lit;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final key = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: HudGlass(
        accent: lit
            ? HudInk.amber.withValues(alpha: 0.9)
            : HudInk.line.withValues(alpha: 0.9),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.42,
            color: lit ? HudInk.amber : HudInk.muted,
          ),
        ),
      ),
    );
    return tooltip == null ? key : Tooltip(message: tooltip!, child: key);
  }
}

/// A gauge: what it measures, a glass tube filled as far as [fraction],
/// and the figure. A [shield] (a share of the same whole) sits in the tube
/// as pale brass glass after the fill and is written after the figure.
class HudGauge extends StatelessWidget {
  const HudGauge({
    super.key,
    required this.label,
    required this.fraction,
    required this.color,
    this.figure,
    this.shield = 0,
  });

  final String label;
  final double fraction;
  final Color color;

  /// Written after the tube; the percentage when left out.
  final String? figure;

  /// What a held shield is worth, as a share of the whole; 0 for none.
  final double shield;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    final s = shield.clamp(0.0, 1.0);
    final shieldFigure = s > 0 ? max(1, (s * 100).round()) : 0;
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(label, style: hudMono(9, HudInk.muted)),
        ),
        Expanded(
          child: SizedBox(
            height: 8,
            child: CustomPaint(painter: HudTubePainter(f, color, shield: s)),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Text.rich(
            TextSpan(
              text: figure ?? '${(f * 100).round()}',
              style: hudMono(
                10,
                f < 0.25 ? HudInk.danger : HudInk.ink,
                spacing: 0.4,
              ),
              children: [
                if (shieldFigure > 0)
                  TextSpan(
                    text: '+$shieldFigure',
                    style: hudMono(8.5, HudInk.shield, spacing: 0.2),
                  ),
              ],
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

/// A glass tube with [color]'s matter in it as far as [fraction]: lit at the
/// top, deep at the bottom, grains settled through it, and the glass's own
/// highlight over all of it.
class HudTubePainter extends CustomPainter {
  HudTubePainter(this.fraction, this.color, {this.shield = 0});

  final double fraction;
  final Color color;

  /// A held shield, as a share of the tube: pale brass glass after the
  /// fill, or over its end when the two overrun the tube.
  final double shield;

  static final Paint _p = Paint();
  static final Paint _grain = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF1A1B26), Color(0xFF08090E), Color(0xFF12131C)],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, _p);

    final w = size.width * fraction;
    if (w > 0.5) {
      final band = Rect.fromLTWH(0, 0, w, size.height);
      final hsl = HSLColor.fromColor(
        Color.lerp(color, const Color(0xFF16141E), 0.15)!,
      );
      final mid = hsl.toColor();
      final lit = hsl
          .withLightness((hsl.lightness + 0.2).clamp(0.0, 0.88))
          .toColor();
      final deep = hsl
          .withLightness((hsl.lightness * 0.42).clamp(0.0, 1.0))
          .toColor();
      _p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lit, mid, deep],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(band);
      canvas.drawRect(band, _p);
      // Grains settled in it — fixed places, so a still gauge is still.
      _grain
        ..strokeWidth = 1.3
        ..color = lit.withValues(alpha: 0.8);
      final pts = <Offset>[];
      for (var i = 0; i * 3.4 < w - 1; i++) {
        final h = ((i * 7919) % 97) / 97;
        pts.add(Offset(i * 3.4 + h * 2.4, size.height * (0.2 + 0.7 * h)));
      }
      canvas.drawPoints(PointMode.points, pts, _grain);
      // The meniscus: the matter's leading edge catches the light.
      _p
        ..shader = null
        ..color = lit.withValues(alpha: 0.9);
      canvas.drawRect(Rect.fromLTWH(w - 1.2, 0, 1.2, size.height), _p);
    }

    if (shield > 0) {
      final sw = max(3.0, size.width * shield.clamp(0.0, 1.0));
      final x0 = min(w, size.width - sw);
      final band = Rect.fromLTWH(x0, 0, sw, size.height);
      _p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [HudInk.shield, Color(0xFFD6C595), Color(0xFF6E5D38)],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(band);
      canvas.drawRect(band, _p);
      // A sliver of dark glass where it meets the fill, so the two read as
      // two things.
      _p
        ..shader = null
        ..color = const Color(0xFF08090E).withValues(alpha: 0.85);
      canvas.drawRect(Rect.fromLTWH(x0, 0, 1.0, size.height), _p);
    }

    _p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, 0.5, size.width, size.height * 0.4), _p);
    _p.shader = null;
  }

  @override
  bool shouldRepaint(HudTubePainter old) =>
      old.fraction != fraction || old.color != color || old.shield != shield;
}

/// The run's top line: the wave and the clock, the console's keys, and the
/// ship's and the orb's gauges.
class SurvivalTopHud extends StatelessWidget {
  const SurvivalTopHud({
    super.key,
    required this.wave,
    required this.time,
    required this.keys,
    required this.shipFraction,
    required this.shipGhost,
    required this.orbFraction,
    required this.orbColor,
    this.orbShield = 0,
    this.compact = false,
    this.element,
    this.nextElement,
  });

  /// The wave's element (every small enemy in it shares one), named small
  /// under the clock; null shows nothing.
  final String? element;

  /// Set once the wave is all on the field: the element the next wave will
  /// share, shown in its place as NEXT, so the bench can be readied for it.
  /// 'Boss' for a boss wave next.
  final String? nextElement;

  /// A narrow screen (the Fold's cover): the keys keep their row and the
  /// gauges drop under it, side by side, instead of being squeezed.
  final bool compact;

  final int wave;
  final String time;
  final List<Widget> keys;
  final double shipFraction;
  final bool shipGhost;
  final double orbFraction;
  final Color orbColor;

  /// The orb's shield as a share of its maximum health; 0 for none.
  final double orbShield;

  Widget _gauges({required bool row}) {
    final ship = HudGauge(
      label: shipGhost ? 'GHOST' : 'SHIP',
      fraction: shipGhost ? 1 : shipFraction,
      color: HudInk.ship,
      figure: shipGhost ? '—' : null,
    );
    final orb = HudGauge(
      label: 'ORB',
      fraction: orbFraction,
      color: orbColor,
      shield: orbShield,
    );
    return HudGlass(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      child: row
          ? Row(
              children: [
                Expanded(child: ship),
                const SizedBox(width: 10),
                Expanded(child: orb),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [ship, const SizedBox(height: 7), orb],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _wavePane(),
              const Spacer(),
              for (final (i, k) in keys.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                k,
              ],
            ],
          ),
          const SizedBox(height: 6),
          _gauges(row: true),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _wavePane(),
        const SizedBox(width: 6),
        for (final k in keys) ...[k, const SizedBox(width: 6)],
        const SizedBox(width: 2),
        Expanded(child: _gauges(row: false)),
      ],
    );
  }

  Widget _wavePane() {
    final figures = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('WAVE ', style: hudMono(8.5, HudInk.muted)),
            Text(
              '$wave',
              style: hudMono(
                17,
                SurvivalInk.brassBright,
                weight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(time, style: hudMono(10, HudInk.ink, spacing: 1.0)),
        if (element != null || nextElement != null)
          const SizedBox(height: _elementLine + 1),
      ],
    );
    final next = nextElement;
    final e = next ?? element;
    return HudGlass(
      padding: e == null
          ? const EdgeInsets.fromLTRB(10, 6, 10, 6)
          : const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: e == null
          ? figures
          // The element's line takes the width the figures give it and no
          // more, so a long name scales down rather than widening the plate.
          : Stack(
              children: [
                figures,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _elementLine,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      next == null
                          ? e.toUpperCase()
                          : 'NEXT · ${e.toUpperCase()}',
                      maxLines: 1,
                      style: hudMono(
                        7.5,
                        e == 'Boss'
                            ? SurvivalInk.brassBright
                            : Color.lerp(elementColor(e), HudInk.ink, 0.4)!,
                        spacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static const double _elementLine = 8.5;
}

/// The run's main progress, under the top bar: a full-width glass tube that
/// fills with the surge as kills come in, as the meter round the core does.
/// Near full, the pane is lit from below in the surge's violet; full opens
/// the draft.
///
/// Rebuilt on the HUD's tick; the fill is quantized to about a pixel of a
/// phone-wide tube, so the tube repaints only when it visibly moves.
class SurgeStrip extends StatelessWidget {
  const SurgeStrip({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final f = (fraction.clamp(0.0, 1.0) * 400).round() / 400;
    final near = f >= 0.85;
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: near ? SurvivalInk.surge : SurvivalInk.plain,
          strokeWidth: 1.4,
        ),
        child: Container(
          color: SurvivalInk.bg0.withValues(alpha: 0.86),
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  'SURGE',
                  style: hudMono(
                    8.5,
                    near ? SurvivalInk.surgeHot : SurvivalInk.muted,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 10,
                  child: CustomPaint(painter: SurgeTubePainter(f)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text(
                  '${(f * 100).floor()}%',
                  textAlign: TextAlign.right,
                  style: hudMono(
                    10,
                    near ? SurvivalInk.ink : SurvivalInk.muted,
                    spacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The surge tube: dark glass, the matter deep at its start and hot at its
/// leading edge, grains settled in fixed places, the edge catching the
/// light.
class SurgeTubePainter extends CustomPainter {
  SurgeTubePainter(this.fraction);

  final double fraction;

  static final Paint _p = Paint();
  static final Paint _grain = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF19181F), Color(0xFF08080B), Color(0xFF111116)],
      stops: [0.0, 0.6, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, _p);

    final w = size.width * fraction;
    if (w > 0.5) {
      final band = Rect.fromLTWH(0, 0, w, size.height);
      _p.shader = LinearGradient(
        colors: [
          SurvivalInk.surgeDeep,
          SurvivalInk.surge,
          Color.lerp(SurvivalInk.surge, SurvivalInk.surgeHot, 0.6)!,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, max(w, 40), size.height));
      canvas.drawRect(band, _p);
      _p.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x40FFFFFF), Color(0x00FFFFFF), Color(0x66000000)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(band);
      canvas.drawRect(band, _p);
      _grain
        ..strokeWidth = 1.4
        ..color = SurvivalInk.surgeHot.withValues(alpha: 0.75);
      final pts = <Offset>[];
      for (var i = 0; i * 3.1 < w - 2; i++) {
        final h = ((i * 7919) % 97) / 97;
        pts.add(Offset(i * 3.1 + h * 2.2, size.height * (0.2 + 0.68 * h)));
      }
      canvas.drawPoints(PointMode.points, pts, _grain);
      _p
        ..shader = null
        ..color = const Color(0xFFF3E4FF).withValues(alpha: 0.9);
      canvas.drawRect(Rect.fromLTWH(w - 1.5, 0, 1.5, size.height), _p);
    }
    _p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x22FFFFFF), Color(0x00FFFFFF)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, 0.5, size.width, size.height * 0.4), _p);
    _p.shader = null;
  }

  @override
  bool shouldRepaint(SurgeTubePainter old) => old.fraction != fraction;
}

/// The detonation key: a sphere of dark glass that fills with molten matter
/// as the charge builds, its surface catching the light. Full, it burns —
/// a pool of its light behind it and the glass's limb lit — instead of a
/// progress ring and a blurred glow.
class DetonationVesselPainter extends CustomPainter {
  DetonationVesselPainter({required this.charge, required this.ready});

  final double charge;
  final bool ready;

  static const _deep = Color(0xFF3A1206);
  static const _melt = Color(0xFFD9602E);
  static const _hot = Color(0xFFFFC27A);
  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final f = charge.clamp(0.0, 1.0);

    if (ready) {
      _p.shader = RadialGradient(
        colors: [
          _melt.withValues(alpha: 0.45),
          _melt.withValues(alpha: 0.12),
          _melt.withValues(alpha: 0),
        ],
        stops: const [0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r + 4));
      canvas.drawCircle(c, r + 4, _p);
    }

    // The empty glass.
    _p.shader = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: const [Color(0xFF1C1A22), Color(0xFF0A090D), Color(0xFF050407)],
      stops: const [0.0, 0.7, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, _p);

    // The melt, up to its level.
    if (f > 0.01) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      final top = c.dy + r - 2 * r * f;
      final body = Rect.fromLTRB(c.dx - r, top, c.dx + r, c.dy + r);
      _p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [ready ? _hot : _melt, _melt, _deep],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(body);
      canvas.drawRect(body, _p);
      // Its surface, seen a little from above.
      _p
        ..shader = null
        ..color = _hot.withValues(alpha: ready ? 0.9 : 0.6);
      final half = sqrt(max(0.0, r * r - (top - c.dy) * (top - c.dy)));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, top),
          width: half * 2,
          height: max(1.5, half * 0.18),
        ),
        _p,
      );
      canvas.restore();
    }

    // The glass's limb and its glint.
    _p.shader = RadialGradient(
      colors: [
        const Color(0x00FFFFFF),
        const Color(0x00FFFFFF),
        (ready ? _hot : const Color(0xFF9A93A6)).withValues(
          alpha: ready ? 0.55 : 0.28,
        ),
        const Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.84, 0.96, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, _p);
    _p
      ..shader = null
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.16);
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.32, -r * 0.5),
        width: r * 0.62,
        height: r * 0.26,
      ),
      _p,
    );
    _p.shader = null;
  }

  @override
  bool shouldRepaint(DetonationVesselPainter old) =>
      old.charge != charge || old.ready != ready;
}
