// Shared palette helpers. Mixes the three contract colours by a 0..1 ramp.
vec3 palette3(float t, vec3 a, vec3 b, vec3 c) {
  t = clamp(t, 0.0, 1.0);
  return t < 0.5 ? mix(a, b, t * 2.0) : mix(b, c, (t - 0.5) * 2.0);
}

// Normalised pixel UV (0..1), origin top-left.
vec2 dungeonUV() {
  return FlutterFragCoord().xy / uResolution;
}
