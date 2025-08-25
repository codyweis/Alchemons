import 'package:alchemons/models/breeding_info.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/special_breeding.dart';

/// Sprite sheet metadata for animated rendering.
class SpriteData {
  final int frameWidth;
  final int frameHeight;
  final int totalFrames;
  final int frameDurationMs; // Duration in milliseconds
  final int rows;
  final String spriteSheetPath;

  SpriteData({
    required this.frameWidth,
    required this.frameHeight,
    required this.totalFrames,
    required this.frameDurationMs,
    required this.rows,
    required this.spriteSheetPath,
  });

  factory SpriteData.fromJson(Map<String, dynamic> json) {
    return SpriteData(
      frameWidth: json['frameWidth'] ?? 512,
      frameHeight: json['frameHeight'] ?? 512,
      totalFrames: json['totalFrames'] ?? 4,
      frameDurationMs: json['frameDurationMs'] ?? 120,
      rows: json['rows'] ?? 1,
      spriteSheetPath: json['spriteSheetPath'] as String,
    );
  }
}

class Genetics {
  final Map<String, String> variants;
  const Genetics(this.variants);

  String? get(String track) => variants[track];

  Genetics copyWith({Map<String, String>? variants}) =>
      Genetics(Map.unmodifiable(variants ?? this.variants));
}

class Creature {
  final String id;
  final String name;
  final List<String>
  types; // primary at [0], optional secondary at [1] for variants
  final String rarity; // "Common" | "Uncommon" | "Rare" | "Mythic" | "Variant"
  final String description;
  final String image; // base static image
  final BreedingInfo breeding;
  final SpecialBreeding? specialBreeding;
  final String? mutationFamily; // e.g. "Wing", "Crest", "Back", ...
  final List<List<String>>? guaranteedBreeding;
  final NatureDef? nature;
  final Genetics? genetics;
  final bool isPrismaticSkin;
  final Parentage? parentage;

  /// Cross-breeding variant compatibility:
  /// if partner's primary type is in here, we may produce a variant.
  final Set<String> variantTypes;

  /// Flags an instance created as a runtime variant (not from the catalog).
  final bool isVariant;

  /// Optional sprite-sheet data for animation.
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
    this.variantTypes = const {},
    this.isVariant = false,
    this.spriteData,
    this.nature,
    this.genetics,
    this.isPrismaticSkin = false,
    this.parentage,
  });

  factory Creature.fromJson(Map<String, dynamic> json) {
    // Base image path from JSON.
    final String imagePath = json['image'];

    // If `spriteData` exists, we synthesize a default spriteSheetPath by convention:
    // "<image basename>_spritesheet.png"
    String? spritesheetPath;
    if (json['spriteData'] != null) {
      spritesheetPath = imagePath.replaceAll('.png', '_spritesheet.png');
    }

    return Creature(
      id: json['id'],
      name: json['name'],
      types: List<String>.from(json['types']),
      rarity: json['rarity'],
      description: json['description'],
      image: imagePath,
      breeding: BreedingInfo.fromJson(json['breeding']),
      specialBreeding: json['specialBreeding'] != null
          ? SpecialBreeding.fromJson(json['specialBreeding'])
          : null,
      guaranteedBreeding: json['guaranteedBreeding'] != null
          ? (json['guaranteedBreeding'] as List)
                .map((e) => List<String>.from(e))
                .toList()
          : null,
      mutationFamily: json['mutationFamily'],
      variantTypes: json['variant'] == null
          ? const {}
          : Set<String>.from(
              (json['variant'] as List).map((e) => e.toString()),
            ),
      isVariant: json['isVariant'] ?? false,
      genetics: json['genetics'] != null
          ? Genetics(Map<String, String>.from(json['genetics']))
          : null,
      nature: json['nature'] != null
          ? NatureDef.fromJson(json['nature'])
          : null,
      parentage: json['parentage'] != null
          ? Parentage.fromJson(json['parentage'])
          : null,
      isPrismaticSkin: json['isPrismaticSkin'] ?? false,
      spriteData: spritesheetPath != null
          ? SpriteData.fromJson({
              ...json['spriteData'],
              'spriteSheetPath': spritesheetPath,
            })
          : null,
    );
  }

  /// Runtime-built variant derived from a base creature + partner’s type.
  factory Creature.variant({
    required String baseId,
    required String baseName,
    required String primaryType, // the base creature's primary type
    required String
    secondaryType, // the partner's primary type that triggered the variant
    required String baseImage,
    SpriteData? spriteVariantData,
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
      nature: null,
      genetics: null,
      isPrismaticSkin: false,
      breeding:
          BreedingInfo.empty(), // variants don't follow normal breeding rules
      isVariant: true,
      spriteData: spriteVariantData,
      variantTypes:
          const {}, // runtime variants don't cause further variants by default
      mutationFamily: null, // or inherit if you prefer
      specialBreeding: null,
      guaranteedBreeding: null,
    );
  }
}

extension CreatureCopy on Creature {
  Creature copyWith({
    String? id,
    String? name,
    List<String>? types,
    String? rarity,
    String? description,
    String? image,
    BreedingInfo? breeding,
    SpecialBreeding? specialBreeding,
    String? mutationFamily,
    List<List<String>>? guaranteedBreeding,
    Set<String>? variantTypes,
    bool? isVariant,
    SpriteData? spriteData,
    bool? isPrismaticSkin,
    NatureDef? nature,
    Genetics? genetics,
    Parentage? parentage,
  }) {
    return Creature(
      id: id ?? this.id,
      name: name ?? this.name,
      types: types ?? this.types,
      rarity: rarity ?? this.rarity,
      description: description ?? this.description,
      image: image ?? this.image,
      breeding: breeding ?? this.breeding,
      specialBreeding: specialBreeding ?? this.specialBreeding,
      mutationFamily: mutationFamily ?? this.mutationFamily,
      guaranteedBreeding: guaranteedBreeding ?? this.guaranteedBreeding,
      variantTypes: variantTypes ?? this.variantTypes,
      isVariant: isVariant ?? this.isVariant,
      spriteData: spriteData ?? this.spriteData,
      isPrismaticSkin: isPrismaticSkin ?? this.isPrismaticSkin,
      nature: nature ?? this.nature,
      genetics: genetics ?? this.genetics,
      parentage: parentage ?? this.parentage,
    );
  }
}
