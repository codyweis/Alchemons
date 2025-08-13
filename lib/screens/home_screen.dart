import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../models/creature.dart';
import 'breed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _rotationController;
  late AnimationController _sparkleController;

  // Track which creatures to display in the showcase (store creature IDs)
  List<String> _featuredCreatureIds = [];

  @override
  void initState() {
    super.initState();

    // Breathing animation for creatures
    _breathingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Rotation animation for magical elements
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Sparkle animation
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _rotationController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _initializeFeaturedCreatures(
    List<Map<String, dynamic>> discoveredCreatures,
  ) {
    if (_featuredCreatureIds.isEmpty && discoveredCreatures.isNotEmpty) {
      // Initialize with first 3 creatures (or less if fewer available)
      _featuredCreatureIds = discoveredCreatures
          .take(3)
          .map((data) => (data['creature'] as Creature).id)
          .toList();
    }
  }

  void _showCreatureSelector(List<Map<String, dynamic>> availableCreatures) {
    // Create a local copy of the featured creatures for the modal
    List<String> tempFeaturedIds = List.from(_featuredCreatureIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: 500,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade50,
                  Colors.purple.shade50,
                  Colors.pink.shade50,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Choose Your Featured Creatures',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Selected: ${tempFeaturedIds.length}/3',
                          style: TextStyle(
                            color: Colors.purple.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
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
                              // Remove from selection
                              tempFeaturedIds.remove(creature.id);
                            } else {
                              // Add to selection
                              if (tempFeaturedIds.length < 3) {
                                tempFeaturedIds.add(creature.id);
                              } else {
                                // Show feedback when trying to add more than 3
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Maximum 3 creatures can be featured! Remove one first.',
                                    ),
                                    backgroundColor: Colors.orange.shade400,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
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
                            // Always maintain the gradient based on creature type
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _getTypeColor(
                                  creature.types.first,
                                ).withOpacity(0.4),
                                _getTypeColor(
                                  creature.types.first,
                                ).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purple.shade400
                                  : _getTypeColor(
                                      creature.types.first,
                                    ).withOpacity(0.6),
                              width: isSelected ? 3 : 2,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Main creature content
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getTypeColor(
                                            creature.types.first,
                                          ).withOpacity(0.3),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    height: 65,
                                    width: 65,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        'assets/images/creatures/${creature.rarity.toLowerCase()}/${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.png',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.fitHeight,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _getCreatureIcon(
                                                    creature.types.first,
                                                  ),
                                                  color: _getTypeColor(
                                                    creature.types.first,
                                                  ),
                                                  size: 20,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Selection indicator
                              if (isSelected)
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade400,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.purple.shade300,
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),

                              // Selection number indicator
                              if (isSelected)
                                Positioned(
                                  top: 5,
                                  left: 5,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.purple.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${tempFeaturedIds.indexOf(creature.id) + 1}',
                                        style: TextStyle(
                                          color: Colors.purple.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
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
                Container(
                  margin: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Clear all button
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
                                horizontal: 20,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey.shade400,
                                    Colors.grey.shade500,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade300,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Clear All',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),

                      // Done button
                      Expanded(
                        flex: tempFeaturedIds.isNotEmpty ? 1 : 2,
                        child: GestureDetector(
                          onTap: () {
                            // Update the main widget's state when done
                            setState(() {
                              _featuredCreatureIds = List.from(tempFeaturedIds);
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.pink.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.shade300,
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
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
    return Scaffold(
      body: Stack(
        children: [
          // Animated background with parallax effect
          _buildBackgroundLayers(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Enhanced header with animations
                _buildEnhancedHeader(),

                // Main content area with improved layout
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // Featured creatures display with enhanced animations
                          _buildFeaturedCreatures(),

                          const SizedBox(height: 30),

                          // Stats cards
                          _buildStatsCards(),

                          const SizedBox(height: 100), // Space for bottom nav
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating particles/sparkles
          _buildFloatingParticles(),

          // Enhanced bottom navigation
          _buildEnhancedBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayers() {
    return Stack(
      children: [
        // Main background with soft gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade50,
                  Colors.purple.shade50,
                  Colors.pink.shade50,
                ],
              ),
            ),
          ),
        ),

        // Animated overlay for depth
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
                      Colors.purple.withOpacity(
                        0.1 * (_rotationController.value),
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.purple.shade50.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.shade200,
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!kReleaseMode)
              GestureDetector(
                onTap: () {
                  final gameDataService = context.read<GameDataService>();
                  gameDataService.markMultipleDiscovered(['CR046', 'CR006']);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Test creatures unlocked!'),
                      backgroundColor: Colors.purple.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bug_report_rounded,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                ),
              ),

            // Settings button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_rounded,
                color: Colors.purple.shade600,
                size: 20,
              ),
            ),

            // Title
            const Expanded(
              child: Text(
                'Alchemons',
                style: TextStyle(
                  color: Color(0xFF6B46C1),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Level indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.pink.shade400],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.shade300,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Text(
                'LV 8',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCreatures() {
    return Consumer<GameStateNotifier>(
      builder: (context, gameState, child) {
        final discoveredCreatures = gameState.discoveredCreatures;
        _initializeFeaturedCreatures(discoveredCreatures);

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.blue.shade50.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200,
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
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

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_breathingController.value * 0.1),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withOpacity(0.5),
                      Colors.purple.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 40,
                  color: Colors.purple.shade400,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Begin Your Journey!',
          style: TextStyle(
            color: Colors.purple.shade700,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Discover creatures through breeding\nand exploration',
          style: TextStyle(
            color: Colors.purple.shade500,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCreatureShowcase(List<Map<String, dynamic>> creatures) {
    // Get the featured creatures based on selected IDs
    final featuredCreatures = _featuredCreatureIds
        .map(
          (id) => creatures.firstWhere(
            (data) => (data['creature'] as Creature).id == id,
            orElse: () => <String, Object>{},
          ),
        )
        .where((data) => data.isNotEmpty)
        .toList();

    // If we don't have enough featured creatures, fill with first available
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
            Text(
              'Showcase',
              style: TextStyle(
                color: Colors.purple.shade700,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () => _showCreatureSelector(creatures),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.pink.shade300],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
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
            padding: const EdgeInsets.only(top: 20),
            child: GestureDetector(
              onTap: () => _showCreatureSelector(creatures),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.purple.shade300,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  color: Colors.purple.shade50,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.purple.shade400,
                  size: 30,
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
          offset: Offset(0, -5 * _breathingController.value),
          child: GestureDetector(
            onTap: () {
              // Show creature details or navigate to creature details
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.purple.shade50.withOpacity(0.95),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            creature.image,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: glowColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  _getCreatureIcon(creature.types.first),
                                  color: glowColor,
                                  size: 50,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          creature.name,
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          creature.types.first,
                          style: TextStyle(
                            color: glowColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 15),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.pink.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withOpacity(0.3),
                    glowColor.withOpacity(0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.9),
                  border: Border.all(
                    color: glowColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/creatures/${creature.rarity.toLowerCase()}/${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.gif',
                    width: 69,
                    height: 69,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        _getCreatureIcon(creature.types.first),
                        size: 35,
                        color: glowColor,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsCards() {
    return Consumer<GameStateNotifier>(
      builder: (context, gameState, child) {
        final total = gameState.creatures.length;
        final discovered = gameState.discoveredCreatures.length;

        final percent = (total > 0) ? ((discovered / total) * 100).round() : 0;
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Discovered',
                '${gameState.discoveredCreatures.length}',
                '${gameState.creatures.length}',
                Icons.pets_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Collection',
                '$percent%',
                'Complete',
                Icons.bookmark_rounded,
                Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.9), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.purple.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.purple.shade700,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.purple.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _sparkleController,
      builder: (context, child) {
        return Stack(
          children: List.generate(5, (index) {
            final progress = (_sparkleController.value + index * 0.2) % 1.0;
            final x =
                50.0 + (MediaQuery.of(context).size.width - 100) * progress;
            final y = 100.0 + 200 * (index / 5);

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: (1.0 - progress) * 0.6,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple.shade300,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.shade300.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildEnhancedBottomNav() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.purple.shade50.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.shade200,
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem('Breed', Icons.science_rounded, 0),
            _buildNavItem('Creatures', Icons.pets_rounded, 1),
            _buildNavItem('Shop', Icons.store_rounded, 2),
            _buildNavItem('Explore', Icons.explore_rounded, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(String label, IconData icon, int index) {
    return GestureDetector(
      onTap: () {
        // Navigate to different screens
        switch (index) {
          case 0:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BreedScreen()),
            );
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreaturesScreen()),
            );
            break;
          case 2:
            print('Navigate to Shop');
            break;
          case 3:
            print('Navigate to Wilderness');
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.purple.shade600, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.purple.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
      case 'Storm':
        return Colors.indigo.shade400;
      case 'Magma':
        return Colors.red.shade600;
      case 'Poison':
        return Colors.green.shade600;
      case 'Spirit':
        return Colors.teal.shade400;
      case 'Shadow':
        return Colors.grey.shade700;
      case 'Light':
        return Colors.yellow.shade300;
      case 'Blood':
        return Colors.red.shade700;
      case 'Dream':
        return Colors.purple.shade200;
      case 'Arcane':
        return Colors.purple.shade400;
      case 'Chaos':
        return Colors.red.shade300;
      case 'Time':
        return Colors.blue.shade300;
      case 'Void':
        return Colors.grey.shade800;
      case 'Ascended':
        return Colors.amber.shade400;
      default:
        return Colors.purple.shade400;
    }
  }
}
