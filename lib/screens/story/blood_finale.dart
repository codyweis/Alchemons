// lib/screens/story/blood_finale.dart
//
// THE FINALE, after the Blood Ring's ritual. Black, and the companion offered
// to the ring gathering up out of its light, grain by grain, and standing
// there, alive -- shown only ever as its grains (its own sprite is read off
// the screen, genetics and costumes on it). "Every collection has a
// favorite." Then the sacrifice: blood runs down over it, and it drips away,
// all of it, into a pool at its feet. A moment of nothing but the pool. And
// a new one rises out of the blood, bigger and brighter, embers of blood
// rising round it: Bloodborn, a favorite made stronger. "Alchemy is
// power." "Favorites can always become stronger."
//
// Then it is sent below, to the chamber: it drips away into the pool and
// the pool is drawn down out of sight. (In the save the offering is gone
// and a Bloodborn Vial waits in the extraction chamber -- see
// docs/campaign_story_canon.md.) The credits roll over the census: every
// species the player has found drifts past in its grains, in three lanes
// deep, each leaving a few grains hanging in the dark (a finger stirs them;
// a tapped Alchemon comes apart and gathers back). Last, the vial: that
// pool sealed in its round chamber, the new one half formed out of it,
// beating (bloodborn_vial.dart). "The census is finished. The collector is
// not." Then, alone: "Thank you for playing."
//
// The lines are the author's (2026-10-16) and each waits for a tap; the
// motion between them plays on its own. No fades onto a sprite, no flashes,
// no shake, no lines drawn as strokes: grains, light and dark, as the first
// descent is.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/bloodborn_vial.dart'
    show BloodbornVialField;
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;
import 'package:alchemons/widgets/fx/realm_sift.dart' show RealmAir;
import 'package:alchemons/widgets/particle_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// One species in the census: its grains (at their read size, centred) and
/// the element that decides which realm its grains are poured into.
class CensusEntry {
  const CensusEntry(this.grains, this.element);
  final SpecimenGrains grains;
  final String element;
}

/// The species the save has found, read into grains a few at a time.
class CensusReader {
  CensusReader(this.db, this.catalog);
  final AlchemonsDatabase db;
  final CreatureCatalog catalog;

  /// How high each is read, in px: small, since it passes as grains.
  static const int readHeight = 150;

  Future<List<String>> ids() async {
    final rows = await (db.select(
      db.playerCreatures,
    )..where((t) => t.discovered.equals(true))).get();
    final ids = [
      for (final r in rows)
        if (catalog.getCreatureById(r.id)?.image.isNotEmpty ?? false) r.id,
    ]..sort();
    return ids;
  }

  Future<CensusEntry?> read(String id) async {
    final c = catalog.getCreatureById(id);
    if (c == null || c.image.isEmpty) return null;
    return readCensusImage(
      'assets/images/${c.image}',
      c.types.isEmpty ? '' : c.types.first,
    );
  }
}

/// [asset] decoded small and read into grains, for the census.
Future<CensusEntry?> readCensusImage(String asset, String element) async {
  try {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: CensusReader.readHeight,
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    try {
      final bytes = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (bytes == null) return null;
      final grains = SpecimenGrains.fromRgba(
        bytes.buffer.asUint8List(),
        image.width,
        image.height,
        pixelRatio: 1,
        maxGrains: 420,
        tones: 16,
      );
      return grains.length < 40 ? null : CensusEntry(grains, element);
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  }
}

class BloodFinalePage extends StatefulWidget {
  const BloodFinalePage({
    super.key,
    required this.offering,
    this.census,
    this.offeringGrains,
    this.portrait,
  });

  /// The companion offered to the ring.
  final CosmicPartyMember offering;

  /// The census already read (previews); otherwise it is read from the save.
  final List<CensusEntry>? census;

  /// The offering already read into grains (previews); otherwise its own
  /// sprite is read, off the screen, the moment it has drawn.
  final SpecimenGrains? offeringGrains;

  /// What is read for the offering instead of its own sprite (previews).
  final Widget Function(double size)? portrait;

  @override
  State<BloodFinalePage> createState() => _BloodFinalePageState();
}

class _Line {
  const _Line(this.text, {this.hint = 'CONTINUE', this.brass = false});
  final String text;
  final String hint;

  /// Set in brass: the last thing said.
  final bool brass;
}

const _lines = [
  _Line('Every collection has a favorite.'),
  _Line('Alchemy is power.'),
  _Line('Favorites can always become stronger.'),
  _Line('The census is finished. The collector is not.'),
  _Line('Thank you for playing.', hint: 'RETURN', brass: true),
];

/// The credits, a block at a time over the census: a heading and its names.
const _credits = <(String, List<String>)>[
  ('', []), // the title, in its grains
  ('Created by', ['Cody Weisenberger', 'Luck3yApps LLC']),
  ('Alchemon designs and sprites by', ['Nehaalg']),
  ('Music by', ['Cleyton Kauffman', 'GloryToTheMachine']),
  ('Special thanks to', ['Bryce', 'Whitney', 'Diego']),
];

enum _Seg { offering, remade, sent, census, last, thanks, gone }

/// The ring's light, the blood the grains are dyed, and its darker shade.
const _kRing = Color(0xFFB3122E);
const _kBlood = Color(0xFFC21A35);
const _kBloodDark = Color(0xFF6E0A1C);

/// The offering gathering out of the ring's light, and then held.
const double _kAssemble = 2.6;

/// Sacrificed and reborn: dyed with blood; dripping away into a pool at
/// its feet, the lowest first; a moment of nothing but the pool; a new one
/// rising out of it. Done (the next line) by [_kRemade].
const double _kDripAt = 1.4, _kDripSpan = 2.6;
const double _kRiseAt = 6.0, _kRiseSpan = 2.0, _kRemade = 9.6;

/// How much bigger the one reborn stands than the one offered.
const double _kReborn = 1.15;

/// Sent below, to the chamber: the one reborn drips away into the pool, the
/// lowest first; then the pool is drawn down out of sight. The census
/// begins at [_kSent].
const double _kSinkAt = 3.0, _kSent = 4.8;

/// A tapped Alchemon in the census comes apart and gathers back in this long.
const double _kBurst = 1.6;

/// When the vial has half formed its one and the last line comes.
const double _kVialSpeaks = 5.2;

class _BloodFinalePageState extends State<BloodFinalePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = _Frame();
  Duration _last = Duration.zero;
  double _clock = 0;
  _Seg _seg = _Seg.offering;
  double _segT = 0;
  Size _size = Size.zero;

  int? _stop;
  double _stopAt = 0;
  final Set<int> _spoken = {};

  // The offering, in its grains from first to last.
  final GlobalKey _readKey = GlobalKey();
  SpecimenGrains? _grains;
  _Specimen? _offer;
  Float32List _yRank = Float32List(0);
  bool _reading = false;
  Timer? _readLate;
  double _assembleT = 0;
  final _Specimen _drops = _Specimen.capacity(2400);
  final _Specimen _embers = _Specimen.capacity(64);

  // The census.
  final List<CensusEntry> _census = [];
  int _censusTotal = 0;
  bool _censusRead = false;
  final List<_Walker> _walkers = [];
  int _spawned = 0;
  double _spawnClock = 0;
  final _air = RealmAir(3200);

  // The vial it was sent to, last: its pool and the new one forming.
  BloodbornVialField? _vial;
  double _vialT = 0;

  double _fadeOut = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final given = widget.census;
    if (given != null) {
      _census.addAll(given);
      _censusTotal = given.length;
      _censusRead = true;
    }
    final grains = widget.offeringGrains;
    if (grains != null) _takeGrains(grains);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.audio?.playEndCreditsMusic());
      if (widget.census == null) unawaited(_readCensus());
    });
    // A sprite that never says it has drawn is read anyway.
    _readLate = Timer(const Duration(seconds: 4), () => unawaited(_read()));
    _ticker.start();
  }

  @override
  void dispose() {
    _readLate?.cancel();
    _ticker.dispose();
    _frame.dispose();
    _air.dispose();
    super.dispose();
  }

  Future<void> _readCensus() async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final reader = CensusReader(db, catalog);
    final ids = await reader.ids();
    if (!mounted) return;
    _censusTotal = ids.length;
    for (final id in ids) {
      final entry = await reader.read(id);
      if (!mounted) return;
      if (entry != null) _census.add(entry);
    }
    _censusRead = true;
  }

  /// Reads the offering as its sprite has drawn it, off the screen: this
  /// frame, its genetics and costumes on it.
  Future<void> _read() async {
    if (_grains != null || _reading) return;
    _reading = true;
    final box = _readKey.currentContext?.findRenderObject();
    SpecimenGrains? grains;
    if (box is RenderRepaintBoundary && box.hasSize) {
      try {
        await WidgetsBinding.instance.endOfFrame;
        grains = await SpecimenGrains.capture(box, pixelRatio: 1.5);
      } catch (_) {}
    }
    if (!mounted) return;
    _takeGrains(
      grains ?? SpecimenGrains.disc(elementColor(widget.offering.element)),
    );
    _reading = false;
    setState(() {});
  }

  void _takeGrains(SpecimenGrains g) {
    _grains = g;
    _offer = _Specimen(g, seed: 3);
    var lo = double.infinity, hi = -double.infinity;
    for (final y in g.hy) {
      lo = math.min(lo, y);
      hi = math.max(hi, y);
    }
    final span = math.max(1.0, hi - lo);
    _yRank = Float32List.fromList([for (final y in g.hy) (y - lo) / span]);
    _feet = hi;
  }

  // ── clock ──────────────────────────────────────────────────────────

  void _enter(_Seg seg) {
    _seg = seg;
    _segT = 0;
    setState(() {});
  }

  void _show(int line) {
    if (_spoken.contains(line)) return;
    _spoken.add(line);
    setState(() {
      _stop = line;
      _stopAt = _clock;
    });
  }

  /// Where the offering stands, and how big: in the ring's light, and at
  /// the end, lower and smaller, under the map.
  Offset get _stand => Offset(_size.width * 0.5, _size.height * 0.6);
  double get _standSize => _size.height * 0.46;

  /// Where the vial stands at the end, and how big its chamber is.
  Offset get _vialAt => Offset(_size.width * 0.5, _size.height * 0.6);
  double get _vialRadius =>
      math.min(_size.height * 0.3, _size.width * 0.3).toDouble();

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    if (_size == Size.zero) return;
    _clock += dt;
    _segT += dt;
    switch (_seg) {
      case _Seg.offering:
        // It gathers once it has been read.
        if (_grains != null) _assembleT += dt;
        if (_assembleT >= _kAssemble + 0.6) _show(0);
      case _Seg.remade:
        if (_segT >= _kRemade) _show(1);
      case _Seg.sent:
        if (_segT >= _kSent) {
          _spawnClock = 0;
          _enter(_Seg.census);
        }
      case _Seg.census:
        _stepCensus(dt);
      case _Seg.last:
        _stepCensus(dt);
        if (_vialT >= _kVialSpeaks) _show(3);
      case _Seg.thanks:
        break;
      case _Seg.gone:
        _fadeOut = (_segT / 1.2).clamp(0.0, 1.0);
        if (_segT >= 1.25 && !_leaving) {
          _leaving = true;
          Navigator.of(context).pop(true);
        }
    }
    for (final w in _walkers) {
      w.step(dt);
    }
    if (_vial != null) _vialT += dt;
    _air.step(dt, _size);
    _frame.tick();
  }

  void _stepCensus(double dt) {
    final w = _size.width, h = _size.height;
    _spawnClock += dt;
    // Spaced so the whole census passes in about a minute, however big it
    // is; the credits share that minute.
    final n = math.max(1, _censusTotal);
    final gap = (_censusSpan / n).clamp(0.22, 2.4);
    if (_seg == _Seg.census) {
      while (_spawned < _census.length && _spawnClock >= _spawned * gap) {
        final lane = _spawned % 3;
        _walkers.add(_Walker(_census[_spawned], lane, w, h, _spawned));
        _spawned++;
      }
      final allOut = _censusRead && _spawned >= _census.length;
      final lastStart = _spawned * gap;
      // Not before the credits are nearly through, however small the
      // census: it walks in under the last of them.
      final due = math.max(lastStart + 1.5, _censusSpan - 4);
      if (allOut && _spawnClock >= due) {
        // Last, the vial it was sent to, under the last of the credits.
        final g = _grains;
        if (g != null) _vial = BloodbornVialField(g, pool: 560);
        _enter(_Seg.last);
      }
    }
    for (final walker in _walkers) {
      // Each leaves a few of its grains in the air, somewhere of its own.
      if (!walker.shed && walker.x < walker.shedAt) {
        walker.shed = true;
        walker.shedInto(_air);
      }
    }
    _walkers.removeWhere((x) => x.x < -w * 0.4);
  }

  double get _censusSpan => (_censusTotal * 0.45).clamp(36.0, 70.0).toDouble();

  void _onTapUp(TapUpDetails d) {
    final line = _stop;
    if (line != null) {
      if (_clock - _stopAt < 0.9) return;
      HapticFeedback.lightImpact();
      setState(() => _stop = null);
      switch (line) {
        case 0:
          _enter(_Seg.remade);
          context.sound(SoundCue.extractionDissolve, owner: this);
        case 1:
          _show(2);
        case 2:
          // Sent below, to the chamber: it drips away and is drawn down.
          _enter(_Seg.sent);
          context.sound(SoundCue.extractionDissolve, owner: this);
        case 3:
          _enter(_Seg.thanks);
          _show(4);
        case 4:
          _enter(_Seg.gone);
      }
      return;
    }
    // In the census, a tapped Alchemon comes apart and gathers back.
    if (_seg != _Seg.census && _seg != _Seg.last) return;
    for (final w in _walkers.reversed) {
      if (w.contains(d.localPosition)) {
        HapticFeedback.selectionClick();
        w.burst(_clock);
        return;
      }
    }
  }

  // ── drawing ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            _size = constraints.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onPanUpdate: (d) => _air.stir(d.localPosition, d.delta),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_grains == null) _readable(),
                  RepaintBoundary(
                    child: CustomPaint(painter: _FinalePainter(this)),
                  ),
                  _creditsLayer(),
                  _text(),
                  // Gone to black, at the very end.
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _frame,
                      builder: (context, _) => ColoredBox(
                        color: Colors.black.withValues(alpha: _fadeOut),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The offering's own sprite, drawn off the screen to be read into its
  /// grains once it has drawn. It is never seen: the offering is shown
  /// only as its grains.
  Widget _readable() {
    final size = _standSize;
    return Positioned(
      left: -size * 4,
      top: 0,
      width: size,
      height: size,
      child: IgnorePointer(
        child: NotificationListener<SpriteReadyNotification>(
          onNotification: (_) {
            unawaited(_read());
            return true;
          },
          child: RepaintBoundary(key: _readKey, child: _portrait(size)),
        ),
      ),
    );
  }

  Widget _portrait(double size) {
    final custom = widget.portrait;
    if (custom != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_read());
      });
      return custom(size);
    }
    final m = widget.offering;
    final sheet = m.spriteSheet;
    final v = m.spriteVisuals;
    if (sheet == null) return const SizedBox.shrink();
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
      costumes: v?.costumes,
      variantFaction: v?.variantFaction,
      elementType: v?.elementType,
    );
  }

  /// The credits, a block at a time across the census.
  Widget _creditsLayer() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _frame,
        builder: (context, _) {
          if (_seg != _Seg.census && _seg != _Seg.last) {
            return const SizedBox.shrink();
          }
          final span = _censusSpan;
          final each = span / _credits.length;
          final t = _spawnClock;
          final i = (t / each).floor();
          if (i >= _credits.length) return const SizedBox.shrink();
          final local = t - i * each;
          final alpha =
              _smooth(0, 0.9, local) * (1 - _smooth(each - 0.9, each, local));
          final (heading, names) = _credits[i];
          const ink = Color(0xFFEDE6D6);
          const brass = Color(0xFFE4C16A);
          return SafeArea(
            child: Align(
              alignment: const Alignment(0, -0.82),
              child: Opacity(
                opacity: alpha,
                child: heading.isEmpty
                    ? const ParticleTitle(darkBackdrop: true, scale: 0.75)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            heading.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: brass,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final name in names)
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.crimsonText(
                                fontSize: 22,
                                height: 1.4,
                                color: ink,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _text() {
    final line = _stop == null ? null : _lines[_stop!];
    const ink = Color(0xFFEDE6D6);
    const brass = Color(0xFFE4C16A);
    final body = line == null
        ? const SizedBox.shrink(key: ValueKey('none'))
        : Column(
            key: ValueKey(_stop),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                line.text,
                textAlign: TextAlign.center,
                style: GoogleFonts.crimsonText(
                  fontSize: 24,
                  height: 1.45,
                  color: line.brass ? brass : ink,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              _Delayed(
                delay: 1.1,
                child: Text(
                  line.hint,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: brass.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
            ],
          );
    // Above the offering; "Thank you for playing" alone in the middle.
    final alignment = _stop == 4 ? Alignment.center : const Alignment(0, -0.78);
    const width = 600.0;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Called by the painter.
  void _paint(Canvas canvas, Size size) {
    _paintRingLight(canvas);
    _paintAura(canvas);
    _paintOffering(canvas);
    for (final w in _walkers) {
      w.paint(canvas, _clock);
    }
    _paintVial(canvas);
    // The grains the census left in the air thin away at the very end.
    _air.paint(
      canvas,
      fade: switch (_seg) {
        _Seg.thanks => 1 - _smooth(0, 1.6, _segT),
        _Seg.gone => 0,
        _ => 1,
      },
    );
  }

  static final Paint _lightPaint = Paint();

  void _pool(Canvas canvas, Offset c, double rx, double ry, double a) {
    _lightPaint.shader = RadialGradient(
      colors: [
        _kRing.withValues(alpha: 0.42 * a),
        _kRing.withValues(alpha: 0.16 * a),
        _kRing.withValues(alpha: 0),
      ],
      stops: const [0, 0.45, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(rx, ry)
      ..drawCircle(Offset.zero, 1, _lightPaint)
      ..restore();
  }

  /// The ring's light on the dark the offering stands in: lit at the
  /// start, deepening as the blood drips into it, gone as the census
  /// begins.
  void _paintRingLight(Canvas canvas) {
    final a = switch (_seg) {
      _Seg.offering => _smooth(0, 2.0, _segT),
      _Seg.remade => 1.0 + 0.35 * _smooth(_kDripAt, _kDripAt + 3.0, _segT),
      // Going out as the pool is drawn down.
      _Seg.sent => 1.35 * (1 - _smooth(_kSinkAt, _kSent, _segT)),
      _ => 0.0,
    };
    if (a <= 0.01) return;
    _pool(
      canvas,
      _stand + Offset(0, _standSize * 0.32),
      _standSize * 1.1,
      _standSize * 0.55,
      a,
    );
  }

  /// Bloodborn's aura, in grains: a low red light where it stands and a
  /// few embers of blood rising round it -- once the blood has dripped
  /// off it, and again where it stops at the end.
  void _paintAura(Canvas canvas) {
    final double on;
    final Offset at;
    final double size;
    switch (_seg) {
      case _Seg.offering || _Seg.remade || _Seg.sent || _Seg.census:
        on = switch (_seg) {
          _Seg.remade => _smooth(_kRiseAt + 1.6, _kRemade, _segT),
          // Out as it starts to drip away.
          _Seg.sent => 1 - _smooth(0.3, 1.2, _segT),
          _ => 0,
        };
        at = _stand;
        size = _standSize;
      case _Seg.last || _Seg.thanks || _Seg.gone:
        // The vial has its own light.
        return;
    }
    if (on <= 0.01) return;
    _pool(
      canvas,
      at + Offset(0, size * 0.3),
      size * 0.6,
      size * 0.22,
      on * 0.8,
    );
    _embers.begin(math.max(1.6, size * 0.012));
    const n = 48;
    for (var i = 0; i < n; i++) {
      final ph = (i * 0.618) % 1;
      final u = (_clock * (0.18 + 0.1 * ((i * 0.37) % 1)) + ph) % 1;
      final side = ((i * 0.73) % 1) - 0.5;
      final x = at.dx + side * size * 0.8 + math.sin(_clock * 1.3 + i) * 3;
      final y = at.dy + size * 0.36 - u * size * 0.9;
      final c = Color.lerp(_kBloodDark, _kBlood, (i * 0.41) % 1)!;
      _embers.put(i, Offset(x, y), c, on * math.sin(math.pi * u) * 0.8);
    }
    _embers.flush(canvas);
  }

  static final Paint _glass = Paint();

  /// The vial it was sent to, sealed in its round chamber in the middle:
  /// dark glass with the red on its rim, the pool from the ring, and the new
  /// one half formed out of it, beating. Gone before the thanks.
  void _paintVial(Canvas canvas) {
    final v = _vial;
    if (v == null) return;
    final t = _vialT;
    final on =
        _smooth(0, 1.6, t) *
        (_seg == _Seg.thanks || _seg == _Seg.gone
            ? 1 - _smooth(0, 1.4, _segT)
            : 1);
    if (on <= 0.01) return;
    final c = _vialAt, r = _vialRadius;
    _glass.shader = RadialGradient(
      colors: [
        const Color(0xFF0A0204).withValues(alpha: on),
        const Color(0xFF050102).withValues(alpha: on),
        _kRing.withValues(alpha: 0.13 * on),
        _kRing.withValues(alpha: 0),
      ],
      stops: const [0, 0.9, 0.975, 1],
    ).createShader(Rect.fromCircle(center: c, radius: r * 1.05));
    canvas
      ..drawCircle(c, r * 1.05, _glass)
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    v.paintVessel(
      canvas,
      c,
      r * 0.98,
      progress: 0.55 * _smooth(0.6, 5.0, t),
      ready: 0.45,
      time: _clock,
      opacity: on,
    );
    canvas.restore();
  }

  /// Where grain [i] lies in the pool of blood at the offering's feet.
  Offset _poolSpot(_Specimen o, int i) {
    final feet = _stand + Offset(0, _feet);
    final a = o.angle[i];
    return feet +
        Offset(
          math.cos(a) * _standSize * 0.42 * o.reach[i],
          math.sin(a) * _standSize * 0.06 * o.reach[i],
        );
  }

  /// From the offering's middle to its feet, as read.
  double _feet = 0;

  /// Grain [i]'s place in the one reborn: bigger, from the same feet.
  Offset _rebornAt(SpecimenGrains g, int i, double breath) {
    final feet = _stand.dy + _feet;
    return Offset(
      _stand.dx + g.hx[i] * _kReborn,
      feet + (g.hy[i] - _feet) * _kReborn + breath,
    );
  }

  /// The offering in its grains, before the census takes it: gathering out
  /// of the ring's light and held; then sacrificed -- dyed with blood and
  /// dripping away, all of it, into a pool at its feet -- and a new one,
  /// stronger, rising out of the blood.
  void _paintOffering(Canvas canvas) {
    final o = _offer;
    final g = _grains;
    if (o == null || g == null) return;
    if (_seg != _Seg.offering && _seg != _Seg.remade && _seg != _Seg.sent) {
      return;
    }
    final centre = _stand;
    final light = centre + Offset(0, _standSize * 0.34);
    o.begin(g.step * 1.15);
    _drops.begin(g.step * 1.0);
    var k = 0;
    final remade = _seg == _Seg.remade;
    final t = remade ? _segT : 0.0;
    final gravity = _size.height * 1.5;
    for (var i = 0; i < g.length; i++) {
      // Alive where it stands: a breath, never still.
      final breath = math.sin(_clock * 1.7 + g.hx[i] * 0.08) * 0.6;
      final home = centre + Offset(g.hx[i], g.hy[i] + breath);
      final r = o.rnd[i];
      final rank = _yRank[i];
      final own = g.tones[g.tone[i]];
      final blood = Color.lerp(_kBloodDark, _kBlood, o.rnd2[i])!;
      var p = home;
      var col = own;
      var alpha = 1.0;
      if (_seg == _Seg.sent) {
        // Sent below: the one reborn dripping away, its own colours running
        // with blood, into the pool; then the pool drawn down out of sight.
        final t = _segT;
        final reborn = _rebornAt(g, i, breath);
        final stronger = Color.lerp(own, const Color(0xFFFFFFFF), 0.08)!;
        final liquid = Color.lerp(stronger, blood, 0.45)!;
        final pool = _poolSpot(o, i);
        final release = 0.5 + 2.0 * (1 - rank) * 0.8 + 0.35 * r;
        if (t < release) {
          p = reborn;
          col = Color.lerp(
            stronger,
            liquid,
            _smooth(release - 0.5, release, t),
          )!;
        } else {
          final a = t - release;
          final fall = math.sqrt(
            2 * math.max(1.0, pool.dy - reborn.dy) / gravity,
          );
          if (a < fall) {
            final e = a / fall;
            final y = reborn.dy + 0.5 * gravity * a * a;
            final x = reborn.dx + (pool.dx - reborn.dx) * _smooth(0, 1, e);
            p = Offset(x, y);
            final v = gravity * a;
            for (var s = 1; s < 3; s++) {
              _drops.put(
                k++,
                Offset(x, y - s * v * 0.014),
                liquid,
                0.8 - 0.25 * s,
              );
            }
            col = liquid;
          } else {
            final sink = _smooth(
              _kSinkAt + 0.5 * r,
              _kSinkAt + 0.5 * r + 0.9,
              t,
            );
            p = pool + Offset(0, sink * _standSize * 0.12);
            col = Color.lerp(liquid, _kBloodDark, _smooth(0, 1.0, a - fall))!;
            alpha = 1 - sink;
          }
        }
        o.put(i, p, col, alpha);
        continue;
      }
      if (!remade) {
        // Up out of the ring's light, the lowest first.
        final u = _smoother(
          ((_assembleT - 0.15 - 1.2 * (1 - rank) * 0.75 - 0.35 * r) / 1.1)
              .clamp(0.0, 1.0),
        );
        if (u < 1) {
          final a = o.angle[i];
          final from =
              light +
              Offset(
                math.cos(a) * _standSize * 0.9 * o.reach[i],
                math.sin(a) * _standSize * 0.22 * o.reach[i],
              );
          final d = home - from;
          final curl = 0.22 * math.sin(math.pi * u) * (o.rnd2[i] - 0.5);
          p = from + d * u + Offset(-d.dy, d.dx) * curl;
          alpha = _smooth(0, 0.25, u);
        }
        o.put(i, p, col, alpha);
        continue;
      }
      final pool = _poolSpot(o, i);
      // Dyed: the blood running down over it from the top.
      final dye = _smooth(0.2 + 0.7 * rank, 0.6 + 0.7 * rank, t);
      // Sacrificed: it drips away, the lowest first, into the pool.
      final release = _kDripAt + _kDripSpan * (1 - rank) * 0.8 + 0.45 * r;
      // Reborn: up out of the blood, the lowest first.
      final rise = _kRiseAt + _kRiseSpan * (1 - rank) * 0.75 + 0.35 * r;
      final reborn = _rebornAt(g, i, breath);
      if (t < release) {
        p = home;
        col = Color.lerp(own, blood, dye)!;
      } else if (t < rise) {
        final a = t - release;
        final fall = math.sqrt(2 * math.max(1.0, pool.dy - home.dy) / gravity);
        if (a < fall) {
          // Falling, a drop with its short run behind it.
          final e = a / fall;
          final y = home.dy + 0.5 * gravity * a * a;
          final x = home.dx + (pool.dx - home.dx) * _smooth(0, 1, e);
          p = Offset(x, y);
          final v = gravity * a;
          for (var s = 1; s < 3; s++) {
            _drops.put(
              k++,
              Offset(x, y - s * v * 0.014),
              blood,
              0.8 - 0.25 * s,
            );
          }
        } else {
          // In the pool, darkening, beating faintly.
          p = pool + Offset(0, math.sin(_clock * 1.6 + r * 6) * 0.4);
        }
        col = Color.lerp(blood, _kBloodDark, _smooth(0, 1.4, a - fall))!;
      } else {
        // Rising out of the blood into the new one, its own colours coming
        // back as it arrives -- and brighter than they were.
        final u = _smoother(((t - rise) / 1.1).clamp(0.0, 1.0));
        final d = reborn - pool;
        final curl = 0.2 * math.sin(math.pi * u) * (o.rnd2[i] - 0.5);
        p = pool + d * u + Offset(-d.dy, d.dx) * curl;
        final stronger = Color.lerp(own, const Color(0xFFFFFFFF), 0.08)!;
        col = Color.lerp(_kBloodDark, stronger, _smooth(0.35, 1, u))!;
      }
      o.put(i, p, col, alpha);
    }
    _drops.flush(canvas);
    o.flush(canvas);
  }
}

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _smoother(double t) => t * t * t * (t * (t * 6 - 15) + 10);

class _Frame extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _FinalePainter extends CustomPainter {
  _FinalePainter(this.state) : super(repaint: state._frame);
  final _BloodFinalePageState state;

  @override
  void paint(Canvas canvas, Size size) => state._paint(canvas, size);

  @override
  bool shouldRepaint(_FinalePainter old) => old.state != state;
}

/// A small solid grain, the census's and the offering's.
final ui.Image _grainDot = () {
  const d = 8.0;
  final rec = ui.PictureRecorder();
  Canvas(rec).drawCircle(
    const Offset(d / 2, d / 2),
    d / 2,
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final p = rec.endRecording();
  final image = p.toImageSync(d.toInt(), d.toInt());
  p.dispose();
  return image;
}();

/// Grains drawn in their own colours, one atlas call a frame; with a
/// random share, a direction and a reach per grain for the motion.
class _Specimen {
  _Specimen(SpecimenGrains g, {int seed = 0}) : this._(g.length, seed);
  _Specimen.capacity(int n) : this._(n, 1);

  _Specimen._(int n, int seed)
    : rnd = Float32List(n),
      rnd2 = Float32List(n),
      angle = Float32List(n),
      reach = Float32List(n),
      _xf = Float32List(n * 4),
      _src = Float32List(n * 4),
      _col = Int32List(n) {
    final rng = math.Random(seed);
    for (var i = 0; i < n; i++) {
      rnd[i] = rng.nextDouble();
      rnd2[i] = rng.nextDouble();
      angle[i] = rng.nextDouble() * 2 * math.pi;
      reach[i] = math.sqrt(rng.nextDouble());
      _src[i * 4 + 2] = 8;
      _src[i * 4 + 3] = 8;
    }
  }

  final Float32List rnd, rnd2, angle, reach;
  final Float32List _xf, _src;
  final Int32List _col;
  int _n = 0;
  double _size = 1;

  static final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  void put(int i, Offset p, Color c, double alpha) {
    if (alpha <= 0.02 || _n >= _col.length) return;
    final j = _n * 4;
    final s = _size / 8;
    _xf[j] = s;
    _xf[j + 1] = 0;
    _xf[j + 2] = p.dx - _size / 2;
    _xf[j + 3] = p.dy - _size / 2;
    _col[_n] =
        (((c.a * alpha) * 255).round().clamp(0, 255) << 24) |
        ((c.r * 255).round() << 16) |
        ((c.g * 255).round() << 8) |
        (c.b * 255).round();
    _n++;
  }

  void begin(double size) {
    _n = 0;
    _size = size;
  }

  void flush(Canvas canvas) {
    if (_n == 0) return;
    canvas.drawRawAtlas(
      _grainDot,
      Float32List.sublistView(_xf, 0, _n * 4),
      Float32List.sublistView(_src, 0, _n * 4),
      Int32List.sublistView(_col, 0, _n),
      BlendMode.modulate,
      null,
      _paint,
    );
    _n = 0;
  }
}

/// One of the census, walking (drifting) across in its lane.
class _Walker {
  _Walker(this.entry, this.lane, double w, double h, this.index)
    : x = w + w * 0.15,
      _specimen = _Specimen(entry.grains, seed: index + 7) {
    final depth = _kDepth[lane];
    // Each leaves its grains somewhere of its own along the way.
    shedAt = w * (0.18 + 0.64 * math.Random(index * 13 + 1).nextDouble());
    scale = h * 0.22 * depth / CensusReader.readHeight;
    feet = h * _kFeet[lane];
    speed = (w * 1.3) / 10.0 * depth;
    final g = entry.grains;
    var x0 = 0.0, x1 = 0.0, y0 = 0.0, y1 = 0.0;
    for (var i = 0; i < g.length; i++) {
      x0 = math.min(x0, g.hx[i]);
      x1 = math.max(x1, g.hx[i]);
      y0 = math.min(y0, g.hy[i]);
      y1 = math.max(y1, g.hy[i]);
    }
    _bounds = Rect.fromLTRB(x0, y0, x1, y1);
  }

  static const _kDepth = [0.62, 0.8, 1.0];
  static const _kFeet = [0.56, 0.7, 0.88];

  final CensusEntry entry;
  final int lane;
  final int index;
  late final double scale;
  late final double feet;
  late final double speed;
  late final Rect _bounds;
  late final double shedAt;
  final _Specimen _specimen;
  double x;
  bool shed = false;
  double _walked = 0;
  double? _burstAt;

  void step(double dt) {
    _walked += dt;
    x -= speed * dt;
  }

  Offset get _origin => Offset(x, feet - _bounds.bottom * scale);

  /// Whether [p] (on the screen) is on it.
  bool contains(Offset p) {
    final o = _origin;
    final r = Rect.fromLTRB(
      o.dx + _bounds.left * scale,
      o.dy + _bounds.top * scale,
      o.dx + _bounds.right * scale,
      o.dy + _bounds.bottom * scale,
    ).inflate(6);
    return r.contains(p);
  }

  /// Comes apart into its grains and gathers back, from [clock] on.
  void burst(double clock) {
    final at = _burstAt;
    if (at != null && clock - at < _kBurst) return;
    _burstAt = clock;
  }

  void shedInto(RealmAir air) {
    final g = entry.grains;
    final rng = math.Random(index * 31 + 5);
    final o = _origin;
    for (var k = 0; k < 14; k++) {
      final i = rng.nextInt(g.length);
      final c = g.tones[g.tone[i]];
      air.add(
        o.dx + g.hx[i] * scale,
        o.dy + g.hy[i] * scale,
        -speed * 0.3,
        -12 - 20 * rng.nextDouble(),
        c.toARGB32() & 0xFFFFFF,
        0,
      );
    }
  }

  void paint(Canvas canvas, double clock) {
    final g = entry.grains;
    final o = _origin;
    final depth = _kDepth[lane];
    // The back lanes dimmer: further into the dark.
    final alpha = 0.45 + 0.55 * (depth - 0.62) / 0.38;
    final bob = math.sin(_walked * 5 + index) * 1.5 * depth;
    final at = _burstAt;
    final u = at == null ? 1.0 : ((clock - at) / _kBurst).clamp(0.0, 1.0);
    final burst = u < 1 ? math.sin(math.pi * _smoother(u)) : 0.0;
    final reach = (_bounds.height * scale) * 0.55;
    final s = _specimen;
    s.begin(math.max(1.2, g.step * scale * 1.2));
    for (var i = 0; i < g.length; i++) {
      var p = Offset(o.dx + g.hx[i] * scale, o.dy + g.hy[i] * scale + bob);
      var c = g.tones[g.tone[i]];
      if (burst > 0) {
        // Out on a current that turns as it goes, and back.
        final a = s.angle[i] + 1.6 * u;
        final d = reach * s.reach[i] * burst;
        p += Offset(math.cos(a) * d, math.sin(a) * d * 0.8);
        c = Color.lerp(c, const Color(0xFFFFFFFF), 0.25 * burst)!;
      }
      s.put(i, p, c, alpha);
    }
    s.flush(canvas);
  }
}

/// [child], faded up [delay] seconds after it is first shown.
class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.child});
  final double delay;
  final Widget child;

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _shown ? 1 : 0,
    duration: const Duration(milliseconds: 700),
    child: widget.child,
  );
}
