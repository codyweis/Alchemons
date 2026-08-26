// SPIRIT — Requia, the Echo Grave. The planet's whole idea is one place read
// twice, so the background is DOUBLED: the same field sampled at two offsets
// and laid over itself, one lagging the other like an afterimage. Wisps drift
// through it and a cold veil breathes across the frame. Pale and weightless —
// nothing here is solid. uColorA grave dark, uColorB spectral cyan,
// uColorC wisp white.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  vec3 col = mix(uColorA, uColorB * 0.4, smoothstep(1.1, 0.0, uv.y));

  // THE TWO WORLDS. One field, sampled twice with a small spatial and
  // temporal offset. Where they agree the air is quiet; where they disagree
  // you get the ghost fringe that gives the planet its look.
  vec2 q = p * uNoiseScale * 1.5 + vec2(t * 0.05, -t * 0.03);
  float living = fbm(q);
  float ghost = fbm(q + vec2(0.09, -0.05));
  col = mix(col, uColorB, smoothstep(0.45, 0.85, living) * 0.34);
  // The lagging copy is written as a cold rim, not a second cloud.
  col += uColorC * smoothstep(0.05, 0.0, abs(living - ghost) - 0.03) * 0.22;

  // A veil breathing across the whole frame — the grave inhaling.
  float breath = 0.5 + 0.5 * sin(t * 0.5);
  col = mix(col, uColorB * 0.9, smoothstep(0.6, 1.0, fbm(q * 0.5 + 29.0))
                                * breath * 0.2);

  // Wisps: they rise, wander, and fade in and out of existence entirely.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 20.0 + fl * 16.0;
    vec2 gg = vec2(p.x + sin(t * 0.6 + fl * 3.0 + p.y * 4.0) * 0.07,
                   p.y - t * (0.05 + fl * 0.035)) * scale;
    vec2 cc = floor(gg);
    float rr = hash(cc + uSeed + fl * 8.2);
    float dd = length(fract(gg) - vec2(hash(cc + 4.1), hash(cc + 9.3)));
    // Presence comes and goes on its own slow cycle — a wisp is not always
    // there, which is what separates these from Lightning's steady motes.
    float here = smoothstep(0.35, 0.9, sin(t * 0.7 + rr * 18.0) * 0.5 + 0.5);
    col += mix(uColorB, uColorC, fl) * step(0.978, rr)
         * smoothstep(0.13, 0.0, dd) * here * 0.45 * uIntensity;
  }

  col *= 1.0 - smoothstep(0.5, 1.0, length(uv - 0.5)) * 0.44;
  fragColor = vec4(col, 1.0);
}
