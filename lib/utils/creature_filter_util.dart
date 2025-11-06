// utils/creature_filter_utils.dart
import 'package:flutter/material.dart';
import '../database/alchemons_db.dart';
import '../services/creature_repository.dart';

class CreatureFilterUtils {
  static const List<String> filterOptions = [
    'All',
    'Fire',
    'Water',
    'Earth',
    'Air',
    'Steam',
    'Lava',
    'Lightning',
    'Mud',
    'Ice',
    'Dust',
    'Crystal',
    'Plant',
    'Poison',
    'Spirit',
    'Dark',
    'Light',
    'Blood',
  ];

  static const List<String> rarityFilters = [
    'All Rarities',
    'Common',
    'Uncommon',
    'Rare',
    'Mythic',
    'Legendary',
  ];

  static const List<String> sortOptions = [
    'Name',
    'Level',
    'Rarity',
    'Type',
    'Created Date',
  ];

  static List<CreatureInstance> filterAndSortInstances(
    List<CreatureInstance> instances,
    CreatureCatalog repo, {
    String typeFilter = 'All',
    String rarityFilter = 'All Rarities',
    String sortBy = 'Name',
    bool ascending = true,
  }) {
    var filtered = instances.where((instance) {
      final creature = repo.getCreatureById(instance.baseId);
      if (creature == null) return false;

      // Type filter
      if (typeFilter != 'All' && !creature.types.contains(typeFilter)) {
        return false;
      }

      // Rarity filter
      if (rarityFilter != 'All Rarities' && creature.rarity != rarityFilter) {
        return false;
      }

      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      final creatureA = repo.getCreatureById(a.baseId);
      final creatureB = repo.getCreatureById(b.baseId);

      if (creatureA == null || creatureB == null) return 0;

      int comparison = 0;
      switch (sortBy) {
        case 'Name':
          comparison = creatureA.name.compareTo(creatureB.name);
          break;
        case 'Level':
          comparison = a.level.compareTo(b.level);
          break;
        case 'Rarity':
          comparison = getRarityOrder(
            creatureA.rarity,
          ).compareTo(getRarityOrder(creatureB.rarity));
          break;
        case 'Type':
          comparison = creatureA.types.first.compareTo(creatureB.types.first);
          break;
        case 'Created Date':
          comparison = a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
          break;
      }

      return ascending ? comparison : -comparison;
    });

    return filtered;
  }

  static int getRarityOrder(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 0;
      case 'uncommon':
        return 1;
      case 'rare':
        return 2;
      case 'mythic':
        return 3;
      case 'legendary':
        return 4;
      default:
        return 0;
    }
  }

  static Color getTypeColor(String type) {
    switch (type) {
      case 'Fire':
        return Colors.red.shade400;
      case 'Water':
        return Colors.blue.shade400;
      case 'Earth':
        return Colors.brown.shade400;
      case 'Air':
        return Colors.cyan.shade400;
      case 'Steam':
        return Colors.grey.shade400;
      case 'Lava':
        return Colors.deepOrange.shade400;
      case 'Lightning':
        return Colors.yellow.shade600;
      case 'Mud':
        return Colors.brown.shade300;
      case 'Ice':
        return Colors.lightBlue.shade400;
      case 'Dust':
        return Colors.brown.shade200;
      case 'Crystal':
        return Colors.purple.shade300;
      case 'Plant':
        return Colors.green.shade400;
      case 'Poison':
        return Colors.green.shade600;
      case 'Spirit':
        return Colors.teal.shade400;
      case 'Dark':
        return Colors.grey.shade700;
      case 'Light':
        return Colors.yellow.shade300;
      case 'Blood':
        return Colors.red.shade700;
      default:
        return Colors.purple.shade400;
    }
  }

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
        return Colors.orange.shade600;
      default:
        return Colors.purple.shade600;
    }
  }

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
}

// widgets/filter_dropdown.dart
class FilterDropdown extends StatelessWidget {
  final String hint;
  final List<String> items;
  final String selectedValue;
  final void Function(String?) onChanged;
  final IconData icon;
  final Color? color;

  const FilterDropdown({
    super.key,
    required this.hint,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.9), themeColor.withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: themeColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          icon: Icon(icon, color: themeColor, size: 18),
          dropdownColor: Colors.white,
          style: TextStyle(
            color: themeColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
