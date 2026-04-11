shader_type canvas_item;

uniform vec4 primary_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade_width : hint_range(0.1, 1.0) = 0.45;

void fragment() {
	// Distance from main diagonal (UV.x == UV.y line)
	// abs(x - y) ranges from 0.0 on the diagonal to ~0.707 at corners
	float dist = abs(UV.x - UV.y) / 1.41421356;
	float t = smoothstep(0.0, fade_width, dist);
	COLOR = mix(primary_color, secondary_color, t);
}
