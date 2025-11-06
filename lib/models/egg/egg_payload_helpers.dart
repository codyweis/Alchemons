import 'dart:convert';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';

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
  final rarity = payload['rarity'] as String? ?? 'Common';
  return '$rarity Vial';
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
