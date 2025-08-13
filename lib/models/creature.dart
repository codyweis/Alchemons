import 'package:alchemons/models/breeding_info.dart';
import 'package:alchemons/models/special_breeding.dart';

// Define a new class for SpriteData to keep it organized
class SpriteData {
  final int frameWidth;
  final int frameHeight;
  final int totalFrames;
  final int frameDurationMs; // Duration in milliseconds

  SpriteData({
    required this.frameWidth,
    required this.frameHeight,
    required this.totalFrames,
    required this.frameDurationMs,
  });

  factory SpriteData.fromJson(Map<String, dynamic> json) {
    return SpriteData(
      frameWidth: json['frameWidth'],
      frameHeight: json['frameHeight'],
      totalFrames: json['totalFrames'],
      frameDurationMs: json['frameDurationMs'],
    );
  }
}

class Creature {
  final String id;
  final String name;
  final List<String> types;
  final String rarity;
  final String description;
  final String image;
  final BreedingInfo breeding;
  final SpecialBreeding? specialBreeding;
  final String? mutationFamily;
  final List<List<String>>? guaranteedBreeding;

  // New optional fields for variants
  final bool isVariant;

  // NEW: Optional SpriteData field
  final SpriteData? spriteData;

  Creature({
    required this.id,
    required this.name,
    required this.types,
    required this.rarity,
    required this.description,
    required this.image,
    required this.breeding,
    this.specialBreeding,
    this.guaranteedBreeding,
    this.mutationFamily,
    this.isVariant = false,
    this.spriteData, // NEW: Initialize spriteData
  });

  factory Creature.fromJson(Map<String, dynamic> json) {
    return Creature(
      id: json['id'],
      name: json['name'],
      types: List<String>.from(json['types']),
      rarity: json['rarity'],
      description: json['description'],
      image: json['image'],
      breeding: BreedingInfo.fromJson(json['breeding']),
      specialBreeding: json['special_breeding'] != null
          ? SpecialBreeding.fromJson(json['special_breeding'])
          : null,
      guaranteedBreeding: json['guaranteed_breeding'] != null
          ? (json['guaranteed_breeding'] as List)
                .map((e) => List<String>.from(e))
                .toList()
          : null,
      mutationFamily: json['mutation_family'],
      isVariant:
          json['isVariant'] ?? false, // Ensure you parse this if it's in JSON
      spriteData:
          json['spriteData'] !=
              null // NEW: Parse spriteData from JSON
          ? SpriteData.fromJson(json['spriteData'])
          : null,
    );
  }

  // New factory for creating variants (consider if variants also use spritesheets)
  factory Creature.variant({
    required String baseId,
    required String baseName,
    required String primaryType,
    required String secondaryType,
    required String baseImage,
    SpriteData?
    spriteVariantData, // Consider passing sprite data for variants too
  }) {
    return Creature(
      id: "${baseId}_${secondaryType}",
      name: "$baseName-$secondaryType",
      types: [primaryType, secondaryType],
      rarity: "Variant",
      description:
          "A rare variant of $baseName infused with $secondaryType energy.",
      image: baseImage.replaceAll(
        '.png',
        '_${secondaryType.toLowerCase()}.png',
      ),
      breeding: BreedingInfo.empty(), // Variants don't breed normally
      isVariant: true,
      spriteData: spriteVariantData, // Assign sprite data for variants
    );
  }
}
