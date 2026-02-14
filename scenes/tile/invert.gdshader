shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(1.0 - tex.rgb, tex.a) * COLOR;
}
