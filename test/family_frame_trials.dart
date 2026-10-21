// Family numbers tried without editing the table, for the balance probes
// (gem_battle_ladder_test 'species balance', family_balance_survival_test):
//
//   FAMILY_TRY='wing.elemAtk=1.15;pip.physAtk=1.2;darkwing=0.65'
//
// Each entry is family.field=value (a field of AlchemonFamilyFrame), or
// darkwing=rate for Wing+Dark's pace.

import 'dart:io';

import 'package:alchemons/games/shared/alchemon_combat_stats.dart';

/// Applies FAMILY_TRY, and says what it tried (empty for nothing).
String applyFamilyTrials() {
  final raw = Platform.environment['FAMILY_TRY'];
  alchemonFamilyFrameTrials.clear();
  alchemonDarkWingRateTrial = null;
  if (raw == null || raw.trim().isEmpty) return '';
  final fields = <String, Map<String, double>>{};
  for (final entry in raw.split(';')) {
    if (entry.trim().isEmpty) continue;
    final [key, value] = entry.trim().split('=');
    if (key == 'darkwing') {
      alchemonDarkWingRateTrial = double.parse(value);
      continue;
    }
    final [family, field] = key.split('.');
    fields.putIfAbsent(family, () => {})[field] = double.parse(value);
  }
  for (final MapEntry(key: family, value: f) in fields.entries) {
    final b = kAlchemonFamilyFrames[family] ?? const AlchemonFamilyFrame();
    alchemonFamilyFrameTrials[family] = AlchemonFamilyFrame(
      hp: f['hp'] ?? b.hp,
      physAtk: f['physAtk'] ?? b.physAtk,
      elemAtk: f['elemAtk'] ?? b.elemAtk,
      physDef: f['physDef'] ?? b.physDef,
      elemDef: f['elemDef'] ?? b.elemDef,
      autoRange: f['autoRange'] ?? b.autoRange,
      specialRange: f['specialRange'] ?? b.specialRange,
      basicCooldown: f['basicCooldown'] ?? b.basicCooldown,
      specialCooldown: f['specialCooldown'] ?? b.specialCooldown,
    );
  }
  return raw;
}
