import 'dart:io';
import 'dart:math';

class _TierProfile {
  final String name;
  final double statValue;

  const _TierProfile(this.name, this.statValue);
}

class _BossRow {
  final int order;
  final String id;
  final String name;
  final String element;
  final String tier;
  final int hp;
  final int atk;
  final int def;
  final int spd;
  final Set<String> moveNames;
  final Set<String> moveTypes;

  const _BossRow({
    required this.order,
    required this.id,
    required this.name,
    required this.element,
    required this.tier,
    required this.hp,
    required this.atk,
    required this.def,
    required this.spd,
    required this.moveNames,
    required this.moveTypes,
  });

  _BossRow copyWith({int? hp, int? atk, int? def, int? spd}) {
    return _BossRow(
      order: order,
      id: id,
      name: name,
      element: element,
      tier: tier,
      hp: hp ?? this.hp,
      atk: atk ?? this.atk,
      def: def ?? this.def,
      spd: spd ?? this.spd,
      moveNames: moveNames,
      moveTypes: moveTypes,
    );
  }
}

class _BossRematchScale {
  final double hpScale;
  final double atkScale;
  final double defScale;
  final double spdScale;
  final int hpFlat;
  final int atkFlat;
  final int defFlat;
  final int spdFlat;

  const _BossRematchScale({
    required this.hpScale,
    required this.atkScale,
    required this.defScale,
    required this.spdScale,
    required this.hpFlat,
    required this.atkFlat,
    required this.defFlat,
    required this.spdFlat,
  });
}

class _ScaleAnchor {
  final int order;
  final double value;
  const _ScaleAnchor(this.order, this.value);
}

double _lerpScale(double a, double b, double t) => a + ((b - a) * t);

double _scaleFromAnchors(int order, List<_ScaleAnchor> anchors) {
  if (anchors.isEmpty) return 1.0;
  if (order <= anchors.first.order) return anchors.first.value;
  for (var i = 0; i < anchors.length - 1; i++) {
    final left = anchors[i];
    final right = anchors[i + 1];
    if (order <= right.order) {
      final span = (right.order - left.order).toDouble();
      final t = span <= 0 ? 0.0 : (order - left.order) / span;
      return _lerpScale(left.value, right.value, t);
    }
  }
  return anchors.last.value;
}

void main() {
  final bosses = _parseBossData('lib/data/boss_data.dart')
    ..sort((a, b) => a.order.compareTo(b.order));
  if (bosses.isEmpty) {
    stderr.writeln('No bosses parsed from lib/data/boss_data.dart');
    exitCode = 1;
    return;
  }

  _printStoryMatrix(bosses);
  _printRematchMatrix(bosses);
}

void _printStoryMatrix(List<_BossRow> bosses) {
  final tiers = <_TierProfile>[
    const _TierProfile('2.5', 2.5),
    const _TierProfile('3.5', 3.5),
    const _TierProfile('4.25', 4.25),
    const _TierProfile('4.8', 4.8),
  ];

  stdout.writeln('\n=== STORY BOSS MATRIX (party: 4 x level 10) ===');
  stdout.writeln(
    'ord boss              elem tier  rnd@2.5 rnd@3.5 rnd@4.25 rnd@4.8 win@4.8 minStat',
  );

  for (final boss in bosses) {
    final roundsByTier = <String, double>{};
    for (final t in tiers) {
      roundsByTier[t.name] = _estimateRoundsForTier(boss, t.statValue);
    }

    final winAt48 = _estimatedWinRate(roundsByTier['4.8']!);
    final minStat = _minSuggestedStoryStat(roundsByTier);

    stdout.writeln(
      '${boss.order.toString().padLeft(2)} '
      '${boss.name.padRight(17)} '
      '${boss.element.padRight(4)} '
      '${boss.tier.padRight(8)} '
      '${roundsByTier['2.5']!.toStringAsFixed(2).padLeft(7)} '
      '${roundsByTier['3.5']!.toStringAsFixed(2).padLeft(7)} '
      '${roundsByTier['4.25']!.toStringAsFixed(2).padLeft(8)} '
      '${roundsByTier['4.8']!.toStringAsFixed(2).padLeft(7)} '
      '${winAt48.toString().padLeft(3)}% '
      '${minStat.padRight(6)}',
    );
  }
}

void _printRematchMatrix(List<_BossRow> baseBosses) {
  stdout.writeln('\n=== REMATCH/DUNGEON MATRIX (enraged scaling) ===');
  stdout.writeln(
    'ord boss              rnd@4.8 rnd@5.0 win@4.8 win@5.0 target',
  );

  for (final base in baseBosses) {
    final rematch = _toRematchBoss(base);
    final rounds48 = _estimateRoundsForTier(rematch, 4.8);
    final rounds50 = _estimateRoundsForTier(rematch, 5.0);
    final win48 = _estimatedWinRate(rounds48);
    final win50 = _estimatedWinRate(rounds50);
    final target = _rematchTargetBand(win48, win50);

    stdout.writeln(
      '${base.order.toString().padLeft(2)} '
      '${base.name.padRight(17)} '
      '${rounds48.toStringAsFixed(2).padLeft(7)} '
      '${rounds50.toStringAsFixed(2).padLeft(7)} '
      '${win48.toString().padLeft(3)}% '
      '${win50.toString().padLeft(3)}% '
      '$target',
    );
  }

  stdout.writeln('\nLegend:');
  stdout.writeln(
    '- win@4.8 / win@5.0 are estimated clear chances for those trait averages.',
  );
  stdout.writeln('- target aims for strict strategy requirement near 4.8-5.0.');
}

_BossRow _toRematchBoss(_BossRow base) {
  final s = _rematchScaleForOrder(base.order);
  return base.copyWith(
    hp: (base.hp * s.hpScale).round() + s.hpFlat,
    atk: (base.atk * s.atkScale).round() + s.atkFlat,
    def: (base.def * s.defScale).round() + s.defFlat,
    spd: (base.spd * s.spdScale).round() + s.spdFlat,
  );
}

_BossRematchScale _rematchScaleForOrder(int order) {
  final hpScale = _scaleFromAnchors(order, const [
    _ScaleAnchor(1, 3.30),
    _ScaleAnchor(4, 2.25),
    _ScaleAnchor(8, 1.46),
    _ScaleAnchor(12, 1.02),
    _ScaleAnchor(17, 0.95),
  ]);
  final atkScale = _scaleFromAnchors(order, const [
    _ScaleAnchor(1, 1.42),
    _ScaleAnchor(4, 1.32),
    _ScaleAnchor(8, 1.20),
    _ScaleAnchor(12, 1.05),
    _ScaleAnchor(17, 1.00),
  ]);
  final defScale = _scaleFromAnchors(order, const [
    _ScaleAnchor(1, 1.32),
    _ScaleAnchor(4, 1.24),
    _ScaleAnchor(8, 1.14),
    _ScaleAnchor(12, 1.05),
    _ScaleAnchor(17, 1.00),
  ]);
  final spdScale = _scaleFromAnchors(order, const [
    _ScaleAnchor(1, 1.20),
    _ScaleAnchor(4, 1.16),
    _ScaleAnchor(8, 1.12),
    _ScaleAnchor(12, 1.07),
    _ScaleAnchor(17, 1.03),
  ]);
  final hpFlat = order <= 4 ? 40 : (order <= 8 ? 20 : 0);
  final atkFlat = order <= 4 ? 3 : (order <= 8 ? 2 : (order <= 12 ? 1 : 0));
  final defFlat = order <= 4 ? 2 : (order <= 8 ? 1 : 0);
  final spdFlat = order <= 6 ? 1 : 0;
  return _BossRematchScale(
    hpScale: hpScale,
    atkScale: atkScale,
    defScale: defScale,
    spdScale: spdScale,
    hpFlat: hpFlat,
    atkFlat: atkFlat,
    defFlat: defFlat,
    spdFlat: spdFlat,
  );
}

String _rematchTargetBand(int win48, int win50) {
  if (win48 >= 50 && win48 <= 70 && win50 >= 60 && win50 <= 78) {
    return 'on-target';
  }
  if (win48 < 50 && win50 < 60) {
    return 'too hard';
  }
  if (win48 > 70) {
    return 'too easy';
  }
  return 'edge';
}

List<_BossRow> _parseBossData(String path) {
  final text = File(path).readAsStringSync();
  final bosses = <_BossRow>[];

  for (final block in _extractBossBlocks(text)) {
    final id = _extractString(block, 'id');
    final name = _extractString(block, 'name');
    final element = _extractString(block, 'element');
    final order = _extractInt(block, 'order');
    final hp = _extractInt(block, 'hp');
    final atk = _extractInt(block, 'atk');
    final def = _extractInt(block, 'def');
    final spd = _extractInt(block, 'spd');
    final tierMatch = RegExp(
      r'tier:\s*BossTier\.([a-zA-Z]+)',
    ).firstMatch(block)?.group(1);

    if (id == null ||
        name == null ||
        element == null ||
        order == null ||
        hp == null ||
        atk == null ||
        def == null ||
        spd == null ||
        tierMatch == null) {
      continue;
    }

    final moveNames = <String>{};
    final moveTypes = <String>{};
    final moveBlock = RegExp(r'BossMove\(([\s\S]*?)\),');
    for (final mm in moveBlock.allMatches(block)) {
      final mblock = mm.group(1)!;
      final moveName = _extractString(mblock, 'name');
      final moveType = RegExp(
        r'type:\s*BossMoveType\.([a-zA-Z]+)',
      ).firstMatch(mblock)?.group(1);
      if (moveName != null) moveNames.add(moveName.toLowerCase());
      if (moveType != null) moveTypes.add(moveType.toLowerCase());
    }

    bosses.add(
      _BossRow(
        order: order,
        id: id,
        name: name,
        element: element,
        tier: tierMatch,
        hp: hp,
        atk: atk,
        def: def,
        spd: spd,
        moveNames: moveNames,
        moveTypes: moveTypes,
      ),
    );
  }

  return bosses;
}

List<String> _extractBossBlocks(String source) {
  final blocks = <String>[];
  var index = 0;
  while (true) {
    final start = source.indexOf('Boss(', index);
    if (start < 0) break;

    var depth = 0;
    var end = -1;
    for (var i = start; i < source.length; i++) {
      final char = source[i];
      if (char == '(') depth++;
      if (char == ')') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    if (end < 0) break;
    blocks.add(source.substring(start + 5, end));
    index = end + 1;
  }
  return blocks;
}

String? _extractString(String block, String key) {
  final match = RegExp("$key:\\s*'([^']+)'").firstMatch(block);
  return match?.group(1);
}

int? _extractInt(String block, String key) {
  final match = RegExp('$key:\\s*(\\d+)').firstMatch(block);
  return match == null ? null : int.tryParse(match.group(1)!);
}

double _estimateRoundsForTier(_BossRow boss, double traitValue) {
  final player = _buildPlayerStats(traitValue);
  final playerDamage = _baseDamage(
    attackStat: player.physAtk,
    defenseStat: boss.def,
  );
  final kit = _bossKitModifier(boss);
  const teamActionsPerRound = 4.0;
  return (boss.hp / (playerDamage * teamActionsPerRound)) * kit;
}

class _PlayerStats {
  final int physAtk;
  final int elemDef;

  const _PlayerStats({required this.physAtk, required this.elemDef});
}

_PlayerStats _buildPlayerStats(double traitValue) {
  const level = 10;
  final scaled = traitValue * 10;
  final physAtk = (scaled * 0.4 + level * 2).round();
  final elemDef = (scaled * 0.4 + level * 2).round();
  return _PlayerStats(physAtk: physAtk, elemDef: elemDef);
}

int _baseDamage({
  required int attackStat,
  required int defenseStat,
  int attackMultiplier = 2,
}) {
  return max(1, (attackStat * attackMultiplier) - defenseStat);
}

double _bossKitModifier(_BossRow boss) {
  var modifier = 1.0;

  if (boss.moveTypes.contains('aoe')) modifier += 0.08;
  if (boss.moveTypes.contains('heal')) modifier += 0.08;
  if (boss.moveTypes.contains('special')) modifier += 0.10;
  if (boss.moveTypes.contains('debuff')) modifier += 0.04;
  if (boss.moveTypes.contains('buff')) modifier += 0.03;

  if (boss.moveNames.contains('charge-up')) modifier += 0.08;
  if (boss.moveNames.contains('corrode')) modifier += 0.05;
  if (boss.moveNames.contains('sink')) modifier += 0.10;
  if (boss.moveNames.contains('mirage')) modifier += 0.10;
  if (boss.moveNames.contains('eclipse')) modifier += 0.12;
  if (boss.moveNames.contains('genesis')) modifier += 0.10;
  if (boss.moveNames.contains('empower')) modifier += 0.08;
  if (boss.moveNames.contains('molten-armor')) modifier += 0.08;
  if (boss.moveNames.contains('quagmire')) modifier += 0.05;
  if (boss.moveNames.contains('refract')) modifier += 0.05;

  return modifier.clamp(1.0, 1.55);
}

int _estimatedWinRate(double roundsToKill) {
  final raw = 98 - ((max(0.0, roundsToKill - 1.5)) * 11.0);
  return raw.clamp(5.0, 95.0).round();
}

String _minSuggestedStoryStat(Map<String, double> roundsByTier) {
  final avgWin = _estimatedWinRate(roundsByTier['2.5']!);
  final strongWin = _estimatedWinRate(roundsByTier['3.5']!);
  final eliteWin = _estimatedWinRate(roundsByTier['4.25']!);
  final peakWin = _estimatedWinRate(roundsByTier['4.8']!);

  if (avgWin >= 60) return '2.5+';
  if (strongWin >= 60) return '3.5+';
  if (eliteWin >= 60) return '4.25+';
  if (peakWin >= 60) return '4.8+';
  return '5.0';
}
