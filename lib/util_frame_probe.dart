// TEMPORARY — frame probe for hunting device jank. Delete when done.
//
// Widget tests never rasterise, so no headless measurement in this repo can
// see GPU cost. This reports real frames off the device, split into build
// (CPU/Dart) and raster (GPU), which is the split that says which side a
// stutter is on.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

bool _installed = false;
int _slow = 0;
int _total = 0;
double _sumBuild = 0;
double _sumRaster = 0;
double _worstBuild = 0;
double _worstRaster = 0;

void installFrameProbe() {
  if (_installed) return;
  _installed = true;
  debugPrint('FRAMEPROBE installed');
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      _total++;
      final build = t.buildDuration.inMicroseconds / 1000.0;
      final raster = t.rasterDuration.inMicroseconds / 1000.0;
      final total = build + raster;
      _sumBuild += build;
      _sumRaster += raster;
      if (build > _worstBuild) _worstBuild = build;
      if (raster > _worstRaster) _worstRaster = raster;
      if (total >= 14) {
        _slow++;
        debugPrint(
          'FRAMEPROBE slow build=${build.toStringAsFixed(1)} '
          'raster=${raster.toStringAsFixed(1)} '
          'total=${total.toStringAsFixed(1)}ms',
        );
      }
      if (_total % 120 == 0) {
        debugPrint(
          'FRAMESUMMARY n=$_total slow=$_slow '
          'avgBuild=${(_sumBuild / _total).toStringAsFixed(1)} '
          'avgRaster=${(_sumRaster / _total).toStringAsFixed(1)} '
          'worstBuild=${_worstBuild.toStringAsFixed(1)} '
          'worstRaster=${_worstRaster.toStringAsFixed(1)}',
        );
        _worstBuild = 0;
        _worstRaster = 0;
      }
    }
  });
}
