import 'dart:math';

class WeightedChoice<T> {
  final T value;
  final double weight;
  const WeightedChoice(this.value, this.weight);
}

class WeightedPicker<T> {
  final List<WeightedChoice<T>> _choices;
  final double _totalWeight;

  WeightedPicker(List<WeightedChoice<T>> choices)
    : _choices = choices.where((c) => c.weight > 0).toList(),
      _totalWeight = choices.fold<double>(
        0,
        (a, b) => a + (b.weight > 0 ? b.weight : 0),
      ) {
    if (_choices.isEmpty) {
      throw ArgumentError(
        'WeightedPicker: choices cannot be empty or all zero-weight.',
      );
    }
  }

  T pick(Random rng) {
    var roll = rng.nextDouble() * _totalWeight;
    for (final c in _choices) {
      if ((roll -= c.weight) <= 0) return c.value;
    }
    return _choices.last.value; // Fallback to last
  }
}
