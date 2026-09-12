import 'package:alchemons/audio/audio.dart';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (matching the survival screen aesthetic)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  // Near-black ground so a saturated accent on top of it actually reads. The
  // previous set was parchment on parchment at low alpha throughout, which is
  // where "faded" came from: no element on the card was ever at full strength.
  static const bg0 = Color(0xFF050507);
  static const bg1 = Color(0xFF0B0B10);
  static const bg2 = Color(0xFF14141B);
  static const bg3 = Color(0xFF1A1A22);
  static const amber = Color(0xFFE0B65F);
  static const textPrimary = Color(0xFFF4EEDF);
  static const textMuted = Color(0xFF7A7488);
}

/// A card's accent: what the player's eye is supposed to sort on.
///
/// CATEGORY, not rarity. Rarity was doing this job and could not: most offers
/// are common, so two of the three cards on screen were the same beige almost
/// every time, and the one thing the player most needs to tell apart at a
/// glance — is this a ship gun, a companion stat, my Mystic's world — carried
/// no colour at all. Rarity keeps its own chip, where being occasionally
/// identical does no harm.
///
/// A Mystic world surge is coloured by its ELEMENT: it upgrades one specific
/// world standing on the map, and it should look like that world.
/// Lifts a colour until it can carry white text beside it and hold its own
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
    PowerUpCategory.statBoost => def.scope == PowerUpScope.companion
        ? const Color(0xFF5BE0B0)
        : const Color(0xFF9B8CFF),
    PowerUpCategory.rarePerk => const Color(0xFFE86BB0),
    PowerUpCategory.mysticWorld => const Color(0xFFE4C16A),
  };
}

class _BracketFramePainter extends CustomPainter {
  const _BracketFramePainter({required this.color});
  static const double bracketSize = 12;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    final s = bracketSize;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0)
      ..moveTo(w - s, 0)
      ..lineTo(w, 0)
      ..lineTo(w, s)
      ..moveTo(0, h - s)
      ..lineTo(0, h)
      ..lineTo(s, h)
      ..moveTo(w - s, h)
      ..lineTo(w, h)
      ..lineTo(w, h - s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BracketFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

class PowerUpSelectionOverlay extends StatefulWidget {
  final List<OfferedPowerUpChoice> choices;
  final int currentWave;
  final List<CosmicPartyMember> party;
  final PowerUpState powerUps;
  final void Function(PowerUpDef def, {int? targetSlot, String? targetName})
  onSelect;

  const PowerUpSelectionOverlay({
    super.key,
    required this.choices,
    required this.currentWave,
    required this.party,
    required this.powerUps,
    required this.onSelect,
  });

  @override
  State<PowerUpSelectionOverlay> createState() =>
      _PowerUpSelectionOverlayState();
}

class _PowerUpSelectionOverlayState extends State<PowerUpSelectionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _backdropFade;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _panelScale;
  late final Animation<double> _panelSlide;
  late final Animation<double> _cardStagger;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingKeystones = widget.choices.any(
      (choice) => choice.def.isKeystone,
    );
    final sharedChoiceGroup = widget.choices.isNotEmpty
        ? widget.choices.first.def.choiceGroup
        : null;
    final isThisOrThatOffer =
        widget.choices.length == 2 &&
        sharedChoiceGroup != null &&
        widget.choices.every(
          (choice) => choice.def.choiceGroup == sharedChoiceGroup,
        );
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, _) {
        final backdropAlpha = (0.84 * _backdropFade.value).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            color: _C.bg0.withValues(alpha: backdropAlpha),
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.15,
              colors: [
                _C.bg3.withValues(alpha: 0.36 * _backdropFade.value),
                _C.bg0.withValues(alpha: 0.9 * _backdropFade.value),
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
                      child: CustomPaint(
                        painter: _BracketFramePainter(
                          color: _C.amber.withValues(
                            alpha: 0.62 * _panelOpacity.value,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                          decoration: BoxDecoration(
                            // Darker and more opaque than the cards sitting on
                            // it, so there is real separation between the panel
                            // and its contents. The old version was one dim
                            // box inside another inside another, which is
                            // where "nested and boxy" came from.
                            color: _C.bg0.withValues(
                              alpha: 0.97 * _panelOpacity.value,
                            ),
                            border: Border.all(
                              color: _C.amber.withValues(alpha: 0.30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // One title, not two stacked: "FORGE OFFERINGS"
                              // over "ALCHEMICAL SURGE" said the same thing
                              // twice and pushed the cards down the screen.
                              const SizedBox(height: 2),
                              Text(
                                showingKeystones
                                    ? 'WAVE ${widget.currentWave} KEYSTONE'
                                    : isThisOrThatOffer
                                    ? 'UNIQUE CHOICE'
                                    : 'ALCHEMICAL SURGE',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: _C.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.2,
                                ),
                              ),
                              const SizedBox(height: 14),
                              for (
                                var i = 0;
                                i < widget.choices.length;
                                i++
                              ) ...[
                                _buildCard(i),
                                if (i < widget.choices.length - 1)
                                  const SizedBox(height: 10),
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
          ),
        );
      },
    );
  }

  Widget _buildCard(int i) {
    final count = widget.choices.length;
    final span = count <= 1 ? 0.0 : 0.35 / count;
    final start = (i / max(1, count)) * 0.55;
    final cardT = ((_cardStagger.value - start) / (span > 0 ? span : 0.55))
        .clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(cardT);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 18),
        child: _PowerUpCard(
          choice: widget.choices[i],
          onTap: () {
            final choice = widget.choices[i];
            HapticFeedback.mediumImpact();
            widget.onSelect(
              choice.def,
              targetSlot: choice.targetSlot,
              targetName: choice.targetName,
            );
          },
        ),
      ),
    );
  }
}

class _PowerUpCard extends StatelessWidget {
  final OfferedPowerUpChoice choice;
  final VoidCallback onTap;

  const _PowerUpCard({required this.choice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final def = choice.def;
    final rarity = def.rarity;
    final accent = powerUpAccentColor(def);
    final systemLabel = _powerUpSystemLabel(def);
    final systemIcon = _powerUpSystemIcon(def);
    final isCompanion = def.scope == PowerUpScope.companion;
    final offeredName = choice.targetName;
    final incrementLabel = powerUpIncrementLabel(choice);
    final totalLabel = powerUpTotalLabel(choice);
    final keystoneEffects = def.isKeystone
        ? incrementLabel
              .split(',')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList()
        : const <String>[];
    final showPips = def.showLevel && def.maxStacks > 1;
    final hasTarget = isCompanion && offeredName != null;

    return GestureDetector(
      onTap: context.soundAction(onTap),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // The accent is IN the card, not just around it: a wash that is
            // strongest at the spine and clears by the middle, so the eye
            // sorts the three offers by colour before reading a word of them.
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.lerp(_C.bg2, accent, 0.34)!,
                Color.lerp(_C.bg2, accent, 0.08)!,
                _C.bg1,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A solid spine at full strength. One saturated element per
                // card is what stops the whole panel reading as washed out.
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 11, 12, 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filled medallion rather than a 10%-alpha outline box.
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            systemIcon,
                            color: _C.bg0,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                def.name.toUpperCase(),
                                style: TextStyle(
                                  color: Color.lerp(
                                    _C.textPrimary,
                                    accent,
                                    0.25,
                                  ),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (def.isKeystone)
                                for (final effect in keystoneEffects)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      '+ $effect',
                                      style: const TextStyle(
                                        color: _C.textPrimary,
                                        fontSize: 13.5,
                                        height: 1.3,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                              else
                                Text(
                                  incrementLabel,
                                  style: const TextStyle(
                                    color: _C.textPrimary,
                                    fontSize: 13.5,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (totalLabel != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  totalLabel,
                                  style: const TextStyle(
                                    color: _C.textMuted,
                                    fontSize: 11.5,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                              // WHO IT IS FOR, on its own line.
                              //
                              // This shared a row with two tags and the level
                              // pips, so on a real phone with real creature
                              // names it ellipsized to "NO...", "BLIGH...",
                              // "TERRA..." — which is worse than omitting it,
                              // because the player can see that a name exists
                              // and still cannot read which of their party it
                              // names.
                              if (hasTarget) ...[
                                const SizedBox(height: 7),
                                Row(
                                  children: [
                                    Icon(
                                      AppIcons.arrow_forward_rounded,
                                      color: accent,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        offeredName.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _C.textPrimary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 9),
                              // What kind of thing it is, and how far along.
                              Row(
                                children: [
                                  _MiniTag(
                                    label: def.isKeystone
                                        ? 'DOCTRINE'
                                        : systemLabel,
                                    color: accent,
                                    filled: true,
                                  ),
                                  const SizedBox(width: 6),
                                  _MiniTag(
                                    label: _rarityLabel(rarity),
                                    color: _rarityColor(rarity),
                                  ),
                                  const Spacer(),
                                  if (showPips)
                                    _LevelPips(
                                      level: choice.currentLevel,
                                      maxStacks: def.maxStacks,
                                      tint: accent,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _powerUpSystemIcon(PowerUpDef def) {
  if (def.isKeystone) return AppIcons.account_tree_rounded;
  return switch (def.category) {
    PowerUpCategory.shipWeapon => AppIcons.rocket_launch_rounded,
    PowerUpCategory.orbDefense => AppIcons.blur_circular_rounded,
    PowerUpCategory.statBoost =>
      def.scope == PowerUpScope.companion
          ? AppIcons.pets_rounded
          : AppIcons.groups_rounded,
    PowerUpCategory.rarePerk =>
      def.scope == PowerUpScope.companion
          ? AppIcons.person_rounded
          : AppIcons.auto_awesome_rounded,
    PowerUpCategory.mysticWorld => AppIcons.public_rounded,
  };
}

String _powerUpSystemLabel(PowerUpDef def) {
  if (def.isKeystone) return 'DOCTRINE';
  return switch (def.category) {
    PowerUpCategory.shipWeapon => 'SHIP',
    PowerUpCategory.orbDefense => 'ORB',
    PowerUpCategory.statBoost =>
      def.scope == PowerUpScope.companion ? 'COMPANION' : 'GLOBAL',
    PowerUpCategory.rarePerk =>
      def.scope == PowerUpScope.companion ? 'COMPANION' : 'GLOBAL',
    // Its own banner: a world surge is not a companion buff, it deepens the
    // map the fight is happening on.
    PowerUpCategory.mysticWorld => 'WORLD',
  };
}

Color _rarityColor(PowerUpRarity rarity) => switch (rarity) {
  PowerUpRarity.common => const Color(0xFFB5A98A),
  PowerUpRarity.uncommon => const Color(0xFF5BC8E8),
  PowerUpRarity.rare => const Color(0xFFD98E4B),
  PowerUpRarity.legendary => const Color(0xFFE4C16A),
};

String _rarityLabel(PowerUpRarity rarity) => switch (rarity) {
  PowerUpRarity.common => 'COMMON',
  PowerUpRarity.uncommon => 'UNCOMMON',
  PowerUpRarity.rare => 'RARE',
  PowerUpRarity.legendary => 'LEGENDARY',
};

class _LevelPips extends StatelessWidget {
  final int level;
  final int maxStacks;
  final Color tint;

  const _LevelPips({
    required this.level,
    required this.maxStacks,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    // Bars, not dots: a row of glowing circles reads as decoration, where a
    // segmented bar reads as "two of three taken" at a glance.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStacks, (index) {
        final filled = index < level;
        return Container(
          width: 12,
          height: 5,
          margin: EdgeInsets.only(left: index == 0 ? 0 : 3),
          decoration: BoxDecoration(
            color: filled ? tint : tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _MiniTag({
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(3),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: filled ? _C.bg0 : color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
