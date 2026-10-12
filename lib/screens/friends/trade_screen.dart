// lib/screens/friends/trade_screen.dart
//
// The trade table with one friend (lib/models/trade.dart). Their side above,
// the player's below, the table's sigil between: each half lights as that
// side confirms. Each puts one Alchemon up; a tap on either shows it in
// full. When both have confirmed the two trade places — each comes apart
// into grains of itself and streams across to the other's stage, where it
// stands up whole (lib/widgets/fx/trade_swap.dart) — and the one that
// arrived is the player's.
//
// The table is live: what the friend does shows as they do it. A trade that
// was done while the player was away plays when they next open the table.
// Under it, the week's trades: three, then 100 gold for three more.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/trade.dart';
import 'package:alchemons/screens/friends/trade_specimen_sheet.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart'
    show hydrateResident;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/trade_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/specimen_picker_route.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/cosmetics/case_style_art.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/grain_text.dart';
import 'package:alchemons/widgets/fx/trade_swap.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

const _palette = BracketPalette.dark;
const _brass = TradeSigil.brass;
const _brassBright = TradeSigil.brassBright;

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key, required this.friend});

  final FriendCard friend;

  static Route<void> route(FriendCard friend) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => TradeScreen(friend: friend),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: TradeSwap.duration,
  );
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _mineSprite = GlobalKey();
  final GlobalKey _theirSprite = GlobalKey();

  /// The trade playing, or played and not dismissed yet.
  TradeArrival? _arrival;
  TradeSwap? _field;
  Offset _minePos = Offset.zero, _theirPos = Offset.zero;
  bool _played = false;
  bool _busy = false;
  Timer? _clock;

  FriendCard get _friend => widget.friend;

  @override
  void initState() {
    super.initState();
    // The reset countdown, once a minute.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _swap.dispose();
    super.dispose();
  }

  // ── Doing ───────────────────────────────────────────────────────────────

  Future<void> _do(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on TradeException catch (e) {
      if (mounted) {
        showAppSnack(e.message, isError: true, fallbackContext: context);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final trades = context.read<TradeService>();
    final picked = await showSpecimenPickerRoute(
      context: context,
      theme: context.read<FactionTheme>(),
      searchHint: 'OFFER ${_friend.name.toUpperCase()}',
      prefsScopeKey: 'trade_picker',
      onWillSelectInstance: (inst) async {
        final why = await trades.whyNot(inst, friendUid: _friend.uid);
        if (why == null) return true;
        showAppSnack(why, isError: true);
        return false;
      },
    );
    if (picked == null || !mounted) return;
    await _do(() => trades.put(_friend, picked.instanceId));
  }

  Future<void> _confirm(TradeView v) async {
    final trades = context.read<TradeService>();
    final mine = trades.read(v.mine?.card),
        theirs = trades.read(v.theirs?.card);
    if (mine == null || theirs == null) return;
    final catalog = context.read<CreatureCatalog>();
    String nameOf(TradedCreature c) =>
        (c.instance.nickname?.trim().isNotEmpty ?? false)
        ? c.instance.nickname!.trim()
        : catalog.getCreatureById(c.instance.baseId)?.name ?? 'Alchemon';
    final last = v.theyReady;
    final ok = await showBracketConfirm(
      context,
      palette: _palette,
      accent: _brass,
      title: 'TRADE?',
      message:
          'Your ${nameOf(mine)} for ${_friend.name}\'s ${nameOf(theirs)}. '
          '${last ? "This can't be undone." : "Once ${_friend.name} confirms too, it is done and can't be undone."}',
      details: Text(
        'Uses 1 of your ${trades.left()} trades left this week.',
        style: caseMono(10.5, _palette.muted),
      ),
      confirmLabel: last ? 'TRADE' : 'CONFIRM',
    );
    if (!ok || !mounted) return;
    context.sound(SoundCue.uiConfirm);
    await _do(() async {
      final result = await trades.confirm(_friend);
      if (result == ConfirmResult.refreshed && mounted) {
        showAppSnack(
          'Your Alchemon changed since it went up. The table has it as it '
          'is now; both confirm again.',
          fallbackContext: context,
        );
      }
    });
  }

  Future<void> _buyMore() async {
    final trades = context.read<TradeService>();
    final ok = await showBracketConfirm(
      context,
      palette: _palette,
      accent: _brass,
      title: 'THREE MORE TRADES?',
      message: 'Three more trades this week.',
      amounts: const [(CoinKind.gold, TradeRules.resetGold)],
      amountsLabel: 'YOU PAY',
      confirmLabel: 'BUY',
    );
    if (!ok || !mounted) return;
    await _do(() async {
      final paid = await trades.buyMore();
      if (!mounted) return;
      if (!paid) {
        showAppSnack(
          'Not enough gold.',
          isError: true,
          fallbackContext: context,
        );
      } else {
        context.sound(SoundCue.purchaseSuccess);
      }
    });
  }

  void _show(TradedCreature? card, {String? owner}) {
    if (card == null) return;
    unawaited(showTradeSpecimenSheet(context, card, owner: owner));
  }

  // ── The trade, played ───────────────────────────────────────────────────

  /// Plays [arrival] once its two sprites are on screen to read.
  Future<void> _play(TradeArrival arrival) async {
    _arrival = arrival;
    _played = false;
    _field = null;
    setState(() {});
    // Let both sprites load and settle before reading them into grains.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || _arrival != arrival) return;
    final catalog = context.read<CreatureCatalog>();
    final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 2.6);
    Future<(SpecimenGrains, Offset)> read(
      GlobalKey key,
      TradedCreature c,
    ) async {
      final species = catalog.getCreatureById(c.instance.baseId);
      final element = species?.types.firstOrNull;
      final fallback = SpecimenGrains.disc(
        BreedConstants.getTypeColor(element ?? 'Fire'),
      );
      final box = key.currentContext?.findRenderObject();
      final stack = _stackKey.currentContext?.findRenderObject();
      if (box is! RenderRepaintBoundary || stack is! RenderBox) {
        return (fallback, Offset.zero);
      }
      final at = box.localToGlobal(
        box.size.center(Offset.zero),
        ancestor: stack,
      );
      try {
        final g = await SpecimenGrains.capture(box, pixelRatio: ratio);
        return (g ?? fallback, at);
      } catch (_) {
        return (fallback, at);
      }
    }

    final (mine, minePos) = await read(_mineSprite, arrival.gave);
    final (theirs, theirPos) = await read(_theirSprite, arrival.got);
    if (!mounted || _arrival != arrival) return;
    Color accentOf(TradedCreature c) => BreedConstants.getTypeColor(
      catalog.getCreatureById(c.instance.baseId)?.types.firstOrNull ?? 'Fire',
    );
    setState(() {
      _field = TradeSwap(
        a: mine,
        b: theirs,
        accentA: accentOf(arrival.gave),
        accentB: accentOf(arrival.got),
      );
      _minePos = minePos;
      _theirPos = theirPos;
    });
    context.sound(SoundCue.fusionPour);
    unawaited(HapticFeedback.mediumImpact());
    await _swap.forward(from: 0);
    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _played = true);
  }

  Future<void> _dismiss() async {
    final arrival = _arrival;
    if (arrival == null) return;
    await context.read<TradeService>().seen(arrival);
    if (!mounted) return;
    setState(() {
      _arrival = null;
      _field = null;
      _played = false;
    });
    _swap.value = 0;
  }

  Future<void> _seeIt() async {
    final arrival = _arrival;
    if (arrival == null) return;
    final catalog = context.read<CreatureCatalog>();
    final species = catalog.getCreatureById(arrival.got.instance.baseId);
    if (species == null) return;
    await CreatureDetailsDialog.show(
      context,
      species,
      true,
      instanceId: arrival.got.instance.instanceId,
    );
  }

  // ── Building ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final trades = context.watch<TradeService>();
    final view = trades.tableWith(_friend.uid);
    final waiting = trades.arrivalWith(_friend.uid);
    if (waiting != null && _arrival == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _arrival == null) unawaited(_play(waiting));
      });
    }
    final arrival = _arrival;

    // What stands on each stage: the table's two; during a trade, the two
    // trading places; after one, each where it went.
    final traded = view?.table.done ?? false;
    final mineCard =
        arrival?.gave ??
        trades.read((traded ? view?.theirs : view?.mine)?.card);
    final theirCard =
        arrival?.got ?? trades.read((traded ? view?.mine : view?.theirs)?.card);

    return Scaffold(
      backgroundColor: _palette.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) =>
                    _table(context, box, view, mineCard, theirCard),
              ),
            ),
            _footer(context, trades, view),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: Row(
      children: [
        BracketIconButton(
          icon: AppIcons.arrow_back_rounded,
          palette: _palette,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _friend.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cinzel(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _brassBright,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'TRADE TABLE',
                style: caseMono(10, _palette.muted, spacing: 3),
              ),
            ],
          ),
        ),
        // Balances the back button.
        const SizedBox(width: 38),
      ],
    ),
  );

  Widget _table(
    BuildContext context,
    BoxConstraints box,
    TradeView? view,
    TradedCreature? mineCard,
    TradedCreature? theirCard,
  ) {
    final h = box.maxHeight, w = box.maxWidth;
    // Two stages, and the sigil's own room between them.
    final stageH = ((h - 130) / 2).clamp(140.0, 236.0);
    final gap = h - stageH * 2 - 8;
    final sigilR = math.min(gap * 0.4, w * 0.17).clamp(26.0, 72.0);
    final arrival = _arrival;
    final iReady = view?.iReady ?? false;
    final theyReady = view?.theyReady ?? false;
    final done = arrival != null || (view?.table.done ?? false);
    return Stack(
      key: _stackKey,
      children: [
        // Their side.
        Positioned(
          left: 16,
          right: 16,
          top: 4,
          height: stageH,
          child: _Stage(
            label: "${_friend.name.toUpperCase()}'S",
            card: theirCard,
            after: arrival?.gave,
            spriteKey: _theirSprite,
            swap: _swap,
            confirmed: theyReady && !done,
            empty: 'Nothing up yet.',
            onTap: () =>
                _show(_played ? arrival?.gave : theirCard, owner: _friend.name),
          ),
        ),
        // The sigil between.
        Positioned(
          left: 0,
          right: 0,
          top: stageH,
          bottom: stageH,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _swap,
              builder: (context, _) => TweenAnimationBuilder<Offset>(
                tween: Tween(
                  end: Offset(
                    iReady || done ? 1 : 0,
                    theyReady || done ? 1 : 0,
                  ),
                ),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                builder: (context, lit, _) => CustomPaint(
                  painter: _SigilPainter(
                    lower: lit.dx,
                    upper: lit.dy,
                    radius: sigilR,
                    t: _field == null ? 0 : _swap.value,
                    // TRADED stands there instead, till it is dismissed.
                    hidden: _played,
                  ),
                ),
              ),
            ),
          ),
        ),
        // The player's side.
        Positioned(
          left: 16,
          right: 16,
          bottom: 4,
          height: stageH,
          child: _Stage(
            label: 'YOURS',
            card: mineCard,
            after: arrival?.got,
            spriteKey: _mineSprite,
            swap: _swap,
            confirmed: iReady && !done,
            empty: 'Tap to choose.',
            onEmptyTap: _busy ? null : _choose,
            onTap: () => _show(_played ? arrival?.got : mineCard),
          ),
        ),
        // The swap itself, over everything.
        if (_field != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SwapPainter(
                    field: _field!,
                    swap: _swap,
                    mine: _minePos,
                    theirs: _theirPos,
                  ),
                ),
              ),
            ),
          ),
        if (_played)
          Positioned(
            left: 0,
            right: 0,
            top: stageH,
            bottom: stageH,
            child: Center(
              child: GrainText(
                'TRADED',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: _brassBright,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer(BuildContext context, TradeService trades, TradeView? v) {
    final arrival = _arrival;
    final children = <Widget>[];
    if (arrival != null) {
      final catalog = context.read<CreatureCatalog>();
      final got = arrival.got.instance;
      final name = (got.nickname?.trim().isNotEmpty ?? false)
          ? got.nickname!.trim()
          : catalog.getCreatureById(got.baseId)?.name ?? 'It';
      children.addAll([
        _line(
          _played ? '$name is yours, from ${arrival.friendName}.' : 'Trading…',
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: _played ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: IgnorePointer(
            ignoring: !_played,
            child: Row(
              children: [
                Expanded(
                  child: BracketButton(
                    label: 'SEE IT',
                    primary: false,
                    palette: _palette,
                    accent: _brass,
                    onTap: _seeIt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BracketButton(
                    label: 'DONE',
                    palette: _palette,
                    accent: _brass,
                    onTap: _dismiss,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]);
    } else {
      children.addAll(_turn(trades, v));
    }
    children.addAll([const SizedBox(height: 14), _allowance(trades)]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  /// What this player can do now, and what the table is waiting on.
  List<Widget> _turn(TradeService trades, TradeView? v) {
    final them = _friend.name;
    final phase = v?.phase ?? TradePhase.empty;
    Widget button(String label, VoidCallback? onTap, {bool primary = true}) =>
        Expanded(
          child: BracketButton(
            label: label,
            primary: primary,
            enabled: onTap != null && !_busy,
            palette: _palette,
            accent: _brass,
            onTap: onTap ?? () {},
          ),
        );
    final none = trades.left() < 1;
    final (String text, List<Widget> buttons) = switch (phase) {
      TradePhase.empty => (
        'Choose an Alchemon to offer $them.',
        [button('CHOOSE', _choose)],
      ),
      TradePhase.waitingForThem => (
        'Waiting for $them to put one up.',
        [
          button(
            'TAKE BACK',
            () => _do(() => trades.takeBack(_friend.uid)),
            primary: false,
          ),
          const SizedBox(width: 10),
          button('CHANGE', _choose),
        ],
      ),
      TradePhase.yourTurn => (
        '$them put one up. Choose one to offer back.',
        [button('CHOOSE', _choose)],
      ),
      TradePhase.bothUp => (
        none
            ? 'No trades left this week.'
            : 'Confirm when the trade looks right.',
        [
          button('CHANGE', _choose, primary: false),
          const SizedBox(width: 10),
          button('CONFIRM', none ? null : () => _confirm(v!)),
        ],
      ),
      TradePhase.youConfirmed => (
        'Confirmed. Waiting for $them. Yours waits on the table.',
        [
          button(
            'UNDO CONFIRM',
            () => _do(() => trades.unconfirm(_friend.uid)),
            primary: false,
          ),
        ],
      ),
      TradePhase.theyConfirmed => (
        none
            ? '$them confirmed. No trades left this week.'
            : '$them confirmed. Confirm to trade.',
        [
          button('CHANGE', _choose, primary: false),
          const SizedBox(width: 10),
          button('TRADE', none ? null : () => _confirm(v!)),
        ],
      ),
      TradePhase.done => (
        v!.theyClaimed
            ? 'Traded. Choose another to trade again.'
            : 'Traded. Waiting for $them to collect theirs.',
        [button('CHOOSE', v.theyClaimed ? _choose : null)],
      ),
    };
    return [_line(text), const SizedBox(height: 12), Row(children: buttons)];
  }

  Widget _line(String text) => SizedBox(
    height: 36,
    child: Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          text,
          key: ValueKey(text),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: bracketText(
            context,
            13,
            _palette.ink.withValues(alpha: 0.85),
            weight: FontWeight.w600,
          ).copyWith(height: 1.3),
        ),
      ),
    ),
  );

  Widget _allowance(TradeService trades) {
    final now = DateTime.now();
    final left = trades.left(now);
    final resets = TradeRules.untilText(
      now,
      TradeRules.nextReset(now),
    ).toUpperCase();
    final text = !trades.allowanceKnown
        ? 'READING THIS WEEK\'S TRADES…'
        : left == 0
        ? 'NO TRADES LEFT  ·  MORE IN $resets'
        : '$left OF ${TradeRules.perWeek} TRADES LEFT THIS WEEK  ·  '
              'RESETS IN $resets';
    return Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: caseMono(9.5, _palette.muted, spacing: 1.4),
        ),
        if (trades.allowanceKnown && left == 0) ...[
          const SizedBox(height: 10),
          BracketButton(
            label: 'THREE MORE',
            height: 40,
            primary: false,
            enabled: !_busy,
            palette: _palette,
            accent: _brass,
            trailing: const CoinAmount(
              kind: CoinKind.gold,
              amount: TradeRules.resetGold,
              size: 13,
            ),
            onTap: _buyMore,
          ),
        ],
      ],
    );
  }
}

/// One side of the table: its Alchemon lit in its case, or the empty stage.
/// During a trade, [card] gives way to [after] as the swap ([swap]) runs.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.label,
    required this.card,
    required this.spriteKey,
    required this.swap,
    required this.confirmed,
    required this.empty,
    required this.onTap,
    this.after,
    this.onEmptyTap,
  });

  final String label;
  final TradedCreature? card, after;
  final GlobalKey spriteKey;
  final Animation<double> swap;
  final bool confirmed;
  final String empty;
  final VoidCallback onTap;
  final VoidCallback? onEmptyTap;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CreatureCatalog>();
    final now = card;
    final species = now == null ? null : hydrateResident(now.instance, catalog);
    final next = after;
    final nextSpecies = next == null
        ? null
        : hydrateResident(next.instance, catalog);
    final light = species == null ? _brass : caseElementLight(species);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: species == null ? onEmptyTap : context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: (confirmed ? _brassBright : light).withValues(
            alpha: confirmed ? 0.9 : 0.4,
          ),
          bracketSize: 12,
          strokeWidth: confirmed ? 1.6 : 1.1,
        ),
        child: ClipRect(
          child: AnimatedBuilder(
            animation: swap,
            builder: (context, child) {
              final t = swap.value;
              CustomPainter caseOf(TradedCreature? c, Color light) =>
                  c?.caseStyle == null
                  ? CaseLightPainter(
                      color: light,
                      strength: c == null ? 0.4 : 1,
                    )
                  : CaseStylePainter(style: c!.caseStyle!, color: light);
              final before = CustomPaint(painter: caseOf(now, light));
              if (next == null || nextSpecies == null || t <= 0) {
                return Stack(fit: StackFit.expand, children: [before, child!]);
              }
              // The case it stood in goes with it; the one coming stands up
              // round the grains as they land.
              final arrived = TradeSwap.arrivedOpacity(t);
              final gone = TradeSwap.leavingOpacity(t);
              return Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(
                    painter: CaseLightPainter(color: _brass, strength: 0.4),
                  ),
                  if (gone > 0) Opacity(opacity: gone, child: before),
                  if (arrived > 0)
                    Opacity(
                      opacity: arrived,
                      child: CustomPaint(
                        painter: caseOf(next, caseElementLight(nextSpecies)),
                      ),
                    ),
                  child!,
                ],
              );
            },
            child: LayoutBuilder(
              builder: (context, box) {
                final size = math.min(box.maxHeight * 0.7, box.maxWidth * 0.6);
                return Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 10,
                      right: 10,
                      child: Row(
                        children: [
                          Text(
                            label,
                            style: caseMono(10, kCaseGlassInk, spacing: 2),
                          ),
                          const Spacer(),
                          AnimatedOpacity(
                            opacity: confirmed ? 1 : 0,
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              'CONFIRMED',
                              style: caseMono(10, _brassBright, spacing: 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (species == null)
                      Center(
                        child: Text(
                          empty,
                          textAlign: TextAlign.center,
                          style: bracketText(
                            context,
                            13,
                            _palette.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      )
                    else ...[
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: box.maxHeight * 0.16,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: swap,
                            builder: (context, child) => Opacity(
                              opacity: next == null
                                  ? 1
                                  : TradeSwap.leavingOpacity(swap.value),
                              child: child,
                            ),
                            child: RepaintBoundary(
                              key: spriteKey,
                              child: InstanceSprite(
                                creature: species,
                                instance: now!.instance,
                                size: size,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (next != null && nextSpecies != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: box.maxHeight * 0.16,
                          child: Center(
                            child: AnimatedBuilder(
                              animation: swap,
                              builder: (context, child) {
                                final o = TradeSwap.arrivedOpacity(swap.value);
                                return o <= 0
                                    ? SizedBox.square(dimension: size)
                                    : Opacity(opacity: o, child: child);
                              },
                              child: InstanceSprite(
                                creature: nextSpecies,
                                instance: next.instance,
                                size: size,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 8,
                        child: AnimatedBuilder(
                          animation: swap,
                          builder: (context, _) {
                            if (next == null || nextSpecies == null) {
                              return _Caption(card: now, species: species);
                            }
                            // Each name goes with its Alchemon.
                            final t = swap.value;
                            final arrived = TradeSwap.arrivedOpacity(t);
                            return arrived > 0
                                ? Opacity(
                                    opacity: arrived,
                                    child: _Caption(
                                      card: next,
                                      species: nextSpecies,
                                    ),
                                  )
                                : Opacity(
                                    opacity: TradeSwap.leavingOpacity(t),
                                    child: _Caption(
                                      card: now,
                                      species: species,
                                    ),
                                  );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Its name, species and level, and its Potential, under it on the stage.
class _Caption extends StatelessWidget {
  const _Caption({required this.card, required this.species});

  final TradedCreature card;
  final Creature species;

  @override
  Widget build(BuildContext context) {
    final i = card.instance;
    final name = (i.nickname?.trim().isNotEmpty ?? false)
        ? i.nickname!.trim()
        : species.name;
    String p(double v) => v.round().toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kCaseGlassInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          [
            if (name != species.name) species.name.toUpperCase(),
            'LV ${i.level}',
            'POTENTIAL ${p(i.statSpeedPotential)} · '
                '${p(i.statIntelligencePotential)} · '
                '${p(i.statStrengthPotential)} · '
                '${p(i.statBeautyPotential)}',
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: caseMono(9, kCaseGlassInk.withValues(alpha: 0.7), spacing: 1),
        ),
      ],
    );
  }
}

class _SigilPainter extends CustomPainter {
  _SigilPainter({
    required this.lower,
    required this.upper,
    required this.radius,
    required this.t,
    this.hidden = false,
  });

  final double lower, upper, radius, t;
  final bool hidden;

  static final TradeSigil _sigil = TradeSigil();

  @override
  void paint(Canvas canvas, Size size) {
    if (hidden) return;
    final c = size.center(Offset.zero);
    final light = TradeSwap.light(t);
    paintLightPool(
      canvas,
      c,
      radius * 2,
      _brassBright,
      0.25 * (lower + upper) / 2 + 0.6 * light,
      squash: 1,
    );
    _sigil.paint(
      canvas,
      c,
      radius,
      lower: lower,
      upper: upper,
      // It loosens and drifts into the currents as the two go by, and is
      // gone by the time they land; it comes back after.
      scatter: t <= 0 || t >= 1 ? 0 : (t / 0.5).clamp(0.0, 1.0),
      opacity: t <= 0 || t >= 1 ? 1 : (t > 0.5 ? 0 : 1),
    );
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.lower != lower ||
      old.upper != upper ||
      old.radius != radius ||
      old.t != t ||
      old.hidden != hidden;
}

class _SwapPainter extends CustomPainter {
  _SwapPainter({
    required this.field,
    required this.swap,
    required this.mine,
    required this.theirs,
  }) : super(repaint: swap);

  final TradeSwap field;
  final Animation<double> swap;
  final Offset mine, theirs;

  @override
  void paint(Canvas canvas, Size size) {
    final t = swap.value;
    final light = TradeSwap.light(t);
    paintLightPool(canvas, mine + const Offset(0, 50), 110, _brass, light);
    paintLightPool(canvas, theirs + const Offset(0, 50), 110, _brass, light);
    field.paint(canvas, t, posA: mine, posB: theirs);
  }

  @override
  bool shouldRepaint(_SwapPainter old) =>
      old.field != field || old.mine != mine || old.theirs != theirs;
}
