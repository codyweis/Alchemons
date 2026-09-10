import 'package:alchemons/audio/audio.dart';
import 'package:flutter/material.dart';
import '../cosmic_survival_game.dart';
import '../../cosmic/cosmic_data.dart';

/// Live combat state takes precedence over the values cached on recall.
class SurvivalPartySlotState {
  const SurvivalPartySlotState({
    required this.active,
    required this.following,
    required this.dead,
    required this.hp,
    required this.cooldown,
  });

  factory SurvivalPartySlotState.fromGame(CosmicSurvivalGame game, int slot) {
    final companion = game.activeCompanions[slot];
    final hp = (companion?.hpPercent ?? game.companionHpFraction[slot] ?? 1.0)
        .clamp(0.0, 1.0);
    final dead =
        game.defeatedCompanionSlots.contains(slot) ||
        (companion?.isDead ?? false) ||
        hp <= 0;
    final active = companion != null && !dead;
    return SurvivalPartySlotState(
      active: active,
      following: active && game.tetheredCompanionSlot == slot,
      dead: dead,
      hp: dead ? 0 : hp,
      cooldown:
          companion?.specialCooldown ??
          game.companionSpecialCooldown[slot] ??
          0,
    );
  }

  final bool active;
  final bool following;
  final bool dead;
  final double hp;
  final double cooldown;
  String get label => dead
      ? 'DOWN'
      : following
      ? 'FOLLOW'
      : active
      ? 'ACTIVE'
      : 'RESERVE';
}

/// Cosmic-style colored deployment portraits, with status kept outside the art.
class SurvivalPartySlot extends StatelessWidget {
  const SurvivalPartySlot({
    super.key,
    required this.member,
    required this.state,
    required this.onTap,
    this.feedCount,
  });

  final CosmicPartyMember member;
  final SurvivalPartySlotState state;
  final VoidCallback onTap;
  final int? feedCount;

  /// The card's chrome at three quarters, and the art a tenth larger inside
  /// it — so the slot takes less of the screen while the thing you actually
  /// read at a glance, the creature, gets bigger rather than shrinking with
  /// it. Kept as named constants because the two scales pull opposite ways
  /// and the numbers have to stay reconcilable: art plus padding must still
  /// fit the card.
  /// Public so the HUD around these can match their width rather than
  /// keeping its own copy of the number and drifting from it.
  static const cardWidth = 54.0; // was 72
  static const _artSize = 42.0; // was 38
  static const _labelSize = 7.0; // was 9
  static const _statusIconSize = 8.0; // was 10

  static const activeColor = Color(0xFFFFC66D);
  static const followColor = Color(0xFF70E7D0);
  static const mutedColor = Color(0xFF9AA6B3);
  static const downColor = Color(0xFFFF7787);

  @override
  Widget build(BuildContext context) {
    final color = state.dead
        ? downColor
        : state.following
        ? followColor
        : state.active
        ? activeColor
        : mutedColor;
    final action = state.dead
        ? 'Defeated'
        : state.active
        ? 'Tap to recall'
        : 'Tap to deploy';
    final name = member.displayName.isEmpty ? 'Alchemon' : member.displayName;
    final portrait = member.imagePath == null
        ? _fallback(name, color)
        : Image.asset(
            member.imagePath!,
            width: _artSize,
            height: _artSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallback(name, color),
          );
    return Semantics(
      label:
          '$name, ${state.label}, ${(state.hp * 100).round()} percent health',
      hint: action,
      button: true,
      enabled: !state.dead,
      child: Tooltip(
        message: '$name · ${state.label}\n$action',
        child: InkWell(
          onTap: context.soundAction(state.dead ? null : onTap),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
            decoration: BoxDecoration(
              color: state.active
                  ? color.withValues(alpha: 0.16)
                  : const Color(0xFF141B24),
              border: Border.all(
                color: state.active || state.dead
                    ? color
                    : const Color(0xFF3A4552),
                width: state.active ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      state.dead
                          ? Icons.close_rounded
                          : state.following
                          ? Icons.link_rounded
                          : state.active
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: _statusIconSize,
                      color: color,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          state.label,
                          style: TextStyle(
                            color: color,
                            fontSize: _labelSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: _artSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: state.dead ? 0.25 : 1,
                        child: ColorFiltered(
                          colorFilter: state.active
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.dst,
                                )
                              : const ColorFilter.matrix([
                                  0,
                                  0,
                                  0,
                                  0,
                                  95,
                                  0,
                                  0,
                                  0,
                                  0,
                                  105,
                                  0,
                                  0,
                                  0,
                                  0,
                                  115,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                          child: portrait,
                        ),
                      ),
                      if (state.dead)
                        const Icon(
                          Icons.close_rounded,
                          color: downColor,
                          // Rides the art, so it grows with it.
                          size: 31,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: state.hp,
                    minHeight: 3,
                    backgroundColor: const Color(0xFF070B10),
                    color: state.hp > 0.5
                        ? followColor
                        : state.hp > 0.25
                        ? activeColor
                        : downColor,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    state.dead
                        ? 'DEFEATED'
                        : state.cooldown > 0.05
                        ? 'SP ${state.cooldown.ceil()}s'
                        : 'SP READY',
                    style: TextStyle(
                      color: state.dead ? downColor : Colors.white70,
                      fontSize: _labelSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (feedCount != null && state.active)
                  Text(
                    '$feedCount · ${(1 + (feedCount! ~/ 10)).clamp(1, 10)} vines',
                    style: const TextStyle(color: followColor, fontSize: 6),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Stands in for missing art, so it grows with the art rather than the
  /// chrome — a slot with no image should still read as the same size slot.
  Widget _fallback(String name, Color color) => Text(
    name.characters.first,
    style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold),
  );
}
