// lib/games/stadium/race_bodies.dart
//
// The six as they are drawn: a party Alchemon or a rival's catalog species,
// its animated sheet at its family's size, and its grains read off the
// sprite once so a fusion station can turn it into its element and back.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/contest_entrant.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/creature_looks.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

/// The box a family-1.0 Alchemon stands in on the track, in world pixels.
const double kRaceFamilyBox = 27;

/// [member] as a racer: its four stats rated 1–5, what the judges see, and
/// its stamina bars as boosts (Dormant's extra bar included).
Racer racerFromMember(
  CosmicPartyMember member,
  CreatureInstance? inst, {
  bool isPlayer = true,
  String? id,
}) => Racer(
  id: id ?? member.instanceId,
  isPlayer: isPlayer,
  entrant: contestEntrantFor(member, inst, CosmicContestTrait.speed),
  ratings: {
    for (final t in CosmicContestTrait.values)
      t: AlchemonStatSystem.legacyGameplayRating(contestStat(member, t)),
  },
  boosts: max(1, member.staminaMax),
);

/// A rival's body: the catalog species of its element and family, drawn
/// with the species' own looks.
CosmicPartyMember? rivalMember(CreatureCatalog catalog, RaceRival rival) {
  final pool = catalog
      .byType(rival.element)
      .where((c) => c.spriteData != null)
      .toList();
  if (pool.isEmpty) return null;
  final c =
      pool.firstWhereOrNull(
        (c) => (c.mutationFamily ?? '').toLowerCase() == rival.family,
      ) ??
      pool.first;
  final sheet = sheetFromCreature(c);
  final looks = visualsFromInstance(c, null);
  return CosmicPartyMember(
    instanceId: 'rival:${rival.name}',
    baseId: c.id,
    displayName: rival.name,
    element: rival.element,
    family: rival.family,
    level: 1,
    statSpeed: rival.speed,
    statIntelligence: rival.intelligence,
    statStrength: rival.strength,
    statBeauty: rival.beauty,
    slotIndex: -1,
    staminaBars: rival.boosts,
    staminaMax: rival.boosts,
    spriteSheet: sheet,
    spriteVisuals: SpriteVisuals(
      scale: rival.scale,
      saturation: looks.saturation,
      brightness: looks.brightness,
      hueShiftDeg: looks.hueShiftDeg,
      isPrismatic: looks.isPrismatic,
      tint: looks.tint,
      elementType: rival.element,
    ),
  );
}

/// [m] as a fusion has made it [element]: the catalog species of that
/// element in its own family (a Fire Mask fused with Water runs on as the
/// Steam Mask), at its own size, still called by its name. Itself when the
/// element is its own; null if the catalog has nothing to draw.
CosmicPartyMember? raceFormMember(
  CreatureCatalog catalog,
  CosmicPartyMember m,
  String element,
) {
  if (element.toLowerCase() == m.element.toLowerCase()) return m;
  final pool = catalog
      .byType(element)
      .where((c) => c.spriteData != null)
      .toList();
  if (pool.isEmpty) return null;
  final c =
      pool.firstWhereOrNull(
        (c) => (c.mutationFamily ?? '').toLowerCase() == m.family.toLowerCase(),
      ) ??
      pool.first;
  final looks = visualsFromInstance(c, null);
  return CosmicPartyMember(
    instanceId: '${m.instanceId}:$element',
    baseId: c.id,
    displayName: m.displayName,
    element: element,
    family: m.family,
    level: m.level,
    statSpeed: m.statSpeed,
    statIntelligence: m.statIntelligence,
    statStrength: m.statStrength,
    statBeauty: m.statBeauty,
    slotIndex: m.slotIndex,
    staminaBars: m.staminaBars,
    staminaMax: m.staminaMax,
    spriteSheet: sheetFromCreature(c),
    spriteVisuals: SpriteVisuals(
      scale: m.spriteVisuals?.scale ?? 1.0,
      saturation: looks.saturation,
      brightness: looks.brightness,
      hueShiftDeg: looks.hueShiftDeg,
      isPrismatic: looks.isPrismatic,
      tint: looks.tint,
      elementType: element,
    ),
  );
}

/// Every form each of the six takes on [course], lane for lane, by element
/// (lower case): its own first, then what each fusion makes it. Load them
/// with the bodies.
List<Map<String, RaceBody>> raceForms(
  CreatureCatalog catalog,
  List<Racer> racers,
  List<RaceBody> bodies,
  RaceCourse course,
) => [
  for (var i = 0; i < racers.length; i++)
    () {
      final own = racers[i].entrant.element.toLowerCase();
      final out = <String, RaceBody>{own: bodies[i]};
      for (final e in raceElements(racers[i].entrant.element, course)) {
        final key = e.toLowerCase();
        if (out.containsKey(key)) continue;
        final m = raceFormMember(catalog, bodies[i].member, e);
        if (m != null) out[key] = RaceBody(m);
      }
      return out;
    }(),
];

/// One of the six as drawn.
class RaceBody {
  RaceBody(this.member);

  final CosmicPartyMember member;
  SpriteAnimationTicker? ticker;

  /// Sheet pixels to world pixels, size gene included.
  double spriteScale = 1;

  /// How tall it stands, in world pixels.
  double height = kRaceFamilyBox;

  /// Its grains, read facing right at world size, centred on the sprite.
  SpecimenGrains? grains;

  /// The frame [grains] was read from, for a finer read later.
  Sprite? _first;

  SpriteVisuals? get looks => member.spriteVisuals;

  /// Loads its sheet and reads its grains. Leaves [ticker] null when it has
  /// no sheet (it is then drawn as a ball of its element).
  Future<void> load(Images images) async {
    final sheet = sheetForVisuals(member.spriteSheet, member.spriteVisuals);
    if (sheet == null) return;
    final image = await loadCreatureSheet(images, sheet.path);
    final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
    final anim = SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.sequenced(
        amount: sheet.totalFrames,
        amountPerRow: cols,
        textureSize: sheet.frameSize,
        stepTime: sheet.stepTime,
        loop: true,
      ),
    );
    ticker = anim.createTicker();
    final box =
        kRaceFamilyBox *
        (kCompanionSpeciesScale[member.family.toLowerCase()] ?? 1.3);
    final frame = max(sheet.frameSize.x, sheet.frameSize.y);
    spriteScale = box / frame * (looks?.scale ?? 1.0);
    height = sheet.frameSize.y * spriteScale;
    _first = anim.frames.first.sprite;
    grains = await _readGrains(_first!);
  }

  /// Its first frame read again, [zoom] times its world size (the night
  /// sky hangs it large), into at most [maxGrains]. Null before [load], or
  /// with no sheet.
  Future<SpecimenGrains?> readFiner({
    double zoom = 4,
    int maxGrains = 2200,
  }) async {
    final sprite = _first;
    if (sprite == null) return null;
    return _readGrains(sprite, zoom: zoom, ratio: 2, maxGrains: maxGrains);
  }

  /// The first frame drawn as it runs (facing right, in its colours, [zoom]
  /// times its world size) and read into grains.
  Future<SpecimenGrains?> _readGrains(
    Sprite sprite, {
    double zoom = 1,
    double ratio = 3.0,
    int maxGrains = 900,
  }) async {
    final w = (sprite.srcSize.x * spriteScale * zoom * ratio).ceil();
    final h = (sprite.srcSize.y * spriteScale * zoom * ratio).ceil();
    if (w <= 0 || h <= 0) return null;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.translate(w / 2, h / 2);
    c.scale(-spriteScale * zoom * ratio, spriteScale * zoom * ratio);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    final v = looks;
    if (v != null) paint.colorFilter = creatureGeneticsFilter(v, 0);
    sprite.render(c, anchor: Anchor.center, overridePaint: paint);
    final image = await rec.endRecording().toImage(w, h);
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return null;
      return SpecimenGrains.fromRgba(
        Uint8List.view(data.buffer),
        w,
        h,
        pixelRatio: ratio,
        maxGrains: maxGrains,
        tones: 16,
      );
    } finally {
      image.dispose();
    }
  }
}

/// The six for [cup]'s race [race] with [player] (and its saved row) in
/// [lane]: racers and bodies, lane for lane. Rivals the catalog cannot draw
/// still race, as balls of their element.
(List<Racer>, List<RaceBody>) raceSix(
  CreatureCatalog catalog,
  RaceCup cup,
  int race,
  CosmicPartyMember player,
  CreatureInstance? inst, {
  int lane = 2,
}) {
  final me = racerFromMember(player, inst);
  final racers = raceField(cup, race, me, lane: lane);
  final bodies = <RaceBody>[];
  var r = 0;
  for (final racer in racers) {
    if (racer.isPlayer) {
      bodies.add(RaceBody(player));
      continue;
    }
    bodies.add(rivalBody(catalog, cup.rivals[r++]));
  }
  return (racers, bodies);
}

/// A rival's body, or a ball of its element if the catalog cannot draw it.
RaceBody rivalBody(CreatureCatalog catalog, RaceRival rival) => RaceBody(
  rivalMember(catalog, rival) ??
      CosmicPartyMember(
        instanceId: 'rival:${rival.name}',
        baseId: '',
        displayName: rival.name,
        element: rival.element,
        family: rival.family,
        level: 1,
        statSpeed: rival.speed,
        statIntelligence: rival.intelligence,
        statStrength: rival.strength,
        statBeauty: rival.beauty,
        slotIndex: -1,
        staminaBars: rival.boosts,
        staminaMax: rival.boosts,
      ),
);

/// A player's racer in a live race (race_room.dart), as drawn: its species
/// in its looks, called by the player's name (a race with friends is
/// theirs) — or by its own with [byPlayer] false.
CosmicPartyMember seatMember(
  CreatureCatalog catalog,
  RaceSeat seat, {
  bool byPlayer = true,
}) {
  final base = catalog.getCreatureById(seat.look.baseId);
  final r = seat.ratings;
  return CosmicPartyMember(
    instanceId: 'live:${seat.uid}',
    baseId: seat.look.baseId,
    displayName: byPlayer ? seat.player : seat.entrant.name,
    element: seat.entrant.element,
    family: seat.entrant.family,
    level: 1,
    statSpeed: r[CosmicContestTrait.speed] ?? 1,
    statIntelligence: r[CosmicContestTrait.intelligence] ?? 1,
    statStrength: r[CosmicContestTrait.strength] ?? 1,
    statBeauty: r[CosmicContestTrait.beauty] ?? 1,
    slotIndex: -1,
    staminaBars: seat.boosts,
    staminaMax: seat.boosts,
    spriteSheet: base?.spriteData != null ? sheetFromCreature(base!) : null,
    spriteVisuals: visualsFromInstance(
      base,
      seat.look.instance('live:${seat.uid}'),
    ),
  );
}
