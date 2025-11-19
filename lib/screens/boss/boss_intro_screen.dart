// lib/screens/boss_battle_screen.dart
import 'package:alchemons/data/boss_data.dart';
import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/providers/boss_provider.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/screens/boss/battle_screen.dart';
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/services/boss_battle_engine_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
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

// Removed SingleTickerProviderStateMixin as pulsing animation is gone
class _BossBattleScreenState extends State<BossBattleScreen> {
  // Removed AnimationController and Animation

  // Removed initState and dispose methods

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
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border, width: 1)),
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
                border: Border.all(color: theme.border, width: 1),
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
                border: Border.all(color: theme.border, width: 1),
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
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                ],
              ),
              Text(
                '$defeated / 17',
                style: TextStyle(
                  color: Colors.amber.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                border: Border.all(
                  color: theme.border.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progressPercent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade800, Colors.amber.shade600],
                      ),
                    ),
                  ),
                ),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.border.withOpacity(0.4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER ----------------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (defeatCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Defeated x$defeatCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ART ----------------------------------------------------------------------
            Container(
              height: 180, // shorter so screen fits
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    boss.elementColor.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.border, width: 1),
              ),
              child: Center(
                child: Icon(
                  boss.elementIcon,
                  size: 64,
                  color: boss.elementColor,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // NAME + TAGS ----------------------------------------------------------------------
            Column(
              children: [
                Text(
                  boss.name,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Element tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: boss.elementColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(boss.elementIcon, color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            boss.element,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Level
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Lv. ${boss.recommendedLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // STATS (4) ----------------------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: _BossStat(
                    icon: Icons.favorite,
                    label: 'HP',
                    value: boss.hp.toString(),
                    color: Colors.red.shade300,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BossStat(
                    icon: Icons.flash_on,
                    label: 'ATK',
                    value: boss.atk.toString(),
                    color: Colors.orange.shade300,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BossStat(
                    icon: Icons.shield,
                    label: 'DEF',
                    value: boss.def.toString(),
                    color: Colors.blue.shade300,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BossStat(
                    icon: Icons.speed,
                    label: 'SPD',
                    value: boss.spd.toString(),
                    color: Colors.cyan.shade300,
                    theme: theme,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // MOVESET (tight list) ----------------------------------------------------------------------
            Text(
              'MOVESET',
              style: TextStyle(
                color: theme.text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...boss.moveset.map(
                    (move) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _BossMoveCard(
                        move: move,
                        theme: theme,
                        elementColor: boss.elementColor,
                      ),
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
            color: theme.surface,
            borderRadius: BorderRadius.circular(4),
            // Replaced bright green border with subtle theme border
            border: Border.all(color: theme.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: Colors.green.shade600,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      // Darker, less "cheesy" green
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${selectedInstances.length} / 3',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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
                MaterialPageRoute(builder: (_) => const PartyPickerScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.surfaceAlt,
              foregroundColor: theme.text,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                // Use theme.primary instead of hard-coded blue
                side: BorderSide(color: theme.primary, width: 2),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_add, size: 20, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  hasTeam ? 'Change Team' : 'Select Team',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: theme.primary,
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
              backgroundColor: hasTeam ? boss.elementColor : theme.border,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              // Add a "mystical" glow shadow using the boss color
              shadowColor: hasTeam ? boss.elementColor : Colors.transparent,
              elevation: hasTeam ? 8 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.scatter_plot_rounded,
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
    final staminaService = StaminaService(db);

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

    // Refresh stamina for all party members and check if they have enough
    final refreshedInstances = <CreatureInstance>[];
    for (final inst in selectedInstances) {
      final refreshed = await staminaService.refreshAndGet(inst.instanceId);
      if (refreshed == null) {
        _showToast(
          'Error checking stamina',
          icon: Icons.error,
          color: Colors.red,
        );
        return;
      }
      refreshedInstances.add(refreshed);
    }

    // Check if any party member lacks stamina
    final lowStaminaCreatures = refreshedInstances
        .where((inst) => inst.staminaBars < 1)
        .toList();

    if (lowStaminaCreatures.isNotEmpty) {
      final names = lowStaminaCreatures
          .map((inst) {
            final creature = repo.getCreatureById(inst.baseId);
            return creature?.name ?? 'Unknown';
          })
          .take(2)
          .join(', ');

      _showToast(
        lowStaminaCreatures.length == 1
            ? '$names needs rest! (0 stamina)'
            : '${lowStaminaCreatures.length} creatures need rest!',
        icon: Icons.battery_0_bar,
        color: Colors.red,
      );
      return;
    }

    // Deduct 1 stamina bar from each party member
    for (final inst in refreshedInstances) {
      final nowUtc = DateTime.now().toUtc();
      final nowMs = nowUtc.millisecondsSinceEpoch;
      await db.creatureDao.updateStamina(
        instanceId: inst.instanceId,
        staminaBars: inst.staminaBars - 1,
        staminaLastUtcMs: nowMs,
      );
    }

    final playerTeam = refreshedInstances
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
  final FactionTheme theme; // Added theme

  const _BossStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme, // Added theme
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        // Use theme color for a cleaner, strategic look
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        // Use theme border
        border: Border.all(color: theme.border, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              // Use theme text color
              color: theme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              // Use theme text color
              color: theme.text,
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
      // Use 'right' margin for spacing in a Row
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border, width: 1),
      ),
      child: Tooltip(
        message: move.description,
        triggerMode: TooltipTriggerMode.tap,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        child: Row(
          children: [
            // Display the move name directly in the Row
            Text(
              move.name,
              style: TextStyle(
                color: theme.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoveTypeColor() {
    switch (move.type) {
      case BossMoveType.singleTarget:
        return Colors.orange.shade800;
      case BossMoveType.aoe:
        return Colors.red.shade800;
      case BossMoveType.buff:
        return Colors.blue.shade700;
      case BossMoveType.debuff:
        return Colors.purple.shade700;
      case BossMoveType.heal:
        return Colors.green.shade700;
      case BossMoveType.special:
        return Colors.indigo.shade600;
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
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.border,
          // Thinner border
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        // Simpler 'add' icon
        child: Icon(Icons.add, color: theme.textMuted, size: 28),
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
        borderRadius: BorderRadius.circular(10),
        // Thinner border
        border: Border.all(color: theme.border, width: 1),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              // Darker, less "cheesy" amber
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Lv ${instance.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: victory ? Colors.green.shade600 : Colors.red.shade600,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              victory ? Icons.emoji_events : Icons.close,
              color: victory ? Colors.amber.shade600 : Colors.red.shade600,
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
                  backgroundColor: victory
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
        border: Border(
          top: BorderSide(color: theme.border, width: 1),
          left: BorderSide(color: theme.border, width: 1),
          right: BorderSide(color: theme.border, width: 1),
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent ? boss.elementColor : theme.border,
            // Make current border slightly thicker, others thinner
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
                // Use darker green
                color: defeated ? Colors.green.shade700 : theme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: defeated ? Colors.green.shade700 : theme.border,
                  width: 1,
                ),
              ),
              child: Center(
                child: defeated
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
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
                  color: boss.elementColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CURRENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else if (defeated && defeatCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  // Darker green
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'x$defeatCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
