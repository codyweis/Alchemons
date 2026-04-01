// lib/models/story/story_page.dart

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/screens/story/models/story_persistance.dart';
import 'package:flutter/material.dart';

enum StoryPageType {
  quote, // Text-heavy philosophical quotes
  elementIntro, // Short chapter-card style text
  loading, // Loading screen with progress bar
}

enum StoryEvent { firstBreeding }

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
      case StoryEvent.firstBreeding:
        _queue.addAll(AlchemonsStory.breedingIntro);
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
  final String? subtitle;
  final Color? textColor;
  final Color? backgroundColor;
  final String? backgroundImagePath; // For loading screen
  final bool useTypewriterEffect;

  const StoryPage({
    required this.type,
    required this.mainText,
    this.subtitle,
    this.textColor,
    this.backgroundColor,
    this.backgroundImagePath,
    this.useTypewriterEffect = false,
  });
}

// Story content currently wired into the game.
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

  static List<StoryPage> get allPages => [
    ...darkPrelude,
    const StoryPage(
      type: StoryPageType.loading,
      mainText: 'INITIALIZING LABORATORY SYSTEMS',
      backgroundColor: Colors.black,
      backgroundImagePath: 'assets/images/background_loading.png',
    ),
  ];
}
