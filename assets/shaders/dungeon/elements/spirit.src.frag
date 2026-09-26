// SPIRIT — Requia, the Echo Grave, under a midnight that is not empty.
//
// MORE MYSTICAL (2026-09-25, from the author: "spirit's colors don't look
// mystical"). The first sky was fbm cloud in a greyed teal — an overcast
// afternoon over a muddy field. What hangs over the grave now is a midnight
// void, indigo at the zenith, with VEILS in it: slow curtains of spectral
// light, aqua turning to violet at their tops, that fold and drift like
// something breathing on the far side of the air. Faint, and mostly dark.
//
// The planet's idea — one place read twice — stays in the sky as the veils'
// AFTERIMAGE: every curtain is sampled twice, a moment apart, and the lagging
// copy is a thin pale rim along the first. Wisps still rise and wink out.
//
// uColorA the void · uColorB spectral aqua · uColorC the pale of a wisp.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Midnight: indigo overhead, the void toward the ground.
  vec3 violet = vec3(0.16, 0.10, 0.30);
  vec3 col = mix(uColorA, violet * 0.55, smoothstep(0.9, 0.0, uv.y));

  // A few cold stars in the dark between the veils.
  vec2 sg = p * 52.0;
  vec2 sc = floor(sg);
  float sr = hash(sc + uSeed);
  float sd = length(fract(sg) - vec2(hash(sc + 3.7), hash(sc + 6.1)));
  col += uColorC * step(0.988, sr) * smoothstep(0.08, 0.0, sd)
       * (0.5 + 0.5 * sin(t * 1.3 + sr * 30.0)) * 0.35;

  // THE VEILS. A curtain is a fold of light that hangs in x and fades in y:
  // noise along x picks where it hangs, a second slower noise bends it, and
  // it is brightest at its lower hem and fades up into violet.
  for (int k = 0; k < 2; k++) {
    float fk = float(k);
    float bend = fbm(vec2(p.x * 0.9 + fk * 7.0, t * 0.06 + fk * 3.0)) - 0.5;
    float x = p.x * (1.6 + fk * 0.9) + bend * 1.4 + t * (0.03 + fk * 0.02);
    float fold = fbm(vec2(x * 1.3, fk * 11.0 + t * 0.04));
    float fold2 = fbm(vec2((x + 0.03) * 1.3, fk * 11.0 + t * 0.04 - 0.06));
    // The hem waves along its length, so a curtain is a ribbon, not a bar.
    float hem = 0.44 + fk * 0.16 + bend * 0.22 + 0.05 * sin(x * 3.1 + t * 0.4);
    // Brightest at its hem, a soft edge below it, fading out upward.
    float drop = smoothstep(hem + 0.07, hem - 0.01, uv.y)
               * smoothstep(hem - 0.46, hem - 0.06, uv.y);
    // Fine vertical rays through it, the way a veil of light is combed.
    float rays = 0.55 + 0.45 * noise(vec2(x * 22.0, t * 0.15 + fk * 5.0));
    float curtain = smoothstep(0.42, 0.72, fold) * drop * rays;
    vec3 tint = mix(uColorB, violet * 2.2, smoothstep(hem, hem - 0.34, uv.y));
    col += tint * curtain * (0.55 - fk * 0.18) * uIntensity;
    // The afterimage: a thin pale rim where the lagging copy parts from it.
    col += uColorC * smoothstep(0.035, 0.0, abs(fold - fold2) - 0.012)
         * drop * 0.07 * uIntensity;
  }

  // Wisps: they rise, wander, and fade in and out of existence entirely.
  for (int layer = 0; layer < 2; layer++) {
    float fl = float(layer);
    float scale = 20.0 + fl * 16.0;
    vec2 gg = vec2(p.x + sin(t * 0.6 + fl * 3.0 + p.y * 4.0) * 0.07,
                   p.y - t * (0.05 + fl * 0.035)) * scale;
    vec2 cc = floor(gg);
    float rr = hash(cc + uSeed + fl * 8.2);
    float dd = length(fract(gg) - vec2(hash(cc + 4.1), hash(cc + 9.3)));
    float here = smoothstep(0.35, 0.9, sin(t * 0.7 + rr * 18.0) * 0.5 + 0.5);
    col += mix(uColorB, uColorC, fl) * step(0.978, rr)
         * smoothstep(0.13, 0.0, dd) * here * 0.45 * uIntensity;
  }

  col *= 1.0 - smoothstep(0.5, 1.0, length(uv - 0.5)) * 0.44;
  fragColor = vec4(col, 1.0);
}
