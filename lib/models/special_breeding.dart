class SpecialBreeding {
  final List<List<String>> requiredParents;
  final List<List<String>> requiredParentNames;
  final String notes;

  SpecialBreeding({
    required this.requiredParents,
    required this.requiredParentNames,
    required this.notes,
  });

  factory SpecialBreeding.fromJson(Map<String, dynamic> json) {
    return SpecialBreeding(
      requiredParents: (json['required_parents'] as List)
          .map((pair) => List<String>.from(pair))
          .toList(),
      requiredParentNames: (json['required_parent_names'] as List)
          .map((pair) => List<String>.from(pair))
          .toList(),
      notes: json['notes'] ?? '',
    );
  }
}
