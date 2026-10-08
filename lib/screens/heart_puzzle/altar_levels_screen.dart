// lib/screens/heart_puzzle/altar_levels_screen.dart
//
// ALCHEMY: the chapters and their levels, each with the best stars won.
// A level opens once the one before it is solved — or at once, every one of
// them, while the developer tools are on. Its title is the word ALCHEMY in
// grains under the alchemy orb, exactly where home's emblem flies its orb
// and gathers the word on the way in (widgets/alchemy_emblem.dart), so the
// passage ends as this page.
//
// Scrolled, the orb slides up into the middle of a top bar and docks there,
// small, as the profile's does, while the title scrolls away. With every
// star won, the first time the page is shown the orb comes down and pays
// its 500 gold (alchemy_mastery.dart).

import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart';
import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_progress.dart';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/heart_puzzle/alchemy_mastery.dart';
import 'package:alchemons/screens/heart_puzzle/altar_play_screen.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/alchemy_emblem.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AltarLevelsScreen extends StatefulWidget {
  const AltarLevelsScreen({super.key});

  @override
  State<AltarLevelsScreen> createState() => _AltarLevelsScreenState();
}

class _AltarLevelsScreenState extends State<AltarLevelsScreen>
    with GlyphClockLease, SingleTickerProviderStateMixin {
  AltarProgress? progress;
  final ScrollController _scroll = ScrollController();

  /// The header orb: away while the mastery plays, easing back after.
  late final AnimationController _orbShown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  bool _mastery = false;
  double _masteryClock = 0;

  /// The header turns on the shared clock, the one the emblem's way in
  /// plays on, so the orb it hands over is at the same turn.
  @override
  bool get wantsClock => true;

  /// Developer tools on: every level is open.
  bool unlockAll = false;

  @override
  void dispose() {
    releaseGlyphClock();
    _scroll.dispose();
    _orbShown.dispose();
    super.dispose();
  }

  /// Every star, and its gold not yet collected: the orb comes down.
  Future<void> _maybeMastery({bool replay = false}) async {
    final p = progress;
    if (p == null || _mastery) return;
    if (!replay && (p.masteryClaimed || !p.allStars(kAltarLevels.length))) {
      return;
    }
    if (_scroll.hasClients && _scroll.offset > 0) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) return;
    _orbShown.value = 0;
    _masteryClock = GlyphClock.instance.seconds.value;
    setState(() => _mastery = true);
  }

  Future<void> _collectMastery() async {
    final p = progress;
    if (p == null) return;
    // Paid once: a replay from the developer tools pays nothing more.
    if (await p.claimMastery()) {
      if (!mounted) return;
      await context.read<AlchemonsDatabase>().currencyDao.addGold(
        AlchemyMastery.gold,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
    alchemyTitleWord().then((_) {
      if (mounted) setState(() {});
    });
    () async {
      final p = await AltarProgress.load();
      final debug = await DebugSettingsService().isEnabled();
      if (mounted) {
        setState(() {
          progress = p;
          unlockAll = debug;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeMastery());
      }
    }();
  }

  bool _isOpen(AltarProgress p, int n) => unlockAll || p.isOpen(n);

  Future<void> _open(int n) async {
    final p = progress;
    if (p == null || !_isOpen(p, n)) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AltarPlayScreen(number: n, progress: p),
      ),
    );
    if (mounted) {
      setState(() {});
      await _maybeMastery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.watch<FactionTheme>());
    final p = progress;
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      letterSpacing: 1.4,
      color: t.textSecondary,
    );
    final pad = MediaQuery.paddingOf(context);
    final head = pad.top + 150;
    final orbHome = alchemyOrbAt(MediaQuery.sizeOf(context).width, pad.top);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (p != null)
            ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(16, head, 16, 32 + pad.bottom),
              children: [
                for (final c in kAltarChapters) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 10),
                    child: Text(c.name.toUpperCase(), style: mono),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var n = c.first; n <= c.last; n++)
                        _tile(t, mono, n, p),
                    ],
                  ),
                ],
              ],
            ),
          // The header: the orb (docking as the page scrolls), its title,
          // and the bar's ground coming up under it.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HeaderPainter(
                  glyphClock ?? GlyphClock.instance.seconds,
                  _scroll,
                  _orbShown,
                  pad.top,
                ),
              ),
            ),
          ),
          // A long press on the orb replays the mastery (developer tools).
          if (unlockAll)
            Positioned(
              left: orbHome.dx - 40,
              top: orbHome.dy - 40,
              width: 80,
              height: 80,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: () => _maybeMastery(replay: true),
              ),
            ),
          Positioned(
            top: pad.top + 4,
            left: 4,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: t.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (p != null)
            Positioned(
              top: pad.top + 18,
              right: 18,
              child: IgnorePointer(
                child: Text(
                  '${p.totalStars} / ${kAltarLevels.length * 3}',
                  style: mono.copyWith(color: t.amberBright, fontSize: 10),
                ),
              ),
            ),
          if (_mastery)
            Positioned.fill(
              child: AlchemyMastery(
                from: orbHome,
                headerRadius: kAlchemyHeaderOrb,
                clockAt: _masteryClock,
                onCollect: _collectMastery,
                onDone: () {
                  if (!mounted) return;
                  setState(() => _mastery = false);
                  _orbShown.forward(from: 0);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(ForgeTokens t, TextStyle mono, int n, AltarProgress p) {
    final open = _isOpen(p, n);
    final stars = p.starsOf(n);
    // The one to play next is still the first unsolved, unlocked or not.
    final next = p.isOpen(n) && stars == 0;
    return GestureDetector(
      onTap: open ? () => _open(n) : null,
      child: Container(
        width: 58,
        height: 62,
        decoration: BoxDecoration(
          color: open ? t.bg2 : t.bg1,
          borderRadius: BorderRadius.circular(4),
        ),
        foregroundDecoration: next
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: t.amberBright, width: 2),
                ),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: open ? t.textPrimary : t.textMuted.withValues(alpha: .5),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 13,
                    color: i < stars
                        ? t.amberBright
                        : t.textMuted.withValues(alpha: open ? .6 : .25),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The alchemy orb and the word ALCHEMY under it, where the emblem's way in
/// leaves them; scrolled, the orb docks small in the middle of a top bar
/// whose ground comes up under it, and the title scrolls away.
class _HeaderPainter extends CustomPainter {
  _HeaderPainter(this.clock, this.scroll, this.shown, this.top)
    : super(repaint: Listenable.merge([clock, scroll, shown]));
  final ValueListenable<double> clock;
  final ScrollController scroll;
  final Animation<double> shown;
  final double top;
  static final RiteGrainBatch _batch = RiteGrainBatch();

  static const double _dockRadius = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final time = clock.value;
    final offset = scroll.hasClients ? math.max(0.0, scroll.offset) : 0.0;
    final home = alchemyOrbAt(size.width, top);
    final dock = Offset(size.width / 2, top + 26);
    // Docked once its place in the header would pass the bar's.
    final reach = math.max(1.0, home.dy - dock.dy) + 50;
    final k = Curves.easeInOut.transform((offset / reach).clamp(0.0, 1.0));
    // The bar's ground.
    final bar = Rect.fromLTWH(0, 0, size.width, top + 56);
    if (k > .01) {
      canvas.drawRect(
        bar,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: .96 * k),
              Colors.black.withValues(alpha: .9 * k),
              Colors.black.withValues(alpha: 0),
            ],
            stops: const [0, .8, 1],
          ).createShader(bar),
      );
    }
    // The title, scrolling away.
    final titleA = 1 - (offset / 70).clamp(0.0, 1.0);
    paintAlchemyTitle(
      canvas,
      _batch,
      alchemyTitleAt(size.width, top) - Offset(0, offset),
      time,
      alpha: titleA,
    );
    _batch.paint(canvas);
    // The orb, sliding up into the bar.
    final from = home - Offset(0, offset);
    final centre = Offset.lerp(from, dock, k)!;
    final r = kAlchemyHeaderOrb + (_dockRadius - kAlchemyHeaderOrb) * k;
    paintAlchemyOrb(
      canvas,
      _batch,
      centre,
      r,
      time,
      alpha: Curves.easeOut.transform(shown.value),
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderPainter old) => old.top != top;
}
