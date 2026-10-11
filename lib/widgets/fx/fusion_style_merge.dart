part of 'fusion_particles.dart';

// THE MERGE, IN A STYLE (the Athanor's fusion styles). Up to the stand it is
// the plain merge: the crest, the pair standing as grains, the hold while a
// verdict is waited on and the run back if it fails. From there each grain
// turns to the style's material where it stands — nearest the orb first —
// and goes into the orb the style's way, and the whole falls into it at the
// end as the plain merge does (2.15–2.5), then goes out in the style's own
// light.
//
//   ink           dissolving where it stands, sinking a little, then
//                 running into the orb along curling streams: two arms of
//                 one dark spiral, one of each, turning slowly
//   frost         locking to a lattice where it stands, so the body turns
//                 faceted, then growing into the orb along the lattice
//                 (across, then on the slant) as two crystals leaning into
//                 each other, shaded facet by facet
//   gilt          turning to gold leaf that flashes as it turns, lifting into
//                 a double helix round the orb (a strand of each), which
//                 folds flat, leaf on leaf
//   ember         heating where it stands, then rising into two flames above
//                 the orb that twist round each other, hottest at the root,
//                 and burn down into it
//   distillation  thinning to vapour that rises into a cloud above the orb,
//                 condenses into drops, and drips into one pool

/// The drops a distillation condenses into.
const int _kDrops = 120;

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// Seconds a styled grain takes to go from where it stood into its form.
const double _kTravel = 0.8;

extension _StyledMerge on FusionParticleField {
  void _seedStyle() {
    final st = style!;
    final n = length;
    _matAt = Float32List(n);
    _sa = Float32List(n);
    _sb = Float32List(n);
    _fx = Float32List(n);
    _fy = Float32List(n);
    _gx = Float32List(n);
    _gy = Float32List(n);
    _look = Uint8List(n);
    _grp = Uint8List(n);
    _grpT = Float32List(_kDrops);
    _matTones = [for (final g in _specimens) fusionStyleTones(st, g.tones)];
    for (var i = 0; i < n; i++) {
      // Never before the stand: a merge held there is the plain merge.
      _matAt[i] = math.max(0.66, _release[i] - 0.32) + 0.12 * fsHash(i, 103);
      _sa[i] = fsHash(i, 101);
      _sb[i] = fsHash(i, 102);
    }
    switch (st) {
      case FusionStyle.ink:
        for (var i = 0; i < n; i++) {
          final a = _sa[i], s = _side[i];
          // How far out on its arm, how the arm wavers there (never an
          // even spiral), and how far across the arm — a few drawn out in
          // tendrils.
          _fx[i] = math.pow(a, 0.85).toDouble();
          _fy[i] =
              1 + 0.2 * math.sin(a * 9 + s * 2.1) + 0.1 * math.sin(a * 23 + s);
          final tendril = fsHash(i, 106) > 0.82 ? 1.8 : 1.0;
          _gx[i] = (_sb[i] - 0.5) * (0.16 + 0.32 * a) * tendril;
          _grp[i] = _inkTone(i, a);
        }
      case FusionStyle.frost:
        for (var i = 0; i < n; i++) {
          final s = _side[i];
          final pitch = math.max(3.0, _grainD[s] * 1.9);
          // Where it locks to the lattice where it stands, and its slot in
          // the crystals at the orb, on the same lattice.
          final snap = fsLattice(_relX[i] * 1.04, _relY[i] * 1.04, pitch);
          _gx[i] = snap.dx;
          _gy[i] = snap.dy;
          final (x, y, facet) = fsCrystalSlot(i, s);
          final slot = fsLattice(x * coreRadius, y * coreRadius, pitch);
          _fx[i] = slot.dx;
          _fy[i] = slot.dy;
          _grp[i] = facet;
        }
      case FusionStyle.distillation:
        // Drops of grains that left together, the last to leave the last
        // to condense; each grain's place in its drop and in the pool.
        final order = List.generate(n, (i) => i)
          ..sort((a, b) => _release[a].compareTo(_release[b]));
        final latest = Float32List(_kDrops);
        for (var r = 0; r < n; r++) {
          final i = order[r];
          final d = math.min(_kDrops - 1, r * _kDrops ~/ math.max(1, n));
          _grp[i] = d;
          latest[d] = math.max(latest[d], _release[i]);
        }
        for (var d = 0; d < _kDrops; d++) {
          _grpT[d] = math.min(1.9, latest[d] + 0.34 + 0.1 * fsHash(d, 3));
        }
        for (var i = 0; i < n; i++) {
          final d = _grp[i];
          final rr = 0.04 * math.sqrt(_sb[i]);
          final ra = _sa[i] * math.pi * 2;
          _gx[i] = (fsHash(d, 1) - 0.5) * 2.6 + math.cos(ra) * rr;
          _gy[i] = -1.6 + (fsHash(d, 2) - 0.5) * 0.45 + math.sin(ra) * rr;
          final r = math.sqrt(fsHash(i, 120));
          final a = fsHash(i, 121) * math.pi * 2;
          _fx[i] = math.cos(a) * r;
          _fy[i] = math.sin(a) * r;
        }
      case FusionStyle.gilt:
      case FusionStyle.ember:
        break;
    }
  }

  /// Where styled grain [i] is at [t], having stood at ([rx], [ry]).
  void _placeStyled(int i, double t, double clock, double rx, double ry) {
    final st = style!;
    final s = _side[i];
    final r = coreRadius;
    final start = _release[i];
    final p = fsClamp01((t - start) / _kTravel);
    final e = fsEaseInOut(p);
    final turned = t >= _matAt[i] + 0.1 * _sb[i];
    final cx = _centres[s].dx + shift[s].dx;
    final cy = _centres[s].dy + shift[s].dy;
    var x = rx, y = ry, depth = 1.0;
    var look = 0;

    switch (st) {
      case FusionStyle.ink:
        // Dissolving where it stands: loosening, and sinking a little, as
        // ink let into water does.
        final k = fsSmooth(_matAt[i], start + 0.1, t);
        final bx = rx + (rx - cx) * 0.08 * k + (_sb[i] - 0.5) * r * 0.1 * k;
        final by = ry + (ry - cy) * 0.05 * k + r * 0.14 * k * _sa[i];
        // Its place on its arm of the spiral, which turns slowly: one arm
        // of each, wavering, thickening outward.
        final a = _sa[i];
        // The arms are not twins: the second set a little off opposite
        // and shorter, so it never reads as an emblem.
        final th = s * math.pi * 0.86 + a * 3.0 * math.pi - t * 0.9;
        final rad = r * (0.14 + _fx[i] * (s == 0 ? 1.0 : 0.82)) * _fy[i];
        final w = _gx[i] * r;
        final ct = math.cos(th), sn = math.sin(th);
        final fx = core.dx + ct * rad - sn * w;
        final fy = core.dy + (sn * rad + ct * w) * 0.78;
        // Running there, curling: both the same way round, so the two
        // streams wind into each other.
        final dx = fx - bx, dy = fy - by;
        final len = math.sqrt(dx * dx + dy * dy) + 1e-3;
        final curl = r * 0.6 * math.sin(math.pi * p);
        x = bx + dx * e - dy / len * curl;
        y = by + dy * e + dx / len * curl;
        if (turned) look = 1 + _grp[i];

      case FusionStyle.frost:
        // Locking to the lattice where it stands.
        final k = fsSmooth(_matAt[i], _matAt[i] + 0.3, t);
        final bx = rx + (cx + _gx[i] - rx) * k;
        final by = ry + (cy + _gy[i] - ry) * k;
        // Growing into its slot in the crystals at the orb along the
        // lattice: across first, then on the slant, so each crystal
        // reaches out toward the other.
        final fx = core.dx + _fx[i], fy = core.dy + _fy[i];
        final dx = fx - bx, dy = fy - by;
        final sx = dx >= 0 ? 1.0 : -1.0, sy = dy >= 0 ? 1.0 : -1.0;
        final along = dy.abs() / 0.8660254;
        final across = dx - sx * 0.5 * along;
        if (e < 0.5) {
          x = bx + across * (e / 0.5);
          y = by;
        } else {
          final q = (e - 0.5) / 0.5;
          x = bx + across + sx * 0.5 * along * q;
          y = by + sy * 0.8660254 * along * q;
        }
        if (turned) {
          final tone = p < 0.5 ? 1 + (_sb[i] * 4).floor() : _grp[i];
          look = 1 + tone;
          if (tone >= 4 && (clock * 0.3 + _phase[i] * 7.3) % 1.0 < 0.02) {
            look = 7;
          }
        }

      case FusionStyle.gilt:
        // Turning to leaf where it stands, lifting a little.
        final k = fsSmooth(_matAt[i], start, t);
        final bx = rx, by = ry - r * 0.12 * k * _sa[i];
        // Its place on its strand of the helix round the orb, which folds
        // flat as the merge ends: leaf on leaf.
        final fold = fsSmooth(1.8, 2.2, t);
        final a = _sa[i];
        final phi = s * math.pi + a * 2 * math.pi * 1.1 + t * 2.4;
        final rho = r * 0.72 * (0.85 + 0.3 * _sb[i]);
        final hy = (a - 0.5) * 2 * r * 1.25 * (1 - 0.85 * fold);
        final fx = core.dx + rho * math.cos(phi);
        final fy = core.dy + hy + rho * 0.3 * math.sin(phi);
        x = bx + (fx - bx) * e;
        y = by + (fy - by) * e - r * 0.9 * math.sin(math.pi * p);
        if (p > 0.6) depth = math.sin(phi);
        if (turned) look = _flash(i, clock);

      case FusionStyle.ember:
        // Heating where it stands: flickering, lifted a little.
        final k = fsSmooth(_matAt[i], start, t);
        final flick = math.sin(clock * 11 + i * 2.7);
        final bx = rx + flick * r * 0.015 * k;
        final by = ry - r * 0.08 * k * (0.5 + 0.5 * flick) * _sa[i];
        // Each becomes a flame rising off where it stood; the two flames'
        // roots draw together under the orb, their tips leaning in, and
        // once together they twist round each other. At the end they burn
        // down into it.
        final sgn = s == 0 ? -1.0 : 1.0;
        final m = fsSmooth(1.0, 2.0, t);
        final burn = fsSmooth(1.95, 2.3, t);
        final footY = cy + _maxY[s] * _scales[s] * 0.8;
        final rootX = cx + (core.dx + sgn * r * 0.12 - cx) * m;
        final rootY = footY + (core.dy + r * 0.55 - footY) * m;
        final hgt =
            (_sb[i] + math.max(0.0, t - start) * (0.55 + 0.4 * _sa[i])) % 1.0;
        final height = r * (1.5 + 0.9 * m) * (1 - 0.7 * burn);
        final lean = (core.dx - rootX) * 0.55 * hgt;
        // Its centre wavers, licking, more toward the tip; once the two are
        // together they wind round each other a little.
        final lick = math.sin(hgt * 6.5 - t * 8 + s * 1.7) * r * 0.12 * hgt;
        final wind = r * 0.16 * m * math.sin(hgt * 4.4 + t * 2.2 + s * math.pi);
        // A flame's width: swelling off the root, tapering to the tip.
        final width =
            r *
            0.36 *
            (0.45 + 0.55 * fsSmooth(0, 0.22, hgt)) *
            (1 - hgt) *
            (1.2 - 0.2 * (1 - hgt)) *
            (0.85 + 0.15 * flick);
        final fx = rootX + lean + lick + wind + (_sa[i] - 0.5) * 2 * width;
        final fy = rootY - hgt * height;
        final q = fsEaseInOut(fsClamp01((t - start) / 0.45));
        x = bx + (fx - bx) * q;
        y = by + (fy - by) * q;
        if (q >= 1 && m > 0.5) {
          depth = math.cos(hgt * 4.4 + t * 2.2 + s * math.pi);
        }
        if (turned) {
          final heat = q < 1 ? 0.35 + 0.35 * k + 0.3 * q : 1 - hgt;
          look = 1 + _clampInt((heat * 5.2 + 0.5 * flick).floor(), 0, 5);
        }

      case FusionStyle.distillation:
        final tc = _grpT[_grp[i]];
        // Thinning to vapour where it stands, lifting.
        final k = fsSmooth(_matAt[i], start, t);
        final bx = rx + (rx - cx) * 0.12 * k;
        final by = ry - r * 0.3 * k * k * (0.4 + _sa[i]);
        // The cloud above the orb, and the vapour rising into it.
        final cloudX =
            core.dx +
            (_sa[i] - 0.5) * 2 * r * 1.5 +
            math.sin(clock * 0.8 + i) * r * 0.12;
        final cloudY =
            core.dy -
            r * 1.7 +
            (_sb[i] - 0.5) * r * 0.55 +
            math.sin(clock * 1.1 + i * 0.7) * r * 0.08;
        final sway = math.sin(math.pi * p) * (_sb[i] - 0.5) * r * 0.6;
        final vx = bx + (cloudX - bx) * e + sway;
        final vy = by + (cloudY - by) * e;
        // Its drop, and its place in the pool.
        final ix = core.dx + _gx[i] * r, iy = core.dy + _gy[i] * r;
        final poolX = core.dx + _fx[i] * r * 0.85;
        final poolY =
            core.dy +
            r * 0.18 +
            _fy[i] * r * 0.22 +
            math.sin(t * 3 + _fx[i] * 6) * r * 0.012;
        final condense = fsSmooth(tc, tc + 0.22, t);
        final fall = fsClamp01((t - tc - 0.22) / 0.36);
        if (fall > 0) {
          // Falling as a drop — drawn out a little as it falls — and
          // spreading into the pool as it lands.
          final land = fsSmooth(0.82, 1.0, fall);
          final streak = (_sb[i] - 0.5) * r * 0.16 * fall * (1 - land);
          x = ix + (poolX - ix) * land;
          y = iy + (poolY - iy) * fall * fall + streak;
          look = fall >= 1
              ? ((clock * 0.3 + _phase[i] * 7.3) % 1.0 < 0.015
                    ? 7
                    : 4 + (_sb[i] * 2).floor())
              : 4 + (_sb[i] * 2.4).floor();
        } else if (condense > 0) {
          x = vx + (ix - vx) * condense;
          y = vy + (iy - vy) * condense;
          look = condense > 0.5 ? 4 + (_sb[i] * 2.4).floor() : 3;
        } else {
          x = vx;
          y = vy;
          if (turned) look = 1 + (_sb[i] * 3).floor();
        }
    }

    // Into the orb at the end, as the plain merge goes.
    final c = FusionParticleField._interval(
      t,
      FusionParticleField._collapseStart,
      FusionParticleField._collapseEnd,
    );
    if (c > 0) {
      final k = 1 - 0.94 * c * c * c;
      x = core.dx + (x - core.dx) * k;
      y = core.dy + (y - core.dy) * k;
    }
    _x[i] = x;
    _y[i] = y;
    _depth[i] = depth;
    _mode[i] = p > 0 ? 2 : 1;
    _look[i] = look;
  }

  /// An ink grain's tone (0–5): mostly deep, darker toward the spiral's
  /// heart, and a lit edge on a few.
  int _inkTone(int i, double a) {
    final h = fsHash(i, 104);
    if (h > 0.88) return 5;
    if (h < 0.14) return 0;
    return 1 + _clampInt((a * 2.2 + _sb[i] * 1.2).floor(), 0, 3);
  }

  /// A leaf turning in the light: its tone flashes, and now and then it
  /// catches the light full (a glint).
  int _flash(int i, double clock) {
    final f = 0.5 + 0.5 * math.sin(clock * (4.5 + 4 * _sb[i]) + i * 1.3);
    if (f > 0.985) return 7;
    return 2 + (f * 3.999).floor();
  }

  void _paintStyled(
    Canvas canvas,
    double t, {
    required bool back,
    required double now,
  }) {
    final st = style!;
    final b = _batch..clear();
    for (var i = 0; i < length; i++) {
      if (_mode[i] == 0) continue;
      if ((_depth[i] < 0) != back) continue;
      final look = _look[i];
      if (look == 0) {
        _addOwn(b, i, t, now, back: back);
        continue;
      }
      final x = _x[i], y = _y[i];
      if (look == 7) {
        b.add(FusionParticleField._glint, x, y);
        continue;
      }
      final s = _side[i];
      b.add(FusionParticleField._matGlow + s, x, y);
      b.add(FusionParticleField._mat + s * kFusionStyleTones + look - 1, x, y);
    }
    _drawOwn(canvas, t, back: back);

    final c = FusionParticleField._interval(
      t,
      FusionParticleField._collapseStart,
      FusionParticleField._collapseEnd,
    );
    final shrink = 1 - 0.7 * c;
    final light = fusionStyleLight(st);
    final size = fusionStyleGrain(st);
    final glowAlpha =
        (darkBackdrop ? 0.06 : 0.035) *
        switch (st) {
          FusionStyle.ink => 1.3,
          FusionStyle.frost => 0.6,
          _ => 1.1,
        };
    for (var s = 0; s < 2; s++) {
      final d = _grainD[s] * shrink * size;
      b.draw(
        canvas,
        FusionParticleField._matGlow + s,
        d * (back ? 3.0 : 3.6),
        Color.lerp(
          _colors[s],
          light,
          0.65,
        )!.withValues(alpha: back ? glowAlpha * 0.6 : glowAlpha),
      );
      final tones = _matTones[s];
      for (var k = 0; k < kFusionStyleTones; k++) {
        var col = Color.lerp(tones[k], light, c * c * 0.4)!;
        if (back) col = Color.lerp(col, const Color(0xFF000000), 0.35)!;
        b.draw(
          canvas,
          FusionParticleField._mat + s * kFusionStyleTones + k,
          d * (back ? 0.85 : 1),
          col,
        );
      }
    }
    if (back) return;
    _bloom(
      canvas,
      t,
      Color.lerp(light, const Color(0xFFFFFFFF), 0.4)!,
      light,
      fusionStyleFlare(st),
    );
  }
}
