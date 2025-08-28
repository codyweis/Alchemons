import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/feeding_screen.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/test/dev_seeder.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../models/creature.dart';
import 'breed/breed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _rotationController;

  List<String> _featuredCreatureIds = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeApp();
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize creature repository
      await _initializeRepository();

      // Handle faction selection
      final factionSvc = context.read<FactionService>();
      final picked = await factionSvc.loadId();

      if (!mounted) return;

      if (picked == null) {
        final selected = await showDialog<FactionId>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const FactionPickerDialog(),
        );
        if (selected != null) {
          await factionSvc.setId(selected);
          if (!mounted) return;
        }
        await factionSvc.ensureAirExtraSlotUnlocked();
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error during app initialization: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize app: $e'),
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _initializeRepository() async {
    try {
      final repository = context.read<CreatureRepository>();
      await repository.loadCreatures();
    } catch (e) {
      print('Error loading creature repository: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load specimen database: $e'),
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _initializeFeaturedCreatures(
    List<Map<String, dynamic>> discoveredCreatures,
  ) {
    if (_featuredCreatureIds.isEmpty && discoveredCreatures.isNotEmpty) {
      _featuredCreatureIds = discoveredCreatures
          .take(3)
          .map((data) => (data['creature'] as Creature).id)
          .toList();
    }
  }

  void _showCreatureSelector(List<Map<String, dynamic>> availableCreatures) {
    List<String> tempFeaturedIds = List.from(_featuredCreatureIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: 500,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.indigo.shade200, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.science_rounded,
                            color: Colors.indigo.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Configure Display Specimens',
                            style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          'Selected: ${tempFeaturedIds.length}/3',
                          style: TextStyle(
                            color: Colors.indigo.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: availableCreatures.length,
                    itemBuilder: (context, index) {
                      final creatureData = availableCreatures[index];
                      final creature = creatureData['creature'] as Creature;
                      final isSelected = tempFeaturedIds.contains(creature.id);

                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              tempFeaturedIds.remove(creature.id);
                            } else {
                              if (tempFeaturedIds.length < 3) {
                                tempFeaturedIds.add(creature.id);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Maximum 3 specimens allowed. Remove one first.',
                                    ),
                                    backgroundColor: Colors.orange.shade600,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.indigo.shade600
                                  : _getTypeColor(
                                      creature.types.first,
                                    ).withOpacity(0.5),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? Colors.indigo.shade200
                                    : _getTypeColor(
                                        creature.types.first,
                                      ).withOpacity(0.1),
                                blurRadius: isSelected ? 6 : 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 50,
                                    width: 100,
                                    decoration: BoxDecoration(
                                      color: _getTypeColor(
                                        creature.types.first,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        'assets/images/${creature.image}',
                                        fit: BoxFit.fitWidth,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Icon(
                                                _getCreatureIcon(
                                                  creature.types.first,
                                                ),
                                                color: _getTypeColor(
                                                  creature.types.first,
                                                ),
                                                size: 20,
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    creature.name,
                                    style: TextStyle(
                                      color: Colors.indigo.shade700,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              if (isSelected) ...[
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 3,
                                  left: 3,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.indigo.shade600,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${tempFeaturedIds.indexOf(creature.id) + 1}',
                                        style: TextStyle(
                                          color: Colors.indigo.shade700,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (tempFeaturedIds.isNotEmpty)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                tempFeaturedIds.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Clear All',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        flex: tempFeaturedIds.isNotEmpty ? 1 : 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _featuredCreatureIds = List.from(tempFeaturedIds);
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Apply Changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameStateNotifier, CatalogData?>(
      builder: (context, gameState, catalogData, child) {
        // Show loading if catalog or app isn't initialized
        if (catalogData == null ||
            !catalogData.isFullyLoaded ||
            !_isInitialized) {
          return _buildLoadingScreen('Initializing research facility...');
        }

        if (gameState.isLoading) {
          return _buildLoadingScreen('Loading specimen database...');
        }

        if (gameState.error != null) {
          return _buildErrorScreen(gameState.error!, gameState.refresh);
        }

        return Scaffold(
          body: Stack(
            children: [
              _buildBackgroundLayers(),
              SafeArea(
                child: Column(
                  children: [
                    _buildEnhancedHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildFeaturedCreatures(),
                              const SizedBox(height: 20),
                              _buildNavigationBubbles(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.shade100,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.indigo.shade600,
                  ),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error, VoidCallback onRetry) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade100,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade500,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'System Error Detected',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Retry Connection',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... rest of your existing methods remain the same ...
  // (I'm keeping the rest of the methods unchanged to avoid repetition)

  Widget _buildBackgroundLayers() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade50,
                  Colors.indigo.shade50,
                  Colors.purple.shade50,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.5,
                    colors: [
                      Colors.indigo.withOpacity(
                        0.05 * (_rotationController.value),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!kReleaseMode)
            GestureDetector(
              onTap: () {
                final db = context.read<AlchemonsDatabase>();
                DevSeeder(db).createTwoTestEggs();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Test specimens initialized'),
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.bug_report_rounded,
                  color: Colors.red.shade600,
                  size: 16,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.settings_rounded,
              color: Colors.indigo.shade600,
              size: 16,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () async {
              final selected = await showDialog<FactionId>(
                context: context,
                builder: (_) => const FactionPickerDialog(),
              );
              if (selected != null) {
                await context.read<FactionService>().setId(selected);
                if (mounted) setState(() {});
              }
            },
            child: Builder(
              builder: (context) {
                final svc = context.read<FactionService>();
                final f = svc.current;
                if (f == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _factionChip(f),
                );
              },
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alchemons',
                  style: TextStyle(
                    color: Colors.indigo.shade800,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Advanced biological research facility',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCreatures() {
    return Consumer<GameStateNotifier>(
      builder: (context, gameState, child) {
        final discoveredCreatures = gameState.discoveredCreatures;
        _initializeFeaturedCreatures(discoveredCreatures);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade200, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.shade100,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: discoveredCreatures.isEmpty
              ? _buildEmptyState()
              : _buildCreatureShowcase(discoveredCreatures),
        );
      },
    );
  }

  Widget _factionChip(FactionId f) {
    IconData icon;
    Color color;
    switch (f) {
      case FactionId.fire:
        icon = Icons.local_fire_department_rounded;
        color = Colors.red;
        break;
      case FactionId.water:
        icon = Icons.water_drop_rounded;
        color = Colors.blue;
        break;
      case FactionId.air:
        icon = Icons.air_rounded;
        color = Colors.cyan;
        break;
      case FactionId.earth:
        icon = Icons.terrain_rounded;
        color = Colors.brown;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            // Capitalize nicely
            f.name[0].toUpperCase() + f.name.substring(1),
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_breathingController.value * 0.05),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade200, width: 2),
                ),
                child: Icon(
                  Icons.science_rounded,
                  size: 28,
                  color: Colors.indigo.shade600,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Research Laboratory Active',
          style: TextStyle(
            color: Colors.indigo.shade700,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Begin specimen collection through\ngenetic synthesis and field research',
          style: TextStyle(
            color: Colors.indigo.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCreatureShowcase(List<Map<String, dynamic>> creatures) {
    final featuredCreatures = _featuredCreatureIds
        .map(
          (id) => creatures.firstWhere(
            (data) => (data['creature'] as Creature).id == id,
            orElse: () => <String, Object>{},
          ),
        )
        .where((data) => data.isNotEmpty)
        .toList();

    while (featuredCreatures.length < 3 &&
        featuredCreatures.length < creatures.length) {
      final nextCreature = creatures.firstWhere(
        (data) =>
            !_featuredCreatureIds.contains((data['creature'] as Creature).id),
        orElse: () => <String, Object>{},
      );
      if (nextCreature.isNotEmpty) {
        featuredCreatures.add(nextCreature);
        _featuredCreatureIds.add((nextCreature['creature'] as Creature).id);
      } else {
        break;
      }
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.view_module_rounded,
                  color: Colors.indigo.shade600,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Active Specimens',
                  style: TextStyle(
                    color: Colors.indigo.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showCreatureSelector(creatures),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Configure',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: featuredCreatures.asMap().entries.map((entry) {
            final index = entry.key;
            final creatureData = entry.value;
            final creature = creatureData['creature'] as Creature;

            return _buildEnhancedCreatureSlot(
              creature,
              _getTypeColor(creature.types.first),
              index * 0.5,
            );
          }).toList(),
        ),
        if (featuredCreatures.length < 3)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: GestureDetector(
              onTap: () => _showCreatureSelector(creatures),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.indigo.shade300,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  color: Colors.indigo.shade50,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.indigo.shade600,
                  size: 24,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEnhancedCreatureSlot(
    Creature creature,
    Color glowColor,
    double delay,
  ) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -2 * _breathingController.value),
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.indigo.shade200,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.shade200,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 160,
                            height: 160,
                            child: creature.spriteData != null
                                ? CreatureSprite(
                                    spritePath:
                                        creature.spriteData!.spriteSheetPath,
                                    totalFrames:
                                        creature.spriteData!.totalFrames,
                                    frameSize: Vector2(
                                      creature.spriteData!.frameWidth * 1.0,
                                      creature.spriteData!.frameHeight * 1.0,
                                    ),
                                    rows: creature.spriteData!.rows,
                                    stepTime:
                                        (creature.spriteData!.frameDurationMs /
                                        1000.0),
                                  )
                                : Container(
                                    color: glowColor.withOpacity(0.1),
                                    child: Icon(
                                      _getCreatureIcon(creature.types.first),
                                      color: glowColor,
                                      size: 40,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          creature.name,
                          style: TextStyle(
                            color: Colors.indigo.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: glowColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: glowColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            creature.types.first,
                            style: TextStyle(
                              color: glowColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: glowColor.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: creature.spriteData != null
                    ? CreatureSprite(
                        spritePath: creature.spriteData!.spriteSheetPath,
                        rows: creature.spriteData!.rows,
                        totalFrames: creature.spriteData!.totalFrames,
                        frameSize: Vector2(
                          creature.spriteData!.frameWidth * 1.0,
                          creature.spriteData!.frameHeight * 1.0,
                        ),
                        stepTime:
                            (creature.spriteData!.frameDurationMs / 1000.0),
                      )
                    : Icon(
                        _getCreatureIcon(creature.types.first),
                        size: 28,
                        color: glowColor,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationBubbles() {
    return Consumer<GameStateNotifier>(
      builder: (context, gameState, child) {
        final total = gameState.creatures.length;
        final collectionPercent = (total > 0)
            ? ((gameState.discoveredCreatures.length / total) * 100).round()
            : 0;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavigationBubble(
                  'Database',
                  Icons.storage_rounded,
                  Colors.blue.shade600,
                  '$collectionPercent%',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreaturesScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationBubble(
                  'Breed',
                  Icons.merge_type_rounded,
                  Colors.purple.shade600,
                  'Lab',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BreedScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationBubble(
                  'Enhancement',
                  Icons.science_outlined,
                  Colors.teal.shade600,
                  'Lab',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeedingScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavigationBubble(
                  'Resources',
                  Icons.inventory_rounded,
                  Colors.green.shade600,
                  'Store',
                  () {
                    print('Navigate to Resources');
                  },
                ),
                _buildNavigationBubble(
                  'Field Work',
                  Icons.explore_rounded,
                  Colors.orange.shade600,
                  'Explore',
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    );
                  },
                ),
                _buildNavigationBubble(
                  'Profile',
                  Icons.person_rounded,
                  Colors.indigo.shade600,
                  'Data',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationBubble(
    String title,
    IconData icon,
    Color color,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              Text(
                subtitle,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getCreatureIcon(String type) {
    switch (type) {
      case 'Fire':
        return Icons.local_fire_department_rounded;
      case 'Water':
        return Icons.water_drop_rounded;
      case 'Earth':
        return Icons.terrain_rounded;
      case 'Air':
        return Icons.air_rounded;
      case 'Steam':
        return Icons.cloud_rounded;
      case 'Lava':
        return Icons.volcano_rounded;
      case 'Lightning':
        return Icons.flash_on_rounded;
      case 'Mud':
        return Icons.layers_rounded;
      case 'Ice':
        return Icons.ac_unit_rounded;
      case 'Dust':
        return Icons.grain_rounded;
      case 'Crystal':
        return Icons.diamond_rounded;
      case 'Plant':
        return Icons.eco_rounded;
      case 'Storm':
        return Icons.thunderstorm_rounded;
      case 'Magma':
        return Icons.whatshot_rounded;
      case 'Poison':
        return Icons.dangerous_rounded;
      case 'Spirit':
        return Icons.auto_awesome_rounded;
      case 'Shadow':
        return Icons.nights_stay_rounded;
      case 'Light':
        return Icons.wb_sunny_rounded;
      case 'Blood':
        return Icons.bloodtype_rounded;
      case 'Dream':
        return Icons.bedtime_rounded;
      case 'Arcane':
        return Icons.auto_fix_high_rounded;
      case 'Chaos':
        return Icons.scatter_plot_rounded;
      case 'Time':
        return Icons.schedule_rounded;
      case 'Void':
        return Icons.blur_circular_rounded;
      case 'Ascended':
        return Icons.star_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Fire':
        return Colors.red.shade400;
      case 'Water':
        return Colors.blue.shade400;
      case 'Earth':
        return Colors.brown.shade400;
      case 'Air':
        return Colors.cyan.shade400;
      case 'Steam':
        return Colors.grey.shade400;
      case 'Lava':
        return Colors.deepOrange.shade400;
      case 'Lightning':
        return Colors.yellow.shade600;
      case 'Mud':
        return Colors.brown.shade300;
      case 'Ice':
        return Colors.lightBlue.shade400;
      case 'Dust':
        return Colors.brown.shade200;
      case 'Crystal':
        return Colors.purple.shade300;
      case 'Plant':
        return Colors.green.shade400;
      case 'Poison':
        return Colors.green.shade600;
      case 'Spirit':
        return Colors.teal.shade400;
      case 'Dark':
        return Colors.grey.shade700;
      case 'Light':
        return Colors.yellow.shade300;
      case 'Blood':
        return Colors.red.shade700;
      default:
        return Colors.purple.shade400;
    }
  }
}
