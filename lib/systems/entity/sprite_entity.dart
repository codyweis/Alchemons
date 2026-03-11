import '../effects/effect.dart';

class SpriteEntity {
  final String id;
  final Map<String, double> baseStats;
  final List<Effect> _effects = [];

  SpriteEntity(this.id, {Map<String, double>? baseStats})
    : baseStats = Map<String, double>.from(baseStats ?? {});

  void addEffect(Effect effect) {
    _effects.add(effect);
    effect.onAttach(this);
  }

  bool removeEffect(Effect effect) {
    final removed = _effects.remove(effect);
    if (removed) effect.onDetach(this);
    return removed;
  }

  void update(double dt) {
    for (final e in List<Effect>.from(_effects)) {
      e.update(this, dt);
    }
  }

  double stat(String name) {
    var value = baseStats[name] ?? 0.0;
    for (final e in _effects) {
      value = e.modifyStat(name, value);
    }
    return value;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'baseStats': baseStats,
    'effects': _effects.map((e) => e.toJson()).toList(),
  };
}
