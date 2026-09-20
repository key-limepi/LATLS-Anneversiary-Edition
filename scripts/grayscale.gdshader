shader_type canvas_item;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray) * c.a, c.a);
}
