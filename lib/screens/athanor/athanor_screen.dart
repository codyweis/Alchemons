// lib/screens/athanor/athanor_screen.dart
//
// THE ATHANOR — the furnace on home where a pour draws a cosmetic
// (docs/athanor_design.md). The furnace stands in a field of its own; over
// it the balances that pay for a pour, and under it the batch being poured
// into: its pieces (owned ones lit, the rest dim ghosts, the capstone
// sealed), how many are left, the pours and the odds of the next one.
//
// A pour plays through [AthanorReveal]. One ticker drives the field and the
// reveal; while a route covers the screen it stops.

import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/athanor/athanor_field.dart';
import 'package:alchemons/screens/athanor/athanor_furnace.dart';
import 'package:alchemons/screens/athanor/athanor_odds_sheet.dart';
import 'package:alchemons/screens/athanor/athanor_piece_art.dart';
import 'package:alchemons/screens/athanor/athanor_reveal.dart';
import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/services/athanor_service.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/tincture_glyph.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AthanorScreen extends StatefulWidget {
  const AthanorScreen({super.key, this.revealReady, this.revealed});

  /// Turned true once the screen has what it shows, and has painted it once
  /// unseen, for the passage that covers it on the way in.
  final ValueNotifier<bool>? revealReady;

  /// Turned true by that passage as it gives way: the header and panel come
  /// up then (the furnace is already standing where the passage left it).
  /// Null shows them at once.
  final ValueListenable<bool>? revealed;

  @override
  State<AthanorScreen> createState() => _AthanorScreenState();
}

class _AthanorScreenState extends State<AthanorScreen>
    with SingleTickerProviderStateMixin {
  late final AthanorField _field;
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Duration _last = Duration.zero;
  late final RevealWhenReady _revealWhenReady;
  Timer? _midnight;

  bool _loaded = false;

  /// The loaded panel has been through a frame: its first paint (piece
  /// art, glyphs) is paid while the passage still covers the screen.
  bool _painted = false;

  /// The header and panel are up (see [AthanorScreen.revealed]).
  late bool _shown = widget.revealed?.value ?? true;
  String? _batchId;
  AthanorReveal? _reveal;
  AthanorLayout? _layout;

  /// Tincture the first fire gave on this visit (0 for none): said once,
  /// plainly.
  int _firstFire = 0;

  /// The free daily is being collected with nothing to pour into.
  bool _collecting = false;

  /// What the header and panel show while a pour plays (and the free
  /// daily's rewards are shown): the Athanor as it stood at the tap. Null
  /// shows it as it is.
  _Shown? _held;

  final GlobalKey _tinctureKey = GlobalKey();
  final GlobalKey _goldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final svc = context.read<AthanorService>();
    // As the passage left it: the same clock, the same fire.
    _field = AthanorField(
      time: GlyphClock.instance.seconds.value,
      lit: svc.dailyPourReady,
    );
    _clock.value = _field.time;
    _revealWhenReady = RevealWhenReady(
      widget.revealReady,
      () => mounted && _loaded && _painted,
    );
    widget.revealed?.addListener(_onRevealed);
    _ticker = createTicker(_tick)..start();
    _scheduleMidnight();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  void _onRevealed() {
    if (mounted && widget.revealed!.value && !_shown) {
      setState(() => _shown = true);
    }
  }

  @override
  void dispose() {
    widget.revealed?.removeListener(_onRevealed);
    _midnight?.cancel();
    _revealWhenReady.dispose();
    _ticker.dispose();
    _clock.dispose();
    _reveal?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final svc = context.read<AthanorService>();
    // Picks up tincture earned since it last looked.
    await svc.load();
    if (!mounted) return;
    final given = await svc.takeFirstFire();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _firstFire = given;
      _batchId ??= _firstBatch(svc);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _painted = true);
    _field.restFire(svc.dailyPourReady);
  }

  /// The free pour comes back at the UTC day's turn, screen open or not.
  void _scheduleMidnight() {
    _midnight?.cancel();
    _midnight = Timer(athanorUntilNextDay(DateTime.now()), () {
      if (!mounted) return;
      final svc = context.read<AthanorService>();
      setState(() {});
      if (_reveal == null) _field.restFire(svc.dailyPourReady);
      _scheduleMidnight();
    });
  }

  /// Opens on the first batch still being poured into.
  String? _firstBatch(AthanorService svc) {
    final open = svc.batches.where((b) => !svc.isComplete(b.id));
    return (open.isNotEmpty ? open.first : svc.batches.firstOrNull)?.id;
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _field.step(dt);
    final r = _reveal;
    if (r != null) {
      r.step(dt * _field.speed);
      if (r.done) _endReveal(r);
    }
    _clock.value = _field.time;
  }

  // ── pouring ────────────────────────────────────────────────────────────

  Offset _sourceFor(AthanorPayment payment, AthanorLayout layout) {
    final key = switch (payment) {
      AthanorPayment.tincture => _tinctureKey,
      AthanorPayment.gold => _goldKey,
      AthanorPayment.daily => null,
    };
    final box = key?.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (box is RenderBox && me is RenderBox && box.hasSize) {
      return box.localToGlobal(box.size.center(Offset.zero), ancestor: me);
    }
    // The free pour comes down out of the dark over the furnace.
    return Offset(layout.size.width / 2, layout.fieldTop - 12);
  }

  Future<void> _pour(AthanorPayment payment) async {
    final layout = _layout;
    final id = _batchId;
    if (_reveal != null || layout == null || id == null) return;
    final svc = context.read<AthanorService>();
    final batch = svc.batchById(id);
    if (batch == null || !svc.canPour(id, payment)) {
      HapticFeedback.selectionClick();
      return;
    }
    if (payment == AthanorPayment.gold) {
      final ok = await showBracketConfirm(
        context,
        palette: AthanorTone.palette,
        accent: AthanorTone.gold,
        title: 'POUR GOLD',
        message:
            'Pour $kAthanorGoldPerPour gold into ${batch.name}. It gives one '
            "piece you don't own yet.",
        amounts: const [(CoinKind.gold, kAthanorGoldPerPour)],
        amountsLabel: 'YOU PAY',
        confirmLabel: 'POUR',
      );
      if (!ok || !mounted || _reveal != null) return;
    }
    final titleStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final reveal = AthanorReveal(
      field: _field,
      layout: layout,
      source: _sourceFor(payment, layout),
      payment: payment,
      onSound: (cue) {
        if (mounted) context.sound(cue);
      },
    );
    setState(() {
      _firstFire = 0;
      _reveal = reveal;
      // The pour's transaction is done long before the reveal shows what
      // it drew: until then the screen shows the batch as it was, with only
      // what was paid taken off.
      _held = _Shown.of(
        svc,
        spentTincture: payment == AthanorPayment.tincture
            ? kAthanorTincturePerPour
            : 0,
        spentGold: payment == AthanorPayment.gold ? kAthanorGoldPerPour : 0,
      );
    });
    unawaited(reveal.attach(svc.pour(id, payment), titleStyle: titleStyle));
  }

  void _endReveal(AthanorReveal r) {
    if (!identical(r, _reveal)) return;
    final svc = context.read<AthanorService>();
    final extras = r.failed ? null : r.result?.daily;
    setState(() {
      _reveal = null;
      // Shown now: the piece lit, one fewer left. The free pour's rewards
      // still hold the balances until they have been shown.
      if (extras == null) _held = null;
    });
    _field.restFire(svc.dailyPourReady);
    // After the frame: never from inside the ticker's callback.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      r.dispose();
      if (!mounted) return;
      if (r.failed) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('Nothing was poured.')));
      } else if (extras != null) {
        await _showDailyExtras(extras);
        if (mounted) setState(() => _held = null);
      }
    });
  }

  Future<void> _showDailyExtras(AthanorDailyExtras x) async {
    final vial = x.vialGroup;
    await showLootOpeningDialog(
      context: context,
      title: 'DAILY POUR',
      entries: [
        LootOpeningEntry(
          icon: AppIcons.monetization_on_rounded,
          coin: CoinKind.silver,
          label: '+${x.silver}',
          name: 'SILVER',
          color: const Color(0xFFB0BEC5),
        ),
        if (x.gold > 0)
          LootOpeningEntry(
            icon: AppIcons.monetization_on_rounded,
            coin: CoinKind.gold,
            label: '+${x.gold}',
            name: 'GOLD',
            color: const Color(0xFFFFD700),
          ),
        if (vial != null)
          LootOpeningEntry(
            icon: AppIcons.biotech_rounded,
            label: '×1',
            name: '${vial.displayName.toUpperCase()} VIAL',
            color: vial.skin.badge,
          ),
      ],
    );
  }

  void _onBack() {
    final r = _reveal;
    if (r == null) {
      VoidPortal.pop(context);
    } else if (r.atRest) {
      r.close();
    } else {
      r.skip();
    }
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AthanorService>();
    final shown = _held ?? _Shown.of(svc);
    return PopScope(
      canPop: _reveal == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: AthanorTone.void0,
        body: LayoutBuilder(
          builder: (context, box) {
            final pad = MediaQuery.paddingOf(context);
            final layout = _layout = AthanorLayout(box.biggest, pad);
            final reveal = _reveal;
            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: AthanorFieldPainter(
                        _field,
                        layout,
                        repaint: _clock,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: pad.top,
                  height: AthanorLayout.headerH,
                  child: _Chrome(
                    shown: _shown,
                    passage: widget.revealed != null,
                    child: _header(shown),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: layout.panelH,
                  child: AnimatedOpacity(
                    opacity: reveal == null ? 1 : 0,
                    duration: Duration(
                      milliseconds: reveal == null ? 700 : 400,
                    ),
                    curve: Curves.easeInOut,
                    child: IgnorePointer(
                      ignoring: reveal != null,
                      child: _Chrome(
                        shown: _shown,
                        passage: widget.revealed != null,
                        child: _loaded
                            ? _panel(svc, shown, pad)
                            : const SizedBox(),
                      ),
                    ),
                  ),
                ),
                // The first fire, said once, over the furnace's rising heat.
                if (_firstFire > 0 && reveal == null)
                  Positioned(
                    left: 20,
                    right: 20,
                    top: layout.fieldTop + 4,
                    child: _Chrome(
                      shown: _shown,
                      passage: widget.revealed != null,
                      child: _FirstFire(
                        amount: _firstFire,
                        onTap: () => setState(() => _firstFire = 0),
                      ),
                    ),
                  ),
                if (reveal != null)
                  Positioned.fill(
                    child: AthanorRevealView(
                      reveal: reveal,
                      clock: _clock,
                      onContinue: reveal.close,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(_Shown svc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 18, 10),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.chevron_left_rounded,
            palette: AthanorTone.palette,
            onTap: _onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'THE ATHANOR',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: athanorMono(11.5, AthanorTone.parchmentDim, spacing: 2.8),
            ),
          ),
          Row(
            key: _tinctureKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              const TinctureGlyph(size: 22, animate: false),
              const SizedBox(width: 3),
              Text(
                formatCoins(svc.tincture),
                style: athanorMono(
                  14,
                  AthanorTone.tinctureBright,
                  spacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          KeyedSubtree(
            key: _goldKey,
            child: CoinAmount(kind: CoinKind.gold, amount: svc.gold),
          ),
        ],
      ),
    );
  }

  /// [svc] does what is tapped; [shown] is what is shown.
  Widget _panel(AthanorService svc, _Shown shown, EdgeInsets pad) {
    final batches = shown.batches;
    final batch = _batchId == null ? null : shown.batchById(_batchId!);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF5060507), Color(0xE6060507), Color(0x00060507)],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + pad.bottom),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (batch == null) ...[
              const _Empty(
                title: 'No batches yet',
                line: 'Batches of pieces to pour for will appear here.',
              ),
              if (shown.dailyPourReady) _collectButton(svc),
            ] else ...[
              if (batches.length > 1) ...[
                _BatchStrip(
                  batches: batches,
                  selected: batch.id,
                  svc: shown,
                  onSelect: (id) => setState(() => _batchId = id),
                ),
                const SizedBox(height: 12),
              ],
              _BatchHead(
                batch: batch,
                svc: shown,
                onOdds: () => showAthanorOdds(
                  context,
                  batch: batch,
                  odds: shown.odds(batch.id),
                  capstoneGiven: shown.owns(batch.capstone.id),
                ),
              ),
              const SizedBox(height: 10),
              _PieceGrid(batch: batch, svc: shown),
              const SizedBox(height: 14),
              _actions(svc, shown, batch),
            ],
          ],
        ),
      ),
    );
  }

  /// The free daily, when there is no piece left to pour for: it pays what
  /// the home chest paid, without a draw.
  Widget _collectButton(AthanorService svc) => BracketButton(
    label: 'COLLECT DAILY',
    palette: AthanorTone.palette,
    accent: AthanorTone.brass,
    height: 46,
    enabled: !_collecting,
    onTap: () => _collectDaily(svc),
  );

  Future<void> _collectDaily(AthanorService svc) async {
    if (_collecting || _reveal != null) return;
    setState(() {
      _collecting = true;
      _firstFire = 0;
      // The balances say nothing of what came until it has been shown.
      _held = _Shown.of(svc);
    });
    final extras = await svc.takeDailyExtras();
    if (!mounted) return;
    setState(() => _collecting = false);
    _field.restFire(svc.dailyPourReady);
    if (extras != null) {
      context.sound(SoundCue.rewardCollect);
      await _showDailyExtras(extras);
    }
    if (mounted) setState(() => _held = null);
  }

  Widget _actions(AthanorService svc, _Shown shown, AthanorBatch batch) {
    if (shown.isComplete(batch.id)) {
      final open = shown.anyPiecesLeft;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                open
                    ? 'This batch is complete. Choose another to pour into.'
                    : 'Every batch is complete.',
                textAlign: TextAlign.center,
                style: athanorBody(context, color: AthanorTone.parchment),
              ),
            ),
          ),
          // With nothing left anywhere the free daily still pays.
          if (!open && shown.dailyPourReady) ...[
            const SizedBox(height: 6),
            _collectButton(svc),
          ],
        ],
      );
    }
    final daily = shown.dailyPourReady;
    final tincture = shown.canPour(batch.id, AthanorPayment.tincture);
    final gold = shown.canPour(batch.id, AthanorPayment.gold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (daily) ...[
          BracketButton(
            label: 'FREE POUR',
            palette: AthanorTone.palette,
            accent: AthanorTone.brass,
            height: 46,
            onTap: () => _pour(AthanorPayment.daily),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: _PourButton(
                cost: '$kAthanorTincturePerPour TINCTURE',
                icon: const TinctureGlyph(size: 16, animate: false),
                accent: AthanorTone.tincture,
                // The pour to make is lit: the free one, else the first
                // that can be paid for.
                lit: !daily && tincture,
                enabled: tincture,
                onTap: () => _pour(AthanorPayment.tincture),
              ),
            ),
            if (shown.goldPoursAvailable) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _PourButton(
                  cost: '$kAthanorGoldPerPour GOLD',
                  icon: const CoinIcon(kind: CoinKind.gold, size: 13),
                  accent: AthanorTone.gold,
                  lit: !daily && !tincture && gold,
                  enabled: gold,
                  onTap: () => _pour(AthanorPayment.gold),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// What the header and panel show of the Athanor. Read fresh on every
/// build, except while a pour (or the free daily's collect) plays: then it
/// is held as it stood at the tap, with only what was paid taken off, so
/// nothing on the screen — a piece lit, what is left, the capstone, a
/// batch's count, a balance, the odds — tells the draw before the reveal
/// does.
class _Shown {
  _Shown.of(AthanorService svc, {int spentTincture = 0, int spentGold = 0})
    : batches = svc.batches,
      tincture = svc.tincture - spentTincture,
      gold = svc.gold - spentGold,
      dailyPourReady = svc.dailyPourReady,
      goldPoursAvailable = svc.goldPoursAvailable,
      anyPiecesLeft = svc.anyPiecesLeft,
      _drawn = {for (final b in svc.batches) b.id: Set.of(svc.drawnIn(b.id))},
      _complete = {
        for (final b in svc.batches)
          if (svc.isComplete(b.id)) b.id,
      },
      _owned = {
        for (final b in svc.batches)
          for (final p in [...b.pieces, b.capstone])
            if (svc.ownsPiece(p.id)) p.id,
      },
      _canPour = {
        for (final b in svc.batches)
          for (final p in AthanorPayment.values)
            if (svc.canPour(b.id, p)) (b.id, p),
      },
      _odds = {for (final b in svc.batches) b.id: svc.nextPourOdds(b.id)};

  final List<AthanorBatch> batches;
  final int tincture, gold;
  final bool dailyPourReady, goldPoursAvailable, anyPiecesLeft;
  final Map<String, Set<String>> _drawn;
  final Set<String> _complete, _owned;
  final Set<(String, AthanorPayment)> _canPour;
  final Map<String, List<(AthanorPiece, double)>> _odds;

  AthanorBatch? batchById(String id) {
    for (final b in batches) {
      if (b.id == id) return b;
    }
    return null;
  }

  Set<String> drawnIn(String batchId) => _drawn[batchId] ?? const {};
  bool isComplete(String batchId) => _complete.contains(batchId);
  bool owns(String pieceId) => _owned.contains(pieceId);
  bool canPour(String batchId, AthanorPayment p) =>
      _canPour.contains((batchId, p));

  /// The next pour's odds, as the service gave them.
  List<(AthanorPiece, double)> odds(String batchId) =>
      _odds[batchId] ?? const [];
}

/// The share of the passage's way back in which the page sinks away, before
/// the furnace gathers home (PassageScene.backSplit, the Athanor's own).
const double _kBackSplit = 0.65;

/// The screen's chrome: up once the passage has given way, and down again
/// with the page as the way back begins, so nothing is left standing when
/// the passage's furnace takes over from the screen's.
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.shown,
    required this.passage,
    required this.child,
  });

  final bool shown;

  /// Came in through the emblem's passage (and so leaves through it).
  final bool passage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Held at a breath above nothing while hidden, never at nothing: at 0
    // its subtree is not painted, and its first paint (the piece art) would
    // land on the first frame it comes up instead of under the passage.
    final faded = AnimatedOpacity(
      opacity: shown ? 1 : 0.004,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      child: child,
    );
    final anim = passage ? ModalRoute.of(context)?.animation : null;
    if (anim == null) return faded;
    return AnimatedBuilder(
      animation: anim,
      child: faded,
      builder: (context, child) {
        final leaving =
            anim.status == AnimationStatus.reverse ||
            anim.status == AnimationStatus.dismissed;
        if (!leaving) return child!;
        final k = ((anim.value - _kBackSplit) / (1 - _kBackSplit)).clamp(
          0.0,
          1.0,
        );
        return Opacity(opacity: k, child: child);
      },
    );
  }
}

/// A paid pour: POUR, and what it costs under it.
class _PourButton extends StatelessWidget {
  const _PourButton({
    required this.cost,
    required this.icon,
    required this.accent,
    required this.lit,
    required this.enabled,
    required this.onTap,
  });

  final String cost;
  final Widget icon;
  final Color accent;
  final bool lit, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AthanorTone.palette;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'POUR · $cost',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.42,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: context.soundAction(enabled ? onTap : null),
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: lit ? accent : p.line,
              strokeWidth: 1.3,
            ),
            child: Container(
              height: 50,
              color: lit
                  ? p.accentWash(accent, darkAlpha: 0.16)
                  : p.surfaceMutedFill(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('POUR', style: athanorMono(13, p.ink, spacing: 1.6)),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 5),
                      Text(
                        cost,
                        style: athanorMono(
                          10,
                          Color.lerp(accent, p.ink, 0.35)!,
                          spacing: 1.4,
                        ),
                      ),
                    ],
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

class _FirstFire extends StatelessWidget {
  const _FirstFire({required this.amount, required this.onTap});

  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AthanorTone.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: const BracketFramePainter(
          color: AthanorTone.tincture,
          strokeWidth: 1.2,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: p.accentWash(AthanorTone.tincture, darkAlpha: 0.12),
          child: Row(
            children: [
              const TinctureGlyph(size: 22, animate: false),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "The Athanor's first fire: +$amount tincture",
                  style: athanorBody(context, color: AthanorTone.parchment),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.line});

  final String title, line;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 30),
    child: Column(
      children: [
        Text(title, style: athanorName(context, 22)),
        const SizedBox(height: 8),
        Text(line, textAlign: TextAlign.center, style: athanorBody(context)),
      ],
    ),
  );
}

/// Which batch to pour into, when there is more than one.
class _BatchStrip extends StatelessWidget {
  const _BatchStrip({
    required this.batches,
    required this.selected,
    required this.svc,
    required this.onSelect,
  });

  final List<AthanorBatch> batches;
  final String selected;
  final _Shown svc;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = AthanorTone.palette;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: batches.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final b = batches[i];
          final on = b.id == selected;
          final drawn = svc.drawnIn(b.id).length;
          final done = svc.isComplete(b.id);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(() {
              if (on) return;
              HapticFeedback.selectionClick();
              onSelect(b.id);
            }),
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: on ? AthanorTone.brass : p.line,
                strokeWidth: on ? 1.3 : 1,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                color: on
                    ? p.accentWash(AthanorTone.brass, darkAlpha: 0.16)
                    : p.surfaceMutedFill(),
                child: Text(
                  '${b.name.toUpperCase()}  '
                  '${done ? 'DONE' : '$drawn/${b.pieces.length}'}',
                  style: athanorMono(10.5, on ? p.ink : p.muted, spacing: 1.4),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BatchHead extends StatelessWidget {
  const _BatchHead({
    required this.batch,
    required this.svc,
    required this.onOdds,
  });

  final AthanorBatch batch;
  final _Shown svc;
  final VoidCallback onOdds;

  @override
  Widget build(BuildContext context) {
    final total = batch.pieces.length;
    final left = total - svc.drawnIn(batch.id).length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                batch.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: athanorName(context, 22),
              ),
              const SizedBox(height: 4),
              Text(
                left == 0 ? 'COMPLETE' : '$left OF $total LEFT',
                style: athanorMono(
                  10.5,
                  left == 0 ? AthanorTone.brassGlow : AthanorTone.brass,
                  spacing: 2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 86,
          child: BracketButton(
            label: 'ODDS',
            primary: false,
            height: 36,
            palette: AthanorTone.palette,
            accent: AthanorTone.brass,
            onTap: onOdds,
          ),
        ),
      ],
    );
  }
}

/// The batch's pieces, then its capstone.
class _PieceGrid extends StatelessWidget {
  const _PieceGrid({required this.batch, required this.svc});

  final AthanorBatch batch;
  final _Shown svc;

  @override
  Widget build(BuildContext context) {
    final drawn = svc.drawnIn(batch.id);
    final capOwned = svc.owns(batch.capstone.id);
    final tiles = [
      for (final p in batch.pieces) (p, drawn.contains(p.id), false),
      (batch.capstone, capOwned, true),
    ];
    final cols = ((tiles.length + 1) ~/ 2).clamp(4, 6);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 7.0;
        final side = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (piece, owned, cap) in tiles)
              SizedBox.square(
                dimension: side,
                child: _Tile(piece: piece, owned: owned, capstone: cap),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.piece,
    required this.owned,
    required this.capstone,
  });

  final AthanorPiece piece;
  final bool owned, capstone;

  @override
  Widget build(BuildContext context) {
    final p = AthanorTone.palette;
    final ink = capstone
        ? AthanorTone.capstone
        : AthanorTone.rarity(piece.rarity);
    final look = owned
        ? AthanorPieceLook.lit
        : (capstone ? AthanorPieceLook.sealed : AthanorPieceLook.ghost);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(
        () => _showPiece(context, piece, owned: owned, capstone: capstone),
      ),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: owned ? ink.withValues(alpha: 0.85) : p.lineSoft,
        ),
        child: Container(
          color: owned
              ? p.accentWash(ink, darkAlpha: 0.08)
              : p.bg1.withValues(alpha: 0.5),
          padding: const EdgeInsets.all(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Lit as the panel comes back after its reveal, not snapped.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: AthanorPieceArt(
                  key: ValueKey(look),
                  piece: piece,
                  look: look,
                ),
              ),
              if (capstone)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'CAPSTONE',
                    maxLines: 1,
                    style: athanorMono(
                      7,
                      owned ? AthanorTone.capstone : AthanorTone.muted,
                      spacing: 1.2,
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

/// A piece, close to: what it is and whether it is owned.
Future<void> _showPiece(
  BuildContext context,
  AthanorPiece piece, {
  required bool owned,
  required bool capstone,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.7),
  builder: (ctx) {
    final p = AthanorTone.palette;
    final ink = capstone
        ? AthanorTone.capstone
        : AthanorTone.rarity(piece.rarity);
    final status = owned
        ? 'Owned.'
        : capstone
        ? 'Comes with the last piece of the batch.'
        : 'Not drawn yet.';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        color: p.bg1,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: AthanorPieceArt(
                piece: piece,
                look: owned || !capstone
                    ? AthanorPieceLook.lit
                    : AthanorPieceLook.sealed,
                animate: owned,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              capstone
                  ? 'CAPSTONE  ·  ${athanorKindLabel(piece.kind)}'
                  : '${piece.rarity.label}  ·  ${athanorKindLabel(piece.kind)}',
              style: athanorMono(10, ink, spacing: 2),
            ),
            const SizedBox(height: 6),
            Text(piece.name, style: athanorName(ctx, 22)),
            const SizedBox(height: 8),
            Text(piece.description, style: athanorBody(ctx)),
            const SizedBox(height: 6),
            Text(status, style: athanorBody(ctx, color: AthanorTone.parchment)),
            const SizedBox(height: 16),
            BracketButton(
              label: 'CLOSE',
              primary: false,
              height: 40,
              palette: p,
              accent: AthanorTone.brass,
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  },
);
