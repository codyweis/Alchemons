// DUST — Cindrath, the Ruins of Time. A buried city under a dry sky: the air
// is full of suspended grit lying in horizontal strata, the light is bleached
// and flat, and sheets of wind-driven dust cross the frame. Everything is
// LAYERED, because the whole planet is about what is buried under what.
// uColorA buried dark, uColorB ochre, uColorC bleached bone.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Bleached above, buried below — the horizon of a half-excavated city.
  vec3 col = mix(uColorB, uColorA, smoothstep(0.1, 1.0, uv.y));

  // STRATA. Sharp horizontal banding is the signature: each layer is a
  // different age of dust, and the quantisation makes the boundaries read as
  // deposition lines rather than as noise.
  float depth = uv.y * 7.0 + fbm(vec2(p.x * 1.2, uv.y * 2.0)) * 1.2;
  float band = floor(depth);
  float shade = 0.78 + 0.30 * hash(vec2(band, 3.0));
  col *= shade;
  // A thin bright line at each boundary — the seam between two burials.
  col += uColorC * smoothstep(0.06, 0.0, abs(fract(depth) - 0.5) - 0.44) * 0.10;

  // Wind sheets crossing left to right, dragging grit with them.
  float sheet = fbm(vec2(p.x * 1.8 - t * 0.35, p.y * 4.5) * uNoiseScale * 0.6);
  col = mix(col, uColorC * 0.8, smoothstep(0.55, 0.95, sheet) * 0.28);

  // Suspended grit — dense, fine, and it drifts sideways rather than falling,
  // because this air never settles.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 50.0 + fl * 34.0;
    vec2 gg = vec2(p.x - t * (0.10 + fl * 0.07), p.y + t * 0.01) * scale;
    vec2 cc = floor(gg);
    float rr = hash(cc + uSeed + fl * 3.3);
    float dd = length(fract(gg) - vec2(hash(cc + 1.9), hash(cc + 6.4)));
    col += uColorC * step(0.972, rr) * smoothstep(0.11, 0.0, dd)
         * (0.22 - fl * 0.08) * uIntensity;
  }

  // Dry haze washing the whole frame out — this planet has no wet colour.
  col = mix(col, uColorC, 0.06);
  col *= 1.0 - smoothstep(0.55, 1.05, length(uv - 0.5)) * 0.38;
  fragColor = vec4(col, 1.0);
}
