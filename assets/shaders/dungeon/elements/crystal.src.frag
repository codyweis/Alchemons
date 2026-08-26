// CRYSTAL — Lumishara, the Prism Labyrinth. Seen from inside a cut stone:
// hard faceted planes, and light SPLIT into its colours along their edges.
// The dispersion is the signature and it belongs to no other planet; keep the
// geometry angular so it cannot be read as Water's caustics.
// uColorA stone dark, uColorB lattice violet, uColorC white refraction.
void main() {
  vec2 uv = dungeonUV();
  float aspect = uResolution.x / max(uResolution.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * uFlowSpeed;

  vec3 col = mix(uColorA, uColorB * 0.5, smoothstep(1.0, 0.0, uv.y));

  // Facets: quantised cells with straight boundaries. Each catches the light
  // differently, and the whole lattice turns very slowly.
  float ang = t * 0.06;
  mat2 rot = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));
  vec2 fp = rot * p * uNoiseScale * 2.0;
  vec2 cell = floor(fp);
  float face = hash(cell + uSeed);
  col = mix(col, uColorB * (0.5 + 0.9 * face), 0.3);

  // Facet EDGES, bright and hard — this is what makes it read as cut stone.
  vec2 f = fract(fp);
  float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
  col += uColorC * smoothstep(0.06, 0.0, edge) * 0.22;

  // DISPERSION. One travelling wavefront, sampled at three slightly different
  // offsets and written to r/g/b separately, so the light splits into a
  // spectrum exactly where it crosses an edge.
  float w = dot(p, vec2(0.8, 0.6)) * 3.0 - t * 0.7;
  float rr = pow(0.5 + 0.5 * sin(w), 22.0);
  float gg = pow(0.5 + 0.5 * sin(w - 0.22), 22.0);
  float bb = pow(0.5 + 0.5 * sin(w - 0.44), 22.0);
  col += vec3(rr, gg, bb) * (0.35 + 0.4 * face) * uIntensity;

  // Sharp specular glints where facets meet — brief, small, star-shaped.
  vec2 sg = fp * 1.5;
  vec2 sc = floor(sg);
  float sr = hash(sc + 9.4);
  vec2 d2 = abs(fract(sg) - vec2(hash(sc + 2.1), hash(sc + 5.6)));
  float star = smoothstep(0.16, 0.0, d2.x + d2.y * 3.0)
             + smoothstep(0.16, 0.0, d2.y + d2.x * 3.0);
  col += uColorC * step(0.985, sr) * star
       * (0.4 + 0.6 * sin(t * 2.2 + sr * 30.0)) * 0.4;

  col *= 1.0 - smoothstep(0.6, 1.05, length(uv - 0.5)) * 0.3;
  fragColor = vec4(col, 1.0);
}
