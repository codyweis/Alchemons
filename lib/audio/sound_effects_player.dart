import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'sound_cue.dart';

/// Small injectable boundary: tests exercise scheduling without platform audio.
abstract class SoundVoice {
  Future<void> load(String asset);
  Future<void> configure(double volume, double speed);
  Future<void> play();
  Future<void> dispose();
}

class JustAudioSoundVoice implements SoundVoice {
  final AudioPlayer _player = AudioPlayer();
  @override
  Future<void> load(String asset) async {
    await _player.setAsset(asset);
  }

  @override
  Future<void> configure(double volume, double speed) async {
    await _player.seek(Duration.zero);
    await _player.setVolume(volume);
    await _player.setSpeed(speed);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> dispose() => _player.dispose();
}

class _VoiceUse {
  _VoiceUse(this.voice, this.asset, this.cue, this.owner);
  final SoundVoice voice;
  final String asset;
  final SoundCue cue;
  final Object? owner;
}

/// At most six active effects and eight cached players. Warnings may displace
/// ordinary effects; ordinary effects never cut off a warning or reveal.
class SoundEffectsPlayer {
  SoundEffectsPlayer({
    SoundVoice Function()? createVoice,
    int Function()? nowMs,
  }) : _createVoice = createVoice ?? JustAudioSoundVoice.new,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
  final SoundVoice Function() _createVoice;
  final int Function() _nowMs;
  final _active = <_VoiceUse>[];
  final _idle = <_VoiceUse>[];
  final _lastPlayed = <SoundCue, int>{};
  final _variant = <SoundCue, int>{};
  bool _enabled = true;
  bool _disposed = false;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) stopAll();
  }

  Future<void> _disposeVoice(SoundVoice voice) async {
    try {
      await voice.dispose();
    } catch (e) {
      debugPrint('SFX dispose: $e');
    }
  }

  void stopOwner(Object owner) {
    final stopped = _active.where((v) => identical(v.owner, owner)).toList();
    _active.removeWhere((v) => identical(v.owner, owner));
    for (final v in stopped) {
      unawaited(_disposeVoice(v.voice));
    }
  }

  void stopAll() {
    final stopped = [..._active, ..._idle];
    _active.clear();
    _idle.clear();
    _lastPlayed.clear();
    for (final v in stopped) {
      unawaited(_disposeVoice(v.voice));
    }
  }

  Future<void> play(SoundCue cue, {Object? owner, double speed = 1}) async {
    if (_disposed || !_enabled) return;
    final now = _nowMs();
    final last = _lastPlayed[cue];
    if (last != null && now - last < cue.cooldownMs) return;
    if (_active.length >= 6) {
      final victims = _active.where((v) => v.cue.priority < cue.priority);
      if (victims.isEmpty) return;
      final victim = victims.reduce(
        (a, b) => a.cue.priority <= b.cue.priority ? a : b,
      );
      _active.remove(victim);
      unawaited(_disposeVoice(victim.voice));
    }
    _lastPlayed[cue] = now;
    final index = _variant[cue] ?? 0;
    _variant[cue] = index + 1;
    final asset = cue.assetForVariant(index);
    final cached = _idle.where((v) => v.asset == asset).firstOrNull;
    if (cached != null) _idle.remove(cached);
    final use = _VoiceUse(cached?.voice ?? _createVoice(), asset, cue, owner);
    _active.add(use); // Reserve before any await: bursts cannot over-allocate.
    var healthy = false;
    try {
      if (cached == null) await use.voice.load(asset);
      if (!_active.contains(use)) return;
      await use.voice.configure(.70 * cue.gain, speed.clamp(.5, 3.0));
      if (!_active.contains(use)) return;
      await use.voice.play();
      healthy = true;
    } catch (e) {
      debugPrint('SFX ${cue.name}: $e');
    } finally {
      // Cancel/dispose owns disposal if it removed this lease during an await.
      if (_active.remove(use)) {
        if (healthy && !_disposed && _enabled) {
          _idle.add(use);
          if (_idle.length > 8) {
            unawaited(_disposeVoice(_idle.removeAt(0).voice));
          }
        } else {
          unawaited(_disposeVoice(use.voice));
        }
      }
    }
  }

  void dispose() {
    _disposed = true;
    stopAll();
  }
}
