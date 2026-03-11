import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';

Widget _buildScorchedContestScorePanel({
  required BuildContext context,
  required String leftScoreText,
  required String rightScoreText,
  required Color leftColor,
  required Color rightColor,
  required String winnerName,
  required String loserName,
  required Color winnerColor,
  required double winnerTextOpacity,
}) {
  final fc = FC.of(context);
  final ft = FT(fc);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fc.bg3.withValues(alpha: 0.94),
          fc.bg2.withValues(alpha: 0.94),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: fc.borderMid),
      boxShadow: [
        BoxShadow(
          color: fc.amberGlow.withValues(alpha: 0.16),
          blurRadius: 16,
          spreadRadius: 1.2,
        ),
      ],
    ),
    child: Column(
      children: [
        Text(
          'ALCHEMICAL SCORE',
          style: ft.label.copyWith(
            color: fc.amberBright,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                leftScoreText,
                style: ft.mono.copyWith(
                  color: leftColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                rightScoreText,
                textAlign: TextAlign.right,
                style: ft.mono.copyWith(
                  color: rightColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: winnerTextOpacity,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: fc.bg1.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: winnerColor.withValues(alpha: 0.74)),
            ),
            child: Column(
              children: [
                Text(
                  '${winnerName.toUpperCase()} WINS',
                  textAlign: TextAlign.center,
                  style: ft.mono.copyWith(
                    color: winnerColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  loserName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: ft.label.copyWith(
                    color: fc.textMuted.withValues(alpha: 0.9),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class CosmicBeautyContestArenaOverlay extends StatefulWidget {
  const CosmicBeautyContestArenaOverlay({
    super.key,
    required this.player,
    required this.opponentMember,
    required this.playerScore,
    required this.opponentScore,
  });

  final CosmicPartyMember player;
  final CosmicPartyMember opponentMember;
  final double playerScore;
  final double opponentScore;

  @override
  State<CosmicBeautyContestArenaOverlay> createState() =>
      _CosmicBeautyContestArenaOverlayState();
}

class _CosmicBeautyContestArenaOverlayState
    extends State<CosmicBeautyContestArenaOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline;
  bool _canContinue = false;

  bool get _playerWon => widget.playerScore >= widget.opponentScore;

  @override
  void initState() {
    super.initState();
    _timeline =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 18000),
        )..addListener(() {
          if (!_canContinue && _timeline.value >= 0.97) {
            setState(() => _canContinue = true);
          }
        });
    _timeline.forward();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  List<String> _playerAbilities() {
    final tags = <String>[
      '${widget.player.element} aura',
      'Beauty ${widget.player.statBeauty.toStringAsFixed(2)}',
    ];
    final visuals = widget.player.spriteVisuals;
    if (visuals?.isPrismatic == true) {
      tags.add('Prismatic shimmer');
    }
    final fx = visuals?.alchemyEffect;
    if (fx == 'prismatic_cascade') {
      tags.add('Prismatic cascade');
    }
    if (fx == 'alchemy_glow' || fx == 'elemental_aura') {
      tags.add('Radiant glow');
    }
    final scale = visuals?.scale ?? 1.0;
    if (scale > 1.15) {
      tags.add('Grand presence');
    }
    if (scale < 0.92) {
      tags.add('Petite grace');
    }
    return tags.take(3).toList();
  }

  List<String> _opponentAbilities() {
    final tags = <String>[
      '${widget.opponentMember.element} aura',
      'Beauty ${widget.opponentMember.statBeauty.toStringAsFixed(2)}',
    ];
    final visuals = widget.opponentMember.spriteVisuals;
    if (visuals?.isPrismatic == true) {
      tags.add('Prismatic shimmer');
    }
    final fx = visuals?.alchemyEffect;
    if (fx == 'prismatic_cascade') {
      tags.add('Prismatic cascade');
    }
    if (fx == 'alchemy_glow' || fx == 'elemental_aura') {
      tags.add('Radiant glow');
    }
    final scale = visuals?.scale ?? 1.0;
    if (scale > 1.15) {
      tags.add('Grand presence');
    }
    if (scale < 0.92) {
      tags.add('Petite grace');
    }
    return tags.take(3).toList();
  }

  Widget _buildAbilityChip(String text, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerAbilities = _playerAbilities();
    final opponentAbilities = _opponentAbilities();
    final showcaseBadges = <String>[];
    final maxBadgeCount = max(playerAbilities.length, opponentAbilities.length);
    for (var i = 0; i < maxBadgeCount; i++) {
      if (i < playerAbilities.length) {
        showcaseBadges.add(
          '${widget.player.displayName} • ${playerAbilities[i]}',
        );
      }
      if (i < opponentAbilities.length) {
        showcaseBadges.add(
          '${widget.opponentMember.displayName} • ${opponentAbilities[i]}',
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _timeline,
        builder: (context, _) {
          final t = _timeline.value.clamp(0.0, 1.0);
          final showcaseT = ((t - 0.12) / 0.66).clamp(0.0, 1.0);
          final scoreT = ((t - 0.80) / 0.14).clamp(0.0, 1.0);
          final resultT = ((t - 0.94) / 0.06).clamp(0.0, 1.0);

          final countedPlayerScore =
              widget.playerScore * Curves.easeOutCubic.transform(scoreT);
          final countedOpponentScore =
              widget.opponentScore * Curves.easeOutCubic.transform(scoreT);

          final winnerTextOpacity = Curves.easeOut.transform(resultT);
          final winnerName = _playerWon
              ? widget.player.displayName
              : widget.opponentMember.displayName;
          final loserName = _playerWon
              ? widget.opponentMember.displayName
              : widget.player.displayName;
          final winnerColor = _playerWon
              ? const Color(0xFFFFC1E3)
              : const Color(0xFFB2EBF2);

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'BEAUTY CONTEST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (showcaseBadges.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Builder(
                              builder: (context) {
                                final badgeCount = showcaseBadges.length;
                                final segment = 1.0 / badgeCount;
                                final rawIndex = (showcaseT / segment).floor();
                                final badgeIndex = max(
                                  0,
                                  min(badgeCount - 1, rawIndex),
                                );
                                final localT =
                                    ((showcaseT - (badgeIndex * segment)) /
                                            segment)
                                        .clamp(0.0, 1.0);
                                final badgeOpacity = showcaseT >= 1.0
                                    ? 0.0
                                    : localT < 0.2
                                    ? Curves.easeOut.transform(localT / 0.2)
                                    : localT < 0.72
                                    ? 1.0
                                    : 1.0 -
                                          Curves.easeIn.transform(
                                            (localT - 0.72) / 0.28,
                                          );
                                return _buildAbilityChip(
                                  showcaseBadges[badgeIndex],
                                  badgeOpacity,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildScorchedContestScorePanel(
                      context: context,
                      leftScoreText:
                          '${widget.player.displayName}: ${countedPlayerScore.toStringAsFixed(2)}',
                      rightScoreText:
                          '${widget.opponentMember.displayName}: ${countedOpponentScore.toStringAsFixed(2)}',
                      leftColor: const Color(0xFFFF8AC5),
                      rightColor: const Color(0xFF80DEEA),
                      winnerName: winnerName,
                      loserName: loserName,
                      winnerColor: winnerColor,
                      winnerTextOpacity: winnerTextOpacity,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _canContinue
                          ? () => Navigator.of(context).pop()
                          : null,
                      child: Text(_canContinue ? 'CONTINUE' : 'JUDGING...'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CosmicSpeedContestArenaOverlay extends StatefulWidget {
  const CosmicSpeedContestArenaOverlay({
    super.key,
    required this.player,
    required this.opponentMember,
    required this.playerScore,
    required this.opponentScore,
  });

  final CosmicPartyMember player;
  final CosmicPartyMember opponentMember;
  final double playerScore;
  final double opponentScore;

  @override
  State<CosmicSpeedContestArenaOverlay> createState() =>
      _CosmicSpeedContestArenaOverlayState();
}

class _CosmicSpeedContestArenaOverlayState
    extends State<CosmicSpeedContestArenaOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline;
  bool _canContinue = false;

  bool get _playerWon => widget.playerScore >= widget.opponentScore;

  List<String> _speedFactorsForMember(CosmicPartyMember member) {
    final tags = <String>['Speed ${member.statSpeed.toStringAsFixed(2)}'];
    final element = member.element.toLowerCase().trim();
    if (element == 'lightning' ||
        element == 'water' ||
        element == 'ice' ||
        element == 'air') {
      tags.add('${member.element} pace bonus');
    } else if (element == 'earth' || element == 'mud' || element == 'poison') {
      tags.add('${member.element} drag risk');
    }

    final family = member.family.toLowerCase().trim();
    if (family == 'wing') {
      tags.add('Wingline acceleration');
    } else if (family == 'let') {
      tags.add('Quick launch frame');
    } else if (family == 'kin') {
      tags.add('Draft control');
    } else if (family == 'horn' || family == 'mane') {
      tags.add('Power build-up');
    }

    final scale = member.spriteVisuals?.scale ?? 1.0;
    if (scale < 0.92) {
      tags.add('Compact burst frame');
    } else if (scale > 1.15) {
      tags.add('Larger drag profile');
    }
    return tags.take(3).toList();
  }

  @override
  void initState() {
    super.initState();
    _timeline =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 14000),
        )..addListener(() {
          if (!_canContinue && _timeline.value >= 0.96) {
            setState(() => _canContinue = true);
          }
        });
    _timeline.forward();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  Widget _buildSpeedBadge(String text, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1B34).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF4FC3F7), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFE1F5FE),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.75,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _timeline,
        builder: (context, _) {
          final t = _timeline.value.clamp(0.0, 1.0);
          final showcaseT = ((t - 0.10) / 0.64).clamp(0.0, 1.0);
          final scoreT = ((t - 0.76) / 0.14).clamp(0.0, 1.0);
          final resultT = ((t - 0.90) / 0.10).clamp(0.0, 1.0);
          final winnerTextOpacity = Curves.easeOut.transform(resultT);

          final badgeFlow = <String>[
            ...() {
              final playerTags = _speedFactorsForMember(widget.player);
              final opponentTags = _speedFactorsForMember(
                widget.opponentMember,
              );
              final out = <String>[];
              final maxTags = max(playerTags.length, opponentTags.length);
              for (var i = 0; i < maxTags; i++) {
                if (i < playerTags.length) {
                  out.add('${widget.player.displayName} • ${playerTags[i]}');
                }
                if (i < opponentTags.length) {
                  out.add(
                    '${widget.opponentMember.displayName} • ${opponentTags[i]}',
                  );
                }
              }
              return out;
            }(),
          ];
          final badgeCount = badgeFlow.length;
          final segment = 1.0 / badgeCount;
          final rawIndex = (showcaseT / segment).floor();
          final badgeIndex = max(0, min(badgeCount - 1, rawIndex));
          final localT = ((showcaseT - (badgeIndex * segment)) / segment).clamp(
            0.0,
            1.0,
          );
          final badgeOpacity = showcaseT >= 1.0
              ? 0.0
              : localT < 0.2
              ? Curves.easeOut.transform(localT / 0.2)
              : localT < 0.72
              ? 1.0
              : 1.0 - Curves.easeIn.transform((localT - 0.72) / 0.28);

          final countedPlayerScore =
              widget.playerScore * Curves.easeOutCubic.transform(scoreT);
          final countedOpponentScore =
              widget.opponentScore * Curves.easeOutCubic.transform(scoreT);

          final winnerName = _playerWon
              ? widget.player.displayName
              : widget.opponentMember.displayName;
          final loserName = _playerWon
              ? widget.opponentMember.displayName
              : widget.player.displayName;
          final winnerColor = _playerWon
              ? const Color(0xFF81D4FA)
              : const Color(0xFFFFCC80);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Text(
                        'SPEED CONTEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 18),
                        _buildSpeedBadge(badgeFlow[badgeIndex], badgeOpacity),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildScorchedContestScorePanel(
                    context: context,
                    leftScoreText:
                        '${widget.player.displayName}: ${countedPlayerScore.toStringAsFixed(2)}',
                    rightScoreText:
                        '${widget.opponentMember.displayName}: ${countedOpponentScore.toStringAsFixed(2)}',
                    leftColor: const Color(0xFF81D4FA),
                    rightColor: const Color(0xFFFFCC80),
                    winnerName: winnerName,
                    loserName: loserName,
                    winnerColor: winnerColor,
                    winnerTextOpacity: winnerTextOpacity,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _canContinue
                        ? () => Navigator.of(context).pop()
                        : null,
                    child: Text(
                      _canContinue ? 'CONTINUE' : 'CHECKING TIMES...',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CosmicStrengthContestArenaOverlay extends StatefulWidget {
  const CosmicStrengthContestArenaOverlay({
    super.key,
    required this.player,
    required this.opponentMember,
    required this.playerScore,
    required this.opponentScore,
  });

  final CosmicPartyMember player;
  final CosmicPartyMember opponentMember;
  final double playerScore;
  final double opponentScore;

  @override
  State<CosmicStrengthContestArenaOverlay> createState() =>
      _CosmicStrengthContestArenaOverlayState();
}

class _CosmicStrengthContestArenaOverlayState
    extends State<CosmicStrengthContestArenaOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline;
  bool _canContinue = false;

  bool get _playerWon => widget.playerScore >= widget.opponentScore;

  @override
  void initState() {
    super.initState();
    _timeline =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 14000),
        )..addListener(() {
          if (!_canContinue && _timeline.value >= 0.96) {
            setState(() => _canContinue = true);
          }
        });
    _timeline.forward();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  List<String> _strengthFactorsForMember(CosmicPartyMember member) {
    final tags = <String>['Strength ${member.statStrength.toStringAsFixed(2)}'];
    final element = member.element.toLowerCase().trim();
    if (element == 'earth' ||
        element == 'lava' ||
        element == 'fire' ||
        element == 'mud') {
      tags.add('${member.element} force bonus');
    } else if (element == 'air' || element == 'water') {
      tags.add('${member.element} impact penalty');
    }
    final family = member.family.toLowerCase().trim();
    if (family == 'horn') {
      tags.add('Hornline power shove');
    } else if (family == 'mane') {
      tags.add('Maneline body force');
    } else if (family == 'kin') {
      tags.add('Kin leverage control');
    }

    final scale = member.spriteVisuals?.scale ?? 1.0;
    if (scale > 1.15) {
      tags.add('Heavy frame advantage');
    } else if (scale < 0.92) {
      tags.add('Lighter mass drawback');
    }
    return tags.take(3).toList();
  }

  Widget _buildStrengthBadge(String text, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF2A120A).withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFFB74D), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFFFF3E0),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.75,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeFlow = <String>[
      ...() {
        final playerTags = _strengthFactorsForMember(widget.player);
        final opponentTags = _strengthFactorsForMember(widget.opponentMember);
        final out = <String>[];
        final maxTags = max(playerTags.length, opponentTags.length);
        for (var i = 0; i < maxTags; i++) {
          if (i < playerTags.length) {
            out.add('${widget.player.displayName} • ${playerTags[i]}');
          }
          if (i < opponentTags.length) {
            out.add(
              '${widget.opponentMember.displayName} • ${opponentTags[i]}',
            );
          }
        }
        return out;
      }(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _timeline,
        builder: (context, _) {
          final t = _timeline.value.clamp(0.0, 1.0);
          final showcaseT = ((t - 0.10) / 0.64).clamp(0.0, 1.0);
          final scoreT = ((t - 0.76) / 0.14).clamp(0.0, 1.0);
          final resultT = ((t - 0.90) / 0.10).clamp(0.0, 1.0);
          final winnerTextOpacity = Curves.easeOut.transform(resultT);

          final badgeCount = max(1, badgeFlow.length);
          final segment = 1.0 / badgeCount;
          final rawIndex = (showcaseT / segment).floor();
          final badgeIndex = max(0, min(badgeCount - 1, rawIndex));
          final localT = ((showcaseT - (badgeIndex * segment)) / segment).clamp(
            0.0,
            1.0,
          );
          final badgeOpacity = showcaseT >= 1.0
              ? 0.0
              : localT < 0.2
              ? Curves.easeOut.transform(localT / 0.2)
              : localT < 0.72
              ? 1.0
              : 1.0 - Curves.easeIn.transform((localT - 0.72) / 0.28);

          final countedPlayerScore =
              widget.playerScore * Curves.easeOutCubic.transform(scoreT);
          final countedOpponentScore =
              widget.opponentScore * Curves.easeOutCubic.transform(scoreT);

          final winnerName = _playerWon
              ? widget.player.displayName
              : widget.opponentMember.displayName;
          final loserName = _playerWon
              ? widget.opponentMember.displayName
              : widget.player.displayName;
          final winnerColor = _playerWon
              ? const Color(0xFFFFCC80)
              : const Color(0xFFFFAB91);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Text(
                        'STRENGTH CONTEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 18),
                        _buildStrengthBadge(
                          badgeFlow.isEmpty
                              ? 'STRENGTH CHECK'
                              : badgeFlow[badgeIndex],
                          badgeOpacity,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildScorchedContestScorePanel(
                    context: context,
                    leftScoreText:
                        '${widget.player.displayName}: ${countedPlayerScore.toStringAsFixed(2)}',
                    rightScoreText:
                        '${widget.opponentMember.displayName}: ${countedOpponentScore.toStringAsFixed(2)}',
                    leftColor: const Color(0xFFFFCC80),
                    rightColor: const Color(0xFFFFAB91),
                    winnerName: winnerName,
                    loserName: loserName,
                    winnerColor: winnerColor,
                    winnerTextOpacity: winnerTextOpacity,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _canContinue
                        ? () => Navigator.of(context).pop()
                        : null,
                    child: Text(_canContinue ? 'CONTINUE' : 'JUDGING POWER...'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CosmicIntelligenceContestArenaOverlay extends StatefulWidget {
  const CosmicIntelligenceContestArenaOverlay({
    super.key,
    required this.player,
    required this.opponentMember,
    required this.playerScore,
    required this.opponentScore,
  });

  final CosmicPartyMember player;
  final CosmicPartyMember opponentMember;
  final double playerScore;
  final double opponentScore;

  @override
  State<CosmicIntelligenceContestArenaOverlay> createState() =>
      _CosmicIntelligenceContestArenaOverlayState();
}

class _CosmicIntelligenceContestArenaOverlayState
    extends State<CosmicIntelligenceContestArenaOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline;
  bool _canContinue = false;

  bool get _playerWon => widget.playerScore >= widget.opponentScore;

  @override
  void initState() {
    super.initState();
    _timeline =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 14000),
        )..addListener(() {
          if (!_canContinue && _timeline.value >= 0.96) {
            setState(() => _canContinue = true);
          }
        });
    _timeline.forward();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  List<String> _intelligenceFactorsForMember(CosmicPartyMember member) {
    final tags = <String>[
      'Intelligence ${member.statIntelligence.toStringAsFixed(2)}',
    ];
    final element = member.element.toLowerCase().trim();
    if (element == 'spirit' ||
        element == 'light' ||
        element == 'dark' ||
        element == 'crystal') {
      tags.add('${member.element} cognition bonus');
    } else if (element == 'lava' || element == 'mud' || element == 'blood') {
      tags.add('${member.element} focus penalty');
    }

    final family = member.family.toLowerCase().trim();
    if (family == 'mask') {
      tags.add('Maskline analysis edge');
    } else if (family == 'kin') {
      tags.add('Kinline memory network');
    } else if (family == 'pip') {
      tags.add('Pipline pattern speed');
    } else if (family == 'horn' || family == 'mane') {
      tags.add('Powerline thought drag');
    }

    if (tags.length < 3) {
      tags.add('Lineage diversity weighting');
    }
    return tags.take(3).toList();
  }

  Widget _buildIntelligenceBadge(String text, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF170F2B).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFB39DDB), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9575CD).withValues(alpha: 0.22),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFEDE7F6),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.75,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeFlow = <String>[
      ...() {
        final playerTags = _intelligenceFactorsForMember(widget.player);
        final opponentTags = _intelligenceFactorsForMember(
          widget.opponentMember,
        );
        final out = <String>[];
        final maxTags = max(playerTags.length, opponentTags.length);
        for (var i = 0; i < maxTags; i++) {
          if (i < playerTags.length) {
            out.add('${widget.player.displayName} • ${playerTags[i]}');
          }
          if (i < opponentTags.length) {
            out.add(
              '${widget.opponentMember.displayName} • ${opponentTags[i]}',
            );
          }
        }
        return out;
      }(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _timeline,
        builder: (context, _) {
          final t = _timeline.value.clamp(0.0, 1.0);
          final showcaseT = ((t - 0.10) / 0.64).clamp(0.0, 1.0);
          final scoreT = ((t - 0.76) / 0.14).clamp(0.0, 1.0);
          final resultT = ((t - 0.90) / 0.10).clamp(0.0, 1.0);
          final winnerTextOpacity = Curves.easeOut.transform(resultT);

          final badgeCount = max(1, badgeFlow.length);
          final segment = 1.0 / badgeCount;
          final rawIndex = (showcaseT / segment).floor();
          final badgeIndex = max(0, min(badgeCount - 1, rawIndex));
          final localT = ((showcaseT - (badgeIndex * segment)) / segment).clamp(
            0.0,
            1.0,
          );
          final badgeOpacity = showcaseT >= 1.0
              ? 0.0
              : localT < 0.2
              ? Curves.easeOut.transform(localT / 0.2)
              : localT < 0.72
              ? 1.0
              : 1.0 - Curves.easeIn.transform((localT - 0.72) / 0.28);

          final countedPlayerScore =
              widget.playerScore * Curves.easeOutCubic.transform(scoreT);
          final countedOpponentScore =
              widget.opponentScore * Curves.easeOutCubic.transform(scoreT);

          final winnerName = _playerWon
              ? widget.player.displayName
              : widget.opponentMember.displayName;
          final loserName = _playerWon
              ? widget.opponentMember.displayName
              : widget.player.displayName;
          final winnerColor = _playerWon
              ? const Color(0xFFCE93D8)
              : const Color(0xFFFFCC80);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Text(
                        'INTELLIGENCE CONTEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 18),
                        _buildIntelligenceBadge(
                          badgeFlow.isEmpty
                              ? 'INTELLIGENCE CHECK'
                              : badgeFlow[badgeIndex],
                          badgeOpacity,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildScorchedContestScorePanel(
                    context: context,
                    leftScoreText:
                        '${widget.player.displayName}: ${countedPlayerScore.toStringAsFixed(2)}',
                    rightScoreText:
                        '${widget.opponentMember.displayName}: ${countedOpponentScore.toStringAsFixed(2)}',
                    leftColor: const Color(0xFFCE93D8),
                    rightColor: const Color(0xFFFFCC80),
                    winnerName: winnerName,
                    loserName: loserName,
                    winnerColor: winnerColor,
                    winnerTextOpacity: winnerTextOpacity,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _canContinue
                        ? () => Navigator.of(context).pop()
                        : null,
                    child: Text(
                      _canContinue ? 'CONTINUE' : 'EVALUATING PATTERNS...',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
