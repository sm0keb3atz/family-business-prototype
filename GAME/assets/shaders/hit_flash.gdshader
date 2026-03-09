shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 flash_rgb = mix(tex_color.rgb, flash_color.rgb, flash_modifier);
	// We only want to influence the alpha with the modulate (COLOR.a) to allow for fading.
	// We keep the RGB as flash_rgb to maintain the appearance the user expects.
	COLOR = vec4(flash_rgb, tex_color.a * COLOR.a);
}
