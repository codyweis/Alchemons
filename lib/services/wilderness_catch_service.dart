// lib/services/catch_service.dart
import 'dart:math';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:flutter/foundation.dart';

enum CatchDeviceType { volcanic, oceanic, verdant, earthen, arcane, guaranteed }

extension CatchDeviceTypeX on CatchDeviceType {
  String get label {
    switch (this) {
      case CatchDeviceType.volcanic:
        return 'Volcanic Harvester';
      case CatchDeviceType.oceanic:
        return 'Oceanic Harvester';
      case CatchDeviceType.verdant:
        return 'Verdant Harvester';
      case CatchDeviceType.earthen:
        return 'Earthen Harvester';
      case CatchDeviceType.arcane:
        return 'Arcane Harvester';
      case CatchDeviceType.guaranteed:
        return 'Stabilized Harvester';
    }
  }

  String get inventoryKey {
    switch (this) {
      case CatchDeviceType.volcanic:
        return InvKeys.harvesterStdVolcanic;
      case CatchDeviceType.oceanic:
        return InvKeys.harvesterStdOceanic;
      case CatchDeviceType.verdant:
        return InvKeys.harvesterStdVerdant;
      case CatchDeviceType.earthen:
        return InvKeys.harvesterStdEarthen;
      case CatchDeviceType.arcane:
        return InvKeys.harvesterStdArcane;
      case CatchDeviceType.guaranteed:
        return InvKeys.harvesterGuaranteed;
    }
  }

  ElementalGroup? get elementalGroup {
    switch (this) {
      case CatchDeviceType.volcanic:
        return ElementalGroup.volcanic;
      case CatchDeviceType.oceanic:
        return ElementalGroup.oceanic;
      case CatchDeviceType.verdant:
        return ElementalGroup.verdant;
      case CatchDeviceType.earthen:
        return ElementalGroup.earthen;
      case CatchDeviceType.arcane:
        return ElementalGroup.arcane;
      case CatchDeviceType.guaranteed:
        return null; // works on all
    }
  }
}

class CatchService {
  final AlchemonsDatabase db;
  final ConstellationEffectsService constellation;
  final Random _rng;

  CatchService(this.db, this.constellation, {Random? rng})
    : _rng = rng ?? Random();

  /// Check if player has at least one device of the given type
  Future<bool> hasDevice(CatchDeviceType device) async {
    final qty = await db.inventoryDao.getItemQty(device.inventoryKey);
    return qty > 0;
  }

  /// Get quantity of a specific device
  Future<int> getDeviceCount(CatchDeviceType device) async {
    return await db.inventoryDao.getItemQty(device.inventoryKey);
  }

  /// Get all devices the player owns (with quantities)
  Future<Map<CatchDeviceType, int>> getAllDevices() async {
    final devices = <CatchDeviceType, int>{};

    for (final type in CatchDeviceType.values) {
      final qty = await getDeviceCount(type);
      if (qty > 0) {
        devices[type] = qty;
      }
    }

    return devices;
  }

  /// Check if a device can be used on a creature (faction matching)
  bool canUseDevice(CatchDeviceType device, Creature target) {
    // Guaranteed device works on everything
    if (device == CatchDeviceType.guaranteed) return true;

    final deviceGroup = device.elementalGroup;
    if (deviceGroup == null) return false;

    // Check if creature's types match the device's elemental group
    final deviceTypes = deviceGroup.elementTypes;
    return target.types.any(deviceTypes.contains);
  }

  /// Get available devices that can catch this creature
  Future<List<CatchDeviceType>> getUsableDevices(Creature target) async {
    final allDevices = await getAllDevices();
    final usable = <CatchDeviceType>[];

    for (final device in allDevices.keys) {
      if (canUseDevice(device, target)) {
        usable.add(device);
      }
    }

    return usable;
  }

  /// Calculate catch chance for a device + creature combination
  double calculateCatchChance(
    CatchDeviceType device,
    String rarity, {
    bool hasMatchingFaction = true,
  }) {
    // Guaranteed device always succeeds
    if (device == CatchDeviceType.guaranteed) return 1.0;

    // Base rates by rarity (assuming faction match)
    double baseRate;
    switch (rarity.toLowerCase()) {
      case 'common':
        baseRate = 0.95;
        break;
      case 'uncommon':
        baseRate = 0.75;
        break;
      case 'rare':
        baseRate = 0.50;
        break;
      case 'epic':
        baseRate = 0.30;
        break;
      case 'legendary':
        baseRate = 0.15;
        break;
      case 'mythic':
        baseRate = 0.10;
        break;
      default:
        baseRate = 0.50;
    }

    // If faction doesn't match, device won't work (but this shouldn't happen
    // as we check canUseDevice first)
    if (!hasMatchingFaction) return 0.0;

    return baseRate;
  }

  /// Attempt to catch a creature
  /// Returns true if successful, false if failed
  /// Throws if player doesn't have the device or can't use it
  Future<bool> attemptCatch({
    required CatchDeviceType device,
    required Creature target,
  }) async {
    // Check if player has the device
    if (!await hasDevice(device)) {
      throw Exception('You do not have a ${device.label}');
    }

    // Check if device can be used on this creature
    if (!canUseDevice(device, target)) {
      throw Exception('${device.label} cannot be used on this creature');
    }

    // Consume the device
    final consumed = await db.inventoryDao.consumeItem(
      device.inventoryKey,
      qty: 1,
    );

    if (!consumed) {
      throw Exception('Failed to consume ${device.label}');
    }

    // Guaranteed device always succeeds, even before constellation logic
    if (device == CatchDeviceType.guaranteed) {
      debugPrint(
        '🎯 Catch attempt: ${device.label} on ${target.name} '
        '(${target.rarity}) - GUARANTEED SUCCESS',
      );
      return true;
    }

    // Base catch chance from rarity/device
    final baseChance = calculateCatchChance(
      device,
      target.rarity,
      hasMatchingFaction: true,
    );

    // 🌿 Constellation harvesting bonus: +5% / +10% / +15% flat
    final bonus = constellation.getWildernessHarvestBonus(); // 0.0–0.15
    final catchChance = (baseChance + bonus).clamp(0.01, 0.98);

    // Roll for success
    final roll = _rng.nextDouble();
    final success = roll < catchChance;

    debugPrint(
      '🎯 Catch attempt: ${device.label} on ${target.name} '
      '(${target.rarity}) - '
      'base ${(baseChance * 100).toStringAsFixed(0)}%, '
      'bonus ${(bonus * 100).toStringAsFixed(0)}%, '
      'final ${(catchChance * 100).toStringAsFixed(0)}% chance, '
      'rolled ${(roll * 100).toStringAsFixed(0)}, ${success ? "SUCCESS" : "FAILED"}',
    );

    return success;
  }
}
