part of 'cosmic_game.dart';

/// Ability projectiles look the same in every mode. Survival's
/// `_renderCompanionProjectile` is the reference: the same shared painters,
/// tried in the same order. The order is part of the look, because several
/// painters claim overlapping signals — Let's stationary catch-all takes any
/// parked thing carrying a snare, so a Mask or Mane zone asked after it wears
/// a Let crater.
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
    drawProjectileRoleOverlay(
      canvas: canvas,
      projectile: cp,
      position: position,
      color: color,
      time: time,
    );
    if (!claimed && cp.decoy) {
      canvas.drawCircle(
        position,
        12 * cp.visualScale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.2),
      );
    }
  }
}
