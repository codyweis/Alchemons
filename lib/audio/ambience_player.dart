import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

enum AmbienceCue {
  cosmicSpace('amb_cosmic_space_loop'),
  dungeonRuins('amb_dungeon_ruins_loop'),
  dungeonWater('amb_dungeon_water_loop'),
  dungeonFire('amb_dungeon_fire_loop'),
  dungeonArcane('amb_dungeon_arcane_loop'),
  lab('amb_lab_loop');

  const AmbienceCue(this.filename);
  final String filename;
  String get asset => 'assets/audio/sounds/$filename.wav';

  static AmbienceCue forDungeon(String element) =>
      switch (element.toLowerCase()) {
        'fire' || 'lava' || 'steam' => dungeonFire,
        'water' || 'ice' || 'mud' || 'poison' => dungeonWater,
        'crystal' ||
        'spirit' ||
        'light' ||
        'dark' ||
        'lightning' ||
        'blood' => dungeonArcane,
        _ => dungeonRuins,
      };
}

abstract class AmbienceVoice {
  Future<void> load(String asset);
  Future<void> volume(double value);
  Future<void> play();
  Future<void> dispose();
}

class _JustAudioAmbienceVoice implements AmbienceVoice {
  final _player = AudioPlayer();
  @override
  Future<void> load(String asset) async {
    await _player.setLoopMode(LoopMode.one);
    await _player.setAsset(asset);
  }

  @override
  Future<void> volume(double value) => _player.setVolume(value);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> dispose() => _player.dispose();
}

/// One ambience bed at a time, outside the six-voice one-shot budget. All
/// transitions serialize; a stale load can never start behind a newer scene.
class AmbiencePlayer {
  AmbiencePlayer({
    AmbienceVoice Function()? createVoice,
    Future<void> Function(Duration)? delay,
  }) : _createVoice = createVoice ?? _JustAudioAmbienceVoice.new,
       _delay = delay ?? Future<void>.delayed;
  final AmbienceVoice Function() _createVoice;
  final Future<void> Function(Duration) _delay;
  Object? _owner;
  AmbienceCue? _requested;
  AmbienceCue? _playing;
  AmbienceVoice? _voice;
  bool _enabled = false;
  bool _disposed = false;
  int _revision = 0;
  Future<void> _queue = Future<void>.value();
  Future<void> get settled => _queue;

  void setScene(Object owner, AmbienceCue cue) {
    if (_disposed) return;
    if (identical(owner, _owner) && _requested == cue) return;
    _owner = owner;
    _requested = cue;
    _schedule();
  }

  void stopOwner(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _requested = null;
    _schedule();
  }

  void setEnabled(bool enabled) {
    if (_enabled == enabled || _disposed) return;
    _enabled = enabled;
    _schedule();
  }

  void _schedule() {
    final revision = ++_revision;
    _queue = _queue.then((_) => _reconcile(revision)).catchError((Object e) {
      debugPrint('Ambience transition: $e');
    });
  }

  Future<void> _reconcile(int revision) async {
    if (revision != _revision) return;
    final target = !_disposed && _enabled ? _requested : null;
    if (_playing == target && _voice != null) return;
    final old = _voice;
    _voice = null;
    _playing = null;
    if (old != null) {
      try {
        // Mute/background stops immediately; ordinary scene changes fade out.
        if (_enabled && !_disposed) {
          for (final volume in [.12, .06, 0.0]) {
            await old.volume(volume);
            await _delay(const Duration(milliseconds: 30));
          }
        } else {
          await old.volume(0);
        }
      } finally {
        await old.dispose();
      }
    }
    if (revision != _revision || target == null) return;
    final next = _createVoice();
    var adopted = false;
    try {
      await next.load(target.asset);
      if (revision != _revision) return;
      await next.volume(0);
      if (revision != _revision) return;
      _voice = next;
      _playing = target;
      adopted = true;
      unawaited(
        next.play().catchError((Object e) {
          debugPrint('Ambience playback: $e');
          if (identical(_voice, next)) {
            _voice = null;
            _playing = null;
            unawaited(
              next.dispose().catchError((Object error) {
                debugPrint('Ambience dispose: $error');
              }),
            );
          }
        }),
      );
      for (final volume in [.06, .12, .18]) {
        if (revision != _revision || !identical(_voice, next)) break;
        await next.volume(volume);
        await _delay(const Duration(milliseconds: 30));
      }
    } catch (_) {
      if (identical(_voice, next)) {
        _voice = null;
        _playing = null;
        adopted = false;
      }
      rethrow;
    } finally {
      if (!adopted) await next.dispose();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _requested = null;
    _schedule();
  }
}
