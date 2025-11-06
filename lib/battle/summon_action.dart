import 'package:alchemons/battle/battle_game_core.dart';

/// Represents a player's planned action (either throw OR summon)
class PlannedAction {
  final PlannedThrow? throw_;
  final BattleCreature? summonCreature;
  final ElementNode? summonAt;

  PlannedAction.throw_(this.throw_) : summonCreature = null, summonAt = null;

  PlannedAction.summon(this.summonCreature, this.summonAt) : throw_ = null;

  bool get isThrow => throw_ != null;
  bool get isSummon => summonCreature != null && summonAt != null;
}
