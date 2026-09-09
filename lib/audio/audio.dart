import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/providers/audio_provider.dart';
export 'package:alchemons/providers/audio_provider.dart' show SoundCue;

/// Optional in isolated previews/tests; production provides AudioController.
extension SoundContext on BuildContext {
  AudioController? get audio => read<AudioController?>();
  void sound(SoundCue cue, {Object? owner, double speed = 1}) {
    final controller = audio;
    if (controller != null) {
      unawaited(controller.playSound(cue, owner: owner, speed: speed));
    }
  }

  /// Feedback for an ordinary tap: a haptic, and nothing audible.
  ///
  /// This used to default to [SoundCue.uiTap], which put a sound on every
  /// button, back arrow and dismiss in the app — around 500 call sites. Sound
  /// is reserved for things worth hearing (collecting, purchasing, unlocking);
  /// everything else is felt, not heard.
  ///
  /// Pass [cue] for the handful of taps that do earn a sound. It still fires
  /// only if the action did not itself navigate or play something.
  VoidCallback? soundAction(VoidCallback? action, [SoundCue? cue]) {
    if (action == null) return null;
    return () {
      // lightImpact, not selectionClick: on Android the latter maps to
      // CLOCK_TICK, which is faint enough to be imperceptible next to the
      // lightImpact/mediumImpact this app already uses elsewhere — it read as
      // "taps have no haptic at all".
      HapticFeedback.lightImpact();
      final controller = audio;
      final serial = controller?.soundEventSerial;
      action();
      if (cue != null &&
          controller != null &&
          controller.soundEventSerial == serial) {
        unawaited(controller.playSound(cue));
      }
    };
  }
}
