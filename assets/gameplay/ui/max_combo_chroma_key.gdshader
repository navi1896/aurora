shader_type canvas_item;
render_mode blend_mix;

uniform vec3 matte_color : source_color = vec3(0.270588, 0.270588, 0.290196);
uniform float key_threshold : hint_range(0.0, 0.1) = 0.010;
uniform float key_softness : hint_range(0.001, 0.1) = 0.026;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 source_color = texture(TEXTURE, UV).rgb;
	float color_distance = distance(source_color, matte_color);
	float alpha = smoothstep(key_threshold, key_threshold + key_softness, color_distance);
	vec3 unmatte_color = clamp(
		(source_color - matte_color * (1.0 - alpha)) / max(alpha, 0.001),
		vec3(0.0),
		vec3(1.0)
	);
	COLOR = vec4(unmatte_color, alpha * opacity);
}
