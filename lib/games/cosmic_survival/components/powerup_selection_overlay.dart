import 'package:alchemons/audio/audio.dart';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/services/game_controller_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show CaseLightPainter, elementLight;

import 'survival_hud.dart' show SurvivalInk, hudMono;
import 'survival_upgrade_art.dart';

/// The draft's ground: the kit's ink (SurvivalInk), and its deepest
/// raised tone for the light the backdrop falls from.
const _inkRaised = Color(0xFF1D1D21);

/// A card's accent: what the player's eye is supposed to sort on.
///
/// CATEGORY, not rarity. Rarity was doing this job and could not: most offers
/// are common, so two of the three cards on screen were the same beige almost
/// every time, and the one thing the player most needs to tell apart at a
/// glance — is this a ship gun, a companion stat, my Mystic's world — carried
/// no color at all. Rarity keeps its own chip, where being occasionally
/// identical does no harm.
///
/// A Mystic world surge is colored by its ELEMENT: it upgrades one specific
/// world standing on the map, and it should look like that world.
/// Lifts a color until it can carry white text beside it and hold its own
/// against the brighter elements.
///
/// The element palette is tuned for creatures on a light card, so the earthy
/// ones — Earth, Mud, Dust — land near the panel's own background and read as
/// washed out next to Poison's violet sitting right below them.
Color _legible(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.45, 1.0))
      .withLightness(hsl.lightness.clamp(0.58, 0.78))
      .toColor();
}

Color powerUpAccentColor(PowerUpDef def) {
  final element = def.mysticElement;
  if (element != null) return _legible(elementColor(element));
  if (def.isKeystone) return const Color(0xFFE4C16A);
  return switch (def.category) {
    PowerUpCategory.shipWeapon => const Color(0xFFFF7A45),
    PowerUpCategory.orbDefense => const Color(0xFF4FA8FF),
    PowerUpCategory.statBoost =>
      def.scope == PowerUpScope.companion
          ? const Color(0xFF5BE0B0)
          : const Color(0xFF9B8CFF),
    PowerUpCategory.rarePerk => const Color(0xFFE86BB0),
    PowerUpCategory.mysticWorld => const Color(0xFFE4C16A),
  };
}

/// BANISH's light: the kit's danger red, cooled toward its grey, so a card
/// armed to go reads as at risk without shouting.
final Color _banishEmber = Color.lerp(
  SurvivalInk.danger,
  SurvivalInk.muted,
  0.3,
)!;

/// A line's color in an element's (or the boss's) tone: mixed toward the ink
/// so it sits with the words round it.
Color _toneOf(Color c) => Color.lerp(c, SurvivalInk.ink, 0.4)!;

class PowerUpSelectionOverlay extends StatefulWidget {
  final List<OfferedPowerUpChoice> choices;
  final int currentWave;
  final List<CosmicPartyMember> party;

  /// The run's picks, and its REROLLs and BANISHes left.
  final PowerUpState powerUps;
  final void Function(PowerUpDef def, {int? targetSlot, String? targetName})
  onSelect;

  /// REROLL and BANISH. Without them (and on a keystone draft) the draft
  /// shows neither key.
  final VoidCallback? onReroll;
  final ValueChanged<int>? onBanish;

  /// What the next wave's small bodies share, for the NEXT WAVE line; or
  /// [nextIsBoss], which says BOSS instead.
  final String? nextWaveElement;
  final bool nextIsBoss;

  const PowerUpSelectionOverlay({
    super.key,
    required this.choices,
    required this.currentWave,
    required this.party,
    required this.powerUps,
    required this.onSelect,
    this.onReroll,
    this.onBanish,
    this.nextWaveElement,
    this.nextIsBoss = false,
  });

  @override
  State<PowerUpSelectionOverlay> createState() =>
      _PowerUpSelectionOverlayState();
}

/// The draft's keys, in the order they sit.
const int _rerollKey = 0;
const int _banishKey = 1;

class _PowerUpSelectionOverlayState extends State<PowerUpSelectionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _backdropFade;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _panelScale;
  late final Animation<double> _panelSlide;
  late final Animation<double> _cardStagger;

  /// A controller chooses with the stick or d-pad and takes with A: down
  /// past the last card is the row of keys, left and right along it.
  PlayInputClaim? _pad;
  int _padChoice = 0;

  /// The key a controller is on, or null while it is on the cards.
  int? _padKey;
  bool _padStickHeld = false;

  /// BANISH pressed: the next card chosen is banished, not taken.
  bool _banishArmed = false;

  bool get _showingKeystones => widget.choices.any((c) => c.def.isKeystone);

  bool get _hasKeys =>
      (widget.onReroll != null || widget.onBanish != null) &&
      powerUpDraftHasKeys(widget.choices);

  bool get _canReroll =>
      _hasKeys && widget.onReroll != null && widget.powerUps.rerollsLeft > 0;

  bool get _canBanish =>
      _hasKeys && widget.onBanish != null && widget.powerUps.banishesLeft > 0;

  bool _keyLive(int key) => key == _rerollKey ? _canReroll : _canBanish;

  @override
  void initState() {
    super.initState();
    // A stick already pushed when the cards come up was steering the ship:
    // it has to come back to centre before it chooses anything.
    _padStickHeld = GameControllerService.instance.move.distance >= 0.3;
    _pad = GameControllerService.instance.claim(
      context,
      onMove: _onPadMove,
      onPressed: (b) {
        // B puts an armed BANISH down again.
        if (b == GamepadButton.b && _banishArmed) {
          _toggleBanish();
          return;
        }
        // Not until the cards are down: A was the nova a moment ago, and a
        // press meant for it must not take a card unread.
        if (b != GamepadButton.a || !_entryController.isCompleted) return;
        if (widget.choices.isEmpty) return;
        final VoidCallback press = switch (_padKey) {
          _rerollKey => _reroll,
          _banishKey => _toggleBanish,
          _ => () => _tapCard(_padChoice.clamp(0, widget.choices.length - 1)),
        };
        context.soundAction(press)?.call();
      },
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _backdropFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _panelOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.18, 0.70, curve: Curves.easeOut),
    );
    _panelScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.18, 0.85, curve: Curves.easeOutBack),
      ),
    );
    _panelSlide = Tween<double>(begin: 28.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.18, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _cardStagger = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _entryController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant PowerUpSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reroll or a banish has changed the cards: the controller stays where
    // it was, if that is still there to be on.
    if (widget.choices.isNotEmpty) {
      _padChoice = _padChoice.clamp(0, widget.choices.length - 1);
    }
    if (!_canBanish) _banishArmed = false;
    final key = _padKey;
    if (key != null && !_keyLive(key)) {
      _padKey = _keyLive(1 - key) ? 1 - key : null;
    }
  }

  void _onPadMove(Offset v) {
    if (v.distance < 0.3) {
      _padStickHeld = false;
      return;
    }
    if (_padStickHeld || widget.choices.isEmpty) return;
    final vertical = v.dy.abs() >= v.dx.abs();
    if ((vertical ? v.dy : v.dx).abs() < 0.5) return;
    _padStickHeld = true;
    final last = widget.choices.length - 1;
    final wasChoice = _padChoice, wasKey = _padKey;
    if (vertical) {
      final down = v.dy > 0;
      if (_padKey != null) {
        if (!down) {
          _padKey = null;
          _padChoice = last;
        }
      } else if (down && _padChoice >= last) {
        // Off the bottom card onto the keys: the first one that can be used.
        _padKey = _keyLive(_rerollKey)
            ? _rerollKey
            : _keyLive(_banishKey)
            ? _banishKey
            : null;
      } else {
        _padChoice = (_padChoice + (down ? 1 : -1)).clamp(0, last);
      }
    } else if (_padKey != null) {
      final toward = v.dx > 0 ? _banishKey : _rerollKey;
      if (_keyLive(toward)) _padKey = toward;
    }
    if (_padChoice != wasChoice || _padKey != wasKey) {
      HapticFeedback.selectionClick();
    }
    // Rebuilt either way: the first push is also what dims the others.
    setState(() {});
  }

  void _tapCard(int i) => _banishArmed ? _banish(i) : _pick(i);

  void _pick(int i) {
    final choice = widget.choices[i];
    HapticFeedback.mediumImpact();
    widget.onSelect(
      choice.def,
      targetSlot: choice.targetSlot,
      targetName: choice.targetName,
    );
  }

  void _banish(int i) {
    setState(() => _banishArmed = false);
    HapticFeedback.mediumImpact();
    widget.onBanish?.call(i);
  }

  void _reroll() {
    if (!_canReroll) return;
    setState(() => _banishArmed = false);
    widget.onReroll!();
  }

  void _toggleBanish() {
    if (!_banishArmed && !_canBanish) return;
    HapticFeedback.selectionClick();
    setState(() => _banishArmed = !_banishArmed);
  }

  @override
  void dispose() {
    _pad?.release();
    _entryController.dispose();
    super.dispose();
  }

  /// NEXT WAVE · FIRE, or · BOSS, in that one's tone.
  (String, Color)? get _nextWave {
    if (widget.nextIsBoss) {
      return ('NEXT WAVE · BOSS', _toneOf(SurvivalInk.danger));
    }
    final element = widget.nextWaveElement;
    if (element == null || element.isEmpty) return null;
    return (
      'NEXT WAVE · ${element.toUpperCase()}',
      _toneOf(elementColor(element)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showingKeystones = _showingKeystones;
    final sharedChoiceGroup = widget.choices.isNotEmpty
        ? widget.choices.first.def.choiceGroup
        : null;
    final isThisOrThatOffer =
        widget.choices.length == 2 &&
        sharedChoiceGroup != null &&
        widget.choices.every(
          (choice) => choice.def.choiceGroup == sharedChoiceGroup,
        );
    final nextWave = _nextWave;
    final padMode =
        GameControllerService.instance.mode.value != PlayInputMode.touch;
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, _) {
        final backdropAlpha = (0.84 * _backdropFade.value).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            color: SurvivalInk.bg0.withValues(alpha: backdropAlpha),
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.15,
              colors: [
                _inkRaised.withValues(alpha: 0.36 * _backdropFade.value),
                SurvivalInk.bg0.withValues(alpha: 0.9 * _backdropFade.value),
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Opacity(
                  opacity: _panelOpacity.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, _panelSlide.value),
                    child: Transform.scale(
                      scale: _panelScale.value,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                        decoration: BoxDecoration(
                          // Darker and more opaque than the cards sitting on
                          // it, so there is real separation between the panel
                          // and its contents. The old version was one dim
                          // box inside another inside another, which is
                          // where "nested and boxy" came from.
                          color: SurvivalInk.bg0.withValues(
                            alpha: 0.97 * _panelOpacity.value,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // One title, not two stacked: "FORGE OFFERINGS"
                            // over "ALCHEMICAL SURGE" said the same thing
                            // twice and pushed the cards down the screen.
                            // While BANISH is armed it says what the next
                            // card chosen is for.
                            const SizedBox(height: 2),
                            Text(
                              _banishArmed
                                  ? 'CHOOSE ONE TO BANISH'
                                  : showingKeystones
                                  ? 'WAVE ${widget.currentWave} KEYSTONE'
                                  : isThisOrThatOffer
                                  ? 'UNIQUE CHOICE'
                                  : 'ALCHEMICAL SURGE',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: SurvivalInk.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.2,
                              ),
                            ),
                            // What the next wave brings, so a pick can be
                            // made against it.
                            if (nextWave != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                nextWave.$1,
                                key: const ValueKey('survival.draft.next'),
                                style: hudMono(9.5, nextWave.$2, spacing: 1.6),
                              ),
                            ],
                            // What the run has taken so far, so a pick is
                            // made against the build, not from memory.
                            if (widget.powerUps.history.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _TakenStrip(
                                powerUps: widget.powerUps,
                                party: widget.party,
                              ),
                            ],
                            const SizedBox(height: 14),
                            for (var i = 0; i < widget.choices.length; i++) ...[
                              _buildCard(i, padMode: padMode),
                              if (i < widget.choices.length - 1)
                                const SizedBox(height: 10),
                            ],
                            if (_hasKeys) ...[
                              const SizedBox(height: 12),
                              _buildKeys(padMode: padMode),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(int i, {required bool padMode}) {
    final count = widget.choices.length;
    final span = count <= 1 ? 0.0 : 0.35 / count;
    final start = (i / max(1, count)) * 0.55;
    final cardT = ((_cardStagger.value - start) / (span > 0 ? span : 0.55))
        .clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(cardT);
    // On a controller the cards it isn't on fade back, the way a frame
    // says "not this one".
    final chosen = padMode && _padKey == null && i == _padChoice;
    final passed = padMode && !chosen ? 0.42 : 1.0;
    final choice = widget.choices[i];
    // Armed, every card is lit in the banish ember, quietly; the one a
    // controller is on, fully. Otherwise only a controller's choice is lit.
    final light = _banishArmed
        ? _banishEmber.withValues(alpha: chosen ? 1.0 : 0.72)
        : chosen
        ? powerUpAccentColor(choice.def)
        : null;
    // A card drawn in by a reroll or a banish eases up into its place; the
    // one it replaces is simply gone.
    final inMs = 300 + 70 * i;
    return KeyedSubtree(
      key: ValueKey('survival.draft.$i'),
      child: Opacity(
        opacity: eased * passed,
        child: Transform.translate(
          offset: Offset(0, (1 - eased) * 18),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: inMs),
              reverseDuration: Duration.zero,
              switchInCurve: Interval(
                70 * i / inMs,
                1,
                curve: Curves.easeOutCubic,
              ),
              layoutBuilder: (current, _) => current ?? const SizedBox(),
              transitionBuilder: (child, t) => FadeTransition(
                opacity: t,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(t),
                  child: child,
                ),
              ),
              child: _PowerUpCard(
                key: ValueKey(
                  'survival.draft.card.${choice.def.id}:${choice.targetSlot}',
                ),
                choice: choice,
                party: widget.party,
                light: light,
                banishing: _banishArmed,
                onTap: () => _tapCard(i),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// REROLL and BANISH, the words themselves the keys, each with what the
  /// run has left. A spent one goes dim and takes no taps.
  Widget _buildKeys({required bool padMode}) {
    final t = Curves.easeOutCubic.transform(
      ((_cardStagger.value - 0.55) / 0.45).clamp(0.0, 1.0),
    );
    Color? padLight(int key) =>
        padMode && _padKey == key ? SurvivalInk.brassGlow : null;
    return Opacity(
      opacity: t,
      child: Row(
        children: [
          Expanded(
            child: _DraftKey(
              key: const ValueKey('survival.draft.reroll'),
              word: 'REROLL',
              left: widget.powerUps.rerollsLeft,
              enabled: _canReroll,
              light: padLight(_rerollKey),
              onTap: _reroll,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DraftKey(
              key: const ValueKey('survival.draft.banish'),
              word: 'BANISH',
              left: widget.powerUps.banishesLeft,
              enabled: _canBanish,
              light: _banishArmed ? _banishEmber : padLight(_banishKey),
              onTap: _toggleBanish,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the draft's keys: its word and the count left, on the cards' ink,
/// lit from below while it is armed or a controller is on it.
class _DraftKey extends StatelessWidget {
  const _DraftKey({
    super.key,
    required this.word,
    required this.left,
    required this.enabled,
    required this.onTap,
    this.light,
  });

  final String word;
  final int left;
  final bool enabled;
  final VoidCallback onTap;
  final Color? light;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: '$word, $left left',
    child: Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? context.soundAction(onTap) : null,
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: light ?? SurvivalInk.plain,
            strokeWidth: 1.4,
          ),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            color: SurvivalInk.bg1.withValues(alpha: 0.96),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$word ',
                    style: hudMono(
                      11.5,
                      enabled ? SurvivalInk.ink : SurvivalInk.muted,
                      weight: FontWeight.w900,
                      spacing: 1.8,
                    ),
                  ),
                  TextSpan(
                    text: '$left',
                    style: hudMono(
                      11.5,
                      enabled ? SurvivalInk.brassBright : SurvivalInk.muted,
                      weight: FontWeight.w900,
                      spacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

CosmicPartyMember? _memberAt(List<CosmicPartyMember> party, int? slot) =>
    slot != null && slot >= 0 && slot < party.length ? party[slot] : null;

/// One offer: its drawn art (the one colored thing on the card), its name
/// with NEW or how far it is taken, what it does, who it is for, and what
/// kind of thing it is. Bare ink; only a controller's chosen card is lit
/// from below, in the offer's color (or every card, in the banish ember,
/// while BANISH is armed).
class _PowerUpCard extends StatelessWidget {
  const _PowerUpCard({
    super.key,
    required this.choice,
    required this.party,
    required this.onTap,
    this.light,
    this.banishing = false,
  });

  final OfferedPowerUpChoice choice;
  final List<CosmicPartyMember> party;

  /// The light under the card, or null for none.
  final Color? light;

  /// A tap banishes this card rather than taking it.
  final bool banishing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // A narrow card (the Fold's cover) keeps its title whole: smaller art,
    // and the NEW / level mark drops to the kind line.
    builder: (context, box) => _build(context, box.maxWidth < 330),
  );

  Widget _build(BuildContext context, bool compact) {
    final def = choice.def;
    final isNew = choice.currentLevel == 0 && !def.isKeystone;
    final leveled = def.showLevel && def.maxStacks > 1 && !def.isKeystone;
    final target = def.scope == PowerUpScope.companion
        ? _memberAt(party, choice.targetSlot)
        : null;
    final targetName = choice.targetName ?? target?.displayName;
    final increment = powerUpIncrementLabel(choice);
    final lines = def.isKeystone
        ? [
            for (final l in increment.split(','))
              if (l.trim().isNotEmpty) l.trim(),
          ]
        : [increment];
    final detail = powerUpTotalLabel(choice);

    Widget mark() => isNew
        ? Text(
            'NEW',
            style: hudMono(9.5, SurvivalInk.brassBright, spacing: 1.4),
          )
        : leveled
        ? _LevelPips(
            level: choice.currentLevel,
            maxStacks: def.maxStacks,
            tint: SurvivalInk.brassBright,
          )
        : const SizedBox.shrink();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                def.name.toUpperCase(),
                style: hudMono(
                  13.5,
                  SurvivalInk.ink,
                  weight: FontWeight.w900,
                  spacing: 1.0,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(top: 2), child: mark()),
            ],
          ],
        ),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              line,
              style: const TextStyle(
                color: SurvivalInk.ink,
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (detail != null) ...[
          const SizedBox(height: 1),
          Text(
            detail,
            style: const TextStyle(
              color: SurvivalInk.muted,
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
        ],
        // WHO IT IS FOR, on its own line: sharing a row with the tags it
        // ellipsized real names to "NO...", which is worse than no name.
        if (targetName != null && def.scope == PowerUpScope.companion) ...[
          const SizedBox(height: 6),
          Text(
            'FOR ${targetName.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hudMono(11, SurvivalInk.brassBright, spacing: 1.2),
          ),
        ],
        const SizedBox(height: 8),
        // A narrow card lets the mark drop to its own line rather than
        // shrinking the words.
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_kind(def)}  ·  ',
                    style: hudMono(
                      9,
                      SurvivalInk.muted,
                      spacing: compact ? 0.6 : 1.2,
                    ),
                  ),
                  TextSpan(
                    text: _rarityLabel(def.rarity),
                    style: hudMono(
                      9,
                      _rarityColor(def.rarity),
                      spacing: compact ? 0.6 : 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (compact) mark(),
          ],
        ),
      ],
    );

    return Semantics(
      button: true,
      label: [
        def.name,
        ...lines,
        if (targetName != null) 'for $targetName',
        if (isNew) 'new',
        if (banishing) 'banish',
      ].join(', '),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(onTap),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: light ?? SurvivalInk.plain,
            strokeWidth: 1.4,
          ),
          child: Container(
            color: SurvivalInk.bg1.withValues(alpha: 0.96),
            padding: const EdgeInsets.fromLTRB(10, 12, 12, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UpgradeArt(def: def, size: compact ? 44 : 58),
                const SizedBox(width: 10),
                Expanded(child: body),
                if (target?.imagePath != null) ...[
                  const SizedBox(width: 8),
                  _TargetCase(member: target!, size: compact ? 40 : 52),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// WHO a companion card is for: the Alchemon, in its element's light.
class _TargetCase extends StatelessWidget {
  const _TargetCase({required this.member, required this.size});

  final CosmicPartyMember member;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: CaseLightPainter(color: elementLight(member.element)),
    child: SizedBox.square(
      dimension: size,
      child: Center(
        child: Image.asset(
          member.imagePath!,
          width: size * 0.85,
          height: size * 0.85,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

/// What the run has taken so far: one still art per upgrade (per Alchemon,
/// for the ones that go to one), its level in the corner, and the face of
/// the Alchemon it went to. Painted once; none of it moves.
class _TakenStrip extends StatelessWidget {
  const _TakenStrip({required this.powerUps, required this.party});

  final PowerUpState powerUps;
  final List<CosmicPartyMember> party;

  @override
  Widget build(BuildContext context) {
    final order = <String>[];
    final picks = <String, ({PowerUpDef def, int? slot})>{};
    for (final a in powerUps.history) {
      final slot = a.def.scope == PowerUpScope.companion ? a.targetSlot : null;
      final key = '${a.def.id}:${slot ?? '-'}';
      if (picks.containsKey(key)) continue;
      order.add(key);
      picks[key] = (def: a.def, slot: slot);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TAKEN', style: hudMono(8.5, SurvivalInk.muted, spacing: 1.6)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: RepaintBoundary(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final k in order)
                  _TakenChip(
                    def: picks[k]!.def,
                    level: powerUps.getStacks(
                      picks[k]!.def.id,
                      slotIndex: picks[k]!.slot,
                    ),
                    member: _memberAt(party, picks[k]!.slot),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TakenChip extends StatelessWidget {
  const _TakenChip({required this.def, required this.level, this.member});

  final PowerUpDef def;
  final int level;
  final CosmicPartyMember? member;

  @override
  Widget build(BuildContext context) {
    final showLevel = def.showLevel && def.maxStacks > 1;
    final face = member?.imagePath;
    return Semantics(
      label: [
        def.name,
        if (showLevel) 'level $level',
        if (member != null) member!.displayName,
      ].join(', '),
      child: Container(
        width: 34,
        height: 34,
        color: SurvivalInk.bg1,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: UpgradeArt(def: def, size: 30, animate: false),
              ),
            ),
            if (face != null)
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  width: 15,
                  height: 15,
                  color: SurvivalInk.bg0.withValues(alpha: 0.85),
                  child: Image.asset(
                    face,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (showLevel)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  color: SurvivalInk.bg0.withValues(alpha: 0.85),
                  padding: const EdgeInsets.fromLTRB(3, 1, 2, 0),
                  child: Text(
                    '$level',
                    style: hudMono(
                      9,
                      level >= def.maxStacks
                          ? SurvivalInk.brassBright
                          : SurvivalInk.ink,
                      weight: FontWeight.w900,
                      spacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _kind(PowerUpDef def) {
  if (def.isKeystone) return 'KEYSTONE';
  return switch (def.category) {
    PowerUpCategory.shipWeapon => 'SHIP',
    PowerUpCategory.orbDefense => 'ORB',
    PowerUpCategory.statBoost || PowerUpCategory.rarePerk =>
      def.scope == PowerUpScope.companion ? 'ONE ALCHEMON' : 'TEAM',
    // Its own kind: a world surge deepens the map the fight is on.
    PowerUpCategory.mysticWorld => 'WORLD',
  };
}

Color _rarityColor(PowerUpRarity rarity) => switch (rarity) {
  PowerUpRarity.common => SurvivalInk.muted,
  PowerUpRarity.uncommon => const Color(0xFF7FB8D6),
  PowerUpRarity.rare => const Color(0xFFD9A06A),
  PowerUpRarity.legendary => SurvivalInk.brassGlow,
};

String _rarityLabel(PowerUpRarity rarity) => switch (rarity) {
  PowerUpRarity.common => 'COMMON',
  PowerUpRarity.uncommon => 'UNCOMMON',
  PowerUpRarity.rare => 'RARE',
  PowerUpRarity.legendary => 'LEGENDARY',
};

/// Bars, not dots: a segmented bar reads as "two of three taken" at a
/// glance where a row of circles reads as decoration.
class _LevelPips extends StatelessWidget {
  const _LevelPips({
    required this.level,
    required this.maxStacks,
    required this.tint,
  });

  final int level;
  final int maxStacks;
  final Color tint;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      maxStacks,
      (i) => Container(
        width: 10,
        height: 4,
        margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
        color: i < level ? tint : const Color(0xFF26262B),
      ),
    ),
  );
}
