import 'dart:ui';

import 'package:alchemons/models/faction.dart';
import 'package:flutter/material.dart';

(Color, Color, Color) getFactionColors(FactionId? factionId) {
  if (factionId == null) {
    return (Colors.indigo, Colors.purple, Colors.blue);
  }

  switch (factionId) {
    case FactionId.fire:
      return (
        Colors.red,
        const Color.fromARGB(255, 255, 0, 21),
        Colors.deepOrange,
      );
    case FactionId.water:
      return (Colors.blue, Colors.cyan, Colors.lightBlue);
    case FactionId.air:
      return (
        const Color.fromARGB(255, 212, 223, 225),
        const Color.fromARGB(255, 207, 218, 191),
        Colors.lightBlue,
      );
    case FactionId.earth:
      return (
        const Color.fromARGB(255, 101, 71, 60),
        const Color.fromARGB(255, 140, 230, 143),
        const Color.fromARGB(255, 42, 132, 55),
      );
  }
}

Color accentForFaction(FactionId f) {
  switch (f) {
    case FactionId.fire:
      return Colors.deepOrangeAccent;
    case FactionId.water:
      return Color.fromARGB(255, 84, 161, 197);
    case FactionId.air:
      return Color.fromARGB(255, 159, 176, 185);
    case FactionId.earth:
      return Color.fromARGB(255, 132, 105, 51);
  }
}
