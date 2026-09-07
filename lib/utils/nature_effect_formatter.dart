import 'package:alchemons/models/nature.dart';

/// Formats Nature mechanics in player-facing units.
///
/// Multipliers are shown as their signed percentage change from 1.0, stat
/// bonuses are stored as fractional bonuses, and flat bonuses retain units.
String formatNatureEffectSummary(NatureEffect effect) {
  if (effect.modifiers.isEmpty) {
    return 'No special behavioral modifications known';
  }

  final effects = <String>[];
  effect.modifiers.forEach((key, value) {
    switch (key) {
      case 'stamina_extra':
        effects.add('Stamina +${value.toInt()}');
      case 'stamina_breeding_cost_mult':
        effects.add('Breeding cost ${_multiplierDelta(value)}');
      case 'wild_fusion_stability_add':
        effects.add('Wild Fusion stability ${_signedPercent(value)}');
      case 'stamina_regen_mult':
        effects.add('Stamina recovery ${_multiplierDelta(value)}');
      case 'harvest_rate_mult':
        effects.add('Harvest rate ${_multiplierDelta(value)}');
      case 'breed_same_species_chance_mult':
        effects.add('Same-species breeding ${_multiplierDelta(value)}');
      case 'breed_same_type_chance_mult':
        effects.add('Same-type breeding ${_multiplierDelta(value)}');
      case 'egg_hatch_time_mult':
        effects.add('Hatch time ${_multiplierDelta(value)}');
      case 'xp_gain_mult':
        effects.add('XP gain ${_multiplierDelta(value)}');
      case 'sale_value_mult':
        effects.add('Sale value ${_multiplierDelta(value)}');
      case 'guarantee_second_nature_inheritance':
        effects.add('Guarantees second Nature inheritance');
      case 'stat_speed_bonus':
        effects.add('Speed ${_signedPercent(value)}');
      case 'stat_intelligence_bonus':
        effects.add('Intelligence ${_signedPercent(value)}');
      case 'stat_strength_bonus':
        effects.add('Strength ${_signedPercent(value)}');
      case 'stat_beauty_bonus':
        effects.add('Beauty ${_signedPercent(value)}');
      default:
        effects.add('${_humanizeKey(key)}: $value');
    }
  });
  return effects.join(' • ');
}

String _multiplierDelta(num multiplier) =>
    _signedPercent(multiplier.toDouble() - 1.0);

String _signedPercent(num fraction) {
  final percentage = fraction.toDouble() * 100.0;
  final rounded = percentage.roundToDouble();
  final amount = (percentage - rounded).abs() < 0.000001
      ? rounded.toInt().toString()
      : percentage.toStringAsFixed(1);
  return '${percentage >= 0 ? '+' : ''}$amount%';
}

String _humanizeKey(String key) => key
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
