import 'special_breeding.dart';

class BreedingInfo {
  final List<List<String>> parents;

  BreedingInfo({required this.parents});

  factory BreedingInfo.fromJson(Map<String, dynamic> json) {
    return BreedingInfo(
      parents:
          (json['parents'] as List)
              .map((pair) => List<String>.from(pair))
              .toList(),
    );
  }

  // New factory for variants (they don't breed normally)
  factory BreedingInfo.empty() {
    return BreedingInfo(parents: []);
  }
}
