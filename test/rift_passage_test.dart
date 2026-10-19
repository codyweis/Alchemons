import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/screens/scenes/rift_threshold.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The way into a rift and out of it: the threshold grows out of the rift
// that was tapped and steps back into it, the key comes apart into grains,
// and the rift is left through black that opens on the screen behind.
void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1720, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 2;
  });

  Future<void> frames(WidgetTester tester, double seconds) async {
    for (var t = 0.0; t < seconds; t += 1 / 30) {
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  testWidgets('the tapped rift hides while its threshold stands in for it, '
      'until it has stepped all the way back', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final hidden = <bool>[];
    final from = RiftOrigin(
      centre: const Offset(600, 90),
      radius: 72,
      hide: hidden.add,
    );
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    nav.currentState!.push(
      riftThresholdRoute(
        from: from,
        builder: (_) => RiftThreshold(
          faction: RiftFaction.earthen,
          from: from,
          loadKeys: () async => 1,
          spendKey: () async => true,
          onEnter: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(hidden, [true]);
    await frames(tester, 1.2);
    expect(find.text('HOLD TO TURN THE KEY'), findsOneWidget);

    nav.currentState!.pop();
    await frames(tester, 0.3);
    expect(hidden, [true], reason: 'still shrinking back into it');
    await frames(tester, 0.8);
    expect(hidden.last, isFalse);
  });

  testWidgets('the black a rift is left through covers, then opens and goes', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final exit = RiftExitSheet()..cover(nav.currentState!);
    await tester.pump();
    expect(exit.covering, isTrue);
    var opened = false;
    exit.open(at: const Offset(600, 90)).then((_) => opened = true);
    await frames(tester, 0.5);
    expect(exit.covering, isTrue);
    await frames(tester, 0.8);
    expect(opened, isTrue);
    expect(exit.covering, isFalse);
  });

  test('a key comes apart into grains of its own shape and colors', () {
    final grains = PortalKeyGlyph.grainsOf(52, const Color(0xFF8B6F47));
    expect(grains.length, inInclusiveRange(250, 900));
    for (var i = 0; i < grains.length; i++) {
      expect(grains.hx[i].abs(), lessThan(26));
      expect(grains.hy[i].abs(), lessThan(26));
      expect(grains.tone[i], lessThan(grains.tones.length));
    }
  });

  testWidgets('leaving the rift goes black, covers and pops with its result', (
    tester,
  ) async {
    late AlchemonsDatabase db;
    final catalog = CreatureCatalog();
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await catalog.load();
      await loadNatures();
    });
    final constellation = ConstellationEffectsService(db);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<CreatureCatalog>.value(value: catalog),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: constellation,
          ),
          Provider<CatchService>(
            create: (_) => CatchService(db, constellation),
          ),
        ],
        child: MaterialApp(navigatorKey: nav, home: const SizedBox()),
      ),
    );
    final exit = RiftExitSheet();
    bool? result;
    nav.currentState!
        .push(
          PageRouteBuilder<bool>(
            transitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => RiftPortalScreen(
              faction: RiftFaction.volcanic,
              species: catalog.getCreatureById('HOR01'),
              exit: exit,
            ),
          ),
        )
        .then((r) => result = r);
    // The sprite cannot be read under the test clock, so it arrives
    // plainly once its wait runs out.
    await frames(tester, 2.6);

    await tester.tap(find.byIcon(AppIcons.close_rounded));
    await frames(tester, 0.4);
    await tester.tap(find.text('LEAVE'));
    await frames(tester, 0.3);
    expect(result, isNull, reason: 'it goes black before it goes');
    expect(exit.covering, isFalse);
    await frames(tester, 0.6);
    expect(result, isFalse);
    expect(exit.covering, isTrue);

    exit.remove();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
