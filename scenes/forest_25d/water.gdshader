shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float ripple=sin(world.x*11.1+world.z*7.2+TIME*0.65)*sin(world.z*9.0-TIME*0.4);
 float streak=pow(max(0.0,sin(world.x*19.0+world.z*12.0+sin(world.z*7.0)+TIME)),24.0);
 ALBEDO=mix(vec3(0.08,0.21,0.21),vec3(0.12,0.28,0.26),ripple*0.5+0.5)+vec3(0.025,0.04,0.03)*streak;
 ROUGHNESS=0.3;
 SPECULAR=0.45;
}
