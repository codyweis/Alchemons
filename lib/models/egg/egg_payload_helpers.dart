import 'dart:convert';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';

import 'package:flutter/material.dart';

/// Parse egg's JSON payload safely
Map<String, dynamic> parseEggPayload(Egg egg) {
  try {
    if (egg.payloadJson != null && egg.payloadJson!.isNotEmpty) {
      return jsonDecode(egg.payloadJson!) as Map<String, dynamic>;
    }
  } catch (e) {
    debugPrint('Error parsing egg payload: $e');
  }
  return {};
}

/// Extract elemental group from egg payload
ElementalGroup getElementalGroupFromPayload(Map<String, dynamic> payload) {
  // Try to get from lineage > nativeFaction
  final lineage = payload['lineage'] as Map<String, dynamic>?;
  if (lineage != null) {
    final nativeFaction = lineage['nativeFaction'] as String?;
    if (nativeFaction != null) {
      return elementalGroupFromString(nativeFaction);
    }

    // Fallback: check elementLineage for primary element
    final elementLineage = lineage['elementLineage'] as Map<String, dynamic>?;
    if (elementLineage != null && elementLineage.isNotEmpty) {
      final primaryElement = elementLineage.keys.first;
      return elementalGroupFromElementType(primaryElement);
    }
  }

  // Final fallback: try to get from parentage
  final parentage = payload['parentage'] as Map<String, dynamic>?;
  if (parentage != null) {
    final parentA = parentage['parentA'] as Map<String, dynamic>?;
    if (parentA != null) {
      final types = parentA['types'] as List?;
      if (types != null && types.isNotEmpty) {
        return elementalGroupFromElementType(types.first.toString());
      }
    }
  }

  return ElementalGroup.volcanic; // Default fallback
}

/// Get display label for the egg
String getEggLabel(Map<String, dynamic> payload) {
  final source = (payload['source'] as String? ?? '').toLowerCase();
  if (source == 'vial') {
    final vialName = (payload['vialName'] as String?)?.trim();
    if (vialName != null && vialName.isNotEmpty) {
      return vialName;
    }
  }

  final rarity = payload['rarity'] as String? ?? 'Common';
  if (source == 'vial') {
    final vialRarity = _vialRarityFromCreatureRarity(rarity);
    return vialRarity.label;
  }
  return '$rarity Vial';
}

VialRarity _vialRarityFromCreatureRarity(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'common':
      return VialRarity.common;
    case 'uncommon':
      return VialRarity.uncommon;
    case 'rare':
      return VialRarity.rare;
    case 'legendary':
      return VialRarity.legendary;
    case 'mythic':
      return VialRarity.mythic;
    default:
      return VialRarity.common;
  }
}

/// Get subtitle showing generation or parents
String getEggSubtitle(Map<String, dynamic> payload) {
  final lineage = payload['lineage'] as Map<String, dynamic>?;
  final generation = lineage?['generationDepth'] as int? ?? 0;

  if (generation == 0) {
    return 'Generation 0';
  }

  final parentage = payload['parentage'] as Map<String, dynamic>?;
  if (parentage != null) {
    final parentA = parentage['parentA'] as Map<String, dynamic>?;
    final parentB = parentage['parentB'] as Map<String, dynamic>?;

    if (parentA != null && parentB != null) {
      final nameA = (parentA['name'] as String?)?.split(' ').first ?? '?';
      final nameB = (parentB['name'] as String?)?.split(' ').first ?? '?';
      return '$nameA × $nameB';
    }
  }

  return 'Gen $generation';
}

/// Resolve up to [maxTypes] element type IDs for chamber particle effects.
///
/// Priority:
/// 1) parentage types (if present)
/// 2) lineage.elementLineage (wild/founder payloads)
/// 3) lineage.nativeFaction mapped to group element types
/// 4) group inferred from payload fallback
List<String> extractParticleTypeIdsFromPayload(
  Map<String, dynamic> payload, {
  int maxTypes = 2,
}) {
  if (maxTypes <= 0) return const [];

  final types = <String>[];
  final seen = <String>{};

  void addType(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return;
    final key = value.toLowerCase();
    if (seen.add(key)) {
      types.add(value);
    }
  }

  final parentage = payload['parentage'] as Map<String, dynamic>?;
  if (parentage != null) {
    final parentA = parentage['parentA'] as Map<String, dynamic>?;
    final parentB = parentage['parentB'] as Map<String, dynamic>?;
    final p1Types = parentA?['types'] as List<dynamic>?;
    final p2Types = parentB?['types'] as List<dynamic>?;
    if (p1Types != null && p1Types.isNotEmpty) addType(p1Types.first);
    if (p2Types != null && p2Types.isNotEmpty) addType(p2Types.first);
  }
  if (types.isNotEmpty) {
    return types.take(maxTypes).toList(growable: false);
  }

  final lineage = payload['lineage'] as Map<String, dynamic>?;
  final lineageElements = lineage?['elementLineage'];
  if (lineageElements is Map) {
    final ranked = lineageElements.entries.map((entry) {
      final weight = entry.value is num
          ? (entry.value as num).toInt()
          : int.tryParse(entry.value.toString()) ?? 0;
      return (type: entry.key.toString(), weight: weight);
    }).toList()..sort((a, b) => b.weight.compareTo(a.weight));
    for (final item in ranked) {
      addType(item.type);
      if (types.length >= maxTypes) {
        return types.take(maxTypes).toList(growable: false);
      }
    }
  }

  final nativeFaction = lineage?['nativeFaction'] as String?;
  if (nativeFaction != null && nativeFaction.trim().isNotEmpty) {
    final group = elementalGroupFromString(nativeFaction);
    for (final type in group.elementTypes) {
      addType(type);
      if (types.length >= maxTypes) {
        return types.take(maxTypes).toList(growable: false);
      }
    }
  }

  final fallbackGroup = getElementalGroupFromPayload(payload);
  for (final type in fallbackGroup.elementTypes) {
    addType(type);
    if (types.length >= maxTypes) break;
  }
  return types.take(maxTypes).toList(growable: false);
}
