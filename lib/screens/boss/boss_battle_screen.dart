// lib/screens/boss_battle_screen.dart
import 'package:alchemons/data/boss_data.dart';
import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/providers/boss_provider.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/screens/boss/battle_screen.dart';
import 'package:alchemons/screens/party_picker.dart';
import 'package:alchemons/services/boss_battle_engine_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';

class BossBattleScreen extends StatefulWidget {
  const BossBattleScreen({super.key});

  @override
  State<BossBattleScreen> createState() => _BossBattleScreenState();
}

class _BossBattleScreenState extends State<BossBattleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final progress = context.watch<BossProgressNotifier>();
    final party = context.watch<SelectedPartyNotifier>();

    if (!progress.isLoaded) {
      return ParticleBackgroundScaffold(
        whiteBackground: theme.brightness == Brightness.light,
        body: Center(child: CircularProgressIndicator(color: theme.primary)),
      );
    }

    final currentBoss = BossRepository.getBossByOrder(
      progress.currentBossOrder,
    );

    if (currentBoss == null) {
      return ParticleBackgroundScaffold(
        whiteBackground: theme.brightness == Brightness.light,
        body: Center(
          child: Text('Boss not found', style: TextStyle(color: theme.text)),
        ),
      );
    }

    return ParticleBackgroundScaffold(
      whiteBackground: theme.brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme, progress),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildProgressBar(theme, progress),
                      const SizedBox(height: 20),
                      _buildBossCard(theme, currentBoss, progress),
                      const SizedBox(height: 20),
                      _buildPartySection(theme, party),
                      const SizedBox(height: 20),
                      _buildActionButtons(theme, currentBoss, party, progress),
                      const SizedBox(height: 20),
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

  Widget _buildHeader(FactionTheme theme, BossProgressNotifier progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.border),
              ),
              child: Icon(Icons.arrow_back, color: theme.text, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BOSS GAUNTLET',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Boss ${progress.currentBossOrder} of 17',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showBossHistory(theme, progress),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.border),
              ),
              child: Icon(Icons.history, color: theme.text, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(FactionTheme theme, BossProgressNotifier progress) {
    final defeated = progress.totalBossesDefeated;
    final progressPercent = defeated / 17;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CAMPAIGN PROGRESS',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '$defeated / 17 Bosses',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(color: theme.border.withOpacity(0.3)),
                  FractionallySizedBox(
                    widthFactor: progressPercent,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade700,
                            Colors.amber.shade400,
                          ],
                        ),
                      ),
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

  Widget _buildBossCard(
    FactionTheme theme,
    Boss boss,
    BossProgressNotifier progress,
  ) {
    final defeatCount = progress.getDefeatCount(boss.id);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _pulseAnimation.value, child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: boss.elementColor.withOpacity(0.7),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: boss.elementColor.withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Boss header with tier badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    boss.elementColor.withOpacity(0.3),
                    boss.elementColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(17),
                  topRight: Radius.circular(17),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: boss.tier.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: boss.tier.color.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      boss.tier.label.toUpperCase(),
                      style: TextStyle(
                        color: boss.tier.color.withOpacity(0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (defeatCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Defeated x$defeatCount',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Boss illustration placeholder
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: boss.elementColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: boss.elementColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  boss.elementIcon,
                  size: 80,
                  color: boss.elementColor.withOpacity(0.8),
                ),
              ),
            ),

            // Boss name and level
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    boss.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: boss.elementColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: boss.elementColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              boss.elementIcon,
                              color: boss.elementColor,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              boss.element,
                              style: TextStyle(
                                color: boss.elementColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          'Lv. ${boss.recommendedLevel}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Boss stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _BossStat(
                      icon: Icons.favorite,
                      label: 'HP',
                      value: boss.hp.toString(),
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BossStat(
                      icon: Icons.flash_on,
                      label: 'ATK',
                      value: boss.atk.toString(),
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BossStat(
                      icon: Icons.shield,
                      label: 'DEF',
                      value: boss.def.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BossStat(
                      icon: Icons.speed,
                      label: 'SPD',
                      value: boss.spd.toString(),
                      color: Colors.cyan,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Moveset
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MOVESET',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...boss.moveset.map(
                    (move) => _BossMoveCard(
                      move: move,
                      theme: theme,
                      elementColor: boss.elementColor,
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

  Widget _buildPartySection(FactionTheme theme, SelectedPartyNotifier party) {
    final db = context.watch<AlchemonsDatabase>();
    final repo = context.watch<CreatureCatalog>();

    return StreamBuilder<List<CreatureInstance>>(
      stream: db.creatureDao.watchAllInstances(),
      builder: (context, snapshot) {
        final allInstances = snapshot.data ?? [];
        final selectedInstances = party.members
            .map(
              (m) => allInstances
                  .where((inst) => inst.instanceId == m.instanceId)
                  .cast<CreatureInstance?>()
                  .firstOrNull,
            )
            .whereType<CreatureInstance>()
            .toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.greenAccent.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: Colors.greenAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'YOUR TEAM',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${selectedInstances.length} / 3',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (selectedInstances.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No team selected',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: List.generate(3, (i) {
                    final inst = i < selectedInstances.length
                        ? selectedInstances[i]
                        : null;
                    final creature = inst != null
                        ? repo.getCreatureById(inst.baseId)
                        : null;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                        child: inst == null || creature == null
                            ? _EmptyPartySlot(theme: theme)
                            : _PartyMemberCard(
                                instance: inst,
                                creature: creature,
                                theme: theme,
                              ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
    FactionTheme theme,
    Boss boss,
    SelectedPartyNotifier party,
    BossProgressNotifier progress,
  ) {
    final hasTeam = party.members.isNotEmpty;

    return Column(
      children: [
        // Select Team Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push<List<PartyMember>>(
                context,
                MaterialPageRoute(builder: (_) => const PartyPickerPage()),
              );
              // Team updated via provider
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.surfaceAlt,
              foregroundColor: theme.text,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.blueAccent.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_add, size: 20),
                const SizedBox(width: 8),
                Text(
                  hasTeam ? 'Change Team' : 'Select Team',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Battle Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasTeam
                ? () => _startBattle(theme, boss, party, progress)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasTeam
                  ? boss.elementColor.withOpacity(0.9)
                  : theme.border,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: hasTeam
                      ? boss.elementColor
                      : theme.border.withOpacity(0.5),
                  width: 2,
                ),
              ),
              elevation: hasTeam ? 8 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cut_sharp,
                  size: 24,
                  color: hasTeam ? Colors.white : theme.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  'ENTER BATTLE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: hasTeam ? Colors.white : theme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _startBattle(
    FactionTheme theme,
    Boss boss,
    SelectedPartyNotifier party,
    BossProgressNotifier progress,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    // Get full instances with stats
    final instances = await db.creatureDao.listAllInstances();
    final selectedInstances = party.members
        .map(
          (m) => instances
              .where((inst) => inst.instanceId == m.instanceId)
              .cast<CreatureInstance?>()
              .firstOrNull,
        )
        .whereType<CreatureInstance>()
        .toList();

    if (selectedInstances.isEmpty) {
      _showToast(
        'No team selected!',
        icon: Icons.warning,
        color: Colors.orange,
      );
      return;
    }

    // Convert to battle combatants
    final playerTeam = selectedInstances
        .map((inst) {
          final creature = repo.getCreatureById(inst.baseId);
          if (creature == null) return null;
          return BattleCombatant.fromInstance(
            instance: inst,
            creature: creature,
          );
        })
        .whereType<BattleCombatant>()
        .toList();

    final bossCombatant = BattleCombatant.fromBoss(boss);

    // Navigate to Flame battle screen
    final victory = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BattleScreenFlame(
          boss: bossCombatant,
          playerTeam: playerTeam,
          themeColor: theme.accent,
        ),
      ),
    );

    if (victory == true && mounted) {
      await progress.defeatBoss(boss.id, boss.order);
      _showToast(
        'Victory! ${boss.name} defeated!',
        icon: Icons.check_circle,
        color: Colors.green,
      );
    }
  }

  void _showToast(
    String message, {
    IconData icon = Icons.info_rounded,
    Color? color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color ?? Colors.indigo.shade400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        dismissDirection: DismissDirection.horizontal,
        showCloseIcon: true,
      ),
    );
  }

  void _showBossHistory(FactionTheme theme, BossProgressNotifier progress) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BossHistorySheet(theme: theme, progress: progress),
    );
  }
}

// ===== SUPPORTING WIDGETS =====

class _BossStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _BossStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BossMoveCard extends StatelessWidget {
  final BossMove move;
  final FactionTheme theme;
  final Color elementColor;

  const _BossMoveCard({
    required this.move,
    required this.theme,
    required this.elementColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: elementColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getMoveTypeColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _getMoveTypeColor().withOpacity(0.5)),
            ),
            child: Icon(
              _getMoveTypeIcon(),
              color: _getMoveTypeColor(),
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  move.name,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  move.description,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getMoveTypeColor() {
    switch (move.type) {
      case BossMoveType.singleTarget:
        return Colors.orange;
      case BossMoveType.aoe:
        return Colors.red;
      case BossMoveType.buff:
        return Colors.green;
      case BossMoveType.debuff:
        return Colors.purple;
      case BossMoveType.heal:
        return Colors.teal;
      case BossMoveType.special:
        return Colors.amber;
    }
  }

  IconData _getMoveTypeIcon() {
    switch (move.type) {
      case BossMoveType.singleTarget:
        return Icons.person;
      case BossMoveType.aoe:
        return Icons.groups;
      case BossMoveType.buff:
        return Icons.arrow_upward;
      case BossMoveType.debuff:
        return Icons.arrow_downward;
      case BossMoveType.heal:
        return Icons.favorite;
      case BossMoveType.special:
        return Icons.auto_awesome;
    }
  }
}

class _EmptyPartySlot extends StatelessWidget {
  final FactionTheme theme;

  const _EmptyPartySlot({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.border.withOpacity(0.5),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.add_circle_outline,
          color: theme.textMuted.withOpacity(0.5),
          size: 28,
        ),
      ),
    );
  }
}

class _PartyMemberCard extends StatelessWidget {
  final CreatureInstance instance;
  final Creature creature;
  final FactionTheme theme;

  const _PartyMemberCard({
    required this.instance,
    required this.creature,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: InstanceSprite(
              creature: creature,
              instance: instance,
              size: 40,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            creature.name,
            style: TextStyle(
              color: theme.text,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Lv. ${instance.level}',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleResultDialog extends StatelessWidget {
  final FactionTheme theme;
  final Boss boss;
  final bool victory;
  final VoidCallback onContinue;

  const _BattleResultDialog({
    required this.theme,
    required this.boss,
    required this.victory,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: victory ? Colors.green : Colors.red,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: (victory ? Colors.green : Colors.red).withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              victory ? Icons.emoji_events : Icons.close,
              color: victory ? Colors.amber : Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              victory ? 'VICTORY!' : 'DEFEATED',
              style: TextStyle(
                color: theme.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              victory
                  ? 'You have defeated ${boss.name}!'
                  : '${boss.name} has defeated you!',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: victory ? Colors.green : Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  victory ? 'CONTINUE' : 'RETRY',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BossHistorySheet extends StatelessWidget {
  final FactionTheme theme;
  final BossProgressNotifier progress;

  const _BossHistorySheet({required this.theme, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.history, color: theme.text, size: 24),
                const SizedBox(width: 12),
                Text(
                  'BOSS HISTORY',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.text),
                ),
              ],
            ),
          ),

          // Boss list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: BossRepository.allBosses.length,
              itemBuilder: (context, index) {
                final boss = BossRepository.allBosses[index];
                final defeated = progress.isBossDefeated(boss.id);
                final defeatCount = progress.getDefeatCount(boss.id);
                final isCurrent = boss.order == progress.currentBossOrder;

                return _BossHistoryCard(
                  theme: theme,
                  boss: boss,
                  defeated: defeated,
                  defeatCount: defeatCount,
                  isCurrent: isCurrent,
                  onTap: () {
                    progress.setCurrentBoss(boss.order);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BossHistoryCard extends StatelessWidget {
  final FactionTheme theme;
  final Boss boss;
  final bool defeated;
  final int defeatCount;
  final bool isCurrent;
  final VoidCallback onTap;

  const _BossHistoryCard({
    required this.theme,
    required this.boss,
    required this.defeated,
    required this.defeatCount,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent
              ? boss.elementColor.withOpacity(0.1)
              : theme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? boss.elementColor.withOpacity(0.5)
                : theme.border,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Boss number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: defeated ? Colors.green.withOpacity(0.2) : theme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: defeated
                      ? Colors.green.withOpacity(0.5)
                      : theme.border,
                ),
              ),
              child: Center(
                child: defeated
                    ? const Icon(Icons.check, color: Colors.green, size: 20)
                    : Text(
                        '${boss.order}',
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Boss info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    boss.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        boss.elementIcon,
                        color: boss.elementColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${boss.element} • Lv. ${boss.recommendedLevel}',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: boss.elementColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: boss.elementColor.withOpacity(0.5)),
                ),
                child: Text(
                  'CURRENT',
                  style: TextStyle(
                    color: boss.elementColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else if (defeated && defeatCount > 0)
              Text(
                'x$defeatCount',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
