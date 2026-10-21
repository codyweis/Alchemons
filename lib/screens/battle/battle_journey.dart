// lib/screens/battle/battle_journey.dart
//
// The way into a live battle (the author, 2026-10-21: "whoever hosts should
// do an awesome transition into their planet, into their home and
// transition into their battle field"). The fight is held at the host's
// place, so both phones go there, in the five seconds between START and
// the fight, landing together on the start time:
//
//   their planet   the host's home planet as it looks, hanging in space,
//                  coming closer; then the dive: it swells, its surface
//                  lifts off in its own grains, and the camera is inside
//                  its air, rushing
//   their home     the air thins and the host's home comes up under it,
//                  settling, the realm they last left with its residents
//                  where they were left; their name on it
//   the arena      the home opens from the floor's middle outward on a soft,
//                  uneven edge, and the arena's floor is under it; the
//                  edge sheds lights of the home's own colours that are
//                  drawn in onto the floor's rim — ending as the fight's
//                  own first frame, the whole floor, where the two sides
//                  gather
//
// The way out (BACK TO THE LOBBY) is the same in short, the other way: the
// floor opens onto the home, which draws in to a planet that falls away
// into the dark. A REMATCH skips all of it.
//
// (A first pass broke the home into falling grains, realm_sift's way: over
// a floor its pale sky read as snow, the front as a lattice of squares and
// a three-lobed hole. The opening has no grid, and its edge is lopsided.)
//
// The home is pictured once, in the lobby, before the fight is started
// ([BattleJourneyPrep]): a field built offstage, stood still, drawn into a
// picture and let go. During the way in nothing is built: a picture, the
// planet's own painter, and grains in batches.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart' show homeColorSwatch;
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/screens/friends/friend_home_screen.dart'
    show friendHomeGame, hydrateFriendHome, standFriendHome;
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/realm_sift.dart';
import 'package:alchemons/widgets/home_planet_view.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long the way in takes: the time from START to the fight.
const double kBattleJourneySeconds = 5.0;

/// How long the way out takes.
const double kBattleJourneyOutSeconds = 2.3;

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

double _ease(double x) {
  final t = _clamp01(x);
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// Space, and the dark under a home as it falls away.
const Color _kSpace = Color(0xFF020010);

/// What the way in shows of the host's place: their planet as it looks,
/// their home pictured, and whose it is.
class BattleJourneyArt {
  BattleJourneyArt({this.planet, this.home, required this.whose});

  /// Null for a host with no planet yet: the way in starts at their home.
  final PlanetLook? planet;

  /// The host's home, pictured at this phone's screen size; null when it
  /// could not be (the way in goes from the planet to the floor).
  final RealmPicture? home;

  /// 'YOUR HOME', or the host's ('BO'S HOME').
  final String whose;

  Color get color => homeColorSwatch(planet?.color);

  void dispose() => home?.dispose();
}

/// Pictures the host's place for the way in, offstage, in the lobby: their
/// planet's look and their home (the host's own from this save; a friend's
/// as they published it), told [onReady] once.
class BattleJourneyPrep extends StatefulWidget {
  const BattleJourneyPrep({
    super.key,
    required this.host,
    required this.hostName,
    required this.mine,
    required this.onReady,
  });

  final String host;
  final String hostName;

  /// This phone is the host's.
  final bool mine;
  final ValueChanged<BattleJourneyArt> onReady;

  @override
  State<BattleJourneyPrep> createState() => _BattleJourneyPrepState();
}

class _BattleJourneyPrepState extends State<BattleJourneyPrep> {
  SceneGame? _game;
  Size _wide = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_whenStill());
    });
  }

  /// Building a field is heavy work on the screen's own thread: it waits
  /// until the lobby has finished coming in and stood a moment, so the way
  /// in and the first taps there are not caught by it.
  Future<void> _whenStill() async {
    final coming = ModalRoute.of(context)?.animation;
    if (coming != null && coming.status != AnimationStatus.completed) {
      final done = Completer<void>();
      void listen(AnimationStatus s) {
        if (s == AnimationStatus.completed && !done.isCompleted) {
          done.complete();
        }
      }

      coming.addStatusListener(listen);
      await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
      coming.removeStatusListener(listen);
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) await _load();
  }

  String get _whose =>
      widget.mine ? 'YOUR HOME' : '${widget.hostName.toUpperCase()}\'S HOME';

  Future<void> _load() async {
    PlanetLook? planet;
    FriendHome? home;
    try {
      if (widget.mine) {
        final wear = context.read<CosmeticWearService?>();
        home = await FriendHome.capture(
          context.read<AlchemonsDatabase>(),
          trailOf: (id) => wear?.trailOf(id)?.id,
          ambienceIn: (realm) => wear?.ambienceIn(realm)?.id,
        );
        planet =
            home.planet ??
            PlanetLook.read(await SharedPreferences.getInstance());
      } else {
        final friends = context.read<FriendService?>();
        home = await friends?.fetchHome(widget.host);
        planet = home?.planet;
        if (planet == null && friends != null) {
          for (final f in friends.friends) {
            if (f.uid == widget.host) planet = f.planet;
          }
        }
      }
    } catch (e) {
      debugPrint('BattleJourneyPrep: the host\'s place was not read: $e');
    }
    if (!mounted) return;
    if (home == null) {
      widget.onReady(BattleJourneyArt(planet: planet, whose: _whose));
      return;
    }
    RealmPicture? picture;
    try {
      picture = await _picture(home);
    } catch (e) {
      debugPrint('BattleJourneyPrep: the home was not pictured: $e');
    }
    if (!mounted) {
      picture?.dispose();
      return;
    }
    widget.onReady(
      BattleJourneyArt(planet: planet, home: picture, whose: _whose),
    );
  }

  /// The home built offstage at the phone's landscape size, stood still,
  /// and drawn to cover the upright screen.
  Future<RealmPicture?> _picture(FriendHome home) async {
    final catalog = context.read<CreatureCatalog>();
    final view = MediaQuery.of(context);
    final screen = view.size;
    final ratio = math.min(2.0, view.devicePixelRatio);
    final (layout, looks) = hydrateFriendHome(home, catalog);
    final game = friendHomeGame(home, layout)
      ..panDrift = 0
      ..pauseEngine();
    setState(() {
      _wide = Size(
        math.max(screen.width, screen.height),
        math.min(screen.width, screen.height),
      );
      _game = game;
    });
    bool alive() => mounted && _game == game;
    try {
      await game.loaded.timeout(const Duration(seconds: 8));
    } catch (_) {}
    for (var i = 0; i < 2; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!alive()) return null;
      game.stepEngine(stepTime: 0);
    }
    await standFriendHome(game, layout, looks, catalog, alive);
    if (!alive()) return null;
    // Its light and grass at rest, a step a frame rather than all at once.
    for (var i = 0; i < 6; i++) {
      game.update(1 / 30);
      await WidgetsBinding.instance.endOfFrame;
      if (!alive()) return null;
    }
    final wide = _wide;
    final cover = math.max(
      screen.width / wide.width,
      screen.height / wide.height,
    );
    final picture = await RealmPicture.record('home', screen, ratio, (canvas) {
      canvas.translate(
        (screen.width - wide.width * cover) / 2,
        (screen.height - wide.height * cover) / 2,
      );
      canvas.scale(cover);
      game.render(canvas);
    });
    if (mounted) setState(() => _game = null);
    return picture;
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) return const SizedBox.shrink();
    return Offstage(
      child: SizedBox.fromSize(
        size: _wide,
        child: GameWidget(key: ObjectKey(game), game: game),
      ),
    );
  }
}

/// The way in, painted at [t] seconds of [kBattleJourneySeconds]; [floor]
/// paints the arena's floor as the fight first frames it, at an opacity.
class BattleJourneyScene {
  BattleJourneyScene({
    required this.art,
    required this.size,
    required this.floorCentre,
    required this.floorRx,
    required this.floorRy,
  }) : homeAt = art.planet == null ? 0.0 : 2.0;

  final BattleJourneyArt art;
  final Size size;

  /// Where the floor lies on the screen, and how wide and tall, as the
  /// fight's first frame has it.
  final Offset floorCentre;
  final double floorRx, floorRy;

  /// When the home is up (at once, with no planet to dive into).
  final double homeAt;

  /// When the home opens onto the floor, and how long the opening takes to
  /// pass the screen's far corner.
  static const double siftAt = 3.2;
  static const double openFor = 1.0;

  /// When the floor starts to rise, under the home, so the home comes
  /// apart onto it rather than onto the dark.
  static const double floorAt = 2.7;

  RealmAir? _air;
  final math.Random _spawn = math.Random(19);
  double? _last;
  double _rush = 0;
  TextPainter? _caption;

  static final GrainBatch _b = GrainBatch(10);

  Offset get _middle => Offset(size.width / 2, size.height * 0.46);

  void paint(
    Canvas canvas,
    double t, {
    required void Function(Canvas canvas, double alpha) floor,
  }) {
    final dt = _step(t);
    canvas.drawRect(Offset.zero & size, Paint()..color = _kSpace);
    final planet = art.planet;
    final home = art.home;

    // The floor rising out of the dark, under whatever is still above it.
    final double floorUp;
    if (home == null && planet == null) {
      floorUp = _smooth(0, 1.2, t);
    } else if (home == null) {
      // Out of the planet's air straight onto the floor.
      floorUp = _smooth(homeAt - 0.2, homeAt + 1.4, t);
    } else {
      // Up in full under the home by the time it opens.
      floorUp = _smooth(floorAt, siftAt, t);
    }
    if (floorUp > 0.004) floor(canvas, floorUp);

    // Their planet, and the dive into it.
    if (planet != null && t < homeAt + 0.8) {
      _paintPlanet(canvas, planet, t, dt, landing: home == null);
    }

    // Their home: up under the thinning air, whole while it is held, then
    // coming apart from the floor's middle outward.
    if (home != null) {
      final up = homeAt <= 0
          ? _smooth(0, 0.6, t)
          : _smooth(homeAt - 0.15, homeAt + 0.6, t);
      final reach = _openingReach(size, floorCentre);
      final open = t < siftAt ? 0.0 : reach * _ease((t - siftAt) / openFor);
      if (up > 0.004 && open < reach) {
        canvas.saveLayer(Offset.zero & size, Paint());
        _paintHome(canvas, home, t, up);
        if (open > 0) eraseOpening(canvas, floorCentre, open, t, 5);
        canvas.restore();
        // Its edge lit, as the home portal's hole is: grains of light along
        // it, so the home opens on light, not on ink.
        if (open > 0) paintOpeningRim(canvas, floorCentre, open, t, 5);
      }
      if (t >= siftAt) {
        final air = _air ??= RealmAir(1200);
        // The opening's edge sheds lights of the home's colours, warmed
        // toward the arena's brass, each drawn in onto the floor's rim.
        if (open < reach) {
          final n = (dt * 1000).round();
          for (var i = 0; i < n; i++) {
            final a = _spawn.nextDouble() * math.pi * 2;
            final r = open * (1 + openingRagged(a, t, 5));
            final p = floorCentre + Offset(math.cos(a), math.sin(a)) * r;
            if (p.dx < 0 ||
                p.dy < 0 ||
                p.dx > size.width ||
                p.dy > size.height) {
              continue;
            }
            final tone = _warm(
              home.colourAt(p.dx / size.width, p.dy / size.height),
            );
            air.add(p.dx, p.dy, math.cos(a) * 30, math.sin(a) * 30, tone, 0);
          }
        }
        air.step(dt, size);
        air.gather(
          0,
          air.clock,
          _onFloor,
          spread: 0.12,
          duration: 0.55,
          durationSpread: 0.2,
        );
        air.paint(canvas, fade: 1 - _smooth(kBattleJourneySeconds, 5.4, t));
      }
      // Whose home it is, while it is held.
      final named =
          _smooth(homeAt + 0.45, homeAt + 0.9, t) *
          (1 - _smooth(siftAt - 0.15, siftAt + 0.2, t));
      if (named > 0.01) _paintCaption(canvas, named);
    }
  }

  double _step(double t) {
    final last = _last;
    _last = t;
    if (last == null || t < last || t - last > 0.25) return 1 / 60;
    return t - last;
  }

  /// [tone] (0xRRGGBB) carried a third of the way to the arena's brass.
  static int _warm(int tone) {
    int mix(int v, int to) => (v + (to - v) / 3).round().clamp(0, 255);
    return (mix((tone >> 16) & 0xFF, 0xCD) << 16) |
        (mix((tone >> 8) & 0xFF, 0xB0) << 8) |
        mix(tone & 0xFF, 0x7A);
  }

  /// A point on the floor for a grain to land in: most near its edge, so
  /// the lights draw the floor's shape as they come.
  Offset _onFloor(math.Random rng) {
    final a = rng.nextDouble() * math.pi * 2;
    final rim = rng.nextDouble() < 0.55;
    final r = rim
        ? 0.82 + 0.16 * rng.nextDouble()
        : 0.8 * math.sqrt(rng.nextDouble());
    return floorCentre +
        Offset(math.cos(a) * floorRx, math.sin(a) * floorRy) * r;
  }

  void _paintPlanet(
    Canvas canvas,
    PlanetLook look,
    double t,
    double dt, {
    required bool landing,
  }) {
    final color = art.color;
    final c = _middle;
    final r0 = planetBodyRadius(look, size.shortestSide, 0.62);
    // It comes closer, then the camera falls into it.
    final near = r0 * (1 + 0.16 * _smooth(0, 1.0, t));
    final u = _clamp01((t - 0.8) / (homeAt - 0.8));
    final pr = near / (1 - 0.8 * _ease(u));
    final inside = _smooth(0.38, 0.78, u);
    final thin = landing
        ? _smooth(homeAt - 0.1, homeAt + 0.7, t)
        : _smooth(homeAt - 0.2, homeAt + 0.55, t);
    final air = inside * (1 - thin);

    // Stars, drawing past as it nears; gone once inside.
    final starAlpha = 1 - _smooth(0.2, 0.6, u);
    if (starAlpha > 0.01) {
      final b = _b..clear();
      final spread = 1 + 0.35 * _smooth(0, 1, t) + 1.4 * _ease(u);
      for (var i = 0; i < 140; i++) {
        final p = Offset(_h(i, 31) * size.width, _h(i, 32) * size.height);
        final q = c + (p - c) * spread;
        b.add(i % 3, q.dx, q.dy);
      }
      for (var k = 0; k < 3; k++) {
        b.draw(
          canvas,
          k,
          1.1 + k * 0.5,
          Color.lerp(
            const Color(0xFFB8C4E0),
            Colors.white,
            k / 2,
          )!.withValues(alpha: starAlpha * (0.35 + 0.25 * k)),
        );
      }
    }
    if (air > 0.004) _paintAir(canvas, color, air);

    final planetAlpha = 1 - _smooth(0.36, 0.66, u);
    if (planetAlpha > 0.004) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, planetAlpha),
      );
      paintPlanetLook(canvas, c, pr, 4 + t, look);
      canvas.restore();
    }
    // Its surface lifting off toward the camera.
    final peel = _smooth(0.3, 0.8, u);
    final flakes = peel * (1 - _smooth(0.72, 0.95, u));
    if (flakes > 0.004) _paintFlakes(canvas, color, c, pr, peel, flakes);

    // Its air rushing past, slowing as the home comes up.
    final pace = _smooth(0.5, 1, u) * (1 - thin);
    _rush += dt * pace * 900;
    if (air > 0.004) _paintRush(canvas, color, c, air, pace);
  }

  void _paintAir(Canvas canvas, Color color, double alpha) {
    final r = math.sqrt(size.width * size.width + size.height * size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          _middle,
          r * 0.6,
          [
            Color.lerp(color, Colors.black, 0.64)!.withValues(alpha: alpha),
            Color.lerp(color, Colors.black, 0.85)!.withValues(alpha: alpha),
            Color.lerp(_kSpace, color, 0.06)!.withValues(alpha: alpha),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  void _paintFlakes(
    Canvas canvas,
    Color color,
    Offset pc,
    double pr,
    double peel,
    double alpha,
  ) {
    final b = _b..clear();
    for (var i = 0; i < 340; i++) {
      final angle = _h(i, 11) * math.pi * 2;
      final rho = math.sqrt(_h(i, 12)) * 0.96;
      final lift = 1 + peel * (0.6 + 2.8 * rho * rho) * (0.7 + 0.6 * _h(i, 13));
      final at =
          pc + Offset(math.cos(angle), math.sin(angle)) * (pr * rho * lift);
      b.add(i % 4, at.dx, at.dy);
    }
    final shades = [
      color,
      Color.lerp(color, Colors.white, 0.25)!,
      Color.lerp(color, Colors.white, 0.5)!,
      Color.lerp(color, Colors.white, 0.8)!,
    ];
    b.draw(canvas, 2, 6, color.withValues(alpha: 0.14 * alpha));
    for (var k = 0; k < 4; k++) {
      b.draw(canvas, k, 2.0 + k * 0.45, shades[k].withValues(alpha: alpha));
    }
  }

  void _paintRush(
    Canvas canvas,
    Color color,
    Offset centre,
    double alpha,
    double pace,
  ) {
    final b = _b..clear();
    final far =
        math.sqrt(size.width * size.width + size.height * size.height) * 0.62;
    for (var i = 0; i < 260; i++) {
      final angle = _h(i, 1) * math.pi * 2;
      final speed = 0.5 + _h(i, 2);
      final d = (_h(i, 3) + _rush * speed / far) % 1.0;
      final rr = far * math.pow(d, 1.7);
      final dir = Offset(math.cos(angle), math.sin(angle));
      final at = centre + dir * rr;
      final shade = i % 4;
      final fade = _smooth(0.0, 0.2, d) * (1 - _smooth(0.85, 1, d));
      b.add(fade > 0.5 ? shade : 4 + shade, at.dx, at.dy);
      final run = (pace * d * 7).round();
      for (var k = 1; k <= run; k++) {
        final back = at - dir * (k * (2.5 + 9 * d) * pace);
        b.add(8 + (k * 2 > run ? 1 : 0), back.dx, back.dy);
      }
    }
    final deep = Color.lerp(color, Colors.black, 0.3)!;
    final lit = Color.lerp(color, Colors.white, 0.35)!;
    final hot = Color.lerp(color, Colors.white, 0.7)!;
    final shades = [deep, color, lit, hot];
    b.draw(canvas, 9, 1.6, lit.withValues(alpha: 0.26 * alpha));
    b.draw(canvas, 8, 1.9, lit.withValues(alpha: 0.5 * alpha));
    b.draw(canvas, 3, 6, color.withValues(alpha: 0.1 * alpha));
    for (var k = 0; k < 4; k++) {
      b.draw(canvas, 4 + k, 1.8, shades[k].withValues(alpha: 0.5 * alpha));
      b.draw(canvas, k, 2.0 + k * 0.35, shades[k].withValues(alpha: alpha));
    }
  }

  /// The home, settling as it comes up: a little large at first, then the
  /// screen's own size by the time it comes apart.
  void _paintHome(Canvas canvas, RealmPicture home, double t, double up) {
    final settle = homeAt <= 0
        ? _smooth(0, 1.0, t)
        : _smooth(homeAt - 0.15, homeAt + 0.9, t);
    final scale = 1.1 - 0.1 * settle;
    final image = home.image;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * scale,
      height: size.height * scale,
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, up),
    );
  }

  void _paintCaption(Canvas canvas, double alpha) {
    final tp = _caption ??= TextPainter(
      text: TextSpan(
        text: art.whose,
        style: const TextStyle(
          color: Color(0xFFE8DFC8),
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(size.width / 2, size.height * 0.8);
    // A soft dark pool under it, so it reads on any home: wide, and faded
    // well before its edge, so it is never seen as a shape.
    final poolW = tp.width + 260;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, 130 / poolW);
    canvas.drawCircle(
      Offset.zero,
      poolW / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          poolW / 2,
          [
            Colors.black.withValues(alpha: 0.42 * alpha),
            Colors.black.withValues(alpha: 0.2 * alpha),
            Colors.black.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    canvas.restore();
    canvas.saveLayer(
      Rect.fromCenter(center: at, width: tp.width + 40, height: 60),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
    );
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
  }

  void dispose() => _air?.dispose();
}

/// How far an opening from [centre] has to grow to pass every corner of a
/// screen of [size], ragged edge and all.
double _openingReach(Size size, Offset centre) {
  var far = 0.0;
  for (final c in [
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ]) {
    far = math.max(far, (c - centre).distance);
  }
  return far * 1.25;
}

/// How far the edge of an opening stands off its round at angle [a]: a few
/// slow waves of different counts, drifting with [t], so it is lopsided
/// and never a star.
double openingRagged(double a, double t, int seed) {
  final p = seed * 1.7;
  return 0.085 * math.sin(2 * a + p + 0.7 * t) +
      0.055 * math.sin(5 * a + 2.3 * p - 1.1 * t) +
      0.03 * math.sin(9 * a + 0.6 * p + 1.9 * t);
}

final GrainBatch _rimBatch = GrainBatch(4);

/// The lit rim of an opening of [radius] round [centre] ([eraseOpening]):
/// grains along its uneven edge in the arena's brass and ember, each
/// shimmering a little in and out of it.
void paintOpeningRim(
  Canvas canvas,
  Offset centre,
  double radius,
  double t,
  int seed,
) {
  final b = _rimBatch..clear();
  // About one every three pixels of edge, so it stays a line of light as
  // it grows.
  final n = (radius * math.pi * 2 / 3).round().clamp(160, 1600);
  for (var i = 0; i < n; i++) {
    final a = (i + _h(i, 41) * 0.8) / n * math.pi * 2;
    final shimmer = math.sin(t * (3 + 4 * _h(i, 42)) + _h(i, 43) * 6.3);
    final r =
        radius * (1 + openingRagged(a, t, seed)) * (0.985 + 0.02 * shimmer);
    final p = centre + Offset(math.cos(a), math.sin(a)) * r;
    b.add(i % 3, p.dx, p.dy);
  }
  const brass = Color(0xFFCDB07A), ember = Color(0xFFE0905A);
  final hot = Color.lerp(brass, Colors.white, 0.55)!;
  b.draw(canvas, 0, 7, brass.withValues(alpha: 0.12));
  b.draw(canvas, 0, 2.2, brass.withValues(alpha: 0.9));
  b.draw(canvas, 1, 1.8, ember.withValues(alpha: 0.8));
  b.draw(canvas, 2, 1.6, hot.withValues(alpha: 0.95));
}

/// Takes out of what is drawn under it (in a layer) an opening of [radius]
/// round [centre], its edge uneven ([openingRagged]) and soft: rings, each
/// a little smaller, taking out a share each, so the middle is clear and
/// the edge thins over its last twentieth. No blur.
void eraseOpening(
  Canvas canvas,
  Offset centre,
  double radius,
  double t,
  int seed,
) {
  const rings = 8;
  final paint = Paint()..blendMode = BlendMode.dstOut;
  for (var k = 0; k < rings; k++) {
    // The smallest clears all inside it; the rest thin the edge.
    paint.color = Color.fromRGBO(0, 0, 0, k == 0 ? 1 : 0.38);
    final f = 0.95 + 0.05 * k / (rings - 1);
    canvas.drawPath(openingPath(centre, radius * f, t, seed), paint);
  }
}

/// The uneven round of an opening of [radius] round [centre].
Path openingPath(Offset centre, double radius, double t, int seed) {
  final path = Path();
  for (var i = 0; i <= 96; i++) {
    final a = i / 96 * math.pi * 2;
    final r = radius * (1 + openingRagged(a, t, seed));
    final x = centre.dx + math.cos(a) * r, y = centre.dy + math.sin(a) * r;
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  return path..close();
}

/// The way out, painted at [t] seconds of [kBattleJourneyOutSeconds]: the
/// fight's last frame ([floor], pictured as it was left) comes apart from
/// the floor's middle, the host's home is under it, and the home draws in
/// to their planet, which falls away into the dark.
class BattleJourneyExit {
  BattleJourneyExit({
    required this.art,
    required this.size,
    required this.floor,
    required this.floorCentre,
  });

  final BattleJourneyArt art;
  final Size size;
  final RealmPicture floor;
  final Offset floorCentre;

  void paint(Canvas canvas, double t) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _kSpace);
    final centre = Offset(size.width / 2, size.height * 0.46);
    final home = art.home;
    final planet = art.planet;
    final out =
        1 -
        _smooth(kBattleJourneyOutSeconds - 0.35, kBattleJourneyOutSeconds, t);
    // Drawing in, from the whole screen to a planet's disc.
    final k = _smooth(1.0, 2.0, t);
    final r0 = planet == null
        ? size.shortestSide * 0.2
        : planetBodyRadius(planet, size.shortestSide, 0.62);
    // From just past the screen's corners (its edge uneven) to the
    // planet's disc, so all of the closing is seen.
    final cover = size.longestSide * 0.62;
    final radius = cover * (1 - k) + r0 * k;
    final toPlanet = planet == null ? 0.0 : _smooth(0.72, 1.0, k);
    if (home != null) {
      final up = (1 - toPlanet) * out;
      if (up > 0.004) {
        // The home stays where it is; the window onto it closes round its
        // middle, as the home portal's does, its edge lit.
        final at = Offset.lerp(size.center(Offset.zero), centre, k)!;
        canvas.save();
        if (k > 0) canvas.clipPath(openingPath(at, radius, t, 3));
        final image = home.image;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Offset.zero & size,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(255, 255, 255, up),
        );
        canvas.restore();
        if (k > 0 && radius < size.longestSide) {
          canvas.saveLayer(
            Offset.zero & size,
            Paint()..color = Color.fromRGBO(0, 0, 0, up),
          );
          paintOpeningRim(canvas, at, radius, t, 3);
          canvas.restore();
        }
      }
    }
    if (planet != null) {
      final shown = (home == null ? _smooth(0.3, 0.9, t) : toPlanet) * out;
      if (shown > 0.004) {
        // Falling away: smaller as it goes.
        final r = r0 * (1 - 0.35 * _smooth(1.6, kBattleJourneyOutSeconds, t));
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Color.fromRGBO(0, 0, 0, shown),
        );
        paintPlanetLook(canvas, centre, r, 4 + t, planet);
        canvas.restore();
      }
    }
    // Over it all at first, the fight's last frame, opening from the
    // floor's middle onto what is under it.
    final reach = _openingReach(size, floorCentre);
    final open = reach * _ease(t / 0.75);
    if (open < reach) {
      final image = floor.image;
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
      if (open > 0) eraseOpening(canvas, floorCentre, open, t, 3);
      canvas.restore();
      if (open > 0) paintOpeningRim(canvas, floorCentre, open, t, 3);
    }
  }

  void dispose() => floor.dispose();
}
