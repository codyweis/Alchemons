// POISON — Toxivyre, the Venom Monastery. Contagion you can SEE hanging in
// the air: heavy miasma settling into flat banks the way cold gas does, spore
// motes tumbling slowly through it, and a faint bubbling where something is
// rotting below. Sickly and STILL — the opposite of Lightning's flicker and
// Lava's flow. uColorA rot-dark, uColorB venous green, uColorC spore pallor.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Gas is heavy: darkest and thickest at the floor, thinning upward.
  vec3 col = mix(uColorB, uColorA, smoothstep(0.15, 1.0, uv.y));

  // Miasma banks — deliberately FLATTENED on y so the fog lies in strata
  // instead of billowing. Slow enough to look like it is settling, not moving.
  vec2 q = vec2(p.x * 0.8, p.y * 3.4) * uNoiseScale + vec2(t * 0.06, -t * 0.02);
  float bank = fbm(q);
  col = mix(col, uColorB, smoothstep(0.42, 0.78, bank) * 0.5);

  // A second, thinner veil drifting the other way, so the air has depth.
  float veil = fbm(vec2(p.x * 1.1 - t * 0.04, p.y * 2.2) * uNoiseScale + 21.0);
  col = mix(col, uColorC * 0.55, smoothstep(0.55, 0.92, veil) * 0.18);

  // Rot bubbles rising from the floor: they swell, then are gone.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 22.0 + fl * 14.0;
    vec2 gg = vec2(p.x, p.y + t * (0.05 + fl * 0.03)) * scale;
    vec2 cc = floor(gg);
    float rr = hash(cc + uSeed + fl * 6.1);
    float isBub = step(0.986, rr);
    vec2 mp = vec2(hash(cc + 1.3), hash(cc + 4.7));
    float dd = length(fract(gg) - mp);
    // Swell and pop rather than twinkle.
    float swell = fract(t * 0.35 + rr);
    float rad = 0.02 + swell * 0.07;
    float ring = smoothstep(rad, rad * 0.55, dd) * (1.0 - swell);
    // Only near the floor — gas does not bubble out of the ceiling.
    col += uColorC * isBub * ring * smoothstep(0.25, 1.0, uv.y) * 0.5;
  }

  // Spore motes: slow, tumbling, and they FALL. Nothing here rises cleanly.
  vec2 gg = vec2(p.x + sin(t * 0.4 + p.y * 3.0) * 0.05, p.y - t * 0.03) * 34.0;
  vec2 cc = floor(gg);
  float rr = hash(cc + uSeed);
  float dd = length(fract(gg) - vec2(hash(cc + 3.7), hash(cc + 8.1)));
  col += uColorC * step(0.985, rr) * smoothstep(0.10, 0.0, dd) * 0.35 * uIntensity;

  col *= 1.0 - smoothstep(0.5, 1.0, length(uv - 0.5)) * 0.42;
  fragColor = vec4(col, 1.0);
}
