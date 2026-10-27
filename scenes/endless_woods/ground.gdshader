shader_type spatial;
render_mode cull_disabled;
varying vec3 ground_color;
void vertex() { ground_color = COLOR.rgb; }
void fragment() {
 ALBEDO = ground_color;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
