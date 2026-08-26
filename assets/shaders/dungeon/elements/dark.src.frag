// DARK — Nythralor, the Eclipse Vault. An eclipse held at the moment of
// totality: a black disc with a corona burning around its rim, shadow bands
// rippling across everything, and the few stars that come out when the light
// goes. Mostly EMPTY on purpose — the planet is about what is not there, and
// a busy background would argue with that. uColorA void, uColorB umbral
// indigo, uColorC corona white.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  vec3 col = uColorA;

  // Stars, sparse and cold — only visible because the light is blocked.
  vec2 sg = p * 40.0;
  vec2 sc = floor(sg);
  float sr = hash(sc + uSeed);
  float sd = length(fract(sg) - vec2(hash(sc + 5.1), hash(sc + 8.6)));
  col += uColorC * step(0.986, sr) * smoothstep(0.08, 0.0, sd)
       * (0.5 + 0.5 * sin(t * 1.1 + sr * 30.0)) * 0.45;

  // THE ECLIPSE. A disc high in the frame, and the corona is a thin ring just
  // outside its edge — narrow, so it reads as light escaping past an obstacle
  // rather than as a glow source.
  vec2 c = vec2(0.5 * aspect, 0.34);
  float r = length(p - c);
  float disc = 0.20;
  float ring = smoothstep(0.055, 0.0, abs(r - disc));
  // The corona is uneven and it seethes.
  float seethe = 0.7 + 0.6 * fbm(vec2(atan(p.y - c.y, p.x - c.x) * 3.0, t * 0.4));
  col += uColorC * ring * seethe * 0.75 * uIntensity;
  // Faint outer bloom, falling off fast.
  col += uColorB * smoothstep(disc * 2.6, disc, r) * 0.28;
  // The disc itself takes light AWAY — nothing shows through it.
  col *= 1.0 - smoothstep(disc + 0.012, disc - 0.012, r) * 0.96;

  // SHADOW BANDS: the fine parallel ripples that cross the ground at
  // totality. Thin, fast, and low contrast.
  float bands = sin((p.x * 0.7 + p.y * 1.6) * 55.0 + t * 2.2);
  col += uColorB * smoothstep(0.85, 1.0, bands) * 0.06;

  // Umbral haze pooling at the bottom of the frame.
  col = mix(col, uColorB * 0.6,
            smoothstep(0.55, 1.0, uv.y) * fbm(p * uNoiseScale + 47.0) * 0.35);

  col *= 1.0 - smoothstep(0.45, 1.0, length(uv - 0.5)) * 0.5;
  fragColor = vec4(col, 1.0);
}
