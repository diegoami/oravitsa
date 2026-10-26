shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
#include "res://scenes/forest_25d/shore.gdshaderinc"
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float ripple=sin(world.x*2.1+world.z*1.7+TIME*0.35)*sin(world.z*2.8-TIME*0.25);
 float streak=pow(max(0.0,sin(world.x*3.8+world.z*2.4+sin(world.z*1.7)+TIME*0.4)),8.0);
 ALBEDO=mix(vec3(0.08,0.21,0.21),vec3(0.12,0.28,0.26),ripple*0.5+0.5)+vec3(0.025,0.04,0.03)*streak;
 float shallows=smoothstep(0.55,1.05,water_edge(world.xz));
 ALBEDO=mix(ALBEDO,vec3(0.24,0.34,0.28)+ripple*0.012,shallows*0.8);
 ROUGHNESS=0.65;
 SPECULAR=0.15;
}
