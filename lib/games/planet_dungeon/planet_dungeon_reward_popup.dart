// lib/games/planet_dungeon/planet_dungeon_reward_popup.dart
//
// Reward popup. Reveals the star (or stars) just secured and
// grants each star's reward (Star 3 is the player's choice of three —
// highlight a card first, then confirm). Styled to match the dungeon HUD:
// dark alchemical panel, bracket corners, monospace headings, amber glow.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_popup_chrome.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_rewards.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'dart:math';

import 'package:flutter/material.dart';

class _C {
  static const bg = Color(0xFF080808);
  static const bg2 = Color(0xFF111722);
  static const panel = Color(0xFF14120E);
  static const amber = Color(0xFFC4A35A);
  static const amberBright = Color(0xFFE4C16A);
  static const border = Color(0xFF74613A);
  static const text = Color(0xFFE8DFC8);
  static const muted = Color(0xFF9C9078);
  static const cyan = Color(0xFF5BC8E8);
}

/// HUD-style corner brackets (mirrors the in-dungeon button chrome).

class DungeonRewardPopup extends StatefulWidget {
  const DungeonRewardPopup({
    super.key,
    required this.element,
    required this.stars,
    required this.db,
    required this.onContinue,
    this.starNames = const [],
    this.onStarClaimed,
  });

  /// Planet element — drives the guardian-relic grant and its artwork.
  final String element;

  /// Pending star indices (subset of [0,1,2], ascending).
  final List<int> stars;

  /// Display names for [stars], index-aligned — 'Wind Star', 'Hush Star'.
  /// Empty falls back to a generic heading, so an unnamed star still reads.
  final List<String> starNames;
  final AlchemonsDatabase db;
  final VoidCallback onContinue;

  /// Called right after a star's reward is granted so the claim flag can be
  /// persisted immediately (a force-quit mid-popup must not re-grant).
  final Future<void> Function(int starIndex)? onStarClaimed;

  @override
  State<DungeonRewardPopup> createState() => _DungeonRewardPopupState();
}

class _DungeonRewardPopupState extends State<DungeonRewardPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  final Map<int, List<String>> _lines = {};
  Star3Choice? _choice;
  Star3Choice? _highlighted;
  bool _busy = false;
  bool _relicIncoming = false;

  /// The heading. One star names itself; several mean the run ended holding
  /// more than one, which is the only case where a count is the useful thing.
  String get _title {
    if (widget.stars.length == 1) {
      final name = widget.starNames.length == 1
          ? widget.starNames.first.trim()
          : '';
      return name.isEmpty ? 'STAR SECURED' : name.toUpperCase();
    }
    return 'STARS SECURED';
  }

  String? get _subtitle {
    if (widget.stars.length == 1) {
      // A named star already says what it is, so a second line would only
      // repeat it. Unnamed, there is nothing to add either.
      return null;
    }
    return '${widget.stars.length} stars secured this run';
  }

  bool get _needStar3 => widget.stars.contains(2);
  bool get _star3Resolved => !_needStar3 || _choice != null;
  bool get _autoDone =>
      widget.stars.where((s) => s != 2).every(_lines.containsKey);
  bool get _canContinue => _autoDone && _star3Resolved && !_busy;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _checkRelicIncoming();
    _grantAuto();
  }

  Future<void> _checkRelicIncoming() async {
    if (!_needStar3) return;
    final traitKey = BossLootKeys.traitKeyForElement(widget.element);
    final qty = await widget.db.inventoryDao.getItemQty(traitKey);
    if (mounted && qty == 0) setState(() => _relicIncoming = true);
  }

  Future<void> _grantAuto() async {
    for (final s in widget.stars) {
      if (s == 2) continue;
      final lines = await grantStarReward(
        db: widget.db,
        element: widget.element,
        starIndex: s,
      );
      await widget.onStarClaimed?.call(s);
      if (mounted) setState(() => _lines[s] = lines);
    }
  }

  Future<void> _pickStar3(Star3Choice c) async {
    if (_busy || _choice != null) return;
    setState(() => _busy = true);
    final lines = await grantStarReward(
      db: widget.db,
      element: widget.element,
      starIndex: 2,
      choice: c,
    );
    await widget.onStarClaimed?.call(2);
    if (!mounted) return;
    setState(() {
      _choice = c;
      _lines[2] = lines;
      _busy = false;
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // absorb taps to the game behind
        onTap: () {},
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) {
            final t = _intro.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Hard scrim. The old one was #080808 at 0.78 over an already
                // dark dungeon, so the rarest moment in a run separated from
                // the world about as much as a hint box does.
                ColoredBox(color: Colors.black.withValues(alpha: 0.90 * t)),
                // Radial light behind the panel: the reward is the only thing
                // in the dungeon that emits its own light.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.75,
                        colors: [
                          _C.amberBright.withValues(alpha: 0.20 * t),
                          _C.amber.withValues(alpha: 0.06 * t),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // Rays, turning slowly. Nothing else in the game does this.
                IgnorePointer(
                  child: CustomPaint(
                    painter: _RewardRaysPainter(
                      progress: t,
                      spin: _intro.value * 0.6,
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: t,
                    child: Transform.scale(
                      // Overshoots harder than a normal panel, and lands.
                      scale: 0.72 + 0.28 * curved.value,
                      child: _panel(),
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

  Widget _panel() {
    return CustomPaint(
      painter: const DungeonBracketPainter(
        color: _C.amberBright,
        bracketSize: 18,
        strokeWidth: 2.4,
      ),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1710), _C.panel],
          ),
          // A real gold frame, not the hairline every other panel wears.
          border: Border.all(color: _C.amberBright, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: _C.amberBright.withValues(alpha: 0.30),
              blurRadius: 46,
              spreadRadius: 6,
            ),
            const BoxShadow(
              color: Color(0xCC000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const SizedBox(height: 14),
            _starRow(),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // The Star 3 CHOICE leads the scroll while unresolved so
                    // it sits at the top of the fold, never hidden under the
                    // granted-reward lists. (It must live INSIDE the scroll
                    // area — pinned outside it, its fixed height overflowed
                    // the panel on small screens.)
                    if (_needStar3 && _choice == null) _rewardBlock(2),
                    for (final s in widget.stars)
                      if (!(s == 2 && _needStar3 && _choice == null))
                        _rewardBlock(s),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _bottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _headerRule(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.star_rounded,
                color: _C.amberBright,
                size: 14,
                shadows: [Shadow(color: _C.amberBright, blurRadius: 8)],
              ),
            ),
            _headerRule(),
          ],
        ),
        const SizedBox(height: 8),
        // This popup is offered AT THE ACCOMPLISHMENT — the moment a star
        // banks, mid-run — not when the expedition ends. It used to announce
        // 'EXPEDITION COMPLETE' over a count of one, which told the player
        // both that they were finished (they are not; they are still in the
        // dungeon) and nothing whatsoever about what they had just done.
        // Naming the star answers the only live question: what did I get?
        Text(
          _title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _C.amberBright,
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
        if (_subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            _subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.muted,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _headerRule() {
    return Container(
      width: 64,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _C.border.withValues(alpha: 0.0),
            _C.amber.withValues(alpha: 0.7),
          ],
        ),
      ),
    );
  }

  /// Only the stars being awarded right now.
  ///
  /// This used to draw all three slots, filling the earned ones and outlining
  /// the rest — so claiming a single star showed one lit star beside two empty
  /// sockets and read as "1 of 3", a progress bar at the moment of a reward.
  /// Progress already lives in the HUD tracker the star flies into; the popup
  /// is here to hand something over.
  Widget _starRow() {
    final awarded = widget.stars.toList()..sort();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var n = 0; n < awarded.length; n++)
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _intro,
              curve: Interval(
                0.15 + n * 0.18,
                (0.55 + n * 0.18).clamp(0.0, 1.0),
                curve: Curves.easeOutBack,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.star_rounded,
                color: _C.amberBright,
                size: 38,
                shadows: [Shadow(color: _C.amberBright, blurRadius: 14)],
              ),
            ),
          ),
      ],
    );
  }

  /// The actual item art the rest of the game uses: the metallic gold coin,
  /// the branded glowing powerup orbs, and the extractor artwork.
  Widget _rewardArt(String line, double size) {
    if (line.contains('Guardian Relic')) return _relicArt(size);
    if (line.contains('Gold')) return CoinIcon.gold(size: size);
    if (line.contains('Extractor')) {
      return Image.asset(
        'assets/images/ui/instantbreedicon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    final type = line.contains('Speed')
        ? AlchemicalPowerupType.speed
        : line.contains('Intelligence')
        ? AlchemicalPowerupType.intelligence
        : line.contains('Strength')
        ? AlchemicalPowerupType.strength
        : line.contains('Beauty')
        ? AlchemicalPowerupType.beauty
        : null;
    if (type != null) return _powerupOrb(type, size);
    return Icon(Icons.auto_awesome_rounded, size: size, color: _C.amberBright);
  }

  /// A powerup as it appears everywhere else: a glowing orb in its stat
  /// colour with the branded glyph.
  Widget _powerupOrb(AlchemicalPowerupType type, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            Color.lerp(type.color, Colors.white, 0.45)!,
            type.color,
            Color.lerp(type.color, Colors.black, 0.45)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [BoxShadow(color: type.glowColor, blurRadius: size * 0.45)],
      ),
      child: Icon(type.icon, size: size * 0.58, color: Colors.white),
    );
  }

  /// The planet's relic artwork with an amber bloom — the headline reward.
  Widget _relicArt(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _C.amberBright.withValues(alpha: 0.55),
            blurRadius: size * 0.6,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/relics/${widget.element.toLowerCase()}relic.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.shield_moon_rounded, size: size, color: _C.amberBright),
      ),
    );
  }

  /// Shown above the Star-3 choice cards: the relic is guaranteed, the
  /// choice is on top of it.
  Widget _relicBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.amberBright.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.amberBright.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          _relicArt(30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardianRelicName(widget.element).toUpperCase(),
                  style: const TextStyle(
                    color: _C.amberBright,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Guardian Relic — yours with any choice below',
                  style: TextStyle(color: _C.muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardBlock(int star) {
    final lines = _lines[star];
    final needChoice = star == 2 && _choice == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 12,
                color: _C.amber.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Text(
                'STAR ${star + 1}',
                style: const TextStyle(
                  color: _C.amber,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              if (needChoice) ...[
                const Spacer(),
                Text(
                  _highlighted == null ? 'PICK ONE' : 'CONFIRM BELOW',
                  style: TextStyle(
                    color: _C.cyan.withValues(alpha: 0.85),
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (needChoice) ...[
            if (_relicIncoming) _relicBanner(),
            _choiceCards(),
          ] else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: lines == null
                  ? const SizedBox(
                      key: ValueKey('wait'),
                      height: 18,
                      child: Text('…', style: TextStyle(color: _C.muted)),
                    )
                  : Column(
                      key: const ValueKey('lines'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final l in lines)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                _rewardArt(l, 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l,
                                    style: const TextStyle(
                                      color: _C.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
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

  /// Choice-card art: the gold coin, a twin pair of powerup orbs, or the
  /// extractor artwork — the items as the player knows them.
  Widget _choiceArt(Star3Choice c, double size, {required bool selected}) {
    final art = switch (c) {
      Star3Choice.gold => CoinIcon.gold(size: size),
      Star3Choice.extractors => Image.asset(
        'assets/images/ui/instantbreedicon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
      Star3Choice.powerups => SizedBox(
        width: size * 1.3,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: size * 0.12,
              child: _powerupOrb(AlchemicalPowerupType.speed, size * 0.74),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _powerupOrb(AlchemicalPowerupType.beauty, size * 0.74),
            ),
          ],
        ),
      ),
    };
    if (!selected) return art;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _C.amberBright.withValues(alpha: 0.45),
            blurRadius: 16,
          ),
        ],
      ),
      child: art,
    );
  }

  /// Star-3 choice cards. First tap highlights a card; the bottom button (or a
  /// second tap on the same card) confirms — no accidental one-tap claims.
  Widget _choiceCards() {
    // IntrinsicHeight bounds the stretch: equal-height cards measured from
    // the tallest. Without it the stretch meets the parent Column's
    // unbounded height and the whole popup fails layout
    // ("BoxConstraints forces an infinite height" on End Run).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in Star3Choice.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _choiceCard(c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _choiceCard(Star3Choice c) {
    final selected = _highlighted == c;
    return GestureDetector(
      onTap: _busy
          ? null
          : () {
              if (selected) {
                _pickStar3(c); // second tap on the highlighted card confirms
              } else {
                setState(() => _highlighted = c);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? _C.bg2 : _C.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _C.amberBright : _C.border.withValues(alpha: 0.7),
            width: selected ? 1.6 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _C.amberBright.withValues(alpha: 0.22),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 34,
              child: Center(child: _choiceArt(c, 30, selected: selected)),
            ),
            const SizedBox(height: 6),
            Text(
              star3ChoiceTitle(c),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? _C.amberBright : _C.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              star3ChoiceSubtitle(c),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom button morphs through the flow:
  ///   choose → highlight → CONFIRM (choice) → CONTINUE.
  Widget _bottomButton() {
    final awaitingChoice = _needStar3 && _choice == null;
    final String label;
    final bool enabled;
    final VoidCallback? action;
    if (awaitingChoice && _highlighted == null) {
      label = 'SELECT A STAR 3 REWARD';
      enabled = false;
      action = null;
    } else if (awaitingChoice) {
      label = 'CONFIRM — ${star3ChoiceTitle(_highlighted!).toUpperCase()}';
      enabled = !_busy;
      action = () => _pickStar3(_highlighted!);
    } else {
      label = 'CONTINUE';
      enabled = _canContinue;
      action = widget.onContinue;
    }
    return GestureDetector(
      onTap: enabled ? action : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: CustomPaint(
          painter: DungeonBracketPainter(
            color: _C.amberBright.withValues(alpha: enabled ? 0.8 : 0.35),
            bracketSize: 8,
            strokeWidth: 1.2,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _C.bg.withValues(alpha: 0.85),
              border: Border.all(
                color: _C.amberBright.withValues(alpha: enabled ? 0.9 : 0.4),
                width: 1.2,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _C.amberBright,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slow rays behind the reward panel.
///
/// Deliberately unlike anything else in the dungeon: every other panel is
/// amber-on-dark with bracket corners, so a reward wearing that same chrome
/// read as another hint. This is the one moment allowed to look like an event.
class _RewardRaysPainter extends CustomPainter {
  const _RewardRaysPainter({required this.progress, required this.spin});

  final double progress;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.longestSide * 0.75;
    const rays = 14;
    final paint = Paint()
      ..color = _C.amberBright.withValues(alpha: 0.055 * progress);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    for (var i = 0; i < rays; i++) {
      final a = i * (pi * 2 / rays);
      final half = 0.055;
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(cos(a - half) * r, sin(a - half) * r)
          ..lineTo(cos(a + half) * r, sin(a + half) * r)
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RewardRaysPainter old) =>
      old.progress != progress || old.spin != spin;
}
