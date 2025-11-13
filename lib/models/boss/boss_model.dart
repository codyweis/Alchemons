// lib/models/boss.dart
import 'package:flutter/material.dart';

class BossMove {
  final String name;
  final String description;
  final BossMoveType type;

  const BossMove({
    required this.name,
    required this.description,
    required this.type,
  });

  factory BossMove.fromJson(Map<String, dynamic> json) {
    return BossMove(
      name: json['name'] as String,
      description: json['description'] as String,
      type: BossMoveType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BossMoveType.singleTarget,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'type': type.name,
  };
}

enum BossMoveType { singleTarget, aoe, buff, debuff, heal, special }

enum BossTier {
  basic('Basic Elements', Colors.blue),
  hybrid('Hybrid Elements', Colors.purple),
  advanced('Advanced Hybrids', Colors.deepPurple),
  cosmic('Arcane & Cosmic', Colors.amber);

  final String label;
  final Color color;
  const BossTier(this.label, this.color);
}

class Boss {
  final String id;
  final String name;
  final String element;
  final int recommendedLevel;
  final int hp;
  final int atk;
  final int def;
  final int spd;
  final List<BossMove> moveset;
  final BossTier tier;
  final int order; // 1-17

  const Boss({
    required this.id,
    required this.name,
    required this.element,
    required this.recommendedLevel,
    required this.hp,
    required this.atk,
    required this.def,
    required this.spd,
    required this.moveset,
    required this.tier,
    required this.order,
  });

  factory Boss.fromJson(Map<String, dynamic> json) {
    return Boss(
      id: json['id'] as String,
      name: json['name'] as String,
      element: json['element'] as String,
      recommendedLevel: json['recommendedLevel'] as int,
      hp: json['hp'] as int,
      atk: json['atk'] as int,
      def: json['def'] as int,
      spd: json['spd'] as int,
      moveset: (json['moveset'] as List)
          .map((m) => BossMove.fromJson(m as Map<String, dynamic>))
          .toList(),
      tier: BossTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => BossTier.basic,
      ),
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'element': element,
    'recommendedLevel': recommendedLevel,
    'hp': hp,
    'atk': atk,
    'def': def,
    'spd': spd,
    'moveset': moveset.map((m) => m.toJson()).toList(),
    'tier': tier.name,
    'order': order,
  };

  Color get elementColor {
    switch (element.toLowerCase()) {
      case 'fire':
        return Colors.deepOrange;
      case 'water':
        return Colors.blue;
      case 'earth':
        return Colors.brown;
      case 'air':
        return Colors.cyan;
      case 'plant':
        return Colors.green;
      case 'ice':
        return Colors.lightBlue;
      case 'lightning':
        return Colors.yellow;
      case 'poison':
        return Colors.purple;
      case 'steam':
        return Colors.teal;
      case 'lava':
        return Colors.deepOrangeAccent;
      case 'mud':
        return Colors.brown.shade700;
      case 'dust':
        return Colors.orange.shade300;
      case 'crystal':
        return Colors.pink;
      case 'spirit':
        return Colors.indigo.shade200;
      case 'dark':
        return Colors.deepPurple.shade900;
      case 'light':
        return Colors.amber.shade100;
      case 'blood':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  IconData get elementIcon {
    switch (element.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'water':
        return Icons.water_drop;
      case 'earth':
        return Icons.terrain;
      case 'air':
        return Icons.air;
      case 'plant':
        return Icons.eco;
      case 'ice':
        return Icons.ac_unit;
      case 'lightning':
        return Icons.bolt;
      case 'poison':
        return Icons.dangerous;
      case 'steam':
        return Icons.cloud;
      case 'lava':
        return Icons.volcano;
      case 'mud':
        return Icons.water_damage;
      case 'dust':
        return Icons.grain;
      case 'crystal':
        return Icons.diamond;
      case 'spirit':
        return Icons.auto_awesome;
      case 'dark':
        return Icons.dark_mode;
      case 'light':
        return Icons.light_mode;
      case 'blood':
        return Icons.bloodtype;
      default:
        return Icons.help_outline;
    }
  }
}
