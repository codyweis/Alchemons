import 'package:alchemons/constants/egg.dart';
import 'package:alchemons/widgets/animations/hatch_animation.dart';
import 'package:flutter/material.dart';

Future<void> playHatchCinematic(
  BuildContext context,
  String assetPath,
  EggPalette palette,
) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'hatch',
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) {
      return HatchCinematic(
        palette: palette,
        triggerAt: 0.7,
        lottieAsset: assetPath,
        onFinished: () {
          Navigator.of(context, rootNavigator: true).pop(); // close overlay
        },
      );
    },
    transitionBuilder: (_, anim, __, child) {
      // Soft fade-in of the cinematic itself
      return FadeTransition(opacity: anim, child: child);
    },
  );
}
