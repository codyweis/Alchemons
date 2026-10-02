part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────
// HOMING MISSILE
// ─────────────────────────────────────────────────────────

class _HomingMissile {
  Offset position;
  double angle;
  static const double maxLife = 3.0;
  double life = maxLife;
  static const double speed = 400.0;
  static const double turnRate = 3.6; // radians/sec

  _HomingMissile({required this.position, required this.angle});
}

// ─────────────────────────────────────────────────────────
// SHIP COMPONENT
// ─────────────────────────────────────────────────────────

class ShipComponent {
  ShipComponent({required this.pos});

  Offset pos;
  double angle = -pi / 2; // pointing up initially

  /// The grains this ship has left behind it (ship_art.dart).
  final ShipWake wake = ShipWake();

  /// Draws the ship: its wake in world space, then the hull at [pos].
  ///
  /// [glow] adds the light pooled round the hull; survival flies with it
  /// off, its arena already paints hundreds of things a frame. [boost]
  /// (0..1) opens the engines up and thickens the wake; [flash] (0..1)
  /// blanches the hull, as a hit does.
  void render(
    Canvas canvas,
    double elapsed, {
    String? skin,
    bool glow = true,
    double boost = 0,
    double flash = 0,
  }) {
    wake.update(elapsed, pos, angle, skin, boost: boost);
    wake.paint(canvas);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle + pi / 2); // adjust so 0 = up
    paintShipHull(
      canvas,
      skin,
      elapsed,
      glow: glow,
      boost: boost,
      flash: flash,
    );
    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────
// PLANET COMPONENT
// ─────────────────────────────────────────────────────────

/// The art for [planet], built once and shared (space, encounter backdrop,
/// map card). Seeded by position so a planet always looks like itself.
PlanetArt planetArtFor(CosmicPlanet planet) => PlanetArt.of(
  planet.element,
  planet.position.dx.toInt() ^ planet.position.dy.toInt(),
);

class PlanetComponent {
  // The art is built here, at world load, rather than on the frame the
  // planet first scrolls into view.
  PlanetComponent({required this.planet}) : art = planetArtFor(planet);

  final CosmicPlanet planet;

  /// How it is drawn — see lib/games/cosmic/planets/.
  final PlanetArt art;

  void render(Canvas canvas, double elapsed, {bool drawLabel = true}) {
    final pos = planet.position;
    final r = planet.radius;
    final color = planet.color;

    // ── particle field ring ──
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos, planet.particleFieldRadius, ringPaint);

    art.paintBack(canvas, pos, r, elapsed);
    art.paintBody(canvas, pos, r, elapsed);
    art.paintFront(canvas, pos, r, elapsed);

    // ── element label ──
    if (!drawLabel) return;
    final tp = TextPainter(
      text: TextSpan(
        text: planetName(planet.element).toUpperCase(),
        style: TextStyle(
          color: color.withValues(alpha: planet.discovered ? 0.9 : 0.0),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + r + 10));
  }
}

// ─────────────────────────────────────────────────────────
// STAR PARTICLE (background decoration)
// ─────────────────────────────────────────────────────────

class _StarParticle {
  _StarParticle({
    required this.x,
    required this.y,
    required this.brightness,
    required this.size,
    required this.twinkleSpeed,
  });

  final double x, y, brightness, size, twinkleSpeed;
}

// ─────────────────────────────────────────────────────────
// PARALLAX STAR LAYER
// ─────────────────────────────────────────────────────────

class _ParallaxStar {
  _ParallaxStar({
    required this.x,
    required this.y,
    required this.brightness,
    required this.size,
    required this.twinkleSpeed,
  });

  final double x, y, brightness, size, twinkleSpeed;
}

class _ParallaxLayer {
  _ParallaxLayer({
    required this.factor,
    required int count,
    required double tile,
    required double maxSize,
    required double maxBrightness,
    required int seed,
  }) {
    final rng = Random(seed);
    for (var i = 0; i < count; i++) {
      stars.add(
        _ParallaxStar(
          x: rng.nextDouble() * tile,
          y: rng.nextDouble() * tile,
          brightness: maxBrightness * (0.4 + rng.nextDouble() * 0.6),
          size: 0.5 + rng.nextDouble() * (maxSize - 0.5),
          twinkleSpeed: 0.3 + rng.nextDouble() * 1.2,
        ),
      );
    }
  }

  // Fraction of camera movement this layer scrolls at (0 = fixed, 1 = world).
  final double factor;
  final List<_ParallaxStar> stars = [];
}

// ─────────────────────────────────────────────────────────
// ELEMENT PARTICLE (collectible)
// ─────────────────────────────────────────────────────────

class ElementParticle {
  ElementParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.element,
    required this.life,
    required this.size,
  });

  double x, y, vx, vy, life, size;
  final String element;
}

// ─────────────────────────────────────────────────────────
// GARRISON CREATURE (stationed at home planet)
// ─────────────────────────────────────────────────────────

class _GarrisonCreature with KinSupportFields {
  _GarrisonCreature({
    required this.member,
    required this.position,
    required this.wanderAngle,
    required this.guardAngle,
    required this.guardRadius,
    required this.guardPhase,
    required this.speciesScale,
    required this.attackDamage,
    required this.specialDamage,
    required this.attackRange,
    required this.specialRange,
    required this.maxHp,
  }) : hp = maxHp;

  final CosmicPartyMember member;
  Offset position;
  double wanderAngle;
  final double guardAngle;
  final double guardRadius;
  final double guardPhase;
  double faceAngle = 0;
  final double speciesScale;

  // Health (for abilities that heal/shield)
  final int maxHp;
  int hp;

  // Sprite animation
  SpriteAnimation? anim;
  SpriteAnimationTicker? ticker;
  SpriteVisuals? visuals;
  double spriteScale = 1.0;

  // Combat
  final double attackDamage;
  final double specialDamage;
  final double attackRange;
  final double specialRange;
  double attackCooldown = 0;
  double specialCooldown = 8.0;

  // Shield/Charge state (Horn special)
  int shieldHp = 0;
  double chargeTimer = 0;
  Offset? chargeTarget;
  double chargeDamage = 0;
  double chargeSpeedMultiplier = 1.0;
  double chargeSweepRadius = 48.0;
  double chargeOvershootDistance = 80.0;
  double chargeFinalSweepRadius = 68.0;

  // Blessing state (Kin special)
  double blessingTimer = 0;
  double blessingHealPerTick = 0;
  // HP is whole points; the fraction of a blessing's heal not yet paid.
  double blessingCarry = 0;

  // Kin support state ([KinSupportFields]): garrison defenders cast the same
  // specials as deployed companions, so their non-projectile paths survive
  // beyond the cast frame too.

  // Temporary basic-attack haste granted by some specials.
  double basicHasteTimer = 0;
  double basicHasteMultiplier = 1.0;
  double damageAmpTimer = 0;
  double damageAmpMultiplier = 1.0;

  int abilityKillStacks = 0;
  double pipSpiritEmpowerTimer = 0;
  double pipSteamWindowTimer = 0;
  Offset? lastPipPoisonHitPos;
  List<Projectile>? pendingChargeBurst;
  Offset? pendingChargeOrigin;
  double pendingChargeAngle = 0;

  // Movement
  static const double wanderSpeed = 14.0;
}
