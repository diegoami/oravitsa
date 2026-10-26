// Match landscape.gd's analytic waterways in both bank and water materials.
float segment_distance(vec2 p, vec2 a, vec2 b) {
 vec2 v = b - a;
 return length(p - a - v * clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0));
}
float river_x(float z) {
 if (z >= -5.0) return -5.0 + 1.5 * sin(z * 0.25);
 return mix(-6.423477, 38.0, clamp((-z - 5.0) / 39.0, 0.0, 1.0)) + sin((z + 5.0) * 0.15);
}
float water_edge(vec2 p) {
 float edge = abs(p.x - river_x(p.y)) / 1.2;
 edge = min(edge, length((p - vec2(-9, -5)) / vec2(5.5, 4.5)));
 edge = min(edge, length((p - vec2(38, -44)) / vec2(12, 9)));
 edge = min(edge, length((p - vec2(-48, 42)) / vec2(11, 8)));
 edge = min(edge, segment_distance(p, vec2(-48, 42), vec2(-30, 30)) / 1.2);
 edge = min(edge, segment_distance(p, vec2(-30, 30), vec2(-12, 28)) / 1.2);
 return min(edge, segment_distance(p, vec2(-12, 28), vec2(-5.419, 24)) / 1.2);
}
