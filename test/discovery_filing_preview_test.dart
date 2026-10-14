@Tags(['preview'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/catalog/species_table.dart';
import 'package:alchemons/widgets/fx/essence_rim.dart' show RimColor;
import 'package:alchemons/widgets/nursery/extraction_result_card.dart'
    show kExtractionCardBarrier;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A new species filing itself away: its card comes apart, the sand pours
// into its cell in the catalog and settles on the shadow, and the portrait
// comes up through it. Once from a card (a single extraction) and once from
// where a card stood (a batch), on a phone.
//
//   FILING_OUT=/tmp/filing flutter test \
//     test/discovery_filing_preview_test.dart --tags preview
//
// (One case per run, with --plain-name single / batch: the portrait reads
// are cached across tests, and a second test waits on the first's.)
void main() {
  final out = Platform.environment['FILING_OUT'];

  for (final (name, id, color, fromCard) in const [
    ('single', 'HOR01', RimColor.element, true),
    ('batch', 'PIP09', RimColor.prismatic, false),
  ]) {
    testWidgets('discovery filing preview ($name)', (tester) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final db = AlchemonsDatabase(NativeDatabase.memory());
      late CreatureCatalog catalog;
      late List<CreatureEntry> entries;
      await tester.runAsync(() async {
        final json =
            jsonDecode(
                  File(
                    'assets/data/alchemons_creatures.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        catalog = CreatureCatalog.fromList([
          for (final c in json['creatures'] as List)
            Creature.fromJson(c as Map<String, dynamic>),
        ]);
        for (final found in [
          ...['LET01', 'LET02', 'LET03', 'LET04', 'LET07', 'HOR07'],
          ...['PIP01', 'PIP02', 'PIP04', 'PIP10', 'MAN03', 'MAN09'],
          ...['MSK04', 'WNG05', 'KIN02', 'MYS06', id],
        ]) {
          await db.creatureDao.addOrUpdateCreature(
            PlayerCreaturesCompanion(
              id: Value(found),
              discovered: const Value(true),
            ),
          );
        }
        entries = await GameDataService(
          db: db,
          catalog: catalog,
        ).watchAllEntries().first;
      });
      final species = catalog.getCreatureById(id)!;

      final shotKey = GlobalKey();
      final cardKey = GlobalKey();
      final navKey = GlobalKey();
      final scroll = ScrollController();
      final reveal = NewDiscoveryReveal.instance;
      reveal.databaseNavKey = navKey;
      reveal.onSwitchSection = (_) {};
      // As the creatures screen does: the revealed cell is brought into view.
      void bringIntoView() {
        if (reveal.pendingRevealCreatureId.value == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = reveal.revealTileKey?.currentContext;
          if (ctx == null) return;
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: 0.5,
          );
        });
      }

      reveal.pendingRevealCreatureId.addListener(bringIntoView);
      addTearDown(() {
        reveal.pendingRevealCreatureId.removeListener(bringIntoView);
        reveal.pendingRevealCreatureId.value = null;
        reveal.databaseNavKey = null;
        reveal.onSwitchSection = null;
      });

      final theme = FactionTheme.scorchForge();
      final palette = BracketPalette.fromTheme(theme);
      final showCard = ValueNotifier(fromCard);
      final element = species.types.first;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) =>
              RepaintBoundary(key: shotKey, child: child!),
          home: Scaffold(
            backgroundColor: const Color(0xFF0B0A10),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: reveal.pendingRevealCreatureId,
                    builder: (_, pending, _) => SpeciesTable(
                      entries: entries,
                      counts: const {},
                      palette: palette,
                      accent: theme.accent,
                      onTap: (_, _) {},
                      revealCreatureId: pending,
                      controller: scroll,
                      bottomInset: 60,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 60,
                  child: ColoredBox(
                    color: const Color(0xFF15131B),
                    child: Center(
                      child: SizedBox(
                        key: navKey,
                        width: 28,
                        height: 28,
                        child: const Icon(Icons.grid_view, size: 22),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: showCard,
                  builder: (_, show, _) => !show
                      ? const SizedBox()
                      : Positioned.fill(
                          child: ColoredBox(
                            color: kExtractionCardBarrier,
                            child: Center(
                              child: RepaintBoundary(
                                key: cardKey,
                                child: _StandInCard(
                                  species: species,
                                  element: element,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );

      Future<void> shoot(String frame) async {
        await tester.runAsync(() async {
          final boundary =
              shotKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/${name}_$frame.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> settle(int frames) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 33));
        }
      }

      // Shadows read, portraits decoded.
      await settle(20);
      await shoot('0_before');

      if (fromCard) {
        final going = await tester.runAsync(
          () => reveal.playFilingAway(
            context: cardKey.currentContext!,
            cardBoundaryKey: cardKey,
            species: species,
            color: color,
            barrier: kExtractionCardBarrier,
            seed: 7,
          ),
        );
        expect(going, isTrue);
        showCard.value = false;
      } else {
        // As the batch ceremony hands it over: the navigator's own context.
        final ctx = tester
            .state<NavigatorState>(find.byType(Navigator))
            .context;
        final size = MediaQuery.sizeOf(ctx);
        // Started in real time, where the portrait can be read; not awaited,
        // as the sand then runs on the test clock.
        await tester.runAsync(() async {
          unawaited(
            reveal.playFilingSequence(
              context: ctx,
              flights: [
                DiscoveryFlight(
                  species: species,
                  from: Rect.fromCenter(
                    center: size.center(Offset.zero),
                    width: size.width * 0.95,
                    height: size.height * 0.82,
                  ),
                  color: color,
                  seed: 9,
                ),
              ],
            ),
          );
          for (var i = 0; i < 100 && reveal.revealFill.value == 1; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        });
        expect(reveal.revealFill.value, 0);
      }

      var at = 0;
      for (final ms in const [
        0,
        90,
        200,
        320,
        460,
        620,
        780,
        940,
        1100,
        1260,
        1420,
        1600,
      ]) {
        await tester.pump(Duration(milliseconds: ms - at));
        at = ms;
        await shoot('1_${ms.toString().padLeft(4, '0')}');
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 800)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(reveal.revealFill.value, 1);
      await shoot('2_after');

      await tester.pumpWidget(const SizedBox());
      await settle(4);
      await tester.runAsync(db.close);
    });
  }
}

/// Enough of an extraction card to see it come apart: dark glass, the
/// specimen on a lit stage, a few lines of reading, a rim of its light.
class _StandInCard extends StatelessWidget {
  const _StandInCard({required this.species, required this.element});

  final Creature species;
  final String element;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final light = switch (element) {
      'Fire' => const Color(0xFFFF8A3D),
      'Ice' => const Color(0xFF9FD8FF),
      _ => const Color(0xFFD9C27A),
    };
    return Container(
      width: size.width * 0.95,
      height: size.height * 0.82,
      decoration: BoxDecoration(
        color: const Color(0xF0141218),
        border: Border.all(color: light.withValues(alpha: 0.5), width: 2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            species.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFFE8DCC0),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [light.withValues(alpha: 0.35), Colors.transparent],
                  ),
                ),
                child: Image.asset(
                  'assets/images/${species.image}',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in ['SPEED', 'INTELLIGENCE', 'STRENGTH'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '$s   1.42',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB8AE98),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < 8; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              height: 8,
              width: 120.0 + (i * 37) % 180,
              color: const Color(0xFF2A2630),
            ),
          const Spacer(),
          Center(
            child: Container(
              width: 180,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: light.withValues(alpha: 0.7)),
              ),
              child: const Text(
                'CONTINUE',
                style: TextStyle(color: Color(0xFFE8DCC0), letterSpacing: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
