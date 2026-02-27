// lib/screens/battle_screen_flame.dart
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
  }

  void _handleGameEvent(BattleGameEvent event) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (event is CreatureSelectedEvent) {
        setState(() {
          selectedCreatureIndex = event.index;
        });
      } else if (event is AttackExecutedEvent) {
        setState(() {
          _addToFeed(event.result.messages, _FeedSource.team);
        });
      } else if (event is BossAttackExecutedEvent) {
        setState(() {
          _addToFeed(event.result.messages, _FeedSource.boss);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: FC.bg1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: FC.borderAccent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: FC.amberBright,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'VICTORY',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: FC.amberBright,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.bossDisplayName.toUpperCase() + ' DEFEATED',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: FC.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Divider(color: FC.borderDim, height: 1),
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
                    color: FC.bg2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FC.amber, width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      'CLAIM REWARDS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: FC.amberBright,
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: FC.bg1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.withOpacity(0.6), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
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
              const Text(
                'YOUR TEAM WAS WIPED OUT',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: FC.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Regroup and try again with a stronger strategy.',
                style: TextStyle(color: FC.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Divider(color: FC.borderDim, height: 1),
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
                    color: FC.bg2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.5),
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

    final move = BattleMove.getBasicMove(creature.family);
    game.post(() => game.executePlayerAttack(move));
  }

  void _useSpecialMove() {
    if (selectedCreatureIndex == null) return;
    if (game.state != BattleState.playerTurn) return;

    final creature = widget.playerTeam[selectedCreatureIndex!];
    if (creature.isDead) return;

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
                  '${creature.name} special is on cooldown. Use a basic attack to recharge.',
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

    final move = BattleMove.getSpecialMove(creature.family);
    game.post(() => game.executePlayerAttack(move));
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
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.86),
            Colors.black.withOpacity(0.72),
            Colors.transparent,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBossHeaderCard(),
          SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(maxHeight: 112),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: battleFeed.isEmpty
                ? Text(
                    'Battle feed will appear here...',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : ListView.builder(
                    controller: _feedScrollController,
                    itemCount: battleFeed.length,
                    itemBuilder: (context, index) {
                      final e = battleFeed[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFeedTag(e),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.message,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
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
        ],
      ),
    );
  }

  Widget _buildBossHeaderCard() {
    final hpPercent = widget.boss.hpPercent.clamp(0.0, 1.0);
    final isLowHp = hpPercent < 0.25;
    final isMidHp = hpPercent < 0.5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: isLowHp
            ? Colors.red.withOpacity(0.12)
            : Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: isLowHp
            ? Border.all(color: Colors.red.withOpacity(0.7), width: 1.5)
            : isMidHp
            ? Border.all(color: Colors.orange.withOpacity(0.35), width: 1.0)
            : null,
        boxShadow: isLowHp
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.25),
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
                if (widget.boss.needsRecharge)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_bottom_rounded,
                            color: Colors.orange.shade300,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'COOLDOWN',
                            style: TextStyle(
                              color: Colors.orange.shade200,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8),
          _buildBossHealthBar(hpPercent),
          SizedBox(height: 4),
          Center(
            child: Text(
              '${widget.boss.currentHp}/${widget.boss.maxHp}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
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
                  colors: [
                    Colors.white,
                    Colors.red.shade200,
                    Colors.red.shade400,
                  ],
                ).createShader(Rect.fromLTWH(0, 0, 28, 26)),
              shadows: [
                Shadow(color: Colors.red.withOpacity(0.38), blurRadius: 14),
                Shadow(color: Colors.black, blurRadius: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBossHealthBar(double hpPercent) {
    final hpColor = _getHealthColor(hpPercent);

    return Container(
      height: 18,
      padding: EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
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
                      hpColor.withOpacity(0.95),
                      hpColor.withOpacity(0.65),
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
                      Colors.white.withOpacity(0.2),
                      Colors.transparent,
                      Colors.black.withOpacity(0.15),
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
    final Color color;
    final String label;

    if (e.isStatus) {
      color = Colors.amber;
      label = 'STS';
    } else if (e.source == _FeedSource.team) {
      color = Colors.blue.shade300;
      label = 'YOU';
    } else {
      color = Colors.red.shade300;
      label = 'BOSS';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.96),
            Colors.black.withOpacity(0.82),
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
          SizedBox(height: 10),
          _buildMoveButtons(),
        ],
      ),
    );
  }

  Widget _buildTurnBanner() {
    final color = Colors.blue.shade300;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Center(
        child: Text(
          'YOUR TURN',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
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
    final creature = widget.playerTeam[index];
    final isSelected = selectedCreatureIndex == index;
    final isDead = creature.isDead;

    return GestureDetector(
      onTap: isDead
          ? null
          : () {
              game.post(() => game.selectCreature(index));
              setState(() {
                selectedCreatureIndex = index;
              });
            },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDead
              ? Colors.grey.shade900.withOpacity(0.6)
              : isSelected
              ? widget.themeColor.withOpacity(0.35)
              : Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? widget.themeColor
                : isDead
                ? Colors.grey.shade700
                : Colors.white.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              creature.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDead ? Colors.grey.shade500 : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            _buildAnimatedHPBar(
              current: creature.currentHp,
              max: creature.maxHp,
              color: _getHealthColor(creature.hpPercent),
              height: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveButtons() {
    final selected = selectedCreatureIndex == null
        ? null
        : widget.playerTeam[selectedCreatureIndex!];

    final canAct =
        game.state == BattleState.playerTurn &&
        selected != null &&
        !selected.isDead;

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
        : BattleMove.getSpecialMove(selected.family);

    final hasSpecial = selected != null && selected.level >= 5;
    final specialReady = canAct && hasSpecial && !selected.needsRecharge;

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
            activeColor: Colors.blue.shade700,
            isActive: canAct,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            onPressed: specialReady ? _useSpecialMove : null,
            title: specialMove.name,
            subtitle: !canAct
                ? 'Select Creature'
                : hasSpecial
                ? (specialReady ? 'Special Ready' : 'On Cooldown')
                : 'Lv 5 Required',
            activeColor: Colors.purple.shade700,
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
    return SizedBox(
      height: 68,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? activeColor : Colors.grey.shade800,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade900,
          disabledForegroundColor: Colors.white54,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isActive ? 3 : 0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.28),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
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
    final percent = (current / max).clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.black.withOpacity(0.5), width: 1),
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
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            ),
          ),
        ),
      ),
    );
  }

  Color _getHealthColor(double percent) {
    if (percent > 0.6) return Colors.green;
    if (percent > 0.3) return Colors.yellow;
    return Colors.red;
  }
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
