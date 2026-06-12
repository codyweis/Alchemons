// AIR — GAS family. Slow vertical sky currents, drifting cloud veils, faint
// star anchors. Body only: the shared header/helpers are prepended by
// tool/build_dungeon_shaders.dart. Uses uColorA (zenith), uColorB (horizon),
// uColorC (cloud highlight).
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  // Base vertical sky gradient (zenith -> horizon).
  vec3 base = mix(uColorA, uColorB, smoothstep(0.0, 1.0, uv.y));

  // Two layers of drifting cloud veils.
  vec2 q1 = p * uNoiseScale + vec2(t * 0.06, -t * 0.10) + uSeed;
  vec2 q2 = p * uNoiseScale * 2.1 + vec2(-t * 0.12, -t * 0.20) + uSeed * 1.7;
  float clouds = fbm(q1) * 0.65 + fbm(q2) * 0.35;
  float veil = smoothstep(0.45, 0.95, clouds);
  vec3 col = mix(base, uColorC, veil * 0.55 * uIntensity);

  // Soft vertical light shafts.
  float shafts = 0.5 + 0.5 * sin(p.x * 6.0 + t * 0.4 + fbm(q1) * 3.0);
  col += uColorC * shafts * 0.04 * uIntensity;

  // Faint twinkling stars — soft round points, not filled cells.
  vec2 g = p * 80.0;
  vec2 cell = floor(g);
  vec2 fp = fract(g);
  float rnd = hash(cell + uSeed);
  float isStar = step(0.993, rnd);
  vec2 sp = vec2(hash(cell + 1.3), hash(cell + 2.7));
  float d = length(fp - sp);
  float star = isStar * smoothstep(0.10, 0.0, d);
  float tw = 0.5 + 0.5 * sin(t * 3.0 + rnd * 30.0);
  col += vec3(0.8, 0.85, 1.0) * star * tw * 0.5 * (1.0 - uv.y * 0.4);

  fragColor = vec4(col, 1.0);
}
