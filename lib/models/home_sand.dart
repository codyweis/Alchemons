import 'dart:ui';

/// How Living Sands' sands lie together.
enum SandPattern {
  /// Poured together in swirling veins.
  marbled('MARBLED'),

  /// Laid one over another in wavy layers, as in a bottle of sand art.
  layered('LAYERED'),

  /// Each in its own broad drift.
  drifts('DRIFTS'),

  /// Mixed through each other grain by grain.
  mixed('MIXED');

  const SandPattern(this.label);

  final String label;
}

/// What Living Sands does when a finger is drawn through it.
enum SandMotion {
  /// Carried along and aside, and flows back.
  springsBack('SPRINGS BACK'),

  /// Ploughed out of the way, down to the floor, and left there.
  staysPut('STAYS PUT'),

  /// Swirled along with the finger, the sands through each other, and left
  /// there: no floor shows.
  mixes('MIXES');

  const SandMotion(this.label);

  final String label;
}

/// Living Sands' look and feel. Saved with the home layout, and kept when
/// the home is another realm for a while.
class HomeSandStyle {
  const HomeSandStyle({
    this.colors = kSandDefaultColors,
    this.count = 2,
    this.shimmer = const Color(0xFFFFE8BB),
    this.pattern = SandPattern.marbled,
    this.density = 0.6,
    this.grain = 0.35,
    this.sparkle = 0.35,
    this.motion = SandMotion.springsBack,
  });

  /// The five sands' colours. Only the first [count] are laid; the rest are
  /// kept for when there are more again.
  final List<Color> colors;

  /// How many sands are laid, 1 to [kSandMaxCount].
  final int count;

  /// The colour of the flecks and glints through the sand.
  final Color shimmer;

  final SandPattern pattern;

  /// 0..1: how thickly the grains lie.
  final double density;

  /// 0..1: fine to coarse.
  final double grain;

  /// 0..1: how much of the shimmer lies through it.
  final double sparkle;

  final SandMotion motion;

  /// Pushed sand stays where it was pushed (ploughed or mixed), instead of
  /// springing back.
  bool get stays => motion != SandMotion.springsBack;

  /// The sands that are laid.
  List<Color> get sands => colors.sublist(0, count);

  HomeSandStyle copyWith({
    int? count,
    Color? shimmer,
    SandPattern? pattern,
    double? density,
    double? grain,
    double? sparkle,
    SandMotion? motion,
  }) => HomeSandStyle(
    colors: colors,
    count: (count ?? this.count).clamp(1, kSandMaxCount),
    shimmer: shimmer ?? this.shimmer,
    pattern: pattern ?? this.pattern,
    density: (density ?? this.density).clamp(0.0, 1.0),
    grain: (grain ?? this.grain).clamp(0.0, 1.0),
    sparkle: (sparkle ?? this.sparkle).clamp(0.0, 1.0),
    motion: motion ?? this.motion,
  );

  /// With sand [i]'s colour [color].
  HomeSandStyle withColor(int i, Color color) => HomeSandStyle(
    colors: [for (final (j, c) in colors.indexed) j == i ? color : c],
    count: count,
    shimmer: shimmer,
    pattern: pattern,
    density: density,
    grain: grain,
    sparkle: sparkle,
    motion: motion,
  );

  @override
  bool operator ==(Object other) {
    if (other is! HomeSandStyle ||
        other.count != count ||
        other.shimmer != shimmer ||
        other.pattern != pattern ||
        other.density != density ||
        other.grain != grain ||
        other.sparkle != sparkle ||
        other.motion != motion ||
        other.colors.length != colors.length) {
      return false;
    }
    for (var i = 0; i < colors.length; i++) {
      if (other.colors[i] != colors[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(colors),
    count,
    shimmer,
    pattern,
    density,
    grain,
    sparkle,
    motion,
  );

  Map<String, Object> toJson() => {
    'colors': [for (final c in colors) c.toARGB32()],
    'count': count,
    'shimmer': shimmer.toARGB32(),
    'pattern': pattern.name,
    'density': density,
    'grain': grain,
    'sparkle': sparkle,
    'motion': motion.name,
  };

  static HomeSandStyle fromJson(Object? value) {
    const defaults = HomeSandStyle();
    if (value is! Map) return defaults;
    Color? colour(Object? v) =>
        v is int && v >= 0 && v <= 0xFFFFFFFF ? Color(v | 0xFF000000) : null;
    double share(String key, double fallback) {
      final v = value[key];
      return v is num && v.isFinite ? v.toDouble().clamp(0.0, 1.0) : fallback;
    }

    final saved = value['colors'];
    final colors = [...kSandDefaultColors];
    if (saved is List) {
      for (var i = 0; i < saved.length && i < kSandMaxCount; i++) {
        colors[i] = colour(saved[i]) ?? colors[i];
      }
    } else {
      // Saved before there could be more than two.
      colors[0] = colour(value['first']) ?? colors[0];
      colors[1] = colour(value['second']) ?? colors[1];
    }
    final count = value['count'];
    return HomeSandStyle(
      colors: colors,
      count: count is int ? count.clamp(1, kSandMaxCount) : defaults.count,
      shimmer: colour(value['shimmer']) ?? defaults.shimmer,
      pattern:
          SandPattern.values
              .where((p) => p.name == value['pattern'])
              .firstOrNull ??
          defaults.pattern,
      density: share('density', defaults.density),
      grain: share('grain', defaults.grain),
      sparkle: share('sparkle', defaults.sparkle),
      motion:
          SandMotion.values
              .where((m) => m.name == value['motion'])
              .firstOrNull ??
          // Saved when sand could only spring back or stay.
          (value['stays'] == true ? SandMotion.staysPut : defaults.motion),
    );
  }
}

/// The most sands Living Sands lays.
const int kSandMaxCount = 5;

/// The sands until the player picks their own: amber, violet, rose, sea
/// green and bone.
const List<Color> kSandDefaultColors = [
  Color(0xFFE6B872),
  Color(0xFF8C78C8),
  Color(0xFFD98A9C),
  Color(0xFF63B5A6),
  Color(0xFFE6DCC6),
];
