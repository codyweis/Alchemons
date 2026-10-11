part of 'fusion_burst.dart';

// THE CINEMATIC, IN A STYLE (the Athanor's fusion styles). The same grains
// and the same clock as the plain eruption — the knot until [burstAt], the
// cultivation whole by [settledAt], turning slowly after — but each style
// plays its own climax, and none draws a sigil.
//
//   ink           one dark marbled bloom turning slowly at the core, the
//                 two inks wound through each other in a shear; at the
//                 climax it opens like ink blooming in water — billows
//                 swelling out, their edges rolling over — carried by the
//                 same curling flow as the merge, and rounds into the
//                 cultivation from the inside out, its colors coming back
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
    _kz = Float32List(length);
    _kw = Float32List(length);
    _kv = Float32List(length);
    _facet = Uint8List(length);
    _matTones = [for (final p in _palettes) fusionStyleTones(st, p)];
    _flow = InkFlow(
      halfWidth: radius * 3.2,
      halfHeight: radius * 3.2,
      scale:
          radius *
          switch (st) {
            FusionStyle.ember => 0.5,
            FusionStyle.gilt => 1.2,
            _ => 0.95,
          },
      nx: st == FusionStyle.ember ? 40 : 26,
      ny: st == FusionStyle.ember ? 40 : 26,
    );
    for (var i = 0; i < length; i++) {
      final s = _side[i];
      switch (st) {
        case FusionStyle.ink:
          // Its place in the bloom: the two inks lie marbled through each
          // other — each grain in a region of its own ink, the regions
          // bounded by a few slow waves, so they meet along curling lines.
          var rn = 0.0, th0 = 0.0;
          for (var k = 0; k < 10; k++) {
            rn = 0.08 + 0.92 * math.sqrt(fsHash(i * 11 + k, 154));
            th0 = fsHash(i * 11 + k, 153) * math.pi * 2;
            final x = math.cos(th0) * rn, y = math.sin(th0) * rn;
            final marble =
                math.sin(3.1 * x + 1.7 * y + 0.5) +
                0.8 * math.sin(-2.3 * x + 3.7 * y + 2.1) +
                0.4 * math.sin(5.3 * x - 4.1 * y);
            if ((marble >= 0) == (s == 0)) break;
          }
          _kx[i] = rn;
          _ky[i] = th0;
          // How far out it billows when the bloom opens: lopsided lobes.
          _kz[i] =
              math.pow(rn, 1.3) *
              (1 +
                  0.3 * math.sin(5 * th0 + 1.3) +
                  0.18 * math.sin(3 * th0 + 0.4) +
                  0.08 * math.sin(9 * th0 + 2.2));
        case FusionStyle.frost:
          // Its place in the crystal mass the two froze into: as the merge
          // left them, two fans of feathered rays meeting in the middle —
          // each ray a spine with branchlets, uneven in angle and reach —
          // and how far out along the frost it lies (the tips go first).
          final sgn = s == 0 ? -1.0 : 1.0;
          final base = s == 0 ? math.pi : 0.0;
          final rn = 0.1 + 0.9 * math.sqrt(fsHash(i, 160));
          final an = base + (fsHash(i, 161) - 0.5) * 2.5;
          var best = 0;
          var bestD = 9.0;
          for (var j = 0; j < 5; j++) {
            final ra =
                base +
                (-1.05 + 2.1 * (j + 0.5) / 5) +
                (fsHash(j + s * 7, 162) - 0.5) * 0.35;
            final dd = an - ra;
            if (dd.abs() < bestD.abs()) {
              bestD = dd;
              best = j;
            }
          }
          final ra = an - bestD;
          final reach = 0.55 + 0.45 * fsHash(best + s * 7, 163);
          final along = rn * math.cos(bestD) * reach;
          final w = rn * math.sin(bestD);
          double ux, uy, len;
          final e1x = math.cos(ra), e1y = math.sin(ra) * 0.8;
          if (fsHash(i, 164) < 0.4) {
            ux = e1x * along;
            uy = e1y * along;
            len = along;
          } else {
            const cb = 0.53, sb = 0.848;
            final ws = w >= 0 ? 1.0 : -1.0;
            const d2 = 0.1;
            final j = ((along - w.abs() * cb / sb) / d2).round();
            final sj = math.max(0.0, j * d2);
            final bl = math.min(w.abs() / sb, d2 * 2.6);
            ux = e1x * sj + (e1x * cb - e1y * ws * sb) * bl;
            uy = e1y * sj + (e1y * cb + e1x * ws * sb) * bl;
            len = sj + bl;
          }
          _kx[i] = ux + sgn * 0.06;
          _ky[i] = uy;
          _kz[i] = len;
          final lit = (ux * -0.55 + uy * -0.835) / math.max(0.05, len);
          _facet[i] = lit > 0.3 ? 4 : (lit < -0.3 ? 1 : (len > 0.6 ? 3 : 2));
        case FusionStyle.gilt:
          // Leaves of gold: nine grains to a leaf, laid along its length.
          final f = i ~/ 9;
          final leaf = 0.8 + 0.5 * fsHash(f, 171);
          _kx[i] = (fsHash(i, 172) - 0.5) * 0.18 * leaf;
          _ky[i] = (fsHash(i, 173) - 0.5) * 0.065 * leaf;
          _kz[i] = fsHash(f, 174);
          _kw[i] = fsHash(f, 175);
        case FusionStyle.ember:
          // Its place in the coal, and when (if) it flares off it: how long
          // it burns and how high it carries.
          final br = math.sqrt(fsHash(i, 175));
          final ba = fsHash(i, 176) * math.pi * 2;
          _kx[i] = math.cos(ba) * br;
          _ky[i] = math.sin(ba) * br;
          final spark = fsHash(i, 177) < 0.04;
          final flares = spark || fsHash(i, 178) < 0.4;
          _kz[i] = flares ? 0.42 + 0.35 * fsHash(i, 179) : 9;
          _kv[i] = (0.45 + 0.55 * fsHash(i, 181)) * (spark ? 1.8 : 1);
          _kw[i] = (0.3 + 0.2 * fsHash(i, 180)) * (spark ? 1.4 : 1);
          _facet[i] = spark ? 1 : 0;
        case FusionStyle.distillation:
          // In the pool, or in one of the last drops still to fall.
          final pr = math.sqrt(fsHash(i, 140));
          final pa = fsHash(i, 141) * math.pi * 2;
          _kx[i] = math.cos(pa) * pr;
          _ky[i] = math.sin(pa) * pr;
          final ra = fsHash(i, 142) * math.pi * 2;
          final rr = math.sqrt(fsHash(i, 143));
          _kz[i] = math.cos(ra) * rr;
          _kw[i] = math.sin(ra) * rr;
          _facet[i] = _role[i] == FusionBurstField._ember ? 1 + i % 8 : 0;
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
    if (st == FusionStyle.ink) {
      // A faint light in the water, so the ink is darker than what is
      // round it; it goes as the cultivation forms.
      final water = (1 - fsSmooth(1.2, 2.0, u)) * (darkBackdrop ? 0.34 : 0.16);
      if (water > 0.004) {
        final open = fsSmooth(0.42, 1.3, u);
        canvas
          ..save()
          ..translate(core.dx, core.dy)
          ..scale(r * (1.15 + 1.0 * open));
        canvas.drawCircle(
          Offset.zero,
          1,
          Paint()
            ..shader = _inkWater
            ..color = Color.fromRGBO(0, 0, 0, water),
        );
        canvas.restore();
      }
    }
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

    if (st == FusionStyle.distillation && u != _bFrameU) {
      // The pool's surface: each landed drop's ring running out from where
      // it landed, sampled across the pool's width.
      _bFrameU = u;
      _bRipple.fillRange(0, _bRipple.length, 0);
      final nb = _bRipple.length;
      for (var d = 0; d < 8; d++) {
        final tau = u - (0.12 + 0.11 * d + 0.32);
        if (tau < 0 || tau > 1.3) continue;
        final xl = (fsHash(d, 191) - 0.5) * 1.5;
        final amp = r * 0.075 * math.exp(-2.6 * tau) * fsSmooth(0, 0.06, tau);
        final front = 1.25 * tau;
        for (var bb = 0; bb < nb; bb++) {
          final xb = -1.0 + 2.0 * bb / (nb - 1);
          final dist = (xb - xl).abs();
          final gg = (dist - front) / 0.2;
          if (gg.abs() > 3) continue;
          _bRipple[bb] +=
              -amp * math.exp(-gg * gg) * math.cos(dist / 0.08 - tau * 13);
        }
      }
    }
    for (var i = 0; i < length; i++) {
      final s = _side[i];
      final ph = _phase[i];
      final role = _role[i];
      switch (st) {
        case FusionStyle.ink:
          final rn = _kx[i];
          final wisp = role == FusionBurstField._ember;
          // The bloom: turning slowly, fastest in the middle, and opening
          // at the climax into billows whose edges roll over.
          final open = fsSmooth(0.42, 1.3, u);
          final r0 = r * 0.42 * (0.94 + 0.06 * heat);
          // Turning slowly, a little faster in the middle.
          final om = 0.3 + 0.2 / (0.4 + rn * rn);
          final th = _ky[i] + om * (u + 2.5);
          var rho = r0 * rn * (1 + 1.0 * open * _kz[i]);
          if (wisp) rho *= 1 + 0.25 * fsSmooth(0.6, 1.8, u);
          final ct = math.cos(th), st2 = math.sin(th);
          var sx = ct * rho, sy = st2 * rho * 0.88;
          if (rn > 0.55 && open > 0) {
            final e = (rn - 0.55) / 0.45 * open;
            final psi = 3.5 * th + 2.6 * u + rn * 4;
            sx += math.cos(psi) * r * 0.09 * e;
            sy += math.sin(psi) * r * 0.09 * e;
          }
          // The water carries it on its curls.
          // Gathering together, the inside a little first, so the
          // cultivation forms out of the ink rather than beside it.
          final from = wisp ? 1.0 + 0.3 * ph : 0.75 + 0.45 * rn;
          final g = fsEaseInOut(fsClamp01((u - from) / 0.75));
          final flow = _flow!..prepare(u);
          final eps = r * (0.1 + 0.16 * open) * (1 - g);
          if (eps > 0.01) {
            for (var k = 0; k < 2; k++) {
              flow.sample(sx, sy);
              sx += eps * flow.vx;
              sy += eps * flow.vy;
            }
          }
          // Rounding into the cultivation from the inside out; its colors
          // come back as it does.
          var x = core.dx + sx, y = core.dy + sy;
          if (g > 0) {
            final (hx, hy, far) = shell(i);
            x += (hx - x) * g;
            y += (hy - y) * g;
            // Its colors come back only as it arrives: until then it is
            // ink, gathering.
            if (g > 0.9) {
              add(i, x, y, 0, far: far);
              continue;
            }
            if (g > 0.4) {
              b.add(FusionBurstField._matB + s * kFusionStyleTones + 3, x, y);
              continue;
            }
          }
          final lit = ct * -0.55 + st2 * -0.835;
          final tone = wisp
              ? 3
              : (rn > 0.9 && lit > 0.88 && fsHash(i, 155) < 0.4
                    ? 4
                    : (rn < 0.45 ? 0 : (rn < 0.7 ? 1 : (rn < 0.88 ? 2 : 3))));
          b.add(FusionBurstField._matB + s * kFusionStyleTones + tone, x, y);

        case FusionStyle.frost:
          // The crystal mass, turning a little, still growing; its tips
          // go first — sublimed to fine snow that drifts on a slow flow,
          // and settles onto the cultivation.
          final grow = 0.88 + 0.12 * fsSmooth(0, 0.45, u);
          final rot = 0.15 * u;
          final cr = math.cos(rot), sr = math.sin(rot);
          final r0 = r * 0.95 * grow;
          final ux = _kx[i], uy = _ky[i];
          var x = core.dx + (ux * cr - uy * sr) * r0;
          var y = core.dy + (ux * sr + uy * cr) * r0;
          final dep = 0.45 + 0.55 * (1 - math.min(1.0, _kz[i]));
          final tau = u - dep;
          if (tau <= 0) {
            final band = (x * 0.05 + y * 0.034 - u * 0.7 + ph * 0.3) % 1.0;
            add(i, x, y, band < 0.035 && _facet[i] >= 3 ? 7 : 1 + _facet[i]);
            continue;
          }
          final snow = fsSmooth(0, 0.5, tau);
          x += ux * r * 0.18 * tau + math.sin(tau * 2.1 + i) * r * 0.06 * snow;
          y += r * 0.16 * tau * tau;
          final flow = _flow!..prepare(u * 0.5);
          final eps = r * 0.18 * snow;
          for (var k = 0; k < 2; k++) {
            flow.sample(x - core.dx, y - core.dy);
            x += eps * flow.vx;
            y += eps * flow.vy;
          }
          final g = fsEaseInOut(fsClamp01((u - dep - 0.25) / 0.7));
          if (g > 0) {
            final (hx, hy, far) = shell(i);
            x += (hx - x) * g;
            y += (hy - y) * g;
            if (g > 0.9) {
              add(i, x, y, 0, far: far);
              continue;
            }
          }
          add(i, x, y, tau < 0.12 ? 6 : 5);

        case FusionStyle.gilt:
          // A storm of gold leaf round the core, opening wide at the
          // climax; each leaf tumbling, flashing face and back, carried on
          // the air; then laid on the cultivation, lying flat, and a
          // burnish sweeps across it and leaves its colors behind.
          final hf1 = _kz[i], hf2 = _kw[i];
          final open = fsSmooth(0.45, 1.0, u);
          final rho = r * (0.35 + 0.5 * hf1) * (1 + 0.8 * open);
          final om = 2.2 / (0.6 + (0.35 + 0.5 * hf1) * (0.35 + 0.5 * hf1));
          final th = hf2 * math.pi * 2 + om * u;
          final phF = (2.5 + 1.5 * hf1) * clock + hf2 * 6;
          var cxl = core.dx + rho * math.cos(th) + r * 0.08 * math.sin(phF);
          // A storm, not a ring: each leaf at a height of its own.
          var cyl =
              core.dy +
              rho * math.sin(th) * 0.4 +
              (((hf1 * 3.7) % 1.0) - 0.5) * r * (0.7 + 0.6 * open) -
              r * 0.1 * open +
              r * 0.04 * (1 - math.cos(2 * phF));
          final flow = _flow!..prepare(u * 0.8);
          for (var k = 0; k < 2; k++) {
            flow.sample(cxl - core.dx, cyl - core.dy);
            cxl += r * 0.12 * flow.vx;
            cyl += r * 0.12 * flow.vy;
          }
          // Laid: onto the cultivation where the leaf's first grain will
          // sit, lying flat.
          final landAt = 0.85 + 0.45 * hf1;
          final lay = fsEaseInOut(fsClamp01((u - landAt) / 0.4));
          final (lx0, ly0, _) = shell((i ~/ 9) * 9);
          cxl += (lx0 - cxl) * lay;
          cyl += (ly0 - cyl) * lay;
          final tumble = (hf1 * math.pi * 2 + (3 + 4 * hf2) * u) * (1 - lay);
          final face = math.cos(tumble);
          final spin = hf2 * math.pi + (hf1 - 0.5) * 2 * u;
          final cs = math.cos(spin), sn = math.sin(spin);
          final ox = _kx[i] * r * face, oy = _ky[i] * r;
          var x = cxl + ox * cs - oy * sn, y = cyl + ox * sn + oy * cs;
          var tone = face >= 0
              ? (face > 0.996
                    ? 7
                    : 4 + (face > 0.94 ? 2 : (face > 0.6 ? 1 : 0)))
              : 3 - (face < -0.7 ? 2 : (face < -0.35 ? 1 : 0));
          if (lay > 0) {
            // The burnish: a bright band sweeping across; behind it each
            // grain goes to its own place, in its own colors.
            final band = -1.4 + 3.8 * fsSmooth(1.3, 1.8, u);
            final w = ((x - core.dx) * 0.7071 + (y - core.dy) * 0.7071) / r;
            final g = fsEaseInOut(fsClamp01((band - 0.12 - w) / 0.5)) * lay;
            if (g > 0) {
              final (hx, hy, far) = shell(i);
              x += (hx - x) * g;
              y += (hy - y) * g;
              if (g > 0.8) {
                add(i, x, y, 0, far: far);
                continue;
              }
            }
            if (lay > 0.3) {
              // Laid flat on the sphere, lit as it is lit.
              final lit =
                  (x - core.dx) / r * -0.55 + (y - core.dy) / r * -0.835;
              tone = lit > 0.35 ? 5 : (lit < -0.35 ? 3 : 4);
            }
            if ((w - band).abs() < 0.12) tone = ph < 0.5 ? 7 : 6;
          }
          add(i, x, y, tone);

        case FusionStyle.ember:
          // The coal: white at its heart, red at its edge, flickering; at
          // the climax half of it flares off as flame, rising on its own
          // heat through a quick flow and cooling as it goes, sparks
          // spiralling up; then the flame's embers fall back and the coal
          // swells into the cultivation, cooling white, orange, red, into
          // its colors.
          final kx = _kx[i], ky = _ky[i];
          final rn2 = kx * kx + ky * ky;
          final flow = _flow!..prepare(u * 2.4);
          var x = core.dx + kx * r * 0.34, y = core.dy + ky * r * 0.34;
          final flick = math.sin(clock * 9 + i * 1.7);
          var tone = rn2 < 0.25 ? 5 : (rn2 < 0.6 ? 4 : 3);
          if (flick > 0.7 && tone < 5) tone++;
          final fl = _kz[i], life = _kw[i];
          final a = (u - fl) / life;
          double from;
          if (a > 0) {
            // A tongue of flame off the coal: up from where it was, leaning
            // out a little its own way, licking, cooling fast; then ash,
            // which goes dark before it is drawn back in.
            final spark = _facet[i] == 1;
            final top = r * _kv[i];
            final aa = math.min(a, 1.0);
            final h = top * aa * aa * (2 - aa);
            y -= h;
            x += kx * r * 0.35 * aa + math.sin(a * 6 + ph * 9) * r * 0.08 * aa;
            if (spark) x += math.sin(a * 7 + ph * 6) * r * 0.25 * aa;
            // Torn by the flow, but rising: it sways more than it drifts.
            final eps = r * (0.04 * fsSmooth(0, 0.15, a) + 0.14 * h / top);
            for (var k = 0; k < 2; k++) {
              flow.sample(x - core.dx, y - core.dy);
              x += eps * flow.vx * 0.45;
              y += eps * flow.vy * 0.5;
            }
            final cool = spark ? a * 0.8 : a * 1.15;
            tone = cool < 0.1
                ? 5
                : (cool < 0.25
                      ? 4
                      : (cool < 0.45
                            ? 3
                            : (cool < 0.7 ? 2 : (cool < 0.95 ? 1 : 0))));
            from = fl + life * 0.85;
          } else {
            // The coal: still, but for its flicker.
            from = 0.8 + 0.5 * math.sqrt(rn2);
            x += flick * r * 0.012;
          }
          final g = fsEaseInOut(fsClamp01((u - from) / 0.4));
          if (g > 0) {
            final (hx, hy, far) = shell(i);
            x += (hx - x) * g;
            y += (hy - y) * g;
            if (g > 0.85) {
              add(i, x, y, 0, far: far);
              continue;
            }
            // Ash coming home stays dark; the coal cools as it swells.
            if (a <= 0) {
              tone = math.min(tone, 5 - _clampTone((g * 5).floor(), 0, 4));
            }
          }
          add(i, x, y, 1 + tone);

        case FusionStyle.distillation:
          // The pool, rocked by the last drops landing in it; at the
          // climax it draws itself up, the middle first, into the round
          // cultivation.
          final drop = _facet[i];
          final px = core.dx + _kx[i] * r * 0.8;
          final bin = ((_kx[i] * 0.8 + 1.0) / 2.0 * (_bRipple.length - 1))
              .round();
          final wave = _bRipple[_clampTone(bin, 0, _bRipple.length - 1)];
          final py = core.dy + r * 0.12 + _ky[i] * r * 0.2 + wave;
          var x = px, y = py;
          // The far surface catches the light where a ring lifts it.
          var tone = _ky[i] < -0.55 && wave < -r * 0.03
              ? 5
              : (_ky[i] < -0.2 ? 4 : 3);
          var from = 0.45 + 0.75 * _kx[i].abs();
          if (drop > 0) {
            // One of the last drops: beading, necking, falling.
            final d = drop - 1;
            final dx0 = core.dx + (fsHash(d, 191) - 0.5) * r * 1.5;
            final dy0 = core.dy - r * 1.35;
            final go = 0.12 + 0.11 * d;
            final land = go + 0.32;
            final rr = r * 0.15;
            final ox = _kz[i], oy = _kw[i];
            if (u < land) {
              double lx, ly, cy0 = dy0;
              if (u < go) {
                final nk = fsSmooth(go - 0.12, go, u);
                lx = ox * (1 - 0.45 * nk * math.max(0.0, -oy));
                ly = oy * (1 + 0.8 * nk) + 0.5 * nk;
              } else {
                final tau = u - go;
                final gr = 2 * (core.dy + r * 0.12 - dy0) / (0.32 * 0.32);
                cy0 = dy0 + 0.5 * gr * tau * tau;
                final ring = math.exp(-5 * tau);
                lx = ox * (1 - 0.45 * math.exp(-8 * tau) * math.max(0.0, -oy));
                ly = oy * (1 + 0.8 * ring * math.cos(16 * tau)) + 0.5 * ring;
              }
              x = dx0 + lx * rr;
              y = cy0 + ly * rr;
              tone = fsDropTone(ox, oy);
              add(i, x, y, 1 + tone);
              continue;
            }
            // Landed: spreading into the pool.
            final m = fsEaseInOut(fsClamp01((u - land) / 0.3));
            final ex = dx0 + ox * rr, ey = core.dy + r * 0.12 + oy * rr;
            x = ex + (px - ex) * m;
            y = ey + (py - ey) * m;
            from = math.max(from, land + 0.15);
          }
          final g = fsEaseInOut(fsClamp01((u - from) / 0.6));
          if (g > 0) {
            final (hx, hy, far) = shell(i);
            x += (hx - x) * g;
            y += (hy - y) * g - math.sin(math.pi * g) * r * 0.25;
            if (g > 0.6) {
              add(i, x, y, 0, far: far);
              continue;
            }
          }
          add(i, x, y, 1 + tone);
      }
    }

    // How far a pure reveal's colors have run into its accent.
    final formed = fsClamp01((u - 0.68) / (FusionBurstField.settledAt - 0.68));
    final into = accent == null ? 0.0 : (pure ? 0.65 : 0.25) * formed;
    const grain = 1.7;
    final glowAlpha = darkBackdrop ? 0.07 : 0.04;
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
    }
    if (st != FusionStyle.ink) {
      // Each tone in its layers — a haze, a body, fine grains — every
      // haze first, so the material reads as one.
      for (var pass = 0; pass < 3; pass++) {
        for (var s = 0; s < 2; s++) {
          final mat = _matTones[s];
          for (var k = 0; k < kFusionStyleTones; k++) {
            final (mul, alpha, dark) = fusionStyleLayers(st, k)[pass];
            if (alpha <= 0) continue;
            var col = mat[k];
            if (dark > 0) col = Color.lerp(col, const Color(0xFF000000), dark)!;
            b.draw(
              canvas,
              FusionBurstField._matB + s * kFusionStyleTones + k,
              grain * size * mul,
              col.withValues(alpha: alpha),
            );
          }
        }
      }
    }
    if (st == FusionStyle.ink) {
      // Each tone in three layers — a haze, a body, fine grains — so the
      // bloom reads as one fluid: the thick tones darker than the light in
      // the water, the thin ones their own color.
      for (var pass = 0; pass < 3; pass++) {
        for (var s = 0; s < 2; s++) {
          final mat = _matTones[s];
          for (var k = 0; k < kFusionStyleTones; k++) {
            final thin = k >= 4;
            if (thin && pass == 1) continue;
            final shade = thin
                ? mat[k]
                : Color.lerp(mat[k], const Color(0xFF000000), 0.45)!;
            final (size, color) = switch (pass) {
              0 => (grain * 4.2, shade.withValues(alpha: thin ? 0.07 : 0.16)),
              1 => (grain * 2.0, shade.withValues(alpha: 0.3)),
              _ => (
                grain * (thin ? 0.85 : 0.9),
                mat[k].withValues(alpha: thin ? 0.9 : 0.72),
              ),
            };
            b.draw(
              canvas,
              FusionBurstField._matB + s * kFusionStyleTones + k,
              size,
              color,
            );
          }
        }
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

final ui.Shader _inkWater = ui.Gradient.radial(
  Offset.zero,
  1,
  const [
    Color(0xFF9CA4C8),
    Color(0x669CA4C8),
    Color(0x149CA4C8),
    Color(0x009CA4C8),
  ],
  const [0.0, 0.35, 0.72, 1.0],
);
