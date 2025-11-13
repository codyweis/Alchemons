// lib/screens/battle_screen_flame.dart
import 'package:alchemons/games/boss/battle_game.dart';
import 'package:alchemons/services/boss_battle_engine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flame/game.dart';

/// Main battle screen that integrates Flame game with Flutter UI
class BattleScreenFlame extends StatefulWidget {
  final BattleCombatant boss;
  final List<BattleCombatant> playerTeam;
  final Color themeColor;

  const BattleScreenFlame({
    super.key,
    required this.boss,
    required this.playerTeam,
    this.themeColor = Colors.red,
  });

  @override
  State<BattleScreenFlame> createState() => _BattleScreenFlameState();
}

class _BattleScreenFlameState extends State<BattleScreenFlame> {
  late BattleGame game;
  int? selectedCreatureIndex;
  List<String> playerLog = [];
  List<String> bossLog = [];
  bool showMoveSelection = false;
  final ScrollController _bossScrollController = ScrollController();
  final ScrollController _playerScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
          showMoveSelection = true;
        });
      } else if (event is AttackExecutedEvent) {
        setState(() {
          _addToPlayerLog(event.result.messages);
          showMoveSelection = false;
        });
      } else if (event is BossAttackExecutedEvent) {
        setState(() => _addToBossLog(event.result.messages));
      } else if (event is StatusEffectEvent) {
        setState(() => _addToBossLog(event.messages));
      } else if (event is VictoryEvent) {
        _showVictory();
      } else if (event is DefeatEvent) {
        _showDefeat();
      }
    });
  }

  void _addToPlayerLog(List<String> messages) {
    playerLog.addAll(messages);
    // Auto-scroll to bottom after adding new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_playerScrollController.hasClients) {
        _playerScrollController.animateTo(
          _playerScrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addToBossLog(List<String> messages) {
    bossLog.addAll(messages);
    // Auto-scroll to bottom after adding new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_bossScrollController.hasClients) {
        _bossScrollController.animateTo(
          _bossScrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showVictory() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.green, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            SizedBox(width: 12),
            Text(
              'Victory!',
              style: TextStyle(
                color: Colors.green,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'You defeated ${widget.boss.name}!\n\nYour team gains experience and rewards.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDefeat() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.close, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text(
              'Defeat',
              style: TextStyle(
                color: Colors.red,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Your team was defeated...\n\nRegroup and try again with a stronger strategy.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Retreat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _useBasicMove() {
    if (selectedCreatureIndex == null) return;

    final creature = widget.playerTeam[selectedCreatureIndex!];
    final move = BattleMove.getBasicMove(creature.family);

    game.post(() {
      game.executePlayerAttack(move);
    });
  }

  void _useSpecialMove() {
    if (selectedCreatureIndex == null) return;

    final creature = widget.playerTeam[selectedCreatureIndex!];

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

    final move = BattleMove.getSpecialMove(creature.family);

    game.post(() {
      game.executePlayerAttack(move);
    });
  }

  @override
  void dispose() {
    _bossScrollController.dispose();
    _playerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. The Flame game as the background
            GameWidget(game: game),

            // 2. The Flutter UI overlaid on top
            Column(
              children: [
                // Top: Split battle log
                _buildSplitBattleLog(),

                // Middle: Transparent spacer
                Spacer(),

                // Bottom: Controls
                _buildBottomUI(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitBattleLog() {
    return Container(
      constraints: BoxConstraints(maxHeight: 100),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player log (left side)
          Expanded(
            child: _buildLogSection(
              title: 'YOUR TEAM',
              titleColor: Colors.blue,
              messages: playerLog,
              emptyText: 'Select a creature',
              isScrollable: true,
              scrollController: _playerScrollController,
            ),
          ),

          // Divider
          Container(
            width: 2,
            margin: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Boss log (right side)
          Expanded(
            child: _buildLogSection(
              title: widget.boss.name.toUpperCase(),
              titleColor: Colors.red,
              messages: bossLog,
              emptyText: 'Waiting...',
              isScrollable: true,
              scrollController: _bossScrollController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSection({
    required String title,
    required Color titleColor,
    required List<String> messages,
    required String emptyText,
    bool isScrollable = false,
    ScrollController? scrollController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 4),

        // Messages
        Flexible(
          child: messages.isEmpty
              ? Text(
                  emptyText,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  physics: isScrollable
                      ? AlwaysScrollableScrollPhysics()
                      : NeverScrollableScrollPhysics(),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text(
                        messages[index],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          height: 1.3,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBottomUI() {
    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.95),
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          _buildCreatureSelection(),
          if (showMoveSelection) ...[SizedBox(height: 16), _buildMoveButtons()],
        ],
      ),
    );
  }

  Widget _buildCreatureSelection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final teamCount = widget.playerTeam.length;

    // Define horizontal padding from screen edges
    final edgePadding = 12.0;

    // Calculate available width after padding
    final availableWidth = screenWidth - (edgePadding * 2);

    // Define spacing between cards
    final cardSpacing = 8.0;

    // Calculate card width based on available space
    final totalSpacing = cardSpacing * (teamCount - 1);
    final cardWidth = (availableWidth - totalSpacing) / teamCount;

    return Container(
      width: screenWidth,
      padding: EdgeInsets.symmetric(horizontal: edgePadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < teamCount; i++) ...[
            SizedBox(width: cardWidth, child: _buildCreatureCard(i)),
            if (i < teamCount - 1) SizedBox(width: cardSpacing),
          ],
        ],
      ),
    );
  }

  Widget _buildCreatureCard(int index) {
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
                showMoveSelection = true;
              });
            },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDead
              ? Colors.grey.shade900.withOpacity(0.7)
              : isSelected
              ? widget.themeColor.withOpacity(0.5)
              : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? widget.themeColor
                : isDead
                ? Colors.grey.shade700
                : Colors.grey.shade600.withOpacity(0.5),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: widget.themeColor.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creature.name,
                    style: TextStyle(
                      color: isDead ? Colors.grey.shade500 : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  _buildHPBar(
                    current: creature.currentHp,
                    max: creature.maxHp,
                    color: _getHealthColor(creature.hpPercent),
                    height: 6,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${creature.currentHp}/${creature.maxHp}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveButtons() {
    final creature = widget.playerTeam[selectedCreatureIndex!];
    final basicMove = BattleMove.getBasicMove(creature.family);
    final specialMove = BattleMove.getSpecialMove(creature.family);
    final hasSpecial = creature.level >= 5;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _useBasicMove,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: Column(
              children: [
                Text(
                  basicMove.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    basicMove.type == MoveType.physical
                        ? 'Physical'
                        : 'Elemental',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: hasSpecial ? _useSpecialMove : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSpecial
                  ? Colors.purple.shade700
                  : Colors.grey.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: hasSpecial ? 4 : 0,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasSpecial)
                      Icon(Icons.stars, size: 16)
                    else
                      Icon(Icons.lock, size: 16),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        specialMove.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasSpecial ? 'Special' : 'Lv 5 Required',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHPBar({
    required int current,
    required int max,
    required Color color,
    double height = 8,
  }) {
    final percent = current / max;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.black.withOpacity(0.5), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: FractionallySizedBox(
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
