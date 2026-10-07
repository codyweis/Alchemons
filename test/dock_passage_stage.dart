// A stand-in for home with one of the dock's emblems where home puts it,
// for previewing that emblem's way in over the real screen it opens.

import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/widgets/dock_emblems.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Home's ink, a faint realm, and [kind]'s emblem on the left dock.
class DockStandIn extends StatelessWidget {
  const DockStandIn({
    super.key,
    required this.kind,
    required this.emblemKey,
    required this.lifted,
    this.size = 70,
    this.top = 300,
    this.orb = OrbBaseSkin.defaultOrb,
  });

  final DockEmblemKind kind;
  final GlobalKey emblemKey;
  final ValueListenable<bool> lifted;
  final double size;
  final double top;
  final OrbBaseSkin orb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.1,
                  colors: [Color(0xFF2A2430), Color(0xFF0C0C0F)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: top,
            child: ValueListenableBuilder<bool>(
              valueListenable: lifted,
              builder: (_, away, child) =>
                  Opacity(opacity: away ? 0 : 1, child: child),
              child: KeyedSubtree(
                key: emblemKey,
                child: DockEmblem(kind: kind, size: size, orb: orb),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
