// lib/screens/scenes/rift_threshold.dart
//
// THE RIFT THRESHOLD — what a wilderness rift shows when it is tapped: the
// rift itself, a disk of grains in the faction's color falling into a black
// core, and the key that opens it.
//
// Holding the button turns the key; the rift spins up as it turns. Let go
// early and nothing is spent. Once it has turned, the key is spent, flies into
// the core, and the camera falls in after it — the screen ends black, and
// the rift opens out of that black (enterRift).
//
// One ticker and one painter; the rift itself is RiftVortexField.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/inventory.dart' show InvKeys;
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/grain_loader.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/element_resource_glyph.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:alchemons/widgets/harvester_glyph.dart';
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ── the screen ───────────────────────────────────────────────────────────────

/// Opens [faction]'s threshold over the current screen, wired to the save:
/// the player's keys and gold, and the Shop's key for this faction, so one
/// can be bought on the spot. [onEnter] runs once the key is spent and the
/// threshold has fallen to black, with the threshold's own context and the
/// species waiting inside — pass both to [enterRift].
///
/// Who waits inside is settled here, before the key turns: nothing in a
/// rift can be fused, so the key only turns for a player holding a
/// harvester that can catch it. [seed] names the rift, so opening the same
/// one again finds the same species; without it each opening rolls anew.
///
/// With [from], the threshold grows out of the rift that was tapped, and
/// stepping back shrinks it into that rift again; without, it fades in.
Future<void> showRiftThreshold(
  BuildContext context, {
  required RiftFaction faction,
  required Future<void> Function(
    BuildContext thresholdContext,
    Creature? species,
  )
  onEnter,
  RiftOrigin? from,
  int? seed,
  String? closesIn,
  bool partyEnters = true,
}) {
  final db = context.read<AlchemonsDatabase>();
  final shop = context.read<ShopService>();
  final keyId = InvKeys.portalKeyForFaction(faction.name);
  final offerId = 'key.portal.${faction.name}';
  final offer = ShopService.allOffers.where((o) => o.id == offerId).firstOrNull;
  final species = pickRiftSpecies(
    context.read<CreatureCatalog>(),
    faction,
    math.Random(seed),
  );
  final harvester = species == null
      ? null
      : _harvesterNeedFor(species, context.read<CatchService>(), shop, db);
  return Navigator.of(context).push(
    riftThresholdRoute(
      from: from,
      builder: (ctx) => RiftThreshold(
        faction: faction,
        from: from,
        closesIn: closesIn,
        partyEnters: partyEnters,
        loadKeys: () => db.inventoryDao.getItemQty(keyId),
        spendKey: () async {
          // Checked again here: a key can go between opening this and
          // turning it.
          if (await db.inventoryDao.getItemQty(keyId) <= 0) return false;
          await db.inventoryDao.addItemQty(keyId, -1);
          return true;
        },
        loadGold: () async =>
            (await db.currencyDao.getAllCurrencies())['gold'] ?? 0,
        keyPrice: offer == null ? null : shop.getEffectiveCost(offer)['gold'],
        buyKey: offer == null ? null : () => shop.purchase(offerId),
        harvester: harvester,
        onEnter: () => onEnter(ctx, species),
      ),
    ),
  );
}

/// The route a threshold opens in. Grown out of the rift [from], it draws
/// its own way in — the rift growing, the void spreading round it — and is
/// opaque only once grown, so the screen behind shows round it meanwhile;
/// stepping back shrinks it into that rift again. Without [from] it fades.
PageRoute<void> riftThresholdRoute({
  required RiftOrigin? from,
  required WidgetBuilder builder,
}) => PageRouteBuilder<void>(
  opaque: true,
  transitionDuration: Duration(milliseconds: from == null ? 420 : 950),
  reverseTransitionDuration: Duration(milliseconds: from == null ? 220 : 650),
  pageBuilder: (ctx, animation, secondary) => builder(ctx),
  transitionsBuilder: (ctx, animation, secondary, child) => from != null
      ? child
      : FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        ),
);

/// A rift as it stands on the screen behind its threshold — the one that
/// was tapped — so the threshold can grow out of it, step back into it, and
/// the way out of the rift can open where it was.
class RiftOrigin {
  const RiftOrigin({
    required this.centre,
    required this.radius,
    this.core = 0.27,
    this.density = 0.3,
    this.grain,
    this.hide,
  });

  /// Its middle, global, and its disk's radius on the screen.
  final Offset centre;
  final double radius;

  /// Its core, as a fraction of [radius].
  final double core;

  /// How many grains it draws against a threshold's.
  final double density;

  /// Its grains' diameter on the screen; null for the threshold's own.
  final double? grain;

  /// Hides it (true) while the threshold stands in for it, and shows it
  /// again (false).
  final void Function(bool hidden)? hide;
}

/// The harvester a rift asks for: any the player holds that can catch
/// [species], and the Shop's harvester for its element to buy when there is
/// none — the one the encounter's Harvest button would draw.
RiftHarvesterNeed _harvesterNeedFor(
  Creature species,
  CatchService catches,
  ShopService shop,
  AlchemonsDatabase db,
) {
  final group = elementalGroupOf(species);
  final biome = group == null ? universalHarvester : groupIdFrom(group);
  final offerId = group == null
      ? 'device.harvest.guaranteed'
      : 'device.harvest.std.$biome';
  final offer = ShopService.allOffers.where((o) => o.id == offerId).firstOrNull;
  return RiftHarvesterNeed(
    fitting: [
      for (final device in CatchDeviceType.values)
        if (catches.canUseDevice(device, species))
          device.label.replaceAll(' Harvester', ''),
    ],
    biome: biome,
    load: () async {
      var held = 0;
      for (final device in await catches.getUsableDevices(species)) {
        held += await catches.getDeviceCount(device);
      }
      return held;
    },
    loadWallet: db.currencyDao.getAllCurrencies,
    price: offer == null ? null : shop.getEffectiveCost(offer),
    buy: offer == null ? null : () => shop.purchase(offerId),
  );
}

/// Takes a fallen threshold straight into the rift: its fall into the core
/// is the whole transition, so the rift replaces it on that black frame and
/// tears open round its Alchemon. Leaving the rift lands back where it was
/// found. Completes with the rift's result: true once something was bred or
/// caught there.
///
/// [returnTo] is the orientation of the screen behind: from a portrait one
/// the phone is turned to the rift's landscape while the screen is black.
/// [species] is the one the threshold settled on.
///
/// The rift is left through black too: it goes dark and is popped under a
/// black sheet, the phone is turned back while only black shows, and
/// [onReturn] runs with the result while the screen behind is still hidden
/// — clear a spent rift there, so it is gone before it can be seen. Then
/// the black opens out from where the rift was ([from]).
Future<bool?> enterRift(
  BuildContext thresholdContext, {
  required RiftFaction faction,
  Creature? species,
  List<PartyMember> party = const [],
  required List<DeviceOrientation> returnTo,
  RiftOrigin? from,
  FutureOr<void> Function(bool? result)? onReturn,
}) async {
  final fromPortrait = returnTo.contains(DeviceOrientation.portraitUp);
  final exit = RiftExitSheet();
  try {
    final result = await VoidPortal.replaceInBlack<bool>(
      thresholdContext,
      page: RiftPortalScreen(
        faction: faction,
        party: party,
        species: species,
        returnOrientation: returnTo,
        exit: exit,
      ),
      orientation: fromPortrait
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : null,
      returnOrientation: fromPortrait ? returnTo : null,
    );
    if (exit.covering) {
      // Turned back on black: wait for the window, then for the screen
      // behind to lay itself out at its own size.
      if (fromPortrait) await _awaitWindow(wide: false);
      for (var i = 0; i < 3; i++) {
        await SchedulerBinding.instance.endOfFrame;
      }
    }
    await onReturn?.call(result);
    unawaited(exit.open(at: from?.centre));
    return result;
  } catch (_) {
    exit.remove();
    rethrow;
  }
}

/// Until the window is [wide] (or not), or plainly will not be.
Future<void> _awaitWindow({required bool wide}) async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  bool isWide() => view.physicalSize.width > view.physicalSize.height;
  final began = DateTime.now();
  while (isWide() != wide &&
      DateTime.now().difference(began) < const Duration(seconds: 1)) {
    await SchedulerBinding.instance.endOfFrame;
  }
}

/// What a rift asks of the kit besides its key: a harvester that can catch
/// the Alchemon inside. Nothing in a rift can be fused, so a key turned
/// without one would be spent for nothing.
class RiftHarvesterNeed {
  const RiftHarvesterNeed({
    required this.fitting,
    required this.biome,
    required this.load,
    this.loadWallet,
    this.price,
    this.buy,
  });

  /// The harvesters that can catch it, by name: "Volcanic", "Stabilized".
  final List<String> fitting;

  /// The harvester offered when none is held, as [HarvesterGlyph] takes it.
  final String biome;

  /// How many harvesters the player holds that can catch it.
  final Future<int> Function() load;

  /// The player's currencies, and that harvester's Shop price and purchase.
  /// Without all three the screen does not offer one.
  final Future<Map<String, int>> Function()? loadWallet;
  final Map<String, int>? price;
  final Future<bool> Function()? buy;
}

/// The rift's threshold: the rift, what is inside it, and the key.
class RiftThreshold extends StatefulWidget {
  const RiftThreshold({
    super.key,
    required this.faction,
    required this.loadKeys,
    required this.spendKey,
    required this.onEnter,
    this.loadGold,
    this.buyKey,
    this.keyPrice,
    this.harvester,
    this.from,
    this.closesIn,
    this.partyEnters = true,
  });

  final RiftFaction faction;

  /// The rift that was tapped, which this one grows out of; null opens the
  /// rift where it stands.
  final RiftOrigin? from;

  /// How many of this faction's keys the player holds.
  final Future<int> Function() loadKeys;

  /// Spends one key; false if there was none to spend.
  final Future<bool> Function() spendKey;

  /// Runs once the key is spent and the screen has gone black.
  final Future<void> Function() onEnter;

  /// The player's gold, for buying a key here. With [buyKey] and
  /// [keyPrice]; without all three the screen does not offer one.
  final Future<int> Function()? loadGold;
  final Future<bool> Function()? buyKey;
  final int? keyPrice;

  /// The harvester the key waits for; null asks for none.
  final RiftHarvesterNeed? harvester;

  /// How long the rift stays open, e.g. "7h 12m".
  final String? closesIn;

  /// Whether the player's party goes in too (the wilderness) or the player
  /// goes alone (space).
  final bool partyEnters;

  @override
  State<RiftThreshold> createState() => _RiftThresholdState();
}

class _RiftThresholdState extends State<RiftThreshold>
    with SingleTickerProviderStateMixin {
  final RiftVortexField _field = RiftVortexField();
  late final RiftPalette _pal = RiftPalette(widget.faction.primaryColor);
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  final GlobalKey _keyGlyph = GlobalKey();
  final GlobalKey _stack = GlobalKey();
  Duration _last = Duration.zero;

  int? _keys;
  int? _gold;
  bool _buying = false;
  String? _note;

  /// Harvesters held that can catch what is inside, and the wallet to buy
  /// one from; both stay null when the rift asks for none.
  int? _harvesters;
  Map<String, int>? _wallet;
  bool _buyingHarvester = false;

  /// The rift asks for a harvester the player does not have yet.
  bool get _needsHarvester => widget.harvester != null && _harvesters == 0;

  /// How far the key has been turned, 0..1.
  final ValueNotifier<double> _turn = ValueNotifier(0);
  bool _holding = false;
  int _lastTick = 0;

  /// Set once the key has turned: from here it is spent and going in.
  bool _committed = false;

  /// The key is spent: until then it waits in place.
  bool _spent = false;

  /// The key coming apart into grains where it stood when it turned,
  /// [_keyT] of the way into the core.
  RiftKeyGrains? _key;
  double _keyT = 0;

  static const double _turnSeconds = 0.9;
  static const double _diveSeconds = 1.0;

  /// How far the key's grains are in when the fall begins: it overlaps
  /// their last turns round the core.
  static const double _diveFrom = 0.8;

  /// The route's way in and out, which is the rift growing out of the one
  /// tapped and shrinking back into it.
  Animation<double>? _route;

  /// 0 standing in for the tapped rift, 1 grown.
  double get _grow {
    final route = _route;
    if (widget.from == null || route == null) return 1;
    return Curves.easeInOutCubic.transform(route.value.clamp(0.0, 1.0));
  }

  @override
  void initState() {
    super.initState();
    // Grown out of a rift, it is open already; and the rift it grew out of
    // gives way to it.
    if (widget.from != null) {
      _field.open = 1;
      widget.from!.hide?.call(true);
    }
    _ticker = createTicker(_tick)..start();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context)?.animation;
    if (!identical(route, _route)) {
      _route?.removeStatusListener(_routeStatus);
      _route = route?..addStatusListener(_routeStatus);
    }
  }

  /// Stepped back all the way: the rift it grew out of shows again.
  void _routeStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) widget.from?.hide?.call(false);
  }

  Future<void> _load() async {
    final keys = await widget.loadKeys();
    final gold = await widget.loadGold?.call();
    final need = widget.harvester;
    final harvesters = await need?.load();
    final wallet = harvesters == 0 ? await need?.loadWallet?.call() : null;
    if (!mounted) return;
    setState(() {
      _keys = keys;
      _gold = gold;
      _harvesters = harvesters;
      _wallet = wallet;
    });
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_routeStatus);
    widget.from?.hide?.call(false);
    _ticker.dispose();
    _clock.dispose();
    _turn.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final f = _field;
    f.open = math.min(1, f.open + dt / 1.1);

    if (!_committed) {
      var turn = _turn.value;
      turn = _holding
          ? math.min(1.0, turn + dt / _turnSeconds)
          : math.max(0.0, turn - dt / 0.35);
      final ticks = (turn * 3).floor();
      if (_holding && ticks > _lastTick && ticks < 3) {
        HapticFeedback.lightImpact();
      }
      _lastTick = ticks;
      _turn.value = turn;
      f.charge = turn;
      if (turn >= 1 && _holding) _commit();
    } else if (!_spent) {
      // Waiting on the spend; the rift keeps turning, the key holds.
    } else {
      if (_keyT < 1) {
        final was = _keyT;
        _keyT = math.min(1, _keyT + dt / RiftKeyGrains.seconds);
        // As the first of it is swallowed.
        if (was < 0.55 && _keyT >= 0.55) HapticFeedback.mediumImpact();
      }
      if ((_key == null || _keyT >= _diveFrom) && f.dive < 1) {
        f.dive = math.min(1, f.dive + dt / _diveSeconds);
        if (f.dive >= 1) {
          _ticker.stop();
          widget.onEnter();
        }
      }
    }
    f.step(dt);
    _clock.value = f.time;
  }

  Future<void> _commit() async {
    _holding = false;
    _committed = true;
    HapticFeedback.heavyImpact();
    // The key comes apart where it stands: the glyph in the panel, turned
    // a quarter round.
    final glyph = _keyGlyph.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (glyph != null && stack != null && glyph.attached) {
      final from = stack.globalToLocal(
        glyph.localToGlobal(glyph.size.center(Offset.zero)),
      );
      final color = _keyColor;
      _key = RiftKeyGrains(
        PortalKeyGlyph.grainsOf(_keySize, color, time: _field.time),
        from: from,
        color: color,
        angle: math.pi / 2,
        glyphSize: _keySize,
      );
    }
    setState(() {});
    final spent = await widget.spendKey();
    if (!mounted) return;
    _spent = spent;
    if (!spent) {
      // Someone else spent it (another screen, a restore): back to the
      // start, with nothing spent.
      setState(() {
        _committed = false;
        _key = null;
        _keyT = 0;
        _turn.value = 0;
        _note = 'That key is gone. Buy another to enter.';
      });
      await _load();
    }
  }

  Future<void> _buy() async {
    final buy = widget.buyKey;
    if (buy == null || _buying) return;
    setState(() {
      _buying = true;
      _note = null;
    });
    final ok = await buy();
    if (!mounted) return;
    setState(() {
      _buying = false;
      if (!ok) _note = 'The purchase did not go through.';
    });
    await _load();
  }

  Future<void> _buyHarvester() async {
    final buy = widget.harvester?.buy;
    if (buy == null || _buyingHarvester) return;
    setState(() {
      _buyingHarvester = true;
      _note = null;
    });
    final ok = await buy();
    if (!mounted) return;
    setState(() {
      _buyingHarvester = false;
      if (!ok) _note = 'The purchase did not go through.';
    });
    await _load();
  }

  /// The key in hand: the Shop's, in the Shop's color.
  static const double _keySize = 52;
  Color get _keyColor =>
      ElementResources.byBiomeId[widget.faction.name]?.color ??
      widget.faction.primaryColor;

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return PopScope(
      canPop: !_committed,
      child: Scaffold(
        // Grown out of a rift, the rift draws its own void as it grows.
        backgroundColor: widget.from == null
            ? const Color(0xFF050507)
            : Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final wide = size.width > size.height;
            final centre = wide
                ? Offset(size.width * 0.3, size.height * 0.5)
                : Offset(size.width * 0.5, size.height * 0.33);
            final radius = wide
                ? math.min(size.height * 0.42, size.width * 0.26)
                : math.min(size.width * 0.42, size.height * 0.24);
            // Upright, the words sit just under the rift rather than
            // floating in the middle of what is left.
            final panel = _Panel(state: this, top: !wide);
            return Stack(
              key: _stack,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _RiftPainter(
                        this,
                        centre,
                        radius,
                        repaint: _clock,
                      ),
                    ),
                  ),
                ),
                _PanelFade(
                  route: widget.from == null ? null : route,
                  child: SafeArea(
                    child: wide
                        ? Row(
                            children: [
                              SizedBox(width: size.width * 0.52),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    12,
                                    24,
                                    12,
                                  ),
                                  child: panel,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              SizedBox(height: size.height * 0.55),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    16,
                                  ),
                                  child: panel,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The words come in once the rift has grown, and go first when it steps
/// back.
class _PanelFade extends StatelessWidget {
  const _PanelFade({required this.route, required this.child});

  final Animation<double>? route;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    if (route == null) return child;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: route,
        curve: const Interval(0.55, 1, curve: Curves.easeOut),
        reverseCurve: const Interval(0.6, 1, curve: Curves.easeIn),
      ),
      child: child,
    );
  }
}

class _RiftPainter extends CustomPainter {
  _RiftPainter(this.s, this.centre, this.radius, {required super.repaint});

  final _RiftThresholdState s;
  final Offset centre;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final field = s._field;
    final from = s.widget.from;
    final g = s._grow;
    if (from == null || g >= 1) {
      field.paint(
        canvas,
        size,
        centre,
        radius,
        s._pal,
        key: s._key,
        keyT: s._keyT,
      );
      return;
    }
    // Growing out of the rift that was tapped: drawn as that one was —
    // where it stood, its size, its core, as few grains — and becoming this
    // one, the void spreading round it.
    final stack = s._stack.currentContext?.findRenderObject() as RenderBox?;
    final at = stack != null && stack.attached
        ? stack.globalToLocal(from.centre)
        : from.centre;
    double lerp(double a, double b) => a + (b - a) * g;
    final ownGrain = math.max(1.25, radius * 0.011);
    field.paint(
      canvas,
      size,
      Offset.lerp(at, centre, g)!,
      lerp(from.radius, radius),
      s._pal,
      fill: Curves.easeOut.transform((g / 0.8).clamp(0.0, 1.0)),
      density: lerp(from.density, 1),
      coreScale: lerp(from.core / field.core, 1),
      grain: from.grain == null ? null : lerp(from.grain!, ownGrain),
    );
  }

  @override
  bool shouldRepaint(_RiftPainter old) =>
      old.centre != centre || old.radius != radius;
}

const _mono = 'monospace';
const _parchment = Color(0xFFE6E2DA);
const _muted = Color(0xFF85827C);

class _Panel extends StatelessWidget {
  const _Panel({required this.state, this.top = false});

  final _RiftThresholdState state;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final w = s.widget;
    final color = w.faction.primaryColor;
    final name = w.faction.displayName;
    final keys = s._keys;
    final types = w.faction.matchingTypes.toList();

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          w.closesIn == null
              ? 'RIFT'
              : 'RIFT  ·  CLOSES IN ${w.closesIn!.toUpperCase()}',
          style: TextStyle(
            fontFamily: _mono,
            color: color.withValues(alpha: 0.85),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${name.toUpperCase()} RIFT',
          style: const TextStyle(
            fontFamily: _mono,
            color: _parchment,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final type in types)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: BreedConstants.getTypeColor(type),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    type,
                    style: TextStyle(
                      // Lifted towards parchment: Lava's and Blood's own
                      // reds sink into the void.
                      color: Color.lerp(
                        BreedConstants.getTypeColor(type),
                        _parchment,
                        0.3,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          w.partyEnters
              ? 'One Alchemon of these elements waits on the other side, '
                    'with one of six mutations, all equally likely. Your party '
                    'goes in with you.'
              : 'One Alchemon of these elements waits on the other side, '
                    'with one of six mutations, all equally likely.',
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (keys == null)
          const SizedBox(height: 104)
        // One need at a time, so the panel keeps its height on a landscape
        // phone: the key, then a harvester for what is inside, then the turn.
        else if (s._committed || (keys > 0 && !s._needsHarvester))
          _KeyAndTurn(state: s, keys: keys)
        else if (keys > 0)
          _NoHarvester(state: s)
        else
          _NoKey(state: s),
        if (s._note != null) ...[
          const SizedBox(height: 8),
          Text(
            s._note!,
            style: const TextStyle(
              color: Color(0xFFE07A66),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: s._committed
              ? null
              : context.soundAction(() => Navigator.of(context).maybePop()),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'STEP BACK',
              style: TextStyle(
                fontFamily: _mono,
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
          ),
        ),
      ],
    );

    // Once the key has turned, the words make way for the rift.
    return AnimatedOpacity(
      opacity: s._committed ? 0 : 1,
      duration: const Duration(milliseconds: 350),
      child: Align(
        alignment: top ? Alignment.topLeft : Alignment.center,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _KeyAndTurn extends StatelessWidget {
  const _KeyAndTurn({required this.state, required this.keys});

  final _RiftThresholdState state;
  final int keys;

  @override
  Widget build(BuildContext context) {
    final s = state;
    // Named in the key's own color, the one the Shop sells it in.
    final color =
        ElementResources.byBiomeId[s.widget.faction.name]?.color ??
        s.widget.faction.primaryColor;
    final name = s.widget.faction.displayName.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // The key in hand: it turns as the button is held, and is gone
            // once it flies.
            ValueListenableBuilder<double>(
              valueListenable: s._turn,
              builder: (context, turn, child) => Opacity(
                // Once turned, the rift draws it, coming apart.
                opacity: s._key != null ? 0 : 1,
                child: Transform.rotate(
                  angle: Curves.easeInOut.transform(turn) * math.pi / 2,
                  child: child,
                ),
              ),
              // The key exactly as the Shop sells it.
              child: PortalKeyGlyph(
                key: s._keyGlyph,
                biomeId: s.widget.faction.name,
                size: _RiftThresholdState._keySize,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name KEY  ×$keys',
                    style: TextStyle(
                      fontFamily: _mono,
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Entering spends one key.',
                    style: TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _HoldToTurn(state: s),
      ],
    );
  }
}

/// Hold to turn the key — the confirmation is the gesture: let go early and
/// nothing is spent.
class _HoldToTurn extends StatelessWidget {
  const _HoldToTurn({required this.state});

  final _RiftThresholdState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final color = s.widget.faction.primaryColor;
    void release() => s._holding = false;
    return Listener(
      onPointerDown: (_) {
        if (s._committed) return;
        s._holding = true;
        HapticFeedback.lightImpact();
      },
      onPointerUp: (_) => release(),
      onPointerCancel: (_) => release(),
      child: ValueListenableBuilder<double>(
        valueListenable: s._turn,
        builder: (context, turn, _) => _RiftPlate(
          color: color,
          lit: 0.55 + 0.45 * turn,
          child: Stack(
            children: [
              // The turn, filling from the left as the key goes round.
              FractionallySizedBox(
                widthFactor: turn,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.12),
                        color.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  turn > 0 ? 'TURNING…' : 'HOLD TO TURN THE KEY',
                  style: TextStyle(
                    fontFamily: _mono,
                    color: Color.lerp(color, _parchment, 0.45 + 0.4 * turn),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
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

class _NoKey extends StatelessWidget {
  const _NoKey({required this.state});

  final _RiftThresholdState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final w = s.widget;
    final color = w.faction.primaryColor;
    final name = w.faction.displayName.toUpperCase();
    final price = w.keyPrice;
    final gold = s._gold;
    final canOffer = w.buyKey != null && price != null && gold != null;
    final canAfford = canOffer && gold >= price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Opacity(
              opacity: 0.32,
              child: PortalKeyGlyph(
                biomeId: w.faction.name,
                size: 52,
                animate: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NO $name KEY',
                    style: const TextStyle(
                      fontFamily: _mono,
                      color: _parchment,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    w.closesIn == null
                        ? 'A $name key opens it.'
                        : 'The rift stays open for ${w.closesIn}.',
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (canOffer)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canAfford && !s._buying ? context.soundAction(s._buy) : null,
            child: _RiftPlate(
              color: color,
              lit: canAfford ? 1 : 0,
              child: s._buying
                  ? Center(child: GrainLoader(size: 16, color: color))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          canAfford ? 'BUY A KEY  ·  $price' : 'NEEDS $price',
                          style: TextStyle(
                            fontFamily: _mono,
                            color: canAfford
                                ? Color.lerp(color, _parchment, 0.45)
                                : _muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const CoinIcon.gold(size: 14),
                        if (!canAfford) ...[
                          const SizedBox(width: 8),
                          Text(
                            'YOU HAVE $gold',
                            style: const TextStyle(
                              fontFamily: _mono,
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          )
        else
          const Text(
            'Portal keys are sold in the Shop.',
            style: TextStyle(color: _muted, fontSize: 11.5),
          ),
      ],
    );
  }
}

/// A key in hand but no harvester that can catch what waits inside: the key
/// will not turn until there is one, and the one for its element can be
/// bought here.
class _NoHarvester extends StatelessWidget {
  const _NoHarvester({required this.state});

  final _RiftThresholdState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final need = s.widget.harvester!;
    final resource = ElementResources.byBiomeId[need.biome];
    final color = resource?.color ?? s.widget.faction.primaryColor;
    final price = need.price;
    final wallet = s._wallet;
    final canOffer = need.buy != null && price != null && wallet != null;
    final canAfford =
        canOffer && price.entries.every((e) => (wallet[e.key] ?? 0) >= e.value);
    final fitting = need.fitting.length < 2
        ? need.fitting.join()
        : '${need.fitting.sublist(0, need.fitting.length - 1).join(', ')} '
              'or ${need.fitting.last}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Opacity(
              opacity: 0.5,
              child: HarvesterGlyph(
                biomeId: need.biome,
                size: 52,
                animate: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NO HARVESTER',
                    style: TextStyle(
                      fontFamily: _mono,
                      color: _parchment,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Only $fitting Harvesters can catch the Alchemon inside.',
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (canOffer)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canAfford && !s._buyingHarvester
                ? context.soundAction(s._buyHarvester)
                : null,
            child: _RiftPlate(
              color: color,
              lit: canAfford ? 1 : 0,
              child: s._buyingHarvester
                  ? Center(child: GrainLoader(size: 16, color: color))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          canAfford
                              ? 'BUY ${resource?.biomeLabel.toUpperCase() ?? 'ONE'}  ·  '
                              : 'NEEDS  ',
                          style: TextStyle(
                            fontFamily: _mono,
                            color: canAfford
                                ? Color.lerp(color, _parchment, 0.45)
                                : _muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                        for (final e in price.entries) ...[
                          _CostIcon(currency: e.key),
                          const SizedBox(width: 3),
                          Text(
                            '${e.value}',
                            style: TextStyle(
                              fontFamily: _mono,
                              color: (wallet[e.key] ?? 0) >= e.value
                                  ? (canAfford ? _parchment : _muted)
                                  : const Color(0xFFE07A66),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (e.key != price.keys.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
            ),
          )
        else
          const Text(
            'Harvesters are sold in the Shop.',
            style: TextStyle(color: _muted, fontSize: 11.5),
          ),
      ],
    );
  }
}

/// The threshold's buttons in the kit's way: a dark plate washed in
/// [color], lit from below as [lit] nears 1, unlit (a price not met) at 0.
/// (Rounded outlined boxes until 2026-10.)
class _RiftPlate extends StatelessWidget {
  const _RiftPlate({
    required this.color,
    required this.lit,
    required this.child,
  });

  final Color color;
  final double lit;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: BracketFramePainter(
      color: lit <= 0
          ? BracketPalette.dark.line
          : color.withValues(alpha: 0.55 + 0.45 * lit.clamp(0.0, 1.0)),
      strokeWidth: 1.3,
    ),
    child: Container(
      height: 48,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFF0B0A0E),
          color,
          lit <= 0 ? 0.0 : 0.12,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    ),
  );
}

/// A price's currency: the gold and silver coins, or an element's glyph.
class _CostIcon extends StatelessWidget {
  const _CostIcon({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final resource = ElementResources.byKey[currency];
    return switch (currency) {
      'gold' => const CoinIcon.gold(size: 14),
      'silver' => const CoinIcon.silver(size: 14),
      _ when resource != null => ElementResourceGlyph.of(
        resource,
        size: 16,
        animate: false,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
