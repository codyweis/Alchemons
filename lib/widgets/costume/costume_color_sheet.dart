// lib/widgets/costume/costume_color_sheet.dart
//
// A COSTUME'S COLOUR, picked on the creature that will wear it.
//
//   The creature stands in the middle wearing it as it is now — the whole
//   Wing under a hat, a Pip's face close for its nose; round it, a ring of
//   every colour the costume comes in, and under it a row of hand-picked
//   ones. Asked when a costume goes on, from any of the places one can, and
//   again whenever the Effect slot is asked to change it (free).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Asks for the colour of the [costume] that [instance] is putting on (or
/// already wears), shown on it. [confirmLabel] names what saying yes does.
/// Null if the player backs out.
Future<Color?> pickCostumeColor(
  BuildContext context, {
  required CreatureInstance instance,
  required FamilyCostume costume,
  required String confirmLabel,
}) {
  final creature = context.read<CreatureCatalog>().getCreatureById(
    instance.baseId,
  );
  final initial = WornCostumes.on(
    instance.baseId,
    instance.costumes,
  ).colorOf(costume);
  // Nothing to show it on: it goes on as it was.
  if (creature == null) return Future.value(initial);
  final palette = BracketPalette.of(context);
  return showModalBottomSheet<Color>(
    context: context,
    backgroundColor: palette.bg1,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) => CostumeColorSheet(
      costume: costume,
      creature: creature,
      instance: instance,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

class CostumeColorSheet extends StatefulWidget {
  const CostumeColorSheet({
    super.key,
    required this.costume,
    required this.creature,
    required this.instance,
    required this.initial,
    required this.confirmLabel,
  });

  final FamilyCostume costume;
  final Creature creature;
  final CreatureInstance instance;
  final Color initial;
  final String confirmLabel;

  /// The ring round the creature, for a test to turn.
  static const ringKey = ValueKey('costume-color-ring');

  @override
  State<CostumeColorSheet> createState() => _CostumeColorSheetState();
}

class _CostumeColorSheetState extends State<CostumeColorSheet> {
  late Color _color = widget.initial;

  /// The ring's middle, from the sheet's own box: where a drag turns about.
  static const double _ring = 136, _band = 18, _box = 2 * _ring + 40;
  bool _turning = false;

  void _turnTo(Offset local, {bool start = false}) {
    final d = local - const Offset(_box / 2, _box / 2);
    // A drag has to start on the ring; once it has, anywhere turns it.
    if (start) _turning = (d.distance - _ring).abs() <= _band + 22;
    if (!_turning) return;
    // Red at the top, round clockwise.
    final hue = (math.atan2(d.dy, d.dx) + math.pi / 2) / (2 * math.pi);
    setState(() => _color = widget.costume.colorForHue(hue));
  }

  /// The creature wearing it as picked: a whole Wing under its hat, and
  /// for a nose (small on a whole Pip) or sunglasses the face, close,
  /// inside the ring.
  Widget _preview(CreatureInstance worn) {
    if (widget.costume == FamilyCostume.partyHat) {
      // Down a little: the hat rises above its head.
      return Transform.translate(
        offset: const Offset(0, 16),
        child: InstanceSprite(
          creature: widget.creature,
          instance: worn,
          size: 236,
        ),
      );
    }
    final glasses = widget.costume == FamilyCostume.sunglasses;
    final size = glasses ? 400.0 : 430.0;
    final fit = widget.costume.fitAt(widget.instance.baseId, 0);
    // The face just behind the nose, or round the glasses, in the middle.
    final focus = fit == null
        ? const Offset(0.5, 0.5)
        : glasses
        ? Offset(fit.x + 0.03, fit.y + 0.02)
        : Offset(fit.x + 0.11, fit.y - 0.02);
    return ClipOval(
      child: SizedBox.square(
        dimension: 2 * (_ring - _band / 2 - 6),
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset((0.5 - focus.dx) * size, (0.5 - focus.dy) * size),
            child: InstanceSprite(
              creature: widget.creature,
              instance: worn,
              size: size,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final accent = bracketReadableAccent(context.read<FactionTheme>());
    final costume = widget.costume;
    // Wearing everything it wears now, and this in the colour picked.
    final worn = widget.instance.copyWith(
      costumes: Value(
        WornCostumes.on(
          widget.instance.baseId,
          widget.instance.costumes,
        ).wear(costume, color: _color).encode(),
      ),
    );
    final hsv = HSVColor.fromColor(_color);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${costume.noun.toUpperCase()} COLOUR',
              style: bracketText(
                context,
                12.5,
                palette.ink,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (e) => _turnTo(e.localPosition, start: true),
              onPanUpdate: (e) => _turnTo(e.localPosition),
              onPanEnd: (_) => _turning = false,
              onTapDown: (e) => _turnTo(e.localPosition, start: true),
              child: SizedBox.square(
                key: CostumeColorSheet.ringKey,
                dimension: _box,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(_box),
                      painter: _HueRingPainter(
                        costume: costume,
                        radius: _ring,
                        band: _band,
                        // A grey has no place on the ring.
                        hue: hsv.saturation > 0.25 ? hsv.hue / 360 : null,
                        color: _color,
                      ),
                    ),
                    _preview(worn),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final preset in costume.presets)
                  _Swatch(
                    key: ValueKey(preset),
                    costume: costume,
                    color: preset,
                    chosen: preset.toARGB32() == _color.toARGB32(),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _color = preset);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: BracketButton(
                    label: 'CANCEL',
                    primary: false,
                    palette: palette,
                    accent: accent,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BracketButton(
                    label: widget.confirmLabel,
                    palette: palette,
                    accent: accent,
                    onTap: () => Navigator.of(context).pop(_color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A hand-picked colour: a disc of the costume's own material in it — the
/// hat's velvet, the nose's glass, the glasses' smoked lens — the chosen
/// one ringed in gold.
class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.costume,
    required this.color,
    required this.chosen,
    required this.onTap,
  });

  final FamilyCostume costume;
  final Color color;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: context.soundAction(onTap),
    child: SizedBox.square(
      dimension: 32,
      child: CustomPaint(painter: _SwatchPainter(costume, color, chosen)),
    ),
  );
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.costume, this.color, this.chosen);
  final FamilyCostume costume;
  final Color color;
  final bool chosen;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - (chosen ? 3 : 4);
    _disc(canvas, costume, c, r, color);
    if (chosen) {
      canvas.drawCircle(
        c,
        r + 1.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _gold,
      );
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.costume != costume || old.color != color || old.chosen != chosen;
}

/// Every colour the costume comes in round the creature, red at the top,
/// and a gold-rimmed knob on the one picked.
class _HueRingPainter extends CustomPainter {
  _HueRingPainter({
    required this.costume,
    required this.radius,
    required this.band,
    required this.hue,
    required this.color,
  });

  final FamilyCostume costume;
  final double radius, band;

  /// Where the knob sits, in turns; null for a colour off the ring.
  final double? hue;
  final Color color;

  /// Each costume's ring of colours, about its own centre: made once.
  static final Map<FamilyCostume, Shader> _wheels = {};
  static Shader _wheel(FamilyCostume costume) =>
      _wheels[costume] ??= ui.Gradient.sweep(
        Offset.zero,
        [for (var i = 0; i <= 24; i++) costume.colorForHue(i / 24)],
        [for (var i = 0; i <= 24; i++) i / 24],
      );

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-math.pi / 2);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band
        ..shader = _wheel(costume),
    );
    canvas.restore();
    final h = hue;
    if (h == null) return;
    final a = h * 2 * math.pi - math.pi / 2;
    final at = c + Offset(math.cos(a), math.sin(a)) * radius;
    canvas.drawCircle(
      at + const Offset(0, 1.5),
      band * 0.72,
      Paint()..color = const Color(0x66000000),
    );
    _disc(canvas, costume, at, band * 0.62, color);
    canvas.drawCircle(
      at,
      band * 0.62 + 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _gold,
    );
  }

  @override
  bool shouldRepaint(_HueRingPainter old) =>
      old.costume != costume ||
      old.hue != hue ||
      old.color != color ||
      old.radius != radius;
}

/// The costumes' trim.
const _gold = Color(0xFFFFD58B);

/// A disc of [color] in [costume]'s material.
void _disc(
  Canvas canvas,
  FamilyCostume costume,
  Offset c,
  double r,
  Color color,
) => switch (costume) {
  FamilyCostume.partyHat => _velvetDisc(canvas, c, r, color),
  FamilyCostume.nose => _glassDisc(canvas, c, r, color),
  FamilyCostume.sunglasses => _lensDisc(canvas, c, r, color),
};

/// A disc of [color] shaded as the hat's velvet: lit up on the left, deep
/// on the right.
void _velvetDisc(Canvas canvas, Offset c, double r, Color color) {
  Color shade(double k) => Color.from(
    alpha: 1,
    red: (color.r * k).clamp(0.0, 1.0),
    green: (color.g * k).clamp(0.0, 1.0),
    blue: (color.b * k).clamp(0.0, 1.0),
  );
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        c + Offset(-r * 0.35, -r * 0.35),
        r * 1.6,
        [shade(1.15), shade(0.68), shade(0.25)],
        const [0.0, 0.45, 1.0],
      ),
  );
}

/// A bead of [color] lit as the nose is: a pale cap up on the left, the
/// colour, a deep edge, and a glint.
void _glassDisc(Canvas canvas, Offset c, double r, Color color) {
  const white = Color(0xFFFFFFFF);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        c + Offset(-r * 0.3, -r * 0.35),
        r * 1.5,
        [
          Color.lerp(color, white, 0.45)!,
          color,
          Color.from(
            alpha: 1,
            red: color.r * 0.55,
            green: color.g * 0.55,
            blue: color.b * 0.55,
          ),
        ],
        const [0.0, 0.5, 1.0],
      ),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: c + Offset(-r * 0.32, -r * 0.42),
      width: r * 0.42,
      height: r * 0.24,
    ),
    Paint()..color = const Color(0xD9FFE5DF),
  );
}

/// A disc of [color] as the sunglasses' lens is tinted: dark at the brow,
/// clearer below, with the sky caught in its top.
void _lensDisc(Canvas canvas, Offset c, double r, Color color) {
  Color shade(double k) => Color.from(
    alpha: 1,
    red: (color.r * k).clamp(0.0, 1.0),
    green: (color.g * k).clamp(0.0, 1.0),
    blue: (color.b * k).clamp(0.0, 1.0),
  );
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.linear(
        c + Offset(0, -r),
        c + Offset(0, r),
        [shade(0.32), shade(0.7), shade(1.25)],
        const [0.0, 0.55, 1.0],
      ),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c + Offset(0, -r * 0.55),
        width: r * 1.1,
        height: r * 0.24,
      ),
      Radius.circular(r * 0.12),
    ),
    Paint()..color = const Color(0x38FFFFFF),
  );
}
