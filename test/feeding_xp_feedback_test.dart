import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/feeding/feeding_widgets.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _RecordingAudio extends Fake implements AudioController {
  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  int soundEventSerial = 0;

  final sounds = <SoundCue>[];

  @override
  Future<void> playSound(
    SoundCue cue, {
    Object? owner,
    double speed = 1,
  }) async {
    soundEventSerial++;
    sounds.add(cue);
  }

  @override
  void stopSoundOwner(Object owner) {}
}

Creature _creature() => Creature(
  id: 'TST01',
  name: 'Test Specimen',
  types: const ['Water'],
  rarity: 'Common',
  description: 'A specimen used to verify feeding feedback.',
  image: 'creatures/common/LET02_waterlet.png',
  spriteData: SpriteData(
    frameWidth: 64,
    frameHeight: 64,
    totalFrames: 4,
    frameDurationMs: 120,
    rows: 1,
    spriteSheetPath: 'creatures/common/LET02_waterlet_spritesheet.png',
  ),
);

CreatureInstance _instance({required int level, int xp = 0}) =>
    CreatureInstance(
      instanceId: 'i1',
      baseId: 'TST01',
      level: level,
      xp: xp,
      locked: false,
      isPrismaticSkin: false,
      source: 'test',
      staminaMax: 3,
      staminaBars: 3,
      staminaLastUtcMs: 0,
      createdAtUtcMs: 0,
      statSpeed: 7.25,
      statIntelligence: 6.5,
      statStrength: 8.0,
      statBeauty: 5.75,
      statSpeedPotential: 70,
      statIntelligencePotential: 70,
      statStrengthPotential: 70,
      statBeautyPotential: 70,
      statSpeedEnhancement: 0,
      statIntelligenceEnhancement: 0,
      statStrengthEnhancement: 0,
      statBeautyEnhancement: 0,
      generationDepth: 0,
      isPure: true,
      isFavorite: false,
    );

void main() {
  testWidgets('XP fill and level threshold each have distinct feedback', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    final catalog = CreatureCatalog.fromList([_creature()]);
    final instance = _instance(level: 10);

    Widget host(bool animating) => MultiProvider(
      providers: [
        Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        Provider<CreatureCatalog>.value(value: catalog),
        ChangeNotifierProvider<AudioController>.value(value: audio),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: XPBarDisplay(
            theme: FactionTheme.scorchForge(),
            instance: instance,
            isAnimating: animating,
            preFeedLevel: 9,
            preFeedXp: 0,
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(false));
    expect(find.text('MAX LEVEL'), findsOneWidget);

    await tester.pumpWidget(host(true));
    await tester.pump();
    expect(audio.sounds, [SoundCue.rewardCollect]);
    expect(find.text('MAX LEVEL'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(audio.sounds, [SoundCue.rewardCollect, SoundCue.upgradeComplete]);

    await tester.pumpWidget(host(false));
    expect(find.text('MAX LEVEL'), findsOneWidget);
  });

  testWidgets('a fully trained target keeps its final stats visible', (
    tester,
  ) async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final effects = ConstellationEffectsService(db);
    addTearDown(effects.dispose);
    final creature = _creature();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(
            value: CreatureCatalog.fromList([creature]),
          ),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: effects,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 500,
              child: FeedTargetPanel(
                theme: FactionTheme.scorchForge(),
                targetInstance: _instance(level: 10),
                targetCreature: creature,
                preview: null,
                shouldAnimate: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Training Complete! Level 10 reached.'), findsOneWidget);
    expect(find.text('POWER'), findsOneWidget);
    expect(find.text('SPD'), findsOneWidget);
    expect(find.text('MAX LEVEL'), findsOneWidget);
  });
}
