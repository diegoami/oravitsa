shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.475, 0.565, 0.427, 1.0);
uniform vec3 player_world = vec3(0.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec4 leaf = texture(leaf_texture, UV);
 if (leaf.a < 0.4) discard;
 // A small dithered window follows the character through foreground crowns.
 // Projection matches the fixed 35.264-degree camera, without sorting alpha.
 vec3 relative = world - player_world - vec3(0, 0.8, 0);
 vec2 screen_delta = vec2(relative.x, relative.y * 0.816497 - relative.z * 0.57735);
 float proximity = exp(-dot(screen_delta / vec2(1.3, 1.6), screen_delta / vec2(1.3, 1.6)));
 float coverage = mix(1.0, 0.02, smoothstep(0.15, 0.45, proximity));
 float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
 float in_front = relative.y * 0.57735 + relative.z * 0.816497;
 if (in_front > 0.1 && dither > coverage) discard;
 ALBEDO = leaf.rgb * tint.rgb;
}
