import 'dart:convert';
import 'dart:io';

const familyProfiles = <String, List<int>>{
  'Let': [52, 50, 50, 54],
  'Pip': [60, 64, 48, 62],
  'Mane': [56, 52, 72, 58],
  'Mask': [60, 72, 54, 68],
  'Horn': [52, 48, 78, 64],
  'Wing': [80, 64, 52, 72],
  'Kin': [66, 70, 74, 72],
  'Mystic': [74, 82, 70, 84],
};

const elementModifiers = <String, List<int>>{
  'Fire': [2, -4, 8, 2],
  'Water': [0, 6, 0, 4],
  'Earth': [-6, 0, 10, 0],
  'Air': [10, 2, -6, 2],
  'Steam': [5, 5, -2, 0],
  'Lava': [-5, -2, 12, 0],
  'Lightning': [12, 2, 0, -2],
  'Mud': [-5, 2, 8, -1],
  'Ice': [0, 7, 2, 4],
  'Dust': [4, 1, 2, -2],
  'Plant': [1, 5, 3, 6],
  'Poison': [4, 6, 0, -2],
  'Dark': [3, 5, 4, 5],
  'Light': [4, 5, -2, 10],
  'Crystal': [-1, 7, 5, 8],
  'Blood': [3, 1, 9, 1],
  'Spirit': [5, 10, -4, 7],
};

void main() {
  final file = File('assets/data/alchemons_creatures.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final creatures = root['creatures'] as List<dynamic>;

  for (final raw in creatures) {
    final creature = raw as Map<String, dynamic>;
    final family = creature['mutationFamily'] as String? ?? 'Let';
    final types = creature['types'] as List<dynamic>? ?? const [];
    final element = types.isEmpty ? 'Fire' : types.first.toString();
    final familyBase = familyProfiles[family] ?? const [58, 58, 58, 58];
    final modifier = elementModifiers[element] ?? const [0, 0, 0, 0];
    int value(int index) => (familyBase[index] + modifier[index]).clamp(1, 100);

    creature['baseStats'] = <String, int>{
      'speed': value(0),
      'intelligence': value(1),
      'strength': value(2),
      'beauty': value(3),
    };
  }

  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(root)}\n',
  );
  stdout.writeln('Assigned fixed base stats to ${creatures.length} Alchemons.');
}
