import 'effect.dart';
import 'effect_registry.dart';
import 'package:alchemons/systems/effects/has_effects.dart';

/// Example: a simple damage multiplier aura.
class FlameAura extends Effect {
  final double dmgMult;

  FlameAura(this.dmgMult) : super('flame_aura');

  FlameAura.fromJson(Map<String, dynamic> json)
    : dmgMult = (json['dmgMult'] is num)
          ? (json['dmgMult'] as num).toDouble()
          : 1.0,
      super('flame_aura');

  @override
  double modifyStat(String stat, double base) {
    if (stat == 'damage') return base * dmgMult;
    return base;
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'dmgMult': dmgMult};
}

/// Example: a slow field that reduces speed; could also implement duration in update().
class SlowField extends Effect {
  final double speedMult;
  final double? duration;
  double _elapsed = 0.0;

  SlowField(this.speedMult, {this.duration}) : super('slow_field');

  SlowField.fromJson(Map<String, dynamic> json)
    : speedMult = (json['speedMult'] is num)
          ? (json['speedMult'] as num).toDouble()
          : 1.0,
      duration = (json['duration'] is num)
          ? (json['duration'] as num).toDouble()
          : null,
      super('slow_field');

  @override
  double modifyStat(String stat, double base) {
    if (stat == 'speed') return base * speedMult;
    return base;
  }

  @override
  void update(Object? entity, double dt) {
    if (duration != null) {
      _elapsed += dt;
      if (_elapsed >= (duration ?? double.infinity)) {
        if (entity is HasEffects) {
          entity.removeEffect(this);
        }
      }
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'speedMult': speedMult,
    'duration': duration,
  };
}

void registerDefaultEffects() {
  EffectRegistry.register('flame_aura', (json) => FlameAura.fromJson(json));
  EffectRegistry.register('slow_field', (json) => SlowField.fromJson(json));
}
