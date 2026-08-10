// EARTH — The Buried Giant. The inside of deep ground: sediment strata
// pressing down in slow bands, grave-dust sifting, buried crystal glinting,
// and a long seismic pulse rolling through everything like a sleeping
// heartbeat. Body only: the shared header/helpers are prepended by
// tool/build_dungeon_shaders.dart. Uses uColorA (packed dark earth),
// uColorB (strata mid), uColorC (bone-amber highlight).
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Depth gradient — darkest at the top (the weight of the world above),
  // warming faintly toward the amber-lit floor.
  vec3 base = mix(uColorA, uColorB, smoothstep(0.05, 1.0, uv.y));

  // Sediment strata: horizontal bands warped by noise, creeping almost
  // imperceptibly — the ages settling.
  float warp = fbm(p * uNoiseScale * 0.8 + vec2(t * 0.015, 0.0) + uSeed);
  float bands = 0.5 + 0.5 * sin((uv.y + warp * 0.18) * 26.0 + t * 0.05);
  vec3 col = mix(base, uColorB * 1.25, smoothstep(0.6, 0.95, bands) * 0.25);

  // Grave-dust veils drifting down and sideways.
  vec2 q1 = p * uNoiseScale * 1.6 + vec2(t * 0.05, -t * 0.06) + uSeed * 1.7;
  float dustVeil = fbm(q1);
  col = mix(col, uColorA * 0.85, smoothstep(0.55, 0.95, dustVeil) * 0.3);

  // The seismic pulse: a slow bright wave rolling up through the strata —
  // the giant's sleeping heartbeat.
  float pulsePos = fract(t * 0.05);
  float pulse = exp(-pow((uv.y - (1.0 - pulsePos)) * 9.0, 2.0));
  col += uColorC * pulse * 0.10 * uIntensity;

  // Buried crystal glints — sharp cold points in the dark.
  vec2 g = p * 60.0;
  vec2 cell = floor(g);
  vec2 fp = fract(g);
  float rnd = hash(cell + uSeed);
  float isGlint = step(0.992, rnd);
  vec2 sp = vec2(hash(cell + 1.3), hash(cell + 2.7));
  float d = length(fp - sp);
  float glint = isGlint * smoothstep(0.09, 0.0, d);
  float tw = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(t * 2.2 + rnd * 30.0), 3.0);
  col += vec3(0.72, 0.88, 0.85) * glint * tw * 0.35 * uIntensity;

  // Sifting dust motes, falling in two layers.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 24.0 + fl * 18.0;
    float fall = t * (0.03 + fl * 0.02);
    vec2 gg = vec2(p.x, p.y - fall) * scale;
    vec2 cc = floor(gg);
    vec2 ff = fract(gg);
    float rr = hash(cc + uSeed + fl * 9.7);
    float isMote = step(0.99, rr);
    vec2 mp = vec2(hash(cc + 1.3), hash(cc + 2.7));
    mp.x += sin(t * 1.2 + rr * 14.0) * 0.08;
    float dd = length(ff - mp);
    float mote = isMote * smoothstep(0.10, 0.0, dd);
    col += uColorC * mote * (0.18 + 0.12 * fl) * uIntensity;
  }

  // The weight of the earth pressing in from above.
  col *= 1.0 - smoothstep(0.0, 0.45, 0.45 - uv.y) * 0.45;

  fragColor = vec4(col, 1.0);
}
