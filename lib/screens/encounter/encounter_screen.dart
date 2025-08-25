import 'dart:convert';
import 'dart:math';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/genetics.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum EncounterResult { ran, bred, completed }

class EncounterPage extends StatefulWidget {
  final String speciesId;
  final Creature? hydrated;
  final List<PartyMember> party;
  const EncounterPage({
    super.key,
    required this.speciesId,
    required this.party,
    this.hydrated,
  });

  @override
  State<EncounterPage> createState() => _EncounterPageState();
}

class _EncounterPageState extends State<EncounterPage>
    with TickerProviderStateMixin {
  PartyMember? _selected;
  bool _isBreeding = false;
  late AnimationController _pulseController;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureRepository>();
    final base = repo.getCreatureById(widget.speciesId);
    final visual = widget.hydrated ?? base;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, EncounterResult.ran);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF0FF),
        body: SafeArea(
          child: Column(
            children: [
              // Wild creature encounter header - reduced height
              _buildWildEncounterHeader(visual),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Encounter info panel - reduced padding
                      _buildEncounterInfo(visual),

                      // Breeding compatibility section
                      if (_selected != null)
                        _buildCompatibilityInfo(visual, _selected!),

                      // Party selection header - condensed
                      _buildPartySection(),
                    ],
                  ),
                ),
              ),

              // Fixed bottom section with actions and party grid
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action buttons - reduced padding
          _buildActionButtons(context),

          // Party grid with proper constraints
          SizedBox(
            height: 200, // Reduced from 300
            child: _PartyGrid(
              party: widget.party,
              selected: _selected,
              onPick: (p) => setState(() => _selected = p),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWildEncounterHeader(Creature? visual) {
    return Container(
      height: 160, // Reduced from 200
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[50]!, Colors.indigo[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.indigo[200]!, width: 2),
        ),
      ),
      child: Stack(
        children: [
          // Back button
          Positioned(
            top: 12, // Reduced from 16
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context, EncounterResult.ran),
              child: Container(
                padding: const EdgeInsets.all(6), // Reduced from 8
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo[300]!),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.indigo[700],
                  size: 18, // Reduced from 20
                ),
              ),
            ),
          ),

          // Wild creature display - repositioned
          Positioned(
            top: 40, // Reduced from 60
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Field Research Encounter',
                  style: TextStyle(
                    color: Colors.indigo[700],
                    fontSize: 12, // Reduced from 14
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6), // Reduced from 8
                _WildPreviewBox(creature: visual),
                const SizedBox(height: 8), // Reduced from 12
                Text(
                  visual?.name ?? 'Unknown Species',
                  style: TextStyle(
                    color: Colors.indigo[800],
                    fontSize: 20, // Reduced from 24
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (visual?.types.isNotEmpty == true) ...[
                  const SizedBox(height: 2), // Reduced from 4
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: visual!.types
                        .map(
                          (type) => Container(
                            margin: const EdgeInsets.only(
                              right: 6,
                            ), // Reduced from 8
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, // Reduced from 12
                              vertical: 2, // Reduced from 4
                            ),
                            decoration: BoxDecoration(
                              color: _getTypeColor(type),
                              borderRadius: BorderRadius.circular(
                                10,
                              ), // Reduced from 12
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10, // Reduced from 12
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncounterInfo(Creature? visual) {
    return Container(
      margin: const EdgeInsets.all(12), // Reduced from 16
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo[100]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                color: Colors.indigo[600],
                size: 18,
              ), // Reduced from 20
              const SizedBox(width: 6), // Reduced from 8
              Text(
                'Research Breeding Opportunity',
                style: TextStyle(
                  color: Colors.indigo[700],
                  fontSize: 14, // Reduced from 16
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Reduced from 12
          Text(
            'Subject ${visual?.name ?? 'specimen'} is displaying breeding readiness indicators. Cross-breeding with your research team may yield valuable genetic data and offspring specimens for further study.',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13, // Reduced from 14
              height: 1.3, // Reduced from 1.4
            ),
          ),
          const SizedBox(height: 8), // Reduced from 12
          Row(
            children: [
              _InfoChip(
                icon: Icons.star_border_outlined,
                label: 'Rarity: ${visual?.rarity ?? 'Unknown'}',
                color: _getRarityColor(visual?.rarity),
              ),
              const SizedBox(width: 8), // Reduced from 12
              _InfoChip(
                icon: Icons.nature_outlined,
                label: 'Wild Specimen',
                color: Colors.green[600]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityInfo(Creature? wild, PartyMember partner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12), // Reduced from 16
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.green[100]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.biotech_outlined,
                color: Colors.green[700],
                size: 18,
              ), // Reduced from 20
              const SizedBox(width: 6), // Reduced from 8
              Text(
                'Genetic Compatibility Analysis',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 14, // Reduced from 16
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Reduced from 12
          FutureBuilder<db.CreatureInstance?>(
            future: context.read<AlchemonsDatabase>().getInstance(
              partner.instanceId,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final instance = snapshot.data!;
              final repo = context.read<CreatureRepository>();
              final partnerCreature = repo.getCreatureById(instance.baseId);

              return Row(
                children: [
                  Expanded(
                    child: _CompatibilityCard(
                      title: 'Field Subject',
                      creature: wild,
                      subtitle: 'Wild specimen',
                    ),
                  ),
                  const SizedBox(width: 12), // Reduced from 16
                  Container(
                    padding: const EdgeInsets.all(6), // Reduced from 8
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Icon(
                      Icons.science,
                      color: Colors.green[700],
                      size: 14, // Reduced from 16
                    ),
                  ),
                  const SizedBox(width: 12), // Reduced from 16
                  Expanded(
                    child: _CompatibilityCard(
                      title: 'Research Partner',
                      creature: partnerCreature,
                      subtitle: 'Lab specimen',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12), // Reduced from 16
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: (_selected != null && !_isBreeding)
                    ? () => _handleBreed(context, _selected!)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selected != null
                      ? Colors.indigo[600]
                      : Colors.grey[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ), // Reduced from 16
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _selected != null ? 4 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isBreeding) ...[
                      const SizedBox(
                        width: 14, // Reduced from 16
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6), // Reduced from 8
                    ] else ...[
                      const Icon(
                        Icons.science_outlined,
                        size: 18,
                      ), // Reduced from 20
                      const SizedBox(width: 6), // Reduced from 8
                    ],
                    Text(
                      _isBreeding
                          ? 'Conducting Research...'
                          : 'Initiate Breeding Study',
                      style: const TextStyle(
                        fontSize: 14, // Reduced from 16
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8), // Reduced from 12
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, EncounterResult.ran),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[600],
                side: BorderSide(color: Colors.grey[400]!, width: 2),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ), // Reduced from 16
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.close_outlined, size: 18), // Reduced from 20
                  SizedBox(width: 4), // Reduced from 8
                  Text(
                    'Abort',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ), // Reduced from 16
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12), // Reduced from 16
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.groups_outlined,
            color: Colors.blue[600],
            size: 18,
          ), // Reduced from 20
          const SizedBox(width: 6), // Reduced from 8
          Text(
            'Research Team Selection',
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 14, // Reduced from 16
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_selected != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ), // Reduced padding
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Text(
                'Partner Selected',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 11, // Reduced from 12
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Colors.red[600]!;
      case 'water':
        return Colors.blue[600]!;
      case 'grass':
        return Colors.green[600]!;
      case 'electric':
        return Colors.yellow[600]!;
      case 'psychic':
        return Colors.purple[600]!;
      case 'ice':
        return Colors.cyan[600]!;
      case 'dragon':
        return Colors.indigo[600]!;
      case 'dark':
        return Colors.grey[800]!;
      case 'fairy':
        return Colors.pink[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Color _getRarityColor(String? rarity) {
    switch (rarity?.toLowerCase()) {
      case 'common':
        return Colors.grey[600]!;
      case 'uncommon':
        return Colors.green[600]!;
      case 'rare':
        return Colors.blue[600]!;
      case 'epic':
        return Colors.purple[600]!;
      case 'legendary':
        return Colors.orange[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // Rest of the methods remain the same...
  Future<void> _handleBreed(BuildContext context, PartyMember partner) async {
    setState(() => _isBreeding = true);

    final factions = context.read<FactionService>();
    final firePerk2 = await factions.perk2Active();

    final dbApi = context.read<db.AlchemonsDatabase>();
    final engine = context.read<BreedingEngine>();
    final repo = context.read<CreatureRepository>();
    final stamina = context.read<StaminaService>();

    bool spinnerOpen = false;
    Future<void> openSpinner() async {
      spinnerOpen = true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    void closeSpinnerIfOpen() {
      if (spinnerOpen) {
        spinnerOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    try {
      final inst = await dbApi.getInstance(partner.instanceId);
      if (inst == null) {
        _snack('Could not load partner.');
        return;
      }

      final can = await stamina.canBreed(inst.instanceId);
      if (!can) {
        _snack('This partner is resting.');
        return;
      }

      final wild = widget.hydrated ?? repo.getCreatureById(widget.speciesId);
      if (wild == null) {
        _snack('Wild specimen unavailable.');
        return;
      }

      openSpinner();

      final hasFireParent =
          repo.getCreatureById(inst.baseId)?.types.contains('Fire') == true ||
          wild.types.contains('Fire');

      final fireMult = factions.fireHatchTimeMultiplier(
        hasFireParent: hasFireParent,
        perk2: firePerk2,
      );

      final result = engine.breedInstanceWithCreature(inst, wild);
      if (!result.success || result.creature == null) {
        closeSpinnerIfOpen();
        _snack('No offspring this time.');
        return;
      }

      final baby = result.creature!;

      final rarityKey = baby.rarity.toLowerCase();
      final baseHatch =
          BreedConstants.rarityHatchTimes[rarityKey] ??
          const Duration(minutes: 10);
      final hatchMult = hatchMultForNature(baby.nature?.id);
      final adjusted = Duration(
        milliseconds: (baseHatch.inMilliseconds * hatchMult * fireMult).round(),
      );

      final payload = {
        'baseId': baby.id,
        'rarity': baby.rarity,
        'natureId': baby.nature?.id,
        'genetics': baby.genetics?.variants ?? <String, String>{},
        'parentage': baby.parentage?.toJson(),
        'isPrismaticSkin': baby.isPrismaticSkin,
      };
      final payloadJson = jsonEncode(payload);
      final eggId = 'egg_${DateTime.now().millisecondsSinceEpoch}';

      final free = await dbApi.firstFreeSlot();
      int? placedIndex;
      bool enqueued = false;

      if (free == null) {
        await dbApi.enqueueEgg(
          eggId: eggId,
          resultCreatureId: baby.id,
          bonusVariantId: result.variantUnlocked?.id,
          rarity: baby.rarity,
          remaining: adjusted,
          payloadJson: payloadJson,
        );
        enqueued = true;
      } else {
        final hatchAtUtc = DateTime.now().toUtc().add(adjusted);
        await dbApi.placeEgg(
          slotId: free.id,
          eggId: eggId,
          resultCreatureId: baby.id,
          bonusVariantId: result.variantUnlocked?.id,
          rarity: baby.rarity,
          hatchAtUtc: hatchAtUtc,
          payloadJson: payloadJson,
        );
        placedIndex = free.id;
      }

      final waterPerk1 = factions.perk1Active && factions.isWater();
      final partnerIsWater =
          (repo.getCreatureById(inst.baseId)?.types.contains('Water') ?? false);
      final wildIsWater = wild.types.contains('Water');

      final skipStamina = factions.waterSkipBreedStamina(
        bothWater: partnerIsWater && wildIsWater,
        perk1: waterPerk1,
      );

      if (!skipStamina) {
        await stamina.spendForBreeding(inst.instanceId);
      }

      closeSpinnerIfOpen();

      if (!mounted) return;
      await _showResultDialog(
        context,
        baby,
        incubatorSlotIndex: placedIndex,
        hatchIn: adjusted,
        enqueuedInstead: enqueued,
      );

      if (!mounted) return;
      Navigator.of(context).pop(EncounterResult.bred);
    } catch (e) {
      closeSpinnerIfOpen();
      _snack('Breeding failed: $e');
    } finally {
      if (mounted) setState(() => _isBreeding = false);
    }
  }

  Future<void> _showResultDialog(
    BuildContext context,
    Creature baby, {
    Creature? unlockedVariant,
    int? incubatorSlotIndex,
    Duration? hatchIn,
    bool enqueuedInstead = false,
  }) async {
    final placedMsg = (incubatorSlotIndex != null)
        ? 'Breeding success! Egg placed in incubator slot ${incubatorSlotIndex + 1}.'
        : 'Breeding success! Egg placed in incubator.';

    final queuedMsg =
        'Breeding success! Incubator full — egg sent to storage queue.';

    final eta = (hatchIn != null)
        ? '• Estimated hatch: ~${_fmtDuration(hatchIn)}'
        : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.indigo[600]),
            const SizedBox(width: 8),
            Text(
              'Research Success!',
              style: TextStyle(color: Colors.indigo[800]),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              enqueuedInstead
                  ? 'Cross-breeding successful! Embryo secured in research queue for incubation.'
                  : 'Cross-breeding successful! Embryo placed in laboratory incubator for development.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            if (eta != null) ...[
              const SizedBox(height: 6),
              Text(
                'Estimated development time: $eta',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Document Results',
              style: TextStyle(color: Colors.indigo[600]),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF374151),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ), // Reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14), // Reduced from 16
          const SizedBox(width: 4), // Reduced from 6
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11, // Reduced from 12
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityCard extends StatelessWidget {
  final String title;
  final Creature? creature;
  final String subtitle;

  const _CompatibilityCard({
    required this.title,
    required this.creature,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10), // Reduced from 12
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11, // Reduced from 12
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3), // Reduced from 4
          Text(
            creature?.name ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14, // Reduced from 16
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3), // Reduced from 4
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
            ), // Reduced from 10
          ),
        ],
      ),
    );
  }
}

// Keep existing classes: _WildPreviewBox, _OneSpriteGame, _PartyGrid, _PartyCard, etc.
// (These remain the same as in your original code)

class _WildPreviewBox extends StatelessWidget {
  final Creature? creature;
  const _WildPreviewBox({required this.creature});

  @override
  Widget build(BuildContext context) {
    if (creature?.spriteData == null) {
      return Container(
        width: 100, // Reduced from 120
        height: 100,
        alignment: Alignment.center,
        decoration: _boxDeco(),
        child: Text(
          'No sprite',
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
      );
    }
    final sd = creature!.spriteData!;
    return Container(
      width: 100, // Reduced from 120
      height: 100,
      decoration: _boxDeco(),
      padding: const EdgeInsets.all(4), // Reduced from 6
      child: GameWidget(
        game: _OneSpriteGame(
          spritePath: sd.spriteSheetPath,
          frames: sd.totalFrames,
          rows: sd.rows,
          frameSize: Vector2(
            sd.frameWidth.toDouble(),
            sd.frameHeight.toDouble(),
          ),
          stepTime: sd.frameDurationMs / 1000.0,
          genetics: creature!.genetics,
          prismatic: creature!.isPrismaticSkin == true,
        ),
      ),
    );
  }

  BoxDecoration _boxDeco() => BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.indigo[300]!, width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.indigo[100]!,
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

class _OneSpriteGame extends FlameGame {
  final String spritePath;
  final int frames;
  final int rows;
  final Vector2 frameSize;
  final double stepTime;
  final Genetics? genetics;
  final bool prismatic;

  _OneSpriteGame({
    required this.spritePath,
    required this.frames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
    required this.genetics,
    required this.prismatic,
  });

  @override
  Future<void> onLoad() async {
    final box = Vector2(size.x, size.y);
    final scale = _scaleFromGenes(genetics);

    add(
      CreatureSpriteComponent(
          spritePath: spritePath,
          totalFrames: frames,
          rows: rows,
          frameSize: frameSize,
          stepTime: stepTime,
          scaleFactor: scale,
          saturation: _satFromGenes(genetics),
          brightness: _briFromGenes(genetics),
          baseHueShift: _hueFromGenes(genetics),
          isPrismatic: prismatic,
          desiredSize: box,
        )
        ..anchor = Anchor.center
        ..position = box / 2,
    );
  }

  double _scaleFromGenes(Genetics? g) {
    switch (g?.get('size')) {
      case 'tiny':
        return 0.75;
      case 'small':
        return 0.9;
      case 'large':
        return 1.15;
      case 'giant':
        return 1.3;
      default:
        return 1.0;
    }
  }

  double _satFromGenes(Genetics? g) {
    switch (g?.get('tinting')) {
      case 'vibrant':
        return 1.4;
      case 'pale':
        return 0.6;
      case 'warm':
      case 'cool':
        return 1.1;
      default:
        return 1.0;
    }
  }

  double _briFromGenes(Genetics? g) {
    switch (g?.get('tinting')) {
      case 'vibrant':
        return 1.1;
      case 'pale':
        return 1.2;
      case 'warm':
      case 'cool':
        return 1.05;
      default:
        return 1.0;
    }
  }

  double _hueFromGenes(Genetics? g) {
    switch (g?.get('tinting')) {
      case 'warm':
        return 15.0;
      case 'cool':
        return -15.0;
      default:
        return 0.0;
    }
  }
}

/// Bottom party grid
class _PartyGrid extends StatelessWidget {
  final List<PartyMember> party;
  final PartyMember? selected;
  final ValueChanged<PartyMember> onPick;

  const _PartyGrid({
    required this.party,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (party.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16), // Reduced from 24
          child: Text(
            'No research team members available for breeding studies',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ), // Reduced from 16
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), // Reduced padding
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8, // Reduced from 10
        crossAxisSpacing: 8, // Reduced from 10
        childAspectRatio: 1.1, // Slightly reduced from 1.2
      ),
      itemCount: party.length,
      itemBuilder: (context, i) {
        final p = party[i];
        final isSel = selected?.instanceId == p.instanceId;
        return _PartyCard(member: p, selected: isSel, onTap: () => onPick(p));
      },
    );
  }
}

class _PartyCard extends StatelessWidget {
  final PartyMember member;
  final bool selected;
  final VoidCallback onTap;

  const _PartyCard({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dbInstance = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.indigo[400]! : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.indigo[200]!,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey[200]!,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(8), // Reduced from 10
        child: FutureBuilder<db.CreatureInstance?>(
          future: dbInstance.getInstance(member.instanceId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const _PartyCardSkeleton();
            }
            final inst = snap.data!;
            final base = repo.getCreatureById(inst.baseId);
            final displayName = base?.name ?? inst.baseId;
            final stamina = inst.staminaBars;
            final maxStamina = inst.staminaMax;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PartyThumb(base: base, instance: inst),
                ),
                const SizedBox(height: 4), // Reduced from 6
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11, // Reduced from 12
                    color: selected ? Colors.indigo[700] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 3), // Reduced from 4
                _StaminaBar(current: stamina, max: maxStamina),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PartyThumb extends StatelessWidget {
  final Creature? base;
  final db.CreatureInstance instance;
  const _PartyThumb({required this.base, required this.instance});

  @override
  Widget build(BuildContext context) {
    final thumbPath = base?.image;
    if (thumbPath != null && thumbPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8), // Reduced from 10
        child: Image.asset(
          'assets/images/$thumbPath',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _fallbackThumb();
          },
        ),
      );
    }
    return _fallbackThumb();
  }

  Widget _fallbackThumb() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8), // Reduced from 10
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        instance.instanceId,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9, // Reduced from 10
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _PartyCardSkeleton extends StatelessWidget {
  const _PartyCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8), // Reduced from 10
            ),
          ),
        ),
        const SizedBox(height: 4), // Reduced from 6
        Container(
          height: 8, // Reduced from 10
          width: 50, // Reduced from 60
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4), // Reduced from 6
        const _StaminaBar(current: 0, max: 100),
      ],
    );
  }
}

class _StaminaBar extends StatelessWidget {
  final int current;
  final int max;
  const _StaminaBar({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = (max <= 0) ? 0.0 : (current / max).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4), // Reduced from 6
      child: Stack(
        children: [
          Container(height: 6, color: Colors.grey[200]), // Reduced from 8
          FractionallySizedBox(
            widthFactor: pct,
            child: Container(
              height: 6, // Reduced from 8
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: pct > 0.5
                      ? [Colors.green[400]!, Colors.green[600]!]
                      : pct > 0.2
                      ? [Colors.orange[400]!, Colors.orange[600]!]
                      : [Colors.red[400]!, Colors.red[600]!],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
