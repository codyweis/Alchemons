// lib/games/cosmic/contest_entrant.dart
//
// What the judges can see of a party Alchemon (contest_judging.dart): what
// it is, how it looks and its line. Shared by the trait contests in space
// and the stadium, so a creature is judged the same in both.

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/stat_system.dart';

/// [member]'s stat for [trait], on the internal scale.
double contestStat(CosmicPartyMember member, CosmicContestTrait trait) =>
    switch (trait) {
      CosmicContestTrait.beauty => member.statBeauty,
      CosmicContestTrait.speed => member.statSpeed,
      CosmicContestTrait.strength => member.statStrength,
      CosmicContestTrait.intelligence => member.statIntelligence,
    };

/// [member] (with its saved row [inst], if it has one) as the judges see it
/// for [trait].
ContestEntrant contestEntrantFor(
  CosmicPartyMember member,
  CreatureInstance? inst,
  CosmicContestTrait trait,
) {
  final visuals = member.spriteVisuals;
  final variantKey = (inst?.variantFaction ?? '').trim().toLowerCase();
  return ContestEntrant(
    name: member.displayName,
    element: member.element,
    family: member.family,
    statRating: AlchemonStatSystem.legacyGameplayRating(
      contestStat(member, trait),
    ),
    scale: visuals?.scale ?? 1.0,
    prismatic: visuals?.isPrismatic == true,
    effect: visuals?.alchemyEffect,
    variant:
        (member.visualVariant ?? '').trim().isNotEmpty ||
        (variantKey.isNotEmpty && variantKey != 'bloodborn'),
    tinted: visuals?.tint != null,
    pureElement: inst == null
        ? null
        : _singleLineageKey(inst.elementLineageJson),
    pureFamily: inst == null ? null : _singleLineageKey(inst.familyLineageJson),
    speciesPure:
        inst != null &&
        _isSpeciesPureFromParentage(inst.parentageJson, member.baseId),
    elementKinds: _lineageDiversityCount(inst?.elementLineageJson),
    factionKinds: _lineageDiversityCount(inst?.factionLineageJson),
    familyKinds: _lineageDiversityCount(inst?.familyLineageJson),
    generations: inst?.generationDepth ?? 0,
  );
}

int _lineageDiversityCount(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 0;
  try {
    final dec = jsonDecode(raw);
    if (dec is! Map<String, dynamic>) return 0;
    return dec.entries
        .where((e) => e.key.trim().isNotEmpty)
        .where((e) => (e.value is num ? (e.value as num).toDouble() : 0) > 0)
        .length;
  } catch (_) {
    return 0;
  }
}

Map<String, int> _decodeLineageCounts(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  try {
    final dec = jsonDecode(raw);
    if (dec is! Map<String, dynamic>) return const {};
    final out = <String, int>{};
    dec.forEach((k, v) {
      var key = k.toString().trim();
      if (key.startsWith('CreatureFamily.')) {
        key = key.split('.').last;
      }
      final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      if (key.isNotEmpty && n > 0) out[key] = n;
    });
    return out;
  } catch (_) {
    return const {};
  }
}

String? _singleLineageKey(String? raw) {
  final parsed = _decodeLineageCounts(raw);
  if (parsed.length != 1) return null;
  return parsed.keys.first;
}

bool _isSpeciesPureFromParentage(String? parentageJson, String baseId) {
  if (parentageJson == null || parentageJson.trim().isEmpty) return true;
  try {
    final dec = jsonDecode(parentageJson);
    if (dec is! Map<String, dynamic>) return false;
    String? readBaseId(dynamic node) {
      if (node is! Map) return null;
      final raw = node['baseId'];
      if (raw is! String || raw.trim().isEmpty) return null;
      return raw.trim();
    }

    final a = readBaseId(dec['parentA']);
    final b = readBaseId(dec['parentB']);
    final ids = <String>[if (a != null) a, if (b != null) b];
    if (ids.isEmpty) return false;
    return ids.every((id) => id == baseId);
  } catch (_) {
    return false;
  }
}
