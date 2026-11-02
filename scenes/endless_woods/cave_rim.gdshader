// A glow drawn over a model's own materials (#102), so dark creatures keep a
// readable shape against dark cave floors and walls: a faint even fill plus a
// brighter rim at grazing angles. It only adds light; the model's own
// surface still shows through unchanged.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 rim_color : source_color = vec4(0.55, 0.75, 1.0, 0.85);
uniform float power = 1.6;
uniform float fill = 0.14;
uniform float edge = 1.4;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = rim_color.rgb * rim_color.a * (fill + edge * rim);
}
