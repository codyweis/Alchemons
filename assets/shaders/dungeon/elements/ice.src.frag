// ICE — Glaceron, the Frozen Observatory. It is an OBSERVATORY: the sky is
// genuinely visible through the ice, so this is the only dungeon background
// with real stars in it. Over them, faceted ice refracts in hard straight
// planes (crystal, not cloud), a slow aurora sheet hangs high, and frost
// creeps in from the edges. uColorA night-dark, uColorB glacier blue,
// uColorC frost white.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  vec3 col = mix(uColorA, uColorB * 0.55, smoothstep(1.05, 0.0, uv.y));

  // STARS through the ice — fixed, faint, and they twinkle slowly. Sitting
  // under the refraction so they read as being beyond it.
  vec2 sg = p * 46.0;
  vec2 sc = floor(sg);
  float sr = hash(sc + uSeed * 0.5);
  float sd = length(fract(sg) - vec2(hash(sc + 6.2), hash(sc + 2.8)));
  float tw = 0.55 + 0.45 * sin(t * 1.4 + sr * 40.0);
  col += vec3(0.85, 0.92, 1.0) * step(0.977, sr)
       * smoothstep(0.09, 0.0, sd) * tw * 0.6;

  // Aurora: one broad sheet, high up, folding slowly. Kept smooth and wide so
  // it cannot be mistaken for Lightning's thin arcs.
  float fold = fbm(vec2(p.x * 1.2 + t * 0.05, p.y * 0.7)) - 0.5;
  float band = smoothstep(0.30, 0.0, abs(uv.y - (0.26 + fold * 0.22)));
  col += mix(uColorB, uColorC, 0.35) * band * 0.30 * uIntensity;

  // Faceting: quantise the field into flat planes and light each one
  // differently, so the ice has hard straight edges rather than soft noise.
  vec2 fp = p * uNoiseScale * 1.6;
  vec2 cell = floor(fp + fbm(fp * 0.5 + uSeed) * 1.5);
  float facet = hash(cell + 13.0);
  // A sweep of light travelling across the facets — refraction moving.
  float sweep = 0.5 + 0.5 * sin(t * 0.5 + facet * 6.28 + p.x * 1.5);
  col = mix(col, uColorB * (0.7 + 0.6 * facet), 0.22);
  col += uColorC * pow(sweep, 6.0) * 0.16 * uIntensity;

  // Frost creeping in from every edge — thickest in the corners.
  float edge = max(abs(uv.x - 0.5), abs(uv.y - 0.5)) * 2.0;
  float crystal = fbm(p * uNoiseScale * 5.0 + 31.0);
  col += uColorC * smoothstep(0.72, 1.05, edge)
       * smoothstep(0.45, 0.85, crystal) * 0.5;

  col *= 1.0 - smoothstep(0.6, 1.0, length(uv - 0.5)) * 0.28;
  fragColor = vec4(col, 1.0);
}
