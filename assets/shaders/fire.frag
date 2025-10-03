// assets/shaders/fire.frag
// Flutter Runtime Effect shader (Impeller/SkSL-compatible)

#include <flutter/runtime_effect.glsl>
// ⚠️ Do NOT use precision qualifiers with runtime_effect.glsl

// ---- Uniforms (match Dart setFloat order) ----
uniform float uTime;          // 0
uniform float uNoiseScale;    // 1
uniform float uRise;          // 2
uniform float uTurbulence;    // 3
uniform float uBrightness;    // 4
uniform float uAspect;        // 5
uniform float uSoftEdge;      // 6
uniform float uWidth;         // 7
uniform float uHeight;        // 8
uniform float uBandTop;       // 9
uniform float uBandFeather;   // 10

// ---- Helpers ----
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }

float noise(vec2 p){
  vec2 i = floor(p), f = fract(p);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p){
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p *= 2.0;
    a *= 0.5;
  }
  return v;
}

// Palette from deep red -> orange -> yellow -> near-white
vec3 fireRamp(float t){
  t = clamp(t, 0.0, 1.0);
  vec3 c1 = vec3(0.05, 0.00, 0.00);
  vec3 c2 = vec3(0.80, 0.07, 0.00);
  vec3 c3 = vec3(1.00, 0.55, 0.00);
  vec3 c4 = vec3(1.00, 0.95, 0.30);
  vec3 c5 = vec3(1.00, 1.00, 1.00);
  if (t < 0.25) return mix(c1, c2, t/0.25);
  if (t < 0.50) return mix(c2, c3, (t-0.25)/0.25);
  if (t < 0.80) return mix(c3, c4, (t-0.50)/0.30);
  return mix(c4, c5, (t-0.80)/0.20);
}

out vec4 fragColor;

void main() {
  // ---- Safe coords / uv
  vec2 frag = FlutterFragCoord().xy;                      // use .xy
  float w = max(uWidth,  1.0);                            // guard sizes
  float h = max(uHeight, 1.0);
  vec2 uv = vec2(frag.x / w, frag.y / h);
  uv.x *= max(uAspect, 1e-6);                             // guard aspect

  // ---- Vertical band (bottom uBandTop portion, feathered)
  float band   = clamp(uBandTop, 0.0, 1.0);
  float feather = max(uBandFeather, 1e-5);                // edge0 < edge1
  float bandEdge = 1.0 - band;
  float bandMask = smoothstep(bandEdge, bandEdge + feather, uv.y);

  // ---- Flame field: upward advection + warp
  float t = uTime;
  float ns = max(uNoiseScale, 1e-4);                      // guard ns
  vec2 p = uv;

  vec2 warp = vec2(
      fbm(p * ns + vec2(0.0,  t * 0.35)),
      fbm(p * (ns * 0.9) + vec2(3.14, -t * 0.27))
  ) - 0.5;
  p += warp * uTurbulence * 0.25;

  // Upward movement
  p.y += -t * uRise;

  // Base turbulence/heat
  float n = fbm(vec2(p.x, p.y * 1.4) * ns);

  // Sharpen base near the bottom; soften near the top with proper edges
  float base = smoothstep(0.25, 1.0, n);
  float se = clamp(uSoftEdge, 0.0, 1.0);
  float edgeTop = 1.0 - smoothstep(1.0 - se, 1.0, uv.y);  // valid ordering
  base *= edgeTop;

  // Licking tongues
  float tongues = fbm((p + warp * 0.5) * (ns * 2.5));
  float flame = clamp(base * 0.9 + tongues * 0.6, 0.0, 1.0);

  // Apply band mask
  flame *= bandMask;

  // Color + brightness
  vec3 col = fireRamp(pow(flame, 1.1)) * uBrightness;

  // Alpha stronger near bottom, taper up, and mask it
  float alpha = clamp(flame * 1.25, 0.0, 1.0) * edgeTop * bandMask;

  fragColor = vec4(col, alpha);
}
