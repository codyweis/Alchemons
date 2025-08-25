import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
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
                Text(
                  widget.isDiscovered ? c.name : 'Unknown Specimen',
                  style: TextStyle(
                    color: Colors.indigo.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
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
            _buildDataSection('Specimen Status', [_buildStaminaRow()]),
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
          Expanded(
            child: Text(
              value,
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

  Widget _buildAnalysisTab(Creature c) {
    final parentage = c.parentage;

    if (parentage == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
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
                Icons.explore_rounded,
                color: Colors.grey.shade400,
                size: 40,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Acquisition Method',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Specimen acquired through field research',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
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
