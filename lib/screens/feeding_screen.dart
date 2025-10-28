import 'dart:convert';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart' show Vector2;

import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart' hide InstanceSprite;
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/enhancement_display.dart';

class FeedingScreen extends StatefulWidget {
  const FeedingScreen({super.key});

  @override
  State<FeedingScreen> createState() => _FeedingScreenState();
}

class _FeedingScreenState extends State<FeedingScreen>
    with TickerProviderStateMixin {
  // Selection state
  String? _targetSpeciesId;
  String? _targetInstanceId;
  final Set<String> _selectedFodder = {};
  FeedResult? _preview;
  bool _busy = false;
  bool _shouldAnimateEnhancement = false;
  int? _preFeedLevel;
  int? _preFeedXp;

  // Search state (species stage)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final ScrollController _speciesScrollCtrl;

  @override
  void initState() {
    super.initState();
    _speciesScrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speciesScrollCtrl.dispose();
    super.dispose();
  }

  // helper to build species summary list
  List<Map<String, dynamic>> buildSpeciesListData({
    required List<CreatureInstance> instances,
    required CreatureRepository repo,
  }) {
    final countBySpecies = <String, int>{};
    for (final inst in instances) {
      countBySpecies[inst.baseId] = (countBySpecies[inst.baseId] ?? 0) + 1;
    }

    final result = <Map<String, dynamic>>[];
    for (final speciesId in countBySpecies.keys) {
      final creature = repo.getCreatureById(speciesId);
      if (creature == null) continue;
      result.add({'creature': creature, 'count': countBySpecies[speciesId]});
    }
    return result;
  }

  bool get _isPickingSpecies => _targetSpeciesId == null;
  bool get _isPickingInstance =>
      _targetSpeciesId != null && _targetInstanceId == null;
  bool get _isPickingFodder =>
      _targetSpeciesId != null && _targetInstanceId != null;

  String get _currentStage {
    if (_isPickingSpecies) return 'species';
    if (_isPickingInstance) return 'instance';
    return 'fodder';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0),
                radius: 1.2,
                colors: [
                  theme.surface,
                  theme.surface,
                  theme.surfaceAlt.withOpacity(.6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _StageHeader(
                    theme: theme,
                    stage: _currentStage,
                    selectedCount: _selectedFodder.length,
                    onBack: _handleBack,
                  ),
                  const SizedBox(height: 10),

                  // main content
                  Expanded(
                    child: StreamBuilder<List<CreatureInstance>>(
                      stream: db.watchAllInstances(),
                      builder: (context, snap) {
                        final instances = snap.data ?? [];
                        return _buildStageContent(theme, instances);
                      },
                    ),
                  ),

                  // footer only in fodder stage (stage 3)
                  if (_isPickingFodder)
                    StreamBuilder<CreatureInstance?>(
                      stream: context
                          .read<AlchemonsDatabase>()
                          .watchInstanceById(_targetInstanceId!),
                      builder: (context, snapshot) {
                        final targetInstance = snapshot.data;
                        final repo = context.read<CreatureRepository>();
                        final targetCreature = targetInstance == null
                            ? null
                            : repo.getCreatureById(targetInstance.baseId);

                        return _FeedFooter(
                          theme: theme,
                          targetInstance: targetInstance,
                          targetCreature: targetCreature,
                          preview: _preview,
                          busy: _busy,
                          selectedCount: _selectedFodder.length,
                          onEnhance: _doFeed,
                          shouldAnimate: _shouldAnimateEnhancement,
                          preFeedLevel: _preFeedLevel,
                          preFeedXp: _preFeedXp,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // close button
          Positioned(
            right: 10,
            top: 40,
            child: FloatingCloseButton(
              size: 50,
              theme: theme,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).maybePop();
              },
              accentColor: theme.text,
              iconColor: theme.text,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Stage Content Builders ----------

  Widget _buildStageContent(
    FactionTheme theme,
    List<CreatureInstance> instances,
  ) {
    final repo = context.read<CreatureRepository>();

    if (_isPickingSpecies) {
      return _buildSpeciesStage(theme, instances, repo);
    }

    if (_isPickingInstance) {
      return _buildInstanceStage(theme, repo);
    }

    // fodder
    return _buildFodderStage(theme, instances);
  }

  // Stage 1: choose species
  Widget _buildSpeciesStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
    CreatureRepository repo,
  ) {
    final speciesData = buildSpeciesListData(instances: instances, repo: repo);

    // nothing owned
    if (speciesData.isEmpty) {
      return const _NoSpeciesOwnedWrapper();
    }

    // Filter species based on search query
    final filteredSpeciesData = _searchQuery.isEmpty
        ? speciesData
        : speciesData.where((data) {
            final creature = data['creature'] as Creature;
            final name = creature.name.toLowerCase();
            final types = creature.types.join(' ').toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || types.contains(query);
          }).toList();

    return Column(
      children: [
        // search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: theme.border.withOpacity(.5), width: 1),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search species...',
                hintStyle: TextStyle(
                  color: theme.textMuted.withOpacity(.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.textMuted,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: theme.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        // results count if searching
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text(
                  '${filteredSpeciesData.length} result${filteredSpeciesData.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // either empty "no matches" or list of species
        Expanded(
          child: filteredSpeciesData.isEmpty
              ? _NoResultsFound(theme: theme)
              : ListView.builder(
                  controller: _speciesScrollCtrl,
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 24),
                  itemCount: filteredSpeciesData.length,
                  itemBuilder: (context, i) {
                    final creature =
                        filteredSpeciesData[i]['creature'] as Creature;
                    final count = filteredSpeciesData[i]['count'] as int;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _SpeciesRow(
                        theme: theme,
                        creature: creature,
                        count: count,
                        onTap: () {
                          setState(() {
                            _targetSpeciesId = creature.id;
                            _targetInstanceId = null;
                            _selectedFodder.clear();
                            _preview = null;
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Stage 2: choose which specific instance gets fed
  Widget _buildInstanceStage(FactionTheme theme, CreatureRepository repo) {
    final species = repo.getCreatureById(_targetSpeciesId!);
    if (species == null) {
      return Center(
        child: Text('Species missing', style: TextStyle(color: theme.text)),
      );
    }

    // InstancesSheet is assumed to manage its own scrollable layout
    return InstancesSheet(
      species: species,
      theme: theme,
      selectionMode: false,
      initialDetailMode: InstanceDetailMode.stats,
      onTap: (inst) {
        setState(() {
          _targetInstanceId = inst.instanceId;
          _selectedFodder.clear();
          _preview = null;
        });
      },
    );
  }

  // Stage 3: pick fodder to consume
  Widget _buildFodderStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
  ) {
    final repo = context.read<CreatureRepository>();

    final candidates =
        instances
            .where(
              (inst) =>
                  inst.baseId == _targetSpeciesId &&
                  inst.instanceId != _targetInstanceId &&
                  !inst.locked,
            )
            .toList()
          ..sort((a, b) => b.level.compareTo(a.level));

    if (candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No available fodder specimens.\nThey might be locked or already selected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: .8,
      ),
      itemCount: candidates.length,
      itemBuilder: (context, i) {
        final inst = candidates[i];
        final isSelected = _selectedFodder.contains(inst.instanceId);
        final baseCreature = repo.getCreatureById(inst.baseId);

        return GestureDetector(
          onTap: () => _toggleFodder(inst.instanceId),
          onLongPress: baseCreature == null
              ? null
              : () {
                  showQuickInstanceDialog(
                    context: context,
                    theme: theme,
                    creature: baseCreature,
                    instance: inst,
                  );
                },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.green.withOpacity(0.15)
                  : theme.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isSelected ? Colors.green : theme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (baseCreature != null)
                  InstanceSprite(
                    creature: baseCreature,
                    instance: inst,
                    size: 40,
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                const SizedBox(height: 4),
                if (baseCreature != null)
                  Text(
                    baseCreature.name,
                    style: TextStyle(
                      color: isSelected ? Colors.green : theme.text,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                Text(
                  'Lv ${inst.level}',
                  style: TextStyle(
                    color: isSelected ? Colors.green.shade300 : theme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Actions ----------

  void _handleBack() {
    setState(() {
      if (_isPickingFodder) {
        _targetInstanceId = null;
        _selectedFodder.clear();
        _preview = null;
      } else if (_isPickingInstance) {
        _targetSpeciesId = null;
      }
    });
  }

  Future<void> _toggleFodder(String instanceId) async {
    setState(() {
      if (_selectedFodder.contains(instanceId)) {
        _selectedFodder.remove(instanceId);
      } else {
        _selectedFodder.add(instanceId);
      }
    });
    await _updatePreview();
  }

  Future<void> _updatePreview() async {
    if (_selectedFodder.isEmpty || _targetInstanceId == null) {
      setState(() => _preview = null);
      return;
    }

    try {
      final db = context.read<AlchemonsDatabase>();
      final repo = context.read<CreatureRepository>();
      final feedService = CreatureInstanceService(db);

      final result = await feedService.previewFeed(
        targetInstanceId: _targetInstanceId!,
        fodderInstanceIds: _selectedFodder.toList(),
        repo: repo,
        strictSpecies: true,
      );

      setState(() => _preview = result);
    } catch (_) {
      setState(() => _preview = null);
    }
  }

  Future<void> _doFeed() async {
    if (_selectedFodder.isEmpty || _targetInstanceId == null || _busy) return;

    setState(() => _busy = true);

    // capture current stats for animation
    final db = context.read<AlchemonsDatabase>();
    final currentInstance = await db.getInstance(_targetInstanceId!);
    final preFeedLevel = currentInstance?.level ?? 0;
    final preFeedXp = currentInstance?.xp ?? 0;

    try {
      final repo = context.read<CreatureRepository>();
      final factions = context.read<FactionService>();
      final feedService = CreatureInstanceService(db);

      final result = await feedService.feedInstances(
        targetInstanceId: _targetInstanceId!,
        fodderInstanceIds: _selectedFodder.toList(),
        repo: repo,
        factions: factions,
        strictSpecies: true,
      );

      if (!mounted) return;

      if (result.ok) {
        // prep animation
        setState(() {
          _shouldAnimateEnhancement = false;
          _preFeedLevel = preFeedLevel;
          _preFeedXp = preFeedXp;
        });

        // tiny delay so EnhancementDisplay can see false then true
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;

        setState(() {
          _shouldAnimateEnhancement = true;
        });

        // wait animation duration
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;

        // cleanup after feed
        setState(() {
          _selectedFodder.clear();
          _preview = null;
          _shouldAnimateEnhancement = false;
          _preFeedLevel = null;
          _preFeedXp = null;
          _busy = false;
        });
      } else {
        setState(() => _busy = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${result.error}')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ---------- Header ----------

class _StageHeader extends StatelessWidget {
  final FactionTheme theme;
  final String stage;
  final int selectedCount;
  final VoidCallback onBack;

  const _StageHeader({
    required this.theme,
    required this.stage,
    required this.selectedCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = stage != 'species';
    final (title, subtitle) = _getStageText();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          if (canGoBack)
            GestureDetector(
              onTap: onBack,
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
          if (canGoBack) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
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

  (String, String?) _getStageText() {
    switch (stage) {
      case 'species':
        return ('Choose Species', 'Select which species to enhance');
      case 'instance':
        return ('Choose Specimen', 'Select the specimen to strengthen');
      case 'fodder':
        return (
          'Select Fodder',
          selectedCount > 0
              ? '$selectedCount selected'
              : 'Choose specimens to feed',
        );
      default:
        return ('', null);
    }
  }
}

// ---------- Footer ----------

class _FeedFooter extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance? targetInstance;
  final Creature? targetCreature;
  final FeedResult? preview;
  final bool busy;
  final int selectedCount;
  final VoidCallback onEnhance;
  final bool shouldAnimate;
  final int? preFeedLevel;
  final int? preFeedXp;

  const _FeedFooter({
    required this.theme,
    required this.targetInstance,
    required this.targetCreature,
    required this.preview,
    required this.busy,
    required this.selectedCount,
    required this.onEnhance,
    required this.shouldAnimate,
    this.preFeedLevel,
    this.preFeedXp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (targetInstance != null && targetCreature != null) ...[
            EnhancementDisplay(
              theme: theme,
              instance: targetInstance!,
              preview: preview,
              instanceSprite: GestureDetector(
                onLongPress: () {
                  showQuickInstanceDialog(
                    context: context,
                    theme: theme,
                    creature: targetCreature!,
                    instance: targetInstance!,
                  );
                },
                child: InstanceSprite(
                  creature: targetCreature!,
                  instance: targetInstance!,
                  size: 70,
                ),
              ),
              shouldAnimate: shouldAnimate,
              preFeedLevel: preFeedLevel,
              preFeedXp: preFeedXp,
            ),
            const SizedBox(height: 12),
          ],
          _EnhanceButton(
            theme: theme,
            enabled: selectedCount > 0 && !busy,
            busy: busy,
            selectedCount: selectedCount,
            onTap: onEnhance,
          ),
        ],
      ),
    );
  }
}

class _EnhanceButton extends StatefulWidget {
  final FactionTheme theme;
  final bool enabled;
  final bool busy;
  final int selectedCount;
  final VoidCallback onTap;

  const _EnhanceButton({
    required this.theme,
    required this.enabled,
    required this.busy,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  State<_EnhanceButton> createState() => _EnhanceButtonState();
}

class _EnhanceButtonState extends State<_EnhanceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.enabled && !widget.busy;

    return AnimatedBuilder(
      animation: _pressCtrl,
      builder: (context, _) {
        return GestureDetector(
          onTapDown: canTap ? (_) => _pressCtrl.forward() : null,
          onTapUp: canTap ? (_) => _pressCtrl.reverse() : null,
          onTapCancel: canTap ? () => _pressCtrl.reverse() : null,
          onTap: canTap ? widget.onTap : null,
          child: Transform.scale(
            scale: 1.0 - (_pressCtrl.value * 0.05),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canTap ? Colors.green.shade600 : widget.theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: canTap
                      ? Colors.green.shade400
                      : widget.theme.border.withOpacity(.8),
                  width: 1.5,
                ),
                boxShadow: canTap
                    ? [
                        BoxShadow(
                          color: Colors.green.shade400.withOpacity(.4),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(
                      Icons.science_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    widget.busy
                        ? 'Processing...'
                        : 'Begin Enhancement${widget.selectedCount > 0 ? ' (${widget.selectedCount})' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Empty states / helpers ----------

class _NoSpeciesOwnedWrapper extends StatelessWidget {
  const _NoSpeciesOwnedWrapper();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          "You don't own any creatures yet.",
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NoResultsFound extends StatelessWidget {
  final FactionTheme theme;
  const _NoResultsFound({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: theme.textMuted.withOpacity(.3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No species found',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(
              color: theme.textMuted.withOpacity(.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Species Row ----------

class _SpeciesRow extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final int count;
  final VoidCallback onTap;

  const _SpeciesRow({
    required this.theme,
    required this.creature,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 75,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            CreatureImage(c: creature, discovered: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    creature.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    creature.types.join(', '),
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: theme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
