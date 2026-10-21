import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

import 'survival_hud.dart';

/// The zoom key, driven by the same state as the arena gestures. One key
/// cycles the camera: freed (lit; drag pans, pinch zooms, the ship flies
/// itself), then that zoom locked for flying (a lock), then back to the
/// run's own zoom.
class SurvivalCameraButton extends StatelessWidget {
  const SurvivalCameraButton({
    super.key,
    required this.cameraMode,
    required this.zoomLocked,
    required this.onToggle,
  });

  final ValueListenable<bool> cameraMode;
  final ValueListenable<bool> zoomLocked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([cameraMode, zoomLocked]),
    builder: (context, _) {
      final free = cameraMode.value;
      final locked = !free && zoomLocked.value;
      final lit = free || locked;
      final label = free
          ? 'Lock this zoom and fly'
          : locked
          ? 'Back to the normal zoom'
          : 'Zoom out and pan';
      return Semantics(
        button: true,
        toggled: lit,
        label: label,
        child: Tooltip(
          message: label,
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: (lit ? HudInk.amber : HudInk.line).withValues(alpha: 0.9),
              bracketSize: 7,
              strokeWidth: 1.1,
            ),
            child: Material(
              color: lit
                  ? const Color(0xFF1E1A10)
                  : HudInk.glass.withValues(alpha: 0.86),
              child: InkWell(
                onTap: onToggle,
                splashFactory: NoSplash.splashFactory,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    locked
                        ? AppIcons.lock_rounded
                        : AppIcons.zoom_out_map_rounded,
                    color: lit ? HudInk.amber : HudInk.muted,
                    size: 18.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
