// DARK — Nythralor, the Eclipse Vault, hung near a BLACK HOLE.
//
// IMPLIED, NOT SHOWN (2026-09-25, second pass). The first black hole was the
// stock picture — an even disc, a clean lensed arch and a white hairline
// round the horizon — and the author called it cheesy. It was: a hairline
// hoop is a UI circle, and a centrepiece is the brightest thing on the
// darkest planet in the set. What is here now is what you would actually
// notice first:
//
//   · a patch of sky with NOTHING in it, and the stars around it crowded
//     and smeared along its edge where their light bends past;
//   · on ONE side only, a dim, broken glow of the disc coming toward you —
//     uneven, streaked, and fading into the dark before it closes a ring;
//   · a faint bruise of that light in the haze around it.
//
// There is no ring, no arch and no symmetry. uColorA void · uColorB the
// disc's cool violet · uColorC its warm heart.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // High and to one side: the camera sits on the party.
  vec2 c = vec2(0.76 * aspect, 0.24);
  vec2 d = p - c;
  float r = length(d);
  float rh = 0.11;
  float ang = atan(d.y, d.x);

  vec3 col = uColorA;

  // ── haze, faintly warmer on the lit side ──
  float lit = 0.5 + 0.5 * cos(ang - 2.6);          // the approaching side
  float haze = fbm(p * uNoiseScale * 1.4 + uSeed + vec2(t * 0.03, 0.0));
  col += uColorB * haze * 0.10 * pow(smoothstep(1.3, 0.1, r), 1.5) * (0.4 + 0.6 * lit);

  // ── lensed stars: pushed out of the hole and smeared along its edge ──
  float bend = (rh * rh * 1.8) / max(r * r, 1e-4);
  vec2 sp = c + d * (1.0 + bend);
  // Stretch the cell tangentially near the edge, so a star close in is a
  // short streak around the hole rather than a dot.
  vec2 tang = vec2(-d.y, d.x) / max(r, 1e-4);
  float smear = smoothstep(rh * 2.6, rh * 1.05, r);
  vec2 sq = sp - tang * dot(sp - c, tang) * smear * 0.65;
  vec2 sg = sq * 46.0;
  vec2 sc = floor(sg);
  float sr = hash(sc + uSeed);
  float sd = length(fract(sg) - vec2(hash(sc + 5.1), hash(sc + 8.6)));
  float star = step(0.982, sr) * smoothstep(0.09, 0.0, sd)
             * (0.6 + 0.4 * sin(t * 1.1 + sr * 40.0));
  // Crowding: a few more come out close to the edge.
  float crowd = step(0.955, sr) * smoothstep(0.07, 0.0, sd) * smear * 0.6;
  col += mix(uColorC, vec3(1.0), 0.55) * (star * 0.6 + crowd * 0.5);

  // ── the one-sided glow of the disc ──
  // A flattened band, only on the approaching side, broken by noise and
  // fading before it can close into anything like a ring.
  float tilt = 0.30;
  vec2 q = vec2(d.x, d.y / tilt);
  float rq = length(q);
  float qa = atan(q.y, q.x);
  float side = smoothstep(0.1, 1.0, 0.5 + 0.5 * cos(qa - 2.8));
  float band = smoothstep(rh * 1.3, rh * 1.9, rq)
             * smoothstep(rh * 4.2, rh * 2.0, rq);
  float wind = qa * 1.5 - log(max(rq, 1e-3)) * 5.0 + t * 0.35;
  float streak = smoothstep(0.42, 0.85, fbm(vec2(wind, rq * 7.0 + uSeed)));
  float glow = band * side * (0.25 + 0.75 * streak);
  float heat = smoothstep(rh * 4.2, rh * 1.4, rq);
  vec3 discCol = mix(uColorB, uColorC, heat * 0.8);
  col += discCol * glow * 0.95 * uIntensity;
  // The light it throws into the haze on that side, very soft.
  col += uColorB * side * pow(smoothstep(rh * 9.0, rh * 1.2, r), 2.0) * 0.10 * uIntensity;

  // ── the horizon: nothing. A soft edge, never a line. ──
  col *= smoothstep(rh * 0.9, rh * 1.25, r);

  col *= 1.0 - smoothstep(0.45, 1.05, length(uv - 0.5)) * 0.55;
  fragColor = vec4(col, 1.0);
}
