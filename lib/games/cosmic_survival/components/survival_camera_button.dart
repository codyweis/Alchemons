import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

import 'survival_hud.dart';

/// A persistent camera-mode toggle, driven by the same state as arena gestures.
/// A console key like the HUD's others, lit while the camera is free.
class SurvivalCameraButton extends StatelessWidget {
  const SurvivalCameraButton({
    super.key,
    required this.cameraMode,
    required this.onToggle,
  });

  final ValueListenable<bool> cameraMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: cameraMode,
    builder: (context, active, _) {
      final label = active ? 'Exit camera mode' : 'Zoom out and pan';
      return Semantics(
        button: true,
        toggled: active,
        label: label,
        child: Tooltip(
          message: label,
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: (active ? HudInk.amber : HudInk.line).withValues(
                alpha: 0.9,
              ),
              bracketSize: 7,
              strokeWidth: 1.1,
            ),
            child: Material(
              color: active
                  ? const Color(0xFF1E1A10)
                  : HudInk.glass.withValues(alpha: 0.86),
              child: InkWell(
                onTap: onToggle,
                splashFactory: NoSplash.splashFactory,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    AppIcons.zoom_out_map_rounded,
                    color: active ? HudInk.amber : HudInk.muted,
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
