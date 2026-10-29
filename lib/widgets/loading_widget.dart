import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/grain_loader.dart';
import 'package:flutter/material.dart';

/// A screen still waiting on game data: ink and the grain loader.
///
/// [message] is what the gate is waiting on. It is not shown; the wait is
/// short enough that naming it only reads as a system booting.
Widget buildLoadingScreen(FactionTheme theme, String message) {
  return const Scaffold(
    backgroundColor: Colors.transparent,
    body: GrainLoadingScreen(),
  );
}
