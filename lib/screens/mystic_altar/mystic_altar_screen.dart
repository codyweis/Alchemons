// lib/screens/mystic_altar/mystic_altar_screen.dart
//
// THE MYSTIC ALTAR — sixteen relic seats on a turning ring of dust round a
// well, and Blood's seat in the well itself (see AltarHubField). Drag the
// ring to turn it, or tap a seat; the seat at the front is the one the panel
// speaks for. A relic in the satchel is held down onto its seat; a set relic
// opens its altar, where the Mystic is called (BossAltarDetailScreen).
//
// Coming back from a summoning, that seat wakes: it lights its stretch of the
// ring and its stream starts running into the heart. Setting the last relic
// tears the heart open into the arcane rift.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/mystic_altar/altar_chrome.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/screens/mystic_altar/altar_hub_field.dart';
import 'package:alchemons/screens/mystic_altar/boss_altar_detail_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class MysticAltarScreen extends StatefulWidget {
  const MysticAltarScreen({super.key, this.revealReady});

  /// Set true once the altar's state has loaded, for an entry portal covering
  /// this screen (VoidPortal.pushThroughGlyphs).
  final ValueNotifier<bool>? revealReady;

  @override
  State<MysticAltarScreen> createState() => _MysticAltarScreenState();
}

class _MysticAltarScreenState extends State<MysticAltarScreen>
    with SingleTickerProviderStateMixin {
  late final List<AltarSeat> _ring = [
    for (final e in kAltarEntries)
      if (e.element.toLowerCase() != 'blood') AltarSeat(e),
  ];
  late final AltarSeat _heart = AltarSeat(
    kAltarEntries.firstWhere((e) => e.element.toLowerCase() == 'blood'),
  );
  late final AltarHubField _field = AltarHubField(_ring, _heart);
  List<AltarSeat> get _all => [..._ring, _heart];

  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Duration _last = Duration.zero;

  final Map<String, String> _mysticNames = {};
  bool _loading = true;
  bool _grainsRead = false;
  late final RevealWhenReady _revealWhenReady;

  /// Where the ring is easing to, after a drag or a tap.
  double? _snapTo;
  bool _dragging = false;

  /// A relic being set: nothing else answers until it has landed.
  bool _busy = false;

  /// The arcane rift tearing open, and the card that names it.
  Completer<void>? _arcaneRun;
  bool _arcaneCard = false;

  AltarSeat get _chosen =>
      _field.selected < 0 ? _heart : _ring[_field.selected];

  @override
  void initState() {
    super.initState();
    _revealWhenReady = RevealWhenReady(
      widget.revealReady,
      () => mounted && !_loading && _grainsRead,
    );
    // Arriving earns the task; collecting it happens in the journal.
    OnboardingTaskService.recordArrival(context, 'rite');
    _ticker = createTicker(_tick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readGrains();
      _load(firstLoad: true);
    });
  }

  @override
  void dispose() {
    _revealWhenReady.dispose();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _readGrains() async {
    final catalog = context.read<CreatureCatalog>();
    await Future.wait([
      for (final seat in _all)
        AltarGrains.relic(seat.entry).then((g) {
          seat.relic = g ?? SpecimenGrains.disc(seat.accent, radius: 14);
        }),
    ]);
    if (mounted) setState(() => _grainsRead = true);
    // The Mystics after the relics: the ring can show before they are read.
    // The chosen one first, so its apparition is the first to stand.
    final order = [_chosen, ..._all.where((s) => !identical(s, _chosen))];
    for (final seat in order) {
      final mystic = catalog.mysticByElement(seat.entry.element);
      if (mystic == null || !mounted) continue;
      seat.mystic = await AltarGrains.creature(
        mystic,
        width: 220,
        maxGrains: 3000,
        tones: 12,
      );
    }
  }

  Future<void> _load({bool firstLoad = false}) async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final relicIds = await db.altarDao.getRelicPlacedIds(
      kAltarEntries.map((e) => e.id).toList(),
    );
    AltarSeat? woke;
    for (final seat in _all) {
      final e = seat.entry;
      final qty = await db.inventoryDao.getItemQty(
        BossLootKeys.traitKeyForElement(e.element),
      );
      final placements = await db.altarDao.getPlacementsForBoss(e.id);
      final mystic = catalog.mysticByElement(e.element);
      final summoned =
          (await db.settingsDao.getSetting(
            'altar_summoned_${e.id}',
          ))?.trim().isNotEmpty ??
          false;
      final next = summoned
          ? SeatState.awakened
          : relicIds.contains(e.id)
          ? SeatState.placed
          : qty > 0
          ? SeatState.held
          : SeatState.unearned;
      if (!firstLoad &&
          next == SeatState.awakened &&
          seat.state != SeatState.awakened) {
        // Back from its summoning: it wakes in front of you.
        seat.waking = 0;
        woke = seat;
      }
      seat
        ..state = next
        ..offerings = placements.length
        ..required = catalog
            .byType(e.element)
            .where((s) => s.id != mystic?.id)
            .length;
      _mysticNames[e.id] = mystic?.name ?? e.name;
    }
    if (!mounted) return;
    setState(() {
      if (firstLoad) _chooseFirst();
      _loading = false;
    });
    if (woke != null) {
      HapticFeedback.heavyImpact();
      context.sound(
        SoundCue.forElement(woke.entry.element) ?? SoundCue.achievementUnlock,
      );
    }
  }

  /// Opens on the seat that wants something: a relic to set, offerings to
  /// give. Failing that, the first awake one; failing that, the first.
  void _chooseFirst() {
    int pick(bool Function(AltarSeat) test) => _ring.indexWhere(test);
    var i = pick((s) => s.state == SeatState.held);
    if (i < 0) i = pick((s) => s.state == SeatState.placed);
    if (i < 0 &&
        (_heart.state == SeatState.held || _heart.state == SeatState.placed)) {
      _field.selected = -1;
      return;
    }
    if (i < 0) i = pick((s) => s.state == SeatState.awakened);
    if (i < 0) i = 0;
    _field
      ..selected = i
      ..rotation = -i * math.pi * 2 / 16;
  }

  // ── the clock ─────────────────────────────────────────────────────────────

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final f = _field;
    f.time += dt;
    f.stepApparition(dt);

    final snap = _snapTo;
    if (snap != null && !_dragging) {
      final d = snap - f.rotation;
      f.rotation += d * (1 - math.exp(-dt * 11));
      if (d.abs() < 0.0006) {
        f.rotation = snap;
        _snapTo = null;
      }
    }
    for (final seat in _all) {
      if (seat.landing > 0 && seat.landing < 1) {
        seat.landing = math.min(1, seat.landing + dt / 0.95);
      }
      if (seat.state == SeatState.awakened && seat.waking < 1) {
        seat.waking = math.min(1, seat.waking + dt / 2.8);
      }
    }
    final run = _arcaneRun;
    if (run != null && !run.isCompleted) {
      f.arcane = math.min(1, f.arcane + dt / 3.4);
      if (f.arcane >= 1) run.complete();
    } else if (run == null && f.arcane > 0) {
      f.arcane = math.max(0, f.arcane - dt / 1.6);
    }
    _clock.value = f.time;
  }

  // ── turning and choosing ──────────────────────────────────────────────────

  static const double _span = math.pi * 2 / 16;

  double _norm(double a) {
    a %= math.pi * 2;
    return a > math.pi ? a - math.pi * 2 : a;
  }

  int _frontmost() {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < 16; i++) {
      final d = _norm(_field.seatAngle(i)).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _choose(int i, {bool turn = true}) {
    final was = _field.selected;
    _field.selected = i;
    if (i >= 0 && turn) {
      var t = -i * _span;
      while (t - _field.rotation > math.pi) {
        t -= math.pi * 2;
      }
      while (t - _field.rotation < -math.pi) {
        t += math.pi * 2;
      }
      _snapTo = t;
    }
    if (was != i) {
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  void _onDragStart(DragStartDetails _) {
    if (_busy || _arcaneRun != null) return;
    _dragging = true;
    _snapTo = null;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    _field.rotation += d.delta.dx * 0.0105;
    final front = _frontmost();
    if (front != _field.selected) _choose(front, turn: false);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    // A flick carries on a little before it settles.
    final ahead = _field.rotation + d.velocity.pixelsPerSecond.dx * 0.0016;
    final keep = _field.rotation;
    _field.rotation = ahead;
    final i = _frontmost();
    _field.rotation = keep;
    _choose(i);
  }

  void _onTapUp(TapUpDetails d) {
    if (_busy || _arcaneRun != null) return;
    final p = d.localPosition;
    final seat = _field.seatAt(p);
    if (seat != null) {
      _choose(seat);
    } else if (_field.heartAt(p)) {
      _choose(-1);
    }
  }

  // ── setting a relic ───────────────────────────────────────────────────────

  Future<void> _setRelic(AltarSeat seat) async {
    if (_busy) return;
    _busy = true;
    final db = context.read<AlchemonsDatabase>();
    final key = BossLootKeys.traitKeyForElement(seat.entry.element);
    final ok = await db.inventoryDao.consumeItem(key, qty: 1);
    if (!mounted) return;
    if (!ok) {
      _busy = false;
      seat.setting = 0;
      await _load();
      return;
    }
    await db.altarDao.setRelicPlaced(seat.entry.id);
    if (!mounted) return;
    context.sound(SoundCue.dungeonRelicCollect);
    setState(() {
      seat
        ..state = SeatState.placed
        ..setting = 0
        ..landing = 0.001;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    final everyRelic = _all.every(
      (s) => s.state == SeatState.placed || s.state == SeatState.awakened,
    );
    final unlocked =
        await db.settingsDao.getSetting('arcane_portal_unlocked') == '1';
    if (!mounted) return;
    _busy = false;
    if (everyRelic && !unlocked) {
      await _openArcane(db);
    } else {
      await _enter(seat);
    }
  }

  /// The last relic is set: the heart tears open into the arcane rift.
  Future<void> _openArcane(AlchemonsDatabase db) async {
    await db.settingsDao.setSetting('arcane_portal_unlocked', '1');
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    context.sound(SoundCue.cosmicPortalOpen);
    final run = _arcaneRun = Completer<void>();
    setState(() {});
    await run.future;
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _arcaneCard = true);
  }

  void _closeArcane() {
    setState(() {
      _arcaneCard = false;
      _arcaneRun = null;
    });
  }

  Future<void> _enter(AltarSeat seat) async {
    await Navigator.of(
      context,
    ).push(_AltarRoute(child: BossAltarDetailScreen(boss: seat.entry)));
    if (!mounted) return;
    await _load();
  }

  String _relicName(AltarEntry e) =>
      BossLootKeys.elementRewards[e.element.toLowerCase()]?.traitName ??
      'relic';

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AltarTone.void0,
      body: LayoutBuilder(
        builder: (context, box) {
          final pad = MediaQuery.paddingOf(context);
          final size = box.biggest;
          const headerH = 62.0;
          final panelH = 214.0 + pad.bottom;
          final stage = Rect.fromLTRB(
            0,
            pad.top + headerH,
            size.width,
            math.max(pad.top + headerH + 120, size.height - panelH),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  onTapUp: _onTapUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _HubPainter(_field, stage, repaint: _clock),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: pad.top,
                height: headerH,
                child: _header(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: panelH,
                child: _loading ? const SizedBox() : _panel(pad.bottom),
              ),
              if (_arcaneCard) Positioned.fill(child: _arcaneOverlay()),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    final awake = _all.where((s) => s.state == SeatState.awakened).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 10),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.chevron_left_rounded,
            palette: altarPalette,
            onTap: () => VoidPortal.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'THE MYSTIC ALTAR',
              style: altarMono(11.5, AltarTone.parchmentDim, spacing: 2.8),
            ),
          ),
          if (!_loading)
            Text(
              '$awake / 17 AWAKE',
              style: altarMono(
                11,
                awake > 0 ? AltarTone.gold : AltarTone.muted,
                spacing: 1.8,
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel(double bottomInset) {
    final seat = _chosen;
    final e = seat.entry;
    final ink = altarInk(e.element);
    final relic = _relicName(e);
    final isHeart = identical(seat, _heart);
    final witnesses = _ring.where((s) => s.state == SeatState.awakened).length;
    final name = _mysticNames[e.id] ?? e.name;

    final status = switch (seat.state) {
      SeatState.unearned when isHeart =>
        'The heart of the altar wakes last. Its relic, the $relic, is won '
            'from the guardian of the ${e.element} planet.',
      SeatState.unearned =>
        'Defeat the guardian of the ${e.element} planet to earn the $relic.',
      SeatState.held =>
        'The $relic is in your satchel. Set it on the altar to open the rite.',
      SeatState.placed when isHeart && witnesses < 16 =>
        'The relic is set. The rite needs all sixteen Mystics awake: '
            '$witnesses of 16.',
      SeatState.placed when seat.offerings >= seat.required =>
        'Every offering is given. The rite can be performed.',
      SeatState.placed =>
        '${seat.offerings} of ${seat.required} offerings given.',
      SeatState.awakened =>
        '$name is awake. Its altar takes offerings for another cultivation.',
    };

    final Widget action = switch (seat.state) {
      SeatState.unearned => const SizedBox(height: 50),
      SeatState.held => AltarHoldButton(
        key: ValueKey('set-${e.id}'),
        label: 'HOLD TO SET THE RELIC',
        holdingLabel: 'SETTING THE $relic'.toUpperCase(),
        accent: seat.accent,
        seconds: 1.1,
        enabled: !_busy && _arcaneRun == null,
        onProgress: (v) => seat.setting = v,
        onComplete: () => _setRelic(seat),
      ),
      _ => BracketButton(
        key: ValueKey('enter-${e.id}'),
        label: 'ENTER THE ALTAR',
        palette: altarPalette,
        accent: seat.accent,
        height: 50,
        primary: seat.state == SeatState.placed,
        onTap: _busy || _arcaneRun != null ? null : () => _enter(seat),
      ),
    };

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF2040307), Color(0x00040307)],
          stops: [0.62, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 18, 24, 16 + bottomInset),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.bottomLeft,
            children: [...previous, ?current],
          ),
          child: Column(
            key: ValueKey('${e.id}-${seat.state}'),
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isHeart ? 'THE HEART  ·  ' : ''}'
                '${e.element.toUpperCase()}  ·  ${relic.toUpperCase()}',
                style: altarMono(10.5, ink, spacing: 2.2),
              ),
              const SizedBox(height: 6),
              Text(
                seat.state == SeatState.unearned ? name : name,
                style: altarName(context, 30).copyWith(
                  color: seat.state == SeatState.unearned
                      ? AltarTone.parchment.withValues(alpha: 0.55)
                      : AltarTone.parchment,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: altarBody(context),
                ),
              ),
              const SizedBox(height: 14),
              action,
            ],
          ),
        ),
      ),
    );
  }

  Widget _arcaneOverlay() {
    return ColoredBox(
      color: const Color(0xB0040307),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: AltarTone.violet.withValues(alpha: 0.8),
              bracketSize: 16,
              strokeWidth: 1.2,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              color: const Color(0xF20B0812),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EVERY RELIC IS SET',
                    style: altarMono(10.5, AltarTone.violet, spacing: 2.4),
                  ),
                  const SizedBox(height: 6),
                  Text('The Arcane Rift', style: altarName(context, 26)),
                  const SizedBox(height: 12),
                  Text(
                    'A rift to the arcane realm has opened on the expedition '
                    'map.\n\nBase stats and potentials have increased across '
                    'all wilderness biomes.',
                    style: altarBody(context),
                  ),
                  const SizedBox(height: 20),
                  BracketButton(
                    label: 'CONTINUE',
                    palette: altarPalette,
                    accent: AltarTone.violet,
                    onTap: _closeArcane,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubPainter extends CustomPainter {
  _HubPainter(this.field, this.stage, {required super.repaint});

  final AltarHubField field;
  final Rect stage;

  @override
  void paint(Canvas canvas, Size size) => field.paint(canvas, size, stage);

  @override
  bool shouldRepaint(_HubPainter old) =>
      old.field != field || old.stage != stage;
}

/// Into an altar: the hub falls away behind a short fade and the altar
/// settles in from a little closer.
class _AltarRoute<T> extends PageRouteBuilder<T> {
  _AltarRoute({required Widget child})
    : super(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 560),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (_, anim, _, child) {
          final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: c,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.12, end: 1.0).animate(c),
              child: child,
            ),
          );
        },
      );
}
