class Egg {
  final String id;
  final String resultCreatureId;
  final String? bonusVariantId;
  final String rarity;
  final DateTime hatchAt;

  Egg({
    required this.id,
    required this.resultCreatureId,
    required this.rarity,
    required this.hatchAt,
    this.bonusVariantId,
  });

  Duration get remaining => hatchAt.difference(DateTime.now());

  bool get isReady => remaining.inSeconds <= 0;
}
