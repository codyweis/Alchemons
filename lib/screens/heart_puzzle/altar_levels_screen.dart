// lib/screens/heart_puzzle/altar_levels_screen.dart
//
// ALCHEMY: the chapters and their levels, each with the best stars won.
// A level opens once the one before it is solved — or at once, every one of
// them, while the developer tools are on. Each chapter stands on a still of
// the realm it is played in; each level is a circle with its goal over it
// (altar_levels_art.dart). The page opens, and comes back from a level,
// gliding down to the one to play next. Its title is the word ALCHEMY in
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
import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/heart_puzzle/alchemy_mastery.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_art.dart';
import 'package:alchemons/screens/heart_puzzle/altar_play_screen.dart';
import 'package:alchemons/screens/heart_puzzle/altar_realm.dart';
import 'package:alchemons/screens/heart_puzzle/altar_stage_art.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/alchemy_emblem.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
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

  /// Bumped whenever the player takes hold of the page, so a glide down to
  /// the next level that was waiting gives way to them.
  int _held = 0;

  /// Each level's goal as its orb, made once; and the empty glass over a
  /// level whose goal is not yet made.
  final Map<int, ElementOrb> _goalOrbs = {};
  static const double _kOrbR = 11;
  static final ElementOrb _emptyGlass = ElementOrb(
    EssenceElement.spirit,
    radius: _kOrbR,
    locked: true,
  );
  ElementOrb _goalOrb(int n) => _goalOrbs.putIfAbsent(
    n,
    () => ElementOrb(
      EssenceElement.of(kAltarLevels[n - 1].goal),
      radius: _kOrbR,
    ),
  );

  // ── the page's layout: chapters as bands, levels as cells ──────────────

  /// Where the chapters begin, under the header.
  double get _head => MediaQuery.paddingOf(context).top + 150;
  static const double _nameTop = 24, _rowsTop = 66, _bottomPad = 24;

  /// A chapter's levels in rows of up to five, every other row set half a
  /// step over, so they sit as a honeycomb and not a table.
  static List<List<int>> _rowsOf(AltarChapter c) {
    final n = c.last - c.first + 1;
    final rows = (n / 5).ceil();
    final base = n ~/ rows, extra = n % rows;
    var at = c.first;
    return [
      for (var r = 0; r < rows; r++)
        [for (var k = 0; k < base + (r < extra ? 1 : 0); k++) at++],
    ];
  }

  static double _chapterHeight(AltarChapter c) =>
      _rowsTop + _rowsOf(c).length * kAltarCellHeight + _bottomPad;

  /// The step between levels across a row: five to a page's width at most.
  static double _pitch(double width) => math.min(72, (width - 32) / 5);

  /// Each of a chapter's levels' centre across the page.
  static Map<int, double> _xs(AltarChapter c, double width) {
    final p = _pitch(width);
    final rows = _rowsOf(c);
    final raw = <int, double>{
      for (var r = 0; r < rows.length; r++)
        for (var k = 0; k < rows[r].length; k++)
          rows[r][k]: k * p + (r.isOdd ? p / 2 : 0),
    };
    final lo = raw.values.reduce(math.min), hi = raw.values.reduce(math.max);
    final shift = width / 2 - (lo + hi) / 2;
    return raw.map((n, x) => MapEntry(n, x + shift));
  }

  /// Where level [n]'s cell begins down the page, unscrolled.
  double _levelTop(int n) {
    var y = _head;
    for (final c in kAltarChapters) {
      if (n > c.last) {
        y += _chapterHeight(c);
        continue;
      }
      final r = _rowsOf(c).indexWhere((row) => row.contains(n));
      return y + _rowsTop + r * kAltarCellHeight;
    }
    return y;
  }

  /// The one to play next: the first level open and not yet solved.
  static int? _nextLevel(AltarProgress p) {
    for (var n = 1; n <= kAltarLevels.length; n++) {
      if (p.isOpen(n) && p.starsOf(n) == 0) return n;
    }
    return null;
  }

  /// Down (or up) to the next level, [after] a moment, unless it is already
  /// in plain sight or the player takes hold of the page first.
  Timer? _glide;
  void _glideToNext({Duration after = Duration.zero}) {
    _glide?.cancel();
    final held = _held;
    _glide = Timer(after, () {
      if (mounted && held == _held) _glideNow();
    });
  }

  void _glideNow() {
    final p = progress;
    if (p == null || _mastery || !_scroll.hasClients) return;
    final n = _nextLevel(p);
    if (n == null) return;
    final pos = _scroll.position;
    final top = _levelTop(n);
    final view = pos.viewportDimension;
    final onScreen = top - pos.pixels;
    final bar = MediaQuery.paddingOf(context).top + 60;
    if (onScreen > bar && onScreen + kAltarCellHeight < view * .82) return;
    final target = (top + kAltarCellHeight / 2 - view * .5).clamp(
      0.0,
      pos.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Tells the way back home where the header stands.
  void _reportScroll() =>
      alchemyPickerScroll.value = math.max(0.0, _scroll.offset);

  @override
  void dispose() {
    releaseGlyphClock();
    _glide?.cancel();
    _scroll.removeListener(_reportScroll);
    alchemyPickerScroll.value = 0;
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
    alchemyPickerScroll.value = 0;
    _scroll.addListener(_reportScroll);
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeMastery();
          // Once the way in has landed.
          _glideToNext(after: const Duration(milliseconds: 650));
        });
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
      _glideToNext(after: const Duration(milliseconds: 250));
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
    final head = _head;
    final width = MediaQuery.sizeOf(context).width;
    final orbHome = alchemyOrbAt(width, pad.top);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (p != null)
            NotificationListener<ScrollStartNotification>(
              onNotification: (n) {
                if (n.dragDetails != null) _held++;
                return false;
              },
              child: ListView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(0, head, 0, 32 + pad.bottom),
                children: [
                  for (final c in kAltarChapters)
                    _chapter(t, mono, c, p, width, _nextLevel(p)),
                ],
              ),
            ),
          // The header: the orb (docking as the page scrolls), its title,
          // and the bar's ground coming up under it.
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
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

  /// A chapter: its realm, its name and stars won, and its levels.
  Widget _chapter(
    ForgeTokens t,
    TextStyle mono,
    AltarChapter c,
    AltarProgress p,
    double width,
    int? next,
  ) {
    final rows = _rowsOf(c);
    final xs = _xs(c, width);
    final pitch = _pitch(width);
    var won = 0;
    for (var n = c.first; n <= c.last; n++) {
      won += p.starsOf(n);
    }
    final most = (c.last - c.first + 1) * 3;
    final reached = _isOpen(p, c.first);
    return SizedBox(
      height: _chapterHeight(c),
      child: Stack(
        children: [
          Positioned.fill(
            child: AltarRealmStill(
              asset: altarRealmStill(c),
              dim: reached ? .5 : .66,
            ),
          ),
          Positioned(
            top: _nameTop,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  c.name.toUpperCase(),
                  style: mono.copyWith(
                    letterSpacing: 3,
                    color: reached ? t.textPrimary : t.textMuted,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$won / $most',
                  style: mono.copyWith(
                    fontSize: 9.5,
                    color: won == most
                        ? kAltarBrass
                        : t.textSecondary.withValues(alpha: reached ? .8 : .4),
                  ),
                ),
              ],
            ),
          ),
          for (var r = 0; r < rows.length; r++)
            for (final n in rows[r])
              Positioned(
                left: xs[n]! - pitch / 2,
                top: _rowsTop + r * kAltarCellHeight,
                width: pitch,
                height: kAltarCellHeight,
                child: _cell(t, n, p, n == next),
              ),
        ],
      ),
    );
  }

  Widget _cell(ForgeTokens t, int n, AltarProgress p, bool next) {
    final open = _isOpen(p, n);
    final stars = p.starsOf(n);
    final cell = !open
        ? AltarCell.locked
        : stars > 0
        ? AltarCell.solved
        : next
        ? AltarCell.next
        : AltarCell.open;
    final art = CustomPaint(
      painter: AltarCellPainter(
        cell: cell,
        stars: stars,
        orb: switch (cell) {
          AltarCell.locked => null,
          AltarCell.solved => _goalOrb(n),
          _ => _emptyGlass,
        },
        salt: n,
        ghost: next ? _goalOrb(n) : null,
        // Only the next one turns, on its own layer.
        clock: next ? glyphClock ?? GlyphClock.instance.seconds : null,
      ),
    );
    return Semantics(
      button: open,
      label:
          'Level $n${open ? '' : ', locked'}'
          '${stars > 0 ? ', $stars of 3 stars' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open ? () => _open(n) : null,
        child: Stack(
          children: [
            Positioned.fill(child: next ? RepaintBoundary(child: art) : art),
            Positioned(
              left: 0,
              right: 0,
              top: 54,
              child: Text(
                '$n',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 1,
                  color: next
                      ? kAltarBrass
                      : open
                      ? t.textPrimary
                      : t.textMuted.withValues(alpha: .45),
                ),
              ),
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

  @override
  void paint(Canvas canvas, Size size) {
    final time = clock.value;
    final offset = scroll.hasClients ? math.max(0.0, scroll.offset) : 0.0;
    final head = alchemyHeaderAt(size.width, top, offset);
    final k = head.dock;
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
    paintAlchemyTitle(canvas, _batch, head.title, time, alpha: head.titleA);
    _batch.paint(canvas);
    // The orb, sliding up into the bar.
    paintAlchemyOrb(
      canvas,
      _batch,
      head.orb,
      head.orbR,
      time,
      alpha: Curves.easeOut.transform(shown.value),
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderPainter old) => old.top != top;
}
