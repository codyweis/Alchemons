// lib/screens/battle_screen_flame.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/games/boss/components/boss_attack_graphx_overlay.dart';
import 'package:alchemons/games/boss/battle_game.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/battle_section.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';

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
  final FactionTheme _battleFactionTheme = FactionTheme.scorchForge();
  late final FC _fc = FC(_battleFactionTheme);
  late BattleGame game;
  late final AnimationController _bossNameController;
  late final BossAttackGraphxOverlayController _bossAttackGraphxController;
  int? selectedCreatureIndex;
  final Map<int, int> _slotShakeNonce = <int, int>{};
  final List<_BattleFeedEntry> battleFeed = [];
  final ScrollController _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bossAttackGraphxController = BossAttackGraphxOverlayController();
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
      unawaited(context.read<AudioController>().playBossBattleMusic());
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
        if (event.state == BattleState.playerTurn) {
          final idx = selectedCreatureIndex;
          final hasValidSelection =
              idx != null &&
              idx >= 0 &&
              idx < widget.playerTeam.length &&
              widget.playerTeam[idx].canAct;
          if (!hasValidSelection) {
            _selectFirstReadyCreature();
          }
        }
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
            selectedCreatureIndex = null;
          }
        });
        _spawnBossAttackGraphx(event);
        if (selectedCreatureIndex == null) {
          _selectFirstReadyCreature();
        }
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

  void _spawnBossAttackGraphx(BossAttackExecutedEvent event) {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    final totalTargets = math.max(1, widget.playerTeam.length);
    final slot = event.targetIndex.clamp(0, totalTargets - 1);
    final spacing = size.width / (totalTargets + 1);
    final targetX = spacing * (slot + 1);
    final targetY = size.height * 0.76;
    final origin = Offset(size.width * 0.5, size.height * 0.33);
    final target = Offset(targetX, targetY);

    _bossAttackGraphxController.spawn(
      BossAttackGraphxEvent(
        element: widget.boss.types.isNotEmpty
            ? widget.boss.types.first
            : 'Dark',
        origin: origin,
        target: target,
        isCritical: event.result.isCritical,
        damage: event.result.damage,
      ),
    );
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
    final fc = _fc;
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
    final fc = _fc;
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
    if (creature.isDead) {
      _selectFirstReadyCreature();
      return;
    }
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
    if (creature.isDead) {
      _selectFirstReadyCreature();
      return;
    }
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
                  '${creature.name} special on cooldown (${creature.specialCooldown} turn${creature.specialCooldown == 1 ? '' : 's'} left). Use basics to recover.',
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
    final fc = _fc;
    final nextReady = widget.playerTeam.indexWhere((c) => c.canAct);
    if (nextReady >= 0) {
      game.post(() => game.selectCreature(nextReady));
      setState(() {
        selectedCreatureIndex = nextReady;
      });
      if (showHint) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to ${widget.playerTeam[nextReady].name}.',
              style: TextStyle(color: fc.textPrimary),
            ),
            duration: Duration(milliseconds: 900),
            behavior: SnackBarBehavior.floating,
            backgroundColor: fc.bg1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: fc.borderAccent.withValues(alpha: 0.55)),
            ),
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
    _bossAttackGraphxController.dispose();
    _bossNameController.dispose();
    _feedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battleTheme = _battleFactionTheme
        .toMaterialTheme(ThemeData.dark().textTheme)
        .copyWith(
          scaffoldBackgroundColor: Colors.black,
          snackBarTheme: SnackBarThemeData(
            backgroundColor: const Color(0xFF0E1117),
            contentTextStyle: const TextStyle(color: Color(0xFFE8DCC8)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF252D3A)),
            ),
          ),
        );

    return Provider<FactionTheme>.value(
      value: _battleFactionTheme,
      child: Theme(
        data: battleTheme,
        child: ParticleBackgroundScaffold(
          backgroundColor: Colors.black,
          whiteBackground: false,
          body: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  GameWidget(game: game),
                  BossAttackGraphxOverlay(
                    controller: _bossAttackGraphxController,
                  ),
                  Column(
                    children: [_buildTopHud(), Spacer(), _buildBottomDock()],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHud() {
    final fc = _fc;
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
                  ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: fc.textMuted.withValues(alpha: 0.6),
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AWAITING ACTION',
                            style: TextStyle(
                              color: fc.textMuted,
                              fontSize: 10,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _feedScrollController,
                      itemCount: battleFeed.length,
                      itemBuilder: (context, index) {
                        final e = battleFeed[index];
                        return _buildFeedRow(e);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossHeaderCard() {
    final fc = _fc;
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
          _buildBossDebuffsUnderHp(),
        ],
      ),
    );
  }

  Widget _buildBossDebuffsUnderHp() {
    final fc = _fc;
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
    final fc = _fc;
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
    final fc = _fc;
    final hpColor = _getHealthColor(hpPercent);

    return Container(
      height: 22,
      padding: const EdgeInsets.all(2),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fc.bg0.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fc.borderAccent.withValues(alpha: 0.55)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            widthFactor: hpPercent,
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
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
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    fc.textPrimary.withValues(alpha: 0.2),
                    Colors.transparent,
                    fc.bg0.withValues(alpha: 0.2),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          // Inline HP numbers overlaid on the bar — saves vertical space
          // and keeps the value glued to the visual it represents.
          IgnorePointer(
            child: Center(
              child: Text(
                '${widget.boss.currentHp} / ${widget.boss.maxHp}',
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontFamily: 'monospace',
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 0.5),
                      blurRadius: 1.5,
                      color: Color(0xCC000000),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Color-coded left bar replaces the old YOU/BOSS/STS pill — same
  /// information density, faster scan. The eye picks the source color
  /// at the leading edge without parsing a 3-letter abbreviation.
  Widget _buildFeedRow(_BattleFeedEntry e) {
    final fc = _fc;
    final Color color;
    if (e.isStatus) {
      color = fc.amberBright;
    } else if (e.source == _FeedSource.team) {
      color = fc.teal;
    } else {
      color = fc.danger;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      // IntrinsicHeight gives the Row a bounded height so the colored
      // left bar can stretch — without it the bar collapses to 0px and
      // the feed entry has no visible source indicator.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 2.5, color: color.withValues(alpha: 0.85)),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  e.message,
                  style: TextStyle(
                    color: fc.textPrimary.withValues(alpha: 0.95),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    final fc = _fc;
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
          // Party strip is always visible — players need to track their
          // team during boss turns too.
          BattleSection(
            title: 'Party',
            color: fc.amber,
            child: _buildPartyStrip(),
          ),
          // Moves section slides out during boss/animation windows.
          // Visibility IS the turn signal — the old YOUR TURN banner
          // was redundant and just jittered the dock layout each turn.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: game.state == BattleState.playerTurn
                  ? Padding(
                      key: const ValueKey('moves_on'),
                      padding: const EdgeInsets.only(top: 12),
                      child: BattleSection(
                        title: 'Moves',
                        color: fc.amber,
                        child: _buildMoveButtons(),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('moves_off')),
            ),
          ),
        ],
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
    final fc = _fc;
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
    final fc = _fc;
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

    // Element/family identity drives the button's look so each creature
    // reads as its own kit instead of a generic teal/amber pair.
    final element = selected?.types.isNotEmpty == true
        ? selected!.types.first
        : 'Normal';
    final basicColor = _elementColor(element, fc);
    final basicIcon = _elementIcon(element);
    final specialColor = _elementColor(element, fc);
    final specialIcon = selected != null
        ? _familyIcon(selected.family)
        : Icons.auto_awesome_rounded;

    String specialSubtitle;
    if (selected == null) {
      specialSubtitle = 'Select Creature';
    } else if (!selected.canAct) {
      specialSubtitle =
          'CD ${selected.actionCooldown} turn${selected.actionCooldown == 1 ? '' : 's'}';
    } else if (!hasSpecial) {
      specialSubtitle = 'Lv 5 Required';
    } else if (selected.specialCooldown > 0) {
      specialSubtitle = 'CD ${selected.specialCooldown} • via basics';
    } else {
      specialSubtitle = 'Ready';
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
            activeColor: basicColor,
            icon: basicIcon,
            isActive: canAct,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            onPressed: specialReady ? _useSpecialMove : null,
            title: specialMove.name,
            subtitle: specialSubtitle,
            activeColor: specialColor,
            icon: specialIcon,
            isActive: specialReady,
          ),
        ),
      ],
    );
  }

  /// Material icon for each element. Picks symbols the eye already
  /// associates with the element so the button's identity reads at a
  /// glance without parsing the move name.
  IconData _elementIcon(String element) {
    switch (element) {
      case 'Fire':
        return Icons.local_fire_department_rounded;
      case 'Water':
        return Icons.water_drop_rounded;
      case 'Earth':
        return Icons.landscape_rounded;
      case 'Air':
        return Icons.air_rounded;
      case 'Ice':
        return Icons.ac_unit_rounded;
      case 'Lightning':
        return Icons.bolt_rounded;
      case 'Plant':
        return Icons.eco_rounded;
      case 'Poison':
        return Icons.science_rounded;
      case 'Steam':
        return Icons.cloud_rounded;
      case 'Lava':
        return Icons.whatshot_rounded;
      case 'Mud':
        return Icons.terrain_rounded;
      case 'Dust':
        return Icons.blur_on_rounded;
      case 'Crystal':
        return Icons.diamond_rounded;
      case 'Spirit':
        return Icons.blur_circular_rounded;
      case 'Dark':
        return Icons.dark_mode_rounded;
      case 'Light':
        return Icons.light_mode_rounded;
      case 'Blood':
        return Icons.favorite_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  /// Element accent color used for the button border + icon tile.
  Color _elementColor(String element, FC fc) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return const Color(0xFFFF7043);
      case 'Water':
        return const Color(0xFF4FC3F7);
      case 'Earth':
      case 'Mud':
        return const Color(0xFF8D6E63);
      case 'Air':
        return const Color(0xFFB0BEC5);
      case 'Ice':
        return const Color(0xFF8FE0FF);
      case 'Lightning':
        return const Color(0xFFFFEE58);
      case 'Plant':
        return const Color(0xFF8BC34A);
      case 'Poison':
        return const Color(0xFFAB47BC);
      case 'Steam':
        return const Color(0xFFCFD8DC);
      case 'Dust':
        return const Color(0xFFFFCA28);
      case 'Crystal':
        return const Color(0xFF80DEEA);
      case 'Spirit':
        return const Color(0xFF9FA8DA);
      case 'Dark':
        return const Color(0xFF7E57C2);
      case 'Light':
        return const Color(0xFFFFE082);
      case 'Blood':
        return const Color(0xFFE53935);
      default:
        return fc.amber;
    }
  }

  /// Family icon for the special button — Mane casts a vine, Let drops
  /// a meteor, etc. Pairs with the element color so the same family at
  /// different elements still reads differently.
  IconData _familyIcon(String family) {
    switch (family) {
      case 'Let':
        return Icons.flare_rounded;
      case 'Pip':
        return Icons.all_inclusive_rounded;
      case 'Mane':
        return Icons.grass_rounded;
      case 'Mask':
        return Icons.masks_rounded;
      case 'Wing':
        return Icons.flutter_dash_rounded;
      case 'Horn':
        return Icons.security_rounded;
      case 'Kin':
        return Icons.favorite_rounded;
      case 'Mystic':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String title,
    required String subtitle,
    required Color activeColor,
    required IconData icon,
    required bool isActive,
  }) {
    final fc = _fc;
    final tileColor = isActive
        ? activeColor.withValues(alpha: 0.22)
        : fc.bg3.withValues(alpha: 0.6);
    final iconColor = isActive
        ? activeColor
        : fc.textMuted.withValues(alpha: 0.85);
    final borderColor = isActive
        ? activeColor.withValues(alpha: 0.85)
        : fc.borderAccent.withValues(alpha: 0.45);

    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.10)
                  : fc.bg2.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1.1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  // Element/family icon tile — the dominant visual cue.
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            fontFamily: 'monospace',
                            color: isActive ? fc.textPrimary : fc.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: isActive
                                ? fc.textSecondary
                                : fc.textMuted.withValues(alpha: 0.85),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final fc = _fc;
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
