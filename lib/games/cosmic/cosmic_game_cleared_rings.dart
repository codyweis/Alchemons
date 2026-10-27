part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  A FALLEN GUARDIAN'S RING, IN SPACE
//
//  A planet whose guardian has fallen wears a ring of its own matter
//  (planets/cleared_ring.dart). The first time the ship comes back up out of
//  it after the fight, the ring forms in front of the player: the camera
//  eases over and out to frame the planet, the world holds still while the
//  grains lift off the surface and wind out to their orbit, and the camera
//  goes back to the ship as the last of them settle. No words, no popup.
// ─────────────────────────────────────────────────────────────────────────────

extension CosmicGameClearedRings on CosmicGame {
  /// The camera's head start before the first grain lifts.
  static const double _ringLead = 0.6;

  /// How long the world holds still, from the first grain lifting. The last
  /// grains settle while the camera goes back.
  static const double _ringHold = 3.6;

  /// How long the camera takes to go back to the ship.
  static const double _ringRelease = 1.1;

  /// Puts a ring on every planet whose guardian has fallen, and takes it off
  /// any whose has not (a debug wipe of a planet's progress).
  void _dressFallenGuardians() {
    for (final pc in planetComps) {
      final fallen = _fallenGuardians.contains(pc.planet.element);
      if (fallen && pc.cleared == null) {
        final p = pc.planet.position;
        pc.cleared = ClearedRing.of(pc.art, p.dx.toInt() ^ p.dy.toInt());
      } else if (!fallen && pc.cleared != null) {
        pc.cleared = null;
        pc.formingFrom = null;
        if (identical(pc, _ringShot)) _ringShot = null;
      }
    }
  }

  /// Back from a planet: [fallen] is every planet whose guardian is down.
  /// [justFell], when its guardian fell on this visit, has its ring form in
  /// front of the player instead of simply being there. Called while space
  /// is paused; the ring starts forming when it resumes.
  void syncFallenGuardians(Set<String> fallen, {String? justFell}) {
    _fallenGuardians
      ..clear()
      ..addAll(fallen);
    // Not built yet: onLoad dresses them from the set.
    if (planetComps.isEmpty) return;
    _dressFallenGuardians();
    if (justFell == null) return;
    for (final pc in planetComps) {
      final ring = pc.cleared;
      if (pc.planet.element != justFell || ring == null) continue;
      pc.formingFrom = _elapsed + _ringLead;
      _ringShot = pc;
      _ringShotAt = _nearestImage(pc.planet.position, ship.pos);
      final r = pc.planet.radius;
      // Tilted, the ring is as wide as it reaches but not as tall.
      _ringFrameZoom = min(
        size.x / (2 * ring.reach * r * 1.12),
        size.y / (2 * max(1.0, 0.62 * ring.reach) * r * 1.15),
      );
    }
  }

  /// The camera holding on a forming ring, and letting go of it. True while
  /// the world is held still.
  bool _updateRingShot(double dt) {
    final shot = _ringShot;
    if (shot != null) {
      _ringFrame += (1 - _ringFrame) * min(1.0, dt * 1.4);
      if (_elapsed >= (shot.formingFrom ?? _elapsed) + _ringHold) {
        _ringShot = null;
      }
    } else if (_ringFrame > 0) {
      _ringFrame = max(0.0, _ringFrame - dt / _ringRelease);
    } else {
      return false;
    }
    // A wild's tear owns the camera while it plays.
    if (_tearWild == null && _tearCloseT < 0) {
      _camPan =
          (_ringShotAt - ship.pos) * Curves.easeInOut.transform(_ringFrame);
    }
    return shot != null;
  }
}
