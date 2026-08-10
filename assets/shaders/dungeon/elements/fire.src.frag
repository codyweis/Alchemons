// FIRE — Cinder Cathedral. A soot-black vault lit from below: hearth-light
// breathing on the horizon, smoke veils crawling upward, and slow embers
// rising like a reversed snowfall. Body only: the shared header/helpers are
// prepended by tool/build_dungeon_shaders.dart. Uses uColorA (soot vault),
// uColorB (ember mid), uColorC (flame highlight).
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Base vault gradient — dark zenith, warm hearth-light pooling low.
  vec3 base = mix(uColorA, uColorB, smoothstep(0.25, 1.05, uv.y));

  // The hearth-light breathes: a slow pulse swelling from the floor line.
  float breathe = 0.5 + 0.5 * sin(t * 0.8 + fbm(vec2(t * 0.15, uSeed)) * 2.0);
  base += uColorB * smoothstep(0.55, 1.0, uv.y) * breathe * 0.18;

  // Two layers of smoke veils climbing the vault (note +t on y: upward).
  vec2 q1 = p * uNoiseScale + vec2(t * 0.04, t * 0.12) + uSeed;
  vec2 q2 = p * uNoiseScale * 2.2 + vec2(-t * 0.07, t * 0.22) + uSeed * 1.7;
  float smoke = fbm(q1) * 0.6 + fbm(q2) * 0.4;
  float veil = smoothstep(0.5, 0.95, smoke);
  // Smoke darkens the warm base near the floor, glows faintly where thin.
  vec3 col = mix(base, uColorA * 0.8, veil * 0.5);
  col += uColorC * smoothstep(0.62, 0.92, smoke) * 0.06 * uIntensity;

  // Candle-glow shafts: soft warm columns wavering with the smoke.
  float shafts = 0.5 + 0.5 * sin(p.x * 5.0 - t * 0.3 + fbm(q1) * 2.6);
  col += uColorC * shafts * 0.035 * uIntensity * smoothstep(0.35, 1.0, uv.y);

  // Rising embers — soft round sparks drifting up through the dark.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 26.0 + fl * 22.0;
    float rise = t * (0.05 + fl * 0.035);
    vec2 g = vec2(p.x, p.y + rise) * scale;
    vec2 cell = floor(g);
    vec2 fp = fract(g);
    float rnd = hash(cell + uSeed + fl * 7.3);
    float isEmber = step(0.986, rnd);
    vec2 sp = vec2(hash(cell + 1.3), hash(cell + 2.7));
    // Embers sway as they climb.
    sp.x += sin(t * 2.0 + rnd * 20.0) * 0.12;
    float d = length(fp - sp);
    float ember = isEmber * smoothstep(0.12, 0.0, d);
    float flicker = 0.55 + 0.45 * sin(t * 6.0 + rnd * 40.0);
    vec3 emberCol = mix(uColorC, vec3(1.0, 0.85, 0.6), rnd * 0.5);
    col += emberCol * ember * flicker * (0.35 + 0.25 * fl) * uIntensity;
  }

  // Vault vignette: the high stone swallows light.
  col *= 1.0 - smoothstep(0.0, 0.45, 0.45 - uv.y) * 0.35;

  fragColor = vec4(col, 1.0);
}
