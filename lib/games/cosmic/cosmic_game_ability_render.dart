part of 'cosmic_game.dart';

/// Ability projectiles look the same in every mode. Survival's
/// `_renderCompanionProjectile` is the reference: the same shared painters,
/// tried in the same order. The order is part of the look, because several
/// painters claim overlapping signals: Mask's ground painter takes any parked
/// sigil carrying a snare or a taunt, whichever family laid it. (Let's
/// stationary catch-all did the same until it was scoped to Let's own pieces;
/// Horn's zones wore Let craters — test/horn_zone_claim_test.dart.)
extension CosmicAbilityRender on CosmicGame {
  void _renderAbilityProjectile(Canvas canvas, Projectile cp) {
    final position = cp.position;
    final color = elementColor(cp.element ?? 'Fire');
    final time = _elapsed;

    if (drawKinSpiritWispVisual(
      canvas: canvas,
      projectile: cp,
      position: position,
      color: color,
      time: time,
    )) {
      return;
    }
    if (drawMysticOrbitalProjectileVisual(
      canvas: canvas,
      projectile: cp,
      position: position,
      color: color,
      time: time,
    )) {
      return;
    }
    if (drawMysticOrbitalFixtureVisual(
      canvas: canvas,
      projectile: cp,
      position: position,
      color: color,
      time: time,
    )) {
      return;
    }
    // Mask traps are ground-zone identity pieces; they carry no role overlay.
    if (drawMaskElementalProjectileVisual(
      canvas: canvas,
      projectile: cp,
      position: position,
      color: color,
      time: time,
    )) {
      if (cp.abilityFamily == 'mask' && cp.element == 'Plant') {
        _drawMaskPlantTendrils(canvas, cp, color);
      }
      return;
    }

    final claimed =
        drawLetElementalProjectileVisual(
          canvas: canvas,
          projectile: cp,
          position: position,
          color: color,
          time: time,
        ) ||
        drawPipElementalProjectileVisual(
          canvas: canvas,
          projectile: cp,
          position: position,
          color: color,
          time: time,
        ) ||
        drawManeElementalProjectileVisual(
          canvas: canvas,
          projectile: cp,
          position: position,
          color: color,
          time: time,
        ) ||
        drawHornElementalProjectileVisual(
          canvas: canvas,
          projectile: cp,
          position: position,
          color: color,
          time: time,
        );
    if (!claimed) {
      drawGenericProjectileVisual(
        canvas: canvas,
        projectile: cp,
        position: position,
        color: color,
        time: time,
      );
    }
    // A taunting decoy pools its light under itself here, as in survival;
    // the stroked hoop that used to ring it is gone.
    drawProjectileRoleOverlay(
      canvas: canvas,
      projectile: cp,
      position: position,
      color: color,
      time: time,
    );
  }
}
