part of 'fusion_burst.dart';

// THE CINEMATIC, IN A STYLE (the Athanor's fusion styles). The same grains
// and the same clock as the plain eruption — the knot until [burstAt], the
// cultivation whole by [settledAt], turning slowly after — but each style
// plays its own climax, and none draws a sigil.
//
//   ink           the dark spiral turning at the core, two arms, one of
//                 each; at the climax it blooms open, the colors coming back
//                 from the inside out as it rounds into the cultivation; a
//                 few wisps curl away and thin out
//   frost         two crystals grown into each other, faceted in grains,
//                 still growing; at the climax the outside of them falls
//                 away as snow, and what was inside thaws into the
//                 cultivation
//   gilt          the helix of leaf, folded close, spinning; at the climax
//                 the leaves fold onto the sphere, and a burnish sweeps
//                 across it, leaving the colors behind it; a few flakes
//                 drift down
//   ember         two flames twisted together over the core; at the climax
//                 they burn down into one white-hot core, which swells into
//                 the cultivation as it cools, white to red to its colors;
//                 embers rise off it until it is cool
//   distillation  the pool at the core, drops still falling into it; at
//                 the climax it draws itself up, the middle first, into the
//                 round cultivation; the last drops fall, and a little
//                 vapour rises off it

extension _StyledBurst on FusionBurstField {
  void _seedStyle() {
    final st = style!;
    _kx = Float32List(length);
    _ky = Float32List(length);
    _facet = Uint8List(length);
    _matTones = [for (final p in _palettes) fusionStyleTones(st, p)];
    for (var i = 0; i < length; i++) {
      final s = _side[i], a = _along[i], ph = _phase[i];
      switch (st) {
        case FusionStyle.ink:
          // How far out on its arm, wavering (never an even spiral), and
          // across it — a few drawn out in tendrils; and its tone.
          _kx[i] =
              math.pow(a, 0.85) *
              (1 +
                  0.2 * math.sin(a * 9 + s * 2.1) +
                  0.1 * math.sin(a * 23 + s));
          _ky[i] =
              (ph - 0.5) * (0.12 + 0.3 * a) * (fsHash(i, 151) > 0.82 ? 1.8 : 1);
          final h = fsHash(i, 150);
          _facet[i] = h > 0.88
              ? 6
              : (h < 0.14
                    ? 1
                    : 2 + _clampTone((a * 2.2 + ph * 1.2).floor(), 0, 3));
        case FusionStyle.frost:
          // Its slot in the crystals, locked to the lattice (full grown,
          // in px), and the facet it lies on.
          final (x, y, f) = fsCrystalSlot(i, s);
          final slot = fsLattice(x * radius * 0.72, y * radius * 0.72, 3.4);
          _kx[i] = slot.dx;
          _ky[i] = slot.dy;
          _facet[i] = f;
        case FusionStyle.ember:
          // Its place in the white-hot core the flames burn down into.
          final br = 0.28 * math.sqrt(fsHash(i, 175));
          final ba = fsHash(i, 176) * math.pi * 2;
          _kx[i] = math.cos(ba) * br;
          _ky[i] = math.sin(ba) * br;
        case FusionStyle.distillation:
          final r = math.sqrt(fsHash(i, 140));
          final a2 = fsHash(i, 141) * math.pi * 2;
          _kx[i] = math.cos(a2) * r;
          _ky[i] = math.sin(a2) * r;
          // Which of the last drops it falls in.
          _facet[i] = i % 18;
        case FusionStyle.gilt:
          break;
      }
    }
  }

  void _paintStyled(
    Canvas canvas,
    Offset core,
    double u, {
    required List<Color> colors,
    Color? accent,
    bool pure = false,
    double clock = 0,
    bool darkBackdrop = true,
  }) {
    final st = style!;
    final b = _batch..clear();
    final r = radius;
    final heat = FusionBurstField._clamp01(u / FusionBurstField.burstAt);
    final turn = clock * 0.35;
    const tip = 0.3;
    final cosT = math.cos(tip), sinT = math.sin(tip);

    // Where grain [i] sits on the turning cultivation, and whether on its
    // far side.
    (double, double, bool) shell(int i) {
      final lon = _lon0[i] + _omega[i] * (u + turn);
      final cl = math.cos(_lat[i]);
      final px = _shellR[i] * cl * math.cos(lon);
      final py = _shellR[i] * math.sin(_lat[i]);
      final pz = _shellR[i] * cl * math.sin(lon);
      return (
        core.dx + px,
        core.dy + py * cosT + pz * sinT,
        pz * cosT - py * sinT < 0,
      );
    }

    // Grain [i] drawn in its own color (on the cultivation), or in tone
    // [mat] of the material (1–6), or as a glint (7).
    void add(int i, double x, double y, int mat, {bool far = false}) {
      final s = _side[i];
      if (mat == 7) {
        b.add(FusionBurstField._glintB, x, y);
        return;
      }
      if (mat > 0) {
        b.add(FusionBurstField._matGlowB + s, x, y);
        b.add(FusionBurstField._matB + s * kFusionStyleTones + mat - 1, x, y);
        return;
      }
      b.add(FusionBurstField._glowB + s, x, y);
      final twinkle = (clock * 0.23 + _phase[i] * 7.3) % 1.0 < 0.01;
      if (twinkle && !far) {
        b.add(FusionBurstField._glintB, x, y);
        return;
      }
      b.add(
        (far ? FusionBurstField._farOff : 0) +
            s * FusionBurstField._tones +
            _tone[i],
        x,
        y,
      );
    }

    for (var i = 0; i < length; i++) {
      final s = _side[i];
      final ph = _phase[i];
      final a = _along[i];
      final role = _role[i];
      switch (st) {
        case FusionStyle.ink:
          // The spiral: one arm of each, wavering, turning; it blooms open
          // at the climax, the outer reaches furthest.
          final bloom = fsSmooth(0.45, 1.15, u);
          final th =
              s * math.pi * 0.86 + a * 3 * math.pi - u * 0.9 - bloom * 0.8 * a;
          final wisp = role == FusionBurstField._ember;
          final spread =
              1 + 1.5 * bloom * a + (wisp ? 0.7 * fsSmooth(0.6, 2.4, u) : 0);
          final rad =
              r *
              0.5 *
              (0.14 + _kx[i] * (s == 0 ? 1.0 : 0.82)) *
              spread *
              (0.92 + 0.08 * heat);
          final w = _ky[i] * r * (1 + bloom);
          final ct = math.cos(th), sn = math.sin(th);
          final sx = core.dx + ct * rad - sn * w;
          final sy = core.dy + (sn * rad + ct * w) * 0.78;
          final inkTone = _facet[i];
          if (wisp) {
            // Curling away and thinning out.
            if (u > 1.3 + 1.1 * ph) continue;
            add(i, sx, sy, u > 0.9 + 0.8 * ph ? 5 : inkTone);
            continue;
          }
          // Rounding into the cultivation, the inside first; its colors
          // come back as it does.
          final from = 0.6 + 0.7 * a;
          final g = fsEaseInOut(fsClamp01((u - from) / 0.6));
          final (hx, hy, far) = shell(i);
          final x = sx + (hx - sx) * g, y = sy + (hy - sy) * g;
          add(i, x, y, u > from + 0.3 ? 0 : inkTone, far: g > 0.6 && far);

        case FusionStyle.frost:
          // The crystals, still growing, facet by facet.
          final grow = 0.55 + 0.45 * fsSmooth(0, 0.45, u);
          final cx = core.dx + _kx[i] * grow, cy = core.dy + _ky[i] * grow;
          final facet = _facet[i];
          final glint = facet >= 4 && (clock * 0.3 + ph * 7.3) % 1.0 < 0.03;
          final crystal = glint ? 7 : 1 + facet;
          final skin =
              role == FusionBurstField._ember ||
              (role == FusionBurstField._sigil && fsHash(i, 160) < 0.25);
          if (skin) {
            // The outside of it: falling away as snow at the climax,
            // drifting as it falls, and gone.
            final from = 0.45 + 0.6 * ph;
            final q = u - from;
            if (q <= 0) {
              add(i, cx, cy, crystal);
              continue;
            }
            if (q > 1.6) continue;
            final drift = (fsHash(i, 161) - 0.5) * 2;
            final x =
                cx +
                drift * q * r * 0.35 +
                math.sin(q * 2.2 + i) * r * 0.12 * math.min(1.0, q * 2);
            final y = cy + q * r * 0.5 + q * q * r * 0.12;
            add(i, x, y, q < 0.7 ? 6 : (q < 1.2 ? 5 : 3));
            continue;
          }
          // What was inside: thawing into the cultivation.
          final from = 0.6 + 0.6 * ph;
          final g = fsEaseInOut(fsClamp01((u - from) / 0.6));
          final (hx, hy, far) = shell(i);
          final x = cx + (hx - cx) * g, y = cy + (hy - cy) * g;
          add(i, x, y, u > from + 0.25 ? 0 : crystal, far: g > 0.6 && far);

        case FusionStyle.gilt:
          // The helix, folded close, spinning; its leaves flash as they
          // turn.
          final fold = 0.6 + 0.4 * fsSmooth(0, 0.45, u);
          final phi = s * math.pi + a * 2 * math.pi * 1.1 + u * 2.6;
          final rho = r * 0.55 * (0.85 + 0.3 * ((ph * 3) % 1.0));
          final hy0 = (a - 0.5) * 2 * r * 0.9 * (1 - 0.8 * fold);
          final lx = core.dx + rho * math.cos(phi);
          final ly = core.dy + hy0 + rho * 0.3 * math.sin(phi);
          final f = 0.5 + 0.5 * math.sin(clock * (4.5 + 4 * ph) + i * 1.3);
          final leafFar = math.sin(phi) < -0.2;
          final leaf = f > 0.985 ? 7 : (leafFar ? 1 : 2) + (f * 3.999).floor();
          if (role == FusionBurstField._ember) {
            // A few leaves let go, drifting down, flashing.
            final from = 0.5 + 0.5 * ph;
            final q = u - from;
            if (q <= 0) {
              add(i, lx, ly, leaf);
              continue;
            }
            if (q > 1.8) continue;
            add(
              i,
              lx + math.sin(q * 1.8 + i) * r * 0.25,
              ly + q * r * 0.45,
              leaf == 7 ? 7 : 2 + (f * 3.999).floor(),
            );
            continue;
          }
          // Folding onto the sphere, still gold; then the burnish sweeps
          // across and leaves the colors behind it.
          final from = 0.45 + 0.4 * ph;
          final g = fsEaseInOut(fsClamp01((u - from) / 0.55));
          final (hx, hy, far) = shell(i);
          final x = lx + (hx - lx) * g, y = ly + (hy - ly) * g;
          var tone = leaf;
          if (u > 1.05) {
            final band = -1.5 + 3.0 * fsClamp01((u - 1.05) / 0.7);
            final w = ((x - core.dx) * 0.7071 + (y - core.dy) * 0.7071) / r;
            if ((w - band).abs() < 0.14) {
              tone = (ph < 0.5) ? 7 : 6;
            } else if (w < band - 0.14) {
              tone = 0;
            }
          }
          add(i, x, y, tone, far: g > 0.6 && far);

        case FusionStyle.ember:
          // Two flames twisted together over the core; at the climax they
          // burn down into one white-hot core.
          final burn = fsSmooth(0.45, 0.85, u);
          final hgt = (ph + u * (0.6 + 0.4 * a)) % 1.0;
          final flick = math.sin(clock * 11 + i * 2.7);
          final height = r * 1.8 * (1 - burn);
          // One flame of the two wound together: wavering, licking toward
          // the tip, swelling off the root and tapering.
          final lick = math.sin(hgt * 6.5 - u * 8 + s * 1.7) * r * 0.1 * hgt;
          final wind = r * 0.14 * math.sin(hgt * 4.4 + u * 2.2 + s * math.pi);
          final width =
              r *
              0.32 *
              (0.45 + 0.55 * fsSmooth(0, 0.22, hgt)) *
              math.pow(1 - hgt, 0.8) *
              (1 - burn);
          final fx =
              core.dx + (lick + wind) * (1 - burn) + (a - 0.5) * 2 * width;
          final fy = core.dy + r * 0.35 * (1 - burn) - hgt * height;
          final bx = core.dx + _kx[i] * r, by = core.dy + _ky[i] * r;
          final kx = fx + (bx - fx) * burn, ky = fy + (by - fy) * burn;
          final flameTone =
              1 + _clampTone(((1 - hgt) * 5.2 + 0.5 * flick).floor(), 0, 5);
          final hot = burn < 1 ? flameTone : (flick > 0.6 ? 6 : 5);
          if (role == FusionBurstField._ember) {
            if (u < 0.5) {
              add(i, kx, ky, hot);
              continue;
            }
            // Embers rising off it until it has cooled, each from its own
            // place, thinning out as it cools.
            if (fsHash(i, 174) < 0.45 + 0.55 * fsSmooth(1.2, 2.0, u)) continue;
            final hg =
                (fsHash(i, 171) + u * (0.45 + 0.4 * fsHash(i, 172))) % 1.0;
            final x =
                core.dx +
                (fsHash(i, 170) - 0.5) * r * 0.6 +
                math.sin(hg * 5 + i) * r * 0.15 * hg;
            final y =
                core.dy - r * 0.15 - hg * r * (1.3 + 0.8 * fsHash(i, 173));
            add(i, x, y, 6 - _clampTone((hg * 5).floor(), 0, 4));
            continue;
          }
          // Swelling into the cultivation as it cools: white, then gold,
          // then red, then its own colors.
          final from = 0.8 + 0.55 * ph;
          final g = fsEaseInOut(fsClamp01((u - from) / 0.6));
          final (hx, hy, far) = shell(i);
          final x = kx + (hx - kx) * g, y = ky + (hy - ky) * g;
          final cool = fsClamp01((u - from) / 0.7);
          final tone = u < from
              ? hot
              : (cool >= 1 ? 0 : 6 - _clampTone((cool * 5).floor(), 0, 4));
          add(i, x, y, tone, far: g > 0.6 && far);

        case FusionStyle.distillation:
          final px = core.dx + _kx[i] * r * 0.8;
          final py =
              core.dy +
              r * 0.12 +
              _ky[i] * r * 0.2 +
              math.sin(u * 3 + _kx[i] * 6) * r * 0.012;
          if (role == FusionBurstField._ember) {
            // The last drops, falling in; then a little vapour rising off.
            final g = _facet[i];
            final from = 0.05 + 1.1 * fsHash(g, 3);
            final ra = fsHash(i, 180) * math.pi * 2;
            final rr = r * 0.035 * math.sqrt(fsHash(i, 181));
            final dx =
                core.dx + (fsHash(g, 1) - 0.5) * r * 1.5 + math.cos(ra) * rr;
            final dy =
                core.dy - r * (1.35 + 0.4 * fsHash(g, 4)) + math.sin(ra) * rr;
            if (u < from) {
              // Gathering, only shortly before it falls.
              if (from - u < 0.45) add(i, dx, dy, from - u < 0.2 ? 4 : 2);
              continue;
            }
            final q = fsClamp01((u - from) / 0.4);
            if (q < 1) {
              final streak = (fsHash(i, 182) - 0.5) * r * 0.14 * q;
              add(
                i,
                dx + (px - dx) * fsSmooth(0.8, 1, q),
                dy + (py - dy) * q * q + streak,
                4 + (fsHash(i, 183) * 2.4).floor(),
              );
              continue;
            }
            final rise = u - (1.3 + 0.6 * ph);
            // Into the pool (most), or rising off it again as vapour.
            if (fsHash(i, 184) > 0.3) continue;
            if (rise <= 0) {
              add(i, px, py, 4);
              continue;
            }
            if (rise > 1.1) continue;
            add(
              i,
              px + math.sin(rise * 2 + i) * r * 0.15,
              py - rise * r * 0.7,
              1,
            );
            continue;
          }
          // The pool drawing itself up into the round cultivation, the
          // middle first.
          final rr = math.sqrt(_kx[i] * _kx[i] + _ky[i] * _ky[i]);
          final from = 0.45 + 0.75 * rr;
          final g = fsEaseInOut(fsClamp01((u - from) / 0.6));
          final (hx, hy, far) = shell(i);
          final x = px + (hx - px) * g;
          final y = py + (hy - py) * g - math.sin(math.pi * g) * r * 0.25;
          final drop = (clock * 0.3 + ph * 7.3) % 1.0 < 0.015
              ? 7
              : 4 + (ph * 2).floor();
          add(i, x, y, g > 0.55 ? 0 : drop, far: g > 0.6 && far);
      }
    }

    // How far a pure reveal's colors have run into its accent.
    final formed = fsClamp01((u - 0.68) / (FusionBurstField.settledAt - 0.68));
    final into = accent == null ? 0.0 : (pure ? 0.65 : 0.25) * formed;
    const grain = 1.7;
    final glowAlpha = darkBackdrop ? 0.07 : 0.04;
    final light = fusionStyleLight(st);
    for (var s = 0; s < 2; s++) {
      final glow = accent == null
          ? colors[s]
          : Color.lerp(colors[s], accent, into)!;
      b.draw(
        canvas,
        FusionBurstField._glowB + s,
        grain * 3.8,
        glow.withValues(alpha: glowAlpha),
      );
      b.draw(
        canvas,
        FusionBurstField._matGlowB + s,
        grain * 3.8,
        Color.lerp(colors[s], light, 0.6)!.withValues(
          alpha:
              glowAlpha *
              switch (st) {
                FusionStyle.ink => 1.4,
                FusionStyle.frost => 0.6,
                _ => 1.2,
              } *
              (1 + heat),
        ),
      );
    }
    final size = fusionStyleGrain(st);
    for (var s = 0; s < 2; s++) {
      final tones = _palettes[s];
      for (var k = 0; k < tones.length; k++) {
        final c = accent == null
            ? tones[k]
            : Color.lerp(tones[k], accent, into)!;
        b.draw(
          canvas,
          FusionBurstField._farOff + s * FusionBurstField._tones + k,
          grain * 0.8,
          Color.lerp(c, const Color(0xFF000000), 0.45)!,
        );
        b.draw(canvas, s * FusionBurstField._tones + k, grain, c);
      }
      final mat = _matTones[s];
      for (var k = 0; k < kFusionStyleTones; k++) {
        b.draw(
          canvas,
          FusionBurstField._matB + s * kFusionStyleTones + k,
          grain * size,
          mat[k],
        );
      }
    }
    const glint = Color(0xFFFFFBEA);
    b.draw(
      canvas,
      FusionBurstField._glintB,
      grain * 2.6,
      glint.withValues(alpha: 0.22),
    );
    b.draw(
      canvas,
      FusionBurstField._glintB,
      grain * 1.4,
      glint.withValues(alpha: 0.95),
    );
  }
}

int _clampTone(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
