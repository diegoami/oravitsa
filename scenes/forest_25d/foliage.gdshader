shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.365, 0.455, 0.335, 1.0);
uniform vec3 player_world = vec3(0.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec4 leaf = texture(leaf_texture, UV);
 if (leaf.a < 0.4) discard;
 // A close-fitting window follows the character through foreground crowns.
 // Projection matches the fixed 35.264-degree camera, without sorting alpha.
 vec3 relative = world - player_world - vec3(0, 0.8, 0);
 vec2 screen_delta = vec2(relative.x, relative.y * 0.816497 - relative.z * 0.57735);
 vec2 ellipse = screen_delta / vec2(0.75, 1.05);
 float distance_squared = dot(ellipse, ellipse);
 float in_front = relative.y * 0.57735 + relative.z * 0.816497;
 float reveal = 1.0 - smoothstep(0.4225, 1.8225, distance_squared);
 float coverage = 1.0 - 0.985 * reveal * smoothstep(0.15, 0.65, in_front);
 // World-anchored interleaved noise avoids both screen swimming and an
 // expensive trigonometric hash on every leaf fragment.
 vec3 cell = floor(world * 48.0);
 float dither = fract(52.9829189 * fract(dot(cell, vec3(0.06711056, 0.00583715, 0.0072391))));
 if (dither > coverage) discard;
 ALBEDO = leaf.rgb * tint.rgb;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 // Keep backlit leaf cards readable without flattening the whole canopy.
 BACKLIGHT = ALBEDO * 0.25;
}
