// A cue the controller only *believes* it is on will play the wrong track
// forever.
//
// playMusic short-circuits when the requested cue is already current. That
// is right, but it used to commit the cue BEFORE loading the asset, so a
// load that failed left the controller claiming a cue whose file had never
// been set — and every later request for that cue hit the short circuit and
// returned without touching the player. The previous screen's music then
// played for the rest of the session, at the new cue's volume, with nothing
// able to correct it.
//
// These pin the invariant that makes that impossible: the recorded cue and
// the loaded asset always agree.

import 'package:alchemons/providers/audio_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every cue owns at least one asset', () {
    // The short circuit now asks whether the current asset belongs to the
    // cue. A cue with no assets could never satisfy that and would reload
    // on every single request.
    for (final cue in MusicCue.values) {
      expect(
        AudioController.assetsForCue(cue),
        isNotEmpty,
        reason: '${cue.name} has no audio to play',
      );
    }
  });

  test('cues may share a fallback file, and the guard still works', () {
    // homescreen.mp3 is listed under survival as a fallback, so ownership
    // is deliberately not exclusive. That is safe because the short circuit
    // tests the cue AND the asset together — a shared file only matches
    // when the caller asked for that cue anyway.
    final shared = AudioController.assetsForCue(MusicCue.home)
        .toSet()
        .intersection(AudioController.assetsForCue(MusicCue.survival).toSet());
    expect(shared, isNotEmpty, reason: 'survival falls back to home audio');
    for (final asset in shared) {
      expect(AudioController.assetBelongsToCue(asset, MusicCue.home), isTrue);
      expect(
        AudioController.assetBelongsToCue(asset, MusicCue.cosmicExploration),
        isFalse,
        reason: 'sharing a fallback must not make it cosmic',
      );
    }
  });

  test('an asset is recognised only by the cue that owns it', () {
    final cosmic = AudioController.assetsForCue(MusicCue.cosmicExploration);
    final home = AudioController.assetsForCue(MusicCue.home);

    expect(
      AudioController.assetBelongsToCue(cosmic.first, MusicCue.cosmicExploration),
      isTrue,
    );
    // The exact confusion that pinned the bug: home's file, cosmic's cue.
    expect(
      AudioController.assetBelongsToCue(home.first, MusicCue.cosmicExploration),
      isFalse,
    );
    expect(
      AudioController.assetBelongsToCue(null, MusicCue.home),
      isFalse,
      reason: 'nothing loaded is never a match',
    );
  });
}
