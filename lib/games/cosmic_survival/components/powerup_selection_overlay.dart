import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _PowerUpSelectionOverlayState extends State<PowerUpSelectionOverlay> {
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
        widget.choices.every((choice) => choice.def.choiceGroup == sharedChoiceGroup);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.76),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF040608).withValues(alpha: 0.92),
            const Color(0xFF0A0E14).withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 376,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF11151D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2A3340).withValues(alpha: 0.95),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.28),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _EtchedHeader(),
              const SizedBox(height: 8),
              Text(
                showingKeystones
                    ? 'WAVE ${widget.currentWave} KEYSTONE'
                    : isThisOrThatOffer
                    ? 'THIS OR THAT'
                    : 'ALCHEMICAL SURGE',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFFE8DCC8),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                showingKeystones
                    ? 'Choose exactly one Keystone path. Unpicked paths are removed for this run. Guardian specials now scale with stats.'
                    : isThisOrThatOffer
                    ? 'Choose one doctrine. The other path is removed for this run.'
                    : 'Choose one upgrade for the next push. Reminder: guardian specials scale by stat thresholds (Kin needs Beauty + Intelligence).',
                style: const TextStyle(color: Color(0xFF8A7B6A), fontSize: 11),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < widget.choices.length; i++) ...[
                _PowerUpCard(
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
                if (i < widget.choices.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EtchedHeader extends StatelessWidget {
  const _EtchedHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFF3A3020))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'FORGE OFFERINGS',
            style: TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF9FB3C8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFF3A4658))),
      ],
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
    final accent = _rarityColor(rarity);
    final systemLabel = _powerUpSystemLabel(def);
    final systemIcon = _powerUpSystemIcon(def);
    final isCompanion = def.scope == PowerUpScope.companion;
    final offeredName = choice.targetName;
    final nextLevel = choice.currentLevel + 1;
    final incrementLabel = powerUpIncrementLabel(choice);
    final totalLabel = powerUpTotalLabel(choice);
    final keystoneEffects = def.isKeystone
      ? incrementLabel
          .split(',')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList()
      : const <String>[];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: const Color(0xFF161B23),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.07),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  child: Icon(systemIcon, color: accent, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              def.name,
                              style: const TextStyle(
                                color: Color(0xFFE8DCC8),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (def.showLevel && def.maxStacks > 1)
                            Text(
                              'Lv $nextLevel/${def.maxStacks}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF0EA5E9),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _MiniTag(label: _rarityLabel(rarity), color: accent),
                          if (!def.isKeystone)
                            _MiniTag(
                              label: systemLabel,
                              color: const Color(0xFF9FB3C8),
                            ),
                          if (def.isKeystone)
                            const _MiniTag(
                              label: 'KEYSTONE',
                              color: Color(0xFFD97706),
                            ),

                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        def.description,
                        style: const TextStyle(
                          color: Color(0xFF9FA8B5),
                          fontSize: 10,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (def.isKeystone)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final effect in keystoneEffects)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '+ $effect',
                                  style: const TextStyle(
                                    color: Color(0xFFE8DCC8),
                                    fontSize: 11.3,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        Text(
                          incrementLabel,
                          style: const TextStyle(
                            color: Color(0xFFE8DCC8),
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (totalLabel != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          totalLabel,
                          style: const TextStyle(
                            color: Color(0xFF8A7B6A),
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (isCompanion && offeredName != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Applied to $offeredName',
                          style: const TextStyle(
                            color: Color(0xFF9FB3C8),
                            fontSize: 9.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

IconData _powerUpSystemIcon(PowerUpDef def) {
  if (def.isKeystone) return Icons.account_tree_rounded;
  return switch (def.category) {
    PowerUpCategory.shipWeapon => Icons.rocket_launch_rounded,
    PowerUpCategory.orbDefense => Icons.blur_circular_rounded,
    PowerUpCategory.statBoost => def.scope == PowerUpScope.companion
        ? Icons.pets_rounded
        : Icons.groups_rounded,
    PowerUpCategory.rarePerk => def.scope == PowerUpScope.companion
        ? Icons.person_rounded
        : Icons.auto_awesome_rounded,
  };
}

String _powerUpSystemLabel(PowerUpDef def) {
  if (def.isKeystone) return 'DOCTRINE';
  return switch (def.category) {
    PowerUpCategory.shipWeapon => 'SHIP',
    PowerUpCategory.orbDefense => 'ORB',
    PowerUpCategory.statBoost => def.scope == PowerUpScope.companion
        ? 'COMPANION'
        : 'GLOBAL',
    PowerUpCategory.rarePerk => def.scope == PowerUpScope.companion
        ? 'COMPANION'
        : 'GLOBAL',
  };
}

Color _rarityColor(PowerUpRarity rarity) => switch (rarity) {
  PowerUpRarity.common => const Color(0xFFD97706),
  PowerUpRarity.uncommon => const Color(0xFF0EA5E9),
  PowerUpRarity.rare => const Color(0xFFF97316),
  PowerUpRarity.legendary => const Color(0xFFFFD166),
};

String _rarityLabel(PowerUpRarity rarity) => switch (rarity) {
  PowerUpRarity.common => 'COMMON',
  PowerUpRarity.uncommon => 'UNCOMMON',
  PowerUpRarity.rare => 'RARE',
  PowerUpRarity.legendary => 'LEGENDARY',
};
