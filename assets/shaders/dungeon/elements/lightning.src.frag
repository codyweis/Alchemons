// LIGHTNING — Voltara, the Storm Circuit. A living circuit seen from inside:
// a dark charged sky veined with branching electricity, a low brass-and-blue
// glow, intermittent sheet-lightning flashes, and a fine drift of charge motes
// rising through it. Body only: the shared header/helpers are prepended by
// tool/build_dungeon_shaders.dart. Uses uColorA (packed storm-dark), uColorB
// (charged blue), uColorC (arc-white / brass highlight).
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Charged sky — darkest low, a cold blue charge gathering toward the top.
  vec3 base = mix(uColorA, uColorB, smoothstep(0.0, 1.15, uv.y));

  // Slow rolling storm haze.
  vec2 q1 = p * uNoiseScale * 1.3 + vec2(t * 0.05, -t * 0.03) + uSeed;
  float haze = fbm(q1);
  vec3 col = mix(base, uColorB * 1.2, smoothstep(0.5, 0.95, haze) * 0.28);

  // Branching electric veins: distort space with fbm, then carve thin glowing
  // filaments where a ridged-noise field crosses zero. Two octaves of veins so
  // the network forks and rejoins like a real arc.
  float vein = 0.0;
  for (int i = 0; i < 2; i++) {
    float fi = float(i);
    vec2 dp = p * (uNoiseScale * (1.1 + fi * 0.9));
    dp += vec2(fbm(dp + uSeed + fi * 3.1), fbm(dp.yx - uSeed - fi * 2.3)) * 1.3;
    float ridge = abs(fbm(dp + vec2(0.0, t * 0.12)) - 0.5);
    // thin bright core where the ridge is near zero
    vein += smoothstep(0.045, 0.0, ridge) * (0.7 - fi * 0.25);
  }
  // Veins flicker — electricity is never steady.
  float flick = 0.6 + 0.4 * sin(t * 9.0 + p.x * 6.0)
                    * sin(t * 5.0 + p.y * 4.0);
  col += uColorC * vein * flick * (0.5 + 0.5 * uIntensity);

  // Sheet-lightning flashes: rare, brief, whole-frame brightening.
  float strike = fract(t * 0.23);
  float flash = exp(-strike * 14.0) + 0.55 * exp(-fract(t * 0.37) * 22.0);
  col += uColorC * flash * 0.14 * uIntensity;

  // Charge motes rising and shimmering.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 30.0 + fl * 20.0;
    float rise = t * (0.06 + fl * 0.04);
    vec2 gg = vec2(p.x, p.y + rise) * scale;
    vec2 cc = floor(gg);
    vec2 ff = fract(gg);
    float rr = hash(cc + uSeed + fl * 7.3);
    float isMote = step(0.99, rr);
    vec2 mp = vec2(hash(cc + 1.7), hash(cc + 3.1));
    mp.x += sin(t * 2.0 + rr * 18.0) * 0.1;
    float dd = length(ff - mp);
    float tw = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(t * 3.0 + rr * 25.0), 3.0);
    float mote = isMote * smoothstep(0.10, 0.0, dd) * tw;
    col += mix(uColorB, uColorC, fl) * mote * (0.22 + 0.12 * fl) * uIntensity;
  }

  // A faint vault vignette so the grid reads as enclosed.
  col *= 1.0 - smoothstep(0.55, 1.0, length(uv - 0.5)) * 0.35;

  fragColor = vec4(col, 1.0);
}
