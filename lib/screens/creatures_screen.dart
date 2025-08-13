import 'package:alchemons/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../models/creature.dart';

class CreaturesScreen extends StatefulWidget {
  const CreaturesScreen({super.key});

  @override
  State<CreaturesScreen> createState() => _CreaturesScreenState();
}

class _CreaturesScreenState extends State<CreaturesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  String _selectedFilter = 'All';
  String _selectedSort = 'Name';

  final List<String> _filterOptions = [
    'All',
    'Discovered',
    'Undiscovered',
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

  final List<String> _sortOptions = [
    'Name',
    'Rarity',
    'Type',
    'Discovery Order',
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameStateNotifier>(
      builder: (context, gameState, child) {
        if (gameState.isLoading) {
          return _buildLoadingScreen();
        }

        if (gameState.error != null) {
          return _buildErrorScreen(gameState);
        }

        final filteredCreatures = _filterAndSortCreatures(gameState.creatures);

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

                  _buildFiltersAndSort(),
                  _buildStatsRow(gameState),
                  Expanded(child: _buildCreatureGrid(filteredCreatures)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
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
                'Loading creature collection...',
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

  Widget _buildErrorScreen(GameStateNotifier gameState) {
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
                  style: TextStyle(color: Colors.purple.shade500, fontSize: 14),
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

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
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
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Creature Collection',
                style: TextStyle(
                  color: Color(0xFF6B46C1),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            IconButton(
              color: Colors.amber,
              icon: const Icon(Icons.map_rounded),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
              },
            ),
          ],
        ),
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
              'Filter: $_selectedFilter',
              _filterOptions,
              _selectedFilter,
              (value) => setState(() => _selectedFilter = value!),
              Icons.filter_list_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDropdown(
              'Sort: $_selectedSort',
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color.fromARGB(255, 255, 255, 255).withOpacity(0.9),
            const Color.fromARGB(255, 235, 245, 255).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.shade200, width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
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

  Widget _buildStatsRow(GameStateNotifier gameState) {
    final discovered = gameState.discoveredCreatures.length;
    final total = gameState.creatures.length;
    final percentage = total > 0 ? ((discovered / total) * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.blue.shade50.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200,
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            'Discovered',
            '$discovered',
            Icons.visibility_rounded,
            Colors.green,
          ),
          _buildStatItem('Total', '$total', Icons.pets_rounded, Colors.blue),
          _buildStatItem(
            'Complete',
            '$percentage%',
            Icons.star_rounded,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.purple.shade700,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.purple.shade500,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatureGrid(List<Map<String, dynamic>> creatures) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.85,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        itemCount: creatures.length,
        itemBuilder: (context, index) {
          final creatureData = creatures[index];
          final creature = creatureData['creature'] as Creature;
          final isDiscovered = creatureData['player'].discovered == true;

          return GestureDetector(
            onTap: () => _showCreatureDetails(creature, isDiscovered),
            child: _buildCreatureCard(creature, isDiscovered),
          );
        },
      ),
    );
  }

  Widget _buildCreatureCard(Creature creature, bool isDiscovered) {
    return Consumer<GameStateNotifier>(
      builder: (context, gameState, child) {
        // Get variants for this creature
        final variants = gameState.discoveredCreatures.where((data) {
          final variantCreature = data['creature'] as Creature;
          return variantCreature.rarity == 'Variant' &&
              variantCreature.id.startsWith('${creature.id}_');
        }).toList();

        return Container(
          decoration: BoxDecoration(
            color: isDiscovered
                ? Colors.white.withOpacity(0.95)
                : Colors.grey.shade200.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDiscovered
                  ? _getTypeColor(creature.types.first).withOpacity(0.6)
                  : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none, // Allow overflow for the badge
            children: [
              // Main content column
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Simple creature image (no swiping)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0), // Reduced from 12.0
                      child: isDiscovered
                          ? _buildCreatureImage(creature)
                          : _buildSilhouetteImage(creature),
                    ),
                  ),

                  // Creature name
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ), // Reduced from 8
                    child: Text(
                      isDiscovered ? creature.name : '???',
                      style: TextStyle(
                        color: isDiscovered
                            ? Colors.purple.shade700
                            : Colors.grey.shade600,
                        fontSize: 11, // Slightly smaller from 12
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Rarity indicator
                  Container(
                    margin: const EdgeInsets.only(
                      top: 4,
                      bottom: 8,
                    ), // Reduced margins
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ), // Reduced padding
                    decoration: BoxDecoration(
                      color: isDiscovered
                          ? _getRarityColor(creature.rarity).withOpacity(0.8)
                          : Colors.grey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isDiscovered ? creature.rarity : '???',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7, // Slightly smaller from 8
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              // Variant count indicator positioned at the very edge
              if (variants.isNotEmpty && isDiscovered)
                Positioned(
                  top: -1, // Negative value to push it to the edge
                  right: -1, // Negative value to push it to the edge
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors
                          .amber
                          .shade600, // Solid color instead of gradient
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '+${variants.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreatureImage(Creature creature) {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
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
          'assets/images/creatures/${creature.rarity.toLowerCase()}/${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.png',
          fit: BoxFit.fitHeight,
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

  Widget _buildSilhouetteImage(Creature creature) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
          child: Center(
            child: Icon(
              Icons.help_outline_rounded,
              size: 40,
              color: Colors.grey.shade500,
            ),
          ),
        );
      },
    );
  }

  void _showCreatureDetails(Creature creature, bool isDiscovered) {
    showDialog(
      context: context,
      builder: (context) =>
          CreatureDetailsDialog(creature: creature, isDiscovered: isDiscovered),
    );
  }

  List<Map<String, dynamic>> _filterAndSortCreatures(
    List<Map<String, dynamic>> creatures,
  ) {
    var filtered = creatures.where((creatureData) {
      final creature = creatureData['creature'] as Creature;
      final isDiscovered = creatureData['player'].discovered == true;

      switch (_selectedFilter) {
        case 'All':
          return true;
        case 'Discovered':
          return isDiscovered;
        case 'Undiscovered':
          return !isDiscovered;
        default:
          return creature.types.contains(_selectedFilter);
      }
    }).toList();

    filtered.sort((a, b) {
      final creatureA = a['creature'] as Creature;
      final creatureB = b['creature'] as Creature;

      switch (_selectedSort) {
        case 'Name':
          return creatureA.name.compareTo(creatureB.name);
        case 'Rarity':
          return _getRarityOrder(
            creatureA.rarity,
          ).compareTo(_getRarityOrder(creatureB.rarity));
        case 'Type':
          return creatureA.types.first.compareTo(creatureB.types.first);
        case 'Discovery Order':
          final discoveredA = a['player'].discovered == true;
          final discoveredB = b['player'].discovered == true;
          if (discoveredA && !discoveredB) return -1;
          if (!discoveredA && discoveredB) return 1;
          return creatureA.name.compareTo(creatureB.name);
        default:
          return 0;
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

class CreatureDetailsDialog extends StatefulWidget {
  final Creature creature;
  final bool isDiscovered;

  const CreatureDetailsDialog({
    super.key,
    required this.creature,
    required this.isDiscovered,
  });

  @override
  State<CreatureDetailsDialog> createState() => _CreatureDetailsDialogState();
}

class _CreatureDetailsDialogState extends State<CreatureDetailsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentImageIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.isDiscovered ? 3 : 1,
      vsync: this,
    );
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(10),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 1,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.purple.shade50.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.purple.shade300, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.shade300,
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            _buildDialogHeader(),
            if (widget.isDiscovered) _buildTabBar(),
            Expanded(
              child: widget.isDiscovered
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildStatsTab(),
                        _buildDiscoveryTab(),
                      ],
                    )
                  : _buildUnknownTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.isDiscovered ? widget.creature.name : 'Unknown Creature',
              style: TextStyle(
                color: Colors.purple.shade700,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.purple.shade600,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
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
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.purple.shade400,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.info_rounded, size: 18), text: 'Overview'),
          Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Stats'),
          Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Discovery'),
        ],
      ),
    );
  }

  Widget _buildSwipeableCreatureDisplay(
    List<Map<String, dynamic>> allVersions,
  ) {
    return Column(
      children: [
        // Main swipeable image area
        Container(
          height: 200,
          width: 200,
          child: Stack(
            children: [
              PageView.builder(
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
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getTypeColor(creature.types.first),
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Stack(
                        children: [
                          // Creature image
                          Image.asset(
                            'assets/images/creatures/${creature.rarity.toLowerCase()}/${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.gif',
                            fit: BoxFit.cover,
                            width: 200,
                            height: 200,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getTypeColor(
                                        creature.types.first,
                                      ).withOpacity(0.3),
                                      _getTypeColor(
                                        creature.types.first,
                                      ).withOpacity(0.1),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  _getTypeIcon(creature.types.first),
                                  size: 80,
                                  color: _getTypeColor(creature.types.first),
                                ),
                              );
                            },
                          ),

                          // Variant type indicator
                          if (isVariant)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getTypeColor(creature.types.last),
                                      _getTypeColor(
                                        creature.types.last,
                                      ).withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getTypeIcon(creature.types.last),
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      creature.types.last.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Current creature name and info
        Text(
          allVersions[_currentImageIndex]['creature'].name,
          style: TextStyle(
            color: Colors.purple.shade700,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),

        // Type display
        Text(
          allVersions[_currentImageIndex]['creature'].types.join(' + '),
          style: TextStyle(
            color: _getTypeColor(
              allVersions[_currentImageIndex]['creature'].types.first,
            ),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Page indicators (if more than one version)
        if (allVersions.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              allVersions.length,
              (index) => GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.purple.shade600
                        : Colors.purple.shade300,
                  ),
                ),
              ),
            ),
          ),

        // Swipe instruction (if variants exist)
        if (allVersions.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '← Swipe to see variants →',
              style: TextStyle(
                color: Colors.purple.shade500,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Swipeable creature images (base + variants)
          Consumer<GameStateNotifier>(
            builder: (context, gameState, child) {
              // Get variants for this creature
              final variants = gameState.discoveredCreatures.where((data) {
                final creature = data['creature'] as Creature;
                return creature.rarity == 'Variant' &&
                    creature.id.startsWith('${widget.creature.id}_');
              }).toList();

              // Create list of all versions (base + variants)
              final allVersions = [
                {'creature': widget.creature, 'isVariant': false},
                ...variants.map(
                  (v) => {'creature': v['creature'], 'isVariant': true},
                ),
              ];

              return _buildSwipeableCreatureDisplay(allVersions);
            },
          ),

          const SizedBox(height: 20),

          // Creature info
          _buildInfoCard(
            'Types',
            widget.creature.types.join(', '),
            Icons.category_rounded,
          ),
          _buildInfoCard('Rarity', widget.creature.rarity, Icons.star_rounded),
          if (widget.creature.description.isNotEmpty)
            _buildInfoCard(
              'Description',
              widget.creature.description,
              Icons.description_rounded,
            ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatRow('Breeding Tier', '${widget.creature.rarity}'),
          if (widget.creature.specialBreeding != null)
            _buildInfoCard(
              'Special Breeding',
              widget.creature.specialBreeding!.requiredParentNames.join(', '),
              Icons.science_rounded,
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.celebration_rounded,
              color: Colors.purple.shade400,
              size: 64,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Discovery Method',
            style: TextStyle(
              color: Colors.purple.shade700,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This adorable creature was discovered through your magical adventures!',
            style: TextStyle(
              color: Colors.purple.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.help_outline_rounded,
              color: Colors.grey.shade500,
              size: 64,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Unknown Creature',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Discover this creature through\nbreeding or exploration!',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.purple.shade50.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade100,
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.purple.shade600, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.purple.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.purple.shade50.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade100,
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.purple.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.purple.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
