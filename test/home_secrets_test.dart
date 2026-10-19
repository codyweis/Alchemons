// The home biome taken further: the sky of the player's planet (its look,
// their constellations, the season, and the switches for them), the ground
// remembering who lived where, kept layouts and a framed view, and the
// secrets — harmonies, visitors, buried shards and the Core they open.

import 'package:alchemons/games/wilderness/field/home_sky_art.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/constellation/constellation_layout.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:alchemons/models/home_secrets.dart';
import 'package:alchemons/models/home_sky.dart';
import 'package:alchemons/models/home_visitors.dart';
import 'package:alchemons/screens/home_biome/home_sky_source.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = 86400000;

void main() {
  group('the sky', () {
    test('the seasons follow the months, or are held, or are off', () {
      expect(seasonOf(DateTime(2026, 10, 19)), HomeSeason.autumn);
      expect(seasonOf(DateTime(2026, 1, 2)), HomeSeason.winter);
      expect(seasonOf(DateTime(2026, 4, 2)), HomeSeason.spring);
      expect(seasonOf(DateTime(2026, 7, 2)), HomeSeason.summer);
      final oct = DateTime(2026, 10, 19);
      expect(const HomeSky().seasonAt(oct), HomeSeason.autumn);
      expect(
        const HomeSky(season: HomeSeasonPick.spring).seasonAt(oct),
        HomeSeason.spring,
      );
      expect(const HomeSky(season: HomeSeasonPick.off).seasonAt(oct), isNull);
    });

    test('the switches are kept with the home, only what differs', () {
      expect(const HomeSky().toJson(), isEmpty);
      const sky = HomeSky(
        season: HomeSeasonPick.winter,
        planet: false,
        constellations: false,
        idleCamera: false,
      );
      final back = HomeBiomeLayout.fromJson(
        const HomeBiomeLayout(sky: sky).toJson(),
      );
      expect(back.sky, sky);
      expect(HomeSky.fromJson('nonsense'), const HomeSky());
    });

    test('the planet shows only what it wears to be seen, and can be off', () {
      const planet = PlanetLook(
        color: 'Fire',
        wearing: {'planetary_rings', 'ammo_burst', 'blood_moon'},
        options: {
          'planetary_rings.style': 'Prismatic',
          'ammo_burst.rate': 'Fast',
        },
      );
      const sources = HomeSkySources(
        planet: planet,
        constellations: {'breeder_cross_species'},
      );
      final on = homeSkyLookOf(const HomeSky(), sources);
      expect(on.tint, isNotNull);
      expect(on.wearing, {'planetary_rings', 'blood_moon'});
      expect(on.options, {'planetary_rings.style': 'Prismatic'});
      expect(on.stars, isNotEmpty);
      final off = homeSkyLookOf(
        const HomeSky(planet: false, constellations: false),
        sources,
      );
      expect(off.isEmpty, isTrue);
      expect(HomeSkyArt()..look = on, isNotNull);
    });

    test('the night sky draws the chart\'s own figures, and links what is '
        'owned at both ends', () {
      final layouts = {
        for (final t in ConstellationTree.values) t: constellationTreeLayout(t),
      };
      // Every stone has a place, the same the chart gives it.
      final chart = constellationChartLayout();
      expect(chart.length, ConstellationCatalog.allSkills.length);
      final root = ConstellationCatalog.forTree(
        ConstellationTree.breeder,
      ).firstWhere((s) => s.prerequisites.isEmpty);
      final child = ConstellationCatalog.allSkills.firstWhere(
        (s) => s.prerequisites.contains(root.id),
      );
      final (one, none) = skyStarsFor({root.id}, layouts);
      expect(one, hasLength(1));
      expect(one.single.root, isTrue);
      expect(none, isEmpty);
      final (two, link) = skyStarsFor({root.id, child.id}, layouts);
      expect(two, hasLength(2));
      expect(link, [(0, 1)]);
      for (final s in two) {
        expect(s.x.abs(), lessThanOrEqualTo(1));
        expect(s.y.abs(), lessThanOrEqualTo(1));
      }
    });
  });

  group('the ground remembers', () {
    String? fire(String _) => 'Fire';

    test('it comes in over days, and fades once they have gone', () {
      expect(homeMarkStrength(0, _day ~/ 48), 0);
      expect(homeMarkStrength(0, 3 * _day), inExclusiveRange(0.2, 0.8));
      expect(homeMarkStrength(0, 9 * _day), 1);
      const m = HomeMark(
        realm: 'valley',
        depth: HomeDepth.front,
        x: 0.3,
        element: 'Fire',
        strength: 1,
        left: 0,
      );
      expect(m.strengthAt(_day), closeTo(0.5, 1e-9));
      expect(m.strengthAt(3 * _day), 0);
      expect(HomeMark.fromJson(m.toJson())!.x, 0.3);
    });

    test('who comes settles; who moves or leaves leaves a mark', () {
      const now = 10 * _day;
      var layout = const HomeBiomeLayout(
        residents: [HomeResident(instanceId: 'a', x: 0.2)],
      );
      layout = layout.markedSince(const HomeBiomeLayout(), 0, fire);
      expect(layout.resident('HOME_a')!.since, 0);
      // A week later it moves: the old spot keeps its mark.
      final moved = layout.replace(layout.resident('HOME_a')!.copyWith(x: 0.6));
      final after = moved.markedSince(layout, now, fire);
      expect(after.resident('HOME_a')!.since, now);
      expect(after.marks, hasLength(1));
      expect(after.marks.single.x, 0.2);
      expect(after.marks.single.strength, 1);
      // Nudged a hair, it is still where it was.
      final nudged = after.replace(
        after.resident('HOME_a')!.copyWith(x: 0.605),
      );
      expect(
        nudged.markedSince(after, now + 1, fire).resident('HOME_a')!.since,
        now,
      );
      // It leaves: that spot too; faded marks are let go.
      final gone = after
          .copyWith(residents: const [])
          .markedSince(after, now + 7 * _day, fire);
      expect(gone.marks.map((m) => m.x), [0.6]);
    });
  });

  group('harmonies', () {
    String? element(String id) => switch (id) {
      'f' => 'Fire',
      'w' => 'Water',
      'e' => 'Earth',
      _ => null,
    };

    test('a night has passed once the small hours come round', () {
      final evening = DateTime(2026, 10, 19, 21).millisecondsSinceEpoch;
      expect(
        nightBetween(
          evening,
          DateTime(2026, 10, 19, 23).millisecondsSinceEpoch,
        ),
        isFalse,
      );
      expect(
        nightBetween(
          evening,
          DateTime(2026, 10, 20, 3, 1).millisecondsSinceEpoch,
        ),
        isTrue,
      );
      final small = DateTime(2026, 10, 20, 2).millisecondsSinceEpoch;
      expect(
        nightBetween(small, DateTime(2026, 10, 20, 4).millisecondsSinceEpoch),
        isTrue,
      );
    });

    test('two sharing ground whose elements fuse, through a night', () {
      final since = DateTime(2026, 10, 19, 20).millisecondsSinceEpoch;
      final morning = DateTime(2026, 10, 20, 9).millisecondsSinceEpoch;
      final layout = HomeBiomeLayout(
        residents: [
          HomeResident(instanceId: 'f', x: 0.3, since: since),
          HomeResident(
            instanceId: 'w',
            x: 0.32,
            beside: 'HOME_f',
            since: since,
          ),
          HomeResident(instanceId: 'e', x: 0.7, since: since),
        ],
      );
      expect(sharingPairs(layout), hasLength(1));
      final formed = formedHarmonies(layout, morning, element);
      expect(formed.single.makes, 'Steam');
      expect(formed.single.key, 'Fire+Water');
      // Not before the night is out.
      expect(formedHarmonies(layout, since + 3600000, element), isEmpty);
      expect(
        formedHarmonies(layout, since + 3600000, element, always: true),
        hasLength(1),
      );
      expect(kHarmonies.length, 41);
    });

    test('what has been found is kept, and nonsense dropped', () {
      const s = HomeSecrets(
        harmonies: {'Fire+Water'},
        visitors: {'wraithord'},
        buried: {'valley'},
      );
      final back = HomeSecrets.fromJson(s.toJson());
      expect(back.harmonies, {'Fire+Water'});
      expect(back.visitors, {'wraithord'});
      expect(back.buried, {'valley'});
      expect(
        HomeSecrets.fromJson({
          'harmonies': ['Fire+Water', 'Cheese+Wine'],
        }).harmonies,
        {'Fire+Water'},
      );
    });
  });

  group('visitors', () {
    HomeMoment at({
      HomeRealm realm = HomeRealm.arcane,
      String mood = 'clear',
      double hour = 23,
      HomeSeason? season,
      double moon = 0.5,
      Set<String> makes = const {'Spirit'},
    }) => HomeMoment(
      realm: realm,
      mood: mood,
      hour: hour,
      season: season,
      moon: moon,
      makes: makes,
    );

    test('one comes only when everything that brings it is true', () {
      expect(visitorAt(at())?.id, 'wraithord');
      expect(visitorAt(at(moon: 0.3)), isNull, reason: 'not full');
      expect(visitorAt(at(hour: 13)), isNull, reason: 'by day');
      expect(visitorAt(at(realm: HomeRealm.valley)), isNull);
      expect(visitorAt(at(makes: const {'Steam'})), isNull);
      expect(visitorAt(at(makes: const {'Steam'}), anyway: true), isNull);
      expect(visitorAt(at(moon: 0.3), anyway: true)?.id, 'wraithord');
      expect(
        visitorAt(
          at(realm: HomeRealm.sky, mood: 'storm', makes: const {'Lightning'}),
        )?.id,
        'raikuma',
      );
      expect(
        visitorAt(at(hour: 6, moon: 0.2, makes: const {'Light'}))?.id,
        'solarin',
      );
      expect(moonNew(0.01), isTrue);
      expect(moonNew(0.5), isFalse);
      // Each a Mystic of its element.
      expect({for (final v in kHomeVisitors) v.speciesId}, hasLength(8));
    });

    test('a visitor met leaves its likeness on the shelf', () {
      final v = visitorById('wraithord')!;
      final k = Keepsake.visitorEffigy(v, 'Wraithord');
      expect(k.id, 'effigy:MYS14');
      expect(k.isEffigy, isTrue);
    });
  });

  group('buried', () {
    test('each realm shows its place only in its own moment', () {
      final now = DateTime(2026, 10, 19, 12);
      expect(buriedShows(HomeRealm.valley, 'rainbow', now), isTrue);
      expect(buriedShows(HomeRealm.valley, 'clear', now), isFalse);
      expect(buriedShows(HomeRealm.swamp, 'dry', now), isTrue);
      expect(buriedShows(HomeRealm.volcano, 'erupting', now), isTrue);
      expect(buriedShows(HomeRealm.core, 'still', now), isFalse);
      for (final r in HomeRealm.values) {
        expect(buriedAt(r), inInclusiveRange(0, 1));
      }
    });

    test('the five first shards open the Core', () {
      expect(coreOpens(const HomeSecrets()), isFalse);
      expect(
        coreOpens(
          const HomeSecrets(buried: {'valley', 'sky', 'swamp', 'volcano'}),
        ),
        isFalse,
      );
      expect(
        coreOpens(
          const HomeSecrets(
            buried: {'valley', 'sky', 'swamp', 'volcano', 'arcane'},
          ),
        ),
        isTrue,
      );
    });

    test('a shard is a keepsake of its realm, drawn in its light', () {
      final k = Keepsake.byId('core_shard:valley')!;
      expect(k.title, 'Verdant Valley Shard');
      expect(k.source, KeepsakeSource.buried);
      for (final r in HomeRealm.values.where((r) => r.buries)) {
        expect(KeepsakeArt.of('core_shard:${r.name}'), isNotNull);
        expect(kShardLightOrder, contains(r.name));
      }
    });
  });

  group('forms', () {
    test('a realm all of one element is held, and turns over its week', () {
      String? dark(String _) => 'Dark';
      final twelve = [
        for (var i = 0; i < kHomeBiomeMaxResidents; i++)
          HomeResident(instanceId: 'd$i', x: i / 12),
      ];
      final full = HomeBiomeLayout(
        residents: twelve,
      ).markedSince(const HomeBiomeLayout(), 1000, dark);
      expect(full.hold?.element, 'Dark');
      expect(full.hold?.since, 1000);
      // Moving them about does not start it again.
      final moved = full
          .replace(full.residents.first.copyWith(x: 0.5))
          .markedSince(full, 5000, dark);
      expect(moved.hold?.since, 1000);
      // One of another element and it is not held.
      final broken = moved.markedSince(
        moved,
        6000,
        (id) => id == 'd3' ? 'Fire' : 'Dark',
      );
      expect(broken.hold, isNull);
      // Eleven is not every place.
      final eleven = full
          .copyWith(residents: twelve.take(11).toList())
          .markedSince(full, 7000, dark);
      expect(eleven.hold, isNull);
      // Elements not known here (a realm not entered yet): left as it was.
      expect(full.markedSince(full, 8000, (_) => null).hold?.since, 1000);
      expect(HomeBiomeLayout.fromJson(full.toJson()).hold?.element, 'Dark');
    });

    test('a division\'s elements together hold it; Dark, Light and Blood '
        'alone; Spirit nothing', () {
      HomeBiomeLayout of(List<String> elements) {
        final rs = [
          for (var i = 0; i < kHomeBiomeMaxResidents; i++)
            HomeResident(instanceId: 'r$i', x: i / 12),
        ];
        return HomeBiomeLayout(residents: rs).markedSince(
          const HomeBiomeLayout(),
          0,
          (id) => elements[int.parse(id.substring(1)) % elements.length],
        );
      }

      expect(of(['Fire', 'Lava', 'Lightning']).hold?.element, 'Volcanic');
      expect(of(['Water', 'Ice', 'Steam']).hold?.element, 'Oceanic');
      expect(of(['Earth', 'Mud', 'Dust', 'Crystal']).hold?.element, 'Earthen');
      expect(of(['Air', 'Plant', 'Poison']).hold?.element, 'Verdant');
      expect(of(['Light']).hold?.element, 'Light');
      expect(of(['Blood']).hold?.element, 'Blood');
      expect(of(['Fire', 'Water']).hold, isNull);
      expect(of(['Dark', 'Light']).hold, isNull);
      expect(of(['Spirit']).hold, isNull);
      expect(kHomeForms, hasLength(7));
      for (final f in kHomeForms) {
        expect(HomeRealm.valley.mood('form:$f').form, f);
      }
    });

    test('nothing for six days, then over the seventh', () {
      expect(homeFormDeep(0, 5 * _day), 0);
      expect(homeFormDeep(0, 6 * _day + _day ~/ 2), closeTo(0.5, 1e-9));
      expect(homeFormDeep(0, 7 * _day), 1);
    });

    test('a form earned is a mood of its realm, and shows fully', () {
      final mood = HomeRealm.valley.mood('form:Dark');
      expect(mood.form, 'Dark');
      expect(mood.label, 'DARK');
      expect(HomeRealm.valley.mood('form:Cheese').id, 'clear');
      const s = HomeSecrets(forms: {'valley:Dark'});
      expect(s.formsOf(HomeRealm.valley).single.id, 'form:Dark');
      expect(s.formsOf(HomeRealm.sky), isEmpty);
      expect(HomeSecrets.fromJson(s.toJson()).forms, {'valley:Dark'});
      final chosen = const HomeBiomeLayout().withMood('form:Dark');
      expect(homeFormOf(chosen, 0), ('Dark', 1.0));
      final held = const HomeBiomeLayout().copyWith(
        holds: {'valley': const HomeHold('Dark', 0)},
      );
      expect(homeFormOf(held, 3 * _day), ('Dark', 0.0));
      expect(homeFormOf(held, 3 * _day, full: true), ('Dark', 1.0));
      expect(homeFormOf(const HomeBiomeLayout(), 0), (null, 0.0));
    });
  });

  group('layouts and a framed view', () {
    test('a realm kept, changed, and taken back', () {
      const first = HomeBiomeLayout(
        residents: [HomeResident(instanceId: 'a', x: 0.2, since: 5)],
        moods: {'valley': 'rain'},
      );
      final kept = first.keepArrangement(1);
      expect(kept.arrangementsHere[0], isNull);
      expect(kept.arrangementsHere[1]!.residents.single.since, isNull);
      final changed = kept
          .copyWith(residents: const [HomeResident(instanceId: 'b')])
          .withMood('snow');
      final back = changed.takeArrangement(1);
      expect(back.residents.single.instanceId, 'a');
      expect(back.mood.id, 'rain');
      expect(changed.takeArrangement(0).residents.single.instanceId, 'b');
      final json = HomeBiomeLayout.fromJson(kept.toJson());
      expect(json.arrangementsHere[1]!.residents.single.instanceId, 'a');
    });

    test('a framed view is kept per realm and travels to friends', () {
      final layout = const HomeBiomeLayout().copyWith(
        frames: {'valley': const HomeFrame(0.25, 1.4)},
      );
      final back = HomeBiomeLayout.fromJson(layout.toJson());
      expect(back.frame!.x, 0.25);
      expect(back.frame!.zoom, 1.4);
      final home = FriendHome(
        layout: layout,
        planet: const PlanetLook(color: 'Water', wearing: {'blood_moon'}),
        constellations: const {'breeder_cross_species'},
      );
      final read = FriendHome.decode(home.encode())!;
      expect(read.layout.frame!.zoom, 1.4);
      expect(read.planet!.color, 'Water');
      expect(read.constellations, {'breeder_cross_species'});
    });
  });
}
