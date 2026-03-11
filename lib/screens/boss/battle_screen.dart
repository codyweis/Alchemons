// lib/screens/battle_screen_flame.dart
import 'dart:math' as math;

import 'package:alchemons/games/boss/battle_game.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';

/// Main battle screen that integrates Flame game with Flutter UI
class BattleScreenFlame extends StatefulWidget {
  final BattleCombatant boss;
  final List<BattleCombatant> playerTeam;
  final Color themeColor;
  final String bossDisplayName;

  const BattleScreenFlame({
    super.key,
    required this.boss,
    required this.playerTeam,
    required this.bossDisplayName,
    this.themeColor = Colors.red,
  });

  @override
  State<BattleScreenFlame> createState() => _BattleScreenFlameState();
}

class _BattleScreenFlameState extends State<BattleScreenFlame>
    with SingleTickerProviderStateMixin {
  late BattleGame game;
  late final AnimationController _bossNameController;
  int? selectedCreatureIndex;
  final Map<int, int> _slotShakeNonce = <int, int>{};
  final List<_BattleFeedEntry> battleFeed = [];
  final ScrollController _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bossNameController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1100),
    )..forward();
    game = BattleGame(
      boss: widget.boss,
      playerTeam: widget.playerTeam,
      onGameEvent: _handleGameEvent,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selectFirstReadyCreature();
    });
  }

  void _handleGameEvent(BattleGameEvent event) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (event is CreatureSelectedEvent) {
        setState(() {
          selectedCreatureIndex = event.index;
        });
      } else if (event is TurnStateChangedEvent) {
        setState(() {});
      } else if (event is AttackExecutedEvent) {
        setState(() {
          _addToFeed(event.result.messages, _FeedSource.team);
        });
      } else if (event is BossAttackExecutedEvent) {
        setState(() {
          _addToFeed(event.result.messages, _FeedSource.boss);

          // If the selected creature was killed, deselect it
          if (selectedCreatureIndex != null &&
              widget.playerTeam[selectedCreatureIndex!].isDead) {
            // Find next alive creature to auto-select
            final nextAlive = widget.playerTeam.indexWhere((c) => c.canAct);
            if (nextAlive >= 0) {
              selectedCreatureIndex = nextAlive;
              game.post(() => game.selectCreature(nextAlive));
            } else {
              selectedCreatureIndex = null;
            }
          }
        });
      } else if (event is StatusEffectEvent) {
        setState(() {
          _addToFeed(
            event.messages,
            event.isBossSource ? _FeedSource.boss : _FeedSource.team,
            isStatus: true,
          );
        });
      } else if (event is VictoryEvent) {
        _showVictory();
      } else if (event is DefeatEvent) {
        _showDefeat();
      }
    });
  }

  void _shakePartySlot(int index) {
    setState(() {
      _slotShakeNonce[index] = (_slotShakeNonce[index] ?? 0) + 1;
    });
  }

  void _addToFeed(
    List<String> messages,
    _FeedSource source, {
    bool isStatus = false,
  }) {
    for (final msg in messages) {
      battleFeed.add(
        _BattleFeedEntry(message: msg, source: source, isStatus: isStatus),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(
          _feedScrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showVictory() {
    final fc = FC.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: fc.bg1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: fc.borderAccent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, color: fc.amberBright, size: 48),
              SizedBox(height: 16),
              Text(
                'VICTORY',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.amberBright,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${widget.bossDisplayName.toUpperCase()} DEFEATED',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.8,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Divider(color: fc.borderDim, height: 1),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pop(ctx, true);
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: fc.bg2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: fc.amber, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'CLAIM REWARDS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: fc.amberBright,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDefeat() {
    final fc = FC.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: fc.bg1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'DEFEATED',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.red,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'YOUR TEAM WAS WIPED OUT',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.8,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Regroup and try again with a stronger strategy.',
                style: TextStyle(color: fc.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Divider(color: fc.borderDim, height: 1),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pop(ctx, false);
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: fc.bg2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'RETREAT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _useBasicMove() {
    if (selectedCreatureIndex == null) return;
    if (game.state != BattleState.playerTurn) return;

    final creature = widget.playerTeam[selectedCreatureIndex!];
    if (creature.isDead) return;
    if (!creature.canAct) {
      _selectFirstReadyCreature(showHint: true);
      return;
    }

    final move = BattleMove.getBasicMove(creature.family);
    game.post(() => game.executePlayerAttack(move));
  }

  void _useSpecialMove() {
    if (selectedCreatureIndex == null) return;
    if (game.state != BattleState.playerTurn) return;

    final creature = widget.playerTeam[selectedCreatureIndex!];
    if (creature.isDead) return;
    if (!creature.canAct) {
      _selectFirstReadyCreature(showHint: true);
      return;
    }

    if (creature.level < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${creature.name} hasn\'t learned a special ability yet! (Requires Lv 5)',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey.shade900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (creature.needsRecharge) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${creature.name} special on cooldown (${creature.specialCooldown} turn${creature.specialCooldown == 1 ? '' : 's'} left)',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey.shade900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final move = BattleMove.getSpecialMoveForCombatant(creature);
    game.post(() => game.executePlayerAttack(move));
  }

  void _selectFirstReadyCreature({bool showHint = false}) {
    final nextReady = widget.playerTeam.indexWhere((c) => c.canAct);
    if (nextReady >= 0) {
      game.post(() => game.selectCreature(nextReady));
      setState(() {
        selectedCreatureIndex = nextReady;
      });
      if (showHint) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${widget.playerTeam[nextReady].name}.'),
            duration: Duration(milliseconds: 900),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final alive = widget.playerTeam.indexWhere((c) => c.isAlive);
    if (alive >= 0) {
      // Hard recovery: clear action cooldowns so the turn can proceed.
      for (final c in widget.playerTeam) {
        if (c.isAlive) c.actionCooldown = 0;
      }
      game.post(() => game.selectCreature(alive));
      setState(() {
        selectedCreatureIndex = alive;
      });
    }
  }

  @override
  void dispose() {
    _bossNameController.dispose();
    _feedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ParticleBackgroundScaffold(
      whiteBackground: false,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              GameWidget(game: game),
              Column(children: [_buildTopHud(), Spacer(), _buildBottomDock()]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHud() {
    final fc = FC.of(context);
    return Container(
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildBossHeaderCard(),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 112),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: fc.borderAccent.withValues(alpha: 0.45),
                ),
              ),
              child: battleFeed.isEmpty
                  ? Text(
                      'Battle feed will appear here...',
                      style: TextStyle(
                        color: fc.textMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'monospace',
                      ),
                    )
                  : ListView.builder(
                      controller: _feedScrollController,
                      itemCount: battleFeed.length,
                      itemBuilder: (context, index) {
                        final e = battleFeed[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFeedTag(e),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.message,
                                  style: TextStyle(
                                    color: fc.textPrimary.withValues(
                                      alpha: 0.95,
                                    ),
                                    fontSize: 11,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossHeaderCard() {
    final fc = FC.of(context);
    final hpPercent = widget.boss.hpPercent.clamp(0.0, 1.0);
    final isLowHp = hpPercent < 0.25;
    final isMidHp = hpPercent < 0.5;
    final accent = isLowHp
        ? fc.danger
        : isMidHp
        ? fc.amberBright
        : fc.borderAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.2),
        boxShadow: isLowHp
            ? [
                BoxShadow(
                  color: fc.danger.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildAnimatedBossTitle(),
                if (widget.boss.needsRecharge ||
                    widget.boss.tauntTargetId != null)
                  Positioned(
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.boss.tauntTargetId != null)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: fc.danger.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: fc.danger.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.gps_fixed_rounded,
                                  color: fc.danger.withValues(alpha: 0.9),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'TAUNTED',
                                  style: TextStyle(
                                    color: fc.textPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.boss.needsRecharge)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: fc.amber.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: fc.amberBright.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.hourglass_bottom_rounded,
                                  color: fc.amberBright,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'CD:${widget.boss.specialCooldown}',
                                  style: TextStyle(
                                    color: fc.textPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          _buildBossHealthBar(hpPercent),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${widget.boss.currentHp}/${widget.boss.maxHp}',
              style: TextStyle(
                color: fc.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          _buildBossDebuffsUnderHp(),
        ],
      ),
    );
  }

  Widget _buildBossDebuffsUnderHp() {
    final fc = FC.of(context);
    final debuffs = _collectBossDebuffs();
    if (debuffs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 4,
        children: debuffs
            .map(
              (d) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: d.color.withValues(alpha: 0.55)),
                ),
                child: Text(
                  d.label,
                  style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  List<_BossDebuffChipData> _collectBossDebuffs() {
    final chips = <_BossDebuffChipData>[];

    final statusMap = <String, _BossDebuffChipData>{
      'burn': _BossDebuffChipData('BURN', Colors.deepOrange),
      'poison': _BossDebuffChipData('POISON', Colors.purple),
      'freeze': _BossDebuffChipData('FREEZE', Colors.cyan),
      'curse': _BossDebuffChipData('CURSE', Colors.deepPurple),
      'bleed': _BossDebuffChipData('BLEED', Colors.red),
      'banished': _BossDebuffChipData('VOID', Colors.deepPurpleAccent),
      'taunt': _BossDebuffChipData('TAUNT', Colors.redAccent),
    };
    final modifierMap = <String, _BossDebuffChipData>{
      'attack_down': _BossDebuffChipData('ATK DOWN', Colors.redAccent),
      'defense_down': _BossDebuffChipData('DEF DOWN', Colors.blueAccent),
      'speed_down': _BossDebuffChipData('SPD DOWN', Colors.amber),
    };

    for (final effectType in widget.boss.statusEffects.keys) {
      final chip = statusMap[effectType];
      if (chip != null) {
        chips.add(chip);
      }
    }
    for (final modType in widget.boss.statModifiers.keys) {
      final chip = modifierMap[modType];
      if (chip != null) {
        chips.add(chip);
      }
    }

    return chips;
  }

  Widget _buildAnimatedBossTitle() {
    final letters = widget.bossDisplayName.split('');
    final total = letters.isEmpty ? 1 : letters.length;

    return AnimatedBuilder(
      animation: _bossNameController,
      builder: (context, _) {
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < letters.length; i++)
                  _buildAnimatedTitleLetter(letters[i], i, total),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTitleLetter(String letter, int index, int total) {
    final fc = FC.of(context);
    final start = (index / total) * 0.7;
    final end = (start + 0.3).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: _bossNameController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    final value = curve.value;

    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * -8),
        child: Padding(
          padding: EdgeInsets.only(right: letter == ' ' ? 8 : 0.5),
          child: Text(
            letter,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [fc.textPrimary, fc.amberBright, fc.amber],
                ).createShader(Rect.fromLTWH(0, 0, 28, 26)),
              shadows: [
                Shadow(color: fc.amber.withValues(alpha: 0.42), blurRadius: 14),
                Shadow(color: Colors.black, blurRadius: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBossHealthBar(double hpPercent) {
    final fc = FC.of(context);
    final hpColor = _getHealthColor(hpPercent);

    return Container(
      height: 18,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: fc.bg0.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fc.borderAccent.withValues(alpha: 0.55)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: AnimatedFractionallySizedBox(
              duration: Duration(milliseconds: 240),
              curve: Curves.easeOut,
              widthFactor: hpPercent,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      hpColor.withValues(alpha: 0.95),
                      hpColor.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.transparent,
                      fc.bg0.withValues(alpha: 0.2),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTag(_BattleFeedEntry e) {
    final fc = FC.of(context);
    final Color color;
    final String label;

    if (e.isStatus) {
      color = fc.amberBright;
      label = 'STS';
    } else if (e.source == _FeedSource.team) {
      color = fc.teal;
      label = 'YOU';
    } else {
      color = fc.danger;
      label = 'BOSS';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    final fc = FC.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            fc.bg0.withValues(alpha: 0.98),
            fc.bg1.withValues(alpha: 0.86),
            Colors.transparent,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: game.state == BattleState.playerTurn
                ? Column(
                    key: const ValueKey('turn_on'),
                    children: [_buildTurnBanner(), const SizedBox(height: 10)],
                  )
                : const SizedBox.shrink(key: ValueKey('turn_off')),
          ),
          _buildPartyStrip(),
          const SizedBox(height: 10),
          _buildMoveButtons(),
        ],
      ),
    );
  }

  Widget _buildTurnBanner() {
    final fc = FC.of(context);
    final color = fc.amberBright;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: fc.bg2.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Center(
        child: Text(
          'YOUR TURN',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildPartyStrip() {
    return Row(
      children: [
        for (int i = 0; i < widget.playerTeam.length; i++) ...[
          Expanded(child: _buildPartySlot(i)),
          if (i < widget.playerTeam.length - 1) SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildPartySlot(int index) {
    final fc = FC.of(context);
    final creature = widget.playerTeam[index];
    final isSelected = selectedCreatureIndex == index;
    final isDead = creature.isDead;
    final isOnCooldown = !isDead && !creature.canAct;
    final shakeNonce = _slotShakeNonce[index] ?? 0;

    return TweenAnimationBuilder<double>(
      key: ValueKey('party_slot_${index}_$shakeNonce'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      builder: (context, value, child) {
        final amplitude = (1 - value) * 9;
        final dx = math.sin(value * math.pi * 6) * amplitude;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: GestureDetector(
        onTap: () {
          if (isDead || isOnCooldown) {
            _shakePartySlot(index);
            return;
          }
          game.post(() => game.selectCreature(index));
          setState(() {
            selectedCreatureIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDead
                ? fc.bg0.withValues(alpha: 0.75)
                : isOnCooldown
                ? fc.bg3.withValues(alpha: 0.8)
                : isSelected
                ? fc.amber.withValues(alpha: 0.24)
                : fc.bg2.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? fc.amberBright
                  : isOnCooldown
                  ? fc.teal.withValues(alpha: 0.55)
                  : isDead
                  ? fc.borderDim
                  : fc.borderAccent.withValues(alpha: 0.4),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      creature.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDead
                            ? fc.textMuted
                            : isOnCooldown
                            ? fc.teal.withValues(alpha: 0.8)
                            : fc.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (isOnCooldown)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: fc.teal.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: fc.teal.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_bottom_rounded,
                            color: fc.teal,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${creature.actionCooldown}',
                            style: TextStyle(
                              color: fc.teal.withValues(alpha: 0.95),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _buildAnimatedHPBar(
                current: creature.currentHp,
                max: creature.maxHp,
                color: _getHealthColor(creature.hpPercent),
                height: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoveButtons() {
    final fc = FC.of(context);
    final selected = selectedCreatureIndex == null
        ? null
        : widget.playerTeam[selectedCreatureIndex!];

    final canAct =
        game.state == BattleState.playerTurn &&
        selected != null &&
        selected.canAct;

    final basicMove = selected == null
        ? const BattleMove(
            name: 'Basic Attack',
            type: MoveType.physical,
            scalingStat: 'statStrength',
          )
        : BattleMove.getBasicMove(selected.family);

    final specialMove = selected == null
        ? const BattleMove(
            name: 'Special',
            type: MoveType.elemental,
            scalingStat: 'statIntelligence',
          )
        : BattleMove.getSpecialMoveForCombatant(selected);

    final hasSpecial = selected != null && selected.level >= 5;
    final specialReady = canAct && hasSpecial && !selected.needsRecharge;

    // Build subtitle for special button
    String specialSubtitle;
    if (selected == null) {
      specialSubtitle = 'Select Creature';
    } else if (!selected.canAct) {
      specialSubtitle =
          'Action Cooldown: ${selected.actionCooldown} turn${selected.actionCooldown == 1 ? '' : 's'}';
    } else if (!hasSpecial) {
      specialSubtitle = 'Lv 5 Required';
    } else if (selected.specialCooldown > 0) {
      specialSubtitle = 'Cooldown: ${selected.specialCooldown} turns';
    } else {
      specialSubtitle = 'Special Ready';
    }

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            onPressed: canAct ? _useBasicMove : null,
            title: basicMove.name,
            subtitle: canAct
                ? (basicMove.type == MoveType.physical
                      ? 'Physical'
                      : 'Elemental')
                : 'Select Creature',
            activeColor: fc.teal,
            isActive: canAct,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            onPressed: specialReady ? _useSpecialMove : null,
            title: specialMove.name,
            subtitle: specialSubtitle,
            activeColor: fc.amber,
            isActive: specialReady,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String title,
    required String subtitle,
    required Color activeColor,
    required bool isActive,
  }) {
    final fc = FC.of(context);
    return SizedBox(
      height: 68,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? activeColor.withValues(alpha: 0.88)
              : fc.bg3.withValues(alpha: 0.92),
          foregroundColor: fc.textPrimary,
          disabledBackgroundColor: fc.bg3.withValues(alpha: 0.92),
          disabledForegroundColor: fc.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isActive
                  ? activeColor.withValues(alpha: 0.95)
                  : fc.borderAccent.withValues(alpha: 0.5),
            ),
          ),
          elevation: isActive ? 1.5 : 0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: fc.bg0.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: fc.borderAccent.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? fc.textPrimary
                      : fc.textSecondary.withValues(alpha: 0.9),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedHPBar({
    required int current,
    required int max,
    required Color color,
    double height = 8,
  }) {
    final fc = FC.of(context);
    final percent = (current / max).clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: fc.bg0.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: fc.borderDim, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: AnimatedFractionallySizedBox(
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          widthFactor: percent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getHealthColor(double percent) {
    if (percent > 0.6) return Colors.green.shade500;
    if (percent > 0.3) return Colors.orange.shade400;
    return Colors.red.shade500;
  }
}

class _BossDebuffChipData {
  final String label;
  final Color color;

  const _BossDebuffChipData(this.label, this.color);
}

enum _FeedSource { team, boss }

class _BattleFeedEntry {
  final String message;
  final _FeedSource source;
  final bool isStatus;

  const _BattleFeedEntry({
    required this.message,
    required this.source,
    this.isStatus = false,
  });
}
