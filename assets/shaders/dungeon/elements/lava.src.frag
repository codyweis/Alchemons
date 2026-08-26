// LAVA — Magmora, the Molten Reliquary. A FOUNDRY, not a cathedral: this must
// read nothing like fire.frag's soft candlelight (§5.5 visual grammar rule).
// Everything here is horizontal and hard-edged — molten runnels crossing the
// dark in straight bands, a crusted basalt skin cracking over them, white-hot
// where the metal is thinnest, with heat shimmer above and sparks rising off
// the pour. uColorA basalt dark, uColorB molten orange, uColorC white-hot.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Heat shimmer: the whole field is sampled through a rising distortion, so
  // the runnels wobble the way air does over hot metal.
  float shim = fbm(vec2(p.x * 3.0, p.y * 6.0 - t * 0.5)) - 0.5;
  vec2 sp = p + vec2(shim * 0.02, 0.0);

  vec3 col = uColorA;

  // Three molten runnels crossing the frame. Straight lines, not plumes — the
  // works are plumbing, and plumbing is engineered.
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float yb = 0.24 + fi * 0.26;
    // A slow sag along the run so it is not a ruler-straight cut.
    float sag = (fbm(vec2(sp.x * 1.6 + fi * 5.0, fi * 2.0)) - 0.5) * 0.06;
    float d = abs(sp.y - (yb + sag));
    // Metal flows LEFT TO RIGHT along the line — the pour has a direction.
    float flow = fbm(vec2(sp.x * 3.5 - t * (0.55 + fi * 0.12), fi * 9.0));
    float body = smoothstep(0.055, 0.0, d);
    float core = smoothstep(0.016, 0.0, d);
    col = mix(col, uColorB, body * (0.55 + 0.45 * flow));
    col = mix(col, uColorC, core * (0.5 + 0.5 * flow) * uIntensity);
  }

  // Crusted skin: a dark cellular crazing laid OVER the glow, so the runnels
  // read as metal cooling rather than as light sources.
  float crust = fbm(sp * uNoiseScale * 3.2 + 11.0);
  col *= 1.0 - smoothstep(0.62, 0.86, crust) * 0.45;

  // Sparks off the pour — sparse, fast, and they rise then die.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 42.0 + fl * 26.0;
    vec2 gg = vec2(p.x, p.y + t * (0.30 + fl * 0.18)) * scale;
    vec2 cc = floor(gg);
    float rr = hash(cc + uSeed + fl * 4.7);
    float isSpark = step(0.988, rr);
    vec2 mp = vec2(hash(cc + 2.3), hash(cc + 5.9));
    float dd = length(fract(gg) - mp);
    float life = 0.5 + 0.5 * sin(t * 6.0 + rr * 30.0);
    col += uColorC * isSpark * smoothstep(0.08, 0.0, dd) * life * 0.5;
  }

  // The works are roofed — heavy vignette, heaviest at the top.
  col *= 1.0 - smoothstep(0.35, 1.0, length(uv - vec2(0.5, 0.62))) * 0.5;
  fragColor = vec4(col, 1.0);
}
