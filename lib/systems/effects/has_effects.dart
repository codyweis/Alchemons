import 'effect.dart';

mixin HasEffects {
  final List<Effect> _effects = [];

  void addEffect(Effect e) {
    _effects.add(e);
    e.onAttach(this);
  }

  bool removeEffect(Effect e) {
    final removed = _effects.remove(e);
    if (removed) e.onDetach(this);
    return removed;
  }

  void updateEffects(double dt) {
    for (final e in List<Effect>.from(_effects)) {
      e.update(this, dt);
    }
  }

  double modifyStat(String name, double base) {
    var v = base;
    for (final e in _effects) {
      v = e.modifyStat(name, v);
    }
    return v;
  }

  List<Effect> get effects => List.unmodifiable(_effects);
}
