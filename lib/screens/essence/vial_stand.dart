// lib/screens/essence/vial_stand.dart
//
// THE VIAL STAND: each Essence chamber's place for a vial of its own group,
// beside the chamber's title. Tapping it grows the vial out of its socket
// into the stand (a passage, as home's emblems open their screens), where
// the chamber's essence is poured into it step by step
// (models/vial_infusion.dart).
//
// Everything that is alchemy here is grains (screens/essence/infusion_fx
// .dart): the essence leaves the count in the header and flows into the
// vial; what comes up leaves the vial and settles into the words of the
// picks; a pick taken runs down into its slot on the ladder, the other
// drifts back in. The vial itself is the cultivation sphere every vial in
// the game is drawn as.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/planet_dungeon/blood_heart_fx.dart'
    show HeartWord, heartWordOf;
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/vial_infusion.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/screens/essence/infusion_fx.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/services/vial_infusion_service.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/element_resource_glyph.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart'
    show EssenceElement, essenceRamp;
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/home_emblems.dart' show EmblemStage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const BracketPalette _p = BracketPalette.dark;
const Color _gold = Color(0xFFE6C36A);

// ── the stand's layout, shared with the passage ────────────────────────────

const double _kHeader = 56;
const double _kStage = 236;

/// The vial's box on the stand: the sphere is a third of it across, as an
/// [ExtractionVialOrb] draws one.
const double _kOrb = 176;

/// Where the vial stands on the stand's page, and its sphere's radius. The
/// passage grows the socket's vial to exactly here.
(Offset, double) vialStandSphere(Size screen, EdgeInsets pad) => (
  Offset(screen.width / 2, pad.top + _kHeader + _kStage * 0.47),
  _kOrb * 0.34,
);

ExtractionVial _vialOf(VialInfusion v) => ExtractionVial(
  id: 'vial.${v.group.name}.${v.rarity.name}.${v.name}',
  name: v.name,
  group: v.group,
  rarity: v.rarity,
  quantity: 1,
  price: null,
);

String _offerLabel(InfusionStep step, String id) => switch (step) {
  InfusionStep.nature => id,
  InfusionStep.tint => tintLabels[id] ?? id,
  InfusionStep.size => sizeLabels[id] ?? id,
  InfusionStep.extract => id,
};

String? _offerDetail(InfusionStep step, String id) => switch (step) {
  InfusionStep.nature => NatureCatalog.byId(id)?.description,
  _ => null,
};

/// The two elements a group's grains are drawn in.
(String, String) _typesOf(ElementalGroup g) {
  final (a, b) = g.particleTypes;
  return (a, b ?? a);
}

/// The group's grain shades: its two elements' ramps.
List<Color> _shadesOf(ElementalGroup g) {
  final (a, b) = _typesOf(g);
  return [
    ...essenceRamp(EssenceElement.of(a)),
    ...essenceRamp(EssenceElement.of(b)),
  ];
}

/// A vial's sphere, as [ExtractionVialOrb] would draw it at [_kOrb].
CultivationSphereField _sphereOf(ElementalGroup g, VialRarity r) {
  final (a, b) = _typesOf(g);
  return CultivationSphereField([
    SpecimenGrains.disc(cultivationTypeColor(a), radius: 40),
    SpecimenGrains.disc(cultivationTypeColor(b), radius: 40),
  ], grains: (_kOrb * 3.4 * r.fx.particleMult).round().clamp(60, 640));
}

List<Color> _sphereColors(ElementalGroup g) {
  final (a, b) = _typesOf(g);
  return [cultivationTypeColor(a), cultivationTypeColor(b)];
}

/// How far round a vial's sphere has turned at [time]: the clock is
/// shared, so the passage and the page agree on it at the hand-off.
double _spinAt(VialRarity r, double time) =>
    time * CultivationSphere.spinRate(null) * (0.6 + r.fx.speedMult);

/// A soft pool of [color] round [c]: what [VialLightPool] lays under a vial.
void _paintPool(Canvas canvas, Offset c, double radius, Color color, double k) {
  if (k <= 0 || radius <= 0) return;
  canvas.drawCircle(
    c,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        radius,
        [
          color.withValues(alpha: (0.34 * k).clamp(0.0, 1.0)),
          color.withValues(alpha: (0.1 * k).clamp(0.0, 1.0)),
          color.withValues(alpha: 0),
        ],
        const [0.0, 0.5, 1.0],
      ),
  );
}

// ── the socket, in the chamber's title ─────────────────────────────────────

/// The stand as it sits beside a chamber's title: the vial on it, or an
/// empty socket that breathes to be found while a vial fits it.
class VialStandSocket extends StatefulWidget {
  const VialStandSocket({super.key, required this.group, this.size = 46});

  final ElementalGroup group;
  final double size;

  @override
  State<VialStandSocket> createState() => _VialStandSocketState();
}

class _VialStandSocketState extends State<VialStandSocket>
    with SingleTickerProviderStateMixin {
  VialInfusion? _on;
  bool _teach = false;
  final GlobalKey _box = GlobalKey();

  /// True while the vial is away on the stand's page.
  final ValueNotifier<bool> _lifted = ValueNotifier(false);

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  VialInfusionService get _svc =>
      VialInfusionService(context.read<AlchemonsDatabase>());

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(covariant VialStandSocket old) {
    super.didUpdateWidget(old);
    if (old.group != widget.group) _read();
  }

  Future<void> _read() async {
    final svc = _svc;
    final on = await svc.load(widget.group);
    final taught =
        await svc.db.settingsDao.getSetting(VialInfusionService.taughtKey) ==
        '1';
    final fits = !taught && (await svc.vialsFor(widget.group)).isNotEmpty;
    if (!mounted) return;
    setState(() {
      _on = on;
      _teach = fits && on == null;
    });
    if (_teach) {
      _breath.repeat(reverse: true);
    } else {
      _breath
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _lifted.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    HapticFeedback.selectionClick();
    final current = ValueNotifier<VialInfusion?>(_on);
    // Lifted a frame after the push, once the passage's own vial stands
    // over it (the route's first frame is laid out offstage, unpainted).
    final away = ValueNotifier<bool>(false);
    away.addListener(() {
      if (!mounted) return;
      if (!away.value) {
        _lifted.value = false;
        return;
      }
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          if (away.value) _lifted.value = true;
        })
        ..ensureVisualUpdate();
    });
    await EmblemPassage.pushScene<void>(
      context,
      scene: VialStandPassage(group: widget.group, current: current),
      from: _box,
      page: VialStandPage(group: widget.group, current: current),
      lifted: away,
    );
    // [current] is not disposed: the way back is still drawing from it
    // when the push completes, and it holds nothing but a value.
    if (mounted) await _read();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.group.color;
    final on = _on;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: ValueListenableBuilder<bool>(
        valueListenable: _lifted,
        builder: (_, away, child) =>
            Opacity(opacity: away ? 0 : 1, child: child),
        child: AnimatedBuilder(
          animation: _breath,
          builder: (_, child) => CustomPaint(
            painter: _SocketPainter(
              color: color,
              filled: on != null,
              breath: _breath.value,
            ),
            child: child,
          ),
          child: SizedBox.square(
            key: _box,
            dimension: widget.size,
            child: on == null
                ? Center(
                    child: Text(
                      'VIAL',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: color.withValues(alpha: 0.8),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                : ExtractionVialOrb(vial: _vialOf(on), size: widget.size),
          ),
        ),
      ),
    );
  }
}

/// A ring of the group's colour: dashed and faint while empty, breathing
/// to be found, none once a vial stands in it.
class _SocketPainter extends CustomPainter {
  _SocketPainter({
    required this.color,
    required this.filled,
    required this.breath,
  });

  final Color color;
  final bool filled;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    if (filled) return;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;
    if (breath > 0) {
      _paintPool(canvas, c, r * 1.5, color, 0.6 * breath);
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.5);
    const dashes = 16;
    for (var i = 0; i < dashes; i++) {
      final a = i / dashes * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a,
        math.pi * 2 / dashes * 0.55,
        false,
        ring,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SocketPainter old) =>
      old.color != color || old.filled != filled || old.breath != breath;
}

// ── the way in ─────────────────────────────────────────────────────────────

/// The socket's vial lifting off the chamber and growing to its place on
/// the stand, as the chamber goes dark under it; back, it shrinks home.
class VialStandPassage extends PassageScene {
  VialStandPassage({required this.group, required this.current});

  final ElementalGroup group;

  /// What is on the stand, as the page last read it: it may have changed
  /// by the way back.
  final ValueListenable<VialInfusion?> current;

  CultivationSphereField? _field;
  VialRarity? _fieldRarity;

  @override
  Duration get inward => const Duration(milliseconds: 640);
  @override
  Duration get outward => const Duration(milliseconds: 560);

  /// A cut: the page's own vial stands exactly where this one grew to.
  @override
  Duration get landing => const Duration(milliseconds: 160);

  @override
  double pageShown(double land) => land > 0 ? 1 : 0.004;

  @override
  Listenable? get listenable => current;

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    final (to, toR) = vialStandSphere(s.screen, s.pad);
    final g = s.grow;
    final c = Offset.lerp(s.box.center, to, g)!;
    final r = ui.lerpDouble(s.box.shortestSide * 0.34, toR, g)!;
    if (back) {
      canvas.drawRect(
        Offset.zero & s.screen,
        Paint()..color = _p.bg0.withValues(alpha: s.ground),
      );
      _paintPool(canvas, c, r / 0.34 * 0.5, group.color, 0.4 + 0.6 * g);
    }
    if (!front || s.land > 0) return;
    final on = current.value;
    if (on == null) return;
    if (_field == null || _fieldRarity != on.rarity) {
      _field = _sphereOf(group, on.rarity);
      _fieldRarity = on.rarity;
    }
    _field!.paint(
      canvas,
      c,
      r,
      spin: _spinAt(on.rarity, s.time),
      time: s.time,
      colors: _sphereColors(group),
      twinkle: on.rarity.fx.twinkle ? 2.5 : 1,
    );
  }
}

// ── the stand ──────────────────────────────────────────────────────────────

enum _Phase { idle, pouring, revealing, taking, drawing }

class VialStandPage extends StatefulWidget {
  const VialStandPage({super.key, required this.group, this.current});

  final ElementalGroup group;

  /// Kept up to date with what is on the stand, for the way back.
  final ValueNotifier<VialInfusion?>? current;

  @override
  State<VialStandPage> createState() => _VialStandPageState();
}

class _VialStandPageState extends State<VialStandPage>
    with GlyphClockLease<VialStandPage> {
  bool _read = false;
  bool _busy = false;
  bool _hinted = true;
  VialInfusion? _on;
  List<ExtractionVial> _vials = const [];
  int _essence = 0;

  _Phase _phase = _Phase.idle;

  /// The pour in flight, and the count the header ticks down from.
  PourFx? _pour;
  int _pourFrom = 0, _pourCost = 0;

  /// The picks as grains, read while the essence flows.
  List<HeartWord>? _words;
  List<WordFormFx> _forms = const [];
  List<WordFlowFx> _flows = const [];

  /// A pick on its way to the ladder: which step, its label, and its flow.
  (InfusionStep, String, WordFlowFx)? _landing;

  /// The vial coming onto the stand, or being drawn out of it.
  double? _appearAt, _drawnAt;

  CultivationSphereField? _field;
  VialRarity? _fieldRarity;
  late final InfusionBatch _batch = InfusionBatch(_shadesOf(widget.group));

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _essenceKey = GlobalKey();
  final List<GlobalKey> _titleKeys = [GlobalKey(), GlobalKey()];
  final Map<InfusionStep, GlobalKey> _slotKeys = {
    for (final s in InfusionStep.values) s: GlobalKey(),
  };

  double _lastTick = 0;

  /// The screen's safe area, as the last build saw it (the painters and the
  /// clock read it outside a build).
  EdgeInsets _pad = EdgeInsets.zero;

  late final VialInfusionService _svc = VialInfusionService(
    context.read<AlchemonsDatabase>(),
  );

  Color get _color => widget.group.color;
  double get _now => GlyphClock.instance.seconds.value;

  @override
  bool get wantsClock => true;

  @override
  void initState() {
    super.initState();
    // What the socket held, so the vial is standing here from the first
    // frame the passage hands over.
    _on = widget.current?.value;
    syncGlyphClock();
    GlyphClock.instance.seconds.addListener(_tick);
    _load();
  }

  @override
  void dispose() {
    GlyphClock.instance.seconds.removeListener(_tick);
    releaseGlyphClock();
    super.dispose();
  }

  Future<void> _load() async {
    final on = await _svc.load(widget.group);
    final vials = await _svc.vialsFor(widget.group);
    final essence = await _svc.essence(widget.group);
    final hinted =
        await _svc.db.settingsDao.getSetting(VialInfusionService.tutorialKey) ==
        '1';
    // A pick waiting from an earlier visit: read its words, shown at once.
    List<HeartWord>? words;
    if (on != null && on.offer.isNotEmpty) words = await _wordsFor(on);
    if (!mounted) return;
    setState(() {
      _on = on;
      _vials = vials;
      _essence = essence;
      _hinted = hinted;
      _read = true;
      _words = words;
    });
    widget.current?.value = on;
  }

  Future<List<HeartWord>> _wordsFor(VialInfusion on) => Future.wait([
    for (final id in on.offer)
      heartWordOf(_offerLabel(on.step, id), size: 17, scale: 3, step: 4),
  ]);

  // ── the clock ──

  void _tick() {
    final now = _now;
    final dt = (now - _lastTick).clamp(0.0, 1 / 20);
    _lastTick = now;
    final on = _on;
    if (on != null) {
      final (_, r) = _sphereGeometry();
      _sphere(on.rarity).step(dt, r, _spinAt(on.rarity, now), 0, now);
    }
    switch (_phase) {
      case _Phase.pouring:
        final pour = _pour;
        if (pour != null && pour.done(now) && _words != null) _reveal();
      case _Phase.revealing:
        if (_forms.every((f) => f.done(now))) {
          setState(() {
            _phase = _Phase.idle;
            _forms = const [];
            _pour = null;
          });
        }
      case _Phase.taking:
        if (_flows.every((f) => f.done(now))) _landed();
      case _Phase.drawing:
      case _Phase.idle:
        break;
    }
  }

  CultivationSphereField _sphere(VialRarity r) {
    if (_field == null || _fieldRarity != r) {
      _field = _sphereOf(widget.group, r);
      _fieldRarity = r;
    }
    return _field!;
  }

  (Offset, double) _sphereGeometry() {
    final box = _stackKey.currentContext?.findRenderObject();
    final size = box is RenderBox && box.hasSize ? box.size : Size.zero;
    return vialStandSphere(size, _pad);
  }

  /// [key]'s box in the page's own coordinates.
  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final stack = _stackKey.currentContext?.findRenderObject();
    if (box is! RenderBox || stack is! RenderBox || !box.hasSize) return null;
    final o = stack.globalToLocal(box.localToGlobal(Offset.zero));
    return o & box.size;
  }

  // ── what the player does ──

  Future<void> _set(ExtractionVial vial) async {
    if (_busy) return;
    _busy = true;
    HapticFeedback.mediumImpact();
    await _svc.set(vial);
    await _load();
    if (!mounted) return;
    context.sound(SoundCue.uiConfirm);
    setState(() {
      _appearAt = _now;
      _busy = false;
    });
  }

  /// Pours for the current step. The essence is spent and what comes up is
  /// rolled at once; what the player sees is it flowing in, and the picks
  /// rising out of the vial when it has all gone in.
  Future<void> _pourNow() async {
    final on = _on;
    if (_busy || on == null || _phase != _Phase.idle) return;
    final cost = on.stepCost;
    if (_essence < cost) {
      context.sound(SoundCue.uiDenied);
      showGameSnack(context, 'Not enough essence', accent: _color);
      return;
    }
    _busy = true;
    final next = await _svc.pour(widget.group);
    if (!mounted) return;
    if (next == null) {
      _busy = false;
      context.sound(SoundCue.uiDenied);
      showGameSnack(context, 'Not enough essence', accent: _color);
      return;
    }
    if (!_hinted) {
      await _svc.db.settingsDao.setSetting(
        VialInfusionService.tutorialKey,
        '1',
      );
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    context.sound(SoundCue.fusionPour);
    final (c, r) = _sphereGeometry();
    final src = _rectOf(_essenceKey)?.center ?? Offset(c.dx + 120, c.dy - 140);
    setState(() {
      _hinted = true;
      _on = next;
      _words = null;
      _pourFrom = _essence;
      _pourCost = cost;
      _phase = next.step == InfusionStep.extract
          ? _Phase.drawing
          : _Phase.pouring;
      _pour = PourFx(from: src, to: c, radius: r, start: _now);
    });
    widget.current?.value = next;
    final words = await _wordsFor(next);
    if (mounted) setState(() => _words = words);
    _busy = false;
  }

  /// The pour has all gone in: the picks rise out of the vial into the
  /// words where their cards stand.
  void _reveal() {
    final words = _words;
    final on = _on;
    if (words == null || on == null) return;
    final (c, r) = _sphereGeometry();
    final now = _now;
    HapticFeedback.heavyImpact();
    setState(() {
      _essence = _pourFrom - _pourCost;
      _phase = _Phase.revealing;
      _forms = [
        for (var i = 0; i < words.length; i++)
          WordFormFx(
            word: words[i],
            sphere: c,
            radius: r,
            at: _titleAt(i) ?? c + Offset(-60, 120 + 70.0 * i),
            start: now + 0.15 * i,
            salt: i,
          ),
      ];
    });
  }

  Offset? _titleAt(int i) {
    final rect = _rectOf(_titleKeys[i]);
    if (rect == null) return null;
    return Offset(rect.left, rect.center.dy);
  }

  /// [index] taken: it runs into its slot on the ladder; the other drifts
  /// back into the vial.
  void _take(int index) {
    final on = _on;
    final words = _words;
    if (_busy || on == null || words == null || _phase != _Phase.idle) return;
    final step = on.step;
    final id = on.offer[index];
    final (c, r) = _sphereGeometry();
    final slot = _rectOf(_slotKeys[step]!);
    final to = slot?.center ?? c;
    final now = _now;
    final flows = [
      for (var j = 0; j < words.length; j++)
        j == index
            ? WordFlowFx(
                word: words[j],
                at: _titleAt(j) ?? to,
                to: to,
                spread: 8,
                start: now,
                salt: j,
              )
            : WordFlowFx(
                word: words[j],
                at: _titleAt(j) ?? c,
                to: c,
                spread: r * 0.6,
                start: now + 0.1,
                bowSide: -1,
                salt: j,
              ),
    ];
    HapticFeedback.mediumImpact();
    context.sound(SoundCue.uiConfirm);
    _busy = true;
    setState(() {
      _phase = _Phase.taking;
      _flows = flows;
      _landing = (step, _offerLabel(step, id), flows[index]);
    });
    _svc.take(widget.group, id).whenComplete(() => _busy = false);
  }

  Future<void> _landed() async {
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await _load();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _flows = const [];
      _landing = null;
      _words = null;
    });
  }

  /// Extraction: the measure flows in, then the vial is drawn out of the
  /// stand, its grains spiralling away, and the egg goes to its chamber.
  Future<void> _extract() async {
    final on = _on;
    if (_busy || on == null || _phase != _Phase.idle) return;
    if (_essence < on.stepCost) {
      context.sound(SoundCue.uiDenied);
      showGameSnack(context, 'Not enough essence', accent: _color);
      return;
    }
    _busy = true;
    final (c, r) = _sphereGeometry();
    final src = _rectOf(_essenceKey)?.center ?? Offset(c.dx + 120, c.dy - 140);
    context.sound(SoundCue.fusionPour);
    setState(() {
      _pourFrom = _essence;
      _pourCost = on.stepCost;
      _phase = _Phase.drawing;
      _pour = PourFx(from: src, to: c, radius: r, start: _now);
    });
    await Future<void>.delayed(
      Duration(milliseconds: ((_pour!.end - _pour!.start) * 1000).round()),
    );
    if (!mounted) return;
    HatchingResult res;
    try {
      res = await EggHatching.extractInfusedVial(
        context: context,
        infusion: on,
        pay: () => _svc.payExtraction(on),
      );
    } catch (e) {
      debugPrint('Vial stand: extraction failed: $e');
      res = HatchingResult(
        success: false,
        message: "Couldn't extract the vial.",
      );
    }
    if (!mounted) return;
    if (!res.success) {
      _busy = false;
      setState(() {
        _phase = _Phase.idle;
        _pour = null;
      });
      context.sound(SoundCue.uiDenied);
      showGameSnack(context, res.message ?? "Couldn't extract the vial.");
      return;
    }
    await _svc.extracted(widget.group);
    if (!mounted) return;
    context.sound(SoundCue.extractionComplete);
    HapticFeedback.heavyImpact();
    setState(() {
      _essence = _pourFrom - _pourCost;
      _drawnAt = _now;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    showGameSnack(context, res.message ?? 'Vial extracted.', accent: _color);
    _busy = false;
    widget.current?.value = null;
    setState(() {
      _phase = _Phase.idle;
      _pour = null;
      _drawnAt = null;
    });
    await _load();
  }

  Future<void> _takeBack() async {
    final on = _on;
    if (on == null || _busy || _phase != _Phase.idle) return;
    final poured = on.step != InfusionStep.nature || on.offer.isNotEmpty;
    if (poured) {
      final ok = await showBracketConfirm(
        context,
        title: 'Take the vial back?',
        message:
            'It goes back to your inventory. The essence poured into it and '
            'the choices it took are lost.',
        confirmLabel: 'TAKE IT BACK',
        palette: _p,
        accent: _color,
      );
      if (!ok || !mounted) return;
    }
    _busy = true;
    await _svc.takeBack(widget.group);
    _busy = false;
    await _load();
  }

  // ── the page ──

  @override
  Widget build(BuildContext context) {
    final pad = _pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: _p.bg0,
      body: Stack(
        key: _stackKey,
        children: [
          // The vial and its light, under everything.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _StandPainter(this)),
            ),
          ),
          Column(
            children: [
              SizedBox(height: pad.top),
              SizedBox(height: _kHeader, child: _header()),
              _stage(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + pad.bottom),
                  child: _lower(),
                ),
              ),
            ],
          ),
          // The grains in flight, over everything.
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _FxPainter(this)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        BracketIconButton(
          icon: AppIcons.chevron_left_rounded,
          palette: _p,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'VIAL STAND  ·  ${widget.group.displayName.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              color: _p.ink.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
            ),
          ),
        ),
        ElementResourceGlyph(
          key: _essenceKey,
          biomeId: groupIdFrom(widget.group),
          color: _color,
          size: 18,
          animate: false,
        ),
        const SizedBox(width: 6),
        ValueListenableBuilder<double>(
          valueListenable: GlyphClock.instance.seconds,
          builder: (_, now, _) {
            final pour = _pour;
            var shown = _essence;
            if (pour != null &&
                (_phase == _Phase.pouring || _phase == _Phase.drawing)) {
              final k = ((now - pour.start) / (pour.span + 0.3)).clamp(
                0.0,
                1.0,
              );
              shown = (_pourFrom - _pourCost * k).round();
            }
            return Text(
              formatCoins(shown),
              style: TextStyle(
                fontFamily: 'monospace',
                color: _p.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
      ],
    ),
  );

  /// The stage the vial stands on: its room is kept, the vial itself is
  /// painted under the page. A long press stirs it, as every sphere does.
  Widget _stage() {
    final on = _on;
    return SizedBox(
      height: _kStage,
      child: Stack(
        children: [
          if (on != null)
            Positioned.fill(
              child: GestureDetector(
                onLongPressStart: (d) => _stir(d.globalPosition),
                onLongPressMoveUpdate: (d) => _stir(d.globalPosition),
                onLongPressEnd: (_) => _field?.pointer = null,
                onLongPressCancel: () => _field?.pointer = null,
              ),
            ),
          if (on != null && !_hinted && _phase == _Phase.idle)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Text(
                'Pour ${widget.group.displayName} essence in to choose its '
                'nature.',
                textAlign: TextAlign.center,
                style: bracketText(context, 13, _p.ink.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }

  void _stir(Offset global) {
    final stack = _stackKey.currentContext?.findRenderObject();
    if (stack is! RenderBox) return;
    final (c, _) = _sphereGeometry();
    _field?.pointer = stack.globalToLocal(global) - c;
  }

  Widget _lower() {
    if (!_read) return const SizedBox(height: 160);
    final on = _on;
    if (on == null) return _choose();
    return _infusing(on);
  }

  // ── empty: choose a vial ──

  Widget _choose() {
    if (_vials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No ${widget.group.displayName} vials. The black market has them.',
          textAlign: TextAlign.center,
          style: bracketText(context, 13.5, _p.ink.withValues(alpha: 0.8)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SET A VIAL',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _p.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        for (final v in _vials)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ExtractionVialOrb(vial: v, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.rarity.label,
                        style: bracketText(
                          context,
                          15,
                          _p.ink,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '×${v.quantity}',
                        style: bracketText(context, 12, _p.muted),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: BracketButton(
                    label: 'SET',
                    height: 38,
                    palette: _p,
                    accent: _color,
                    enabled: !_busy,
                    onTap: () => _set(v),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── a vial on the stand ──

  Widget _infusing(VialInfusion on) {
    final step = on.step;
    final cost = on.stepCost;
    final afford = _essence >= cost;
    final idle = _phase == _Phase.idle && !_busy;
    // Only follows the clock while something is moving in it.
    Widget follow(Widget Function(BuildContext, double) build) =>
        _phase == _Phase.idle
        ? build(context, _now)
        : ValueListenableBuilder<double>(
            valueListenable: GlyphClock.instance.seconds,
            builder: (context, now, _) => build(context, now),
          );
    return follow((context, now) {
      final landing = _landing;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              on.rarity.label,
              style: bracketText(context, 15, _p.ink, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final s in InfusionStep.values)
                Expanded(
                  child: _LadderStep(
                    barKey: _slotKeys[s]!,
                    label: s.label,
                    pick: landing != null && landing.$1 == s
                        ? landing.$2
                        : _takenLabel(on, s),
                    pickShown: landing != null && landing.$1 == s
                        ? landing.$3.arrived(now)
                        : 1,
                    active: s == step && landing == null,
                    done:
                        s.index < step.index ||
                        (landing != null && landing.$1 == s),
                    color: _color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (on.offer.isNotEmpty) ...[
            for (var i = 0; i < on.offer.length && i < 2; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OfferCard(
                  titleKey: _titleKeys[i],
                  label: _offerLabel(step, on.offer[i]),
                  detail: _offerDetail(step, on.offer[i]),
                  action: step == InfusionStep.size ? 'KEEP' : 'TAKE',
                  color: _color,
                  enabled: idle,
                  // The title is what the grains became; the rest comes
                  // in around it.
                  titleShown: _titleShown(i, now),
                  chromeShown: _chromeShown(i, now),
                  onTap: () => _take(i),
                ),
              ),
            const SizedBox(height: 4),
            Opacity(
              opacity: _chromeShown(on.offer.length - 1, now),
              child: BracketButton(
                label: 'POUR AGAIN  ·  ${formatCoins(cost)}',
                height: 42,
                palette: _p,
                accent: _color,
                primary: false,
                enabled: idle && afford,
                onTap: _pourNow,
              ),
            ),
          ] else if (step == InfusionStep.extract)
            BracketButton(
              label: 'EXTRACT  ·  ${formatCoins(cost)}',
              height: 46,
              palette: _p,
              accent: _gold,
              enabled: idle && afford,
              onTap: _extract,
            )
          else
            BracketButton(
              label: 'POUR  ·  ${formatCoins(cost)}',
              height: 46,
              palette: _p,
              accent: _color,
              enabled: idle && afford,
              onTap: _pourNow,
            ),
          if (!afford && idle)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Needs ${formatCoins(cost)} ${widget.group.displayName} '
                'essence.',
                textAlign: TextAlign.center,
                style: bracketText(context, 12, _p.muted),
              ),
            ),
          const SizedBox(height: 10),
          BracketButton(
            label: 'TAKE THE VIAL BACK',
            height: 38,
            palette: _p,
            accent: _p.muted,
            primary: false,
            enabled: idle,
            onTap: _takeBack,
          ),
        ],
      );
    });
  }

  String? _takenLabel(VialInfusion on, InfusionStep s) => switch (s) {
    InfusionStep.nature => on.natureId,
    InfusionStep.tint => on.tint == null ? null : tintLabels[on.tint],
    InfusionStep.size => on.size == null ? null : sizeLabels[on.size],
    InfusionStep.extract => null,
  };

  /// How far the [i]th card's title is in: hidden while the essence flows
  /// and while it is a word of grains; gone once it has been taken.
  double _titleShown(int i, double now) => switch (_phase) {
    _Phase.pouring || _Phase.drawing || _Phase.taking => 0,
    _Phase.revealing => i < _forms.length ? _forms[i].textShown(now) : 0,
    _Phase.idle => 1,
  };

  /// The rest of the [i]th card: it comes in as its word settles.
  double _chromeShown(int i, double now) => switch (_phase) {
    _Phase.pouring || _Phase.drawing || _Phase.taking => 0,
    _Phase.revealing =>
      i < _forms.length
          ? ((now - _forms[i].textIn + 0.25) / 0.5).clamp(0.0, 1.0)
          : 0,
    _Phase.idle => 1,
  };
}

/// The vial on the stand and its light: the sphere every vial is drawn as,
/// swelling a little as essence goes in, settling as the picks rise.
class _StandPainter extends CustomPainter {
  _StandPainter(this.s) : super(repaint: GlyphClock.instance.seconds);

  final _VialStandPageState s;

  @override
  void paint(Canvas canvas, Size size) {
    final on = s._on;
    final group = s.widget.group;
    final now = s._now;
    final (c, r0) = vialStandSphere(size, s._pad);
    // A vial just set grows in; one drawn out spirals away.
    final appear = s._appearAt == null
        ? 1.0
        : _ease(((now - s._appearAt!) / 0.7).clamp(0.0, 1.0));
    final drawn = s._drawnAt == null
        ? 0.0
        : ((now - s._drawnAt!) / 1.0).clamp(0.0, 1.0);
    final pour = s._pour;
    final taken = pour?.taken(now) ?? 0;
    final settle = s._phase == _Phase.revealing && s._forms.isNotEmpty
        ? ((now - s._forms.first.start) / 0.9).clamp(0.0, 1.0)
        : 0.0;
    final swell = 0.08 * taken * (1 - settle);
    final r = r0 * (1 + swell) * appear;
    // Its light: under it on the floor, and round it, brighter as it fills.
    _paintPool(
      canvas,
      Offset(c.dx, c.dy + r0 * 1.15),
      r0 * 1.9,
      group.color,
      (0.35 + 0.5 * swell / 0.08) * appear * (1 - drawn),
    );
    _paintPool(
      canvas,
      c,
      r0 / 0.34 * 0.5,
      group.color,
      (1 + 1.6 * swell / 0.08) * (on == null ? 0.35 : appear * (1 - drawn)),
    );
    if (on == null || r <= 0) return;
    s
        ._sphere(on.rarity)
        .paint(
          canvas,
          c,
          r,
          spin: _spinAt(on.rarity, now) + 1.4 * taken,
          time: now,
          colors: _sphereColors(group),
          twinkle: on.rarity.fx.twinkle ? 2.5 : 1,
          opacity: 1 - _ease(drawn),
          unwind: drawn,
        );
  }

  static double _ease(double x) => x * x * (3 - 2 * x);

  @override
  bool shouldRepaint(covariant _StandPainter old) => true;
}

/// The grains in flight: the pour, the picks forming, a pick taken.
class _FxPainter extends CustomPainter {
  _FxPainter(this.s) : super(repaint: GlyphClock.instance.seconds);

  final _VialStandPageState s;

  @override
  void paint(Canvas canvas, Size size) {
    final now = s._now;
    final b = s._batch..clear();
    s._pour?.paint(b, now);
    for (final f in s._forms) {
      f.paint(b, now);
    }
    for (final f in s._flows) {
      f.paint(b, now);
    }
    b.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) => true;
}

/// One rung of the ladder: the step, a bar, and what it took. A pick
/// running into it comes in as its grains arrive, over a soft light.
class _LadderStep extends StatelessWidget {
  const _LadderStep({
    required this.barKey,
    required this.label,
    required this.pick,
    required this.pickShown,
    required this.active,
    required this.done,
    required this.color,
  });

  final GlobalKey barKey;
  final String label;
  final String? pick;
  final double pickShown;
  final bool active;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final arriving = pickShown < 1;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: active
                ? color
                : done
                ? _p.ink.withValues(alpha: 0.75)
                : _p.muted.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          key: barKey,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          color: done
              ? color.withValues(alpha: 0.35 + 0.4 * pickShown)
              : active
              ? color.withValues(alpha: 0.35)
              : _p.lineSoft,
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 16,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (arriving && pickShown > 0)
                Positioned(
                  left: -8,
                  right: -8,
                  top: -10,
                  bottom: -10,
                  child: CustomPaint(
                    painter: _SlotLightPainter(
                      color,
                      math.sin(math.pi * pickShown),
                    ),
                  ),
                ),
              Opacity(
                opacity: pickShown,
                child: Text(
                  pick ?? (active ? '…' : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(context, 11.5, _p.ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlotLightPainter extends CustomPainter {
  _SlotLightPainter(this.color, this.k);
  final Color color;
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(size.width / size.height, 1);
    _paintPool(canvas, Offset.zero, size.height / 2, color, 1.4 * k);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SlotLightPainter old) =>
      old.color != color || old.k != k;
}

/// A pick, laid out where its word of grains settles: the title is in the
/// same heavy, spaced capitals the grains were read from, so the hand-off
/// lands on the letters.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.titleKey,
    required this.label,
    required this.detail,
    required this.action,
    required this.color,
    required this.enabled,
    required this.titleShown,
    required this.chromeShown,
    required this.onTap,
  });

  final GlobalKey titleKey;
  final String label;
  final String? detail;
  final String action;
  final Color color;
  final bool enabled;
  final double titleShown;
  final double chromeShown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      label.toUpperCase(),
      key: titleKey,
      maxLines: 1,
      overflow: TextOverflow.visible,
      softWrap: false,
      style: TextStyle(
        fontFamily: 'Roboto',
        color: _p.ink,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: 17 * 0.2,
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: chromeShown,
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: color.withValues(alpha: 0.6),
                bracketSize: 9,
                strokeWidth: 1,
              ),
              child: ColoredBox(color: _p.bg1.withValues(alpha: 0.9)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Opacity(opacity: titleShown, child: title),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: chromeShown,
                        child: Text(
                          detail!,
                          style: bracketText(context, 12, _p.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Opacity(
                opacity: chromeShown,
                child: SizedBox(
                  width: 78,
                  child: BracketButton(
                    label: action,
                    height: 36,
                    palette: _p,
                    accent: color,
                    enabled: enabled && chromeShown >= 1,
                    onTap: onTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
