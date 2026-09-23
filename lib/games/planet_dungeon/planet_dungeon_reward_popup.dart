import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/audio/audio.dart';
// lib/games/planet_dungeon/planet_dungeon_reward_popup.dart
//
// Reward popup. Reveals the star (or stars) just secured and
// grants each star's reward (Star 3 is the player's choice of three —
// highlight a card first, then confirm). Styled to match the dungeon HUD:
// dark alchemical panel, bracket corners, monospace headings, amber glow.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_popup_chrome.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_rewards.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/instant_extractor_glyph.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'dart:math';

import 'package:flutter/material.dart';

/// THE HOUSE POPUP PALETTE. These were a warm brown set of their own
/// (panel 14120E, amber C4A35A, border 74613A) while cosmic and survival
/// moved to black grounds and brighter ink — so a star payout read as a
/// screen from an older game than the one that opened it. Aliases onto
/// `CosmicScreenStyles` now: one set of tokens, and the dialogs cannot drift
/// apart again.
class _C {
  static const bg = CosmicScreenStyles.bg0;
  static const amber = CosmicScreenStyles.amber;
  static const amberBright = CosmicScreenStyles.amberBright;
  static const border = CosmicScreenStyles.borderAccent;
  static const text = CosmicScreenStyles.textPrimary;
  static const muted = CosmicScreenStyles.textSecondary;
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

  /// The actual item art the rest of the game uses: the metallic gold coin,
  /// the branded glowing powerup orbs, and the extractor artwork.
  Widget _rewardArt(String line, double size) {
    if (line.contains('Guardian Relic')) return _relicArt(size);
    if (line.contains('Gold')) return CoinIcon.gold(size: size);
    if (line.contains('Extractor')) {
      return InstantExtractorGlyph(size: size);
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

  // ── THE PANEL — the survival surge's chrome ───────────────────────────
  //
  // Star rewards used to be a list of text lines under a row of star glyphs,
  // in a panel of their own design. Survival's surge offer is the dialog the
  // game already does best: a near-black plate with bracket corners, and each
  // thing on it a CARD whose colour says what kind of thing it is before a
  // word is read. A star payout is the same kind of moment, so it wears the
  // same clothes: every reward is a card, and the Star 3 choice is three of
  // them to pick between.

  Widget _panel() {
    final maxWidth = MediaQuery.sizeOf(context).width - 36;
    return CustomPaint(
      painter: const DungeonBracketPainter(
        color: _C.amber,
        bracketSize: 14,
        strokeWidth: 1.3,
      ),
      child: Container(
        width: maxWidth < 400 ? maxWidth : 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 60,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: _C.bg.withValues(alpha: 0.97),
          border: Border.all(color: _C.amber.withValues(alpha: 0.30)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The Star 3 CHOICE leads the scroll while unresolved so
                    // it sits at the top of the fold, never hidden under the
                    // granted-reward lists.
                    if (_needStar3 && _choice == null) _rewardBlock(2),
                    for (final s in widget.stars)
                      if (!(s == 2 && _needStar3 && _choice == null))
                        _rewardBlock(s),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            _bottomButton(),
          ],
        ),
      ),
    );
  }

  /// The star itself, as a struck medallion, then its name. Several stars
  /// at once (a run ended holding more than one) stand side by side.
  Widget _header() {
    final awarded = widget.stars.toList()..sort();
    final size = awarded.length == 1 ? 68.0 : 50.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var n = 0; n < awarded.length; n++)
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _intro,
                  curve: Interval(
                    0.1 + n * 0.15,
                    (0.55 + n * 0.15).clamp(0.0, 1.0),
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _starMedallion(size),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // The caption, unless the title already IS the caption (an unnamed
        // star, or several at once).
        if (!_title.endsWith('SECURED'))
          Text(
            widget.stars.length == 1 ? 'STAR SECURED' : 'STARS SECURED',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: _C.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          _title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _C.text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        if (_subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            _subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.muted, fontSize: 11),
          ),
        ],
      ],
    );
  }

  /// A gold medallion with the star struck into it — a coin of the game's
  /// own minting, not an icon from a font.
  Widget _starMedallion(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [
            CosmicScreenStyles.amberGlow,
            _C.amberBright,
            Color(0xFF8A6A2C),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: const Color(0xFFFFF1C8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _C.amberBright.withValues(alpha: 0.35),
            blurRadius: size * 0.35,
          ),
        ],
      ),
      child: Icon(
        Icons.star_rounded,
        size: size * 0.6,
        color: const Color(0xFF3A2A0E),
      ),
    );
  }

  /// A section heading: monospace label, then a rule out to the edge.
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: _C.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: _C.border.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardBlock(int star) {
    final lines = _lines[star];
    final needChoice = star == 2 && _choice == null;
    final label = needChoice ? 'CHOOSE YOUR REWARD' : 'STAR ${star + 1}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(label),
          if (needChoice) ...[
            if (_relicIncoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StaggerIn(
                  index: 0,
                  child: _rewardCard(
                    '+1 ${guardianRelicName(widget.element)}, Guardian Relic',
                    tagOverride: 'GUARANTEED',
                  ),
                ),
              ),
            for (var i = 0; i < Star3Choice.values.length; i++) ...[
              _StaggerIn(
                index: i + (_relicIncoming ? 1 : 0),
                child: _choiceCard(Star3Choice.values[i]),
              ),
              if (i < Star3Choice.values.length - 1) const SizedBox(height: 8),
            ],
          ] else if (lines == null)
            const SizedBox(
              height: 60,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _C.amber,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < lines.length; i++) ...[
              _StaggerIn(index: i, child: _rewardCard(lines[i])),
              if (i < lines.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  /// What a reward line IS, for its card: accent, tag, amount and name.
  ({Color accent, String tag, String amount, String name}) _describe(
    String line,
  ) {
    final m = RegExp(r'^\+(\d+)\s+(.*)$').firstMatch(line);
    final amount = m == null ? '' : '+${m.group(1)}';
    var name = m == null ? line : m.group(2)!;
    if (line.contains('Guardian Relic')) {
      name = name.replaceAll(', Guardian Relic', '');
      return (
        accent: _legible(elementColor(widget.element)),
        tag: 'GUARDIAN RELIC',
        amount: amount,
        name: name,
      );
    }
    if (line.contains('Gold')) {
      return (
        accent: _C.amberBright,
        tag: 'CURRENCY',
        amount: amount,
        name: name,
      );
    }
    if (line.contains('Extractor')) {
      return (
        accent: CosmicScreenStyles.teal,
        tag: 'FUSION',
        amount: amount,
        name: name,
      );
    }
    for (final t in AlchemicalPowerupType.values) {
      if (line.toLowerCase().contains(t.statKey)) {
        return (
          accent: _legible(t.color),
          tag: 'POWERUP',
          amount: amount,
          name: name,
        );
      }
    }
    return (accent: _C.amber, tag: 'REWARD', amount: amount, name: name);
  }

  /// ONE REWARD, AS A SURGE CARD: the accent washing in from a solid spine,
  /// a medallion with the item's own art, the amount large and the name
  /// under it, and a tag saying what kind of thing it is.
  Widget _rewardCard(String line, {String? tagOverride}) {
    final d = _describe(line);
    return _surgeCard(
      accent: d.accent,
      art: _rewardArt(line, 26),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.amount.isNotEmpty)
                  Text(
                    d.amount,
                    style: TextStyle(
                      color: Color.lerp(_C.text, d.accent, 0.45),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  d.name.toUpperCase(),
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniTag(label: tagOverride ?? d.tag, color: d.accent),
        ],
      ),
    );
  }

  /// The card chrome every reward and choice shares (survival's surge card).
  Widget _surgeCard({
    required Color accent,
    required Widget art,
    required Widget child,
    bool selected = false,
    bool dim = false,
  }) {
    final wash = dim ? 0.16 : (selected ? 0.46 : 0.34);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(CosmicScreenStyles.bg2, accent, wash)!,
              Color.lerp(CosmicScreenStyles.bg2, accent, wash * 0.25)!,
              CosmicScreenStyles.bg1,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(
            color: accent.withValues(
              alpha: selected ? 1.0 : (dim ? 0.3 : 0.55),
            ),
            width: selected ? 1.8 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: accent.withValues(alpha: dim ? 0.5 : 1),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CosmicScreenStyles.bg0.withValues(alpha: 0.7),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.7),
                          ),
                        ),
                        child: art,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _choiceAccent(Star3Choice c) => switch (c) {
    Star3Choice.gold => _C.amberBright,
    Star3Choice.powerups => const Color(0xFF9B8CFF),
    Star3Choice.extractors => CosmicScreenStyles.teal,
  };

  Widget _choiceArt(Star3Choice c, double size) => switch (c) {
    Star3Choice.gold => CoinIcon.gold(size: size),
    Star3Choice.extractors => InstantExtractorGlyph(size: size),
    Star3Choice.powerups => SizedBox(
      width: size * 1.2,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: size * 0.1,
            child: _powerupOrb(AlchemicalPowerupType.speed, size * 0.7),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _powerupOrb(AlchemicalPowerupType.beauty, size * 0.7),
          ),
        ],
      ),
    ),
  };

  /// A Star 3 choice. First tap highlights it; a second tap (or the button)
  /// claims it — no accidental one-tap claims.
  Widget _choiceCard(Star3Choice c) {
    final selected = _highlighted == c;
    final accent = _choiceAccent(c);
    return GestureDetector(
      onTap: context.soundAction(
        _busy
            ? null
            : () {
                if (selected) {
                  _pickStar3(c);
                } else {
                  setState(() => _highlighted = c);
                }
              },
      ),
      child: _surgeCard(
        accent: accent,
        selected: selected,
        dim: _highlighted != null && !selected,
        art: _choiceArt(c, 26),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    star3ChoiceTitle(c).toUpperCase(),
                    style: TextStyle(
                      color: Color.lerp(_C.text, accent, 0.3),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    star3ChoiceSubtitle(c),
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: Icon(Icons.check_circle_rounded, color: accent, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  /// The button morphs through the flow: choose → CLAIM (choice) → CONTINUE.
  /// Filled amber when there is something to press, like survival's.
  Widget _bottomButton() {
    final awaitingChoice = _needStar3 && _choice == null;
    final String label;
    final bool enabled;
    final VoidCallback? action;
    if (awaitingChoice && _highlighted == null) {
      label = 'PICK A REWARD';
      enabled = false;
      action = null;
    } else if (awaitingChoice) {
      label = 'CLAIM ${star3ChoiceTitle(_highlighted!).toUpperCase()}';
      enabled = !_busy;
      action = () => _pickStar3(_highlighted!);
    } else {
      label = 'CONTINUE';
      enabled = _canContinue;
      action = widget.onContinue;
    }
    return GestureDetector(
      onTap: context.soundAction(enabled ? action : null),
      child: CustomPaint(
        painter: DungeonBracketPainter(
          color: _C.amberBright.withValues(alpha: enabled ? 0.9 : 0.3),
          bracketSize: 8,
          strokeWidth: 1.2,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: enabled ? _C.amberBright : CosmicScreenStyles.bg2,
            border: Border.all(
              color: enabled ? _C.amberBright : CosmicScreenStyles.borderDim,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enabled ? _C.bg : _C.muted,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lifts a colour until it holds its own as an accent on the near-black
/// plate (the survival surge's rule: earthy element colours otherwise land
/// on the panel's own background).
Color _legible(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.45, 1.0))
      .withLightness(hsl.lightness.clamp(0.58, 0.78))
      .toColor();
}

/// The surge card's kind tag.
class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Cards arrive one after another, sliding up — the reward is counted out,
/// not dumped.
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  // The wait is part of the animation (an Interval), not a Future.delayed:
  // a bare timer outlives the widget if the popup closes early.
  late final int _delayMs = 260 + widget.index * 110;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delayMs + 380),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = _delayMs / (_delayMs + 380);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Interval(
          start,
          1,
          curve: Curves.easeOutCubic,
        ).transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
      child: widget.child,
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
