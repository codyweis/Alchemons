import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

Widget buildLoadingScreen(FactionTheme theme, String message) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.2,
          colors: [
            theme.surface,
            theme.surface,
            theme.surfaceAlt.withOpacity(.6),
          ],
          stops: const [0, .6, 1],
        ),
      ),
      child: Center(
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withOpacity(.4),
                blurRadius: 28,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.8),
                blurRadius: 40,
                spreadRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(theme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
