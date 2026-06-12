// Dungeon background shader — shared header + uniform contract.
// Every elemental shader uses THIS exact uniform interface (same setFloat order
// on the Dart side). Output is background-only; no gameplay logic here.
#include <flutter/runtime_effect.glsl>

out vec4 fragColor;

uniform vec2 uResolution;  // 0,1
uniform float uTime;       // 2
uniform vec3 uColorA;      // 3,4,5   (zenith / base)
uniform vec3 uColorB;      // 6,7,8   (horizon / mid)
uniform vec3 uColorC;      // 9,10,11 (highlight / energy)
uniform float uIntensity;  // 12
uniform float uNoiseScale; // 13
uniform float uFlowSpeed;  // 14
uniform float uSeed;       // 15
