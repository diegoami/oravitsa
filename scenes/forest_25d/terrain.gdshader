shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world.xz;
 float grain=noise(p*6.0)*0.35+noise(p*1.3)*0.65;
 vec3 grass=mix(vec3(0.22,0.32,0.12),vec3(0.47,0.52,0.22),grain);
 float road=abs(p.y-(5.0+0.6*sin(p.x*0.15)));
 float spur=abs(p.x-7.0);
 if(p.y<5.0 && p.y>-5.0) road=min(road,spur);
 float trail=1.0-smoothstep(0.65,1.35,road+noise(p*3.0)*0.3);
 float lake=length((p-vec2(-9,-5))/vec2(5.5,4.5));
 float river=abs(p.x-(-5.0+1.5*sin(p.y*0.25)));
 float shore=1.0-smoothstep(1.0,1.2,lake);
 if(p.y>-5.0) shore=max(shore,1.0-smoothstep(1.2,1.9,river));
 vec3 dirt=mix(vec3(0.42,0.32,0.19),vec3(0.65,0.53,0.32),grain);
 ALBEDO=mix(grass,dirt,max(trail,shore*0.85));
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}
