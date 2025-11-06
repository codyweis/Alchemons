import 'package:alchemons/battle/battle_game_core.dart';
import 'package:alchemons/battle/battle_screen.dart';
import 'package:alchemons/battle/battle_stats.dart';
import 'package:alchemons/battle/fusion_system.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/utils/creature_instance_uti.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TeamPrepScreen extends StatefulWidget {
  const TeamPrepScreen({super.key});

  @override
  State<TeamPrepScreen> createState() => _TeamPrepScreenState();
}

class _TeamPrepScreenState extends State<TeamPrepScreen>
    with SingleTickerProviderStateMixin {
  final List<BattleCreature?> selectedTeam = List.filled(
    8,
    null,
  ); // Exactly 8 slots
  late AnimationController _pulseController;

  static const int maxTeamSize = 8;
  static const int rarityBudgetMax = 20;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int rarityPointsOf(String rarity) => switch (rarity) {
    'Legendary' => 4,
    'Rare' => 3,
    'Uncommon' => 2,
    _ => 1,
  };

  int get rarityBudgetUsed => selectedTeam
      .where((c) => c != null)
      .fold(0, (sum, c) => sum + rarityPointsOf(c!.rarity));

  int get filledSlots => selectedTeam.where((c) => c != null).length;

  bool get hasLegendary =>
      selectedTeam.where((c) => c != null).any((c) => c!.rarity == 'Legendary');

  int _baseHpFromInstance(CreatureInstance inst) {
    final tempCreature = BattleCreature(
      instance: inst,
      element: 'Fire',
      rarity: 'Common',
      team: 0,
      hp: 0,
    );
    return BattleStats.calculateMaxHP(tempCreature);
  }

  void _selectInstance(CreatureInstance inst, int slotNumber) {
    final repo = context.read<CreatureCatalog>();
    final species = repo.getCreatureById(inst.baseId);
    if (species == null) return;

    final element = species.types.isNotEmpty ? species.types.first : 'Neutral';
    final rarity = species.rarity;

    // Prevent duplicates
    final alreadyPicked = selectedTeam.any(
      (bc) => bc != null && bc.instance.instanceId == inst.instanceId,
    );
    if (alreadyPicked) {
      _showToast(
        'That creature is already in your team!',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
      );
      return;
    }

    // Rarity budget check
    final currentSlot = selectedTeam[slotNumber];
    final currentPoints = currentSlot != null
        ? rarityPointsOf(currentSlot.rarity)
        : 0;
    final newPoints = rarityPointsOf(rarity);
    final nextBudget = rarityBudgetUsed - currentPoints + newPoints;

    if (nextBudget > rarityBudgetMax) {
      _showToast(
        'Team rarity budget exceeded! ($nextBudget/$rarityBudgetMax points)',
        icon: Icons.block,
        color: Colors.redAccent,
      );
      return;
    }

    // Legendary limit
    if (rarity == 'Legendary' &&
        hasLegendary &&
        currentSlot?.rarity != 'Legendary') {
      _showToast(
        'Only one Legendary allowed per team!',
        icon: Icons.star,
        color: Colors.amber,
      );
      return;
    }

    final baseHp = _baseHpFromInstance(inst);

    final bc = BattleCreature(
      instance: inst,
      element: element,
      rarity: rarity,
      team: 0,
      hp: baseHp,
      onField: false,
      summonable: true,
      bubble: null,
    );

    setState(() {
      selectedTeam[slotNumber] = bc;
    });

    _showToast(
      '${species.name} added to slot ${slotNumber + 1}!',
      icon: Icons.check_circle,
      color: Colors.greenAccent.shade700,
    );
  }

  void _showToast(String message, {IconData icon = Icons.info, Color? color}) {
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
        backgroundColor: color ?? Colors.indigo.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'Legendary':
        return Colors.amber.shade600;
      case 'Rare':
        return Colors.purple.shade400;
      case 'Uncommon':
        return Colors.blue.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  Color _elementColor(String element) {
    switch (element) {
      case 'Fire':
        return Colors.deepOrange;
      case 'Water':
        return Colors.blue;
      case 'Earth':
        return Colors.brown;
      case 'Air':
        return Colors.grey.shade400;
      case 'Ice':
        return Colors.cyan;
      case 'Plant':
        return Colors.green;
      case 'Poison':
        return Colors.purple;
      case 'Lightning':
        return Colors.yellow.shade700;
      case 'Steam':
        return Colors.blueGrey;
      case 'Lava':
        return Colors.deepOrange.shade900;
      case 'Crystal':
        return Colors.lightBlue.shade200;
      case 'Dark':
        return Colors.grey.shade900;
      case 'Light':
        return Colors.yellow.shade100;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final discoveredEntries = context.watchDiscoveredEntries();
    final available = context.watchAvailableSpecies();
    final filteredDiscovered = filterByAvailableInstances(
      discoveredEntries,
      available,
    );

    final canBattle = filledSlots >= 4; // Minimum 4 to start
    final budgetRemaining = rarityBudgetMax - rarityBudgetUsed;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text(
          'Battle Team',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1F3A),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Stats Header
          _buildStatsHeader(budgetRemaining),

          // Team Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: maxTeamSize,
                itemBuilder: (context, index) {
                  return _buildTeamSlot(
                    context,
                    index,
                    filteredDiscovered,
                    theme,
                  );
                },
              ),
            ),
          ),

          // Fusion Analysis
          _buildFusionAnalysis(),

          // Battle Button
          _buildBattleButton(canBattle),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int budgetRemaining) {
    final budgetPercent = rarityBudgetUsed / rarityBudgetMax;
    final budgetColor = budgetPercent > 0.9
        ? Colors.red
        : budgetPercent > 0.7
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1F3A), const Color(0xFF0A0E27)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Team Count
          Expanded(
            child: _buildStatCard(
              icon: Icons.group,
              label: 'TEAM SIZE',
              value: '$filledSlots / $maxTeamSize',
              color: filledSlots >= 8 ? Colors.green : Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          // Rarity Budget
          Expanded(
            child: _buildStatCard(
              icon: Icons.diamond,
              label: 'RARITY POINTS',
              value: '$rarityBudgetUsed / $rarityBudgetMax',
              color: budgetColor,
              progress: budgetPercent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamSlot(
    BuildContext context,
    int index,
    List<CreatureEntry> filteredDiscovered,
    FactionTheme theme,
  ) {
    final creature = selectedTeam[index];
    final isEmpty = creature == null;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = isEmpty ? _pulseController.value * 0.1 : 0.0;

        return GestureDetector(
          onTap: () =>
              _selectCreature(context, index, filteredDiscovered, theme),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isEmpty
                  ? LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.05 + pulse),
                        Colors.white.withOpacity(0.02 + pulse),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        _elementColor(creature.element).withOpacity(0.3),
                        _elementColor(creature.element).withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border.all(
                color: isEmpty
                    ? Colors.white.withOpacity(0.2)
                    : _rarityColor(creature.rarity).withOpacity(0.6),
                width: 2,
              ),
              boxShadow: isEmpty
                  ? null
                  : [
                      BoxShadow(
                        color: _rarityColor(creature.rarity).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
            ),
            child: Stack(
              children: [
                if (isEmpty) _buildEmptySlot(index),
                if (!isEmpty) _buildFilledSlot(creature, index),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySlot(int index) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 32,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'SLOT ${index + 1}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilledSlot(BattleCreature creature, int index) {
    return Stack(
      children: [
        // Content
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Slot number + Remove button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.white.withOpacity(0.8),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => selectedTeam[index] = null),
                  ),
                ],
              ),

              const Spacer(),

              // Creature info
              Text(
                creature.instance.baseId,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Element badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _elementColor(creature.element).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  creature.element.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Rarity + HP
              Row(
                children: [
                  Icon(
                    Icons.diamond,
                    size: 12,
                    color: _rarityColor(creature.rarity),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    creature.rarity,
                    style: TextStyle(
                      color: _rarityColor(creature.rarity),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.favorite, size: 12, color: Colors.red.shade400),
                  const SizedBox(width: 4),
                  Text(
                    '${creature.hp} HP',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Rarity border accent
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              color: _rarityColor(creature.rarity).withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFusionAnalysis() {
    final nonNullTeam = selectedTeam
        .where((c) => c != null)
        .cast<BattleCreature>()
        .toList();
    if (nonNullTeam.isEmpty) return const SizedBox.shrink();

    final possibleFusions = FusionSystem.getPossibleFusions(nonNullTeam);
    final hasFusionPotential = FusionSystem.hasFusionPotential(nonNullTeam);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasFusionPotential
            ? Colors.purple.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFusionPotential
              ? Colors.purple.withOpacity(0.4)
              : Colors.orange.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasFusionPotential
                ? Icons.auto_fix_high
                : Icons.warning_amber_rounded,
            color: hasFusionPotential ? Colors.purple.shade300 : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFusionPotential ? 'FUSION READY' : 'FUSION WARNING',
                  style: TextStyle(
                    color: hasFusionPotential
                        ? Colors.purple.shade300
                        : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasFusionPotential
                      ? 'Possible fusions: ${possibleFusions.join(", ")}'
                      : 'No fusion synergies detected in team',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleButton(bool canBattle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0A0E27), const Color(0xFF1A1F3A)],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canBattle
                ? () {
                    final team = selectedTeam
                        .where((c) => c != null)
                        .cast<BattleCreature>()
                        .toList();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BattleScreen(team: team),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canBattle
                  ? Colors.green.shade600
                  : Colors.grey.shade800,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade800,
              disabledForegroundColor: Colors.grey.shade600,
              elevation: canBattle ? 8 : 0,
              shadowColor: canBattle ? Colors.green.withOpacity(0.5) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(canBattle ? Icons.bolt : Icons.lock, size: 24),
                const SizedBox(width: 12),
                Text(
                  canBattle ? 'START BATTLE' : 'SELECT AT LEAST 4 CREATURES',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectCreature(
    BuildContext rootContext,
    int slotIndex,
    List<CreatureEntry> filteredDiscovered,
    FactionTheme theme,
  ) async {
    // 1) First sheet: pick a species, return its id
    final String? creatureId = await showModalBottomSheet<String>(
      context: rootContext,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (innerSheetContext, scrollController) {
            return CreatureSelectionSheet(
              scrollController: scrollController,
              discoveredCreatures: filteredDiscovered,
              showOnlyAvailableTypes: true,
              onSelectCreature: (id) {
                // CLOSE THIS SHEET with its own context and RETURN a value
                Navigator.pop(innerSheetContext, id);
              },
            );
          },
        );
      },
    );

    if (!mounted || creatureId == null) return;

    // Read providers from a stable context (the State's/root context)
    final repo = rootContext.read<CreatureCatalog>();
    final species = repo.getCreatureById(creatureId);
    if (species == null) return;

    // 2) Second sheet: pick a specific instance, return it
    final CreatureInstance? inst = await showModalBottomSheet<CreatureInstance>(
      context: rootContext,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final factionTheme = rootContext.read<FactionTheme>();
        return BottomSheetShell(
          theme: factionTheme,
          title: '${species.name} Specimens',
          child: InstancesSheet(
            species: species,
            theme: factionTheme,
            selectedInstanceIds: const [],
            onTap: (CreatureInstance selected) {
              // CLOSE THIS SHEET and RETURN the picked instance
              Navigator.pop(sheetContext, selected);
            },
          ),
        );
      },
    );

    if (!mounted || inst == null) return;

    // 3) Apply the selection
    _selectInstance(inst, slotIndex);
  }
}
