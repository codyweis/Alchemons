import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/creature.dart';
import '../database/alchemons_db.dart';

class CreatureRepository {
  List<Creature> _creatures = [];
  List<Creature> _discoveredVariants = [];
  final AlchemonsDatabase? db;

  CreatureRepository({this.db});

  /// Load all creatures from JSON asset AND discovered variants from DB
  Future<void> loadCreatures({
    String path = 'assets/data/alchemons_creatures.json',
  }) async {
    // Load base creatures from JSON
    final String response = await rootBundle.loadString(path);
    final Map<String, dynamic> data = jsonDecode(response);

    _creatures = (data['creatures'] as List)
        .map((json) => Creature.fromJson(json))
        .toList();

    // Load discovered variants from database
    if (db != null) {
      await _loadDiscoveredVariants();
    }
  }

  /// Load variants that have been discovered and stored in DB
  Future<void> _loadDiscoveredVariants() async {
    if (db == null) return;

    try {
      // Use the correct database method
      final allPlayerCreatures = await db?.getAllCreatures();

      // Find variant IDs (ones with underscore indicating they're variants)
      final variantIds = allPlayerCreatures
          ?.where((creature) => creature.id.contains('_'))
          .map((creature) => creature.id)
          .toList();

      // Create variant objects from IDs
      _discoveredVariants.clear();
      for (final variantId in variantIds!) {
        final variant = _createVariantFromId(variantId);
        if (variant != null) {
          _discoveredVariants.add(variant);
        }
      }

      print('Loaded ${_discoveredVariants.length} variants from database');
    } catch (e) {
      print('Error loading variants: $e');
    }
  }

  /// Create a variant creature from its ID (e.g., "CR003_Ice")
  Creature? _createVariantFromId(String variantId) {
    final parts = variantId.split('_');
    if (parts.length != 2) return null;

    final baseId = parts[0];
    final secondaryType = parts[1];

    // Find the base creature
    final baseCreature = _creatures.where((c) => c.id == baseId).firstOrNull;
    if (baseCreature == null) return null;

    // Create variant using the factory constructor
    return Creature.variant(
      baseId: baseCreature.id,
      baseName: baseCreature.name,
      primaryType: baseCreature.types.first,
      secondaryType: secondaryType,
      baseImage: baseCreature.image,
    );
  }

  /// Add a newly discovered variant to the repository
  void addDiscoveredVariant(Creature variant) {
    // Check if variant already exists
    final exists = _discoveredVariants.any((v) => v.id == variant.id);
    if (!exists) {
      _discoveredVariants.add(variant);
      print('Added variant to repository: ${variant.id}');
    }
  }

  /// Find a creature by its ID (checks both base creatures and variants)
  Creature? getCreatureById(String id) {
    // First check base creatures
    final baseCreature = _creatures.where((c) => c.id == id).firstOrNull;
    if (baseCreature != null) return baseCreature;

    // Then check variants
    final variant = _discoveredVariants.where((c) => c.id == id).firstOrNull;
    return variant;
  }

  /// Return ALL creatures (base + discovered variants)
  List<Creature> get creatures => [..._creatures, ..._discoveredVariants];

  /// Return only base creatures (from JSON)
  List<Creature> get baseCreatures => _creatures;

  /// Return only discovered variants
  List<Creature> get discoveredVariants => _discoveredVariants;

  /// Return creatures filtered by type
  List<Creature> getCreaturesByType(String type) {
    return creatures.where((c) => c.types.contains(type)).toList();
  }

  /// Return creatures that have a special breeding requirement
  List<Creature> get specialBreedingCreatures =>
      creatures.where((c) => c.specialBreeding != null).toList();

  /// Refresh variants from database (useful after new discoveries)
  Future<void> refreshVariants() async {
    if (db != null) {
      await _loadDiscoveredVariants();
    }
  }
}
