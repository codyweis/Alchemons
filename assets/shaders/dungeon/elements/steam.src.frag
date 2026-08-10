// STEAM — Vaporis, the Pressure Cathedral. The inside of a great boiler-works:
// rising columns of hot mist, a heavy iron gloom, pressure-shimmer warping the
// air, furnace-light pooling low, and a slow tidal pulse like the breath of the
// machine. Body only: the shared header/helpers are prepended by
// tool/build_dungeon_shaders.dart. Uses uColorA (iron dark), uColorB (steam
// grey-white), uColorC (furnace ember).
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Iron gloom — darkest at the top girders, a faint furnace warmth pooling low.
  vec3 base = mix(uColorA, uColorA * 1.35, smoothstep(0.0, 1.1, uv.y));
  base = mix(base, uColorC * 0.5, smoothstep(0.78, 1.0, uv.y) * 0.35);

  // Pressure shimmer: warp the sampling so the mist columns waver like heat-haze.
  float shimmer = fbm(p * uNoiseScale * 2.0 + vec2(0.0, -t * 0.4));
  vec2 warp = vec2(shimmer - 0.5, 0.0) * 0.08;

  // Rising steam columns — vertical fbm scrolling upward, brighter where dense.
  vec2 q = (p + warp) * vec2(uNoiseScale * 1.1, uNoiseScale * 0.7)
           + vec2(t * 0.03, -t * 0.5);
  float steam = fbm(q);
  steam = smoothstep(0.45, 0.95, steam);
  vec3 col = mix(base, uColorB, steam * 0.55);

  // A second, slower veil for depth.
  float veil = fbm((p + warp) * uNoiseScale * 0.8 + vec2(-t * 0.02, -t * 0.22));
  col = mix(col, uColorB * 0.9, smoothstep(0.6, 1.0, veil) * 0.22);

  // The machine's breath: a slow brightness pulse across the whole frame.
  float breath = 0.5 + 0.5 * sin(t * 0.5);
  col += uColorB * breath * 0.04 * uIntensity;

  // Condensation droplets sliding down, catching furnace-light.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 26.0 + fl * 16.0;
    float fall = t * (0.05 + fl * 0.03);
    vec2 gg = vec2(p.x, p.y - fall) * scale;
    vec2 cc = floor(gg);
    vec2 ff = fract(gg);
    float rr = hash(cc + uSeed + fl * 8.3);
    float isDrop = step(0.988, rr);
    vec2 dp = vec2(hash(cc + 1.9), hash(cc + 3.3));
    float dd = length(ff - dp);
    float drop = isDrop * smoothstep(0.10, 0.0, dd);
    col += mix(uColorB, uColorC, fl * 0.5) * drop * (0.2 + 0.1 * fl) * uIntensity;
  }

  // Furnace embers drifting up from below, fading as they rise.
  vec2 eg = p * 34.0 + vec2(sin(t * 0.6) * 0.4, t * 0.8);
  vec2 ec = floor(eg);
  vec2 ef = fract(eg);
  float er = hash(ec + uSeed + 5.1);
  float isEmber = step(0.992, er);
  float ed = length(ef - vec2(0.5));
  float ember = isEmber * smoothstep(0.12, 0.0, ed) * smoothstep(0.0, 0.6, uv.y);
  col += uColorC * ember * 0.5 * uIntensity;

  // Heavy vault vignette.
  col *= 1.0 - smoothstep(0.5, 1.0, length(uv - 0.5)) * 0.4;

  fragColor = vec4(col, 1.0);
}
