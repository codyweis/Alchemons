import 'dart:async';
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

  VoidCallback? soundAction(
    VoidCallback? action, [
    SoundCue cue = SoundCue.uiTap,
  ]) {
    if (action == null) return null;
    return () {
      final controller = audio;
      final serial = controller?.soundEventSerial;
      action();
      if (controller != null && controller.soundEventSerial == serial) {
        unawaited(controller.playSound(cue));
      }
    };
  }
}
