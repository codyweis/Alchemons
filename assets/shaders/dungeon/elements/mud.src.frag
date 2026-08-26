// MUD — Mireholm, the Sinking Altar. Wet, heavy and SLOW. The fen is mostly
// standing water under a low mist, so the motion here is sluggish surface
// drift and the occasional gout of swamp gas — never a flow and never a
// flicker (§5.5: nothing like Steam's tile floods). uColorA peat dark,
// uColorB silt brown, uColorC pale mist.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  vec3 col = mix(uColorA, uColorB, smoothstep(1.1, 0.1, uv.y));

  // Standing water: two very slow counter-drifting sheets, warped into each
  // other so the surface stirs without ever appearing to travel.
  vec2 w1 = p * uNoiseScale * 1.4 + vec2(t * 0.035, t * 0.012);
  vec2 w2 = p * uNoiseScale * 0.9 - vec2(t * 0.022, t * 0.008) + 17.0;
  float sheet = fbm(w1 + fbm(w2) * 0.8);
  col = mix(col, uColorB * 1.25, smoothstep(0.45, 0.85, sheet) * 0.42);

  // Silt suspended in it — darker blotches that make the water look thick.
  col *= 1.0 - smoothstep(0.55, 0.9, fbm(p * uNoiseScale * 2.6 + 41.0)) * 0.3;

  // Swamp gas: a slow gout that swells and releases. Low frequency, so the
  // fen feels like it is breathing rather than fizzing.
  vec2 gg = vec2(p.x, p.y + t * 0.04) * 18.0;
  vec2 cc = floor(gg);
  float rr = hash(cc + uSeed);
  float phase = fract(t * 0.18 + rr);
  float dd = length(fract(gg) - vec2(hash(cc + 2.9), hash(cc + 7.3)));
  float gout = step(0.982, rr) * smoothstep(0.02 + phase * 0.08, 0.0, dd)
             * (1.0 - phase);
  col += uColorC * gout * 0.4;

  // Ground mist lying ON the water — a flat band low in the frame, drifting
  // sideways. This is the only fast-ish motion, and it is still gentle.
  float mist = fbm(vec2(p.x * 1.5 - t * 0.09, p.y * 5.0) + 63.0);
  col = mix(col, uColorC, smoothstep(0.5, 0.95, mist)
                          * smoothstep(0.45, 1.0, uv.y) * 0.3);

  col *= 1.0 - smoothstep(0.5, 1.0, length(uv - 0.5)) * 0.45;
  fragColor = vec4(col, 1.0);
}
