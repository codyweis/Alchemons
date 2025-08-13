import 'special_breeding.dart';

class BreedingInfo {
  final List<List<String>> parents;
  final Map<String, dynamic> odds;

  BreedingInfo({required this.parents, required this.odds});

  factory BreedingInfo.fromJson(Map<String, dynamic> json) {
    return BreedingInfo(
      parents: (json['parents'] as List)
          .map((pair) => List<String>.from(pair))
          .toList(),
      odds: Map<String, dynamic>.from(json['odds']),
    );
  }

  // New factory for variants (they don't breed normally)
  factory BreedingInfo.empty() {
    return BreedingInfo(
      parents: [],
      odds: {'hybrid': 0, 'parent1': 0, 'parent2': 0, 'mutation': 0},
    );
  }
}
