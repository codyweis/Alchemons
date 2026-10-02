// Device profiling entry point: the real app, logging frame timings. Not
// shipped.
//
//   flutter build apk --profile -t tool/frame_timing_main.dart
//   adb install -r build/app/outputs/flutter-apk/app-profile.apk
//   adb logcat -s flutter | grep FRAMES
//
// Every 240 frames it logs build and raster time (avg / p90 / max, ms) and
// how many frames ran over a 60 Hz and a 120 Hz budget. A screen at rest
// still produces frames while anything on it animates, so this measures an
// idle screen too.
import 'package:alchemons/main.dart' as app;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final build = <double>[], raster = <double>[];

  String stats(List<double> v) {
    final s = List<double>.of(v)..sort();
    final avg = s.reduce((a, b) => a + b) / s.length;
    final p90 = s[((s.length - 1) * 0.9).round()];
    return '${avg.toStringAsFixed(2)}/${p90.toStringAsFixed(2)}/'
        '${s.last.toStringAsFixed(2)}';
  }

  SchedulerBinding.instance.addTimingsCallback((frames) {
    for (final f in frames) {
      build.add(f.buildDuration.inMicroseconds / 1000);
      raster.add(f.rasterDuration.inMicroseconds / 1000);
    }
    if (build.length < 240) return;
    var over60 = 0, over120 = 0;
    for (var i = 0; i < build.length; i++) {
      final worst = build[i] > raster[i] ? build[i] : raster[i];
      if (worst > 16.7) over60++;
      if (worst > 8.3) over120++;
    }
    // ignore: avoid_print
    print(
      'FRAMES n=${build.length} build ${stats(build)} '
      'raster ${stats(raster)} over16.7=$over60 over8.3=$over120',
    );
    build.clear();
    raster.clear();
  });
  app.main();
}
