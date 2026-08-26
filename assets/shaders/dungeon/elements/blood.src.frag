// BLOOD — Hemavorn, the Sanguine Orrery. The planet runs on a four-phase
// pulse, so the background BEATS: a systolic surge washes outward, the field
// brightens with it, and thick vessels swell and subside. The vessels are
// deliberately unlike Lightning's veins — slow, smooth, warm and thick, with
// no flicker and no forking filaments, because the two would otherwise be the
// same effect twice. uColorA venous dark, uColorB arterial red,
// uColorC oxygen bright.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // THE BEAT — one cycle, with a sharp systole and a long slack diastole,
  // shaped so it lands like a heartbeat rather than a sine wave.
  float cyc = fract(t * 0.32);
  float beat = exp(-cyc * 7.0) + 0.55 * exp(-fract(cyc + 0.86) * 11.0);

  vec3 col = mix(uColorA, uColorB * 0.42, smoothstep(1.1, 0.0, uv.y));

  // Vessels: thick smooth tubes, warped slowly. Wide smoothstep bands, not
  // ridged filaments — the difference from Lightning is the WIDTH and the
  // absence of any high-frequency flicker.
  vec2 vq = p * uNoiseScale * 1.1 + uSeed;
  vq += vec2(fbm(vq * 0.7), fbm(vq.yx * 0.7 + 4.0)) * 1.1;
  float field = fbm(vq);
  // Two nested bands give a dark wall and a brighter lumen inside it.
  float wall = smoothstep(0.20, 0.10, abs(field - 0.5));
  float lumen = smoothstep(0.10, 0.02, abs(field - 0.5));
  col = mix(col, uColorB * 0.8, wall * 0.55);
  col = mix(col, uColorB * 1.35, lumen * (0.5 + 0.5 * beat));

  // The surge itself: a wave travelling out from the heart on every beat.
  vec2 heart = vec2(0.5 * aspect, 0.5);
  float r = length(p - heart);
  float wave = smoothstep(0.10, 0.0, abs(r - cyc * 1.4)) * (1.0 - cyc);
  col += uColorC * wave * 0.35 * uIntensity;

  // Whole-field flush — the room itself pinks up as the pressure arrives.
  col += uColorB * beat * 0.14 * uIntensity;

  // Corpuscles carried along, faster while the pressure is high.
  vec2 gg = vec2(p.x - t * 0.05, p.y + sin(t * 0.4 + p.x * 3.0) * 0.03) * 32.0;
  vec2 cc = floor(gg);
  float rr = hash(cc + uSeed);
  float dd = length(fract(gg) - vec2(hash(cc + 3.9), hash(cc + 8.4)));
  col += uColorC * step(0.980, rr) * smoothstep(0.09, 0.0, dd)
       * (0.35 + 0.65 * beat) * 0.4;

  // Tight vignette — you are inside something.
  col *= 1.0 - smoothstep(0.42, 1.0, length(uv - 0.5)) * 0.52;
  fragColor = vec4(col, 1.0);
}
