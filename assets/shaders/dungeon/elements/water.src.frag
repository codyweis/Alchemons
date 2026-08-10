// WATER — Mirror-Tide Temple. A drowned hall seen from beneath the surface:
// god-rays wavering down, a caustic web playing over everything, silt veils
// drifting sideways and slow bubbles climbing. Body only: the shared
// header/helpers are prepended by tool/build_dungeon_shaders.dart. Uses
// uColorA (abyss), uColorB (deep teal), uColorC (caustic highlight).
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Depth gradient — dark abyss above (the ceiling of a drowned hall),
  // warming faintly toward the lit floor.
  vec3 base = mix(uColorA, uColorB, smoothstep(0.1, 1.0, uv.y));

  // Silt veils crawling sideways.
  vec2 q1 = p * uNoiseScale + vec2(t * 0.10, t * 0.02) + uSeed;
  vec2 q2 = p * uNoiseScale * 2.0 + vec2(-t * 0.06, t * 0.04) + uSeed * 1.7;
  float silt = fbm(q1) * 0.6 + fbm(q2) * 0.4;
  vec3 col = mix(base, uColorB * 1.2, smoothstep(0.5, 0.95, silt) * 0.35);

  // The caustic web: two ridged noise fields beating against each other —
  // bright filaments that never sit still.
  vec2 cuv = p * uNoiseScale * 2.6;
  float c1 = 1.0 - abs(2.0 * noise(cuv + vec2(t * 0.22, t * 0.13)) - 1.0);
  float c2 = 1.0 - abs(2.0 * noise(cuv * 1.3 - vec2(t * 0.17, t * 0.21)) - 1.0);
  float caustic = pow(c1 * c2, 3.0);
  col += uColorC * caustic * 0.30 * uIntensity * (0.4 + 0.6 * uv.y);

  // God-rays: slow diagonal shafts from the surface far above.
  float ray = 0.5 + 0.5 * sin(p.x * 4.0 - uv.y * 1.5 + t * 0.3 + fbm(q1) * 2.0);
  col += uColorC * pow(ray, 3.0) * 0.07 * uIntensity * (1.0 - uv.y * 0.6);

  // Slow bubbles climbing in two depth layers.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 22.0 + fl * 18.0;
    float rise = t * (0.04 + fl * 0.03);
    vec2 g = vec2(p.x, p.y + rise) * scale;
    vec2 cell = floor(g);
    vec2 fp = fract(g);
    float rnd = hash(cell + uSeed + fl * 5.1);
    float isBubble = step(0.988, rnd);
    vec2 sp = vec2(hash(cell + 1.3), hash(cell + 2.7));
    sp.x += sin(t * 1.6 + rnd * 16.0) * 0.10;
    float d = length(fp - sp);
    float ring = smoothstep(0.10, 0.05, d) - smoothstep(0.05, 0.0, d) * 0.55;
    col += uColorC * isBubble * max(ring, 0.0) * (0.30 + 0.2 * fl) * uIntensity;
  }

  // Abyssal vignette pressing in from the top.
  col *= 1.0 - smoothstep(0.0, 0.4, 0.4 - uv.y) * 0.4;

  fragColor = vec4(col, 1.0);
}
