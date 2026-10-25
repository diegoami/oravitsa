shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float segment_distance(vec2 p, vec2 a, vec2 b) { vec2 v=b-a; return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0)); }
float river_x(float z) {
 if(z>=-5.0) return -5.0+1.5*sin(z*0.25);
 return mix(-6.423477,38.0,clamp((-z-5.0)/39.0,0.0,1.0))+sin((z+5.0)*0.15);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world.xz;
 float grain=noise(p*6.0)*0.35+noise(p*1.3)*0.65;
 vec3 grass=mix(vec3(0.22,0.32,0.12),vec3(0.47,0.52,0.22),grain);
 float road=abs(p.y-(5.0+0.6*sin(p.x*0.15)));
 road=min(road,abs(p.y-(-28.0+0.6*sin(p.x*0.15))));
 road=min(road,abs(p.y-(58.0+0.6*sin(p.x*0.15))));
 if(p.y<6.0 && p.y>-5.0) road=min(road,abs(p.x-7.0));
 if(p.x<-28.0 && p.x>-69.0) road=min(road,abs(p.y-28.0));
 if(p.y>20.0 && p.y<59.0) road=min(road,abs(p.x+30.0));
 if(p.y>-48.0 && p.y<-27.0) road=min(road,abs(p.x+55.0));
 float trail=1.0-smoothstep(0.65,1.35,road+noise(p*3.0)*0.3);
 float edge=abs(p.x-river_x(p.y))/1.2;
 edge=min(edge,length((p-vec2(-9,-5))/vec2(5.5,4.5)));
 edge=min(edge,length((p-vec2(38,-44))/vec2(12,9)));
 edge=min(edge,length((p-vec2(-48,42))/vec2(11,8)));
 edge=min(edge,segment_distance(p,vec2(-48,42),vec2(-30,30))/1.2);
 edge=min(edge,segment_distance(p,vec2(-30,30),vec2(-12,28))/1.2);
 edge=min(edge,segment_distance(p,vec2(-12,28),vec2(-5.419,24))/1.2);
 float shore=1.0-smoothstep(1.0,1.24,edge);
 vec3 dirt=mix(vec3(0.42,0.32,0.19),vec3(0.65,0.53,0.32),grain);
 ALBEDO=mix(grass,dirt,max(trail,shore*0.85));
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}
