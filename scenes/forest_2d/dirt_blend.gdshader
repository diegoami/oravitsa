shader_type canvas_item;

uniform sampler2D terrain_mask : filter_linear, repeat_disable;
uniform float world_size = 47424.0;

varying vec2 map_uv;

void vertex() {
	map_uv = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy / world_size;
}

void fragment() {
	float amount = texture(terrain_mask, map_uv).r;
	COLOR.a *= smoothstep(0.12, 0.86, amount);
}
