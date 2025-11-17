// lib/models/story/story_page.dart

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/screens/story/models/story_persistance.dart';
import 'package:flutter/material.dart';

enum StoryPageType {
  quote, // Text-heavy philosophical quotes
  narrative, // Standard narrative text
  creatureReveal, // Show a creature with text
  elementIntro, // Introduce an element/faction concept
  loading, // Loading screen with progress bar
}

enum StoryEvent {
  firstBoot,
  firstWilderness,
  firstBreeding,
  firstCreatureCaught,
  periodicWhisper, // fire occasionally
}

class StoryManager extends ChangeNotifier {
  final StoryPersistence _persist;
  StoryManager(SettingsDao settingsDao)
    : _persist = StoryPersistence(settingsDao);

  final Set<StoryEvent> _seen = {};
  final List<StoryPage> _queue = [];

  /// Call once at app boot (e.g., from a provider init).
  Future<void> loadSeen() async {
    final loaded = await _persist.loadSeen();
    _seen
      ..clear()
      ..addAll(loaded);
  }

  Future<void> _saveSeen() async {
    await _persist.saveSeen(_seen);
  }

  bool hasSeen(StoryEvent e) => _seen.contains(e);

  void trigger(StoryEvent e) {
    if (_seen.contains(e)) return;

    _seen.add(e);
    _saveSeen(); // fire-and-forget is okay; no await needed here

    switch (e) {
      case StoryEvent.firstBoot:
        _queue.addAll(AlchemonsStory.darkPrelude);
        _queue.addAll(AlchemonsStory.labBoot);
        break;
      case StoryEvent.firstWilderness:
        _queue.addAll(AlchemonsStory.wildernessIntro);
        break;
      case StoryEvent.firstBreeding:
        _queue.addAll(AlchemonsStory.breedingIntro);
        break;
      case StoryEvent.firstCreatureCaught:
        _queue.addAll(AlchemonsStory.firstCreatureReveal);
        break;
      case StoryEvent.periodicWhisper:
        _queue.add(
          StoryPage(
            type: StoryPageType.narrative,
            mainText: (AlchemonsStory.unknownWhispers..shuffle()).first,
            backgroundColor: const Color(0xFF0A0A0A),
            textColor: const Color(0xFFE8E8E8),
            autoAdvanceDuration: const Duration(milliseconds: 1200),
            useTypewriterEffect: true,
          ),
        );
        break;
    }

    notifyListeners();
  }

  List<StoryPage> drainQueue() {
    final out = List<StoryPage>.from(_queue);
    _queue.clear();
    return out;
  }
}

class StoryPage {
  final StoryPageType type;
  final String mainText;
  final String? attribution; // For quotes
  final String? subtitle;
  final Color? textColor;
  final Color? backgroundColor;
  final String? creatureId; // For creature reveals
  final String? backgroundImagePath; // For loading screen
  final Duration autoAdvanceDuration; // 0 = manual only
  final bool useTypewriterEffect;

  const StoryPage({
    required this.type,
    required this.mainText,
    this.attribution,
    this.subtitle,
    this.textColor,
    this.backgroundColor,
    this.creatureId,
    this.backgroundImagePath,
    this.autoAdvanceDuration = Duration.zero,
    this.useTypewriterEffect = false,
  });
}

// Story content definition
class AlchemonsStory {
  static List<StoryPage> get darkPrelude => [
    // Slide 1: Natural History
    const StoryPage(
      type: StoryPageType.quote,
      mainText:
          '"In the history of science the collector of specimens preceded the zoologist and followed the exponents of natural theology and magic."',
      textColor: Color(0xFFE8E8E8),
      backgroundColor: Color(0xFF0A0A0A),
    ),

    // Slide 2: The Collector's Purpose
    const StoryPage(
      type: StoryPageType.quote,
      mainText:
          '"But, except in a rudimentary way, he was not yet a physiologist, ecologist, or student of animal behaviour. His primary concern was to make a census, to catch, kill, stuff, and describe as many kinds of beasts as he could lay his hands on."',
      textColor: Color(0xFFE8E8E8),
      backgroundColor: Color(0xFF0A0A0A),
    ),

    // Slide 3: Alchemy's Sin
    const StoryPage(
      type: StoryPageType.quote,
      mainText:
          '"Alchemy\'s not love, it\'s playing God. And there\'s a penance paid for entering the temple like a fraud in your charade."',
      textColor: Color(0xFFE8E8E8),
      backgroundColor: Color(0xFF0A0A0A),
    ),

    // Slide 4: Father's DNA
    const StoryPage(
      type: StoryPageType.quote,
      mainText:
          '"Did you know the father\'s DNA stays inside the mother for seven years?"',
      textColor: Color(0xFFE8E8E8),
      backgroundColor: Color(0xFF0A0A0A),
    ),

    // Slide 5: Waited Seven Years
    const StoryPage(
      type: StoryPageType.quote,
      mainText: '"Have you ever waited seven years?"',
      textColor: Color(0xFFE8E8E8),
      backgroundColor: Color(0xFF0A0A0A),
    ),

    // Slide 6: Still Asleep
    const StoryPage(
      type: StoryPageType.quote,
      mainText:
          '"Have you ever woken from a dream just to realize that you\'re still asleep?"',
      textColor: Color(0xFFE8E8E8),
      backgroundColor: Color(0xFF0A0A0A),
    ),

    // Slide 7: Wish You Were Asleep
    const StoryPage(
      type: StoryPageType.quote,
      mainText: '"Do you ever wish you were still asleep?"',
      textColor: Color(0xFFE8E8E8),
      backgroundColor: Color(0xFF0A0A0A),
    ),

    // Slide 8: Wish Not to Wake
    const StoryPage(
      type: StoryPageType.quote,
      mainText: '"Do you ever wish you wouldn\'t wake up?"',
      textColor: Color(0xFFE8E8E8),
      backgroundColor: Color(0xFF0A0A0A),
    ),
  ];

  static List<StoryPage> get labBoot => [
    StoryPage(
      type: StoryPageType.loading,
      mainText: 'INITIALIZING LABORATORY SYSTEMS [ v3.7 ]',
      backgroundColor: Colors.black,
      backgroundImagePath: 'assets/images/ui/trialsicon.png',
    ),
    const StoryPage(
      type: StoryPageType.narrative,
      mainText: 'Signal acquired.\nRole: Creator?  Confidence: 51%.',
      subtitle: 'If you are not the Creator, please remain still.',
      backgroundColor: Color(0xFF0A0A0A),
      textColor: Color(0xFFE8E8E8),
      useTypewriterEffect: true,
    ),
    const StoryPage(
      type: StoryPageType.narrative,
      mainText:
          'We kept your name somewhere safe. We just can’t open the door.',
      backgroundColor: Color(0xFF0A0A0A),
      textColor: Color(0xFFE8E8E8),
      useTypewriterEffect: true,
    ),
  ];

  static List<StoryPage> get wildernessIntro => [
    const StoryPage(
      type: StoryPageType.elementIntro,
      mainText: 'THE WILDERNESS',
      subtitle: 'Unmapped. Unsterilized. Unfinished.',
      backgroundColor: Color(0xFF030E07),
      textColor: Color(0xFFE8FFE8),
      useTypewriterEffect: true,
    ),
    const StoryPage(
      type: StoryPageType.narrative,
      mainText:
          'Air tastes like memory. Grass repeats your footsteps one second late.',
      backgroundColor: Color(0xFF030E07),
      textColor: Color(0xFFE8FFE8),
    ),
    const StoryPage(
      type: StoryPageType.quote,
      mainText: '"Did you make this place, or did it practice you first?"',
      backgroundColor: Color(0xFF030E07),
      textColor: Color(0xFFA7FFC8),
    ),
  ];

  static List<StoryPage> get firstCreatureReveal => [
    const StoryPage(
      type: StoryPageType.creatureReveal,
      mainText: 'It notices you noticing it.',
      creatureId: 'sproutling', // your internal id
      backgroundColor: Color(0xFF0D0E10),
      textColor: Color(0xFFE8E8E8),
      useTypewriterEffect: true,
    ),
    const StoryPage(
      type: StoryPageType.quote,
      mainText: '"Names are leashes that feel like crowns."',
      backgroundColor: Color(0xFF0D0E10),
      textColor: Color(0xFFE8E8E8),
    ),
  ];

  static List<StoryPage> get breedingIntro => [
    const StoryPage(
      type: StoryPageType.elementIntro,
      mainText: 'Did two ever exist?',
      subtitle: 'Two becomes one again.',
      backgroundColor: Color(0xFF101010),
      textColor: Color(0xFFE0D2FF),
      useTypewriterEffect: true,
    ),
  ];

  static const unknownWhispers = [
    'Creator? Or echo?',
    'If you wake, who sleeps?',
    'Seven years is long enough to borrow a name.',
    'We remember you differently each time.',
  ];

  static List<StoryPage> get allPages => [
    ...darkPrelude,
    // ...elementalIntroduction,

    // Final loading screen
    const StoryPage(
      type: StoryPageType.loading,
      mainText: 'INITIALIZING LABORATORY SYSTEMS',
      backgroundColor: Colors.black,
      backgroundImagePath: 'assets/images/ui/trialsicon.png',
    ),
  ];
}
