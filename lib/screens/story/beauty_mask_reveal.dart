// lib/screens/story/beauty_mask_reveal.dart
//
// BEAUTY OBSTRUCTS REALITY. The first descent onto any planet lands, instead,
// in the Valley: the real one, drawn in code, its wind moving, the party
// standing in it. Then it stops. The wind stops, the light stops, and a few
// grains slip at one place in the sky -- and the Valley sifts away, and
// behind it is the Sky, and behind that the Swamp, and every other realm on
// the wild map in turn, each held a little less and falling a little
// faster, until the last one goes and nothing is behind it but the planet.
//
// The party stays standing through all of it (the creatures were real; the
// realms were not) and walks onto the planet's floor where the room has
// them. Some of every realm's grains do not fall: they hang in the planet's
// dark as lights of the colours they were, and gather into the realms'
// circles on the wild map -- the realms shown as what they are, things made
// -- and the circles come apart one by one.
//
// The lines are the campaign's (docs/campaign_story_canon.md: kept word for
// word): the first descent's own three, and the "Trees and valleys are
// absent" passage written for this moment and never reachable until now.
// Each waits for a tap, as the opening's quotes do; the motion between them
// plays on its own.
//
// Cheap, for its length: the planet below is frozen throughout. Only the
// Valley is ever live; every other realm is pictured once while the descent
// still covers the screen (offstage, through the field's own render), and
// falls as that picture (realm_sift.dart). The wild map is the map's own
// field, laid out while hidden.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/scenes/dunes/dunes_scene.dart';
import 'package:alchemons/models/scenes/geode/geode_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/tidal/tidal_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/widgets/fx/realm_sift.dart';
import 'package:alchemons/widgets/wilderness/wild_map.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The realms the alchemist made, in the order they fall: the Valley first,
/// then every other realm on the wild map.
List<(String, SceneDefinition)> maskedRealms() => [
  ('valley', valleySceneCorrected),
  ('sky', skyScene),
  ('swamp', swampScene),
  ('volcano', volcanoScene),
  ('arcane', arcaneScene),
  ('dunes', dunesScene),
  ('geode', geodeScene),
  ('tidal', tidalScene),
];

/// The party the cinematic stands in the realms, drawn by whoever owns
/// them (the dungeon, which takes them over when it ends).
abstract interface class RevealParty {
  int get count;

  /// Where creature [i] stands on the screen once the planet has them.
  Offset restAt(int i);

  /// The scale they are drawn at there.
  double get zoom;
  bool facesRight(int i);

  /// From creature [i]'s middle to its feet, at [zoom] 1.
  double halfHeight(int i);

  /// Draws creature [i] centred on the canvas, at [zoom] 1.
  void paint(Canvas canvas, int i, {required bool faceRight, required double time});

  /// Moves their own animations on.
  void step(double dt);
}

class BeautyMaskReveal extends StatefulWidget {
  const BeautyMaskReveal({
    super.key,
    required this.onComplete,
    this.onReady,
    this.begin,
    this.party,
    this.pictures,
  });

  /// The last line has been read and the planet's light has risen.
  final Future<void> Function() onComplete;

  /// Every realm is pictured and the Valley is up: the descent may show it.
  final VoidCallback? onReady;

  /// Plays once this is true (the descent has shown the page); without it,
  /// as soon as the Valley is up.
  final ValueListenable<bool>? begin;
  final RevealParty? party;

  /// Every realm already pictured, the Valley too (previews): nothing is
  /// made, and the Valley is its picture instead of live.
  final List<RealmPicture>? pictures;

  @override
  State<BeautyMaskReveal> createState() => _BeautyMaskRevealState();
}

/// One line of the story, waiting for a tap.
class _Line {
  const _Line({
    this.title,
    this.caption,
    required this.text,
    this.more,
    this.hint = 'CONTINUE',
  });

  /// Set above the line in the dialogs' monospace capitals.
  final String? title;

  /// Set above the line, small, in the voice's serif.
  final String? caption;
  final String text;

  /// A second paragraph, smaller.
  final String? more;
  final String hint;
}

const _lines = [
  _Line(
    title: 'Beauty Obstructs Reality',
    text: 'The valley is here, where it cannot be.',
    hint: 'LOOK CLOSER',
  ),
  _Line(
    text: 'Trees and valleys are absent in this universe.',
    more:
        'It is nothing but desolation and precariousness. Eventually reality '
        "seeps through the mind's defense. Why would I create such a world.",
  ),
  _Line(title: 'AM I DREAMING?', text: 'No, I am finally awake.'),
  _Line(
    caption: 'A memory speaks',
    text:
        'You did not make the valley to hide the world from danger. You made '
        'it to hide your work from yourself.',
  ),
];

enum _Seg { landing, still, masks, bare, map, awake, rise }

/// The hour every realm is lit at: late gold, the mask at its loveliest.
const double _kHour = 18.4;

/// How long the Valley is only itself before the first line.
const double _kLanding = 4.5;

/// After LOOK CLOSER: the wind still moving, then all of it stopping, then
/// the stillness held before the first grain slips.
const double _kStopAt = 1.4, _kSlipAt = 3.8;

/// Each realm: how long it is seen whole before it starts to go (the
/// Valley's is the stillness), and how long its front takes to cross it.
/// Each is held less and falls faster than the last; the last is slower
/// again, since nothing comes after it.
const _kHold = [0.0, 2.4, 2.0, 1.7, 1.4, 1.1, 0.9, 0.8];
const _kFront = [3.4, 2.8, 2.4, 2.1, 1.8, 1.6, 1.4, 2.8];

/// Which way each realm's grains are carried: all the same way within a
/// realm, turning between them.
const _kWind = [1.0, -0.8, 1.0, 0.7, -1.0, 0.9, -0.7, 0.6];

/// The party walking onto the planet's floor; the planet's light rising.
const double _kGlide = 2.0, _kRise = 2.4;

/// How dark the planet is under the cinematic until its light rises, and
/// under the map (darker, so the map is not read over the room).
const double _kVeil = 0.62, _kVeilMap = 0.84;

/// The map: its grains gathering, then the circles coming apart one by one,
/// then the dust going out.
const double _kGatherAt = 0.4, _kApartAt = 5.2, _kApartEach = 0.9;
const double _kMapOut = 1.6;

/// The realms' order of coming apart on the map, and the circle each
/// realm's grains are drawn into ('arcane': the rift in the middle).
const _kApartOrder = ['valley', 'sky', 'volcano', 'swamp', 'arcane'];

class _BeautyMaskRevealState extends State<BeautyMaskReveal>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = _Frame();
  final _realms = maskedRealms();

  Size _size = Size.zero;
  double _ratio = 1;
  bool _reduced = false;
  bool _preparing = false;

  /// The Valley, live, until it is pictured.
  SceneGame? _valley;
  bool _valleyUp = false;
  bool _valleyStopped = false;

  /// Fading the live Valley straight to the planet (reduced motion).
  double _valleyFade = 1;

  /// The realm being pictured, offstage.
  SceneGame? _prepGame;
  final Map<String, RealmPicture> _pics = {};
  bool _prepared = false;

  WildMapField? _map;
  final _air = RealmAir(3600);
  late final List<RealmSift?> _sifts = List.filled(_realms.length, null);
  late final List<double> _start = List.filled(_realms.length, 0);
  late final List<double> _seenAt = List.filled(_realms.length, -1);

  bool _playing = false;
  Duration _last = Duration.zero;
  double _clock = 0;
  _Seg _seg = _Seg.landing;
  double _segT = 0;
  double _masksEnd = 0;
  double _mapAlpha = 0;
  bool _gathered = false;
  int _apart = 0;

  /// The line showing, and when it showed; whether one has been read.
  int? _stop;
  double _stopAt = 0;
  final Set<int> _spoken = {};

  bool _saving = false;
  String? _error;

  /// The planet's dark, eased; the pool of dark behind the words, eased,
  /// and where the words last were.
  double _veil = _kVeil;
  double _pool = 0;
  Rect? _poolRect;
  final GlobalKey _textKey = GlobalKey();
  final GlobalKey _stageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    var at = 0.0;
    for (var k = 0; k < _realms.length; k++) {
      at += _kHold[k];
      _start[k] = at;
      at += _kFront[k];
    }
    _masksEnd = at + 1.4;
    final given = widget.pictures;
    if (given != null) {
      for (final p in given) {
        _pics[p.id] = p;
      }
    }
    widget.begin?.addListener(_maybeBegin);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reduced = media.disableAnimations;
    _ratio = math.min(media.devicePixelRatio, 1.5);
  }

  @override
  void dispose() {
    widget.begin?.removeListener(_maybeBegin);
    _ticker.dispose();
    _frame.dispose();
    for (final p in _pics.values) {
      p.dispose();
    }
    for (final sift in _sifts) {
      sift?.dispose();
    }
    _air.dispose();
    _map?.dispose();
    super.dispose();
  }

  // ── Getting ready, under the descent ───────────────────────────────

  Future<void> _prepare() async {
    if (_preparing) return;
    _preparing = true;
    final live = widget.pictures == null;
    if (live) {
      final valley = SceneGame(scene: valleySceneCorrected)
        ..fieldHourOverride = _kHour
        ..panDrift = 7
        ..pauseEngine();
      setState(() => _valley = valley);
      await _settle(valley);
      if (!mounted) return;
      _valleyUp = true;
      _maybeBegin();
    }
    _map = WildMapField()
      ..slots = kWildCoreSlots
      ..arcane = true
      ..layout(_size)
      ..settle(gather: true);
    await WidgetsBinding.instance.endOfFrame;
    for (final (id, scene) in _realms) {
      if (!mounted) return;
      if (_pics.containsKey(id) || id == 'valley' && live) continue;
      final game = SceneGame(scene: scene)
        ..fieldHourOverride = _kHour
        ..pauseEngine();
      setState(() => _prepGame = game);
      await _settle(game);
      if (!mounted) return;
      final picture = await RealmPicture.record(id, _size, _ratio, game.render);
      if (!mounted) {
        picture.dispose();
        return;
      }
      _pics[id] = picture;
      setState(() => _prepGame = null);
      await WidgetsBinding.instance.endOfFrame;
    }
    _prepared = true;
    widget.onReady?.call();
    _maybeBegin();
  }

  /// Loads [game] and steps it still until its world and camera are laid
  /// out, then a moment on, so its light and grass are at rest.
  Future<void> _settle(SceneGame game) async {
    try {
      await game.loaded.timeout(const Duration(seconds: 8));
    } catch (_) {}
    for (var i = 0; i < 2; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      game.stepEngine(stepTime: 0);
    }
    for (var i = 0; i < 6; i++) {
      game.update(1 / 30);
    }
  }

  void _maybeBegin() {
    if (_playing || !mounted) return;
    if (!(widget.begin?.value ?? true)) return;
    final up = widget.pictures == null ? _valleyUp : _pics['valley'] != null;
    if (!up) return;
    _playing = true;
    _valley?.resumeEngine();
    _ticker.start();
  }

  // ── The clock ──────────────────────────────────────────────────────

  void _enter(_Seg seg) {
    _seg = seg;
    _segT = 0;
  }

  void _show(int line) {
    if (_spoken.contains(line)) return;
    _spoken.add(line);
    setState(() {
      _stop = line;
      _stopAt = _clock;
    });
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    _clock += dt;
    _segT += dt;
    widget.party?.step(dt);

    switch (_seg) {
      case _Seg.landing:
        if (_segT >= _kLanding) _show(0);
      case _Seg.still:
        if (_reduced) {
          _valleyFade = 1 - (_segT / 0.6).clamp(0.0, 1.0);
          setState(() {});
          if (_segT >= 0.6) {
            setState(() => _valley = null);
            _enter(_Seg.bare);
          }
          break;
        }
        if (!_valleyStopped && _segT >= _kStopAt) _stopValley();
        if (_pics['valley'] != null &&
            _valley == null &&
            _prepared &&
            _segT >= _kSlipAt) {
          _enter(_Seg.masks);
        }
      case _Seg.masks:
        _stepMasks();
        if (_segT >= _masksEnd) {
          _enter(_Seg.bare);
          _dropPictures();
        }
      case _Seg.bare:
        if (_segT >= _kGlide + 0.8) _show(1);
      case _Seg.map:
        _stepMap(dt);
      case _Seg.awake:
        break;
      case _Seg.rise:
        if (_segT >= _kRise && !_saving && _error == null) {
          unawaited(_finish());
        }
    }
    if (_seg.index >= _Seg.masks.index) _air.step(dt, _size);
    final veil = _seg == _Seg.map ? _kVeilMap : _kVeil;
    _veil += (veil - _veil) * math.min(1.0, dt / 0.8);
    final pool = _stop != null || _error != null ? 1.0 : 0.0;
    _pool += (pool - _pool) * math.min(1.0, dt / 0.35);
    _frame.tick();
  }

  /// The wind stops and the light stops: the Valley, pictured, is what
  /// sifts.
  Future<void> _stopValley() async {
    _valleyStopped = true;
    final valley = _valley;
    if (valley == null) return;
    valley.pauseEngine();
    final picture = await RealmPicture.record(
      'valley',
      _size,
      _ratio,
      valley.render,
    );
    if (!mounted) {
      picture.dispose();
      return;
    }
    _pics['valley'] = picture;
    _seenAt[0] = _clock;
    setState(() => _valley = null);
  }

  void _stepMasks() {
    final t = _segT;
    for (var k = 0; k < _realms.length; k++) {
      if (t < _start[k]) break;
      var sift = _sifts[k];
      if (sift == null) {
        final picture = _pics[_realms[k].$1];
        if (picture == null) continue;
        // The Valley slips high in its sky; each after it from somewhere
        // else along the top, so no two go the same way.
        final from = k == 0
            ? Offset(_size.width * 0.64, _size.height * 0.34)
            : Offset(
                _size.width * (0.2 + 0.6 * ((k * 0.618) % 1)),
                _size.height * (0.05 + 0.2 * ((k * 0.382) % 1)),
              );
        sift = _sifts[k] = RealmSift(
          picture: picture,
          size: _size,
          from: from,
          frontTime: _kFront[k],
          wind: _kWind[k],
          seed: 31 + k,
        );
        if (k + 1 < _realms.length) _seenAt[k + 1] = _clock;
        if (_seenAt[k] < 0) _seenAt[k] = _clock;
        context.sound(
          SoundCue.extractionDissolve,
          owner: this,
          speed: 1 + 0.05 * k,
        );
      }
      sift.handOver(t - _start[k], _air, k);
    }
  }

  /// The pictures the masks fell as are no longer drawn.
  void _dropPictures() {
    for (final p in _pics.values) {
      p.dispose();
    }
    _pics.clear();
    for (final sift in _sifts) {
      sift?.dispose();
    }
    _sifts.fillRange(0, _sifts.length, null);
  }

  void _stepMap(double dt) {
    final map = _map;
    if (map == null) {
      _enter(_Seg.awake);
      _show(2);
      return;
    }
    map.step(dt);
    final t = _segT;
    final apartEnd = _kApartAt + _kApartOrder.length * _kApartEach + 1.6;
    if (t < apartEnd) {
      _mapAlpha = (t / 1.2).clamp(0.0, 1.0);
    } else {
      _mapAlpha = 1 - ((t - apartEnd) / _kMapOut).clamp(0.0, 1.0);
    }
    if (!_gathered && t >= _kGatherAt) {
      _gathered = true;
      map.ready = _kApartOrder.toSet();
      for (var k = 0; k < _realms.length; k++) {
        final circle = _circleFor(_realms[k].$1);
        _air.gather(k, _airClock, (rng) {
          final r = circle.width / 2 * 0.75 * math.sqrt(rng.nextDouble());
          final a = rng.nextDouble() * 2 * math.pi;
          return circle.center + Offset(math.cos(a) * r, math.sin(a) * r);
        });
      }
    }
    while (_apart < _kApartOrder.length &&
        t >= _kApartAt + _apart * _kApartEach) {
      map.ready = _kApartOrder.skip(_apart + 1).toSet();
      _apart++;
    }
    if (t >= apartEnd + _kMapOut) {
      _enter(_Seg.awake);
      _show(2);
    }
  }

  /// The air's own clock, which runs from the first realm's fall.
  double get _airClock => _air.clock;

  Rect _circleFor(String id) {
    final map = _map!;
    for (final r in WildRealm.values) {
      if (r.sceneId == id && map.shows(r)) return map.circleOf(r);
    }
    return map.riftRect;
  }

  void _onTap() {
    if (_error != null) {
      unawaited(_finish());
      return;
    }
    final line = _stop;
    if (line == null || _clock - _stopAt < 0.9) return;
    HapticFeedback.lightImpact();
    setState(() => _stop = null);
    switch (line) {
      case 0:
        _enter(_Seg.still);
      case 1:
        if (_reduced) {
          _enter(_Seg.awake);
          _show(2);
        } else {
          _enter(_Seg.map);
        }
      case 2:
        _show(3);
      case 3:
        _enter(_Seg.rise);
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this memory. Tap to retry.';
        });
      }
    }
  }

  // ── Drawing ────────────────────────────────────────────────────────

  /// How far the party has walked onto the planet's floor (0 still in the
  /// realms, 1 where the room has them).
  double get _glide => switch (_seg) {
    _Seg.landing || _Seg.still || _Seg.masks => 0,
    _Seg.bare => _smoother((_segT / _kGlide).clamp(0.0, 1.0)),
    _ => 1,
  };

  /// How much of the planet's light has risen.
  double get _risen =>
      _seg == _Seg.rise ? _smoother((_segT / _kRise).clamp(0.0, 1.0)) : 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: _stage(),
      ),
    );
  }

  Widget _stage() {
    return LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_size != size) {
            final first = _size == Size.zero;
            _size = size;
            if (first) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) unawaited(_prepare());
              });
            }
          }
          final valley = _valley;
          final prep = _prepGame;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: Stack(
              key: _stageKey,
              fit: StackFit.expand,
              children: [
                // The planet, dark under it all until its light rises.
                AnimatedBuilder(
                  animation: _frame,
                  builder: (context, _) => ColoredBox(
                    color: Colors.black.withValues(
                      alpha: _veil * (1 - _risen),
                    ),
                  ),
                ),
                if (prep != null)
                  Offstage(
                    child: GameWidget(key: ObjectKey(prep), game: prep),
                  ),
                if (valley != null)
                  Opacity(
                    opacity: _valleyFade,
                    child: RepaintBoundary(
                      child: GameWidget(key: ObjectKey(valley), game: valley),
                    ),
                  ),
                RepaintBoundary(
                  child: CustomPaint(painter: _RevealPainter(this)),
                ),
                _text(),
              ],
            ),
          );
        },
    );
  }

  /// Where the words go: high over the Valley, above the party standing in
  /// it; once the party is on the planet's floor, to the side away from
  /// them.
  (Alignment, double) _textPlace() {
    final party = widget.party;
    final w = _size.width;
    if (_seg.index <= _Seg.masks.index || party == null || party.count == 0) {
      return (const Alignment(0, -0.5), 560);
    }
    var x = 0.0;
    for (var i = 0; i < party.count; i++) {
      x += party.restAt(i).dx;
    }
    x /= party.count;
    final side = x < w / 2 ? 0.55 : -0.55;
    return (Alignment(side, -0.1), math.min(520, w * 0.48));
  }

  Widget _text() {
    final line = _stop == null ? null : _lines[_stop!];
    const ink = Color(0xFFEDE6D6);
    const brass = Color(0xFFE4C16A);
    final error = _error;
    Widget body;
    if (error != null) {
      body = Text(
        error,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFE8A25A), fontSize: 14),
      );
    } else if (line == null) {
      body = const SizedBox.shrink(key: ValueKey('none'));
    } else {
      body = Column(
        key: ValueKey(_stop),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (line.title != null) ...[
            Text(
              line.title!.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: brass,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (line.caption != null) ...[
            Text(
              line.caption!,
              textAlign: TextAlign.center,
              style: GoogleFonts.crimsonText(
                fontSize: 15,
                color: brass.withValues(alpha: 0.85),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            line.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.crimsonText(
              fontSize: 22,
              height: 1.45,
              color: ink,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (line.more != null) ...[
            const SizedBox(height: 10),
            Text(
              line.more!,
              textAlign: TextAlign.center,
              style: GoogleFonts.crimsonText(
                fontSize: 17,
                height: 1.5,
                color: ink.withValues(alpha: 0.82),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // The way on, once the line has had a moment to be read.
          _DelayedHint(label: line.hint, color: brass),
        ],
      );
    }
    final (alignment, width) = _textPlace();
    return IgnorePointer(
      child: SafeArea(
        child: AnimatedAlign(
          alignment: alignment,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Padding(
              key: _textKey,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
  void _paintScene(Canvas canvas, Size size) {
    if (_seg.index <= _Seg.masks.index) _paintRealms(canvas, size);
    _paintParty(canvas, size);
    final map = _map;
    if (map != null && _seg == _Seg.map && _mapAlpha > 0.004) {
      if (_mapAlpha < 0.999) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Colors.white.withValues(alpha: _mapAlpha),
        );
        map.paint(canvas);
        canvas.restore();
      } else {
        map.paint(canvas);
      }
    }
    _air.paint(canvas, fade: 1 - _risen);
    _paintPool(canvas);
  }

  static final Paint _poolPaint = Paint();

  /// A soft pool of dark behind the words, so they read over the brightest
  /// realm: an ellipse that thins to nothing, never a box.
  void _paintPool(Canvas canvas) {
    final text = _textKey.currentContext?.findRenderObject();
    final stage = _stageKey.currentContext?.findRenderObject();
    if (text is RenderBox && stage is RenderBox && text.hasSize) {
      final at = text.localToGlobal(Offset.zero, ancestor: stage);
      if (text.size.height > 4) _poolRect = at & text.size;
    }
    final rect = _poolRect;
    if (rect == null || _pool <= 0.01) return;
    final rx = rect.width * 0.62 + 30, ry = rect.height * 0.62 + 34;
    _poolPaint.shader = RadialGradient(
      colors: [
        Colors.black.withValues(alpha: 0.58 * _pool),
        Colors.black.withValues(alpha: 0.34 * _pool),
        Colors.black.withValues(alpha: 0),
      ],
      stops: const [0, 0.5, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..scale(rx, ry)
      ..drawCircle(Offset.zero, 1, _poolPaint)
      ..restore();
  }

  /// A realm's picture grows very slowly from the moment it is seen.
  void _zoomFor(Canvas canvas, Size size, int k) {
    final seen = _seenAt[k];
    if (seen < 0) return;
    final z = math.min(1.07, 1 + 0.008 * (_clock - seen));
    final c = size.center(Offset.zero);
    canvas
      ..translate(c.dx, c.dy)
      ..scale(z)
      ..translate(-c.dx, -c.dy);
  }

  void _paintRealms(Canvas canvas, Size size) {
    if (_valley != null) return;
    if (_seg != _Seg.masks) {
      // Pictured and still, before the first grain slips.
      final valley = _pics['valley'];
      if (valley == null) return;
      canvas.save();
      _zoomFor(canvas, size, 0);
      _drawWhole(canvas, size, valley);
      canvas.restore();
      return;
    }
    final t = _segT;
    // The realm seen whole behind the ones going, if any is left.
    var whole = _realms.length;
    for (var k = 0; k < _realms.length; k++) {
      if (t < _start[k]) {
        whole = k;
        break;
      }
    }
    if (whole < _realms.length) {
      final picture = _pics[_realms[whole].$1];
      if (picture != null) {
        canvas.save();
        _zoomFor(canvas, size, whole);
        _drawWhole(canvas, size, picture);
        canvas.restore();
      }
    }
    // Those going, the newest behind the older ones still falling.
    for (var k = whole - 1; k >= 0; k--) {
      final sift = _sifts[k];
      if (sift == null) continue;
      final at = t - _start[k];
      if (at > sift.doneBy) continue;
      canvas.save();
      _zoomFor(canvas, size, k);
      sift.paint(canvas, at);
      canvas.restore();
    }
  }

  static final Paint _wholePaint = Paint()..filterQuality = FilterQuality.low;

  void _drawWhole(Canvas canvas, Size size, RealmPicture picture) {
    final image = picture.image;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      _wholePaint,
    );
  }

  static final Paint _shadowPaint = Paint();

  void _paintParty(Canvas canvas, Size size) {
    final party = widget.party;
    if (party == null || party.count == 0) return;
    final n = party.count;
    final rest = party.zoom;
    // In the realms they stand as close as the realms' own creatures do:
    // the biggest of them about a fifth of the screen high.
    var tallest = 1.0;
    for (var i = 0; i < n; i++) {
      tallest = math.max(tallest, party.halfHeight(i));
    }
    final stance = rest * (size.height * 0.1 / (tallest * rest)).clamp(1.0, 3.2);
    final g = _glide;
    for (var i = 0; i < n; i++) {
      final hh = party.halfHeight(i);
      final feet = Offset(
        size.width * (0.5 + (i - (n - 1) / 2) * 0.085),
        size.height * 0.885,
      );
      final standing = feet - Offset(0, hh * stance);
      final at = Offset.lerp(standing, party.restAt(i), g)!;
      final z = stance + (rest - stance) * g;
      // A shadow on ground that is not there, gone once they are on the
      // floor that is.
      final shade = 0.38 * (1 - g);
      if (shade > 0.01) {
        _shadowPaint.color = Colors.black.withValues(alpha: shade);
        canvas.drawOval(
          Rect.fromCenter(
            center: at + Offset(0, hh * z * 0.92),
            width: hh * z * 1.5,
            height: hh * z * 0.3,
          ),
          _shadowPaint,
        );
      }
      // Drawn whole to the end: the room takes them over where they stand.
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(z);
      party.paint(canvas, i, faceRight: party.facesRight(i), time: _clock);
      canvas.restore();
    }
  }
}

double _smoother(double t) => t * t * t * (t * (t * 6 - 15) + 10);

class _Frame extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.state) : super(repaint: state._frame);

  final _BeautyMaskRevealState state;

  @override
  void paint(Canvas canvas, Size size) => state._paintScene(canvas, size);

  @override
  bool shouldRepaint(_RevealPainter old) => old.state != state;
}

/// The way on, faded up once the line has had a moment to be read.
class _DelayedHint extends StatefulWidget {
  const _DelayedHint({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  State<_DelayedHint> createState() => _DelayedHintState();
}

class _DelayedHintState extends State<_DelayedHint> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1100), () {
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
    child: Text(
      widget.label,
      style: TextStyle(
        fontFamily: 'monospace',
        color: widget.color.withValues(alpha: 0.75),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.4,
      ),
    ),
  );
}
