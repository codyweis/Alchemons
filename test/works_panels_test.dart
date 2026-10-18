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
import 'package:alchemons/screens/cosmic/widgets/works_tutorials.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
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
  void setRecipe(String? recipe) => calls.add('recipe $recipe');
  @override
  void setRefineKeep(int keep) => calls.add('refine keep $keep');
  @override
  void openArmory() => calls.add('armory');
  @override
  Future<void> openCodex() async => calls.add('codex');
  @override
  Future<void> dismantle(WorksBuilding b) async =>
      calls.add('take down ${b.name}');
  @override
  Future<void> openOutpost(String element) async =>
      calls.add('outpost $element');
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
        berth: 0,
        crates: [
          const ScavengerFind(elements: {'Fire': 14, 'Dust': 6}, shards: 2),
          const ScavengerFind(elements: {'Water': 20}),
        ],
      ),
      press: SilverPressState(tier: 1, berth: 1, presser: 'w5', reserve: 200),
      refinery: RefineryState(
        tier: 2,
        berth: 2,
        refiner: 'w6',
        recipe: 'Fire+Water',
        made: 312,
      ),
      armory: ArmoryState(tier: 1, berth: 3),
    );
    works.bay.slots[0]
      ..instanceId = 'w4'
      ..tripStartMs = now - 30000
      ..tripMs = 240000;
    return works;
  }

  WorksView view(
    WorksState works, {
    String? nearRig,
    String? atPlanet,
    int berthCount = 4,
  }) => WorksView(
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
    berthCount: berthCount,
    knownRecipes: const {'Fire+Water', 'Air+Fire', 'Earth+Fire'},
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
        'works_refinery_empty': WorksPanel(
          view: ValueNotifier(view(WorksState())),
          actions: actions,
          initialTab: WorksTab.refinery,
        ),
        'works_refinery_no_berth': WorksPanel(
          view: ValueNotifier(
            view(
              WorksState(
                bay: ScavengerBayState(tier: 1, berth: 0),
                press: SilverPressState(tier: 1, berth: 1),
              ),
              berthCount: 2,
            ),
          ),
          actions: actions,
          initialTab: WorksTab.refinery,
        ),
        for (final tab in WorksTab.values)
          'works_${tab.name}': WorksPanel(
            view: ValueNotifier(view(builtWorks())),
            actions: actions,
            initialTab: tab,
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
    Future<void> tap(String key) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle(tester, 2);
    }

    Future<void> tab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('works.tabs')),
          matching: find.text(label),
        ),
      );
      await settle(tester, 2);
    }

    expect(find.text('SLOTS 4/4'), findsOneWidget);
    await tap('works.armory.open');
    await tab('BAY');
    await tap('works.bay.collect');
    await tap('works.bay.slot.1');
    await tab('PRESS');
    await tap('works.press.keep.500');
    await tab('REFINERY');
    await tap('works.refinery.slot');
    await tap('works.refinery.codex');
    await tap('works.refinery.recipe.Air+Fire');
    await tap('works.refinery.keep.200');
    await tap('works.takeDown.refinery');
    await tab('PLANETS');
    await tap('works.outpost.Fire');
    expect(actions.calls, [
      'armory',
      'collect',
      'assign scavenger null 1',
      'keep 500',
      'assign refiner null 0',
      'codex',
      'recipe Air+Fire',
      'refine keep 200',
      'take down refinery',
      'outpost Fire',
    ]);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2);
  });

  testWidgets('the Works mark what wants the player', (tester) async {
    tester.view.physicalSize = const Size(475, 751);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    final actions = _Actions();
    final tabs = <WorksTab>[];
    final v = view(builtWorks());
    // Crates wait in the bay; Water's hopper is full with no one to mine
    // or carry it.
    expect(firstWorksTabNeeding(v), WorksTab.bay);
    expect(firstWorksTabNeeding(view(WorksState())), isNull);
    await tester.pumpWidget(
      host(
        WorksPanel(
          view: ValueNotifier(v),
          actions: actions,
          onTabChanged: tabs.add,
        ),
      ),
    );
    await settle(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('works.tabs')),
        matching: find.byType(AttentionDot),
      ),
      findsNWidgets(2),
    );

    Future<void> tab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('works.tabs')),
          matching: find.text(label),
        ),
      );
      await settle(tester, 2);
    }

    // An upgrade that can be paid for is lit like the thing to do.
    await tab('BAY');
    final upgrade = tester.widget<BracketButton>(
      find.ancestor(
        of: find.text('UPGRADE TO TIER 3'),
        matching: find.byType(BracketButton),
      ),
    );
    expect(upgrade.enabled, isTrue);
    expect(upgrade.primary, isTrue);
    await tester.tap(find.byKey(const ValueKey('works.bay.slot.0.remove')));
    await settle(tester, 2);
    expect(actions.calls, ['clear scavenger']);

    // The press says what it makes in silver, as its presser's slot does.
    await tab('PRESS');
    expect(find.textContaining('SPARE · '), findsOneWidget);
    expect(find.textContaining('SILVER/MIN'), findsNWidgets(2));

    // A recipe short of an input says so, and stands dim.
    await tab('REFINERY');
    expect(find.text('NOT ENOUGH AIR'), findsOneWidget);
    expect(find.text('NOT ENOUGH EARTH'), findsNothing);

    await tab('PLANETS');
    String status(String e) => tester
        .widget<Text>(find.byKey(ValueKey('works.outpost.$e.status')))
        .data!;
    expect(status('Water'), 'FULL · NO MINER');
    expect(status('Fire'), startsWith('MINING '));
    expect(status('Fire'), contains('COURIER FLYING 25 HOME'));
    expect(tabs, [
      WorksTab.bay,
      WorksTab.press,
      WorksTab.refinery,
      WorksTab.planets,
    ]);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2);
  });

  test('every slot and summary writes a rate a minute the same way', () {
    const p = WorkerProfile(
      instanceId: 'w',
      element: 'Fire',
      speed: 3,
      intelligence: 4,
      strength: 3,
      beauty: 3,
      harvestRate: 6,
    );
    expect(fmtRate(7.6), '7.6');
    expect(fmtRate(12.4), '12');
    expect(fmtRate(5), '5');
    expect(jobFigure(WorkJob.miner, p), '6/MIN');
    expect(jobFigure(WorkJob.courier, p, distance: 7200), endsWith('/MIN'));
    expect(jobDetail(WorkJob.courier, p, distance: 7200), contains('A RUN'));
    expect(jobDetail(WorkJob.miner, p), isNull);
    expect(jobFigure(WorkJob.presser, p), '5 SILVER/MIN');
    expect(jobFigure(WorkJob.refiner, p, refineTier: 2), '11 MADE/MIN');
    expect(jobStats(WorkJob.courier, p, level: 9), 'SPD 3 · STR 3');
    expect(jobStats(WorkJob.miner, p, level: 9), 'LV 9');
    // The picker ranks a courier by what it moves a minute.
    const slow = WorkerProfile(
      instanceId: 's',
      element: 'Fire',
      speed: 1,
      intelligence: 3,
      strength: 3,
      harvestRate: 6,
    );
    expect(
      jobScore(WorkJob.courier, p, distance: 7200),
      greaterThan(jobScore(WorkJob.courier, slow, distance: 7200)),
    );
  });

  testWidgets('the picker shows the stats a job reads', (tester) async {
    tester.view.physicalSize = const Size(475, 751);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.pumpWidget(
      host(const WorkerPicker(job: WorkJob.courier, distance: 7200)),
    );
    await settle(tester);
    expect(find.textContaining('SPD '), findsWidgets);
    expect(find.textContaining('LV '), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2);
  });

  test('each building explains itself with the rules it runs on', () {
    for (final b in WorksBuilding.values) {
      expect(
        worksTutorial(b, element: 'Fire').length,
        greaterThanOrEqualTo(2),
        reason: b.name,
      );
    }
    String all(WorksBuilding b, {String? element}) =>
        worksTutorial(b, element: element).map((p) => p.message).join(' ');
    expect(
      all(WorksBuilding.extractor, element: 'Fire'),
      contains('a Fire Alchemon'),
    );
    expect(
      all(WorksBuilding.extractor, element: 'Air'),
      contains('an Air Alchemon'),
    );
    expect(all(WorksBuilding.extractor), contains("this planet's element"));
    expect(
      all(WorksBuilding.extractor, element: 'Ice'),
      contains('holds ${WorkRules.hopperCap(1)}'),
    );
    expect(
      all(WorksBuilding.scavengerBay),
      contains('all ${WorkRules.crateCap(1)} crates'),
    );
    expect(
      all(WorksBuilding.silverPress),
      contains('${WorkRules.grainsPerSilver} elements make 1 silver'),
    );
    expect(
      all(WorksBuilding.armory),
      contains('reach level ${WorkRules.armoryPowerCap(1)}'),
    );
  });

  testWidgets('every building\'s ? opens its tutorial', (tester) async {
    tester.view.physicalSize = const Size(475, 751);
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

    Future<void> read(WorksBuilding b, String opens, {String? tab}) async {
      if (tab != null) {
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('works.tabs')),
            matching: find.text(tab),
          ),
        );
        await settle(tester, 2);
      }
      await tester.tap(find.byKey(ValueKey('works.help.${b.name}')));
      await settle(tester, 4);
      expect(find.textContaining(opens), findsOneWidget, reason: b.name);
      await shoot(tester, 'tutorial_${b.name}');
      final pages = worksTutorial(b).length;
      for (var i = 0; i < pages; i++) {
        await tester.tap(find.text(i == pages - 1 ? 'OK' : 'NEXT'));
        await settle(tester, 4);
      }
      expect(find.textContaining(opens), findsNothing, reason: b.name);
    }

    await read(WorksBuilding.armory, 'are made here');
    await read(WorksBuilding.scavengerBay, 'Scavengers fly', tab: 'BAY');
    await read(WorksBuilding.silverPress, 'into silver', tab: 'PRESS');
    await read(WorksBuilding.refinery, 'out of two others', tab: 'REFINERY');
    expect(actions.calls, isEmpty);

    await tester.pumpWidget(
      host(
        OutpostPanel(
          element: 'Fire',
          view: ValueNotifier(view(builtWorks())),
          actions: actions,
        ),
      ),
    );
    await settle(tester);
    await read(WorksBuilding.extractor, 'Mines Fire from this planet');
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
