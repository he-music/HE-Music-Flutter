#include <flutter/runtime_effect.glsl>

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform vec3 uColor;
uniform float uReach;
uniform float uRadius;
uniform float uSpacing;
uniform float uOldestRadius;
uniform sampler2D uField;

out vec4 fragColor;

void main() {
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  vec2 encoded = texture(uField, uv).rg;
  float distanceToOutline = dot(encoded, vec2(65280.0, 255.0)) * (uReach / 65535.0);
  float index = floor((distanceToOutline - uRadius) / uSpacing + 0.5);
  float radius = uRadius + index * uSpacing;
  float fade = smoothstep(0.0, 9.0, radius) * (1.0 - smoothstep(uReach * 0.22, uReach, radius));
  float gap = abs(distanceToOutline - radius);
  float stroke = 1.0 - smoothstep(0.35, 1.65, gap);
  float glow = (1.0 - smoothstep(0.0, 4.0, gap)) * 0.13;
  float visible = step(0.0, index) * step(radius, uOldestRadius + 0.01);
  float alpha = (stroke * 0.5 + glow) * fade * visible * smoothstep(0.0, 2.0, distanceToOutline);
  fragColor = vec4(uColor * alpha, alpha);
}
