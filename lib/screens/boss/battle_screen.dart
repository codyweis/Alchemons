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
                      // Wide top boss header — name + level + HP bar +
                      // status bubbles. Sits at the very top so the boss
                      // sprite has the arena to itself.
                      Positioned(
                        top: 6,
                        left: 8,
                        right: 8,
                        child: _buildBossHud(),
                      ),
                      // HP overlays floating above each Flame sprite — one
                      // Positioned per slot so the pill anchors directly
                      // to the creature rather than living in a side rail.
                      for (int i = 0; i < widget.playerTeam.length; i++)
                        _buildPartyPillForSlot(constraints, i),
                      // Last action line — single condensed row beneath
                      // the boss header on the left. Tapping opens the
                      // full battle log dialog.
                      Positioned(
                        left: 8,
                        top: constraints.maxHeight * 0.12,
                        width: constraints.maxWidth * 0.62,
                        child: _buildLastActionLine(),
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

  /// Wide top boss header with name, level, HP bar, and a row of status
  /// effect bubbles. Anchored to the top of the screen so the boss
  /// sprite has the arena to itself.
  Widget _buildBossHud() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBossHeaderCard(),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerRight, child: _buildBossStatusStack()),
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
          onTap: () => _showStatusDetail(
            title: 'Special Cooldown',
            body:
                'Boss special recharges in ${widget.boss.specialCooldown} turn(s).',
          ),
        ),
      );
    }
    if (widget.boss.tauntTargetId != null) {
      items.add(
        _buildBossStatusBubble(
          icon: Icons.gps_fixed_rounded,
          label: 'T',
          color: fc.danger,
          onTap: () => _showStatusDetail(
            title: 'Taunt',
            body: 'Boss is taunted — must target the taunting alchemon.',
          ),
        ),
      );
    }
    for (final d in debuffs) {
      items.add(
        _buildBossStatusBubble(
          icon: _iconForDebuffLabel(d.label),
          label: null,
          color: d.color,
          onTap: () => _showStatusDetail(
            title: d.label,
            body: _describeBossDebuff(d.label),
          ),
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
    VoidCallback? onTap,
  }) {
    final fc = _fc;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fc.bg0.withValues(alpha: 0.78),
          border: Border.all(color: color.withValues(alpha: 0.75), width: 1.2),
        ),
        child: label == null
            ? Icon(icon, color: color, size: 14)
            : Text(
                label,
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
      ),
    );
  }

  void _showStatusDetail({required String title, required String body}) {
    final fc = _fc;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: fc.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: fc.borderAccent.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: fc.amberBright,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: fc.amberBright,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
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

  String _describeBossDebuff(String label) {
    switch (label) {
      case 'BURN':
        return 'Boss is burning — takes damage at the start of each turn.';
      case 'POISON':
        return 'Boss is poisoned — takes stacking damage each turn.';
      case 'FREEZE':
        return 'Boss is frozen — actions may be skipped.';
      case 'CURSE':
        return 'Boss is cursed — vulnerable to burst detonations.';
      case 'BLEED':
        return 'Boss is bleeding — damage over time scaled by hits.';
      case 'VOID':
        return 'Boss is banished into the void for a limited duration.';
      case 'TAUNT':
        return 'Boss is taunted — locked onto the taunting alchemon.';
      case 'ATK DOWN':
        return 'Boss attack is reduced.';
      case 'DEF DOWN':
        return 'Boss defense is reduced.';
      case 'SPD DOWN':
        return 'Boss speed is reduced.';
      default:
        return 'Status effect active on the boss.';
    }
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

  Widget _buildLastActionLine() {
    final fc = _fc;
    if (battleFeed.isEmpty) return const SizedBox.shrink();
    final last = battleFeed.last;
    final accent = last.isStatus
        ? fc.amberBright
        : last.source == _FeedSource.team
        ? fc.teal
        : fc.danger;
    return GestureDetector(
      onTap: _showBattleLogDialog,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: fc.bg0.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                last.message,
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fc.textPrimary.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 13, color: fc.textMuted),
          ],
        ),
      ),
    );
  }

  void _showBattleLogDialog() {
    final fc = _fc;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: fc.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: fc.borderAccent.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BATTLE LOG',
                style: TextStyle(
                  color: fc.amberBright,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 360),
                width: double.maxFinite,
                child: battleFeed.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No actions yet.',
                          style: TextStyle(color: fc.textMuted),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: battleFeed.length,
                        reverse: false,
                        itemBuilder: (_, i) {
                          final e = battleFeed[i];
                          final color = e.isStatus
                              ? fc.amberBright
                              : e.source == _FeedSource.team
                              ? fc.teal
                              : fc.danger;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 3,
                                  height: 14,
                                  margin: const EdgeInsets.only(top: 2),
                                  color: color.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.message,
                                    style: TextStyle(
                                      color: fc.textPrimary,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: fc.amberBright,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: fc.bg0.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.bossDisplayName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.boss.currentHp} / ${widget.boss.maxHp}',
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildBossHealthBar(hpPercent),
        ],
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

    // Featured = the move that's primed; drives the diamond-crown
    // decoration on the orb.
    final showSpecial = specialReady;
    final turnLabel = !isPlayerTurn
        ? (game.state == BattleState.animating
              ? 'IMPACT IN PROGRESS'
              : 'BOSS IS MOVING')
        : selected == null
        ? 'CHOOSE A READY ALCHEMON'
        : 'READY';
    final turnColor = isPlayerTurn ? fc.amberBright : fc.danger;

    final basicDescription = selected == null
        ? 'Quick attack that recovers your special charge.'
        : 'Quick attack — recovers +${BattleMove.specialRecoveryPerBasicForCombatant(selected)} special per use.';
    final specialDescription = selected == null
        ? 'Family special — unlocks at level 5.'
        : BattleMove.specialSummaryForCombatant(selected);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(width: 3, height: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected == null ? 'NO SELECTION' : selected.name.toUpperCase(),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMoveOrb(
              onTap: canAct ? _useBasicMove : null,
              onLongPress: () => _showMoveDetail(
                title: basicMove.name,
                subtitle:
                    'Basic · ${basicMove.type == MoveType.physical ? 'Physical' : 'Elemental'}',
                body: basicDescription,
              ),
              label: basicMove.name,
              subtitle: _basicSubtitle(selected, basicMove, canAct),
              elementColor: accent,
              isEnabled: canAct,
              isFeatured: !showSpecial && canAct,
              icon: basicMove.type == MoveType.physical
                  ? Icons.flash_on_rounded
                  : Icons.auto_awesome_rounded,
              family: selected?.family,
              isSpecialMove: false,
            ),
            const SizedBox(width: 36),
            _buildMoveOrb(
              onTap: specialReady ? _useSpecialMove : null,
              onLongPress: () => _showMoveDetail(
                title: specialMove.name,
                subtitle: hasSpecial
                    ? 'Special · CD ${BattleMove.specialCooldownForFamily(selected.family)}'
                    : 'Special · Unlocks at Lv 5',
                body: specialDescription,
              ),
              label: specialMove.name,
              subtitle: _specialSubtitle(selected, hasSpecial),
              elementColor: accent,
              isEnabled: specialReady,
              isFeatured: showSpecial,
              icon: Icons.bolt_rounded,
              family: selected?.family,
              isSpecialMove: true,
            ),
          ],
        ),
      ],
    );
  }

  void _showMoveDetail({
    required String title,
    required String subtitle,
    required String body,
  }) {
    final fc = _fc;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: fc.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: fc.borderAccent.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: fc.amberBright,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: fc.amberBright,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
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

  /// VoidPet-style move orb: round element-tinted button with a
  /// crystalline diamond crown around the featured move. Label sits
  /// underneath so the orb itself stays clean.
  Widget _buildMoveOrb({
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    required String label,
    required String subtitle,
    required Color elementColor,
    required bool isEnabled,
    required bool isFeatured,
    required IconData icon,
    required String? family,
    required bool isSpecialMove,
  }) {
    final fc = _fc;
    final color = isEnabled ? elementColor : fc.textMuted;
    final useFamilyIcon = family == 'Wing';
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (isFeatured)
                  CustomPaint(
                    size: const Size(86, 86),
                    painter: _OrbCrownPainter(color: color),
                  ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isEnabled
                          ? [
                              color.withValues(alpha: 0.85),
                              color.withValues(alpha: 0.35),
                              fc.bg0.withValues(alpha: 0.85),
                            ]
                          : [
                              fc.bg2.withValues(alpha: 0.6),
                              fc.bg0.withValues(alpha: 0.8),
                              fc.bg0,
                            ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                    border: Border.all(
                      color: isEnabled
                          ? color.withValues(alpha: 0.95)
                          : fc.borderDim,
                      width: isFeatured ? 2.0 : 1.2,
                    ),
                  ),
                  child: useFamilyIcon
                      ? CustomPaint(
                          painter: _MoveAttackIconPainter(
                            family: family!,
                            elementColor: color,
                            isEnabled: isEnabled,
                            isSpecial: isSpecialMove,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 28,
                          color: isEnabled
                              ? Colors.white.withValues(alpha: 0.95)
                              : fc.textMuted,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isEnabled ? fc.textPrimary : fc.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isEnabled
                    ? fc.textSecondary.withValues(alpha: 0.85)
                    : fc.textMuted.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _basicSubtitle(
    BattleCombatant? selected,
    BattleMove basic,
    bool canAct,
  ) {
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

  /// HP pill positioned directly above the Flame sprite for each slot.
  /// Coordinates derived from BattleGame.team* constants so the pill
  /// tracks the sprite regardless of screen size.
  Widget _buildPartyPillForSlot(BoxConstraints constraints, int index) {
    final span = BattleGame.teamRailBottomY - BattleGame.teamRailTopY;
    final spriteCenterY =
        constraints.maxHeight *
        (BattleGame.teamRailTopY +
            span * ((index + 0.5) / widget.playerTeam.length));
    final spriteCenterX = constraints.maxWidth * BattleGame.teamColumnX;
    // Compact Pokemon-style nameplate placed directly under each sprite.
    // Centered horizontally on the sprite, no border, minimal chrome.
    const pillWidth = 124.0;
    final left = math.max(2.0, spriteCenterX - pillWidth / 2);

    return Positioned(
      // Sprite visible bottom ≈ centerY + 36 (72px sprite, anchored
      // center). Pill top placed 6px below that.
      top: spriteCenterY + 42,
      left: left,
      width: pillWidth,
      child: _buildHpPill(index),
    );
  }

  Widget _buildHpPill(int index) {
    final fc = _fc;
    final creature = widget.playerTeam[index];
    final isSelected = selectedCreatureIndex == index;
    final isDead = creature.isDead;
    final isOnCooldown = !isDead && !creature.canAct;
    final shakeNonce = _slotShakeNonce[index] ?? 0;
    final element = creature.types.isNotEmpty ? creature.types.first : 'Normal';
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

    final highlightColor = isSelected
        ? elementColor
        : isOnCooldown
        ? fc.teal
        : null;

    return TweenAnimationBuilder<double>(
      key: ValueKey('party_pill_${index}_$shakeNonce'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      builder: (context, value, child) {
        final amplitude = (1 - value) * 8;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Lv${creature.level}',
                  style: TextStyle(
                    color: isDead
                        ? fc.textMuted
                        : (highlightColor ?? fc.textPrimary),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  isDead ? 'DOWN' : '${creature.currentHp}/${creature.maxHp}',
                  style: TextStyle(
                    color: isDead
                        ? fc.danger.withValues(alpha: 0.9)
                        : fc.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            _buildAnimatedHPBar(
              current: creature.currentHp,
              max: creature.maxHp,
              color: _getHealthColor(creature.hpPercent),
              height: 4,
            ),
            const SizedBox(height: 1),
            _buildAnimatedHPBar(
              current: (specialPct * 100).round(),
              max: 100,
              color: creature.specialCooldown == 0
                  ? elementColor
                  : Colors.orange.shade400,
              height: 2,
            ),
          ],
        ),
      ),
    );
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

    // Just a subtle radial vignette — no arena ring. The HUD chrome
    // (boss header, HP pills, move card) carries the visual weight now.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
        stops: const [0.6, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    // Faint floor glow under the boss for depth.
    final bossCenter = Offset(
      size.width * BattleGame.bossArenaX,
      size.height * (BattleGame.bossArenaY + 0.06),
    );
    final glowRect = Rect.fromCircle(
      center: bossCenter,
      radius: math.min(size.width * 0.26, size.height * 0.18),
    );
    final floorPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.12),
          danger.withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(glowRect)
      ..style = PaintingStyle.fill;
    canvas.drawOval(glowRect, floorPaint);
  }

  @override
  bool shouldRepaint(covariant _BossBattleStagePainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.danger != danger;
  }
}

class _MoveAttackIconPainter extends CustomPainter {
  final String family;
  final Color elementColor;
  final bool isEnabled;
  final bool isSpecial;

  const _MoveAttackIconPainter({
    required this.family,
    required this.elementColor,
    required this.isEnabled,
    required this.isSpecial,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bounds = Offset.zero & size;
    final circle = Path()
      ..addOval(
        Rect.fromCircle(
          center: bounds.center,
          radius: math.min(size.width, size.height) / 2,
        ),
      );

    canvas.save();
    canvas.clipPath(circle);
    _drawEnergyBackdrop(canvas, size);

    switch (family) {
      case 'Wing':
        if (isSpecial) {
          _drawWingBeam(canvas, size);
        } else {
          _drawWingFeatherBurst(canvas, size);
        }
        break;
    }

    canvas.restore();
  }

  void _drawEnergyBackdrop(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final hot = Color.lerp(
      elementColor,
      Colors.white,
      isEnabled ? 0.34 : 0.12,
    )!;
    final cool = Color.lerp(elementColor, const Color(0xFF102033), 0.5)!;
    final dark = isEnabled
        ? Color.lerp(elementColor, Colors.black, 0.72)!
        : const Color(0xFF1B1D24);

    final fill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.08,
        colors: [
          hot.withValues(alpha: isEnabled ? 0.95 : 0.32),
          elementColor.withValues(alpha: isEnabled ? 0.82 : 0.22),
          cool.withValues(alpha: isEnabled ? 0.78 : 0.28),
          dark.withValues(alpha: 0.98),
        ],
        stops: const [0.0, 0.36, 0.68, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, fill);

    final haze = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.18
      ..color = hot.withValues(alpha: isEnabled ? 0.22 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawArc(
      Rect.fromCircle(
        center: center.translate(-radius * 0.12, 0),
        radius: radius * 0.72,
      ),
      -math.pi * 0.88,
      math.pi * 1.18,
      false,
      haze,
    );

    final current = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.07
      ..color = hot.withValues(alpha: isEnabled ? 0.38 : 0.12);
    final sweep = Path()
      ..moveTo(size.width * 0.03, size.height * 0.64)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.28,
        size.width * 0.58,
        size.height * 0.84,
        size.width * 0.97,
        size.height * 0.35,
      );
    canvas.drawPath(sweep, current);

    final shadowCurrent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.08
      ..color = Colors.black.withValues(alpha: isEnabled ? 0.2 : 0.28);
    final counter = Path()
      ..moveTo(size.width * 0.14, size.height * 0.24)
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.12,
        size.width * 0.42,
        size.height * 0.64,
        size.width * 0.84,
        size.height * 0.54,
      );
    canvas.drawPath(counter, shadowCurrent);
  }

  void _drawWingFeatherBurst(Canvas canvas, Size size) {
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.11
      ..color = elementColor.withValues(alpha: isEnabled ? 0.45 : 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.075
      ..color = Color.lerp(
        elementColor,
        Colors.white,
        isEnabled ? 0.52 : 0.18,
      )!.withValues(alpha: isEnabled ? 0.96 : 0.46);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.026
      ..color = Colors.white.withValues(alpha: isEnabled ? 0.78 : 0.28);

    final feathers = <Path>[
      Path()
        ..moveTo(size.width * 0.20, size.height * 0.61)
        ..cubicTo(
          size.width * 0.40,
          size.height * 0.28,
          size.width * 0.67,
          size.height * 0.28,
          size.width * 0.84,
          size.height * 0.17,
        ),
      Path()
        ..moveTo(size.width * 0.24, size.height * 0.73)
        ..cubicTo(
          size.width * 0.45,
          size.height * 0.45,
          size.width * 0.64,
          size.height * 0.56,
          size.width * 0.80,
          size.height * 0.39,
        ),
      Path()
        ..moveTo(size.width * 0.27, size.height * 0.84)
        ..cubicTo(
          size.width * 0.46,
          size.height * 0.62,
          size.width * 0.57,
          size.height * 0.73,
          size.width * 0.73,
          size.height * 0.60,
        ),
    ];

    for (final feather in feathers) {
      canvas.drawPath(feather, glow);
      canvas.drawPath(feather, stroke);
      canvas.drawPath(feather, inner);
    }

    final slash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.055
      ..color = Colors.white.withValues(alpha: isEnabled ? 0.9 : 0.3);
    canvas.drawLine(
      Offset(size.width * 0.39, size.height * 0.36),
      Offset(size.width * 0.59, size.height * 0.23),
      slash,
    );
  }

  void _drawWingBeam(Canvas canvas, Size size) {
    final hot = Color.lerp(elementColor, Colors.white, isEnabled ? 0.56 : 0.2)!;
    final beamGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.20
      ..color = elementColor.withValues(alpha: isEnabled ? 0.55 : 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final beam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.125
      ..color = hot.withValues(alpha: isEnabled ? 0.96 : 0.38);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.04
      ..color = Colors.white.withValues(alpha: isEnabled ? 0.94 : 0.34);

    final beamPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.77)
      ..lineTo(size.width * 0.87, size.height * 0.20);
    canvas.drawPath(beamPath, beamGlow);
    canvas.drawPath(beamPath, beam);
    canvas.drawPath(beamPath, core);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.045
      ..color = hot.withValues(alpha: isEnabled ? 0.78 : 0.24);
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.02,
        size.height * 0.16,
        size.width * 0.64,
        size.height * 0.62,
      ),
      -math.pi * 0.08,
      math.pi * 0.72,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.34,
        size.height * 0.22,
        size.width * 0.58,
        size.height * 0.56,
      ),
      math.pi * 0.95,
      math.pi * 0.58,
      false,
      arcPaint,
    );

    final shardFill = Paint()
      ..style = PaintingStyle.fill
      ..color = hot.withValues(alpha: isEnabled ? 0.86 : 0.22);
    for (final spec in const [
      (0.24, 0.28, 0.10),
      (0.70, 0.72, 0.085),
      (0.78, 0.36, 0.07),
    ]) {
      final path = Path()
        ..moveTo(size.width * spec.$1, size.height * (spec.$2 - spec.$3))
        ..lineTo(size.width * (spec.$1 + spec.$3), size.height * spec.$2)
        ..lineTo(size.width * spec.$1, size.height * (spec.$2 + spec.$3))
        ..lineTo(size.width * (spec.$1 - spec.$3), size.height * spec.$2)
        ..close();
      canvas.drawPath(path, shardFill);
    }
  }

  @override
  bool shouldRepaint(covariant _MoveAttackIconPainter old) {
    return old.family != family ||
        old.elementColor != elementColor ||
        old.isEnabled != isEnabled ||
        old.isSpecial != isSpecial;
  }
}

/// Crystalline diamond crown drawn around the featured move orb —
/// 8 small rotated squares evenly spaced around the circumference,
/// echoing the VoidPet "selected move" decoration.
class _OrbCrownPainter extends CustomPainter {
  final Color color;
  const _OrbCrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const count = 8;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi - math.pi / 2;
      final cx = center.dx + math.cos(angle) * radius;
      final cy = center.dy + math.sin(angle) * radius;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(math.pi / 4);
      final r = Rect.fromCenter(center: Offset.zero, width: 6, height: 6);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OrbCrownPainter old) => old.color != color;
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
