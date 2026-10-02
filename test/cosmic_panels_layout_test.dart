import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/home_planet_menu_overlay.dart';
import 'package:alchemons/screens/cosmic/widgets/ship_menu_overlay.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The ship console and the home base window fit a phone, short or tall,
// and their buttons reach their callbacks.

final _calls = <String>[];

Widget _host(AlchemonsDatabase db, Widget panel) => Provider.value(
  value: db,
  child: MaterialApp(
    home: Scaffold(
      body: Stack(children: [Positioned.fill(child: panel)]),
    ),
  ),
);

ShipMenuOverlay _console({bool hasHome = true, bool tutorial = false}) =>
    ShipMenuOverlay(
      hasHomePlanet: hasHome,
      meterFill: 0.5,
      walletShards: 80,
      shipHealth: 40,
      shipMaxHealth: 100,
      fuelFraction: 0.3,
      activeWeaponName: 'STANDARD GUN',
      orbitalStockpile: 2,
      orbitalActive: 1,
      hasBooster: true,
      hasOrbitals: true,
      hasMissiles: true,
      missileAmmo: 3,
      cargoLevel: 0,
      isNearHome: true,
      hasParty: true,
      onParty: () => _calls.add('party'),
      hasMatterInjector: true,
      onToggleMatterBoost: (v) => _calls.add('boost $v'),
      tutorialBuildHomeMode: tutorial,
      elementStorage: ElementStorage(stored: const {'Fire': 50}),
      onClose: () => _calls.add('close'),
      onBuildHome: () => _calls.add('build'),
      onRelocateHome: () => _calls.add('move'),
      onJettisonCargo: () {},
      onDumpWallet: () {},
      onRefuel: () => _calls.add('refuel'),
      onCraftMissiles: () => _calls.add('missiles'),
      onCraftSentinels: () => _calls.add('sentinels'),
      onUpgradeCargo: () {},
    );

HomePlanetMenuOverlay _home() => HomePlanetMenuOverlay(
  homePlanet: HomePlanet(position: Offset.zero, activeColor: 'Fire'),
  elementStorage: ElementStorage(
    stored: const {'Fire': 900, 'Water': 12, 'Lightning': 4},
  ),
  stats: const HomeBaseStats(
    astralBank: 12000,
    shardsCarried: 400,
    shardCapacity: 400,
    dustCollected: 3,
    dustTotal: 120,
    gold: 999999,
    silver: 1234567,
    soft: 88,
  ),
  onCustomize: () => _calls.add('customize'),
  onClose: () => _calls.add('close'),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late AlchemonsDatabase db;
  setUp(() {
    _calls.clear();
    db = AlchemonsDatabase(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  for (final size in const [Size(475, 751), Size(360, 640), Size(412, 915)]) {
    testWidgets('both panels lay out at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final panel in [
        _console(),
        _console(hasHome: false, tutorial: true),
        _home(),
      ]) {
        await tester.pumpWidget(_host(db, panel));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$panel at $size');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('the console docks its actions', (tester) async {
    await tester.pumpWidget(_host(db, _console()));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('ship.party')));
    await tester.tap(find.byKey(const ValueKey('ship.moveHome')));
    await tester.ensureVisible(find.text('MATTER BOOST'));
    await _settle(tester);
    await tester.tap(find.text('MATTER BOOST'));
    await _settle(tester);
    expect(_calls, ['party', 'move', 'boost true']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with no home, the console builds one; a tutorial holds it '
      'open', (tester) async {
    await tester.pumpWidget(
      _host(db, _console(hasHome: false, tutorial: true)),
    );
    await _settle(tester);
    expect(find.byTooltip('Close'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ship.buildHome')));
    await _settle(tester);
    expect(_calls, ['build']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the home window customizes', (tester) async {
    await tester.pumpWidget(_host(db, _home()));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('home.customize')));
    await _settle(tester);
    expect(_calls, ['customize']);
    await tester.pumpWidget(const SizedBox());
  });
}
