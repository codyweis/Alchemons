// lib/screens/friends/friend_planet_screen.dart
//
// A friend's page: their division's realm in grains, as their home screen
// has it, and their home planet hanging in it as they made it. Drawing a
// circle round the planet opens a hole through the sand where it was — the
// planet comes apart into grains and falls in turning — onto their home
// biome, live (FriendHomeWindow). A tap on the window goes down into it; a
// second circle closes it and the planet comes back. The same portal as the
// home screen's (lib/widgets/home_portal.dart). A tap on the planet itself
// goes straight down, the planet pouring into their home as sand.
//
// A friend who has not built their home planet yet has nothing to look into:
// their page shows a dim grey planet, still, and no portal.
//
// TRADE under the planet opens the trade table with them (trade_screen.dart),
// with a dot while it waits on the player.
//
// The ⋮ holds what is needed to stop being friends: remove, block, report.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart' show premiumHomeColor;
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/screens/friends/friend_home_screen.dart';
import 'package:alchemons/screens/friends/trade_screen.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/trade_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/home_planet_view.dart';
import 'package:alchemons/widgets/home_portal.dart';
import 'package:alchemons/widgets/notification_banner_system.dart'
    show HomeNoticeDot;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set once the player has drawn a circle on a friend's page: the traced
/// guide stops showing.
const String kFriendPortalDrawnKey = 'friends.portal_drawn';

const _palette = BracketPalette.dark;

TextStyle _mono(double size, Color color, {double spacing = 1.4}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: FontWeight.w800,
  letterSpacing: spacing,
  height: 1.2,
);

class FriendPlanetScreen extends StatefulWidget {
  const FriendPlanetScreen({super.key, required this.friend, this.loadHome});

  final FriendCard friend;

  /// Where their home comes from; FriendService.fetchHome when null.
  final Future<FriendHome?> Function()? loadHome;

  /// Fades up over whatever opened it.
  static Route<void> route(FriendCard friend) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => FriendPlanetScreen(friend: friend),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );

  @override
  State<FriendPlanetScreen> createState() => _FriendPlanetScreenState();
}

class _FriendPlanetScreenState extends State<FriendPlanetScreen> {
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _portalKey = GlobalKey();
  final GlobalKey _planetKey = GlobalKey();

  late final FactionId _faction = FactionId.values.firstWhere(
    (f) => f.name == widget.friend.faction,
    orElse: () => FactionId.volcanic,
  );
  late final FactionRealmField _field = FactionRealmField(faction: _faction);

  bool _open = false;
  bool _guide = false;
  bool _descending = false;

  /// Bumped after each visit, so the window is built fresh.
  int _visit = 0;

  FriendHome? _home;
  bool _homeLoading = false;
  String? _homeError;

  /// The planet was tapped before their home had loaded: down once it has.
  bool _enterWhenLoaded = false;

  /// The planet's body as drawn, for where a tap on it lands.
  double _bodyR = 0;

  bool get _hasPlanet => widget.friend.planet != null;

  @override
  void initState() {
    super.initState();
    if (_hasPlanet) {
      unawaited(_loadGuide());
      unawaited(_loadHome());
    }
  }

  Future<void> _loadGuide() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _guide = prefs.getBool(kFriendPortalDrawnKey) != true);
  }

  Future<void> _loadHome() async {
    if (_homeLoading) return;
    setState(() {
      _homeLoading = true;
      _homeError = null;
    });
    try {
      final load =
          widget.loadHome ??
          () => context.read<FriendService>().fetchHome(widget.friend.uid);
      final home = await load();
      if (!mounted) return;
      setState(() {
        _home = home;
        if (home == null) _homeError = 'They have not made their home yet.';
      });
      if (home != null && _enterWhenLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tapPlanet());
      }
    } on FriendException catch (e) {
      if (mounted) setState(() => _homeError = e.message);
    } catch (_) {
      if (mounted) setState(() => _homeError = 'Their home could not load.');
    } finally {
      if (mounted) {
        setState(() {
          _homeLoading = false;
          if (_home == null) _enterWhenLoaded = false;
        });
      }
    }
  }

  /// Straight down through the planet, without drawing the circle.
  void _tapPlanet() {
    _enterWhenLoaded = false;
    if (!_hasPlanet || _open || _descending || !mounted) return;
    if (_home == null) {
      // Still on its way (or failed: try again), and gone into once here.
      setState(() => _enterWhenLoaded = true);
      if (!_homeLoading) unawaited(_loadHome());
      return;
    }
    final box = _planetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || _bodyR <= 0) return;
    HapticFeedback.selectionClick();
    unawaited(
      _enter(
        _planetKey,
        Rect.fromCircle(
          center: box.localToGlobal(box.size.center(Offset.zero)),
          radius: _bodyR * 1.15,
        ),
      ),
    );
  }

  Color get _tone => factionThemeFor(_faction).primary;

  // ── The portal ──────────────────────────────────────────────────────────

  void _onToggle(bool open) {
    setState(() {
      _open = open;
      _guide = false;
    });
    unawaited(
      SharedPreferences.getInstance().then(
        (p) => p.setBool(kFriendPortalDrawnKey, true),
      ),
    );
    // Opened onto a home that failed to load: try again.
    if (open && _home == null && !_homeLoading) unawaited(_loadHome());
  }

  Future<void> _enter(GlobalKey picture, Rect hole) async {
    final home = _home;
    if (home == null || _descending) return;
    setState(() => _descending = true);
    final audio = context.read<AudioController?>();
    try {
      unawaited(
        audio?.playSound(SoundCue.cosmicPortalOpen) ?? Future<void>.value(),
      );
      await visitFriendHome(
        context,
        home: home,
        name: widget.friend.name,
        from: SandSource(picture: picture, circle: hole),
        back: (element) => SandLanding(
          element: element,
          circle: () => HomePortalHero.holeOf(_portalKey),
          onLanded: () {
            final hole = HomePortalHero.holeOf(_portalKey);
            final at = hole == null ? null : _local(hole.center);
            if (at != null) _field.ripple(at);
          },
        ),
      );
      unawaited(audio?.playHomeMusic() ?? Future<void>.value());
    } finally {
      if (mounted) {
        setState(() {
          _descending = false;
          _visit++;
        });
      }
    }
  }

  /// [global] in the realm's own coordinates.
  Offset? _local(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject();
    return box is RenderBox && box.attached ? box.globalToLocal(global) : null;
  }

  // ── Leaving them ────────────────────────────────────────────────────────

  Future<void> _menu() async {
    final name = widget.friend.name;
    final action = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => _MenuDialog(
        title: name.toUpperCase(),
        options: const [
          ('remove', 'REMOVE FRIEND'),
          ('block', 'BLOCK'),
          ('report', 'REPORT'),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'remove':
        await _remove();
      case 'block':
        await _block();
      case 'report':
        await _report();
    }
  }

  Future<void> _remove() async {
    final ok = await showBracketConfirm(
      context,
      palette: _palette,
      accent: kLeaveDangerAccent,
      title: 'REMOVE FRIEND?',
      message:
          'You and ${widget.friend.name} will no longer see each '
          "other's homes.",
      confirmLabel: 'REMOVE',
    );
    if (!ok || !mounted) return;
    final friends = context.read<FriendService>();
    final trades = context.read<TradeService>();
    await _act(() async {
      await trades.leave(widget.friend.uid);
      await friends.remove(widget.friend.uid);
    });
  }

  Future<void> _block({bool asked = false}) async {
    if (!asked) {
      final ok = await showBracketConfirm(
        context,
        palette: _palette,
        accent: kLeaveDangerAccent,
        title: 'BLOCK ${widget.friend.name.toUpperCase()}?',
        message:
            'They are removed from your friends and cannot send you '
            'requests.',
        confirmLabel: 'BLOCK',
      );
      if (!ok || !mounted) return;
    }
    final friends = context.read<FriendService>();
    final trades = context.read<TradeService>();
    await _act(() async {
      await trades.leave(widget.friend.uid);
      await friends.block(widget.friend.uid);
    });
  }

  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => _MenuDialog(
        title: 'REPORT',
        message: 'What is wrong?',
        options: [
          for (final r in FriendReportReason.values)
            (r.id, r.label.toUpperCase()),
        ],
      ),
    );
    if (!mounted || reason == null) return;
    final service = context.read<FriendService>();
    try {
      await service.report(
        widget.friend.uid,
        FriendReportReason.values.firstWhere((r) => r.id == reason),
      );
    } on FriendException catch (e) {
      if (mounted) {
        showAppSnack(e.message, isError: true, fallbackContext: context);
      }
      return;
    }
    if (!mounted) return;
    final block = await showBracketConfirm(
      context,
      palette: _palette,
      accent: kLeaveDangerAccent,
      title: 'REPORT SENT',
      message: 'Block ${widget.friend.name} as well?',
      confirmLabel: 'BLOCK',
      cancelLabel: 'NO',
    );
    if (block && mounted) await _block(asked: true);
  }

  /// Runs [change]; done, the page closes.
  Future<void> _act(Future<void> Function() change) async {
    try {
      await change();
      if (mounted) Navigator.of(context).pop();
    } on FriendException catch (e) {
      if (mounted) {
        showAppSnack(e.message, isError: true, fallbackContext: context);
      }
    }
  }

  // ── Building ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final accent = factionThemeFor(_faction).accent;
    final home = _home;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        key: _stackKey,
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: FactionRealmView(faction: _faction, field: _field),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
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
                              friend.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cinzel(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 1.1,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 10),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (FactionService.catalog[_faction]?.name ??
                                      'Alchemist')
                                  .toUpperCase(),
                              style: _mono(
                                10,
                                _palette.muted,
                              ).copyWith(letterSpacing: 3),
                            ),
                          ],
                        ),
                      ),
                      BracketIconButton(
                        icon: AppIcons.more_vert,
                        palette: _palette,
                        onTap: _menu,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: !_hasPlanet
                      // Nothing built to look into: the plain grey planet,
                      // dim and still.
                      ? LayoutBuilder(
                          builder: (context, box) => Opacity(
                            opacity: 0.4,
                            child: _planet(box, animate: false),
                          ),
                        )
                      : HomePortalHero(
                          key: _portalKey,
                          open: _open,
                          spriteKey: _planetKey,
                          tone: _tone,
                          window: _descending || home == null
                              ? null
                              : (context, onReady) => FriendHomeWindow(
                                  key: ValueKey(_visit),
                                  home: home,
                                  active: TickerMode.valuesOf(context).enabled,
                                  onReady: onReady,
                                ),
                          guide: _guide,
                          onToggle: _onToggle,
                          onEnter: _enter,
                          onStir: (global, delta, dt) {
                            final at = _local(global);
                            if (at != null) _field.stir(at, delta, dt);
                          },
                          onTapSand: (global) {
                            final at = _local(global);
                            if (at != null) _field.ripple(at);
                          },
                          onSwirl: (global, reach, spin, pull) {
                            final at = _local(global);
                            if (at != null) {
                              _field.swirl(at, reach, spin: spin, pull: pull);
                            }
                          },
                          child: LayoutBuilder(
                            builder: (context, box) => _planet(box),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Column(
                    children: [
                      if (friend.planet case final planet?) ...[
                        Text(
                          _planetLine(planet),
                          textAlign: TextAlign.center,
                          style: _mono(10.5, _palette.muted, spacing: 2),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _TradeButton(friend: friend, accent: accent),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _hint(),
                          key: ValueKey(_hint()),
                          textAlign: TextAlign.center,
                          style: bracketText(
                            context,
                            13,
                            _palette.ink.withValues(alpha: 0.85),
                            weight: FontWeight.w600,
                          ).copyWith(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The planet, sized to the portal round it (HomePortalHero's radius): a
  /// Huge one fills most of the hole, a Tiny one half. A tap on its body
  /// goes down.
  Widget _planet(BoxConstraints box, {bool animate = true}) {
    final side = math.min(box.maxWidth, box.maxHeight);
    final hole = math.min(box.maxHeight * 0.42, box.maxWidth * 0.38);
    final fill = 1.64 * hole / side;
    final look = widget.friend.planet;
    _bodyR = planetBodyRadius(look ?? const PlanetLook(), side, fill);
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final c = Offset(side / 2, side / 2);
          if ((d.localPosition - c).distance <= _bodyR * 1.15) _tapPlanet();
        },
        child: RepaintBoundary(
          key: _planetKey,
          child: SizedBox.square(
            dimension: side,
            child: HomePlanetView(
              look: look,
              fill: fill,
              animate: animate,
              fadeIn: animate,
            ),
          ),
        ),
      ),
    );
  }

  String _hint() {
    if (!_hasPlanet) {
      return "${widget.friend.name} hasn't built a home planet yet.";
    }
    if (!_open) {
      if (_enterWhenLoaded) return 'Looking inside…';
      if (_homeError != null && !_homeLoading) return _homeError!;
      return 'Tap the planet to visit. Draw a circle round it to look inside.';
    }
    if (_home != null) return 'Tap the window to go down.';
    if (_homeLoading) return 'Looking inside…';
    return _homeError ?? 'Their home could not load.';
  }

  static String _planetLine(PlanetLook planet) {
    final color = premiumHomeColor(planet.color)?.label ?? planet.color;
    return '${planet.sizeName.toUpperCase()} CLASS'
        '${color == null ? '' : '  ·  ${color.toUpperCase()}'}';
  }
}

/// TRADE: the table with them, dotted while it waits on the player.
class _TradeButton extends StatelessWidget {
  const _TradeButton({required this.friend, required this.accent});

  final FriendCard friend;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final waiting = context.select<TradeService?, bool>(
      (t) => t?.attentionWith(friend.uid) ?? false,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        BracketButton(
          label: 'TRADE',
          height: 42,
          palette: _palette,
          accent: accent,
          onTap: () => Navigator.of(context).push(TradeScreen.route(friend)),
        ),
        if (waiting)
          const Positioned(
            right: -4,
            top: -4,
            child: HomeNoticeDot(color: Color(0xFFE4C16A), size: 12),
          ),
      ],
    );
  }
}

/// A few choices, one under another, in the kit's dark dialog.
class _MenuDialog extends StatelessWidget {
  const _MenuDialog({required this.title, required this.options, this.message});

  final String title;
  final String? message;
  final List<(String, String)> options;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: _palette.line.withValues(alpha: 0.9),
          bracketSize: 12,
          strokeWidth: 1.2,
        ),
        child: Container(
          color: _palette.bg1,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(13, _palette.ink, spacing: 1.8),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, style: bracketText(context, 13, _palette.muted)),
              ],
              const SizedBox(height: 14),
              for (final (id, label) in options) ...[
                BracketButton(
                  label: label,
                  height: 42,
                  primary: false,
                  palette: _palette,
                  accent: kLeaveDangerAccent,
                  onTap: () => Navigator.of(context).pop(id),
                ),
                const SizedBox(height: 8),
              ],
              BracketButton(
                label: 'CANCEL',
                height: 42,
                palette: _palette,
                accent: kLeaveQuietAccent,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
