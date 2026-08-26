// LIGHT — the Beacon Archive. Volumetric god-rays coming down through a high
// clerestory, with dust turning in them. The ONE rule this shader exists to
// obey (§5.5): it must read nothing like Lightning. So every edge here is
// soft, every cone is wide and smooth, nothing branches, nothing flickers,
// and the palette is warm rather than electric. uColorA hall shadow,
// uColorB warm stone, uColorC beam white.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  vec3 col = mix(uColorB * 0.35, uColorA, smoothstep(0.0, 1.15, uv.y));

  // GOD-RAYS. Cones spreading as they descend from a source above the frame,
  // each one soft-edged. Rays SWEEP very slowly, because in this dungeon the
  // light is something the player aims.
  vec2 src = vec2(0.5 * aspect, -0.35);
  vec2 d = p - src;
  float ang = atan(d.x, d.y);
  float dist = length(d);
  float rays = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float centre = -0.42 + fi * 0.42 + sin(t * 0.12 + fi * 2.1) * 0.06;
    float width = 0.13 + 0.03 * fi;
    // pow() rather than smoothstep on a hard edge: the falloff has no corner.
    rays += pow(max(0.0, 1.0 - abs(ang - centre) / width), 2.6)
          * (0.9 - fi * 0.18);
  }
  // The beam thins with distance from the window, never cuts off.
  float reach = exp(-dist * 0.85);
  col += uColorC * rays * reach * 0.55 * uIntensity;

  // Dust suspended IN the beams — visible only where the light is, which is
  // what makes the rays read as volume rather than as painted stripes.
  vec2 gg = vec2(p.x + sin(t * 0.3 + p.y * 2.0) * 0.04, p.y - t * 0.02) * 40.0;
  vec2 cc = floor(gg);
  float rr = hash(cc + uSeed);
  float dd = length(fract(gg) - vec2(hash(cc + 2.7), hash(cc + 6.9)));
  float mote = step(0.972, rr) * smoothstep(0.10, 0.0, dd);
  col += uColorC * mote * (0.25 + rays * 1.6) * reach * 0.5;

  // A slow warm haze filling the hall between the beams.
  col = mix(col, uColorB,
            fbm(p * uNoiseScale * 0.9 + vec2(t * 0.03, 0.0)) * 0.16);

  // Soft, generous vignette — a hall, not a tunnel.
  col *= 1.0 - smoothstep(0.65, 1.15, length(uv - vec2(0.5, 0.45))) * 0.3;
  fragColor = vec4(col, 1.0);
}
