import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/game.dart';
import '../providers/app_providers.dart';
import '../models/creature.dart';
import '../widgets/creature_sprite.dart';

class CreatureDetailsDialog extends StatefulWidget {
  final Creature creature;
  final bool isDiscovered;
  final String? instanceId;

  const CreatureDetailsDialog({
    super.key,
    required this.creature,
    required this.isDiscovered,
    this.instanceId,
  });

  @override
  State<CreatureDetailsDialog> createState() => _CreatureDetailsDialogState();

  static void show(
    BuildContext context,
    Creature creature,
    bool isDiscovered, {
    String? instanceId,
  }) {
    showDialog(
      context: context,
      builder: (context) => CreatureDetailsDialog(
        creature: creature,
        isDiscovered: isDiscovered || instanceId != null,
        instanceId: instanceId,
      ),
    );
  }
}

class _CreatureDetailsDialogState extends State<CreatureDetailsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentImageIndex = 0;
  late PageController _pageController;
  Future<Creature>? _resolvedCreature;
  Set<String> _expandedParents = {};

  // Instance data for level/XP display
  int? _instanceLevel;
  int? _instanceXp;
  int? _instanceXpToNext;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.isDiscovered ? 2 : 1,
      vsync: this,
    );
    _pageController = PageController(viewportFraction: 1.0);
    if (widget.instanceId != null) {
      _resolvedCreature = _displayCreatureForInstance(widget.instanceId!);
    }
  }

  Future<Creature> _displayCreatureForInstance(String instanceId) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    final row = await db.getInstance(instanceId);
    if (row == null) throw Exception('Instance not found');

    // Store level and XP data
    _instanceLevel = row.level;
    _instanceXp = row.xp;

    final base = repo.getCreatureById(row.baseId);
    if (base == null) {
      throw Exception('Catalog creature ${row.baseId} not loaded');
    }

    // start from catalog template
    var out = base;

    // apply instance-level cosmetics/stats
    if (row.isPrismaticSkin == true) {
      out = out.copyWith(isPrismaticSkin: true);
    }
    if (row.natureId != null && row.natureId!.isNotEmpty) {
      final n = NatureCatalog.byId(row.natureId!);
      if (n != null) out = out.copyWith(nature: n);
    }
    final g = decodeGenetics(row.geneticsJson);
    if (g != null) out = out.copyWith(genetics: g);

    final decoded = _decodeParentage(row.parentageJson);
    if (decoded != null) {
      final hydrated = decoded.rehydrate(
        repo,
      ); // <-- requires the rehydrate() helpers
      out = out.copyWith(parentage: hydrated);
    }

    return out;
  }

  Parentage? _decodeParentage(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return Parentage.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _sizeName(Creature c) =>
      sizeLabels[c.genetics?.get('size') ?? 'normal'] ?? 'Standard';

  String _tintName(Creature c) =>
      tintLabels[c.genetics?.get('tinting') ?? 'normal'] ?? 'Standard';

  @override
  Widget build(BuildContext context) {
    if (widget.instanceId == null) {
      return _buildScaffoldWithCreature(widget.creature);
    }

    return FutureBuilder<Creature>(
      future: _resolvedCreature,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return _buildScaffoldWithCreature(widget.creature);
        }
        return _buildScaffoldWithCreature(snap.data!);
      },
    );
  }

  Widget _buildScaffoldWithCreature(Creature effective) {
    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 1,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.shade200,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildDialogHeader(effective),
            if (widget.isDiscovered) _buildTabBar(),
            Expanded(
              child: widget.isDiscovered
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(effective),
                        _buildAnalysisTab(effective),
                      ],
                    )
                  : _buildUnknownTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(Creature c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: Colors.indigo.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.biotech_rounded,
              color: Colors.indigo.shade600,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.isDiscovered ? c.name : 'Unknown Specimen',
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Show level in header if this is an instance
                    if (widget.instanceId != null && _instanceLevel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          'LVL $_instanceLevel',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),

                Text(
                  'Specimen Analysis Report',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.grey.shade600,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.shade100,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.indigo.shade700,
        unselectedLabelColor: Colors.indigo.shade500,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Analysis'),
        ],
      ),
    );
  }

  Widget _buildSwipeableCreatureDisplay(
    List<Map<String, dynamic>> allVersions,
  ) {
    return Center(
      child: Column(
        children: [
          Container(
            height: 140,
            width: 140,
            child: PageView.builder(
              controller: _pageController,
              itemCount: allVersions.length,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final versionData = allVersions[index];
                final creature = versionData['creature'] as Creature;
                final isVariant = versionData['isVariant'] as bool;

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200, width: 2),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CreatureSprite(
                            spritePath: creature.spriteData!.spriteSheetPath,
                            totalFrames: creature.spriteData!.totalFrames,
                            rows: creature.spriteData!.rows,
                            scale: scaleFromGenes(creature.genetics),
                            saturation: satFromGenes(creature.genetics),
                            brightness: briFromGenes(creature.genetics),
                            hueShift: hueFromGenes(creature.genetics),
                            isPrismatic: creature.isPrismaticSkin,
                            frameSize: Vector2(
                              creature.spriteData!.frameWidth.toDouble(),
                              creature.spriteData!.frameHeight.toDouble(),
                            ),
                            stepTime:
                                (creature.spriteData!.frameDurationMs / 1000.0),
                          ),
                        ),
                        if (isVariant)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'VAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (creature.isPrismaticSkin == true)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade600,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'PRIS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (allVersions.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                allVersions.length,
                (index) => Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.indigo.shade600
                        : Colors.indigo.shade300,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Creature c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<GameStateNotifier>(
            builder: (context, gameState, child) {
              final variants = gameState.discoveredCreatures.where((data) {
                final creature = data['creature'] as Creature;
                return creature.rarity == 'Variant' &&
                    creature.id.startsWith('${c.id}_');
              }).toList();

              final allVersions = [
                {'creature': c, 'isVariant': false},
                ...variants.map(
                  (v) => {'creature': v['creature'], 'isVariant': true},
                ),
              ];

              return _buildSwipeableCreatureDisplay(allVersions);
            },
          ),
          const SizedBox(height: 16),
          if (widget.instanceId != null) ...[
            _buildDataSection('Specimen Status', [
              if (_instanceLevel != null) _buildLevelRow(),
              _buildStaminaRow(),
            ]),
          ],
          const SizedBox(height: 16),
          _buildDataSection('Specimen Classification', [
            _buildDataRow('Classification', c.rarity),
            _buildDataRow('Type Categories', c.types.join(', ')),
            if (c.description.isNotEmpty)
              _buildDataRow('Description', c.description),
          ]),
          const SizedBox(height: 12),
          _buildDataSection('Genetic Profile', [
            _buildDataRow('Size Variant', _sizeName(c)),
            _buildDataRow('Pigmentation', _tintName(c)),
            if (c.nature != null)
              _buildDataRow('Behavioral Pattern', c.nature!.id),
            if (c.isPrismaticSkin == true)
              _buildDataRow('Special Trait', 'Prismatic Phenotype'),
          ]),

          if (c.specialBreeding != null)
            _buildDataSection('Synthesis Requirements', [
              _buildDataRow('Method', 'Specialized Genetic Fusion'),
              _buildDataRow(
                'Required Components',
                c.specialBreeding!.requiredParentNames.join(' + '),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildStaminaRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              'Energy Level',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: StaminaBadge(
                instanceId: widget.instanceId!,
                showCountdown: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              'Level',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$_instanceLevel',
            style: TextStyle(
              color: Colors.amber.shade800,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.indigo.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (value.isNotEmpty)
            Expanded(
              child: Text(
                value.toUpperCase(),
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add this method to your _CreatureDetailsDialogState class

  Widget _buildAnalysisTab(Creature c) {
    final parentage = c.parentage;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breeding Likelihood Section (NEW)
          if (parentage != null && widget.instanceId != null) ...[
            _buildBreedingLikelihoodSection(),
            const SizedBox(height: 16),
          ],

          // Nature Analysis Section
          _buildDataSection('Behavioral Analysis', [
            if (c.nature != null) ...[
              _buildDataRow('Nature Type', c.nature!.id),
              if (c.nature!.effect.modifiers.isNotEmpty) ...[
                _buildDataRow(
                  'Active Effects',
                  _formatNatureEffects(c.nature!.effect),
                ),
              ] else ...[
                _buildDataRow(
                  'Effects',
                  'No special behavioral modifications known',
                ),
              ],
            ] else ...[
              _buildDataRow(
                'Nature',
                'Unspecified - Standard behavioral pattern',
              ),
            ],
          ]),

          const SizedBox(height: 12),

          // Detailed Genetics Analysis Section
          _buildDataSection('Genetic Analysis', [
            if (c.genetics != null) ...[
              // Size genetics
              if (c.genetics!.get('size') != null) ...[
                _buildDataRow('Size Gene', c.genetics!.get('size')!),
              ] else ...[
                _buildDataRow('Size Gene', 'normal (default)'),
                _buildDataRow('Size Expression', 'Standard morphology'),
              ],

              // Tinting genetics
              if (c.genetics!.get('tinting') != null) ...[
                _buildDataRow(
                  'Coloration',
                  tintLabels[c.genetics!.get('tinting')]!,
                ),
                _buildDataRow(
                  'Color',
                  _getGeneticDescription(
                    'tinting',
                    c.genetics!.get('tinting')!,
                  ),
                ),
              ] else ...[
                _buildDataRow('Coloration Gene', 'normal (default)'),
                _buildDataRow('Color Expression', 'Natural pigmentation'),
              ],
              const SizedBox(height: 12),
              // title for dominance
              Text(
                'Inheritance Analysis',
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _buildDataRow(
                'Nature',
                c.nature?.dominance == 1 ? 'Recessive' : 'Dominant',
              ),
              // Dominance analysis
              _buildDataRow(
                'Size',
                _getGeneDominance('size', c.genetics!.get('size') ?? 'normal'),
              ),
              _buildDataRow(
                'Color',
                _getGeneDominance(
                  'tinting',
                  c.genetics!.get('tinting') ?? 'normal',
                ),
              ),
            ] else ...[
              _buildDataRow(
                'Genetic Profile',
                'Standard genotype - no variants detected',
              ),
              _buildDataRow('Inheritance', 'Wild-type characteristics'),
            ],
          ]),

          const SizedBox(height: 12),

          // Synthesis Information (existing parentage section)
          if (parentage != null) ...[
            _buildDataSection('Synthesis Information', [
              _buildDataRow('Method', 'Genetic Fusion'),
              _buildDataRow('Date', _formatBreedLine(parentage)),
            ]),
            const SizedBox(height: 12),
            Text(
              'Parent Specimens',
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildParentCard(parentage.parentA, 'parentA'),
            const SizedBox(height: 8),
            _buildParentCard(parentage.parentB, 'parentB'),
          ] else ...[
            _buildDataSection('Acquisition Method', [
              _buildDataRow('Source', 'Field Research'),
              _buildDataRow(
                'Discovery',
                'Wild specimen - no synthesis data available',
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // NEW: Breeding Likelihood Section - Updated to handle new format
  // Breeding Likelihood Section - New format only
  Widget _buildBreedingLikelihoodSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadLikelihoodAnalysis(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.indigo.shade400),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading breeding analysis...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildDataSection('Breeding Analysis', [
            _buildDataRow('Analysis Status', 'No breeding data available'),
            _buildDataRow('Note', 'Analysis requires synthesis information'),
          ]);
        }

        final analysis = snapshot.data!;

        return _buildDataSection('Breeding Likelihood Analysis', [
          _buildDataRow('Analysis Date', 'Generated at synthesis time'),
          const SizedBox(height: 8),
          _buildJustificationSummary(analysis),
          const SizedBox(height: 10),
          _buildJustificationDetails(
            analysis['traitJustifications'] as List? ?? [],
          ),
        ]);
      },
    );
  }

  Widget _buildJustificationSummary(Map<String, dynamic> analysis) {
    final overallOutcome = analysis['overallOutcome'] as String? ?? 'Unknown';
    final traitJustifications = analysis['traitJustifications'] as List? ?? [];
    final summary = analysis['summaryExplanation'] as String? ?? '';

    // Get main traits (family and type)
    final mainTraits = traitJustifications.where((t) {
      final trait = t as Map;
      final category = trait['category'] as String;
      return category == 'familyLineage' ||
          category == 'elementalType' ||
          category == 'nature';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall outcome
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                'Outcome',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getOutcomeColor(overallOutcome).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getOutcomeColor(overallOutcome).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getOutcomeEmoji(overallOutcome),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    overallOutcome,
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (mainTraits.isNotEmpty) ...[
          const SizedBox(height: 6),
          // Key trait results
          Padding(
            padding: const EdgeInsets.only(left: 90),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: mainTraits.map((t) {
                final trait = t as Map;
                final traitName = trait['trait'] as String;
                final actualValue = trait['actualValue'] as String;
                final actualChance = (trait['actualChance'] as num).toDouble();

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Text(
                    '$traitName: $actualValue (${actualChance.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 90),
            child: Text(
              summary.split('\n').first, // Just the main summary line
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildJustificationDetails(List traitJustifications) {
    final categories = {
      'familyLineage': 'Family Lineage',
      'elementalType': 'Elemental Type',
      'genetics': 'Genetics',
      'nature': 'Nature',
      'special': 'Special Events',
    };

    return Column(
      children: categories.entries.map((entry) {
        final categoryTraits = traitJustifications.where((t) {
          final trait = t as Map;
          return trait['category'] == entry.key;
        }).toList();

        if (categoryTraits.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            const SizedBox(height: 6),
            ...categoryTraits.map((t) {
              final trait = t as Map;
              return _buildJustificationResult(
                entry.value,
                trait['actualValue'] as String,
                (trait['actualChance'] as num).toDouble(),
                trait['mechanism'] as String,
                trait['explanation'] as String,
                trait['wasUnexpected'] as bool? ?? false,
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildJustificationResult(
    String category,
    String value,
    double percentage,
    String mechanism,
    String explanation,
    bool wasUnexpected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                category,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (wasUnexpected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (wasUnexpected) const SizedBox(width: 6),
                  Text(
                    '$value (${percentage.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mechanism,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                explanation,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper methods
  Color _getOutcomeColor(String outcome) {
    switch (outcome) {
      case 'Expected':
        return Colors.green;
      case 'Surprising':
        return Colors.orange;
      case 'Rare':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getOutcomeEmoji(String outcome) {
    switch (outcome) {
      case 'Expected':
        return '✅';
      case 'Surprising':
        return '❗';
      case 'Rare':
        return '✨';
      default:
        return '❓';
    }
  }

  // NEW: Load likelihood analysis from database
  Future<Map<String, dynamic>?> _loadLikelihoodAnalysis() async {
    if (widget.instanceId == null) return null;

    try {
      final db = context.read<AlchemonsDatabase>();
      final instance = await db.getInstance(widget.instanceId!);

      if (instance?.likelihoodAnalysisJson == null ||
          instance!.likelihoodAnalysisJson!.isEmpty) {
        return null;
      }

      return jsonDecode(instance.likelihoodAnalysisJson!)
          as Map<String, dynamic>;
    } catch (e) {
      print('Error loading likelihood analysis: $e');
      return null;
    }
  }

  // NEW: Build likelihood results display
  Widget _buildLikelihoodResults(String category, dynamic results) {
    if (results == null || (results as List).isEmpty) {
      return _buildDataRow(category, 'No data available');
    }

    final resultList = results;
    final topResult = resultList.first as Map<String, dynamic>;

    final likelihood = _getLikelihoodFromIndex(
      (topResult['likelihood'] as int?) ?? 0,
    );
    final percentage = ((topResult['percentage'] as num?)?.toDouble() ?? 0.0)
        .toStringAsFixed(1);
    final value = topResult['value'] as String;
    final description = topResult['description'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                category,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getLikelihoodColor(likelihood).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getLikelihoodColor(likelihood).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getLikelihoodEmoji(likelihood),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$value ($percentage%)',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 90),
            child: Text(
              description,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // NEW: Helper methods for likelihood display
  String _getLikelihoodFromIndex(int index) {
    const likelihoods = ['Improbable', 'Unlikely', 'Likely', 'Probable'];
    return likelihoods[index.clamp(0, 3)];
  }

  Color _getLikelihoodColor(String likelihood) {
    switch (likelihood) {
      case 'Probable':
        return Colors.green;
      case 'Likely':
        return Colors.blue;
      case 'Unlikely':
        return Colors.orange;
      case 'Improbable':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getLikelihoodEmoji(String likelihood) {
    switch (likelihood) {
      case 'Probable':
        return '🎯';
      case 'Likely':
        return '⚖️';
      case 'Unlikely':
        return '🎲';
      case 'Improbable':
        return '🔮';
      default:
        return '❓';
    }
  }

  // Helper method to format nature effects
  String _formatNatureEffects(NatureEffect effect) {
    if (effect.modifiers.isEmpty) return 'None';

    final effects = <String>[];
    effect.modifiers.forEach((key, value) {
      switch (key) {
        case 'stamina_extra':
          effects.add('Stamina +${value.toInt()}');
          break;
        case 'stamina_breeding_cost_mult':
          final percent = ((1 - value) * 100).round();
          effects.add('Breeding cost -$percent%');
          break;
        case 'stamina_wilderness_drain_mult':
          final percent = ((1 - value) * 100).round();
          effects.add('Wilderness stamina -$percent%');
          break;
        case 'breed_same_species_chance_mult':
          final percent = ((value - 1) * 100).round();
          effects.add(
            'Same species breeding ${percent >= 0 ? '+' : ''}$percent%',
          );
          break;
        case 'breed_same_type_chance_mult':
          final percent = ((value - 1) * 100).round();
          effects.add('Same type breeding ${percent >= 0 ? '+' : ''}$percent%');
          break;
        case 'egg_hatch_time_mult':
          final percent = ((1 - value) * 100).round();
          effects.add('Hatch time -$percent%');
          break;
        case 'xp_gain_mult':
          final percent = ((value - 1) * 100).round();
          effects.add('XP gain +$percent%');
          break;
        default:
          effects.add('$key: ${value}x');
      }
    });

    return effects.join(', ');
  }

  // Helper method to get genetic descriptions
  String _getGeneticDescription(String track, String variant) {
    try {
      final geneTrack = GeneticsCatalog.track(track);
      final geneVariant = geneTrack.byId(variant);
      return geneVariant.description;
    } catch (e) {
      return 'Unknown variant';
    }
  }

  // Helper method to get genetic effects
  String _getGeneticEffect(String track, String variant) {
    try {
      final geneTrack = GeneticsCatalog.track(track);
      final geneVariant = geneTrack.byId(variant);

      if (track == 'size') {
        final scale = geneVariant.effect['scale'] as double? ?? 1.0;
        final percent = ((scale - 1) * 100).round();
        return 'Scale ${percent >= 0 ? '+' : ''}$percent%';
      } else if (track == 'tinting') {
        final effects = <String>[];
        final hue = geneVariant.effect['hue_shift'] as num? ?? 0;
        final sat = geneVariant.effect['saturation'] as num? ?? 1.0;
        final bri = geneVariant.effect['brightness'] as num? ?? 1.0;

        if (hue != 0) effects.add('Hue ${hue >= 0 ? '+' : ''}$hue°');
        if (sat != 1.0) {
          final percent = ((sat - 1) * 100).round();
          effects.add('Saturation ${percent >= 0 ? '+' : ''}$percent%');
        }
        if (bri != 1.0) {
          final percent = ((bri - 1) * 100).round();
          effects.add('Brightness ${percent >= 0 ? '+' : ''}$percent%');
        }

        return effects.isEmpty ? 'No modification' : effects.join(', ');
      }

      return 'Custom effects applied';
    } catch (e) {
      return 'Effect unknown';
    }
  }

  // Helper method to get gene dominance info
  String _getGeneDominance(String track, String variant) {
    try {
      final geneTrack = GeneticsCatalog.track(track);
      final geneVariant = geneTrack.byId(variant);
      final dominance = geneVariant.dominance;

      if (dominance >= 6) return 'Dominant';
      if (dominance >= 4) return 'Moderately dominant';
      if (dominance >= 2) return 'Recessive';
      return 'Recessive';
    } catch (e) {
      return 'Unknown dominance';
    }
  }

  // Helper method to describe inheritance patterns
  String _getInheritancePattern(Genetics genetics) {
    final patterns = <String>[];

    try {
      if (genetics.get('size') != null) {
        final track = GeneticsCatalog.track('size');
        patterns.add('Size: ${track.inheritance}');
      }
      if (genetics.get('tinting') != null) {
        final track = GeneticsCatalog.track('tinting');
        patterns.add('Color: ${track.inheritance}');
      }

      return patterns.isEmpty ? 'Standard inheritance' : patterns.join('; ');
    } catch (e) {
      return 'Complex inheritance patterns';
    }
  }

  // Helper method to assess fertility
  String _getFertilityRating(Genetics genetics) {
    try {
      final sizeVariant = genetics.get('size') ?? 'normal';
      final breedingEffects = GeneticsCatalog.breedingEffects;

      if (breedingEffects['size'] != null &&
          breedingEffects['size']['fertility_bonus'] != null) {
        final bonus =
            breedingEffects['size']['fertility_bonus'][sizeVariant] as num?;
        if (bonus != null) {
          if (bonus < 0) return 'Reduced (${bonus.toInt()})';
          if (bonus > 0) return 'Enhanced (+${bonus.toInt()})';
        }
      }

      return 'Standard fertility';
    } catch (e) {
      return 'Assessment unavailable';
    }
  }

  // Helper method to assess mutation risk
  String _getMutationRisk(Genetics genetics) {
    try {
      double totalRisk = 0.0;
      int trackCount = 0;

      if (genetics.get('size') != null) {
        totalRisk += GeneticsCatalog.track('size').mutationChance;
        trackCount++;
      }
      if (genetics.get('tinting') != null) {
        totalRisk += GeneticsCatalog.track('tinting').mutationChance;
        trackCount++;
      }

      if (trackCount == 0) return 'Minimal';

      final avgRisk = totalRisk / trackCount;
      if (avgRisk > 0.15)
        return 'High (${(avgRisk * 100).toStringAsFixed(1)}%)';
      if (avgRisk > 0.08)
        return 'Moderate (${(avgRisk * 100).toStringAsFixed(1)}%)';
      return 'Low (${(avgRisk * 100).toStringAsFixed(1)}%)';
    } catch (e) {
      return 'Assessment error';
    }
  }

  // Helper method to assess trait stability
  String _getTraitStability(Genetics genetics) {
    try {
      final variants = <String>[];
      if (genetics.get('size') != null) variants.add(genetics.get('size')!);
      if (genetics.get('tinting') != null)
        variants.add(genetics.get('tinting')!);

      final nonStandard = variants.where((v) => v != 'normal').length;

      if (nonStandard == 0) return 'Highly stable - wild type';
      if (nonStandard == 1) return 'Stable with minor variation';
      return 'Variable - multiple mutations';
    } catch (e) {
      return 'Unknown stability';
    }
  }

  // Helper method to check for breeding effects
  bool _hasBreedingEffects(Genetics genetics) {
    try {
      final sizeVariant = genetics.get('size') ?? 'normal';
      final breedingEffects = GeneticsCatalog.breedingEffects;

      return breedingEffects['size'] != null &&
          breedingEffects['size']['fertility_bonus'] != null &&
          breedingEffects['size']['fertility_bonus'][sizeVariant] != null;
    } catch (e) {
      return false;
    }
  }

  // Helper method to get breeding modifiers
  String _getBreedingModifiers(Genetics genetics) {
    try {
      final sizeVariant = genetics.get('size') ?? 'normal';
      final breedingEffects = GeneticsCatalog.breedingEffects;

      if (breedingEffects['size']?['fertility_bonus']?[sizeVariant] != null) {
        final bonus =
            breedingEffects['size']['fertility_bonus'][sizeVariant] as num;
        return 'Size-based fertility modifier: ${bonus.toInt()}';
      }

      return 'None detected';
    } catch (e) {
      return 'Analysis error';
    }
  }

  String _formatBreedLine(Parentage p) {
    final dt = p.bredAt;
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _buildParentCard(ParentSnapshot snap, String parentId) {
    final isExpanded = _expandedParents.contains(parentId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedParents.remove(parentId);
                } else {
                  _expandedParents.add(parentId);
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: snap.spriteData != null
                          ? CreatureSprite(
                              spritePath: snap.spriteData!.spriteSheetPath,
                              totalFrames: snap.spriteData!.totalFrames,
                              rows: snap.spriteData!.rows,
                              frameSize: Vector2(
                                snap.spriteData!.frameWidth.toDouble(),
                                snap.spriteData!.frameHeight.toDouble(),
                              ),
                              stepTime:
                                  snap.spriteData!.frameDurationMs / 1000.0,
                              scale: scaleFromGenes(snap.genetics),
                              saturation: satFromGenes(snap.genetics),
                              brightness: briFromGenes(snap.genetics),
                              hueShift: hueFromGenes(snap.genetics),
                              isPrismatic: snap.isPrismaticSkin,
                            )
                          : Image.asset(snap.image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snap.name,
                          style: TextStyle(
                            color: Colors.indigo.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          snap.types.join(' • '),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          snap.rarity,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (snap.isPrismaticSkin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'P',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.indigo.shade400,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(color: Colors.indigo.shade200, height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _buildParentDataSection('Genetic Profile', [
                    if (snap.genetics?.get('size') != null)
                      _buildDataRow(
                        'Size Variant',
                        sizeLabels[snap.genetics!.get('size')] ?? 'Standard',
                      ),
                    if (snap.genetics?.get('tinting') != null)
                      _buildDataRow(
                        'Pigmentation',
                        tintLabels[snap.genetics!.get('tinting')] ?? 'Standard',
                      ),
                    if (snap.nature != null)
                      _buildDataRow('Behavior', snap.nature!.id),
                  ]),
                  if (snap.genetics != null &&
                      (snap.genetics!.get('size') != null ||
                          snap.genetics!.get('tinting') != null)) ...[
                    const SizedBox(height: 8),
                    _buildParentDataSection('Genetic Contribution', [
                      _buildDataRow(
                        'Traits Passed',
                        '${sizeLabels[snap.genetics!.get('size')] ?? 'Standard'} morphology, ${(tintLabels[snap.genetics!.get('tinting')] ?? 'Standard').toLowerCase()} pigmentation',
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParentDataSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.indigo.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildUnknownTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.help_outline_rounded,
              color: Colors.grey.shade400,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Unknown Specimen',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Specimen data unavailable\nContinue research to unlock analysis',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
