import 'package:flutter/material.dart';

extension SoftPush on BuildContext {
  Future<T?> pushSoft<T>(Widget page) => Navigator.of(this).push<T>(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final curve = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    ),
  );
}
