// The Works' screens and LOAD THE HOLD lay out at phone sizes, upright and
// on their side, and answer their buttons.
//
// With WORKS_PANELS_OUT=/tmp/works_panels set, each one is also written out
// as a picture (fonts loaded from the system so the type reads).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/works.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/cosmic/cosmic_screen.dart'
    show cosmicMemberFromInstance;
import 'package:alchemons/screens/cosmic/widgets/load_hold_panel.dart';
import 'package:alchemons/screens/cosmic/widgets/worker_picker.dart';
import 'package:alchemons/screens/cosmic/widgets/works_panels.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Actions implements WorksActions {
  final List<String> calls = [];
  @override
  Future<void> build(WorksBuilding b, {String? element}) async =>
      calls.add('build ${b.name} $element');
  @override
  Future<void> upgrade(WorksBuilding b, {String? element}) async =>
      calls.add('upgrade ${b.name} $element');
  @override
  Future<void> assign(WorkSlotRef slot) async =>
      calls.add('assign ${slot.job.name} ${slot.element} ${slot.index}');
  @override
  Future<void> clear(WorkSlotRef slot) async =>
      calls.add('clear ${slot.job.name}');
  @override
  void collectCrates() => calls.add('collect');
  @override
  void sendHome(String element) => calls.add('send $element');
  @override
  void setReserve(int reserve) => calls.add('keep $reserve');
  @override
  Future<void> openOutpost(String element) async =>
      calls.add('outpost $element');
  @override
  Future<void> help() async => calls.add('help');
}

void main() {
  final out = Platform.environment['WORKS_PANELS_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  late AlchemonsDatabase db;
  late CreatureCatalog catalog;
  final members = <String, CosmicPartyMember>{};
  final profiles = <String, WorkerProfile>{};

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      catalog = CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
      // Fire Alchemons for the miners, a couple of others for the rest.
      final fire = catalog.creatures
          .where((c) => c.types.isNotEmpty && c.types.first == 'Fire')
          .take(3)
          .toList();
      final other = catalog.creatures
          .where((c) => c.types.isNotEmpty && c.types.first != 'Fire')
          .take(4)
          .toList();
      var n = 0;
      for (final c in [...fire, ...other]) {
        final id = 'w${n++}';
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: c.id,
          level: 3 + n * 2,
          source: 'planet_summon',
        );
        final inst = (await db.creatureDao.getInstance(id))!;
        final m = cosmicMemberFromInstance(inst, c, slotIndex: 0);
        members[id] = m;
        profiles[id] = workerProfileOf(inst, m.element);
      }
    });
  }

  WorksState builtWorks() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final works = WorksState(
      extractors: {
        'Fire': ExtractorState(
          element: 'Fire',
          updatedMs: now,
          tier: 2,
          miners: ['w0'],
          courier: 'w3',
          hopper: 84,
          cycleStartMs: now - 20000,
          cycleMs: 140000,
          cargo: 25,
          delivered: false,
        ),
        'Water': ExtractorState(element: 'Water', updatedMs: now, hopper: 120),
      },
      bay: ScavengerBayState(
        tier: 2,
        crates: [
          const ScavengerFind(elements: {'Fire': 14, 'Dust': 6}, shards: 2),
          const ScavengerFind(elements: {'Water': 20}),
        ],
      ),
      press: SilverPressState(tier: 1, presser: 'w5', reserve: 200),
    );
    works.bay.slots[0]
      ..instanceId = 'w4'
      ..tripStartMs = now - 30000
      ..tripMs = 240000;
    return works;
  }

  WorksView view(WorksState works, {String? nearRig, String? atPlanet}) =>
      WorksView(
        works: works,
        profiles: profiles,
        members: members,
        storage: const {'Fire': 640, 'Water': 210, 'Earth': 95, 'Dust': 30},
        hold: const {'Fire': 36, 'Air': 20},
        silver: 2400,
        planetsFound: const ['Fire', 'Water', 'Earth', 'Dust', 'Air'],
        distanceHome: (_) => 7200,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        nearRig: nearRig,
        atPlanet: atPlanet,
      );

  final key = GlobalKey();

  Widget host(Widget child) => MultiProvider(
    providers: [
      Provider<AlchemonsDatabase>.value(value: db),
      Provider<CreatureCatalog>.value(value: catalog),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      builder: (context, c) => RepaintBoundary(key: key, child: c!),
      home: Scaffold(backgroundColor: const Color(0xFF05040C), body: child),
    ),
  );

  Future<void> settle(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    if (out == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  const sizes = {
    'portrait': Size(475, 751),
    'narrow': Size(360, 640),
    'landscape': Size(916, 412),
  };

  for (final size in sizes.entries) {
    testWidgets('the Works screens lay out (${size.key})', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await seed(tester);
      final actions = _Actions();
      final screens = <String, Widget>{
        'works_empty': WorksPanel(
          view: ValueNotifier(view(WorksState())),
          actions: actions,
        ),
        'works_built': WorksPanel(
          view: ValueNotifier(view(builtWorks())),
          actions: actions,
        ),
        'outpost_unbuilt': OutpostPanel(
          element: 'Earth',
          view: ValueNotifier(view(builtWorks(), atPlanet: 'Earth')),
          actions: actions,
        ),
        'outpost_built': OutpostPanel(
          element: 'Fire',
          view: ValueNotifier(view(builtWorks(), nearRig: 'Fire')),
          actions: actions,
        ),
        'load_hold': LoadHoldPanel(
          stored: const {'Fire': 640, 'Water': 210, 'Earth': 95, 'Dust': 30},
          hold: const {'Fire': 36, 'Air': 20},
          patterns: [
            GatePattern(
              planetName: 'Pyraxis',
              recipe: PlanetRecipe.pure(element: 'Fire'),
            ),
            const GatePattern(
              planetName: 'Vaporis',
              recipe: PlanetRecipe(
                planetElement: 'Steam',
                level: 1,
                components: {'Steam': 55, 'Earth': 37},
                randomPct: 8,
              ),
            ),
          ],
          onLoad: (_) {},
        ),
        'picker_miner': WorkerPicker(
          job: WorkJob.miner,
          element: 'Fire',
          blocked: const {'w1': 'IN PARTY'},
          atWork: const {'w0': 'MINER · FIRE'},
          current: 'w0',
        ),
        'picker_courier': const WorkerPicker(
          job: WorkJob.courier,
          distance: 7200,
        ),
      };
      for (final s in screens.entries) {
        await tester.pumpWidget(host(s.value));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${s.key} ${size.key}');
        await shoot(tester, '${s.key}_${size.key}');
      }
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 2);
    });
  }

  testWidgets('the Works panel answers its buttons', (tester) async {
    tester.view.physicalSize = const Size(916, 412);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    final actions = _Actions();
    await tester.pumpWidget(
      host(
        WorksPanel(view: ValueNotifier(view(builtWorks())), actions: actions),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('works.bay.collect')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('works.press.keep.500')),
    );
    await tester.tap(find.byKey(const ValueKey('works.press.keep.500')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('works.outpost.Fire')),
    );
    await tester.tap(find.byKey(const ValueKey('works.outpost.Fire')));
    await tester.ensureVisible(find.byKey(const ValueKey('works.bay.slot.1')));
    await tester.tap(find.byKey(const ValueKey('works.bay.slot.1')));
    await settle(tester, 2);
    expect(actions.calls, [
      'collect',
      'keep 500',
      'outpost Fire',
      'assign scavenger null 1',
    ]);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2);
  });

  testWidgets('an outpost sends home only when the ship is there', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(475, 751);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    final actions = _Actions();
    final v = ValueNotifier(view(builtWorks()));
    await tester.pumpWidget(
      host(OutpostPanel(element: 'Fire', view: v, actions: actions)),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('outpost.sendHome')));
    expect(actions.calls, isEmpty);
    v.value = view(builtWorks(), nearRig: 'Fire');
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('outpost.sendHome')));
    expect(actions.calls, ['send Fire']);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2);
  });
}
