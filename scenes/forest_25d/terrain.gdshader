shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
#include "res://scenes/forest_25d/shore.gdshaderinc"
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world.xz;
 float grain=noise(p*2.8)*0.4+noise(p*0.65)*0.6;
 vec3 grass=mix(vec3(0.30,0.36,0.18),vec3(0.45,0.48,0.25),grain);
 float road=abs(p.y-(5.0+0.6*sin(p.x*0.15)));
 road=min(road,abs(p.y-(-28.0+0.6*sin(p.x*0.15))));
 road=min(road,abs(p.y-(58.0+0.6*sin(p.x*0.15))));
 if(p.y<6.0 && p.y>-5.0) road=min(road,abs(p.x-7.0));
 if(p.x<-28.0 && p.x>-69.0) road=min(road,abs(p.y-28.0));
 if(p.y>20.0 && p.y<59.0) road=min(road,abs(p.x+30.0));
 if(p.y>-48.0 && p.y<-27.0) road=min(road,abs(p.x+55.0));
 road=min(road,segment_distance(p,vec2(7,-0.8),vec2(13,2.8)));
 float trail=1.0-smoothstep(0.65,1.35,road+noise(p*3.0)*0.3);
 float edge=water_edge(p);
 float shore=1.0-smoothstep(1.02,1.65,edge+(noise(p*1.7)-0.5)*0.18);
 vec3 dirt=mix(vec3(0.42,0.32,0.19),vec3(0.65,0.53,0.32),grain);
 ALBEDO=mix(grass,dirt,max(trail,shore*0.85));
 vec3 wet_soil=mix(vec3(0.20,0.23,0.17),vec3(0.34,0.32,0.23),grain);
 ALBEDO=mix(ALBEDO,wet_soil,(1.0-smoothstep(1.0,1.25,edge))*0.8);
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}
