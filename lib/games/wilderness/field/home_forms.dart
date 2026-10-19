part of 'grain_field.dart';

// The forms a home realm's land takes (models/home_biome.dart, HomeHold):
// filled with Alchemons of one division's elements — Volcanic, Oceanic,
// Earthen, Verdant — or all Dark, all Light, all Blood, the land takes it
// at once ([FieldArt.formCast]) and over a week turns into its form
// ([FieldArt.formDeep]).
//
// Each realm takes a form its own way: it says what each of its parts is
// (its leaves, its turf, its rock, its water, its sand, its crystals — a
// [_Mat]), and each form says what such a part becomes. What else is its
// own — the Volcano's lava, the Tidal Shelf's light in the waves, the
// Geode's crystals and the light down its cracks, the Arcane's hole — each
// form has its own of, too. Over all of it the form has its light (the
// sky, the ambient light, the rim, the grass, the motes), and in its form
// its sign in the sky: an eclipse for Dark, a halo for Light, a blood moon
// for Blood, a glow of lava round the horizon for Volcanic, a mist for
// Oceanic, dust on the high wind for Earthen, seeds on it for Verdant.

/// What a part of a realm is, for what a form makes of it.
enum _Mat { far, foliage, wood, cover, soil, rock, water, sand, crystal }

/// What each form makes of each kind of part, in daylight.
const Map<String, Map<_Mat, Color>> _formPalette = {
  'Dark': {
    _Mat.far: Color(0xFF2A2640),
    _Mat.foliage: Color(0xFF120F1C),
    _Mat.wood: Color(0xFF1A1620),
    _Mat.cover: Color(0xFF26223A),
    _Mat.soil: Color(0xFF221E2E),
    _Mat.rock: Color(0xFF34304A),
    _Mat.water: Color(0xFF05030A),
    _Mat.sand: Color(0xFF27232F),
    _Mat.crystal: Color(0xFF3A2266),
  },
  'Light': {
    _Mat.far: Color(0xFFB8B4C8),
    _Mat.foliage: Color(0xFFD8CC94),
    _Mat.wood: Color(0xFFA89878),
    _Mat.cover: Color(0xFFC8C890),
    _Mat.soil: Color(0xFFC8BC98),
    _Mat.rock: Color(0xFFD8D0C0),
    _Mat.water: Color(0xFF9AD0F0),
    _Mat.sand: Color(0xFFF0E8D4),
    _Mat.crystal: Color(0xFFFFF4D8),
  },
  'Blood': {
    _Mat.far: Color(0xFF4A2030),
    _Mat.foliage: Color(0xFF5A121C),
    _Mat.wood: Color(0xFF3A1418),
    _Mat.cover: Color(0xFF6A1A24),
    _Mat.soil: Color(0xFF4A1A1E),
    _Mat.rock: Color(0xFF4A2A2C),
    _Mat.water: Color(0xFF3A060E),
    _Mat.sand: Color(0xFF6A2A24),
    _Mat.crystal: Color(0xFF8A1428),
  },
  'Volcanic': {
    _Mat.far: Color(0xFF3A2A2A),
    _Mat.foliage: Color(0xFF2A1A14),
    _Mat.wood: Color(0xFF1E1410),
    _Mat.cover: Color(0xFF3A2418),
    _Mat.soil: Color(0xFF2A1E1A),
    _Mat.rock: Color(0xFF2A2222),
    _Mat.water: Color(0xFF3A3434),
    _Mat.sand: Color(0xFF5A5250),
    _Mat.crystal: Color(0xFFE8702A),
  },
  'Oceanic': {
    _Mat.far: Color(0xFF3A5A70),
    _Mat.foliage: Color(0xFF2A5A5A),
    _Mat.wood: Color(0xFF2A3A40),
    _Mat.cover: Color(0xFF3A7070),
    _Mat.soil: Color(0xFF4A5A60),
    _Mat.rock: Color(0xFF3A4A52),
    _Mat.water: Color(0xFF2A7A8A),
    _Mat.sand: Color(0xFF8A9AA0),
    _Mat.crystal: Color(0xFF8AE0F0),
  },
  'Earthen': {
    _Mat.far: Color(0xFF8A6A50),
    _Mat.foliage: Color(0xFF7A6230),
    _Mat.wood: Color(0xFF5A4028),
    _Mat.cover: Color(0xFF9A7A40),
    _Mat.soil: Color(0xFF8A5A30),
    _Mat.rock: Color(0xFF7A5A40),
    _Mat.water: Color(0xFF5A4028),
    _Mat.sand: Color(0xFFB0703A),
    _Mat.crystal: Color(0xFF4AD8B0),
  },
  'Verdant': {
    _Mat.far: Color(0xFF3A6A50),
    _Mat.foliage: Color(0xFF2E6A30),
    _Mat.wood: Color(0xFF3A3A20),
    _Mat.cover: Color(0xFF4A8A3A),
    _Mat.soil: Color(0xFF3A5A2A),
    _Mat.rock: Color(0xFF4A6A4A),
    _Mat.water: Color(0xFF2A5A3A),
    _Mat.sand: Color(0xFF7A8A4A),
    _Mat.crystal: Color(0xFF8AF06A),
  },
};

/// What a form does to the land's light.
class _FormLight {
  const _FormLight({
    required this.skyLo,
    required this.skyHi,
    this.skyCast = 0.3,
    this.skyDeep = 0.5,
    required this.ambient,
    this.ambientCast = 0.55,
    this.ambientDeep = 0.25,
    this.floor,
    required this.rim,
    this.glow = 0,
    this.starsUp = 0,
    this.starsDim = 0,
    required this.grassLo,
    required this.grassHi,
    required this.mote,
    this.firefly = 0,
  });

  /// The sky toward [skyLo] where it is dark and [skyHi] where it is
  /// light — this far at once, and this much more in its form.
  final Color skyLo, skyHi;
  final double skyCast, skyDeep;

  /// The ambient light multiplied by these (red, green, blue), this far at
  /// once and this much more in its form; in its form, never darker than
  /// [floor] (Light: no night is all dark).
  final (double, double, double) ambient;
  final double ambientCast, ambientDeep;
  final Color? floor;

  /// The light catching edges.
  final Color rim;

  /// How much brighter (or, below 0, dimmer) the sun's glow; how far the
  /// stars come out by day, or fade by night.
  final double glow, starsUp, starsDim;

  /// The grass from root to tip.
  final Color grassLo, grassHi;

  /// The motes, and how much they are lights, in its form (embers, light
  /// motes, wisps — or, at 0, dust and pollen).
  final Color mote;
  final double firefly;
}

const Map<String, _FormLight> _formLights = {
  'Dark': _FormLight(
    skyLo: Color(0xFF07040E),
    skyHi: Color(0xFF3A2766),
    skyDeep: 0.55,
    ambient: (0.5, 0.45, 0.72),
    ambientCast: 0.6,
    rim: Color(0xFFB89AFF),
    glow: -0.45,
    starsUp: 0.65,
    grassLo: Color(0xFF16121F),
    grassHi: Color(0xFF7A5AC8),
    mote: Color(0xFFB08AF0),
    firefly: 1,
  ),
  'Light': _FormLight(
    skyLo: Color(0xFF2A2C4A),
    skyHi: Color(0xFFFFF4DC),
    skyCast: 0.25,
    skyDeep: 0.4,
    ambient: (1.15, 1.1, 0.98),
    floor: Color(0xFF6A6658),
    rim: Color(0xFFFFF0C8),
    glow: 0.5,
    starsDim: 0.6,
    grassLo: Color(0xFF5A6A3A),
    grassHi: Color(0xFFFFF0B0),
    mote: Color(0xFFFFF0C0),
    firefly: 1,
  ),
  'Blood': _FormLight(
    skyLo: Color(0xFF12040A),
    skyHi: Color(0xFF8A2030),
    ambient: (0.85, 0.5, 0.55),
    ambientCast: 0.6,
    ambientDeep: 0.2,
    rim: Color(0xFFFF7A7A),
    glow: -0.2,
    starsUp: 0.35,
    grassLo: Color(0xFF2A0A10),
    grassHi: Color(0xFFC83040),
    mote: Color(0xFFE04050),
    firefly: 0.6,
  ),
  'Volcanic': _FormLight(
    skyLo: Color(0xFF1A0A06),
    skyHi: Color(0xFFB8603A),
    skyDeep: 0.45,
    ambient: (1.0, 0.7, 0.55),
    ambientCast: 0.5,
    rim: Color(0xFFFFA060),
    glow: 0.1,
    grassLo: Color(0xFF1A1210),
    grassHi: Color(0xFFE8702A),
    mote: Color(0xFFFFA04A),
    firefly: 1,
  ),
  'Oceanic': _FormLight(
    skyLo: Color(0xFF061420),
    skyHi: Color(0xFF7AC8E0),
    skyCast: 0.25,
    skyDeep: 0.4,
    ambient: (0.75, 0.9, 1.05),
    ambientCast: 0.5,
    ambientDeep: 0.2,
    rim: Color(0xFFA8E8FF),
    glow: -0.2,
    grassLo: Color(0xFF0E3A3A),
    grassHi: Color(0xFF6AD8C8),
    mote: Color(0xFFBFEFFF),
    firefly: 0.6,
  ),
  'Earthen': _FormLight(
    skyLo: Color(0xFF140C06),
    skyHi: Color(0xFFD8A060),
    skyCast: 0.25,
    skyDeep: 0.4,
    ambient: (1.05, 0.88, 0.65),
    ambientCast: 0.5,
    ambientDeep: 0.2,
    rim: Color(0xFFFFD08A),
    grassLo: Color(0xFF3A2A14),
    grassHi: Color(0xFFD8B060),
    mote: Color(0xFFE8C080),
  ),
  'Verdant': _FormLight(
    skyLo: Color(0xFF061408),
    skyHi: Color(0xFFA8E0A0),
    skyCast: 0.2,
    skyDeep: 0.35,
    ambient: (0.85, 1.05, 0.8),
    ambientCast: 0.45,
    ambientDeep: 0.2,
    rim: Color(0xFFC8FFB0),
    grassLo: Color(0xFF143A14),
    grassHi: Color(0xFF8AF06A),
    mote: Color(0xFFC8F07A),
    firefly: 0.4,
  ),
};

/// The sign of each form in the sky, in its form (drawn as the planet's
/// looks are, home_sky_art.dart). Dark's is the eclipse, drawn by the sun.
const Map<String, Set<String>> _formSky = {
  'Light': {'radiant_halo'},
  'Blood': {'blood_moon'},
  'Volcanic': {'lava_moat'},
  'Oceanic': {'ocean_mist'},
  'Earthen': {'dust_storm'},
  'Verdant': {'vine_tendrils'},
};

/// The Volcano's lava in each form: its running color and its hot cores.
const Map<String, (Color, Color)> _formLava = {
  'Dark': (Color(0xFF7A2EE8), Color(0xFFE8B8FF)),
  'Light': (Color(0xFFFFC870), Color(0xFFFFFFF0)),
  'Blood': (Color(0xFFB0102A), Color(0xFFFF7A7A)),
  'Volcanic': (Color(0xFFFF7A1C), Color(0xFFFFF4A0)),
  'Oceanic': (Color(0xFF2A9AE8), Color(0xFFC0F4FF)),
  'Earthen': (Color(0xFFC8862A), Color(0xFFFFE0A8)),
  'Verdant': (Color(0xFF4ACC3A), Color(0xFFE0FF9A)),
};

/// The light breaking waves give off at night, in each form.
const Map<String, Color> _formWaveGlow = {
  'Dark': Color(0xFFB08AF0),
  'Light': Color(0xFFFFE8A0),
  'Blood': Color(0xFFFF4A5A),
  'Volcanic': Color(0xFFFF9A4A),
  'Oceanic': Color(0xFF6CF2FF),
  'Earthen': Color(0xFFE8B86A),
  'Verdant': Color(0xFF8AF08A),
};

/// The Geode's crystals' own light in each form: amethyst, quartz, ice.
const Map<String, (Color, Color, Color)> _formCrystalGlow = {
  'Dark': (Color(0xFF8A4CFF), Color(0xFF8E7ACC), Color(0xFF6A6AD8)),
  'Light': (Color(0xFFFFF0B0), Color(0xFFFFFFFF), Color(0xFFFFF4D8)),
  'Blood': (Color(0xFFFF3A4A), Color(0xFFE87A80), Color(0xFFC84060)),
  'Volcanic': (Color(0xFFFF8A3A), Color(0xFFFFC08A), Color(0xFFFF6A2A)),
  'Oceanic': (Color(0xFF6AD8FF), Color(0xFFC8F4FF), Color(0xFFA8F0FF)),
  'Earthen': (Color(0xFF4AE8C0), Color(0xFFE8D0A0), Color(0xFF6AE8D0)),
  'Verdant': (Color(0xFF8AF06A), Color(0xFFD8FFC0), Color(0xFFA8FF8A)),
};

/// The light coming down the Geode's cracks in each form.
const Map<String, Color> _formShaft = {
  'Dark': Color(0xFF9A7ADC),
  'Light': Color(0xFFFFF4D0),
  'Blood': Color(0xFFFF6A6A),
  'Volcanic': Color(0xFFFFA060),
  'Oceanic': Color(0xFF9AE0FF),
  'Earthen': Color(0xFFFFD08A),
  'Verdant': Color(0xFFC8FFA0),
};
