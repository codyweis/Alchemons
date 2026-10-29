import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/audio/audio.dart';
// lib/games/planet_dungeon/planet_dungeon_reward_popup.dart
//
// Reward popup. The star (or stars) just secured gathers out of gold
// grains, and each star's reward is granted (Star 3 is the player's choice
// of three — light a row first, then confirm). The bare kit on ink, from
// reward_popup_parts.dart, which the raid's loot popup shares.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_rewards.dart';
import 'package:alchemons/games/planet_dungeon/reward_popup_parts.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/instant_extractor_glyph.dart';
import 'package:alchemons/widgets/tincture_glyph.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/fx/power_orb.dart';
import 'package:alchemons/widgets/grain_loader.dart';
import 'package:flutter/material.dart';

/// THE HOUSE POPUP PALETTE. These were a warm brown set of their own
/// (panel 14120E, amber C4A35A, border 74613A) while cosmic and survival
/// moved to black grounds and brighter ink — so a star payout read as a
/// screen from an older game than the one that opened it. Aliases onto
/// `CosmicScreenStyles` now: one set of tokens, and the dialogs cannot drift
/// apart again.
class _C {
  static const amber = CosmicScreenStyles.amber;
  static const amberBright = CosmicScreenStyles.amberBright;
  static const text = CosmicScreenStyles.textPrimary;
  static const muted = CosmicScreenStyles.textSecondary;
}

class DungeonRewardPopup extends StatefulWidget {
  const DungeonRewardPopup({
    super.key,
    required this.element,
    required this.stars,
    required this.db,
    required this.onContinue,
    this.starNames = const [],
    this.onStarClaimed,
    this.onLeave,
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

  /// Star 3: the guardian has fallen and the planet is done. When set, the
  /// last button splits in two, LEAVE PLANET or STAY, where a lone CONTINUE
  /// used to drop the player back in an empty arena with END RUN, in alarm
  /// red, as the only way out of a planet they had just won.
  final VoidCallback? onLeave;

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
    _intro = AnimationController(vsync: this, duration: kRewardIntro)
      ..forward();
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
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // absorb taps to the game behind
        onTap: () {},
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, panel) {
            final t = Curves.easeOutCubic.transform(_intro.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                RewardBackdrop(t: _intro.value),
                Center(
                  child: Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 18),
                      child: panel,
                    ),
                  ),
                ),
              ],
            );
          },
          child: _panel(),
        ),
      ),
    );
  }

  /// The art the rest of the game draws these with: the gold coin, the
  /// power orbs, the extractor and tincture glyphs, the planet's relic.
  Widget _rewardArt(String line, double size) {
    if (line.contains('Guardian Relic')) return _relicArt(size);
    if (line.contains('Sparks')) return TinctureGlyph(size: size);
    if (line.contains('Gold')) return CoinIcon.gold(size: size * 0.8);
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
    if (type != null) return PowerOrb(type: type, size: size);
    return RewardStarGrains(size: size);
  }

  /// The planet's relic artwork, the headline reward.
  Widget _relicArt(double size) {
    return Image.asset(
      'assets/images/relics/${widget.element.toLowerCase()}relic.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => RewardStarGrains(size: size),
    );
  }

  Widget _panel() {
    return RewardPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          const SizedBox(height: 18),
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
    );
  }

  /// The star itself, gathering out of gold grains, then its name. Several
  /// stars at once (a run ended holding more than one) stand side by side.
  Widget _header() {
    final awarded = widget.stars.toList()..sort();
    final size = awarded.length == 1 ? 92.0 : 68.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var n = 0; n < awarded.length; n++)
              RewardStarGrains(
                size: size,
                delay: Duration(milliseconds: 120 + n * 260),
                salt: awarded[n],
              ),
          ],
        ),
        const SizedBox(height: 6),
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

  Widget _rewardBlock(int star) {
    final lines = _lines[star];
    final needChoice = star == 2 && _choice == null;
    final label = needChoice ? 'CHOOSE YOUR REWARD' : 'STAR ${star + 1}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RewardSectionLabel(label),
          if (needChoice) ...[
            if (_relicIncoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RewardStaggerIn(
                  index: 0,
                  child: _rewardCard(
                    '+1 ${guardianRelicName(widget.element)}, Guardian Relic',
                    tagOverride: 'GUARANTEED',
                  ),
                ),
              ),
            for (var i = 0; i < Star3Choice.values.length; i++) ...[
              RewardStaggerIn(
                index: i + (_relicIncoming ? 1 : 0),
                child: _choiceCard(Star3Choice.values[i]),
              ),
              if (i < Star3Choice.values.length - 1) const SizedBox(height: 6),
            ],
          ] else if (lines == null)
            const SizedBox(
              height: 60,
              child: Center(child: GrainLoader(size: 28, color: _C.amber)),
            )
          else
            for (var i = 0; i < lines.length; i++) ...[
              RewardStaggerIn(index: i, child: _rewardCard(lines[i])),
              if (i < lines.length - 1) const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  /// What a reward line IS, for its row: accent, kind, amount and name.
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
    if (line.contains('Sparks')) {
      return (
        accent: _C.amberBright,
        tag: 'ATHANOR',
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

  /// One reward as a row: its art in its own light, the amount large and
  /// the name under it, and what kind of thing it is.
  Widget _rewardCard(String line, {String? tagOverride}) {
    final d = _describe(line);
    return RewardRow(
      accent: d.accent,
      art: _rewardArt(line, 32),
      kind: tagOverride ?? d.tag,
      child: RewardAmountName(
        amount: d.amount,
        name: d.name,
        accent: d.accent,
      ),
    );
  }

  Color _choiceAccent(Star3Choice c) => switch (c) {
    Star3Choice.gold => _C.amberBright,
    Star3Choice.powerups => const Color(0xFF9B8CFF),
    Star3Choice.extractors => CosmicScreenStyles.teal,
  };

  Widget _choiceArt(Star3Choice c, double size) => switch (c) {
    Star3Choice.gold => CoinIcon.gold(size: size * 0.8),
    Star3Choice.extractors => InstantExtractorGlyph(size: size),
    Star3Choice.powerups => SizedBox(
      width: size * 1.2,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: PowerOrb(
              type: AlchemicalPowerupType.speed,
              size: size * 0.8,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: PowerOrb(
              type: AlchemicalPowerupType.beauty,
              size: size * 0.8,
            ),
          ),
        ],
      ),
    ),
  };

  /// A Star 3 choice. First tap lights it; a second tap (or the button)
  /// claims it — no accidental one-tap claims.
  Widget _choiceCard(Star3Choice c) {
    final selected = _highlighted == c;
    final accent = _choiceAccent(c);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
      child: RewardRow(
        accent: accent,
        selected: selected,
        dim: _highlighted != null && !selected,
        art: _choiceArt(c, 32),
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
    );
  }

  /// The button changes through the flow: choose → CLAIM (choice) →
  /// CONTINUE. Lit when there is something to press.
  Widget _bottomButton() {
    final awaitingChoice = _needStar3 && _choice == null;
    // The guardian's star, claimed: leave the planet, or stay. Not "keep
    // looking": the vault and the maxim may both be found already, and the
    // maxim is a secret, so a button must not say whether anything is left.
    if (!awaitingChoice && _needStar3 && widget.onLeave != null) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: RewardPopupButton(
              label: 'STAY',
              enabled: _canContinue,
              onTap: widget.onContinue,
              quiet: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: RewardPopupButton(
              label: 'LEAVE PLANET',
              enabled: _canContinue,
              onTap: widget.onLeave,
            ),
          ),
        ],
      );
    }
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
    return RewardPopupButton(label: label, enabled: enabled, onTap: action);
  }
}

/// Lifts a color until it holds its own as an accent on the near-black
/// plate (the survival surge's rule: earthy element colors otherwise land
/// on the panel's own background).
Color _legible(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.45, 1.0))
      .withLightness(hsl.lightness.clamp(0.58, 0.78))
      .toColor();
}
