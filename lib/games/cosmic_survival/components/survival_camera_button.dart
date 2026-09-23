import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// A persistent camera-mode toggle, driven by the same state as arena gestures.
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
      const teal = Color(0xFF5EEAD4);
      final label = active ? 'Exit camera mode' : 'Zoom out and pan';
      return Semantics(
        button: true,
        toggled: active,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: active ? const Color(0xFF173C3C) : const Color(0xFF141C24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
              side: BorderSide(
                color: active ? teal : const Color(0xFF43515F),
                width: active ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  AppIcons.zoom_out_map_rounded,
                  color: active ? teal : const Color(0xFFBBC6D1),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
