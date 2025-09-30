// Resource model
import 'package:flutter/material.dart';

class ElementResource {
  final String id;
  final String name;
  final String resourceName; // e.g., "Embers", "Droplets"
  final IconData icon;
  final int amount;
  final Color color;

  ElementResource({
    required this.id,
    required this.name,
    required this.resourceName,
    required this.icon,
    required this.amount,
    required this.color,
  });
}

// Sample data - replace with your actual data
List<ElementResource> getSampleResources() {
  return [
    ElementResource(
      id: 'T001',
      name: 'Fire',
      resourceName: 'Embers',
      icon: Icons.local_fire_department_rounded,
      amount: 47,
      color: Colors.deepOrangeAccent,
    ),
    ElementResource(
      id: 'T002',
      name: 'Water',
      resourceName: 'Droplets',
      icon: Icons.water_drop_rounded,
      amount: 32,
      color: Colors.cyanAccent,
    ),
    ElementResource(
      id: 'T003',
      name: 'Earth',
      resourceName: 'Pebbles',
      icon: Icons.terrain_rounded,
      amount: 28,
      color: Colors.limeAccent,
    ),
    ElementResource(
      id: 'T004',
      name: 'Air',
      resourceName: 'Wisps',
      icon: Icons.air_rounded,
      amount: 19,
      color: Colors.lightBlueAccent,
    ),
    ElementResource(
      id: 'T005',
      name: 'Steam',
      resourceName: 'Vapor',
      icon: Icons.cloud_rounded,
      amount: 15,
      color: Colors.grey.shade300,
    ),
    ElementResource(
      id: 'T006',
      name: 'Lava',
      resourceName: 'Magma Cores',
      icon: Icons.whatshot_rounded,
      amount: 8,
      color: Colors.redAccent,
    ),
    ElementResource(
      id: 'T007',
      name: 'Lightning',
      resourceName: 'Sparks',
      icon: Icons.bolt_rounded,
      amount: 23,
      color: Colors.yellowAccent,
    ),
    ElementResource(
      id: 'T008',
      name: 'Mud',
      resourceName: 'Silt',
      icon: Icons.layers_rounded,
      amount: 12,
      color: Colors.brown.shade400,
    ),
    ElementResource(
      id: 'T009',
      name: 'Ice',
      resourceName: 'Frost Crystals',
      icon: Icons.ac_unit_rounded,
      amount: 31,
      color: Colors.lightBlue.shade200,
    ),
    ElementResource(
      id: 'T010',
      name: 'Dust',
      resourceName: 'Particles',
      icon: Icons.grain_rounded,
      amount: 44,
      color: Colors.grey.shade400,
    ),
    ElementResource(
      id: 'T011',
      name: 'Crystal',
      resourceName: 'Prisms',
      icon: Icons.diamond_rounded,
      amount: 6,
      color: Colors.purple.shade200,
    ),
    ElementResource(
      id: 'T012',
      name: 'Plant',
      resourceName: 'Seeds',
      icon: Icons.eco_rounded,
      amount: 38,
      color: Colors.greenAccent,
    ),
    ElementResource(
      id: 'T013',
      name: 'Poison',
      resourceName: 'Venom Drops',
      icon: Icons.science_rounded,
      amount: 11,
      color: Colors.purple.shade400,
    ),
    ElementResource(
      id: 'T014',
      name: 'Spirit',
      resourceName: 'Essence',
      icon: Icons.auto_awesome_rounded,
      amount: 5,
      color: Colors.indigo.shade200,
    ),
    ElementResource(
      id: 'T015',
      name: 'Dark',
      resourceName: 'Shadow Fragments',
      icon: Icons.dark_mode_rounded,
      amount: 17,
      color: Colors.deepPurple.shade300,
    ),
    ElementResource(
      id: 'T016',
      name: 'Light',
      resourceName: 'Lumens',
      icon: Icons.light_mode_rounded,
      amount: 29,
      color: Colors.amber.shade200,
    ),
    ElementResource(
      id: 'T017',
      name: 'Blood',
      resourceName: 'Vitae',
      icon: Icons.favorite_rounded,
      amount: 9,
      color: Colors.red.shade400,
    ),
  ];
}
