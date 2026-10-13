// lib/screens/stadium/racer_gate.dart
//
// The stadium's starting gate (the author, 2026-10-12: "a normal picker like
// we usually do for selecting alchemon then a cool transition to selected
// one to the one that's ready to race"). The player's racer stands at the
// line in a pool of its element's light, its name, boosts and stats beside
// it; the cup's five rivals wait further down the lane. Tap the racer and the
// usual slide-up specimen picker opens; the one picked flies out of its case
// along an arc to the line, and lands in a puff of its element's grains.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);

/// How long the picked racer flies from its case to the line.
const Duration kRacerFlight = Duration(milliseconds: 620);

/// The Hero tag a racer flies under.
Object racerHeroTag(String instanceId) => ('stadium.racer', instanceId);

/// A party member as a sprite [size] across (a dot of its element without
/// a sheet).
Widget stadiumSprite(CosmicPartyMember m, double size) {
  final sheet = m.spriteSheet;
  if (sheet == null) {
    return Center(
      child: Container(
        width: size * 0.4,
        height: size * 0.4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: elementColor(m.element),
        ),
      ),
    );
  }
  final v = m.spriteVisuals;
  return CreatureSprite(
    spritePath: sheet.path,
    totalFrames: sheet.totalFrames,
    rows: sheet.rows,
    frameSize: sheet.frameSize,
    stepTime: sheet.stepTime,
    scale: v?.scale ?? 1.0,
    saturation: v?.saturation ?? 1.0,
    brightness: v?.brightness ?? 1.0,
    hueShift: v?.hueShiftDeg ?? 0.0,
    isPrismatic: v?.isPrismatic ?? false,
    mutation: v?.mutation,
    tint: v?.tint,
    alchemyEffect: v?.alchemyEffect,
    costumes: v?.costumes,
    variantFaction: v?.variantFaction,
    elementType: v?.elementType,
    effectSlotSize: size,
  );
}

/// The slide-up specimen picker, for a racer. [current] opens marked;
/// [onPick] is awaited before the picker closes, so the gate under it is
/// already showing the one picked and its case can fly there.
Future<CreatureInstance?> pickRacer(
  BuildContext context, {
  required String? current,
  required Future<CosmicPartyMember?> Function(CreatureInstance inst) onPick,
  required ValueNotifier<bool> flying,
}) {
  final theme = context.read<FactionTheme>();
  return Navigator.of(context).push<CreatureInstance>(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: kRacerFlight,
      pageBuilder: (_, _, _) => AllSpecimensPage(
        theme: theme,
        instancePrefsScopeKey: 'stadium_racer',
        popOnSelect: true,
        title: 'CHOOSE A RACER',
        selectedInstanceIds: [?current],
        onWillSelectInstance: (inst) async {
          final m = await onPick(inst);
          if (m == null) return false;
          // The line's racer takes part in the flight from here.
          flying.value = true;
          return true;
        },
        caseWrapper: (inst, kase) =>
            _RacerHero(instanceId: inst.instanceId, child: kase),
      ),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    ),
  );
}

/// One end of a racer's flight. The picker's case and the line's sprite
/// both wear one; the line's own sprite is what flies, in a glow of its
/// element's light that swells mid-flight.
class _RacerHero extends StatelessWidget {
  const _RacerHero({required this.instanceId, required this.child});

  final String instanceId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: racerHeroTag(instanceId),
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      flightShuttleBuilder: (_, animation, direction, from, to) {
        final line = (direction == HeroFlightDirection.pop ? to : from).widget;
        final fly = line is Hero && line.child is _LineSprite
            ? (line.child as _LineSprite)
            : null;
        if (fly == null) return (to.widget as Hero).child;
        return AnimatedBuilder(
          animation: animation,
          builder: (_, child) {
            final t = animation.value;
            final glow = math.sin(math.pi * t.clamp(0.0, 1.0));
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        fly.tint.withValues(alpha: .38 * glow),
                        fly.tint.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: FittedBox(
            child: SizedBox.square(dimension: fly.size, child: fly.sprite),
          ),
        );
      },
      child: child,
    );
  }
}

/// The racer's sprite at the line (what a flight carries).
class _LineSprite extends StatelessWidget {
  const _LineSprite({
    required this.sprite,
    required this.size,
    required this.tint,
  });

  final Widget sprite;
  final double size;
  final Color tint;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: sprite);
}

/// Another cup's rivals: the last going quickly, the new coming up a
/// moment after, as the light reaches the new cup on the shelf.
const Duration _kRivalsChange = Duration(milliseconds: 640);
const Curve _kRivalsIn = Interval(.4, 1, curve: Curves.easeOutCubic);
const Curve _kRivalsOut = Interval(.7, 1, curve: Curves.easeIn);

class RacerGate extends StatefulWidget {
  const RacerGate({
    super.key,
    required this.racer,
    required this.rivals,
    required this.onChoose,
    required this.flying,
    required this.landings,
  });

  /// The one at the line (null: none chosen yet).
  final CosmicPartyMember? racer;
  final List<RaceRival> rivals;
  final VoidCallback onChoose;

  /// True while a racer is picked and flying in (the line's Hero joins the
  /// flight only then — opening the picker flies nothing).
  final ValueNotifier<bool> flying;

  /// Counts landings: each new one plays the puff at the line once the
  /// flight has arrived.
  final int landings;

  @override
  State<RacerGate> createState() => _RacerGateState();
}

class _RacerGateState extends State<RacerGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: kRacerFlight + const Duration(milliseconds: 950),
  );

  /// Where the flight ends, as a share of [_land].
  double get _arrive =>
      kRacerFlight.inMilliseconds / _land.duration!.inMilliseconds;

  @override
  void didUpdateWidget(covariant RacerGate old) {
    super.didUpdateWidget(old);
    if (widget.landings != old.landings) _land.forward(from: 0);
  }

  @override
  void dispose() {
    _land.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.racer;
    final tint = m == null ? _brass : elementColor(m.element);
    return LayoutBuilder(
      builder: (context, box) {
        final g = _GateGeo(box.biggest, widget.rivals.length);
        final you = g.lanes - 1;
        final size = g.sizeOf(you);
        final foot = g.footOf(you);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onChoose();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The lanes, the line, the light, and the landing.
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _GatePainter(
                      geo: g,
                      tint: tint,
                      chosen: m != null,
                      land: _land,
                      arrive: _arrive,
                    ),
                  ),
                ),
              ),
              // The rivals at the line, back lane first.
              for (var i = 0; i < widget.rivals.length; i++)
                Positioned(
                  left: g.footOf(i).dx - g.sizeOf(i) / 2,
                  top: g.footOf(i).dy - g.sizeOf(i) * .96,
                  width: g.sizeOf(i),
                  height: g.sizeOf(i),
                  // A new cup's rivals fade in over the last one's.
                  child: AnimatedSwitcher(
                    duration: _kRivalsChange,
                    switchInCurve: _kRivalsIn,
                    switchOutCurve: _kRivalsOut,
                    child: _Rival(
                      key: ValueKey(widget.rivals[i].name),
                      r: widget.rivals[i],
                      size: g.sizeOf(i),
                    ),
                  ),
                ),
              // Yours in the front lane.
              Positioned(
                left: foot.dx - size / 2,
                top: foot.dy - size * .96,
                width: size,
                height: size,
                child: m == null
                    ? const SizedBox.shrink()
                    : ValueListenableBuilder<bool>(
                        valueListenable: widget.flying,
                        builder: (_, flying, child) =>
                            HeroMode(enabled: flying, child: child!),
                        child: _RacerHero(
                          instanceId: m.instanceId,
                          child: _LineSprite(
                            sprite: stadiumSprite(m, size),
                            size: size,
                            tint: tint,
                          ),
                        ),
                      ),
              ),
              // Who runs against it.
              Positioned(
                left: g.lineAt(0).dx + 12,
                right: 0,
                top: 0,
                child: AnimatedSwitcher(
                  duration: _kRivalsChange,
                  switchInCurve: _kRivalsIn,
                  switchOutCurve: _kRivalsOut,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topRight,
                    children: [...previous, ?current],
                  ),
                  child: FittedBox(
                    key: ValueKey(widget.rivals.first.name),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topRight,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'RIVALS   ',
                            style: bracketText(
                              context,
                              9.5,
                              _muted,
                              weight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                          TextSpan(
                            text: [
                              for (final r in widget.rivals) r.name,
                            ].join('  ·  '),
                            style: bracketText(
                              context,
                              10.5,
                              _ink.withValues(alpha: .7),
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              // Who it is.
              Positioned(
                left: g.lineAt(you).dx + 18,
                right: 0,
                top: 18,
                bottom: box.maxHeight - foot.dy + 4,
                child: _Plate(racer: m),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The start: a lane per racer, the back lanes higher and smaller and
/// stepped back to the left, a slanted line across their fronts; the
/// player's racer in the front lane, the biggest.
class _GateGeo {
  _GateGeo(this.box, int rivals) : lanes = rivals + 1 {
    final w = box.width, h = box.height;
    // Upright (the hub in portrait), the pack stands bigger and steeper,
    // its back lane kept on the screen.
    tall = h > w * 0.8;
    front = tall
        ? math.max(24.0, math.min(math.min(w * .34, h * .4), 150.0))
        : math.max(24.0, math.min(h * .7, 108.0));
    frontFloor = h - 4;
    backFloor = tall
        ? math.max(front * .5, frontFloor - front * 1.9)
        : math.max(front * .46, frontFloor - front * 1.4);
    // Three in a bout (the gem cups) stand further apart than six in a
    // race, so the two behind don't stand on the front one's head.
    final few = lanes <= 3;
    lineX = w * (tall ? (few ? .6 : .5) : .4);
    final keepIn = (lineX - front * .46 * .92 - 8) / math.max(1, lanes - 1);
    step = math.max(
      0.0,
      math.min(
        tall
            ? front * (few ? .78 : .42)
            : math.min(w * (few ? .12 : .065), front * .5),
        keepIn,
      ),
    );
  }

  late final bool tall;
  late final double lineX;

  final Size box;
  final int lanes;
  late final double front, frontFloor, backFloor, step;

  double _depth(int lane) => lanes <= 1 ? 1 : lane / (lanes - 1);

  /// How big a racer in [lane] stands (0 the back lane).
  double sizeOf(int lane) => front * (.46 + .54 * _depth(lane));

  /// Where [lane] crosses the start line.
  Offset lineAt(int lane) {
    final d = _depth(lane);
    final x = lineX - (1 - d) * (lanes - 1) * step;
    return Offset(x, backFloor + (frontFloor - backFloor) * d);
  }

  /// Where a racer in [lane] stands, just behind the line.
  Offset footOf(int lane) => lineAt(lane) - Offset(sizeOf(lane) * .42, 0);
}

class _Plate extends StatelessWidget {
  const _Plate({required this.racer});

  final CosmicPartyMember? racer;

  @override
  Widget build(BuildContext context) {
    final m = racer;
    String stat(double v) => AlchemonStatSystem.displayRating(v).toString();
    TextSpan pair(String label, double v, {bool lead = false}) => TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: bracketText(context, 8.5, _muted, letterSpacing: .6),
        ),
        TextSpan(
          text: stat(v),
          style: bracketText(
            context,
            10.5,
            lead ? _ink : _ink.withValues(alpha: .75),
            weight: lead ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
    final change = Text(
      m == null ? 'CHOOSE' : 'CHANGE',
      style: bracketText(
        context,
        10,
        _brass,
        weight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.displayName,
                  maxLines: 1,
                  style: bracketText(
                    context,
                    15,
                    _brassHot,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 7),
                for (var b = 0; b < m.staminaMax; b++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: elementColor(m.element).withValues(alpha: .85),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(
                children: [
                  pair('SPD', m.statSpeed, lead: true),
                  const TextSpan(text: '   '),
                  pair('STR', m.statStrength),
                ],
              ),
              maxLines: 1,
            ),
            Text.rich(
              TextSpan(
                children: [
                  pair('INT', m.statIntelligence),
                  const TextSpan(text: '   '),
                  pair('BEA', m.statBeauty),
                ],
              ),
              maxLines: 1,
            ),
          ],
          const SizedBox(height: 4),
          change,
        ],
      ),
    );
  }
}

class _Rival extends StatelessWidget {
  const _Rival({super.key, required this.r, required this.size});

  final RaceRival r;
  final double size;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CreatureCatalog?>();
    final body = catalog == null ? null : rivalMember(catalog, r);
    return Opacity(
      opacity: .7,
      child: body == null
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: elementColor(r.element),
                ),
              ),
            )
          : stadiumSprite(body, size),
    );
  }
}

/// The lanes under the gate: each a dotted floor fading off to the right,
/// the slanted start line across them, the player's pool of light, and the
/// puff of its element's grains as a new racer lands.
class _GatePainter extends CustomPainter {
  _GatePainter({
    required this.geo,
    required this.tint,
    required this.chosen,
    required this.land,
    required this.arrive,
  }) : super(repaint: land);

  final _GateGeo geo;
  final Color tint;
  final bool chosen;
  final Animation<double> land;
  final double arrive;

  static final GrainBatch _batch = GrainBatch(6);

  static double _hash(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size box) {
    final b = _batch..clear();
    final w = box.width;
    final you = geo.lanes - 1;
    // The lanes' floors, back to front, fading to the right.
    for (var lane = 0; lane < geo.lanes; lane++) {
      final at = geo.lineAt(lane);
      final left = at.dx - geo.sizeOf(lane) * 1.1;
      // A short run ahead of the line, thinning out.
      final right = math.min(w, at.dx + geo.sizeOf(lane) * 1.4);
      final gap = 4.0 + 3 * (1 - lane / you);
      for (var x = left; x < right; x += gap) {
        final fade = 1 - (x - left) / (right - left);
        if (_hash((x * 3).round() + lane * 977, 3) > fade * fade + .08) {
          continue;
        }
        b.add(lane == you ? 0 : 1, x, at.dy);
      }
    }
    // The start line, across the fronts.
    final back = geo.lineAt(0), front = geo.lineAt(you);
    final len = (front - back).distance;
    for (var d = -6.0; d <= len + 4; d += 3) {
      final p = Offset.lerp(back, front, d / len)!;
      b.add(2, p.dx, p.dy);
    }

    // The pool of light the racer stands in.
    final size = geo.sizeOf(you);
    final pool = geo.footOf(you) + const Offset(0, -2);
    final t = land.value;
    final arrived = ((t - arrive) / (1 - arrive)).clamp(0.0, 1.0);
    final flare = t <= arrive || t >= 1 ? 0.0 : math.sin(math.pi * arrived);
    if (chosen) {
      final r = size * (.6 + .25 * flare);
      canvas.drawOval(
        Rect.fromCenter(center: pool, width: r * 2, height: r * .5),
        Paint()
          ..shader = ui.Gradient.radial(pool, r, [
            tint.withValues(alpha: .34 + .3 * flare),
            tint.withValues(alpha: 0),
          ]),
      );
    }

    // The landing: grains of its element thrown low along the lane from
    // its feet, drifting out and settling.
    if (flare > 0) {
      final e = Curves.easeOutCubic.transform(arrived);
      for (var i = 0; i < 46; i++) {
        final side = i.isEven ? 1.0 : -1.0;
        final reach = size * (.25 + .55 * _hash(i, 21)) * e;
        final lift = math.sin(math.pi * arrived) * size * .16 * _hash(i, 22);
        b.add(
          _hash(i, 23) < .3 ? 4 : 3,
          pool.dx + side * reach,
          pool.dy - lift + (_hash(i, 24) - .5) * 4,
        );
      }
    }
    b.draw(canvas, 0, 1.7, _brass.withValues(alpha: .55));
    b.draw(canvas, 1, 1.3, _brass.withValues(alpha: .3));
    b.draw(canvas, 2, 1.5, _ink.withValues(alpha: .5));
    final fade = 1 - arrived;
    b.draw(canvas, 3, 2.0, tint.withValues(alpha: .75 * fade));
    b.draw(
      canvas,
      4,
      2.4,
      Color.lerp(tint, Colors.white, .45)!.withValues(alpha: .9 * fade),
    );
  }

  @override
  bool shouldRepaint(_GatePainter old) =>
      old.geo.box != geo.box ||
      old.geo.lanes != geo.lanes ||
      old.tint != tint ||
      old.chosen != chosen;
}
