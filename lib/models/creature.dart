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
      frameWidth: (json['frameWidth'] as int?) ?? 512,
      frameHeight: (json['frameHeight'] as int?) ?? 512,
      totalFrames: (json['totalFrames'] as int?) ?? 4,
      frameDurationMs: (json['frameDurationMs'] as int?) ?? 120,
      rows: (json['rows'] as int?) ?? 1,
      spriteSheetPath: json['spriteSheetPath'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'frameWidth': frameWidth,
    'frameHeight': frameHeight,
    'totalFrames': totalFrames,
    'frameDurationMs': frameDurationMs,
    'rows': rows,
    'spriteSheetPath': spriteSheetPath,
  };
}

class Genetics {
  final Map<String, String> variants;
  const Genetics(this.variants);

  String? get(String track) => variants[track];

  Genetics copyWith({Map<String, String>? variants}) =>
      Genetics(Map.unmodifiable(variants ?? this.variants));

  factory Genetics.fromJson(Map<String, dynamic> json) =>
      Genetics(Map<String, String>.from(json));

  Map<String, dynamic> toJson() => variants;
}

class Creature {
  final String id;
  final String name;

  /// Primary at [0], optional secondary at [1] for variants.
  final List<String> types;

  /// "Common" | "Uncommon" | "Rare" | "Mythic" | "Variant"
  final String rarity;

  final String description;

  /// Base static image path, e.g. "creatures/rare/HOR01_firehorn.png"
  final String image;

  final SpecialBreeding? specialBreeding;

  /// e.g. "Wing", "Crest", "Back", ...
  final String? mutationFamily;

  final List<List<String>>? guaranteedBreeding;
  final NatureDef? nature;
  final Genetics? genetics;

  /// Prismatic skin flag (e.g. special cosmetic)
  final bool isPrismaticSkin;

  final Parentage? parentage;

  /// Cross-breeding variant compatibility: if partner's primary type is in
  /// here, we may produce a variant.
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

  /// JSON -> Creature (null-safe)
  factory Creature.fromJson(Map<String, dynamic> json) {
    // Basic fields
    final String imagePath = json['image'] as String;
    final String id = json['id'] as String;
    final String name = json['name'] as String;
    final String rarity = json['rarity'] as String;
    final String description = json['description'] as String;

    // Collections with guards
    final types = (json['types'] is List)
        ? List<String>.from(json['types'] as List)
        : const <String>[];

    // Optional/nested JSON blobs
    final specialBreedingJson = json['specialBreeding'];
    final guaranteedBreedingJson = json['guaranteedBreeding'];
    final variantJson = json['variant'];
    final geneticsJson = json['genetics'];
    final natureJson = json['nature'];
    final parentageJson = json['parentage'];
    final spriteDataJson = json['spriteData'];

    // If `spriteData` exists, synthesize a default spriteSheetPath by convention:
    // "<image basename>_spritesheet.png"
    String? spritesheetPath;
    if (spriteDataJson is Map && imagePath.isNotEmpty) {
      spritesheetPath = imagePath.replaceAll('.png', '_spritesheet.png');
    }

    return Creature(
      id: id,
      name: name,
      types: types,
      rarity: rarity,
      description: description,
      image: imagePath,

      specialBreeding: specialBreedingJson is Map<String, dynamic>
          ? SpecialBreeding.fromJson(specialBreedingJson)
          : null,

      guaranteedBreeding: guaranteedBreedingJson is List
          ? (guaranteedBreedingJson as List)
                .map((e) => List<String>.from(e as List))
                .toList()
          : null,

      mutationFamily: json['mutationFamily'] as String?,

      variantTypes: variantJson is List
          ? Set<String>.from(variantJson.map((e) => e.toString()))
          : const {},

      isVariant: (json['isVariant'] as bool?) ?? false,

      genetics: geneticsJson is Map<String, dynamic>
          ? Genetics.fromJson(geneticsJson)
          : null,

      nature: natureJson is Map<String, dynamic>
          ? NatureDef.fromJson(natureJson)
          : null,

      parentage: parentageJson is Map<String, dynamic>
          ? Parentage.fromJson(parentageJson)
          : null,

      isPrismaticSkin: (json['isPrismaticSkin'] as bool?) ?? false,

      spriteData: spriteDataJson is Map<String, dynamic>
          ? SpriteData.fromJson({
              ...spriteDataJson,
              if (spritesheetPath != null) 'spriteSheetPath': spritesheetPath,
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
      isVariant: true,
      spriteData: spriteVariantData,
      variantTypes:
          const {}, // runtime variants don't cause further variants by default
      mutationFamily: null,
      specialBreeding: null,
      guaranteedBreeding: null,
      parentage: null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'types': types,
    'rarity': rarity,
    'description': description,
    'image': image,
    if (guaranteedBreeding != null) 'guaranteedBreeding': guaranteedBreeding,
    if (mutationFamily != null) 'mutationFamily': mutationFamily,
    'variant': variantTypes.toList(),
    'isVariant': isVariant,
    if (spriteData != null) 'spriteData': spriteData!.toJson(),
    if (nature != null) 'nature': nature!.toJson(),
    if (genetics != null) 'genetics': genetics!.toJson(),
    'isPrismaticSkin': isPrismaticSkin,
    if (parentage != null) 'parentage': parentage!.toJson(),
  };
}

extension CreatureCopy on Creature {
  Creature copyWith({
    String? id,
    String? name,
    List<String>? types,
    String? rarity,
    String? description,
    String? image,
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
