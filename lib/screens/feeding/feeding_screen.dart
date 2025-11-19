import 'package:alchemons/screens/feeding/feeding_stages.dart';
import 'package:alchemons/screens/feeding/feeding_widgets.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/widgets/tutorial_step.dart';

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

  // Tutorial state
  bool _feedingTutorialChecked = false;

  // Search state (species stage)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final ScrollController _speciesScrollCtrl;

  bool _showAllInstances = false;

  @override
  void initState() {
    super.initState();
    _speciesScrollCtrl = ScrollController();

    // Check first-time tutorial after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowFeedingTutorial();
    });
  }

  Future<void> _maybeShowFeedingTutorial() async {
    if (_feedingTutorialChecked) return;
    _feedingTutorialChecked = true;

    if (!mounted) return;

    final db = context.read<AlchemonsDatabase>();
    final settings = db.settingsDao;
    final hasSeen = await settings.hasSeenFeedingTutorial();
    if (hasSeen || !mounted) return;

    final theme = context.read<FactionTheme>();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Text(
                'Enhancement Basics',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This screen lets you power up your creatures by consuming others of the same species.',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TutorialStep(
                theme: theme,
                icon: Icons.pets_rounded,
                title: 'Step 1 – Choose Species',
                body: 'Pick which species you want to enhance.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.person_search_rounded,
                title: 'Step 2 – Choose Specimen',
                body:
                    'Select the specific creature that will gain levels and stats.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.local_fire_department_rounded,
                title: 'Step 3 – Select Fodder',
                body:
                    'Choose other specimens of the same species to consume. '
                    'They will be permanently lost in exchange for XP and stat growth.',
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: You can long-press a specimen to inspect its details before using it as fodder.',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: Text(
                'Got it',
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (mounted) {
      await settings.setFeedingTutorialSeen();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speciesScrollCtrl.dispose();
    super.dispose();
  }

  String get _currentStage {
    if (_showAllInstances) return 'all_instances';
    if (_isPickingSpecies) return 'species';
    if (_isPickingInstance) return 'instance';
    return 'fodder';
  }

  bool get _isPickingSpecies => _targetSpeciesId == null;
  bool get _isPickingInstance =>
      _targetSpeciesId != null && _targetInstanceId == null;
  bool get _isPickingFodder =>
      _targetSpeciesId != null && _targetInstanceId != null;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _currentStage == 'species'
          ? FloatingCloseButton(
              size: 50,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).maybePop();
              },
              theme: theme,
            )
          : null,
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
                  StageHeader(
                    theme: theme,
                    stage: _currentStage,
                    selectedCount: _selectedFodder.length,
                    onBack: _handleBack,
                    onOpenAllInstances: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _showAllInstances = true;
                        _targetSpeciesId = null;
                        _targetInstanceId = null;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<List<CreatureInstance>>(
                      stream: db.creatureDao.watchAllInstances(),
                      builder: (context, snap) {
                        final instances = snap.data ?? [];
                        return _buildStageContent(theme, instances);
                      },
                    ),
                  ),
                  if (_isPickingFodder)
                    StreamBuilder<CreatureInstance?>(
                      stream: context
                          .read<AlchemonsDatabase>()
                          .creatureDao
                          .watchInstanceById(_targetInstanceId!),
                      builder: (context, snapshot) {
                        final targetInstance = snapshot.data;
                        final repo = context.read<CreatureCatalog>();
                        final targetCreature = targetInstance == null
                            ? null
                            : repo.getCreatureById(targetInstance.baseId);

                        return FeedFooter(
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
        ],
      ),
    );
  }

  Widget _buildStageContent(
    FactionTheme theme,
    List<CreatureInstance> instances,
  ) {
    final repo = context.read<CreatureCatalog>();
    final stageBuilders = FeedingStageBuilders(
      context: context,
      searchController: _searchController,
      searchQuery: _searchQuery,
      speciesScrollController: _speciesScrollCtrl,
      onSearchQueryChanged: (query) => setState(() => _searchQuery = query),
      onSpeciesSelected: (speciesId) {
        setState(() {
          _targetSpeciesId = speciesId;
          _targetInstanceId = null;
          _selectedFodder.clear();
          _preview = null;
          _searchController.clear();
          _searchQuery = '';
        });
      },
      onInstanceSelected: (instanceId) {
        setState(() {
          _targetInstanceId = instanceId;
          _selectedFodder.clear();
          _preview = null;
        });
      },
      onAllInstancesInstanceSelected: (inst) {
        setState(() {
          _showAllInstances = false;
          _targetSpeciesId = inst.baseId;
          _targetInstanceId = inst.instanceId;
          _selectedFodder.clear();
          _preview = null;
        });
      },
      onFodderToggle: _toggleFodder,
      targetSpeciesId: _targetSpeciesId,
      targetInstanceId: _targetInstanceId,
      selectedFodder: _selectedFodder,
    );

    if (_showAllInstances) {
      return stageBuilders.buildAllInstancesStage(theme, instances, repo);
    }

    if (_isPickingSpecies) {
      return stageBuilders.buildSpeciesStage(theme, instances, repo);
    }

    if (_isPickingInstance) {
      return stageBuilders.buildInstanceStage(theme, repo);
    }

    return stageBuilders.buildFodderStage(theme, instances, repo);
  }

  void _handleBack() {
    setState(() {
      if (_showAllInstances) {
        _showAllInstances = false;
        _searchController.clear();
        _searchQuery = '';
      } else if (_isPickingFodder) {
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
      final repo = context.read<CreatureCatalog>();
      final feedService = CreatureInstanceService(db);
      final constellationEffects = context.read<ConstellationEffectsService>();

      final result = await feedService.previewFeed(
        targetInstanceId: _targetInstanceId!,
        fodderInstanceIds: _selectedFodder.toList(),
        repo: repo,
        constellationEffects: constellationEffects,
        maxLevel: 10,
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

    final db = context.read<AlchemonsDatabase>();
    final currentInstance = await db.creatureDao.getInstance(
      _targetInstanceId!,
    );
    final preFeedLevel = currentInstance?.level ?? 0;
    final preFeedXp = currentInstance?.xp ?? 0;

    try {
      final repo = context.read<CreatureCatalog>();
      final feedService = CreatureInstanceService(db);
      final constellationEffects = context.read<ConstellationEffectsService>();

      final result = await feedService.feedInstances(
        targetInstanceId: _targetInstanceId!,
        fodderInstanceIds: _selectedFodder.toList(),
        repo: repo,
        constellationEffects: constellationEffects,
        maxLevel: 10,
        strictSpecies: true,
      );
      if (!mounted) return;

      if (result.ok) {
        setState(() {
          _preFeedLevel = preFeedLevel;
          _preFeedXp = preFeedXp;
          _shouldAnimateEnhancement = true;
        });

        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;

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
