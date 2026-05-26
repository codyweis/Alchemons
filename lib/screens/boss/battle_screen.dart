// lib/screens/battle_screen_flame.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/games/boss/components/boss_attack_graphx_overlay.dart';
import 'package:alchemons/games/boss/battle_game.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
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

class _BattleScreenFlameState extends State<BattleScreenFlame> {
  final FactionTheme _battleFactionTheme = FactionTheme.scorchForge();
  late final FC _fc = FC(_battleFactionTheme);
  late BattleGame game;
  late final BossAttackGraphxOverlayController _bossAttackGraphxController;
  int? selectedCreatureIndex;
  final Map<int, int> _slotShakeNonce = <int, int>{};
  final List<_BattleFeedEntry> battleFeed = [];
  final ScrollController _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bossAttackGraphxController = BossAttackGraphxOverlayController();
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
    final top = size.height * BattleGame.teamRailTopY;
    final bottom = size.height * BattleGame.teamRailBottomY;
    final targetY = top + (bottom - top) * ((slot + 0.5) / totalTargets);
    final targetX = size.width * BattleGame.teamColumnX;
    final origin = Offset(
      size.width * BattleGame.bossArenaX,
      size.height * BattleGame.bossArenaY,
    );
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
                  fontSize: 12,
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
                  fontSize: 12,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned.fill(child: GameWidget(game: game)),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _BossBattleStagePainter(
                              accent: _fc.amber,
                              danger: _fc.danger,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: BossAttackGraphxOverlay(
                          controller: _bossAttackGraphxController,
                        ),
                      ),
                      // Boss HUD — compact card pinned upper-right, anchored
                      // directly above the boss sprite so HP info reads as
                      // attached to the boss rather than floating.
                      Positioned(
                        top: 6,
                        right: 8,
                        width: constraints.maxWidth * 0.42,
                        child: _buildBossHud(),
                      ),
                      // Left party rail — vertical stack of slot cards
                      // sized to align with the Flame sprite Y-positions.
                      // Top/bottom match BattleGame.teamRailTopY/BottomY so
                      // each Expanded slot centers on its Flame sprite.
                      Positioned(
                        top: constraints.maxHeight * BattleGame.teamRailTopY,
                        bottom:
                            constraints.maxHeight *
                            (1 - BattleGame.teamRailBottomY),
                        left: 4,
                        width: constraints.maxWidth * 0.55,
                        child: _buildPartyRail(),
                      ),
                      // Floating recent event feed — fades in over the
                      // arena instead of eating top-of-screen space.
                      Positioned(
                        left: constraints.maxWidth * 0.55,
                        right: 8,
                        bottom: constraints.maxHeight * 0.34,
                        child: IgnorePointer(child: _buildFloatingFeed()),
                      ),
                      // Bottom move card — single compact panel.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildBottomDock(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact boss card pinned to the upper-right. Status icons stack
  /// above the card so they sit just over the Flame boss sprite.
  Widget _buildBossHud() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildBossStatusStack(),
        const SizedBox(height: 4),
        _buildBossHeaderCard(),
      ],
    );
  }

  Widget _buildBossStatusStack() {
    final debuffs = _collectBossDebuffs();
    final fc = _fc;
    final items = <Widget>[];
    if (widget.boss.needsRecharge) {
      items.add(
        _buildBossStatusBubble(
          icon: Icons.hourglass_bottom_rounded,
          label: '${widget.boss.specialCooldown}',
          color: fc.amberBright,
        ),
      );
    }
    if (widget.boss.tauntTargetId != null) {
      items.add(
        _buildBossStatusBubble(
          icon: Icons.gps_fixed_rounded,
          label: 'T',
          color: fc.danger,
        ),
      );
    }
    for (final d in debuffs) {
      items.add(
        _buildBossStatusBubble(
          icon: _iconForDebuffLabel(d.label),
          label: null,
          color: d.color,
        ),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: items,
    );
  }

  Widget _buildBossStatusBubble({
    required IconData icon,
    required String? label,
    required Color color,
  }) {
    final fc = _fc;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fc.bg0.withValues(alpha: 0.78),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.4),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      child: label == null
          ? Icon(icon, color: color, size: 16)
          : Text(
              label,
              style: TextStyle(
                color: fc.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
    );
  }

  IconData _iconForDebuffLabel(String label) {
    switch (label) {
      case 'BURN':
        return Icons.local_fire_department_rounded;
      case 'POISON':
        return Icons.science_rounded;
      case 'FREEZE':
        return Icons.ac_unit_rounded;
      case 'CURSE':
        return Icons.dark_mode_rounded;
      case 'BLEED':
        return Icons.water_drop_rounded;
      case 'VOID':
        return Icons.blur_circular_rounded;
      case 'TAUNT':
        return Icons.gps_fixed_rounded;
      case 'ATK DOWN':
        return Icons.south_rounded;
      case 'DEF DOWN':
        return Icons.shield_outlined;
      case 'SPD DOWN':
        return Icons.speed_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Widget _buildFloatingFeed() {
    final fc = _fc;
    if (battleFeed.isEmpty) return const SizedBox.shrink();
    // Show the last 3 entries fading toward older.
    final recent = battleFeed.length <= 3
        ? battleFeed
        : battleFeed.sublist(battleFeed.length - 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < recent.length; i++)
          Opacity(
            opacity: 0.45 + 0.55 * ((i + 1) / recent.length),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: fc.bg0.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _feedAccentColor(recent[i]).withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  recent[i].message,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fc.textPrimary.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _feedAccentColor(_BattleFeedEntry e) {
    final fc = _fc;
    if (e.isStatus) return fc.amberBright;
    return e.source == _FeedSource.team ? fc.teal : fc.danger;
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
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fc.bg0.withValues(alpha: 0.78),
            fc.bg2.withValues(alpha: 0.6),
            accent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          if (isLowHp)
            BoxShadow(
              color: fc.danger.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildBossElementBadge(widget.boss, accent),
              const SizedBox(width: 7),
              Text(
                'Lv${widget.boss.level}',
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.boss.currentHp}',
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _buildBossHealthBar(hpPercent),
        ],
      ),
    );
  }

  Widget _buildBossElementBadge(BattleCombatant boss, Color accent) {
    final element = boss.types.isNotEmpty ? boss.types.first : 'Normal';
    final color = _elementColor(element, _fc);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.25),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(_iconForElement(element), size: 11, color: color),
    );
  }

  IconData _iconForElement(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return Icons.local_fire_department_rounded;
      case 'Water':
        return Icons.water_drop_rounded;
      case 'Ice':
        return Icons.ac_unit_rounded;
      case 'Air':
        return Icons.air_rounded;
      case 'Earth':
      case 'Mud':
        return Icons.terrain_rounded;
      case 'Plant':
        return Icons.eco_rounded;
      case 'Poison':
        return Icons.science_rounded;
      case 'Lightning':
        return Icons.bolt_rounded;
      case 'Light':
        return Icons.wb_sunny_rounded;
      case 'Dark':
        return Icons.dark_mode_rounded;
      case 'Crystal':
        return Icons.diamond_rounded;
      case 'Spirit':
        return Icons.auto_awesome_rounded;
      case 'Blood':
        return Icons.bloodtype_rounded;
      case 'Steam':
        return Icons.cloud_rounded;
      case 'Dust':
        return Icons.grain_rounded;
      default:
        return Icons.bolt_rounded;
    }
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

  Widget _buildBossHealthBar(double hpPercent) {
    final fc = _fc;
    final hpColor = _getHealthColor(hpPercent);

    return Container(
      height: 14,
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
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
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
  Widget _buildBottomDock() {
    final fc = _fc;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            fc.bg0.withValues(alpha: 0.97),
            fc.bg1.withValues(alpha: 0.82),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: _buildMoveCard(),
    );
  }

  /// Compact move panel: header (move name + selected creature),
  /// damage/cooldown/effects stat row, description, basic+special toggle.
  Widget _buildMoveCard() {
    final fc = _fc;
    final selected = selectedCreatureIndex == null
        ? null
        : widget.playerTeam[selectedCreatureIndex!];

    final canAct =
        game.state == BattleState.playerTurn &&
        selected != null &&
        selected.canAct;
    final isPlayerTurn = game.state == BattleState.playerTurn;

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

    final element = selected?.types.isNotEmpty == true
        ? selected!.types.first
        : 'Normal';
    final accent = _elementColor(element, fc);

    // Highlighted "featured" move — special if it's ready, else basic.
    // The featured slot drives the description shown above the buttons.
    final showSpecial = specialReady;
    final featuredMove = showSpecial ? specialMove : basicMove;
    final featuredSubtitle = showSpecial
        ? 'Special · CD ${BattleMove.specialCooldownForFamily(selected.family)}'
        : 'Basic · ${basicMove.type == MoveType.physical ? 'Physical' : 'Elemental'}';
    final featuredDescription = selected == null
        ? 'Choose an alchemon to view its moves.'
        : showSpecial
        ? BattleMove.specialSummaryForCombatant(selected)
        : 'Quick attack — recovers +${BattleMove.specialRecoveryPerBasicForCombatant(selected)} special per use.';

    final turnLabel = !isPlayerTurn
        ? (game.state == BattleState.animating
              ? 'IMPACT IN PROGRESS'
              : 'BOSS IS MOVING')
        : selected == null
        ? 'CHOOSE A READY ALCHEMON'
        : '${selected.name.toUpperCase()} READY';
    final turnColor = isPlayerTurn ? fc.amberBright : fc.danger;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Featured move title row — mirrors VoidPet "Anxious's Restless Strike".
        Row(
          children: [
            Container(width: 3, height: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected == null
                    ? featuredMove.name.toUpperCase()
                    : '${selected.name.toUpperCase()} · ${featuredMove.name.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Icon(
              isPlayerTurn
                  ? Icons.radio_button_checked_rounded
                  : Icons.warning_amber_rounded,
              color: turnColor,
              size: 13,
            ),
            const SizedBox(width: 5),
            Text(
              turnLabel,
              style: TextStyle(
                color: turnColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Stat row + description.
        Text(
          featuredSubtitle,
          style: TextStyle(
            color: accent.withValues(alpha: 0.95),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          featuredDescription,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fc.textSecondary,
            fontSize: 11,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                onPressed: canAct ? _useBasicMove : null,
                title: basicMove.name,
                subtitle: _basicSubtitle(selected, basicMove, canAct),
                activeColor: accent,
                isActive: canAct,
                icon: basicMove.type == MoveType.physical
                    ? Icons.flash_on_rounded
                    : Icons.auto_awesome_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                onPressed: specialReady ? _useSpecialMove : null,
                title: specialMove.name,
                subtitle: _specialSubtitle(selected, hasSpecial),
                activeColor: accent,
                isActive: specialReady,
                icon: Icons.bolt_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _basicSubtitle(BattleCombatant? selected, BattleMove basic, bool canAct) {
    if (selected == null) return 'Select a creature';
    if (!canAct) return 'Waiting on turn';
    final recovery = BattleMove.specialRecoveryPerBasicForCombatant(selected);
    final type = basic.type == MoveType.physical ? 'Physical' : 'Elemental';
    return '$type · recovers +$recovery';
  }

  String _specialSubtitle(BattleCombatant? selected, bool hasSpecial) {
    if (selected == null) return 'Select a creature';
    if (!selected.canAct) return 'Action CD ${selected.actionCooldown}';
    if (!hasSpecial) return 'Unlocks at Lv 5';
    if (selected.specialCooldown > 0) {
      return 'Recharging · ${selected.specialCooldown} via basics';
    }
    return 'Ready';
  }

  /// Vertical left rail. Equal-flex slots align 1:1 with the Flame
  /// sprite Y-bands so each HP card sits beside its creature.
  Widget _buildPartyRail() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        for (int i = 0; i < widget.playerTeam.length; i++)
          Expanded(child: _buildPartySlot(i)),
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
    final chips = _collectCreatureChips(creature);
    final hasShield = (creature.shieldHp ?? 0) > 0;
    final element = creature.types.isNotEmpty
        ? creature.types.first
        : 'Normal';
    final elementColor = _elementColor(element, fc);
    final specialPct = (creature.specialCooldown == 0)
        ? 1.0
        : 1.0 -
              (creature.specialCooldown /
                      math.max(
                        1,
                        BattleMove.specialCooldownForFamily(creature.family),
                      ))
                  .clamp(0.0, 1.0);

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
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Reserved sprite area — Flame renders the creature here.
              // Sized to roughly match the 88px sprite footprint so the
              // card lands flush against the sprite's right edge.
              const SizedBox(width: 66),
              // Left-pointing nub on the card so it visually attaches to
              // the sprite rather than floating as a separate island.
              CustomPaint(
                size: const Size(8, 18),
                painter: _SlotNubPainter(
                  fill: isSelected
                      ? elementColor.withValues(alpha: 0.22)
                      : fc.bg2.withValues(alpha: 0.86),
                  stroke: isSelected
                      ? elementColor
                      : isOnCooldown
                      ? fc.teal.withValues(alpha: 0.55)
                      : isDead
                      ? fc.borderDim
                      : fc.borderAccent.withValues(alpha: 0.4),
                  strokeWidth: isSelected ? 1.6 : 1,
                ),
              ),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                          ? [
                              elementColor.withValues(alpha: 0.22),
                              fc.bg2.withValues(alpha: 0.92),
                            ]
                          : [
                              fc.bg2.withValues(alpha: isDead ? 0.58 : 0.86),
                              fc.bg0.withValues(alpha: 0.82),
                            ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: isSelected
                            ? elementColor
                            : isOnCooldown
                            ? fc.teal.withValues(alpha: 0.55)
                            : isDead
                            ? fc.borderDim
                            : fc.borderAccent.withValues(alpha: 0.4),
                        width: isSelected ? 1.6 : 1,
                      ),
                      right: BorderSide(
                        color: isSelected
                            ? elementColor
                            : isOnCooldown
                            ? fc.teal.withValues(alpha: 0.55)
                            : isDead
                            ? fc.borderDim
                            : fc.borderAccent.withValues(alpha: 0.4),
                        width: isSelected ? 1.6 : 1,
                      ),
                      bottom: BorderSide(
                        color: isSelected
                            ? elementColor
                            : isOnCooldown
                            ? fc.teal.withValues(alpha: 0.55)
                            : isDead
                            ? fc.borderDim
                            : fc.borderAccent.withValues(alpha: 0.4),
                        width: isSelected ? 1.6 : 1,
                      ),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: elementColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: elementColor.withValues(alpha: 0.25),
                              border: Border.all(
                                color: elementColor.withValues(alpha: 0.8),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _iconForElement(element),
                              size: 8,
                              color: elementColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Lv${creature.level}',
                            style: TextStyle(
                              color: isDead
                                  ? fc.textMuted
                                  : fc.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isDead
                                  ? 'DOWN'
                                  : '${creature.currentHp}/${creature.maxHp}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: isDead
                                    ? fc.danger.withValues(alpha: 0.9)
                                    : fc.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          if (hasShield) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.shield_rounded,
                              size: 11,
                              color: const Color(0xFF8FE0FF),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildAnimatedHPBar(
                        current: creature.currentHp,
                        max: creature.maxHp,
                        color: _getHealthColor(creature.hpPercent),
                        height: 5,
                      ),
                      const SizedBox(height: 2),
                      // Special-recharge bar — mirrors VoidPet's secondary
                      // sub-bar; orange when charging, accent when ready.
                      _buildAnimatedHPBar(
                        current: (specialPct * 100).round(),
                        max: 100,
                        color: creature.specialCooldown == 0
                            ? elementColor
                            : Colors.orange.shade400,
                        height: 3,
                      ),
                      if (chips.isNotEmpty || isOnCooldown) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 3,
                          runSpacing: 3,
                          children: [
                            if (isOnCooldown)
                              _buildSlotChip(
                                'CD ${creature.actionCooldown}',
                                fc.teal,
                              ),
                            for (final c in chips)
                              _buildSlotChip(c.label, c.color),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  List<_BossDebuffChipData> _collectCreatureChips(BattleCombatant creature) {
    final chips = <_BossDebuffChipData>[];
    const statusMap = <String, _BossDebuffChipData>{
      'burn': _BossDebuffChipData('BRN', Colors.deepOrange),
      'poison': _BossDebuffChipData('PSN', Colors.purple),
      'freeze': _BossDebuffChipData('FRZ', Colors.cyan),
      'curse': _BossDebuffChipData('CRS', Colors.deepPurple),
      'bleed': _BossDebuffChipData('BLD', Colors.red),
      'banished': _BossDebuffChipData('VOID', Colors.deepPurpleAccent),
      'taunt': _BossDebuffChipData('TNT', Colors.redAccent),
    };
    const modifierMap = <String, _BossDebuffChipData>{
      'attack_up': _BossDebuffChipData('ATK+', Colors.lightGreenAccent),
      'attack_down': _BossDebuffChipData('ATK-', Colors.redAccent),
      'defense_up': _BossDebuffChipData('DEF+', Colors.lightGreenAccent),
      'defense_down': _BossDebuffChipData('DEF-', Colors.blueAccent),
      'speed_up': _BossDebuffChipData('SPD+', Colors.lightGreenAccent),
      'speed_down': _BossDebuffChipData('SPD-', Colors.amber),
    };
    for (final t in creature.statusEffects.keys) {
      final chip = statusMap[t];
      if (chip != null) chips.add(chip);
    }
    for (final t in creature.statModifiers.keys) {
      final chip = modifierMap[t];
      if (chip != null) chips.add(chip);
    }
    return chips;
  }

  /// Element accent color used for the button border + section accents.
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

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String title,
    required String subtitle,
    required Color activeColor,
    required bool isActive,
    required IconData icon,
  }) {
    final fc = _fc;
    final borderColor = isActive
        ? activeColor.withValues(alpha: 0.85)
        : fc.borderAccent.withValues(alpha: 0.45);
    final titleColor = isActive ? fc.textPrimary : fc.textMuted;
    final subtitleColor = isActive
        ? fc.textSecondary
        : fc.textMuted.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 66,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? [
                      activeColor.withValues(alpha: 0.2),
                      fc.bg2.withValues(alpha: 0.94),
                    ]
                  : [
                      fc.bg2.withValues(alpha: 0.72),
                      fc.bg0.withValues(alpha: 0.9),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.1),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -20,
                child: Icon(
                  icon,
                  size: 82,
                  color: activeColor.withValues(alpha: isActive ? 0.08 : 0.03),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: activeColor.withValues(
                          alpha: isActive ? 0.18 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activeColor.withValues(
                            alpha: isActive ? 0.62 : 0.22,
                          ),
                        ),
                      ),
                      child: Icon(icon, color: activeColor, size: 19),
                    ),
                    const SizedBox(width: 10),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              fontFamily: 'monospace',
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: subtitleColor,
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

class _BossBattleStagePainter extends CustomPainter {
  final Color accent;
  final Color danger;

  const _BossBattleStagePainter({required this.accent, required this.danger});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Arena ring sits under the boss in the upper-right; dashed circle
    // mirrors the VoidPet reference. Centered on the boss sprite at
    // BattleGame.bossArenaX/Y so the boss reads as standing in the ring.
    final bossCenter = Offset(
      size.width * BattleGame.bossArenaX,
      size.height * (BattleGame.bossArenaY + 0.05),
    );
    final radius = math.min(size.width * 0.24, size.height * 0.17);
    final ringRect = Rect.fromCircle(center: bossCenter, radius: radius);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.32)],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    // Soft floor wash under the boss arena.
    final floorPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.18),
          danger.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(ringRect)
      ..style = PaintingStyle.fill;
    canvas.drawOval(ringRect, floorPaint);

    // Dashed outer ring around the boss.
    _drawDashedCircle(
      canvas,
      bossCenter,
      radius,
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
      dashLength: 8,
      gapLength: 6,
    );
    canvas.drawCircle(
      bossCenter,
      radius - 6,
      Paint()
        ..color = accent.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Subtle vertical lane lines anchored beneath the left rail.
    final lanePaint = Paint()
      ..color = accent.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    for (var i = 0; i < 4; i++) {
      final x = size.width * 0.13 + (i - 1.5) * 6;
      canvas.drawLine(
        Offset(x, size.height * 0.08),
        Offset(x, size.height * 0.64),
        lanePaint,
      );
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final dashAngle = (dashLength / circumference) * 2 * math.pi;
    final gapAngle = (gapLength / circumference) * 2 * math.pi;
    double start = -math.pi / 2;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashAngle,
        false,
        paint,
      );
      start += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _BossBattleStagePainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.danger != danger;
  }
}

/// Triangular left-pointing connector painted between the sprite gutter
/// and the rail card body. Tip kisses the sprite, base aligns with the
/// card's left edge so they read as one unit.
class _SlotNubPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  const _SlotNubPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    final strokePath = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height);
    canvas.drawPath(
      strokePath,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SlotNubPainter old) {
    return old.fill != fill ||
        old.stroke != stroke ||
        old.strokeWidth != strokeWidth;
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
