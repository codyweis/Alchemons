// SABLIS, IN GLASS — the states Dust's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Dust`; this is the STATES. The kept tally is shot from a
// game where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (DustGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dust.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Dust', 'Earth', 'Air'];
  const fams = ['horn', 'mask', 'wing'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: fams[i],
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: 'Dust',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Dust']!.rooms[roomId]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
  g.entryDoorRevealed = true;
  g.currentRoomId = roomId;
  final stand = Offset(b.left + 60, b.bottom - 40);
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = stand
        ..lastSafe = stand,
    );
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every state the ruins\' glass shows', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId, {
        void Function(PlanetDungeonGame g)? setup,
        double seconds = 0.4,
        int stars = 0,
      }) async {
        final g = await _game(roomId, stars: stars);
        setup?.call(g);
        for (var i = 0; i < (seconds * 60).round(); i++) {
          g.update(1 / 60);
        }
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(
          g.size.x.round(),
          g.size.y.round(),
        );
        if (out.existsSync()) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/room_audit/DustGlass_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = raw!.buffer.asUint8List();
        var hash = 17;
        for (var i = 0; i < bytes.length; i += 97) {
          hash = (hash * 31 + bytes[i]) & 0x3FFFFFFF;
        }
        shots[name] = hash;
      }

      // A mound's tag: buried, bared, drifted.
      await shoot('terrace_buried', 'high_terrace');
      await shoot(
        'terrace_bared',
        'high_terrace',
        setup: (g) => g.ruins.mound['m_kiln'] = 0,
      );
      await shoot(
        'terrace_drifted',
        'high_terrace',
        setup: (g) => g.ruins.mound['m_kiln'] = 2,
      );

      // The seal yard as authored, and with the seals kept bare.
      await shoot('seals', 'seal_street');
      await shoot(
        'seals_kept',
        'seal_street',
        setup: (g) {
          g.ruins
            ..sealsKept = true
            ..reset();
        },
      );

      // The court: the great glass still, then turned; a vane wound.
      await shoot('court', 'sand_court');
      await shoot(
        'court_turned',
        'sand_court',
        setup: (g) => g.conduitEnergy['B'] = 1,
      );
      await shoot(
        'court_vane_wound',
        'sand_court',
        setup: (g) {
          g.ruins
            ..armedVaneRoom = 'sand_court'
            ..armedVaneTimer = 4;
        },
      );

      // The granary: cold, the rite binding, and the tally kept.
      await shoot('granary', 'granary');
      await shoot(
        'granary_rite',
        'granary',
        setup: (g) => g.beginMaximRite(
          kDustNothingPerishesEggId,
          g.layout.rooms['granary']!.ruins!.tallyCist!,
        ),
        seconds: 1.2,
      );
      await shoot(
        'granary_kept',
        'granary',
        setup: (g) => g.discoveredClouds.add(kDustNothingPerishesEggId),
      );

      // THE TRADE, SEEN (2026-09-25): standing on the roof's east stone
      // previews the pit here and the dune on the bump; pressing plays the
      // dig, the flight and the heap rising. The agora's stones send sand
      // next door, through a doorway.
      final roof = kDustMounds.firstWhere((m) => m.id == 'm_roof').streetPos;
      final eastStone = roof + moundChoiceOffset(const Offset(1, 0));
      void stand(PlanetDungeonGame g, Offset at) {
        final i = g.creatures.indexWhere((c) => c.member.element == 'Dust');
        g.setActive(i);
        g.creatures[i]
          ..position = at
          ..lastSafe = at;
      }

      await shoot(
        'trade_preview',
        'roof_walk',
        setup: (g) => stand(g, eastStone),
      );
      for (final (name, secs) in const [
        ('trade_dig', 0.3),
        ('trade_flight', 0.8),
        ('trade_landing', 1.5),
        ('trade_settled', 2.5),
      ]) {
        await shoot(
          name,
          'roof_walk',
          setup: (g) {
            stand(g, eastStone);
            g.activateAbility();
          },
          seconds: secs,
        );
      }
      final agora = kDustMounds.firstWhere((m) => m.id == 'm_agora').streetPos;
      await shoot(
        'trade_next_door',
        'seal_street',
        setup: (g) => stand(g, agora + moundChoiceOffset(const Offset(-1, 0))),
      );
      for (final (name, secs) in const [
        ('trade_next_door_flight', 0.6),
        ('trade_next_door_pour', 1.6),
        ('trade_next_door_heap', 2.3),
        ('trade_next_door_pan', 2.8),
        ('trade_next_door_choke', 3.4),
        ('trade_next_door_blocked', 4.4),
      ]) {
        await shoot(
          name,
          'seal_street',
          setup: (g) {
            stand(g, agora + moundChoiceOffset(const Offset(-1, 0)));
            g.activateAbility();
          },
          seconds: secs,
        );
      }

      // THE OBSERVATORY: sealed, the roof dug, both sights open (the star
      // forming, then formed), and won.
      await shoot('obs_sealed', 'observatory');
      await shoot(
        'obs_roof',
        'observatory',
        setup: (g) => g.ruins.mound['m_roof'] = 0,
      );
      await shoot(
        'obs_star_forming',
        'observatory',
        setup: (g) {
          g.update(1 / 60); // seen unsolved first, so the star eases in
          g.ruins.mound['m_roof'] = 0;
          g.ruins.mound['m_kiln'] = 0;
        },
        seconds: 0.8,
      );
      await shoot(
        'obs_star',
        'observatory',
        setup: (g) {
          g.update(1 / 60);
          g.ruins.mound['m_roof'] = 0;
          g.ruins.mound['m_kiln'] = 0;
        },
        seconds: 2.4,
      );
      await shoot('obs_won', 'observatory', stars: 0x2);

      for (final (a, b) in const [
        ('terrace_buried', 'terrace_bared'),
        ('terrace_bared', 'terrace_drifted'),
        ('seals', 'seals_kept'),
        ('court', 'court_turned'),
        ('court', 'court_vane_wound'),
        ('granary', 'granary_rite'),
        ('obs_sealed', 'obs_roof'),
        ('obs_star_forming', 'obs_star'),
        ('obs_star', 'obs_won'),
        ('granary_rite', 'granary_kept'),
      ]) {
        expect(
          shots[a] != shots[b],
          isTrue,
          reason: '$a and $b draw the same picture',
        );
      }
    });
  });
}
