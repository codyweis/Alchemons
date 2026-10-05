import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show CaseLightPainter, elementLight;
import 'package:flutter/material.dart';
import '../cosmic_survival_game.dart';
import '../../cosmic/cosmic_data.dart';
import 'survival_hud.dart';

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

/// A party member as a small specimen case: out in the arena, it stands lit
/// in its element's light inside an amber frame; in reserve, it waits dim
/// and colourless in dark glass. Its state, health and special sit outside
/// the art, in the HUD's monospace and glass tube.
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

  /// Public so the HUD around these can match their width rather than
  /// keeping its own copy of the number and drifting from it.
  static const cardWidth = 54.0;
  static const _artSize = 40.0;
  static const _labelSize = 7.0;

  static const activeColor = HudInk.amber;
  static const followColor = Color(0xFF7FD6C4);
  static const mutedColor = HudInk.muted;
  static const downColor = HudInk.danger;

  /// Reserve: the creature in grey, dimmed — present, not out.
  static const _reserve = ColorFilter.matrix([
    0.16, 0.32, 0.06, 0, 0, //
    0.16, 0.32, 0.06, 0, 0, //
    0.17, 0.34, 0.07, 0, 0, //
    0, 0, 0, 0.8, 0,
  ]);

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
    final ready =
        !state.dead && state.cooldown.isFinite && state.cooldown <= 0.05;
    return Semantics(
      label:
          '$name, ${state.label}, ${(state.hp * 100).round()} percent health',
      hint: action,
      button: true,
      enabled: !state.dead,
      child: Tooltip(
        message: '$name · ${state.label}\n$action',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: state.dead ? null : context.soundAction(onTap),
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: state.active || state.dead
                  ? color.withValues(alpha: 0.9)
                  : HudInk.line.withValues(alpha: 0.9),
              bracketSize: 7,
              strokeWidth: state.active ? 1.5 : 1.1,
            ),
            child: Container(
              width: cardWidth,
              color: HudInk.glass.withValues(alpha: 0.88),
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      state.label,
                      style: hudMono(_labelSize, color, spacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: _artSize,
                    child: CustomPaint(
                      painter: state.active
                          ? CaseLightPainter(
                              color: elementLight(member.element),
                            )
                          : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: state.dead ? 0.3 : 1,
                            child: state.active
                                ? portrait
                                : ColorFiltered(
                                    colorFilter: _reserve,
                                    child: portrait,
                                  ),
                          ),
                          if (state.dead)
                            const Icon(
                              Icons.close_rounded,
                              color: downColor,
                              size: 28,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 4,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: HudTubePainter(
                        state.hp,
                        state.hp > 0.5
                            ? followColor
                            : state.hp > 0.25
                            ? activeColor
                            : downColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      state.dead
                          ? 'DEFEATED'
                          : !state.cooldown.isFinite
                          // A Mystic whose world is out carries an INFINITE
                          // cooldown: the cast is spent for the deployment and
                          // only a recall gives it back. `.ceil()` on infinity
                          // throws in Dart, which crashed this widget's build —
                          // and a crashed build paints a grey error box over the
                          // party HUD in profile, where there is no red screen to
                          // explain it.
                          ? 'WORLD OUT'
                          : state.cooldown > 0.05
                          ? 'SP ${state.cooldown.ceil()}'
                          : 'SP READY',
                      style: hudMono(
                        _labelSize,
                        state.dead
                            ? downColor
                            : ready
                            ? HudInk.ink
                            : HudInk.muted,
                        spacing: 0.6,
                      ),
                    ),
                  ),
                  if (feedCount != null && state.active)
                    Text(
                      '$feedCount · ${(1 + (feedCount! ~/ 10)).clamp(1, 10)} vines',
                      style: hudMono(6, followColor, spacing: 0.3),
                    ),
                ],
              ),
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
    style: hudMono(24, color, weight: FontWeight.w900),
  );
}
