import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/creature.dart';
import '../providers/app_providers.dart';
import '../services/breeding_engine.dart';
import '../services/creature_repository.dart';
import '../services/game_data_service.dart';

class BreedScreen extends StatefulWidget {
  const BreedScreen({super.key});

  @override
  State<BreedScreen> createState() => _BreedScreenState();
}

class _BreedScreenState extends State<BreedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selected creatures for breeding
  String? selectedCreature1;
  String? selectedCreature2;

  // Mock incubator data
  final List<Map<String, dynamic>> incubatorSlots = [
    {'id': 0, 'creature': null, 'timeRemaining': 0, 'unlocked': true},
    {'id': 1, 'creature': null, 'timeRemaining': 0, 'unlocked': true},
    {'id': 2, 'creature': null, 'timeRemaining': 0, 'unlocked': false},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize repository loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRepository();
    });
  }

  Future<void> _initializeRepository() async {
    try {
      final repository = context.read<CreatureRepository>();
      await repository.loadCreatures();
    } catch (e) {
      print('Error loading creature repository: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load creatures: $e'),
            backgroundColor: Colors.pink.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameStateNotifier>(
      builder: (context, gameState, child) {
        if (gameState.isLoading) {
          return Scaffold(
            body: Container(
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.shade200,
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.purple.shade300,
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading magical creatures...',
                      style: TextStyle(
                        color: Colors.purple.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (gameState.error != null) {
          return Scaffold(
            body: Container(
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
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.shade200,
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sentiment_dissatisfied_rounded,
                          color: Colors.pink.shade400,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Oops! Something went wrong',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        gameState.error!,
                        style: TextStyle(
                          color: Colors.purple.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => gameState.refresh(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade300,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 5,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Container(
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
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBreedingTab(gameState.discoveredCreatures),
                        _buildIncubatorTab(),
                      ],
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

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
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
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'Creature Lab',
                style: TextStyle(
                  color: Color(0xFF6B46C1),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade300, Colors.pink.shade300],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.purple.shade400,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        tabs: const [
          Tab(
            icon: Icon(Icons.favorite_rounded, size: 20),
            text: 'Breed',
            height: 50,
          ),
          Tab(
            icon: Icon(Icons.egg_rounded, size: 20),
            text: 'Nursery',
            height: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildBreedingTab(List<Map<String, dynamic>> discoveredCreatures) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBreedingSlots(discoveredCreatures),
          const SizedBox(height: 20),
          _buildBreedButton(),
        ],
      ),
    );
  }

  Widget _buildBreedingSlots(List<Map<String, dynamic>> availableCreatures) {
    return Container(
      padding: const EdgeInsets.all(25),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Breeding',
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildBreedingSlot(
                selectedCreature1,
                'Parent 1',
                () => _showCreatureSelection(1, availableCreatures),
                availableCreatures,
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.pink.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: Colors.pink.shade400,
                  size: 20,
                ),
              ),
              _buildBreedingSlot(
                selectedCreature2,
                'Parent 2',
                () => _showCreatureSelection(2, availableCreatures),
                availableCreatures,
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.purple.shade400,
                  size: 20,
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade100, Colors.pink.shade100],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade300, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.purple.shade400,
                      size: 30,
                    ),
                    Text(
                      '???',
                      style: TextStyle(
                        color: Colors.purple.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreedingSlot(
    String? creatureId,
    String placeholder,
    VoidCallback onTap,
    List<Map<String, dynamic>> availableCreatures,
  ) {
    Creature? creature;

    if (creatureId != null) {
      final creatureData = availableCreatures.firstWhere(
        (c) => c['creature'].id == creatureId,
        orElse: () => <String, Object>{},
      );
      if (creatureData.isNotEmpty) {
        creature = creatureData['creature'] as Creature;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: creature != null
              ? LinearGradient(
                  colors: [
                    _getTypeColor(creature.types.first).withOpacity(0.3),
                    _getTypeColor(creature.types.first).withOpacity(0.1),
                  ],
                )
              : LinearGradient(
                  colors: [Colors.grey.shade200, Colors.grey.shade100],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: creature != null
                ? _getTypeColor(creature.types.first).withOpacity(0.8)
                : Colors.grey.shade400,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: creature != null
                  ? _getTypeColor(creature.types.first).withOpacity(0.3)
                  : Colors.grey.shade300,
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: creature != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTypeIcon(creature.types.first),
                      color: _getTypeColor(creature.types.first),
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    creature.name,
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.grey.shade500,
                    size: 30,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    placeholder,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBreedButton() {
    final canBreed = selectedCreature1 != null && selectedCreature2 != null;

    return GestureDetector(
      onTap: canBreed ? _performBreeding : null,
      child: Container(
        width: 220,
        height: 55,
        decoration: BoxDecoration(
          gradient: canBreed
              ? LinearGradient(
                  colors: [Colors.purple.shade400, Colors.pink.shade400],
                )
              : null,
          color: canBreed ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(30),
          boxShadow: canBreed
              ? [
                  BoxShadow(
                    color: Colors.purple.shade300,
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: canBreed ? Colors.white : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'CREATE MAGIC',
                style: TextStyle(
                  color: canBreed ? Colors.white : Colors.grey.shade500,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncubatorTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.orange.shade50.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.shade200,
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.egg_rounded,
                    color: Colors.orange.shade600,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🥚 Creature Nursery 🥚',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Where little ones come to life',
                        style: TextStyle(
                          color: Colors.purple.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...incubatorSlots.map((slot) => _buildIncubatorSlot(slot)),
        ],
      ),
    );
  }

  Widget _buildIncubatorSlot(Map<String, dynamic> slot) {
    final isUnlocked = slot['unlocked'];
    final hasCreature = slot['creature'] != null;
    final slotIndex = slot['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            isUnlocked
                ? Colors.green.shade50.withOpacity(0.9)
                : Colors.grey.shade50.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? Colors.green.shade300 : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnlocked ? Colors.green.shade200 : Colors.grey.shade200,
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: hasCreature
                  ? LinearGradient(
                      colors: [Colors.purple.shade200, Colors.pink.shade200],
                    )
                  : isUnlocked
                  ? LinearGradient(
                      colors: [Colors.green.shade200, Colors.green.shade100],
                    )
                  : null,
              color: !isUnlocked ? Colors.grey.shade200 : null,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: hasCreature
                    ? Colors.purple.shade400
                    : isUnlocked
                    ? Colors.green.shade400
                    : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                hasCreature
                    ? Icons.egg_rounded
                    : isUnlocked
                    ? Icons.egg_alt_rounded
                    : Icons.lock_rounded,
                color: hasCreature
                    ? Colors.purple.shade600
                    : isUnlocked
                    ? Colors.green.shade600
                    : Colors.grey.shade600,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUnlocked
                      ? hasCreature
                            ? '✨ Hatching Magic...'
                            : '🌸 Ready to Nurture'
                      : '🔒 Locked Nest',
                  style: TextStyle(
                    color: isUnlocked
                        ? Colors.purple.shade700
                        : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUnlocked
                      ? hasCreature
                            ? '⏰ 2h 30m remaining'
                            : 'Perfect for new arrivals'
                      : 'Unlock at level ${10 + slotIndex * 5}',
                  style: TextStyle(
                    color: isUnlocked
                        ? Colors.purple.shade500
                        : Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (hasCreature)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade300],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade300,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Collect',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else if (!isUnlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade300, Colors.pink.shade300],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.shade300,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_open_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Unlock',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  void _showCreatureSelection(
    int slotNumber,
    List<Map<String, dynamic>> discoveredCreatures,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for taller content
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Use a fraction of the screen height
        return DraggableScrollableSheet(
          initialChildSize: 0.7, // Start at 70% of screen height
          minChildSize: 0.4, // Can be dragged down to 40%
          maxChildSize: 0.9, // Can be dragged up to 90%
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return _CreatureSelectionSheet(
              scrollController: scrollController,
              discoveredCreatures: discoveredCreatures,
              onSelectCreature: (creatureId) {
                _selectCreature(creatureId, slotNumber);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _selectCreature(String creatureId, int slotNumber) {
    setState(() {
      // Prevent selecting the same creature for both slots
      if (slotNumber == 1) {
        if (creatureId != selectedCreature2) {
          selectedCreature1 = creatureId;
        }
      } else if (slotNumber == 2) {
        if (creatureId != selectedCreature1) {
          selectedCreature2 = creatureId;
        }
      } else {
        // Default behavior for the main grid selection
        if (selectedCreature1 == null) {
          selectedCreature1 = creatureId;
        } else if (selectedCreature2 == null &&
            creatureId != selectedCreature1) {
          selectedCreature2 = creatureId;
        } else {
          selectedCreature1 = creatureId;
          selectedCreature2 = null;
        }
      }
    });
  }

  void _performBreeding() async {
    if (selectedCreature1 != null && selectedCreature2 != null) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Container(
            color: Colors.purple.shade50.withOpacity(0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.shade200,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.purple.shade300,
                      ),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '✨ Creating Magic... ✨',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final breedingEngine = context.read<BreedingEngine>();
        final gameDataService = context.read<GameDataService>();
        final gameState = context.read<GameStateNotifier>();

        final breedingResult = breedingEngine.breed(
          selectedCreature1!,
          selectedCreature2!,
        );

        Navigator.of(context).pop();

        if (breedingResult.success && breedingResult.creature != null) {
          await gameDataService.markDiscovered(breedingResult.creature!.id);

          // Also mark variant as discovered if one was unlocked
          if (breedingResult.variantUnlocked != null) {
            await gameDataService.markDiscovered(
              breedingResult.variantUnlocked!.id,
            );
          }

          await gameState.refresh();
          _showBreedingResult(
            breedingResult.creature!,
            breedingResult.variantUnlocked,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied_rounded,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Text('These creatures aren\'t compatible yet!'),
                ],
              ),
              backgroundColor: Colors.pink.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        setState(() {
          selectedCreature1 = null;
          selectedCreature2 = null;
        });
      } catch (e) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text('Breeding error: $e'),
              ],
            ),
            backgroundColor: Colors.pink.shade400,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBreedingResult(Creature offspring, Creature? variant) {
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
                color: Colors.purple.shade300,
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                variant != null
                    ? '🎉 Breeding Success + Bonus! 🎉'
                    : '🎉 Breeding Success! 🎉',
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Main creature result
              _buildCreatureDisplay(offspring),

              // Variant bonus if unlocked
              if (variant != null) ...[
                const SizedBox(height: 20),
                Text(
                  '✨ Bonus Variant Unlocked! ✨',
                  style: TextStyle(
                    color: Colors.amber.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                _buildCreatureDisplay(variant),
              ],

              const SizedBox(height: 20),
              _buildInfoSection(offspring, variant),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade400, Colors.pink.shade400],
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        variant != null ? 'Incredible!' : 'Amazing!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _buildCreatureDisplay(Creature creature) {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _getTypeColor(creature.types.first).withOpacity(0.3),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          'assets/images/creatures/${creature.rarity.toLowerCase()}/${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.gif',
          fit: BoxFit.fitWidth,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getTypeColor(creature.types.first).withOpacity(0.3),
                    _getTypeColor(creature.types.first).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _getTypeIcon(creature.types.first),
                size: 40,
                color: _getTypeColor(creature.types.first),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoSection(Creature offspring, Creature? variant) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            variant != null
                ? 'You discovered ${offspring.name} and unlocked ${variant.name}!'
                : 'You discovered ${offspring.name}!',
            style: TextStyle(
              color: Colors.purple.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    'Type',
                    style: TextStyle(
                      color: Colors.purple.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    offspring.types.join(', '),
                    style: TextStyle(
                      color: _getTypeColor(offspring.types.first),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 30, color: Colors.purple.shade300),
              Column(
                children: [
                  Text(
                    'Rarity',
                    style: TextStyle(
                      color: Colors.purple.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    offspring.rarity,
                    style: TextStyle(
                      color: _getRarityColor(offspring.rarity),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (variant != null) ...[
                Container(width: 1, height: 30, color: Colors.purple.shade300),
                Column(
                  children: [
                    Text(
                      'Variant',
                      style: TextStyle(
                        color: Colors.purple.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      variant.types.join('-'),
                      style: TextStyle(
                        color: Colors.amber.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade600;
      case 'uncommon':
        return Colors.green.shade500;
      case 'rare':
        return Colors.blue.shade600;
      case 'mythic':
        return Colors.purple.shade600;
      case 'legendary':
        return Colors.orange.shade600;
      case 'ascended':
        return Colors.pink.shade600;
      default:
        return Colors.purple.shade600;
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

  IconData _getTypeIcon(String type) {
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
}

class _CreatureSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> discoveredCreatures;
  final Function(String) onSelectCreature;
  final ScrollController scrollController;

  const _CreatureSelectionSheet({
    required this.discoveredCreatures,
    required this.onSelectCreature,
    required this.scrollController,
  });

  @override
  State<_CreatureSelectionSheet> createState() =>
      _CreatureSelectionSheetState();
}

class _CreatureSelectionSheetState extends State<_CreatureSelectionSheet> {
  String _selectedFilter = 'All';
  String _selectedSort = 'Name';

  // Adjusted filter options for the breeding sheet
  final List<String> _filterOptions = [
    'All',
    'Fire',
    'Water',
    'Earth',
    'Air',
    'Steam',
    'Lava',
    'Lightning',
    'Mud',
    'Ice',
    'Dust',
    'Crystal',
    'Plant',
    'Storm',
    'Magma',
    'Poison',
    'Spirit',
    'Shadow',
    'Light',
    'Blood',
    'Dream',
    'Arcane',
    'Chaos',
    'Time',
    'Void',
    'Ascended',
  ];

  final List<String> _sortOptions = ['Name', 'Rarity', 'Type'];

  @override
  Widget build(BuildContext context) {
    final filteredCreatures = _filterAndSortCreatures(
      widget.discoveredCreatures,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.purple.shade50, Colors.pink.shade50],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        border: Border.all(color: Colors.purple.shade200, width: 2),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Title
          Text(
            'Select a Creature',
            style: TextStyle(
              color: Colors.purple.shade700,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          // Filters
          _buildFiltersAndSort(),
          // Grid
          Expanded(child: _buildCreatureGrid(filteredCreatures)),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSort() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              'Filter',
              _filterOptions,
              _selectedFilter,
              (value) => setState(() => _selectedFilter = value!),
              Icons.filter_list_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDropdown(
              'Sort',
              _sortOptions,
              _selectedSort,
              (value) => setState(() => _selectedSort = value!),
              Icons.sort_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    String selectedValue,
    void Function(String?) onChanged,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.shade200, width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: Icon(icon, color: Colors.purple.shade500, size: 18),
          dropdownColor: Colors.white,
          style: TextStyle(
            color: Colors.purple.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCreatureGrid(List<Map<String, dynamic>> creatures) {
    if (creatures.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: creatures.length,
      itemBuilder: (context, index) => _buildCreatureCard(creatures[index]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Colors.purple.shade300,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No creatures match the filter.',
            style: TextStyle(
              color: Colors.purple.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatureCard(Map<String, dynamic> creatureData) {
    final creature = creatureData['creature'] as Creature;
    final typeColor = _getTypeColor(creature.types.first);

    return GestureDetector(
      onTap: () => widget.onSelectCreature(creature.id),
      child: Container(
        decoration: _buildCardDecoration(typeColor),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCreatureName(creature),
              const SizedBox(height: 8),
              Expanded(child: _buildCreatureDisplay(creature)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatureName(Creature creature) {
    return Text(
      creature.name,
      style: TextStyle(
        color: Colors.purple.shade700,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  BoxDecoration _buildCardDecoration(Color typeColor) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [typeColor.withOpacity(0.2), typeColor.withOpacity(0.1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: typeColor.withOpacity(0.6), width: 2),
      boxShadow: [
        BoxShadow(
          color: typeColor.withOpacity(0.15),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildCreatureDisplay(Creature creature) {
    final typeColor = _getTypeColor(creature.types.first);

    return Container(
      constraints: const BoxConstraints(maxHeight: 100, maxWidth: 100),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.25),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          _getCreatureImagePath(creature),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackDisplay(creature),
        ),
      ),
    );
  }

  String _getCreatureImagePath(Creature creature) {
    return 'assets/images/creatures/${creature.rarity.toLowerCase()}/'
        '${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.png';
  }

  Widget _buildFallbackDisplay(Creature creature) {
    final typeColor = _getTypeColor(creature.types.first);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [typeColor.withOpacity(0.3), typeColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          _getTypeIcon(creature.types.first),
          size: 40,
          color: typeColor,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterAndSortCreatures(
    List<Map<String, dynamic>> creatures,
  ) {
    var filtered = creatures.where((creatureData) {
      final creature = creatureData['creature'] as Creature;
      if (_selectedFilter == 'All') {
        return true;
      }
      return creature.types.contains(_selectedFilter);
    }).toList();

    filtered.sort((a, b) {
      final creatureA = a['creature'] as Creature;
      final creatureB = b['creature'] as Creature;
      switch (_selectedSort) {
        case 'Rarity':
          return _getRarityOrder(
            creatureA.rarity,
          ).compareTo(_getRarityOrder(creatureB.rarity));
        case 'Type':
          return creatureA.types.first.compareTo(creatureB.types.first);
        case 'Name':
        default:
          return creatureA.name.compareTo(creatureB.name);
      }
    });

    return filtered;
  }

  int _getRarityOrder(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 0;
      case 'uncommon':
        return 1;
      case 'rare':
        return 2;
      case 'mythic':
        return 3;
      case 'legendary':
        return 4;
      case 'ascended':
        return 5;
      default:
        return 0;
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade600;
      case 'uncommon':
        return Colors.green.shade500;
      case 'rare':
        return Colors.blue.shade600;
      case 'mythic':
        return Colors.purple.shade600;
      case 'legendary':
        return Colors.orange.shade600;
      case 'ascended':
        return Colors.pink.shade600;
      default:
        return Colors.purple.shade600;
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

  IconData _getTypeIcon(String type) {
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
}
