import 'dart:convert';
import 'dart:ui';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/screens/instance_selection_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
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

  static Future<void> show(
    BuildContext context,
    Creature creature,
    bool isDiscovered, {
    String? instanceId,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
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
  final Set<String> _expandedParents = {};
  late ScrollController _scrollController;

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
    _scrollController = ScrollController();
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

    _instanceLevel = row.level;
    _instanceXp = row.xp;

    final base = repo.getCreatureById(row.baseId);
    if (base == null) {
      throw Exception('Catalog creature ${row.baseId} not loaded');
    }

    var out = base;

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
      final hydrated = decoded.rehydrate(repo);
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
    _scrollController.dispose();
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
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F14).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return _buildScaffoldWithCreature(widget.creature);
        }
        return _buildScaffoldWithCreature(snap.data!);
      },
    );
  }

  Widget _buildScaffoldWithCreature(Creature effective) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;
    final secondaryColor = factionColors.$2;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14).withOpacity(0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withOpacity(.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildDialogHeader(effective, primaryColor),
                if (widget.isDiscovered) _buildTabBar(primaryColor),
                Expanded(
                  child: widget.isDiscovered
                      ? TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverviewTab(effective, primaryColor),
                            _buildAnalysisTab(effective, primaryColor),
                          ],
                        )
                      : _buildUnknownTab(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(Creature c, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.3),
        border: Border(bottom: BorderSide(color: primaryColor.withOpacity(.3))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(.3),
                  primaryColor.withOpacity(.2),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.biotech_rounded, color: primaryColor, size: 18),
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
                        widget.isDiscovered
                            ? c.name.toUpperCase()
                            : 'UNKNOWN SPECIMEN',
                        style: const TextStyle(
                          color: Color(0xFFE8EAED),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.instanceId != null && _instanceLevel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade600,
                              Colors.amber.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(.3),
                          ),
                        ),
                        child: Text(
                          'LV $_instanceLevel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Specimen analysis report',
                  style: TextStyle(
                    color: Color(0xFFB6C0CC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(.2)),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFE8EAED),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(.3)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(.3),
              primaryColor.withOpacity(.2),
            ],
          ),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: primaryColor.withOpacity(.4)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFFE8EAED),
        unselectedLabelColor: const Color(0xFFB6C0CC),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        tabs: const [
          Tab(text: 'OVERVIEW'),
          Tab(text: 'ANALYSIS'),
        ],
      ),
    );
  }

  Widget _buildSwipeableCreatureDisplay(
    List<Map<String, dynamic>> allVersions,
    Color primaryColor,
  ) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          width: 160,
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

              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                    ),
                    if (isVariant)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade500,
                                Colors.orange.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withOpacity(.3),
                            ),
                          ),
                          child: const Text(
                            'VARIANT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    if (creature.isPrismaticSkin == true)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withOpacity(.3),
                            ),
                          ),
                          child: const Text(
                            'PRISMATIC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (allVersions.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              allVersions.length,
              (index) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentImageIndex == index
                      ? primaryColor
                      : Colors.white.withOpacity(.3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewTab(Creature c, Color primaryColor) {
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

              return Center(
                child: _buildSwipeableCreatureDisplay(
                  allVersions,
                  primaryColor,
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          if (widget.instanceId != null) ...[
            _buildDataSection('Specimen Status', [
              if (_instanceLevel != null) _buildLevelRow(primaryColor),
              _buildStaminaRow(),
            ], primaryColor),
            const SizedBox(height: 16),
          ],
          _buildDataSection('Specimen Classification', [
            _buildDataRow('Classification', c.rarity),
            _buildDataRow('Type Categories', c.types.join(', ')),
            if (c.description.isNotEmpty)
              _buildDataRow('Description', c.description),
          ], primaryColor),
          const SizedBox(height: 16),

          // NEW: Physical Attributes Section
          if (widget.instanceId != null)
            FutureBuilder<CreatureInstance?>(
              future: context.read<AlchemonsDatabase>().getInstance(
                widget.instanceId!,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final instance = snapshot.data!;
                  return Column(
                    children: [
                      _buildDataSection('Physical Attributes', [
                        _buildStatRow(
                          'Speed',
                          instance.statSpeed,
                          primaryColor,
                        ),
                        _buildStatRow(
                          'Intelligence',
                          instance.statIntelligence,
                          primaryColor,
                        ),
                        _buildStatRow(
                          'Strength',
                          instance.statStrength,
                          primaryColor,
                        ),
                        _buildStatRow(
                          'Beauty',
                          instance.statBeauty,
                          primaryColor,
                        ),
                      ], primaryColor),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

          _buildDataSection('Genetic Profile', [
            _buildDataRow('Size Variant', _sizeName(c)),
            _buildDataRow('Pigmentation', _tintName(c)),
            if (c.nature != null)
              _buildDataRow('Behavioral Pattern', c.nature!.id),
            if (c.isPrismaticSkin == true)
              _buildDataRow('Special Trait', 'Prismatic Phenotype'),
          ], primaryColor),
          if (c.specialBreeding != null) ...[
            const SizedBox(height: 16),
            _buildDataSection('Synthesis Requirements', [
              _buildDataRow('Method', 'Specialized Genetic Fusion'),
              _buildDataRow(
                'Required Components',
                c.specialBreeding!.requiredParentNames.join(' + '),
              ),
            ], primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildStaminaRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              'Energy Level',
              style: TextStyle(
                color: Color(0xFFB6C0CC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: StaminaBadge(
              instanceId: widget.instanceId!,
              showCountdown: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              'Level',
              style: TextStyle(
                color: Color(0xFFB6C0CC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$_instanceLevel',
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(
    String title,
    List<Widget> children,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.15)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB6C0CC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (value.isNotEmpty)
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFE8EAED),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab(Creature c, Color primaryColor) {
    final parentage = c.parentage;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parentage != null && widget.instanceId != null) ...[
            _buildBreedingLikelihoodSection(primaryColor),
            const SizedBox(height: 16),
          ],
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
          ], primaryColor),
          const SizedBox(height: 16),
          _buildDataSection('Genetic Analysis', [
            if (c.genetics != null) ...[
              if (c.genetics!.get('size') != null) ...[
                _buildDataRow('Size Gene', c.genetics!.get('size')!),
              ] else ...[
                _buildDataRow('Size Gene', 'normal (default)'),
                _buildDataRow('Size Expression', 'Standard morphology'),
              ],
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
            ] else ...[
              _buildDataRow(
                'Genetic Profile',
                'Standard genotype - no variants detected',
              ),
              _buildDataRow('Inheritance', 'Wild-type characteristics'),
            ],
          ], primaryColor),
          const SizedBox(height: 16),
          if (parentage != null) ...[
            _buildDataSection('Synthesis Information', [
              _buildDataRow('Method', 'Genetic Fusion'),
              _buildDataRow('Date', _formatBreedLine(parentage)),
            ], primaryColor),
            const SizedBox(height: 16),
            Text(
              'PARENT SPECIMENS',
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            _buildParentCard(parentage.parentA, 'parentA', primaryColor),
            const SizedBox(height: 10),
            _buildParentCard(parentage.parentB, 'parentB', primaryColor),
          ] else ...[
            _buildDataSection('Acquisition Method', [
              _buildDataRow('Source', 'Field Research'),
              _buildDataRow(
                'Discovery',
                'Wild specimen - no synthesis data available',
              ),
            ], primaryColor),
          ],
        ],
      ),
    );
  }

  // Keep all your existing helper methods but I'll update the breeding likelihood section
  Widget _buildBreedingLikelihoodSection(Color primaryColor) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadLikelihoodAnalysis(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(.15)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Loading breeding analysis...',
                  style: TextStyle(color: Color(0xFFB6C0CC), fontSize: 11),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildDataSection('Breeding Analysis', [
            _buildDataRow('Analysis Status', 'No breeding data available'),
            _buildDataRow('Note', 'Analysis requires synthesis information'),
          ], primaryColor);
        }

        final analysis = snapshot.data!;

        return _buildDataSection('Breeding Likelihood Analysis', [
          _buildDataRow('Analysis Date', 'Generated at synthesis time'),
          const SizedBox(height: 8),
          _buildJustificationSummary(analysis, primaryColor),
          const SizedBox(height: 10),
          _buildJustificationDetails(
            analysis['traitJustifications'] as List? ?? [],
            primaryColor,
          ),
        ], primaryColor);
      },
    );
  }

  Widget _buildJustificationSummary(
    Map<String, dynamic> analysis,
    Color primaryColor,
  ) {
    final overallOutcome = analysis['overallOutcome'] as String? ?? 'Unknown';
    final traitJustifications = analysis['traitJustifications'] as List? ?? [];
    final summary = analysis['summaryExplanation'] as String? ?? '';

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
        Row(
          children: [
            const SizedBox(
              width: 100,
              child: Text(
                'Outcome',
                style: TextStyle(
                  color: Color(0xFFB6C0CC),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getOutcomeColor(overallOutcome).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getOutcomeColor(overallOutcome).withOpacity(0.4),
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
                      color: _getOutcomeColor(overallOutcome),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (mainTraits.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 100),
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
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: primaryColor.withOpacity(.3)),
                  ),
                  child: Text(
                    '$traitName: $actualValue (${actualChance.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
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
            padding: const EdgeInsets.only(left: 100),
            child: Text(
              summary.split('\n').first,
              style: const TextStyle(
                color: Color(0xFF9AA6B2),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildJustificationDetails(
    List traitJustifications,
    Color primaryColor,
  ) {
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
                trait['category'] != 'genetics'
                    ? entry.value
                    : trait['trait'] as String,
                trait['actualValue'] as String,
                (trait['actualChance'] as num).toDouble(),
                trait['mechanism'] as String,
                trait['explanation'] as String,
                trait['wasUnexpected'] as bool? ?? false,
                primaryColor,
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
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 100,
              child: Text(
                '',
                style: TextStyle(
                  color: Color(0xFFB6C0CC),
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
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.orange.withOpacity(.4),
                        ),
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (wasUnexpected) const SizedBox(width: 6),
                  Text(
                    '$value (${percentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mechanism,
                style: const TextStyle(
                  color: Color(0xFFB6C0CC),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                explanation,
                style: const TextStyle(
                  color: Color(0xFF9AA6B2),
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
      return null;
    }
  }

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

  String _getGeneticDescription(String track, String variant) {
    try {
      final geneTrack = GeneticsCatalog.track(track);
      final geneVariant = geneTrack.byId(variant);
      return geneVariant.description;
    } catch (e) {
      return 'Unknown variant';
    }
  }

  String _formatBreedLine(Parentage p) {
    final dt = p.bredAt;
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _buildParentCard(
    ParentSnapshot snap,
    String parentId,
    Color primaryColor,
  ) {
    final isExpanded = _expandedParents.contains(parentId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              double? currentOffset;
              if (_scrollController.hasClients) {
                currentOffset = _scrollController.offset;
              }

              setState(() {
                if (isExpanded) {
                  _expandedParents.remove(parentId);
                } else {
                  _expandedParents.add(parentId);
                }
              });

              if (currentOffset != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(currentOffset!);
                  }
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snap.name,
                          style: const TextStyle(
                            color: Color(0xFFE8EAED),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snap.types.join(' • '),
                          style: const TextStyle(
                            color: Color(0xFFB6C0CC),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          snap.rarity,
                          style: const TextStyle(
                            color: Color(0xFF9AA6B2),
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
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400.withOpacity(.3),
                                Colors.purple.shade600.withOpacity(.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.purple.withOpacity(.4),
                            ),
                          ),
                          child: const Text(
                            'P',
                            style: TextStyle(
                              color: Colors.purple,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          color: primaryColor.withOpacity(.6),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                children: [
                  Divider(color: primaryColor.withOpacity(.2), height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildParentDataSection('Genetic Profile', [
                          if (snap.genetics?.get('size') != null)
                            _buildDataRow(
                              'Size Variant',
                              sizeLabels[snap.genetics!.get('size')] ??
                                  'Standard',
                            ),
                          if (snap.genetics?.get('tinting') != null)
                            _buildDataRow(
                              'Pigmentation',
                              tintLabels[snap.genetics!.get('tinting')] ??
                                  'Standard',
                            ),
                          if (snap.nature != null)
                            _buildDataRow('Behavior', snap.nature!.id),
                        ], primaryColor),
                        if (snap.genetics != null &&
                            (snap.genetics!.get('size') != null ||
                                snap.genetics!.get('tinting') != null)) ...[
                          const SizedBox(height: 10),
                          _buildParentDataSection('Genetic Contribution', [
                            _buildDataRow(
                              'Traits Passed',
                              '${sizeLabels[snap.genetics!.get('size')] ?? 'Standard'} morphology, ${(tintLabels[snap.genetics!.get('tinting')] ?? 'Standard').toLowerCase()} pigmentation',
                            ),
                          ], primaryColor),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, double value, Color primaryColor) {
    final descriptor = getStatDescriptor(value, label.toLowerCase());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFB6C0CC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    // Stat bar
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (value / 10.0).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: value == 10.0
                                    ? [Colors.amber, Colors.amber.shade600]
                                    : value >= 8.0
                                    ? [Colors.green, Colors.green.shade600]
                                    : value >= 6.0
                                    ? [Colors.blue, Colors.blue.shade600]
                                    : value >= 4.0
                                    ? [
                                        primaryColor,
                                        primaryColor.withOpacity(.7),
                                      ]
                                    : [
                                        Colors.orange.shade700,
                                        Colors.orange.shade800,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Numeric value
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: value == 10.0
                            ? Colors.amber.withOpacity(.2)
                            : primaryColor.withOpacity(.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: value == 10.0
                              ? Colors.amber.withOpacity(.4)
                              : primaryColor.withOpacity(.3),
                        ),
                      ),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          color: value == 10.0 ? Colors.amber : primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 100),
            child: Text(
              descriptor,
              style: TextStyle(
                color: value == 10.0
                    ? Colors.amber.withOpacity(.9)
                    : const Color(0xFF9AA6B2),
                fontSize: 10,
                fontStyle: FontStyle.italic,
                fontWeight: value == 10.0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentDataSection(
    String title,
    List<Widget> children,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: primaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.02),
            borderRadius: BorderRadius.circular(8),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.15)),
            ),
            child: Icon(
              Icons.help_outline_rounded,
              color: Colors.white.withOpacity(.4),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unknown Specimen',
            style: TextStyle(
              color: Color(0xFFE8EAED),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Specimen data unavailable\nContinue research to unlock analysis',
            style: TextStyle(
              color: Color(0xFFB6C0CC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
