// DARK — Nythralor, the Eclipse Vault, hung in front of a BLACK HOLE.
// (2026-09-25, from the author: the vault should read as a black-hole
// mystical level.) The eclipse the whole planet is named for is not the moon
// over a sun here — it is the event horizon itself, and everything the vault
// is built out of is falling toward it.
//
// Four layers, all cheap and all analytic:
//   · the starfield, LENSED — each star is looked up where the hole's gravity
//     bends its light from, so stars crowd into a ring just outside it;
//   · the ACCRETION DISC, tilted almost edge-on, streaked by a spiral of
//     noise that turns with time, brighter on the side swinging toward you;
//   · the BACK of the disc, bent up over the hole and under it by the lens —
//     the arch that makes a black hole read as one and not as a dark planet;
//   · the PHOTON RING, a hairline of light at the edge, and inside it nothing.
// Mostly black on purpose: the author asked for the darkest planet in the
// set, and a black hole is the one thing in the sky darker than the sky.
//
// uColorA void · uColorB the disc's cool outer violet · uColorC its hot
// inner light.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Hung high and to one side, like a moon: the camera sits on the party,
  // so a hole at the centre of the frame would always be over their heads.
  vec2 c = vec2(0.76 * aspect, 0.24);
  vec2 d = p - c;
  float r = length(d);
  float rh = 0.12;                  // the event horizon
  float ang = atan(d.y, d.x);

  vec3 col = uColorA;

  // ── a faint nebula so the void has depth, pulled into a swirl ──
  float swirl = ang + 1.4 / (r + 0.25) + t * 0.05;
  vec2 np = vec2(cos(swirl), sin(swirl)) * r * uNoiseScale + uSeed;
  col += uColorB * fbm(np * 1.3) * 0.16 * smoothstep(1.2, 0.2, r);

  // ── lensed stars ──
  // Light passing the hole at distance r comes from farther out.
  vec2 sp = c + d * (1.0 + (rh * rh * 1.6) / max(r * r, 1e-4));
  vec2 sg = sp * 46.0;
  vec2 sc = floor(sg);
  float sr = hash(sc + uSeed);
  float sd = length(fract(sg) - vec2(hash(sc + 5.1), hash(sc + 8.6)));
  float star = step(0.982, sr) * smoothstep(0.09, 0.0, sd)
             * (0.55 + 0.45 * sin(t * 1.3 + sr * 40.0));
  col += mix(uColorC, vec3(1.0), 0.5) * star * 0.55;

  // ── the accretion disc, tilted ──
  float tilt = 0.24;
  vec2 q = vec2(d.x, d.y / tilt);
  float rq = length(q);
  float inner = rh * 1.55, outer = rh * 4.6;
  float band = smoothstep(inner * 0.92, inner * 1.12, rq)
             * smoothstep(outer, outer * 0.55, rq);
  float disc = 0.0;
  vec3 discCol = vec3(0.0);
  if (band > 0.001) {
    float qa = atan(q.y, q.x);
    // Streaks wound into a spiral that turns, fastest near the inside.
    float wind = qa * 2.0 - log(rq) * 7.0 + t * (0.9 + 0.5 * inner / rq);
    float streak = fbm(vec2(wind, rq * 9.0 + uSeed));
    streak = 0.35 + 0.95 * smoothstep(0.35, 0.8, streak);
    // Doppler: the side coming toward you is brighter.
    float beam = 0.55 + 0.45 * cos(qa + 0.4);
    float heat = smoothstep(outer, inner, rq);   // 1 at the inner edge
    disc = band * streak * beam * (0.25 + 0.95 * heat);
    discCol = mix(uColorB, uColorC, heat);
    discCol = mix(discCol, vec3(1.0), heat * heat * 0.35);
  }
  // Only the FRONT half of the disc crosses in front of the hole.
  bool front = d.y > 0.0;

  // ── the back of the disc, lensed up over the hole and down under it ──
  float arcR = rh * 1.42;
  float arc = smoothstep(rh * 0.34, 0.0, abs(r - arcR));
  float arcNoise = 0.55 + 0.6 * fbm(vec2(ang * 3.0 - t * 0.7, uSeed + 3.0));
  // Brightest over the top, thinner beneath.
  float arcShape = mix(0.35, 1.0, smoothstep(0.3, -0.9, d.y / max(r, 1e-4)));
  vec3 arcCol = mix(uColorC, vec3(1.0), 0.25);

  // Behind the hole: the back disc and the arch.
  if (!front) col += discCol * disc * uIntensity;
  col += arcCol * arc * arcShape * arcNoise * 0.85 * uIntensity;

  // ── the photon ring and the horizon ──
  float ring = smoothstep(rh * 0.045, 0.0, abs(r - rh * 1.02));
  col += mix(uColorC, vec3(1.0), 0.6) * ring * 0.7 * uIntensity;
  col *= smoothstep(rh * 0.97, rh * 1.02, r);   // inside: nothing at all

  // The near half of the disc, in front of everything.
  if (front) col += discCol * disc * uIntensity;

  // A soft glow the disc throws round itself, falling off fast.
  col += uColorB * smoothstep(outer * 1.9, rh, rq) * 0.10 * uIntensity;

  // Vignette.
  col *= 1.0 - smoothstep(0.45, 1.05, length(uv - 0.5)) * 0.55;
  fragColor = vec4(col, 1.0);
}
