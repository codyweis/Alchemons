import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/audio/sound_cue.dart';
import 'package:alchemons/audio/ambience_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all ambience beds are bundled stereo WAVs', () async {
    for (final cue in AmbienceCue.values) {
      final bytes = await rootBundle.load(cue.asset);
      expect(bytes.getUint16(22, Endian.little), 2, reason: cue.name);
      expect(bytes.lengthInBytes, greaterThan(48000 * 4), reason: cue.name);
    }
  });
  test('every cue and variation is bundled as a playable WAV', () async {
    for (final cue in SoundCue.values) {
      for (var i = 0; i < (cue.hasVariants ? 4 : 1); i++) {
        final bytes = await rootBundle.load(cue.assetForVariant(i));
        expect(bytes.lengthInBytes, greaterThan(44), reason: cue.name);
        expect(
          String.fromCharCodes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, 4),
          ),
          'RIFF',
        );
      }
    }
    expect(SoundCue.forElement('Fire'), SoundCue.elementFire);
    expect(SoundCue.forElement('LIGHTNING'), SoundCue.elementLightning);
    expect(SoundCue.forElement('unknown'), isNull);
  });
}
