// lib/screens/cosmic/widgets/cosmic_panel_kit.dart
//
// The pieces the space panels share — the customization lab, the ship
// console, the home base window — so the three read as one instrument: a
// live stage at the top (the ship flying, or the home planet turning, drawn
// by the painters that draw them in space), labels in monospace ink,
// readouts and gauges in bracket frames, prices as shards and element
// chips.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart' show ShipComponent;
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'cosmic_overlay_chrome.dart';
import 'cosmic_screen_styles.dart';

const panelPalette = BracketPalette.dark;
const panelMono = 'monospace';

/// Draws the home planet into [area] at [time], wearing [wearing] in
/// [color] — see CosmicGame.paintHomeShowcase.
typedef HomeShowcasePainter =
    void Function(
      Canvas canvas,
      Rect area,
      double time, {
      required Set<String> wearing,
      String? color,
    });

TextStyle panelLabel(double size, Color color, {double spacing = 1.2}) =>
    TextStyle(
      fontFamily: panelMono,
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: spacing,
    );

/// Format a number with commas (e.g. 1234567 → "1,234,567").
String panelFmt(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i] != '-') buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class PanelDot extends StatelessWidget {
  const PanelDot(this.color, {super.key, this.size = 7});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class ShardAmount extends StatelessWidget {
  const ShardAmount(
    this.amount, {
    super.key,
    this.size = 12,
    this.enabled = true,
  });
  final int amount;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? CosmicScreenStyles.astralShardColor
        : CosmicScreenStyles.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CosmicScreenStyles.astralShardIcon, size: size, color: color),
        SizedBox(width: size * 0.3),
        Text(panelFmt(amount), style: panelLabel(size, color, spacing: 0.4)),
      ],
    );
  }
}

/// One element of a price: how much is held against how much it takes.
class CostChip extends StatelessWidget {
  const CostChip(
    this.element,
    this.need,
    this.stored, {
    super.key,
    this.size = 11,
  });
  final String element;
  final int need;
  final Map<String, double> stored;
  final double size;

  @override
  Widget build(BuildContext context) {
    final has = stored[element] ?? 0;
    final enough = has >= need;
    final ink = elementInk(element);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelDot(enough ? ink : ink.withValues(alpha: 0.4), size: size * 0.6),
        SizedBox(width: size * 0.4),
        Text(
          '$element ${panelFmt(has)}/${panelFmt(need)}',
          style: panelLabel(
            size,
            enough ? ink : CosmicScreenStyles.textMuted,
            spacing: 0.3,
          ),
        ),
      ],
    );
  }
}

void paintPlainPlanet(Canvas canvas, Offset c, double r, Color col) {
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        c + Offset(-r * 0.35, -r * 0.4),
        r * 1.4,
        [
          Color.lerp(col, Colors.white, 0.3)!,
          col,
          Color.lerp(col, Colors.black, 0.7)!,
        ],
        const [0.0, 0.4, 1.0],
      ),
  );
}

/// A bolt in flight, nose up: a hot head trailing its color.
void paintBoltGlyph(Canvas canvas, Offset at, double u, Color col) {
  final tail = Path()
    ..moveTo(at.dx - 2.4 * u, at.dy - 2 * u)
    ..quadraticBezierTo(at.dx - 1.2 * u, at.dy + 6 * u, at.dx, at.dy + 11 * u)
    ..quadraticBezierTo(
      at.dx + 1.2 * u,
      at.dy + 6 * u,
      at.dx + 2.4 * u,
      at.dy - 2 * u,
    )
    ..close();
  canvas.drawPath(
    tail,
    Paint()
      ..shader = ui.Gradient.linear(at, at + Offset(0, 11 * u), [
        col.withValues(alpha: 0.85),
        col.withValues(alpha: 0),
      ]),
  );
  canvas.drawCircle(
    at - Offset(0, 1.2 * u),
    3.4 * u,
    Paint()
      ..shader = ui.Gradient.radial(
        at - Offset(0, 1.2 * u),
        3.4 * u,
        [Colors.white, col, col.withValues(alpha: 0)],
        const [0.0, 0.45, 1.0],
      ),
  );
}

/// A seeker missile, nose up: a dark dart with its motor lit.
void paintMissileGlyph(Canvas canvas, Offset at, double u) {
  final body = Path()
    ..moveTo(at.dx, at.dy - 9 * u)
    ..lineTo(at.dx - 2.4 * u, at.dy + 4 * u)
    ..lineTo(at.dx, at.dy + 2.6 * u)
    ..lineTo(at.dx + 2.4 * u, at.dy + 4 * u)
    ..close();
  final flame = Path()
    ..moveTo(at.dx - 1.4 * u, at.dy + 3.4 * u)
    ..quadraticBezierTo(at.dx, at.dy + 13 * u, at.dx + 1.4 * u, at.dy + 3.4 * u)
    ..close();
  canvas.drawPath(
    flame,
    Paint()
      ..shader = ui.Gradient.linear(
        at + Offset(0, 3 * u),
        at + Offset(0, 13 * u),
        [const Color(0xFFFFE0B0), const Color(0x00FF8A3D)],
      ),
  );
  canvas.drawPath(
    body,
    Paint()
      ..shader = ui.Gradient.linear(
        at + Offset(-2.4 * u, 0),
        at + Offset(2.4 * u, 0),
        [const Color(0xFF6A7488), const Color(0xFF1C2029)],
      ),
  );
  canvas.drawCircle(
    at - Offset(0, 4.5 * u),
    1.1 * u,
    Paint()..color = const Color(0xFFFFB74D),
  );
}

/// The stage's backdrop: deep space with a few stars, the same each frame.
abstract class _StagePainter extends CustomPainter {
  _StagePainter(this.clock) : super(repaint: clock);
  final ValueListenable<double> clock;

  /// Stars in two brightnesses, each drawn as one batch of points.
  static final List<Float32List> _stars = () {
    final r = Random(11);
    return [
      for (var k = 0; k < 2; k++)
        Float32List.fromList([for (var i = 0; i < 46; i++) r.nextDouble()]),
    ];
  }();
  static final Paint _starPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.4;

  void paintBackdrop(Canvas canvas, Size size, Color tint) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(rect.center, size.longestSide * 0.6, [
          tint.withValues(alpha: 0.10),
          tint.withValues(alpha: 0),
        ]),
    );
    for (var k = 0; k < 2; k++) {
      final unit = _stars[k];
      final pts = Float32List(unit.length);
      for (var i = 0; i < unit.length; i += 2) {
        pts[i] = unit[i] * size.width;
        pts[i + 1] = unit[i + 1] * size.height;
      }
      _starPaint.color = Colors.white.withValues(alpha: k == 0 ? 0.2 : 0.42);
      canvas.drawRawPoints(ui.PointMode.points, pts, _starPaint);
    }
  }
}

class _ShipStagePainter extends _StagePainter {
  _ShipStagePainter({
    required ValueListenable<double> clock,
    required this.ship,
    required this.skin,
    required this.orbitals,
    required this.bolts,
    required this.repeater,
    required this.missiles,
    this.zoom = 1.75,
    this.orbitalCount = OrbitalSentinel.maxActive,
  }) : super(clock);

  final double zoom;
  final int orbitalCount;
  final ShipComponent ship;
  final String? skin;
  final bool orbitals;

  /// When ammo is on show, the color its bolts fly in.
  final Color? bolts;
  final bool repeater, missiles;

  static const double _speed = 150;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final light = shipLight(skin);
    paintBackdrop(canvas, size, light.essence);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // The ship climbs steadily with a gentle weave; the camera keeps it in
    // the middle, so its wake streams away below it.
    final weave = 16 * sin(t * 0.6);
    final y = -t * _speed;
    ship
      ..pos = Offset(weave, y)
      ..angle = atan2(-_speed, 16 * 0.6 * cos(t * 0.6));
    canvas.translate(size.width / 2, size.height * 0.64);
    canvas.scale(zoom);
    canvas.translate(0, -y);
    if (bolts != null) _paintBolts(canvas, t, y);
    ship.render(canvas, t, skin: skin);
    if (orbitals) {
      for (var i = 0; i < orbitalCount; i++) {
        final a = t * OrbitalSentinel.orbitSpeed + i * 2 * pi / 3;
        paintOrbitalSentinel(
          canvas,
          ship.pos + Offset(cos(a), sin(a)) * OrbitalSentinel.orbitRadius,
          light,
          time: t,
          seed: i * 1.7,
          radius: OrbitalSentinel.hitboxRadius * 0.6,
        );
      }
    }
    canvas.restore();
  }

  /// Fire on show: bolts (or missiles) leaving the nose at the weapon's
  /// rate, laid out from when each was fired.
  void _paintBolts(Canvas canvas, double t, double shipY) {
    // Slower than in space, so the eye can follow them off the stage.
    final period = missiles ? 0.6 : (repeater ? 0.16 : 0.34);
    final speed = missiles ? 170.0 : 260.0;
    final col = bolts!;
    final last = (t / period).floor();
    for (var k = 0; k < 8; k++) {
      final fired = (last - k) * period;
      if (fired < 0) break;
      final age = t - fired;
      final at = Offset(
        16 * sin(fired * 0.6),
        -fired * _speed - 30 - age * speed,
      );
      if (at.dy < shipY - 140) break;
      if (missiles) {
        paintMissileGlyph(canvas, at, 1.1);
      } else {
        paintBoltGlyph(canvas, at, 0.9, col);
      }
    }
  }

  @override
  bool shouldRepaint(_ShipStagePainter old) =>
      old.skin != skin ||
      old.orbitals != orbitals ||
      old.bolts != bolts ||
      old.repeater != repeater ||
      old.missiles != missiles ||
      old.zoom != zoom ||
      old.orbitalCount != orbitalCount;
}

class _HomeStagePainter extends _StagePainter {
  _HomeStagePainter({
    required ValueListenable<double> clock,
    required this.paintHome,
    required this.wearing,
    required this.color,
    this.scale = 1.15,
  }) : super(clock);

  final double scale;
  final HomeShowcasePainter? paintHome;
  final Set<String> wearing;
  final String? color;

  @override
  void paint(Canvas canvas, Size size) {
    final swatch = homeColorSwatch(color);
    paintBackdrop(canvas, size, swatch);
    final area = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.height * scale,
      height: size.height * scale,
    );
    final paint = paintHome;
    if (paint == null) {
      paintPlainPlanet(canvas, area.center, size.height * 0.2, swatch);
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paint(canvas, area, 4 + clock.value, wearing: wearing, color: color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HomeStagePainter old) =>
      old.paintHome != paintHome ||
      old.scale != scale ||
      old.color != color ||
      old.wearing.length != wearing.length ||
      !old.wearing.containsAll(wearing);
}

// ── stages ──────────────────────────────────────────────────────────────────

/// A stage's clock: seconds since it appeared, ticking while it is shown.
mixin _StageClock<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  final ValueNotifier<double> clock = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    (d) => clock.value = d.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    clock.dispose();
    super.dispose();
  }
}

/// The ship flying on a panel's stage: its hull, its wake streaming away
/// below it, its orbital sentinels, and — when [bolts] is set — firing.
class ShipStage extends StatefulWidget {
  const ShipStage({
    super.key,
    required this.skin,
    this.orbitals = false,
    this.bolts,
    this.repeater = false,
    this.missiles = false,
    this.zoom = 1.75,
    this.orbitalCount = OrbitalSentinel.maxActive,
  });

  final String? skin;
  final bool orbitals;

  /// How many sentinels are out, when [orbitals] is on.
  final int orbitalCount;

  /// When fire is on show, the color its bolts fly in.
  final Color? bolts;
  final bool repeater, missiles;
  final double zoom;

  @override
  State<ShipStage> createState() => _ShipStageState();
}

class _ShipStageState extends State<ShipStage>
    with SingleTickerProviderStateMixin, _StageClock {
  /// Kept, so the wake runs on unbroken while the hull changes.
  final ShipComponent _ship = ShipComponent(pos: Offset.zero);

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _ShipStagePainter(
        clock: clock,
        ship: _ship,
        skin: widget.skin,
        orbitals: widget.orbitals,
        bolts: widget.bolts,
        repeater: widget.repeater,
        missiles: widget.missiles,
        zoom: widget.zoom,
        orbitalCount: widget.orbitalCount,
      ),
    ),
  );
}

/// The home planet turning on a panel's stage, wearing [wearing] in
/// [color]. Without [paintHome] it is a plain sphere.
class HomeStage extends StatefulWidget {
  const HomeStage({
    super.key,
    required this.paintHome,
    required this.wearing,
    required this.color,
    this.scale = 1.15,
  });

  final HomeShowcasePainter? paintHome;
  final Set<String> wearing;
  final String? color;

  /// How much of the stage's height the planet's widest reach spans.
  final double scale;

  @override
  State<HomeStage> createState() => _HomeStageState();
}

class _HomeStageState extends State<HomeStage>
    with SingleTickerProviderStateMixin, _StageClock {
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _HomeStagePainter(
        clock: clock,
        paintHome: widget.paintHome,
        wearing: widget.wearing,
        color: widget.color,
        scale: widget.scale,
      ),
    ),
  );
}

// ── chrome ──────────────────────────────────────────────────────────────────

/// A panel's title row: the name in spaced ink, anything [trailing], and
/// the close cross (left out while a tutorial holds the panel open).
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onClose,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, onClose == null ? 16 : 4, 6),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: panelLabel(13, panelPalette.ink, spacing: 2.6),
              ),
            ),
            if (trailing != null) trailing!,
            if (onClose != null) CosmicCloseButton(onTap: onClose!),
          ],
        ),
      ),
    );
  }
}

/// A section's label with a rule running out from it, and an optional
/// reading at the far end.
class PanelSectionHeader extends StatelessWidget {
  const PanelSectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: panelLabel(10.5, panelPalette.muted, spacing: 1.8),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: panelPalette.lineSoft)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(
              trailing!.toUpperCase(),
              style: panelLabel(10.5, panelPalette.ink.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A gauge: what it measures, how full, and the figure.
class PanelGauge extends StatelessWidget {
  const PanelGauge({
    super.key,
    required this.label,
    required this.fraction,
    required this.value,
    required this.color,
    this.note,
    this.labelWidth = 64,
  });

  final double labelWidth;
  final String label;
  final double fraction;
  final String value;
  final Color color;

  /// A word after the figure ("REFILLS AT HOME").
  final String? note;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 1,
              style: panelLabel(10.5, panelPalette.muted),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 6,
              child: CustomPaint(painter: _GaugePainter(f, color)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: panelLabel(11, panelPalette.ink, spacing: 0.6),
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 8),
            Text(note!, style: panelLabel(9, color.withValues(alpha: 0.8))),
          ],
        ],
      ),
    );
  }
}

/// A gauge's bar: ten cells, lit as far as it is full, the last lit one
/// only partly.
class _GaugePainter extends CustomPainter {
  _GaugePainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const cells = 10;
    const gap = 2.0;
    final w = (size.width - gap * (cells - 1)) / cells;
    final lit = Paint()..color = color;
    final dim = Paint()..color = panelPalette.lineSoft;
    for (var i = 0; i < cells; i++) {
      final x = i * (w + gap);
      final r = Rect.fromLTWH(x, 0, w, size.height);
      final fill = (fraction * cells - i).clamp(0.0, 1.0);
      canvas.drawRect(r, dim);
      if (fill > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, w * fill, size.height),
          lit..color = color.withValues(alpha: 0.55 + 0.45 * fill),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

/// A reading in a bracket frame: the figure large, what it is small below.
class PanelReadout extends StatelessWidget {
  const PanelReadout({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.leading,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? color;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? panelPalette.ink;
    final body = CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: panelPalette.line.withValues(alpha: 0.55),
        bracketSize: 6,
      ),
      child: Container(
        color: panelPalette.bg1.withValues(alpha: 0.6),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: panelLabel(15, ink, spacing: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: panelLabel(9, panelPalette.muted, spacing: 1.2),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: body,
    );
  }
}

/// [children] side by side with even gaps, each as wide as the rest.
class PanelRow extends StatelessWidget {
  const PanelRow({super.key, required this.children, this.gap = 8});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: children[i]),
      ],
    ],
  );
}
