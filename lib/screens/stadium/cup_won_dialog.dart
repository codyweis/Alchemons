// lib/screens/stadium/cup_won_dialog.dart
//
// A cup won: the cup itself, brimming, over what it gives — the racer
// standing in its new spotlight, the cup as a keepsake for the home realm,
// and the title. Shown once, back on the Trials after the race that won it
// (or, for a cup won before there were rewards, the next time they open).

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/cup_rewards.dart';
import 'package:alchemons/screens/stadium/racer_gate.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_view.dart';
import 'package:alchemons/widgets/stadium_trophy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);
const Color _bg1 = Color(0xFF131316);

/// Shows each of [rewards] in turn, [racer] standing in its spotlight.
Future<void> showCupsWon(
  BuildContext context,
  List<CupReward> rewards, {
  CosmicPartyMember? racer,
}) async {
  for (final r in rewards) {
    if (!context.mounted) return;
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _CupWon(reward: r, racer: racer),
    );
  }
}

class _CupWon extends StatelessWidget {
  const _CupWon({required this.reward, this.racer});

  final CupReward reward;
  final CosmicPartyMember? racer;

  @override
  Widget build(BuildContext context) {
    final metal = reward.metal;
    final light = trophyLight(metal);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: light.withValues(alpha: 0.85),
          bracketSize: 14,
          strokeWidth: 1.3,
        ),
        child: Container(
          color: _bg1,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: StadiumTrophyEmblem(
                  height: 64,
                  look: TrophyLook(metal, fill: 1),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${reward.name.toUpperCase()} WON',
                textAlign: TextAlign.center,
                style: bracketText(
                  context,
                  16,
                  _brassHot,
                  weight: FontWeight.w800,
                  letterSpacing: 2.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All three won.',
                textAlign: TextAlign.center,
                style: bracketText(context, 12.5, _muted),
              ),
              const SizedBox(height: 14),
              const BracketSectionDivider(label: 'YOU RECEIVE'),
              const SizedBox(height: 10),
              _Line(
                art: SizedBox.square(
                  dimension: 64,
                  child: AlchemyEffectView(
                    effectKey: reward.effect,
                    dark: true,
                    inset: 10,
                    child: racer == null ? null : stadiumSprite(racer!, 44),
                  ),
                ),
                name: reward.statEffectName == null
                    ? reward.effectName
                    : '${reward.effectName} · ${reward.statEffectName}',
                line: reward.statEffectName == null
                    ? 'An alchemy effect, in your inventory.'
                    : 'Two alchemy effects, in your inventory; the second '
                          'is sold in the shop from now on.',
              ),
              _Line(
                art: SizedBox(
                  width: 64,
                  height: 56,
                  child: Center(
                    child: StadiumTrophyEmblem(
                      height: 38,
                      look: TrophyLook(metal, fill: 1),
                      animate: false,
                    ),
                  ),
                ),
                name: reward.statKeepsakeName == null
                    ? reward.keepsakeName
                    : '${reward.keepsakeName} · ${reward.statKeepsakeName}',
                line: reward.statKeepsakeName == null
                    ? 'A keepsake to stand in your home realm.'
                    : 'Two keepsakes to stand in your home realm.',
              ),
              _Line(
                art: SizedBox(
                  width: 64,
                  height: 40,
                  child: Center(
                    child: Text(
                      'TITLE',
                      style: bracketText(
                        context,
                        10,
                        _brass,
                        weight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ),
                name: reward.titleWords,
                line: 'A title to wear on your profile.',
              ),
              const SizedBox(height: 14),
              BracketButton(
                label: 'CONTINUE',
                palette: BracketPalette.dark,
                accent: _brass,
                height: 42,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.art, required this.name, required this.line});

  final Widget art;
  final String name, line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          art,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: bracketText(
                    context,
                    12.5,
                    _ink,
                    weight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(line, style: bracketText(context, 11.5, _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
