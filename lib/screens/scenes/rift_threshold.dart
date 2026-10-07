// lib/screens/scenes/rift_threshold.dart
//
// THE RIFT THRESHOLD — what a wilderness rift shows when it is tapped: the
// rift itself, a disk of grains in the faction's colour falling into a black
// core, and the key that opens it.
//
// Holding the button turns the key; the rift spins up as it turns. Let go
// early and nothing is spent. Once it has turned, the key is spent, flies into
// the core, and the camera falls in after it — the screen ends black, and
// the rift opens out of that black (enterRift).
//
// One ticker and one painter; the rift itself is RiftVortexField.

import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/inventory.dart' show InvKeys;
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ── the screen ───────────────────────────────────────────────────────────────

/// Opens [faction]'s threshold over the current screen, wired to the save:
/// the player's keys and gold, and the Shop's key for this faction, so one
/// can be bought on the spot. [onEnter] runs once the key is spent and the
/// threshold has fallen to black, with the threshold's own context — pass
/// it to [enterRift].
Future<void> showRiftThreshold(
  BuildContext context, {
  required RiftFaction faction,
  required Future<void> Function(BuildContext thresholdContext) onEnter,
  String? closesIn,
  bool partyEnters = true,
}) {
  final db = context.read<AlchemonsDatabase>();
  final shop = context.read<ShopService>();
  final keyId = InvKeys.portalKeyForFaction(faction.name);
  final offerId = 'key.portal.${faction.name}';
  final offer = ShopService.allOffers.where((o) => o.id == offerId).firstOrNull;
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondary) => RiftThreshold(
        faction: faction,
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
        onEnter: () => onEnter(ctx),
      ),
      transitionsBuilder: (ctx, animation, secondary, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      ),
    ),
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
Future<bool?> enterRift(
  BuildContext thresholdContext, {
  required RiftFaction faction,
  List<PartyMember> party = const [],
  required List<DeviceOrientation> returnTo,
}) {
  final fromPortrait = returnTo.contains(DeviceOrientation.portraitUp);
  return VoidPortal.replaceInBlack<bool>(
    thresholdContext,
    page: RiftPortalScreen(
      faction: faction,
      party: party,
      returnOrientation: returnTo,
    ),
    orientation: fromPortrait
        ? const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : null,
    returnOrientation: fromPortrait ? returnTo : null,
  );
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
    this.closesIn,
    this.partyEnters = true,
  });

  final RiftFaction faction;

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

  /// How far the key has been turned, 0..1.
  final ValueNotifier<double> _turn = ValueNotifier(0);
  bool _holding = false;
  int _lastTick = 0;

  /// Set once the key has turned: from here it is spent and going in.
  bool _committed = false;

  /// The key is spent: until then it waits in place.
  bool _spent = false;
  Offset? _keyFrom;
  double _keyFlight = 0;

  static const double _turnSeconds = 0.9;
  static const double _flightSeconds = 0.55;
  static const double _diveSeconds = 1.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _load();
  }

  Future<void> _load() async {
    final keys = await widget.loadKeys();
    final gold = await widget.loadGold?.call();
    if (!mounted) return;
    setState(() {
      _keys = keys;
      _gold = gold;
    });
  }

  @override
  void dispose() {
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
    } else if (_keyFlight < 1) {
      _keyFlight = math.min(1, _keyFlight + dt / _flightSeconds);
      if (_keyFlight >= 1) HapticFeedback.mediumImpact();
    } else if (f.dive < 1) {
      f.dive = math.min(1, f.dive + dt / _diveSeconds);
      if (f.dive >= 1) {
        _ticker.stop();
        widget.onEnter();
      }
    }
    f.step(dt);
    _clock.value = f.time;
  }

  Future<void> _commit() async {
    _holding = false;
    _committed = true;
    HapticFeedback.heavyImpact();
    // Where the key starts its flight: the glyph in the panel.
    final glyph = _keyGlyph.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (glyph != null && stack != null && glyph.attached) {
      _keyFrom = stack.globalToLocal(
        glyph.localToGlobal(glyph.size.center(Offset.zero)),
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
        _keyFrom = null;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_committed,
      child: Scaffold(
        backgroundColor: const Color(0xFF050507),
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
                SafeArea(
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RiftPainter extends CustomPainter {
  _RiftPainter(this.s, this.centre, this.radius, {required super.repaint});

  final _RiftThresholdState s;
  final Offset centre;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) => s._field.paint(
    canvas,
    size,
    centre,
    radius,
    s._pal,
    keyFrom: s._keyFrom,
    keyFlight: s._keyFrom == null ? 0 : s._keyFlight,
    // The shop's key, in the shop's colour.
    keyColor: ElementResources.byBiomeId[s.widget.faction.name]?.color,
  );

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
              ? 'One prismatic Alchemon of these elements waits on the other '
                    'side. Your party goes in with you.'
              : 'One prismatic Alchemon of these elements waits on the other '
                    'side.',
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (keys == null)
          const SizedBox(height: 104)
        else if (keys > 0 || s._committed)
          _KeyAndTurn(state: s, keys: keys)
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
    // Named in the key's own colour, the one the Shop sells it in.
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
                opacity: s._keyFrom != null ? 0 : 1,
                child: Transform.rotate(
                  angle: Curves.easeInOut.transform(turn) * math.pi / 2,
                  child: child,
                ),
              ),
              // The key exactly as the Shop sells it.
              child: PortalKeyGlyph(
                key: s._keyGlyph,
                biomeId: s.widget.faction.name,
                size: 52,
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
        builder: (context, turn, _) => Container(
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0B0A0E),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: color.withValues(alpha: 0.45 + 0.5 * turn),
              width: 1.1,
            ),
          ),
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
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0B0A0E),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: canAfford
                      ? color.withValues(alpha: 0.8)
                      : const Color(0xFF3A3530),
                  width: 1.1,
                ),
              ),
              child: s._buying
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    )
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
