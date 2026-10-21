@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/battle_link.dart';
import 'package:alchemons/games/cosmic/battle_wire.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/models/friend_home.dart' show PlanetLook;
import 'package:alchemons/screens/battle/battle_journey.dart';
import 'package:alchemons/screens/battle/battle_live.dart';
import 'package:alchemons/screens/battle/battle_screen.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

// A live battle on two phones, side by side: the host's screen (left) runs
// the fight, the guest's (right) shows it through a fake network with
// Firestore's delays. Each sees their own four at the bottom. Both come in
// by the host's planet and home (this save's home, pictured as the lobby
// does), and the host goes out the same way at the end.
//
//   BATTLE_LIVE_OUT=/tmp/live flutter test test/battle_live_preview_test.dart \
//     --tags preview
//   [BATTLE_LIVE_FILM=15 [BATTLE_LIVE_SECONDS=20]]  frames into <out>/film
//   [BATTLE_HOME=Horn:Fire,...] [BATTLE_AWAY=...]
//   [BATTLE_LIVE_PLANET=Water]  the host's planet colour (none: no planet)
//   [BATTLE_LIVE_NO_HOME=1]     no home picture
//
//   ffmpeg -framerate 15 -i <out>/film/f%04d.png -pix_fmt yuv420p live.mp4

/// The network between the two phones, on the test's clock.
class _Net {
  int wall = 0;

  /// The fight's start, on [wall].
  int startAt = 0;

  /// The phones' clock: an epoch, moved on by [wall].
  static const int epoch = 1760000000000;
  final Random rng = Random(3);
  final List<(int, void Function())> _queue = [];

  void send(void Function() arrive) =>
      _queue.add((wall + 150 + rng.nextInt(300), arrive));

  void deliver() {
    _queue.sort((a, b) => a.$1.compareTo(b.$1));
    while (_queue.isNotEmpty && _queue.first.$1 <= wall) {
      _queue.removeAt(0).$2();
    }
  }
}

class _FakeLive implements BattleLive {
  _FakeLive(this.net, {required this.hosting, required this.friendName});

  final _Net net;
  @override
  final bool hosting;
  @override
  final String friendName;
  BattleHostLink? host;
  BattleGuestLink? guest;
  _FakeLive? other;

  @override
  int get startAtMs => _Net.epoch + net.startAt;

  @override
  int nowMs() => _Net.epoch + net.wall;

  @override
  CosmicBattle begin(
    CosmicGame game, {
    required List<CosmicPartyMember> team,
    required List<CosmicPartyMember> rival,
    required String arena,
  }) {
    if (hosting) {
      final h = host = BattleHostLink(
        game: game,
        now: () => net.wall,
        send: (seq, p) => net.send(() => other?.guest?.packet(seq, p)),
      );
      return game.startBattle(
        home: team,
        away: rival,
        awayAuto: false,
        center: game.ship.pos,
        arena: arena,
        tape: h.tape,
      );
    }
    final g = guest = BattleGuestLink(
      now: () => net.wall,
      send: (inputs, beat) => net.send(() => other?.host?.heard(inputs, beat)),
    );
    return game.startBattle(
      home: team,
      away: rival,
      center: game.ship.pos,
      arena: arena,
      replica: g.playback,
    );
  }

  @override
  int send(BattleInput input) => guest?.input(input) ?? -1;

  @override
  void tick(CosmicGame game) {
    if (hosting) net.deliver();
    host?.tick();
    guest?.tick(game);
  }

  @override
  bool get waiting => guest?.waiting ?? false;
  @override
  bool get friendAway => host?.away ?? false;
  @override
  Future<void> finished(CosmicBattle battle) async {}
  @override
  void concede(CosmicGame game) {}
  @override
  void rematch() {}
  @override
  void dispose() {}
}

void main() {
  final out = Platform.environment['BATTLE_LIVE_OUT'];

  setUpAll(loadLobbyFonts);

  testWidgets('a live battle on two phones', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    // Two phones side by side.
    tester.view.physicalSize = Size(
      kLobbyPhysical.width * 2,
      kLobbyPhysical.height,
    );
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    final phone = kLobbyPhysical / kLobbyDpr;

    final save = await LobbySave.create(tester, fresh: true);
    CosmicPartyMember member(String spec, int slot, String tag) {
      final [family, element] = spec.split(':');
      final c = save.catalog.creatures.firstWhere(
        (c) =>
            (c.mutationFamily ?? '').toLowerCase() == family.toLowerCase() &&
            c.types.isNotEmpty &&
            c.types.first == element &&
            c.spriteData != null,
        orElse: () => save.catalog.creatures.firstWhere(
          (c) =>
              (c.mutationFamily ?? '').toLowerCase() == family.toLowerCase() &&
              c.spriteData != null,
        ),
      );
      return _member(c, slot, tag);
    }

    List<CosmicPartyMember> team(String env, String fallback, String tag) {
      final specs = (Platform.environment[env] ?? fallback).split(',');
      return [for (var i = 0; i < specs.length; i++) member(specs[i], i, tag)];
    }

    final hostFour = team(
      'BATTLE_HOME',
      'Horn:Fire,Wing:Dust,Kin:Water,Mane:Lightning',
      'h',
    );
    final guestFour = team(
      'BATTLE_AWAY',
      'Mask:Air,Let:Ice,Wing:Light,Pip:Earth',
      'g',
    );
    // The host's place, pictured as the lobby pictures it.
    BattleJourneyArt? prepared;
    if (Platform.environment['BATTLE_LIVE_NO_HOME'] != '1') {
      await tester.pumpWidget(
        save.app(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(size: phone),
              child: BattleJourneyPrep(
                host: 'a',
                hostName: 'Ann',
                mine: true,
                onReady: (art) => prepared = art,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 200 && prepared == null; i++) {
        await settleLobby(tester, 1);
      }
    }
    final planetColour = Platform.environment['BATTLE_LIVE_PLANET'] ?? 'Water';
    final planet = planetColour == 'none'
        ? null
        : PlanetLook(color: planetColour, size: 2);
    final hostArt = BattleJourneyArt(
      planet: planet,
      home: prepared?.home,
      whose: 'YOUR HOME',
    );
    final guestArt = BattleJourneyArt(
      planet: planet,
      home: prepared?.home,
      whose: 'ANN\'S HOME',
    );

    final net = _Net()..startAt = (kBattleJourneySeconds * 1000).round();
    final hostLive = _FakeLive(net, hosting: true, friendName: 'Bo');
    final guestLive = _FakeLive(net, hosting: false, friendName: 'Ann');
    hostLive.other = guestLive;
    guestLive.other = hostLive;

    // Each phone its own navigator, so the way out has a page to go back
    // to.
    Widget phoneOf(String tag, Widget screen) => SizedBox(
      key: ValueKey('phone.$tag'),
      width: phone.width,
      height: phone.height,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: phone),
          child: ClipRect(
            child: Navigator(
              onGenerateInitialRoutes: (_, _) => [
                PageRouteBuilder<void>(
                  pageBuilder: (_, _, _) =>
                      const ColoredBox(color: Colors.black),
                ),
                BattleScreen.liveRoute(screen as BattleScreen),
              ],
            ),
          ),
        ),
      ),
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: SilentAudio(),
        child: save.app(
          shot: key,
          home: Row(
            children: [
              phoneOf(
                'a',
                BattleScreen(
                  team: hostFour,
                  rival: guestFour,
                  rivalName: 'BO',
                  arena: 'orrery',
                  leaveLabel: 'BACK TO THE LOBBY',
                  live: hostLive,
                  journey: hostArt,
                ),
              ),
              Container(width: 0, color: Colors.black),
              phoneOf(
                'b',
                BattleScreen(
                  team: guestFour,
                  rival: hostFour,
                  rivalName: 'ANN',
                  arena: 'orrery',
                  leaveLabel: 'BACK TO THE LOBBY',
                  live: guestLive,
                  journey: guestArt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    List<CosmicGame> games() => [
      for (final w in tester.widgetList<GameWidget>(
        find.byWidgetPredicate((w) => w is GameWidget),
      ))
        w.game! as CosmicGame,
    ];

    Future<void> shoot(String name, {double ratio = 1}) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final filmFps = int.tryParse(
      Platform.environment['BATTLE_LIVE_FILM'] ?? '',
    );
    final filmSeconds =
        double.tryParse(Platform.environment['BATTLE_LIVE_SECONDS'] ?? '') ??
        20;
    if (filmFps != null) Directory('$out/film').createSync(recursive: true);
    var filmNext = 0.0, frame = 0;
    var t = 0.0;
    // The way in (until 5 s), then the fight.
    final shots = [0.6, 1.6, 2.4, 3.0, 3.6, 4.2, 4.8, 6.0, 12.0, 20.0];
    var next = 0;
    var focused = false;
    // The way in, the games loading under it on the real clock.
    while (games().length < 2 || games().any((g) => g.battle == null)) {
      await tester.pump(const Duration(milliseconds: 33));
      net.wall += 33;
      t += 0.033;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      if (filmFps != null && t >= filmNext && t <= filmSeconds) {
        filmNext += 1 / filmFps;
        await shoot(
          'film/f${(frame++).toString().padLeft(4, '0')}',
          ratio: 0.4,
        );
      }
      if (next < shots.length && t >= shots[next]) {
        await shoot(
          'in_${(shots[next] * 10).round().toString().padLeft(3, '0')}',
          ratio: 0.6,
        );
        next++;
      }
      if (t > 30) fail('the fight never started');
    }
    final host = games().first.battle!, guest = games().last.battle!;
    while (t < 100) {
      await tester.pump(const Duration(milliseconds: 33));
      net.wall += 33;
      t += 0.033;
      if ((t * 30).round() % 30 == 0) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      // The guest's focus at 4 s: on its phone at once.
      if (!focused && t >= 4) {
        final target = guest.sides[1].creatures.indexWhere((c) => c.onField);
        if (target >= 0) {
          focused = true;
          games().last.predictBattleFocus(
            target,
            guestLive.send(BattleInput.focus(target)),
          );
        }
      }
      if (filmFps != null && t >= filmNext && t <= filmSeconds) {
        filmNext += 1 / filmFps;
        await shoot(
          'film/f${(frame++).toString().padLeft(4, '0')}',
          ratio: 0.4,
        );
      }
      if (next < shots.length && t >= shots[next]) {
        tester.takeException();
        await shoot(
          'live_${shots[next].toStringAsFixed(0).padLeft(2, '0')}s',
          ratio: 0.6,
        );
        next++;
      }
      if (host.over && guest.over && (guest.sinceEnd ?? 0) > 1) break;
    }
    // Both cards up.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      net.wall += 33;
      if (i % 10 == 0) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
    }
    tester.takeException();
    await shoot('live_result', ratio: 0.6);
    expect(host.over, isTrue);
    expect(guest.over, isTrue);
    final w = host.result!.winner;
    expect(guest.result!.winner, w == null ? null : 1 - w);

    // The way out, on both: back to the lobby.
    for (final tag in ['a', 'b']) {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('phone.$tag')),
          matching: find.text('BACK TO THE LOBBY'),
        ),
      );
    }
    if (filmFps != null) Directory('$out/exit').createSync(recursive: true);
    var outFrame = 0;
    for (var i = 0; i < 110; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      net.wall += 33;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      if (filmFps != null && i % (30 ~/ filmFps).clamp(1, 30) == 0) {
        await shoot(
          'exit/f${(outFrame++).toString().padLeft(4, '0')}',
          ratio: 0.4,
        );
      }
      if ([18, 30, 42, 54].contains(i)) {
        await shoot('out_${i.toString().padLeft(3, '0')}', ratio: 0.6);
      }
    }
    tester.takeException();
    expect(find.byType(BattleScreen), findsNothing);
    hostArt.dispose();
    await save.dispose(tester);
  });
}

CosmicPartyMember _member(Creature c, int slot, String tag) =>
    CosmicPartyMember(
      instanceId: '$tag:$slot:${c.id}',
      baseId: c.id,
      displayName: c.name,
      element: c.types.first,
      family: c.mutationFamily!,
      level: 10,
      statSpeed: 4.3,
      statIntelligence: 4.3,
      statStrength: 4.3,
      statBeauty: 4.3,
      slotIndex: slot,
      staminaBars: 3,
      staminaMax: 3,
      spriteSheet: sheetFromCreature(c),
      spriteVisuals: visualsFromInstance(c, null),
    );
