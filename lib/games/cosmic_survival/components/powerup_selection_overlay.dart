import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (matching the survival screen aesthetic)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg0 = Color(0xFF080808);
  static const bg1 = Color(0xFF111111);
  static const bg2 = Color(0xFF171511);
  static const bg3 = Color(0xFF201D17);
  static const amber = Color(0xFFC4A35A);
  static const teal = Color(0xFF5BC8E8);
  static const textPrimary = Color(0xFFE8DFC8);
  static const textSecondary = Color(0xFFB5A98A);
  static const textMuted = Color(0xFF6B6050);
  static const borderDim = Color(0xFF2E2A23);
}

class _BracketFramePainter extends CustomPainter {
  const _BracketFramePainter({required this.color, this.bracketSize = 12});

  final Color color;
  final double bracketSize;

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
      oldDelegate.color != color || oldDelegate.bracketSize != bracketSize;
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
        widget.choices.every(
          (choice) => choice.def.choiceGroup == sharedChoiceGroup,
        );
    return Container(
      decoration: BoxDecoration(
        color: _C.bg0.withValues(alpha: 0.84),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.15,
          colors: [
            _C.bg3.withValues(alpha: 0.36),
            _C.bg0.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: CustomPaint(
              painter: _BracketFramePainter(
                color: _C.amber.withValues(alpha: 0.62),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                decoration: BoxDecoration(
                  color: _C.bg1.withValues(alpha: 0.96),
                  border: Border.all(color: _C.borderDim),
                  boxShadow: [
                    BoxShadow(
                      color: _C.amber.withValues(alpha: 0.10),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _EtchedDivider(label: 'FORGE OFFERINGS'),
                    const SizedBox(height: 10),
                    Text(
                      showingKeystones
                          ? 'WAVE ${widget.currentWave} KEYSTONE'
                          : isThisOrThatOffer
                          ? 'THIS OR THAT'
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
    );
  }
}

class _EtchedDivider extends StatelessWidget {
  final String label;

  const _EtchedDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _C.borderDim)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: _C.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: _C.borderDim)),
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
    final hasSystemTag = !isCompanion && !def.isKeystone;

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: accent.withValues(alpha: 0.6),
          bracketSize: 9,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            color: _C.bg2.withValues(alpha: 0.92),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.07),
                blurRadius: 16,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  border: Border.all(color: accent.withValues(alpha: 0.32)),
                ),
                child: Icon(systemIcon, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            def.name,
                            style: const TextStyle(
                              color: _C.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MiniTag(label: _rarityLabel(rarity), color: accent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (def.isKeystone)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final effect in keystoneEffects)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '+ $effect',
                                style: const TextStyle(
                                  color: _C.textPrimary,
                                  fontSize: 14,
                                  height: 1.3,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      Text(
                        incrementLabel,
                        style: const TextStyle(
                          color: _C.textPrimary,
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (totalLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        totalLabel,
                        style: const TextStyle(
                          color: _C.textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (showPips || hasTarget || hasSystemTag) ...[
                      const SizedBox(height: 9),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: hasTarget
                                ? Row(
                                    children: [
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: _C.teal,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          offeredName.toUpperCase(),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _C.teal,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : hasSystemTag
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: _MiniTag(
                                      label: systemLabel,
                                      color: _C.textSecondary,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          if (showPips) ...[
                            const SizedBox(width: 10),
                            _LevelPips(
                              level: choice.currentLevel,
                              maxStacks: def.maxStacks,
                              tint: _C.teal,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStacks, (index) {
        final filled = index < level;
        return Container(
          width: 9,
          height: 9,
          margin: EdgeInsets.only(left: index == 0 ? 0 : 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? tint : Colors.transparent,
            border: Border.all(
              color: filled ? tint : tint.withValues(alpha: 0.3),
              width: 1.1,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.55),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
        );
      }),
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 12,
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
    PowerUpCategory.statBoost =>
      def.scope == PowerUpScope.companion
          ? Icons.pets_rounded
          : Icons.groups_rounded,
    PowerUpCategory.rarePerk =>
      def.scope == PowerUpScope.companion
          ? Icons.person_rounded
          : Icons.auto_awesome_rounded,
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
