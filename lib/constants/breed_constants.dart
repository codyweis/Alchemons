import 'package:flutter/material.dart';

class BreedConstants {
  // Rarity → hatch time mapping
  static const Map<String, Duration> rarityHatchTimes = {
    'common': Duration(minutes: 5),
    'uncommon': Duration(minutes: 15),
    'rare': Duration(hours: 1),
    'mythic': Duration(hours: 3),
    'legendary': Duration(hours: 8),
  };

  // Type colors
  static Color getTypeColor(String type) {
    switch (type) {
      case 'Fire':
        return const Color.fromARGB(255, 255, 130, 57);
      case 'Water':
        return const Color.fromARGB(255, 42, 144, 227);
      case 'Earth':
        return const Color.fromARGB(255, 137, 88, 71);
      case 'Air':
        return const Color.fromARGB(255, 157, 184, 188);
      case 'Steam':
        return Colors.grey.shade400;
      case 'Lava':
        return const Color.fromARGB(255, 149, 16, 16);
      case 'Lightning':
        return const Color.fromARGB(255, 209, 172, 6);
      case 'Mud':
        return const Color.fromARGB(255, 54, 41, 36);
      case 'Ice':
        return const Color.fromARGB(255, 102, 207, 255);
      case 'Dust':
        return Colors.brown.shade200;
      case 'Crystal':
        return const Color.fromARGB(255, 77, 36, 202);
      case 'Plant':
        return Colors.green.shade400;
      case 'Poison':
        return const Color.fromARGB(255, 148, 105, 184);
      case 'Spirit':
        return const Color.fromARGB(255, 252, 255, 255);
      case 'Dark':
        return const Color.fromARGB(255, 43, 42, 42);
      case 'Light':
        return Colors.yellow.shade300;
      case 'Blood':
        return Colors.red.shade700;
      default:
        return Colors.purple.shade400;
    }
  }

  // Type icons
  static IconData getTypeIcon(String type) {
    switch (type) {
      case 'Fire':
        return Icons.local_fire_department_rounded;
      case 'Water':
        return Icons.water_drop_rounded;
      case 'Earth':
        return Icons.terrain_rounded;
      case 'Air':
        return Icons.air_rounded;
      case 'Steam':
        return Icons.cloud_rounded;
      case 'Lava':
        return Icons.volcano_rounded;
      case 'Lightning':
        return Icons.flash_on_rounded;
      case 'Mud':
        return Icons.layers_rounded;
      case 'Ice':
        return Icons.ac_unit_rounded;
      case 'Dust':
        return Icons.grain_rounded;
      case 'Crystal':
        return Icons.diamond_rounded;
      case 'Plant':
        return Icons.eco_rounded;
      case 'Storm':
        return Icons.thunderstorm_rounded;
      case 'Poison':
        return Icons.dangerous_rounded;
      case 'Spirit':
        return Icons.auto_awesome_rounded;
      case 'Dark':
        return Icons.nights_stay_rounded;
      case 'Light':
        return Icons.wb_sunny_rounded;
      case 'Blood':
        return Icons.bloodtype_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  // Rarity colors
  static Color getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade600;
      case 'uncommon':
        return Colors.green.shade500;
      case 'rare':
        return Colors.blue.shade600;
      case 'mythic':
        return Colors.purple.shade600;
      case 'legendary':
        return Colors.amber.shade700;
      default:
        return Colors.purple.shade600;
    }
  }

  // Common gradient styles
  static BoxDecoration getCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blue.shade50,
          Colors.purple.shade50,
          Colors.pink.shade50,
        ],
      ),
    );
  }

  static BoxDecoration getWhiteCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.9),
          Colors.purple.shade50.withOpacity(0.9),
        ],
      ),
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.purple.shade200,
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  // Utility method to format remaining time
  static String formatRemaining(Duration d) {
    if (d.isNegative) return '0s';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s.toString().padLeft(2, '0')}s';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  // Common pill widget style
  static Widget buildPill(String text, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: colors.last.withOpacity(0.35), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
