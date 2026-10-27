shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 float ripple = sin(world.x * 2.1 + world.z * 1.7 + TIME * 0.35) * sin(world.z * 2.8 - TIME * 0.25);
 ALBEDO = mix(vec3(0.10,0.23,0.23),vec3(0.17,0.31,0.28),ripple * 0.5 + 0.5);
 ROUGHNESS = 0.7;
 SPECULAR = 0.12;
}
