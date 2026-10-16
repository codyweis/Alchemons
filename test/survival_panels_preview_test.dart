@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/cosmic_survival_game_over_panel.dart';
import 'package:alchemons/games/cosmic_survival/components/powerup_selection_overlay.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_fusion_ledger.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_hud.dart'
    show SurvivalInk, hudMono;
import 'package:alchemons/games/cosmic_survival/components/survival_upgrade_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart'
    show PanelSectionHeader;
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_lobby_harness.dart';

// Survival's two full-screen panels on the phone, with real fonts: the
// surge draft and the results. Also the surge fusions: a draft holding
// one, the pause panel's FUSIONS list, and a sheet of their art beside
// their parents'.
//
//   PANELS_OUT=/tmp/panels flutter test \
//     test/survival_panels_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['PANELS_OUT'];
  setUpAll(loadLobbyFonts);

  CosmicPartyMember member(
    String family,
    String element,
    String name, {
    String? image,
  }) => CosmicPartyMember(
    instanceId: name,
    baseId: 'PRV01',
    displayName: name,
    family: family,
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: 4,
    statIntelligence: 4,
    statStrength: 4,
    statBeauty: 4,
    staminaBars: 3,
    staminaMax: 3,
    imagePath: image,
  );

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> show(WidgetTester tester, GlobalKey key, Widget child) async {
    tester.view
      ..physicalSize = kLobbyPhysical
      ..devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFF020010),
            body: child,
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  /// The draft some way into a run, as the screen shows it: the TAKEN
  /// strip, three cards, the keys, and what the next wave brings.
  Widget draft({
    PowerUpState? state,
    String nextWaveElement = 'Water',
    bool nextIsBoss = false,
  }) {
    // A build some way in, for the TAKEN strip: the same picks the cards
    // below are offered more of, and a few others.
    final taken = state ?? PowerUpState();
    for (final (id, slot) in const [
      ('world_plant', 0),
      ('strength_up', 1),
      ('strength_up', 1),
      ('shield_pulse', null),
      ('command_speed', null),
      ('chain_lightning', 1),
    ]) {
      final def = [
        ...kAllPowerUps,
        ...kMysticWorldPowerUps,
      ].firstWhere((d) => d.id == id);
      taken.apply(def, targetSlot: slot);
    }
    return PowerUpSelectionOverlay(
      choices: [
        OfferedPowerUpChoice(
          def: kMysticWorldPowerUps.firstWhere((d) => d.id == 'world_plant'),
          targetSlot: 0,
          targetName: 'Verdant',
          currentLevel: 1,
        ),
        OfferedPowerUpChoice(
          def: kAllPowerUps.firstWhere((d) => d.id == 'strength_up'),
          targetSlot: 1,
          targetName: 'Bulwark',
          currentLevel: 2,
        ),
        OfferedPowerUpChoice(
          def: kAllPowerUps.firstWhere(
            (d) => d.category == PowerUpCategory.shipWeapon,
          ),
          currentLevel: 0,
        ),
      ],
      currentWave: 12,
      party: [
        member(
          'Mystic',
          'Plant',
          'Verdant',
          image: 'assets/images/creatures/mystic/MYS12_plantmystic.png',
        ),
        member(
          'Horn',
          'Fire',
          'Bulwark',
          image: 'assets/images/creatures/rare/HOR01_firehorn.png',
        ),
      ],
      powerUps: taken,
      onSelect: (def, {targetSlot, targetName}) {},
      onReroll: () {},
      onBanish: (_) {},
      nextWaveElement: nextWaveElement,
      nextIsBoss: nextIsBoss,
    );
  }

  Future<void> shootDraft(
    WidgetTester tester,
    String name,
    Widget overlay, {
    Future<void> Function()? then,
  }) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await show(tester, key, overlay);
      await precacheLobbyImages(tester);
      await tester.pump(const Duration(milliseconds: 40));
      if (then != null) {
        await then();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
      }
      await shoot(tester, key, name);
    } finally {
      debugDisableShadows = true;
      await tester.pumpWidget(const SizedBox());
    }
  }

  testWidgets('surge draft', (tester) async {
    await shootDraft(tester, 'surge_draft', draft());
  });

  // BANISH pressed, before a card is chosen: every card lit in the ember.
  testWidgets('surge draft, banish armed', (tester) async {
    await shootDraft(
      tester,
      'surge_draft_banish',
      draft(),
      then: () =>
          tester.tap(find.byKey(const ValueKey('survival.draft.banish'))),
    );
  });

  // A boss next, both rerolls spent and one banish.
  testWidgets('surge draft, boss next, a key spent', (tester) async {
    final state = PowerUpState()
      ..restoreDraftKeys(
        rerollsLeft: 0,
        banishesLeft: 1,
        banished: const {'ship_damage'},
      );
    await shootDraft(
      tester,
      'surge_draft_boss_spent',
      draft(state: state, nextIsBoss: true),
    );
  });

  // ── SURGE FUSIONS ──
  PowerUpDef byId(String id) => kSurvivalPowerUpsById[id]!;
  void maxOut(PowerUpState s, String id) {
    for (var i = 0; i < byId(id).maxStacks; i++) {
      s.apply(byId(id));
    }
  }

  final fusionParty = [
    member(
      'Pip',
      'Fire',
      'Sparkle',
      image: 'assets/images/creatures/uncommon/PIP01_firepip.png',
    ),
    member(
      'Horn',
      'Fire',
      'Bulwark',
      image: 'assets/images/creatures/rare/HOR01_firehorn.png',
    ),
  ];

  Widget fusionDraft(PowerUpState state, List<(String, int)> cards) =>
      PowerUpSelectionOverlay(
        choices: [
          for (final (id, level) in cards)
            OfferedPowerUpChoice(def: byId(id), currentLevel: level),
        ],
        currentWave: 14,
        party: fusionParty,
        powerUps: state,
        onSelect: (def, {targetSlot, targetName}) {},
        onReroll: () {},
        onBanish: (_) {},
        nextWaveElement: 'Fire',
      );

  // Spread Shot and Hunter Salvo both taken in full: Homing Spread leads the
  // draft; the two parent cards beside it say what they fuse with.
  testWidgets('surge draft, a fusion due', (tester) async {
    final state = PowerUpState();
    maxOut(state, 'spread_shot');
    maxOut(state, 'homing_missiles');
    state
      ..apply(byId('kinetic_overdrive'))
      ..apply(byId('regen_field'))
      ..apply(byId('regen_field'))
      ..apply(byId('strength_up'), targetSlot: 1);
    await shootDraft(
      tester,
      'fusion_draft',
      fusionDraft(state, const [
        ('fusion_homing_spread', 0),
        ('kinetic_overdrive', 1),
        ('regen_field', 2),
      ]),
    );
  });

  // The same on the Fold's cover (344 wide): the narrow card's layout.
  testWidgets('surge draft, a fusion due, narrow', (tester) async {
    final state = PowerUpState();
    maxOut(state, 'spread_shot');
    maxOut(state, 'homing_missiles');
    state
      ..apply(byId('kinetic_overdrive'))
      ..apply(byId('regen_field'));
    await shootDraft(
      tester,
      'fusion_draft_narrow',
      Center(
        child: SizedBox(
          width: 344,
          child: fusionDraft(state, const [
            ('fusion_homing_spread', 0),
            ('kinetic_overdrive', 1),
            ('regen_field', 1),
          ]),
        ),
      ),
    );
  });

  // Taken: the fusion sits in the TAKEN strip with its parents.
  testWidgets('surge draft, a fusion taken', (tester) async {
    final state = PowerUpState();
    maxOut(state, 'spread_shot');
    maxOut(state, 'homing_missiles');
    state
      ..apply(byId('fusion_homing_spread'))
      ..apply(byId('regen_field'))
      ..apply(byId('strength_up'), targetSlot: 1);
    await shootDraft(
      tester,
      'fusion_draft_taken',
      fusionDraft(state, const [
        ('missile_launcher', 0),
        ('orb_vitality', 0),
        ('shield_pulse', 1),
      ]),
    );
  });

  // The pause panel's FUSIONS, as it sits under POWERUPS: one made, one
  // ready, one half done, two only seen.
  testWidgets('pause fusions', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final state = PowerUpState();
    maxOut(state, 'spread_shot');
    maxOut(state, 'homing_missiles');
    state.apply(byId('fusion_homing_spread'));
    maxOut(state, 'shield_pulse');
    state.apply(byId('nova_detonation'));
    maxOut(state, 'regen_field');
    maxOut(state, 'orb_vitality');
    state.apply(byId('kinetic_overdrive'));
    state.noteOffered([
      OfferedPowerUpChoice(def: byId('missile_launcher'), currentLevel: 0),
      OfferedPowerUpChoice(def: byId('rapid_turret'), currentLevel: 0),
    ]);
    final key = GlobalKey();
    await show(
      tester,
      key,
      SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          color: const Color(0xFF0B0B10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const PanelSectionHeader('POWERUPS'),
              Text(
                'Spread Shot · Hunter Salvo · Homing Spread · …',
                style: hudMono(10, SurvivalInk.muted),
              ),
              const SizedBox(height: 14),
              const PanelSectionHeader('FUSIONS'),
              SurvivalFusionLedger(powerUps: state),
              const SizedBox(height: 14),
              const PanelSectionHeader('ALCHEMON STATS'),
            ],
          ),
        ),
      ),
    );
    await shoot(tester, key, 'fusion_pause');
  });

  // Each fusion's art beside its two parents', and the fusion again at two
  // later moments of its loop, to see it move.
  testWidgets('fusion art sheet', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view
      ..physicalSize = const Size(1640, 1500)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Widget art(PowerUpDef def, double dt, double size) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: UpgradeArtPainter(
          spec: upgradeArtFor(def),
          clock: ValueNotifier<double>(dt),
        ),
      ),
    );
    Widget cell(PowerUpDef def, String label, {double dt = 0}) => SizedBox(
      width: 112,
      child: Column(
        children: [
          art(def, dt, 96),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: hudMono(8.5, SurvivalInk.muted, spacing: 0.8),
          ),
        ],
      ),
    );
    Widget joint(String s) => SizedBox(
      width: 22,
      child: Text(
        s,
        textAlign: TextAlign.center,
        style: hudMono(14, SurvivalInk.plain),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Material(
            color: SurvivalInk.bg0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final fusion in kFusionPowerUps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          for (final (i, parent) in fusionParents(
                            fusion,
                          ).indexed) ...[
                            if (i > 0) joint('+'),
                            cell(parent, parent.name.toUpperCase()),
                          ],
                          joint('→'),
                          cell(fusion, fusion.name.toUpperCase()),
                          cell(fusion, '+0.9 S', dt: 0.9),
                          cell(fusion, '+1.8 S', dt: 1.8),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await shoot(tester, key, 'fusion_art');
  });

  testWidgets('results', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await show(
        tester,
        key,
        CosmicSurvivalGameOverPanel(
          wave: 23,
          kills: 1840,
          score: 48210,
          time: '14:32',
          rewards: [
            for (final (i, name, label) in const [
              (0, 'Silver', 'x 1,240'),
              (1, 'Fire Essence', 'x 18'),
              (2, 'Survival Shard', 'x 3'),
            ])
              LootOpeningEntry(
                icon: AppIcons.inventory_2_rounded,
                name: name,
                label: label,
                color: [
                  const Color(0xFFC4A35A),
                  const Color(0xFFE0703A),
                  const Color(0xFF9B7FE0),
                ][i],
              ),
          ],
          onQuit: () {},
          onNewTeam: () {},
          onReplay: () {},
        ),
      );
      await shoot(tester, key, 'results');
    } finally {
      debugDisableShadows = true;
    }
  });
}
