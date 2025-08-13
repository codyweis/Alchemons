import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import '../database/alchemons_db.dart';
import '../models/creature.dart';

class GameDataService {
  final AlchemonsDatabase db;
  late List<Creature> allCreatures;
  List<Creature> _discoveredVariants = []; // New: Track variants
  bool _isInitialized = false;

  GameDataService({required this.db});

  /// Check if service has been initialized
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return; // Prevent double initialization

    try {
      // Load base creatures from JSON
      final jsonString = await rootBundle.loadString(
        'assets/data/alchemons_creatures.json',
      );
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      allCreatures = (jsonMap['creatures'] as List)
          .map((e) => Creature.fromJson(e))
          .toList();

      // Ensure all base creatures exist in database
      for (var c in allCreatures) {
        final existing = await db.getCreature(c.id);
        if (existing == null) {
          await db.addOrUpdateCreature(
            PlayerCreaturesCompanion.insert(id: c.id),
          );
        }
      }

      // Load discovered variants from database
      await _loadDiscoveredVariants();

      _isInitialized = true;
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to initialize GameDataService: $e');
    }
  }

  /// Load variants that have been discovered and stored in DB
  Future<void> _loadDiscoveredVariants() async {
    try {
      final allPlayerData = await db.getAllCreatures();

      // Find variant IDs (ones with underscore)
      final variantIds = allPlayerData
          .where((creature) => creature.id.contains('_'))
          .map((creature) => creature.id)
          .toList();

      // Create variant objects from IDs
      _discoveredVariants.clear();
      for (final variantId in variantIds) {
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
    final baseCreature = allCreatures.where((c) => c.id == baseId).firstOrNull;
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

  /// Add a newly discovered variant (call this when breeding creates a variant)
  Future<void> addDiscoveredVariant(Creature variant) async {
    if (!_isInitialized) {
      throw StateError('GameDataService not initialized. Call init() first.');
    }

    try {
      // Add to database
      await markDiscovered(variant.id);

      // Add to memory if not already there
      final exists = _discoveredVariants.any((v) => v.id == variant.id);
      if (!exists) {
        _discoveredVariants.add(variant);
        print('Added variant: ${variant.id}');
      }
    } catch (e) {
      throw Exception('Failed to add discovered variant: $e');
    }
  }

  /// Returns merged list: includes base creatures AND discovered variants
  Future<List<Map<String, dynamic>>> getMergedCreatureData() async {
    if (!_isInitialized) {
      throw StateError('GameDataService not initialized. Call init() first.');
    }

    try {
      final playerData = await db.getAllCreatures();

      // Combine base creatures and discovered variants
      final allCreaturesIncludingVariants = [
        ...allCreatures,
        ..._discoveredVariants,
      ];

      return allCreaturesIncludingVariants.map((c) {
        // Find player data or create default if missing
        final save = playerData.cast<PlayerCreature?>().firstWhere(
          (p) => p?.id == c.id,
          orElse: () => null,
        );

        // Handle case where player data might be missing
        return {
          'creature': c,
          'player': save ?? PlayerCreature(id: c.id, discovered: false),
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get merged creature data: $e');
    }
  }

  /// Mark a creature as discovered (works for both base creatures and variants)
  Future<void> markDiscovered(String id) async {
    if (!_isInitialized) {
      throw StateError('GameDataService not initialized. Call init() first.');
    }

    try {
      await db.addOrUpdateCreature(
        PlayerCreaturesCompanion(id: Value(id), discovered: const Value(true)),
      );

      // If this is a variant being marked as discovered, and we don't have it in memory yet,
      // try to create it and add it to our variants list
      if (id.contains('_')) {
        final existsInMemory = _discoveredVariants.any((v) => v.id == id);
        if (!existsInMemory) {
          final variant = _createVariantFromId(id);
          if (variant != null) {
            _discoveredVariants.add(variant);
            print('Auto-added variant to memory: ${variant.id}');
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to mark creature $id as discovered: $e');
    }
  }

  /// Get a specific creature by ID (checks both base creatures and variants)
  Creature? getCreatureById(String id) {
    if (!_isInitialized) return null;

    // Check base creatures first
    final baseCreature = allCreatures.where((c) => c.id == id).firstOrNull;
    if (baseCreature != null) return baseCreature;

    // Then check variants
    final variant = _discoveredVariants.where((c) => c.id == id).firstOrNull;
    return variant;
  }

  /// Get all creatures of a specific type (includes variants)
  List<Creature> getCreaturesByType(String type) {
    if (!_isInitialized) return [];

    final allCreaturesIncludingVariants = [
      ...allCreatures,
      ..._discoveredVariants,
    ];
    return allCreaturesIncludingVariants
        .where((c) => c.types.contains(type))
        .toList();
  }

  /// Get discovery statistics (includes variants)
  Future<Map<String, int>> getDiscoveryStats() async {
    if (!_isInitialized) {
      return {'discovered': 0, 'total': 0, 'percentage': 0};
    }

    try {
      final playerData = await db.getAllCreatures();
      final discoveredCount = playerData.where((p) => p.discovered).length;
      final totalCount = allCreatures.length + _discoveredVariants.length;
      final percentage = totalCount > 0
          ? (discoveredCount * 100 / totalCount).round()
          : 0;

      return {
        'discovered': discoveredCount,
        'total': totalCount,
        'percentage': percentage,
      };
    } catch (e) {
      return {'discovered': 0, 'total': allCreatures.length, 'percentage': 0};
    }
  }

  /// Mark multiple creatures as discovered (batch operation)
  Future<void> markMultipleDiscovered(List<String> ids) async {
    if (!_isInitialized) {
      throw StateError('GameDataService not initialized. Call init() first.');
    }

    try {
      // Use a transaction for better performance
      await db.transaction(() async {
        for (final id in ids) {
          await db.addOrUpdateCreature(
            PlayerCreaturesCompanion(
              id: Value(id),
              discovered: const Value(true),
            ),
          );
        }
      });

      // Handle any variants in the batch
      for (final id in ids) {
        if (id.contains('_')) {
          final existsInMemory = _discoveredVariants.any((v) => v.id == id);
          if (!existsInMemory) {
            final variant = _createVariantFromId(id);
            if (variant != null) {
              _discoveredVariants.add(variant);
            }
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to mark multiple creatures as discovered: $e');
    }
  }

  /// Reset all discovery progress (for testing or new game)
  Future<void> resetDiscoveryProgress() async {
    if (!_isInitialized) {
      throw StateError('GameDataService not initialized. Call init() first.');
    }

    try {
      await db.transaction(() async {
        final allCreaturesIncludingVariants = [
          ...allCreatures,
          ..._discoveredVariants,
        ];
        for (final creature in allCreaturesIncludingVariants) {
          await db.addOrUpdateCreature(
            PlayerCreaturesCompanion(
              id: Value(creature.id),
              discovered: const Value(false),
            ),
          );
        }
      });

      // Clear variants from memory since they're no longer discovered
      _discoveredVariants.clear();
    } catch (e) {
      throw Exception('Failed to reset discovery progress: $e');
    }
  }

  /// Get all base creatures (from JSON only)
  List<Creature> get baseCreatures => allCreatures;

  /// Get all discovered variants
  List<Creature> get discoveredVariants => _discoveredVariants;

  /// Get all creatures (base + variants)
  List<Creature> get allCreaturesIncludingVariants => [
    ...allCreatures,
    ..._discoveredVariants,
  ];

  /// Refresh variants from database (useful if external changes happen)
  Future<void> refreshVariants() async {
    if (!_isInitialized) return;
    await _loadDiscoveredVariants();
  }

  /// Get variants for a specific base creature
  List<Creature> getVariantsForCreature(String baseCreatureId) {
    return _discoveredVariants
        .where((variant) => variant.id.startsWith('${baseCreatureId}_'))
        .toList();
  }

  /// Check if a variant exists for a base creature + secondary type
  bool hasVariant(String baseCreatureId, String secondaryType) {
    final variantId = '${baseCreatureId}_$secondaryType';
    return _discoveredVariants.any((v) => v.id == variantId);
  }
}
