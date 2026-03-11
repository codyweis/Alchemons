import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

enum MusicCue {
  home,
  bossBattle,
  survival,
  wildSky,
  wildValley,
  wildVolcano,
  wildSwamp,
  wildArcane,
  planet,
  portal,
  endCredits,
  cosmicExploration,
}

class AudioController extends ChangeNotifier {
  static const double _defaultMusicVolume = 0.20;
  static const double _homeMusicVolume = 0.15;

  static const String _kMasterEnabled = 'audio.master_enabled';
  static const String _kMusicEnabled = 'audio.music_enabled';
  static const String _kSoundsEnabled = 'audio.sounds_enabled';
  static const String _kCosmicMusicCycleIndex =
      'audio.cosmic_music_cycle_index';

  static const Map<MusicCue, List<String>> _musicAssetsByCue = {
    MusicCue.home: ['assets/audio/music/homescreen.mp3'],
    MusicCue.bossBattle: ['assets/audio/music/bossbattle.mp3'],
    MusicCue.survival: [
      'assets/audio/music/survival.ogg',
      'assets/audio/music/survival.flac',
      'assets/audio/music/survival.mp3',
      'assets/audio/music/survival.m4a',
      'assets/audio/music/homescreen.mp3',
    ],
    MusicCue.wildSky: [
      'assets/audio/music/skywild.ogg',
      'assets/audio/music/skywild.flac',
      'assets/audio/music/skywild.mp3',
      'assets/audio/music/skywild.m4a',
      'assets/audio/music/valleywild.flac',
    ],
    MusicCue.wildValley: ['assets/audio/music/valleywild.flac'],
    MusicCue.wildVolcano: [
      'assets/audio/music/volcanowild.ogg',
      'assets/audio/music/volcanowild.flac',
      'assets/audio/music/volcanowild.mp3',
      'assets/audio/music/volcanowild.m4a',
      'assets/audio/music/valleywild.flac',
    ],
    MusicCue.wildSwamp: [
      'assets/audio/music/swampmusic.ogg',
      'assets/audio/music/swampmusic.flac',
      'assets/audio/music/swampmusic.mp3',
      'assets/audio/music/swampmusic.m4a',
      'assets/audio/music/valleywild.flac',
    ],
    MusicCue.wildArcane: [
      'assets/audio/music/arcanewild.ogg',
      'assets/audio/music/arcanewild.flac',
      'assets/audio/music/arcanewild.mp3',
      'assets/audio/music/arcanewild.m4a',
      'assets/audio/music/valleywild.flac',
    ],
    MusicCue.planet: ['assets/audio/music/planet.flac'],
    MusicCue.portal: ['assets/audio/music/portal.flac'],
    MusicCue.endCredits: ['assets/audio/music/endcredits.flac'],
    MusicCue.cosmicExploration: [
      'assets/audio/music/spaceexploration1.mp3',
      'assets/audio/music/spaceexploration2.flac',
    ],
  };

  final AlchemonsDatabase _db;
  final AudioPlayer _musicPlayer = AudioPlayer();
  late final Future<void> _bootstrapFuture;

  StreamSubscription<String?>? _masterSub;
  StreamSubscription<String?>? _musicSub;
  StreamSubscription<String?>? _soundsSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  bool _isLoaded = false;
  bool _masterEnabled = true;
  bool _musicEnabled = true;
  bool _soundsEnabled = true;
  int _cosmicCycleIndex = 0;
  String? _lastCosmicMusicAsset;
  bool _advancingCosmicTrack = false;

  MusicCue? _currentCue;
  String? _currentMusicAsset;

  AudioController(this._db) {
    _bootstrapFuture = _bootstrap();
  }

  bool get isLoaded => _isLoaded;
  bool get masterEnabled => _masterEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get soundsEnabled => _soundsEnabled;

  bool get effectiveMusicEnabled => _masterEnabled && _musicEnabled;
  bool get effectiveSoundsEnabled => _masterEnabled && _soundsEnabled;

  Future<void> _bootstrap() async {
    _masterEnabled = await _readBoolSetting(
      _kMasterEnabled,
      defaultValue: true,
    );
    _musicEnabled = await _readBoolSetting(_kMusicEnabled, defaultValue: true);
    _soundsEnabled = await _readBoolSetting(
      _kSoundsEnabled,
      defaultValue: true,
    );
    _cosmicCycleIndex = await _readIntSetting(
      _kCosmicMusicCycleIndex,
      defaultValue: 0,
    );

    _isLoaded = true;
    notifyListeners();

    _masterSub = _db.settingsDao.watchSetting(_kMasterEnabled).listen((raw) {
      final next = _parseBool(raw, fallback: true);
      if (next == _masterEnabled) return;
      _masterEnabled = next;
      notifyListeners();
      unawaited(_applyMusicState());
    });

    _musicSub = _db.settingsDao.watchSetting(_kMusicEnabled).listen((raw) {
      final next = _parseBool(raw, fallback: true);
      if (next == _musicEnabled) return;
      _musicEnabled = next;
      notifyListeners();
      unawaited(_applyMusicState());
    });

    _soundsSub = _db.settingsDao.watchSetting(_kSoundsEnabled).listen((raw) {
      final next = _parseBool(raw, fallback: true);
      if (next == _soundsEnabled) return;
      _soundsEnabled = next;
      notifyListeners();
    });

    _playerStateSub = _musicPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_handleTrackCompleted());
      }
    });

    await _musicPlayer.setLoopMode(LoopMode.one);
    await _applyMusicState();
  }

  Future<void> setMasterEnabled(bool enabled) async {
    await _bootstrapFuture;
    if (_masterEnabled == enabled) return;
    _masterEnabled = enabled;
    notifyListeners();
    await _db.settingsDao.setSetting(_kMasterEnabled, enabled ? '1' : '0');
    await _applyMusicState();
  }

  Future<void> setMusicEnabled(bool enabled) async {
    await _bootstrapFuture;
    if (_musicEnabled == enabled) return;
    _musicEnabled = enabled;
    notifyListeners();
    await _db.settingsDao.setSetting(_kMusicEnabled, enabled ? '1' : '0');
    await _applyMusicState();
  }

  Future<void> setSoundsEnabled(bool enabled) async {
    await _bootstrapFuture;
    if (_soundsEnabled == enabled) return;
    _soundsEnabled = enabled;
    notifyListeners();
    await _db.settingsDao.setSetting(_kSoundsEnabled, enabled ? '1' : '0');
  }

  Future<void> playHomeMusic() => playMusic(MusicCue.home);
  Future<void> playBossBattleMusic() => playMusic(MusicCue.bossBattle);
  Future<void> playSurvivalMusic() => playMusic(MusicCue.survival);
  Future<void> playPlanetMusic() => playMusic(MusicCue.planet);
  Future<void> playPortalMusic() => playMusic(MusicCue.portal);
  Future<void> playEndCreditsMusic() => playMusic(MusicCue.endCredits);
  Future<void> playCosmicExplorationMusic({bool cycle = true}) async {
    if (cycle) {
      await playMusic(MusicCue.cosmicExploration);
      return;
    }

    await _bootstrapFuture;

    if (_currentCue == MusicCue.cosmicExploration &&
        _currentMusicAsset != null) {
      await _applyMusicState();
      return;
    }

    final asset =
        _lastCosmicMusicAsset ??
        _musicAssetsByCue[MusicCue.cosmicExploration]!.first;

    _currentCue = MusicCue.cosmicExploration;

    final ordered = <String>[
      asset,
      ..._musicAssetsByCue[MusicCue.cosmicExploration]!.where(
        (a) => a != asset,
      ),
    ];

    var loaded = false;
    for (final candidate in ordered) {
      if (_currentMusicAsset == candidate) {
        loaded = true;
        break;
      }
      try {
        await _musicPlayer.setAsset(candidate);
        _currentMusicAsset = candidate;
        loaded = true;
        break;
      } catch (e) {
        debugPrint(
          'AudioController failed to set cosmic music candidate "$candidate": $e',
        );
      }
    }

    if (!loaded) {
      debugPrint(
        'AudioController: failed to restore cosmic exploration music.',
      );
      return;
    }

    await _applyMusicState();
  }

  Future<void> playWildMusicForScene(String sceneId) {
    final cue = switch (sceneId) {
      'sky' => MusicCue.wildSky,
      'volcano' => MusicCue.wildVolcano,
      'swamp' || 'poison' => MusicCue.wildSwamp,
      'arcane' => MusicCue.wildArcane,
      _ => MusicCue.wildValley,
    };
    return playMusic(cue);
  }

  Future<void> playMusic(MusicCue cue) async {
    await _bootstrapFuture;

    if (_currentCue == cue && _currentMusicAsset != null) {
      await _applyMusicState();
      return;
    }

    _currentCue = cue;

    final candidates = await _resolveAssetCandidatesForCue(cue);
    var loaded = false;

    for (final asset in candidates) {
      if (_currentMusicAsset == asset) {
        loaded = true;
        break;
      }
      try {
        await _musicPlayer.setAsset(asset);
        _currentMusicAsset = asset;
        loaded = true;
        break;
      } catch (e) {
        debugPrint('AudioController failed to load "$asset": $e');
      }
    }

    if (!loaded) {
      debugPrint('AudioController: no playable assets for cue $cue');
      return;
    }

    await _applyMusicState();
  }

  Future<void> _applyMusicState() async {
    if (_currentMusicAsset == null) return;

    try {
      await _syncLoopModeForCurrentCue();

      final targetVolume = effectiveMusicEnabled
          ? _volumeForCue(_currentCue)
          : 0.0;
      await _musicPlayer.setVolume(targetVolume);

      if (effectiveMusicEnabled) {
        if (!_musicPlayer.playing) {
          await _musicPlayer.play();
        }
      } else if (_musicPlayer.playing) {
        await _musicPlayer.pause();
      }
    } catch (e) {
      debugPrint('AudioController failed to update music state: $e');
    }
  }

  Future<void> _syncLoopModeForCurrentCue() async {
    final target = _currentCue == MusicCue.cosmicExploration
        ? LoopMode.off
        : LoopMode.one;
    if (_musicPlayer.loopMode == target) return;
    await _musicPlayer.setLoopMode(target);
  }

  Future<void> _handleTrackCompleted() async {
    if (_currentCue != MusicCue.cosmicExploration) return;
    if (!effectiveMusicEnabled) return;
    if (_advancingCosmicTrack) return;

    _advancingCosmicTrack = true;
    try {
      await _playNextCosmicTrack();
    } finally {
      _advancingCosmicTrack = false;
    }
  }

  Future<void> _playNextCosmicTrack() async {
    final assets = _musicAssetsByCue[MusicCue.cosmicExploration] ?? const [];
    if (assets.isEmpty) return;

    final currentIndex = assets.indexOf(_currentMusicAsset ?? '');
    final fallbackIndex = _cosmicCycleIndex % assets.length;
    final nextIndex = currentIndex >= 0
        ? (currentIndex + 1) % assets.length
        : fallbackIndex;

    final ordered = <String>[
      assets[nextIndex],
      ...[
        for (var i = 0; i < assets.length; i++)
          if (i != nextIndex) assets[i],
      ],
    ];

    for (final candidate in _prioritizeCodecCandidates(ordered)) {
      try {
        await _musicPlayer.setAsset(candidate);
        _currentMusicAsset = candidate;
        _lastCosmicMusicAsset = candidate;

        final selectedIndex = assets.indexOf(candidate);
        if (selectedIndex >= 0) {
          _cosmicCycleIndex = (selectedIndex + 1) % assets.length;
          unawaited(
            _db.settingsDao.setSetting(
              _kCosmicMusicCycleIndex,
              _cosmicCycleIndex.toString(),
            ),
          );
        }

        await _applyMusicState();
        return;
      } catch (e) {
        debugPrint(
          'AudioController failed to advance cosmic music to "$candidate": $e',
        );
      }
    }

    debugPrint('AudioController: failed to advance cosmic exploration music.');
  }

  double _volumeForCue(MusicCue? cue) {
    return cue == MusicCue.home ? _homeMusicVolume : _defaultMusicVolume;
  }

  Future<bool> _readBoolSetting(
    String key, {
    required bool defaultValue,
  }) async {
    final raw = await _db.settingsDao.getSetting(key);
    if (raw == null) {
      await _db.settingsDao.setSetting(key, defaultValue ? '1' : '0');
      return defaultValue;
    }
    return _parseBool(raw, fallback: defaultValue);
  }

  Future<int> _readIntSetting(String key, {required int defaultValue}) async {
    final raw = await _db.settingsDao.getSetting(key);
    final parsed = int.tryParse(raw ?? '');
    if (parsed != null) return parsed;
    await _db.settingsDao.setSetting(key, defaultValue.toString());
    return defaultValue;
  }

  bool _parseBool(String? raw, {required bool fallback}) {
    if (raw == null) return fallback;
    if (raw == '1') return true;
    if (raw == '0') return false;
    final lowered = raw.toLowerCase();
    if (lowered == 'true') return true;
    if (lowered == 'false') return false;
    return fallback;
  }

  Future<List<String>> _resolveAssetCandidatesForCue(MusicCue cue) async {
    final assets = _musicAssetsByCue[cue] ?? const <String>[];
    if (assets.isEmpty) {
      return const ['assets/audio/music/homescreen.mp3'];
    }

    if (cue != MusicCue.cosmicExploration || assets.length == 1) {
      return _prioritizeCodecCandidates(assets);
    }

    final selectedIndex = _cosmicCycleIndex % assets.length;
    final selected = assets[selectedIndex];
    _lastCosmicMusicAsset = selected;
    _cosmicCycleIndex = (_cosmicCycleIndex + 1) % assets.length;
    unawaited(
      _db.settingsDao.setSetting(
        _kCosmicMusicCycleIndex,
        _cosmicCycleIndex.toString(),
      ),
    );
    return _prioritizeCodecCandidates(<String>[
      selected,
      ...[
        for (var i = 0; i < assets.length; i++)
          if (i != selectedIndex) assets[i],
      ],
    ]);
  }

  List<String> _prioritizeCodecCandidates(List<String> candidates) {
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!isApple) return candidates;

    final nonOgg = <String>[];
    final ogg = <String>[];
    for (final c in candidates) {
      if (c.toLowerCase().endsWith('.ogg') ||
          c.toLowerCase().endsWith('.oga')) {
        ogg.add(c);
      } else {
        nonOgg.add(c);
      }
    }
    return <String>[...nonOgg, ...ogg];
  }

  @override
  void dispose() {
    _masterSub?.cancel();
    _musicSub?.cancel();
    _soundsSub?.cancel();
    _playerStateSub?.cancel();
    unawaited(_musicPlayer.dispose());
    super.dispose();
  }
}
