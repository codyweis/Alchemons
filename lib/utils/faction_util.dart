import 'dart:ui';

import 'package:alchemons/models/faction.dart';
import 'package:flutter/material.dart';

(Color, Color, Color) getFactionColors(FactionId? factionId) {
  if (factionId == null) {
    return (Colors.indigo, Colors.purple, Colors.blue);
  }

  switch (factionId) {
    case FactionId.fire:
      return (Colors.red, Colors.orange, Colors.deepOrange);
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
        Colors.brown,
        const Color.fromARGB(255, 140, 230, 143),
        Colors.amber,
      );
  }
}
