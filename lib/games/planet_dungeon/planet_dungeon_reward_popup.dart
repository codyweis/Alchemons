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
  static const panel = Color(0xFF14120E);
  static const amber = Color(0xFFC4A35A);
  static const amberBright = Color(0xFFE4C16A);
  static const border = Color(0xFF74613A);
  static const text = Color(0xFFE8DFC8);
  static const muted = Color(0xFF9C9078);
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
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _turn;
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
    // THE LIGHT KEEPS TURNING. The rays used to be spun by `_intro`, which
    // runs once and stops at 1.0 — so the moment the panel finished arriving
    // the light behind it froze mid-turn, and the rarest screen in the game
    // sat there as a still image. This one repeats, slowly, forever.
    _turn = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 44),
    )..repeat();
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
    _turn.dispose();
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
          animation: Listenable.merge([_intro, _turn]),
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
                      spin: _turn.value * pi * 2,
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
    // The panel was a fixed 400 wide. A 412pt phone left six points of air on
    // each side and anything narrower — a 375pt iPhone SE — overflowed the
    // screen outright.
    final maxWidth = MediaQuery.sizeOf(context).width - 36;
    return CustomPaint(
      painter: const DungeonBracketPainter(
        color: _C.amberBright,
        bracketSize: 18,
        strokeWidth: 2.4,
      ),
      child: Container(
        width: maxWidth < 400 ? maxWidth : 400,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1710), _C.panel],
          ),
          // ONE FRAME, NOT A HALO. A 2px bright-gold border wrapped in a
          // 46px amber bloom is how a slot machine announces a win; the
          // bracket chrome around this panel already says "important", and
          // the turning light behind it already says "rare". The blur was
          // also the most expensive thing on the screen.
          border: Border.all(color: _C.amber, width: 1.2),
          boxShadow: const [
            BoxShadow(
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
                shadows: [Shadow(color: _C.amber, blurRadius: 4)],
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
                // A halo, not a flare. 14px of bloom on a 38px glyph is most of
                // the glyph again, and three of them in a row read as arcade
                // signage rather than as an earned mark.
                shadows: [Shadow(color: _C.amber, blurRadius: 6)],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
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
    // NO BOX. This used to be a bordered, rounded, filled panel sitting
    // inside the bordered panel — and the choice cards were bordered boxes
    // inside THAT, with a bordered medallion inside each of those. Four
    // frames deep is what made the popup read as nested rather than
    // designed. A section is a heading, a rule, and its contents.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
              // Flexible, because a heading in a fixed-width face is one font
              // substitution away from being wider than the panel — which is
              // exactly how it overflowed on a 320pt screen.
              Flexible(
                child: Text(
                  // The choice block is the only one that needs a heading, and
                  // "STAR 3" is not it: the popup's title already names the
                  // star in inch-high letters directly above. Say the thing the
                  // player has to DO.
                  needChoice ? 'CHOOSE YOUR REWARD' : 'STAR ${star + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.amber,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // The rule runs out to the panel edge and does the job the box
              // used to: it separates without enclosing.
              Expanded(
                child: Container(
                  height: 1,
                  color: _C.border.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          // "CONFIRM BELOW" in cyan used to live on this row — an instruction
          // in another screen's accent colour, telling the player to read the
          // button that is already telling them the same thing.
          const SizedBox(height: 10),
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
    // THE MEDALLION. The three arts are a metallic coin sprite, two glowing
    // orbs and a UI png that carries its own pale halo — side by side they
    // read as three things borrowed from three places. A common dark disc
    // with a thin rim makes them one set of choices, and it gives the png's
    // halo something to sit on instead of floating.
    return Container(
      width: size * 1.62,
      height: size * 1.62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? const Color(0xFF241C10)
            : Colors.black.withValues(alpha: 0.32),
        border: Border.all(
          color: selected
              ? _C.amberBright.withValues(alpha: 0.85)
              : _C.border.withValues(alpha: 0.20),
          width: selected ? 1.4 : 1.0,
        ),
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
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        decoration: BoxDecoration(
          // Warm, not the HUD's blue-black: a gold reward highlighted in navy
          // looked like a different screen's component had wandered in.
          // A CARD ONLY ONCE YOU TOUCH IT. Three bordered boxes side by side
          // inside a bordered section inside a bordered panel is the nesting;
          // unselected these are just their contents on the panel's own
          // ground, and the border arrives with the choice. The bloom is gone
          // for the same reason the panel's is.
          color: selected
              ? const Color(0xFF1E1810)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _C.amberBright
                : _C.border.withValues(alpha: 0.22),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _choiceArt(c, 28, selected: selected),
            const SizedBox(height: 9),
            // FIXED height, two lines' worth. "10 Fusion Extractors" wraps and
            // the other two do not, so without this its subtitle sat a line
            // lower than its neighbours' and the row lost its baseline.
            SizedBox(
              height: 30,
              child: Text(
                star3ChoiceTitle(c),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: selected ? _C.amberBright : _C.text,
                  fontSize: 11.5,
                  height: 1.24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              star3ChoiceSubtitle(c),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: selected
                    ? _C.text.withValues(alpha: 0.8)
                    : _C.muted,
                fontSize: 9,
                height: 1.3,
              ),
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
    final r = size.longestSide * 0.78;
    // UNEVEN, so it reads as light and not as a pinwheel. Fourteen identical
    // wedges turning in lockstep is a prize-wheel; a scatter of long thin
    // ones at three different widths and reaches is a shaft coming through
    // something.
    const rays = 11;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    for (var i = 0; i < rays; i++) {
      final a = i * (pi * 2 / rays);
      final half = 0.016 + (i % 3) * 0.014;
      final reach = r * (0.62 + (i % 4) * 0.13);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(cos(a - half) * reach, sin(a - half) * reach)
          ..lineTo(cos(a + half) * reach, sin(a + half) * reach)
          ..close(),
        Paint()
          ..color = _C.amberBright.withValues(
            alpha: (0.030 + (i % 3) * 0.014) * progress,
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RewardRaysPainter old) =>
      old.progress != progress || old.spin != spin;
}
