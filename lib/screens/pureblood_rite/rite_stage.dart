// lib/screens/pureblood_rite/rite_stage.dart
//
// The rite screen's stage and the small living pieces under it: the pool
// with its vessel standing over it, the ladder of twenty offerings, and the
// vessel itself (a sprite, read through the bloodline genes it is asked to
// carry).

import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/screens/pureblood_rite/rite_pool.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The rite's ground, the passage's too.
const Color kRiteVoid = Color(0xFF080808);

/// How wide the vessel stands over the pool.
const double kRiteVesselSize = 150;

/// Where, on a stage [width] wide, the pool lies (as [ritePoolFor] puts it
/// on the screen) and where the vessel's feet rest on it.
({Offset centre, double radius, double feet}) riteStageLayout(double width) {
  final centre = Offset(width / 2, kRiteStageHeight * 0.8);
  final radius = width * 0.44;
  return (
    centre: centre,
    radius: radius,
    feet: centre.dy - radius * RitePool.flat * 0.12,
  );
}

/// The pool, alive, with [vessel] standing over it. [lit] (0..1) is the pool
/// answering a worthy vessel; [still] quiets it (the rite is sealed).
class RiteStage extends StatefulWidget {
  const RiteStage({super.key, this.vessel, this.lit = 0, this.still = false});

  final Widget? vessel;
  final double lit;
  final bool still;

  @override
  State<RiteStage> createState() => _RiteStageState();
}

class _RiteStageState extends State<RiteStage>
    with SingleTickerProviderStateMixin, GlyphClockLease {
  bool _visible = true;

  /// The pool warms and cools toward [RiteStage.lit] rather than snapping.
  late final AnimationController _lit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.lit,
  );

  @override
  bool get wantsClock => _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void didUpdateWidget(covariant RiteStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lit != widget.lit) {
      _lit.animateTo(widget.lit, curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _lit.dispose();
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kRiteStageHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          final layout = riteStageLayout(box.maxWidth);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PoolPainter(
                      clock: glyphClock,
                      lit: _lit,
                      still: widget.still,
                    ),
                  ),
                ),
              ),
              if (widget.vessel != null)
                Positioned(
                  left: (box.maxWidth - kRiteVesselSize) / 2,
                  top: layout.feet - kRiteVesselSize,
                  width: kRiteVesselSize,
                  height: kRiteVesselSize,
                  child: widget.vessel!,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PoolPainter extends CustomPainter {
  _PoolPainter({required this.clock, required this.lit, required this.still})
    : super(repaint: Listenable.merge([clock, lit]));

  final ValueListenable<double>? clock;
  final Animation<double> lit;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock?.value ?? 0;
    final layout = riteStageLayout(size.width);
    final l = lit.value;
    RitePool.paintGlow(
      canvas,
      layout.centre,
      layout.radius,
      alpha: still ? 0.4 : 1,
      lit: l,
    );
    RitePool.paintGrains(
      canvas,
      layout.centre,
      layout.radius,
      t,
      alpha: still ? 0.5 : 1,
      lit: l,
    );
    if (!still) {
      RitePool.paintSouls(
        canvas,
        layout.centre,
        layout.radius,
        0,
        t,
        souls: (40 + 30 * l).round(),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PoolPainter old) =>
      old.clock != clock || old.lit != lit || old.still != still;
}

// ── the ladder ──────────────────────────────────────────────────────────────

/// The twenty offerings in a row: those given are beads of blood with a
/// gold heart, the one asked for now beats, the rest are ash.
class RiteLadder extends StatefulWidget {
  const RiteLadder({
    super.key,
    required this.done,
    required this.total,
    this.onDoneTap,
  });

  /// How many have been given (the one at [done] is the one asked for).
  final int done;
  final int total;
  final ValueChanged<int>? onDoneTap;

  @override
  State<RiteLadder> createState() => _RiteLadderState();
}

class _RiteLadderState extends State<RiteLadder> with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _LadderPainter(
                done: widget.done,
                total: widget.total,
                clock: glyphClock,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < widget.total; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: i < widget.done && widget.onDoneTap != null
                        ? () => widget.onDoneTap!(i)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LadderPainter extends CustomPainter {
  _LadderPainter({required this.done, required this.total, this.clock})
    : super(repaint: clock);

  final int done, total;
  final ValueListenable<double>? clock;

  static final GrainBatch _b = GrainBatch(5);
  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final t = clock?.value ?? 0;
    final step = size.width / total;
    final y = size.height / 2;
    final b = _b..clear();
    // The thread between them: grains, gold where it has been walked.
    for (var i = 0; i < total - 1; i++) {
      final x0 = step * (i + 0.5), x1 = step * (i + 1.5);
      for (var j = 1; j < 4; j++) {
        b.add(i < done ? 0 : 1, x0 + (x1 - x0) * j / 4, y);
      }
    }
    b.draw(canvas, 0, 1.4, RitePool.soulGold.withValues(alpha: 0.55));
    b.draw(canvas, 1, 1.2, AltarTone.ash.withValues(alpha: 0.45));
    b.clear();

    final beat = math.exp(-math.pow(((t / 1.8) % 1.0 - 0.2) / 0.08, 2));
    for (var i = 0; i < total; i++) {
      final c = Offset(step * (i + 0.5), y);
      if (i < done) {
        // Given: a bead of blood with a gold heart.
        _bead(canvas, c, step * 0.24, RitePool.blood[2], 0.9);
        b.add(2, c.dx, c.dy);
      } else if (i == done) {
        // Asked for now: it beats.
        final r = step * (0.28 + 0.06 * beat);
        _bead(canvas, c, r * 2.1, RitePool.blood[2], 0.22 + 0.2 * beat);
        _bead(canvas, c, r, RitePool.blood[3], 1);
        b.add(3, c.dx, c.dy);
      } else {
        // Still to come: a pinch of ash.
        for (var k = 0; k < 3; k++) {
          final a = k * 2.1 + i;
          b.add(
            4,
            c.dx + math.cos(a) * step * 0.09,
            c.dy + math.sin(a) * step * 0.09,
          );
        }
      }
    }
    b.draw(canvas, 2, step * 0.14, RitePool.soulGold);
    b.draw(canvas, 3, step * 0.16, RitePool.blood[5]);
    b.draw(canvas, 4, 1.3, AltarTone.ash.withValues(alpha: 0.8));
  }

  void _bead(Canvas canvas, Offset c, double r, Color color, double alpha) {
    _p.shader = RadialGradient(
      colors: [
        color.withValues(alpha: alpha),
        color.withValues(alpha: alpha * 0.55),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, _p);
    _p.shader = null;
  }

  @override
  bool shouldRepaint(covariant _LadderPainter old) =>
      old.done != done || old.total != total || old.clock != clock;
}

// ── the vessel ──────────────────────────────────────────────────────────────

/// A specimen as the rite shows it: [instance]'s own sprite, or [species]
/// carrying the size and tint genes the rite asks for ([previewSizeGene],
/// [previewTintGene]).
class RiteVessel extends StatelessWidget {
  const RiteVessel({
    super.key,
    required this.species,
    required this.size,
    this.instance,
    this.previewSizeGene,
    this.previewTintGene,
    this.still = false,
  });

  final Creature species;
  final double size;
  final CreatureInstance? instance;
  final String? previewSizeGene, previewTintGene;

  /// A still picture rather than the animated sprite (small, in lists).
  final bool still;

  @override
  Widget build(BuildContext context) {
    final placed = instance;
    if (placed != null && !still) {
      return SizedBox(
        width: size,
        height: size,
        child: InstanceSprite(creature: species, instance: placed, size: size),
      );
    }
    final genetics = previewSizeGene != null || previewTintGene != null
        ? Genetics({
            ...?species.genetics?.variants,
            if (previewSizeGene != null) 'size': previewSizeGene!,
            if (previewTintGene != null) 'tinting': previewTintGene!,
          })
        : species.genetics;
    final scale = scaleFromGenes(genetics);
    final sprite = species.spriteData;
    final image = Transform.scale(
      scale: scale,
      child: Image.asset(
        species.image.startsWith('assets/')
            ? species.image
            : 'assets/images/${species.image}',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: still || sprite == null
          ? image
          : RepaintBoundary(
              child: CreatureSprite(
                spritePath: sprite.spriteSheetPath,
                totalFrames: sprite.totalFrames,
                rows: sprite.rows,
                frameSize: Vector2(
                  sprite.frameWidth.toDouble(),
                  sprite.frameHeight.toDouble(),
                ),
                stepTime: sprite.frameDurationMs / 1000.0,
                scale: scale,
                saturation: satFromGenes(genetics),
                brightness: briFromGenes(genetics),
                hueShift: hueFromGenes(genetics),
                isPrismatic: species.isPrismaticSkin,
                alchemyEffect: species.alchemyEffect,
                variantFaction: species.variantFaction,
                elementType: species.types.isEmpty ? null : species.types.first,
                effectSlotSize: size,
              ),
            ),
    );
  }
}
