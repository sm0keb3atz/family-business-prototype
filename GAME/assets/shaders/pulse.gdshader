shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float radius : hint_range(0.0, 1.0) = 0.0;
uniform float thickness : hint_range(0.0, 1.0) = 0.05;
uniform vec4 color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float feather : hint_range(0.0, 1.0) = 0.05;
uniform float secondary_radius_offset : hint_range(0.0, 0.5) = 0.05;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.01;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.05;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.02;
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.05;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float glow_strength : hint_range(0.0, 4.0) = 1.25;
uniform float fill_strength : hint_range(0.0, 1.0) = 0.18;
uniform float edge_flash_strength : hint_range(0.0, 2.0) = 0.45;
uniform float ripple_strength : hint_range(0.0, 0.1) = 0.018;
uniform float ripple_density : hint_range(1.0, 40.0) = 16.0;
uniform float swirl_strength : hint_range(0.0, 0.05) = 0.006;

float ring_from_dist(float dist, float r, float t, float f) {
	float inner = max(r - t * 0.5, 0.0);
	float outer = r + t * 0.5;
	return smoothstep(inner - f, inner, dist) - smoothstep(outer, outer + f, dist);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 center = vec2(0.5);
	vec2 local = UV - center;
	float dist = length(local);
	vec2 dir = local / max(dist, 0.0001);

	float glitch_gate = step(0.84, hash(vec2(floor(TIME * 18.0), 7.0)));
	float glitch = glitch_intensity * mix(0.2, 1.0, glitch_gate);
	float organic_noise = (fbm(UV * 8.0 + vec2(TIME * 0.18, -TIME * 0.12)) - 0.5) * noise_intensity;
	float ripple = sin((dist - radius) * ripple_density * 6.28318 - TIME * 6.0) * ripple_strength * (1.0 - radius * 0.55);
	float warped_dist = dist + organic_noise * 0.08 + ripple;

	float primary_ring = ring_from_dist(warped_dist, radius, thickness, feather);
	float echo_radius = max(0.0, radius - secondary_radius_offset);
	float echo_ring = ring_from_dist(warped_dist, echo_radius, thickness * 0.7, feather * 1.25) * (1.0 - radius * 0.45);
	float edge_flash = ring_from_dist(warped_dist, radius + thickness * 0.12, max(thickness * 0.35, 0.003), feather * 0.8) * edge_flash_strength;

	float fill_radius = max(radius - max(thickness * 5.5, 0.16), 0.0);
	float interior_fill = (1.0 - smoothstep(fill_radius, radius + feather * 0.75, warped_dist)) * fill_strength * (1.0 - radius * 0.35);
	float trailing_band = smoothstep(radius - thickness * 2.6, radius - thickness * 0.6, warped_dist);
	trailing_band *= 1.0 - smoothstep(radius - thickness * 0.2, radius + feather, warped_dist);

	float field = clamp(primary_ring + echo_ring * 0.7 + edge_flash + interior_fill * 0.9, 0.0, 1.0);
	float displacement = (primary_ring * 1.2 + edge_flash + interior_fill * 0.35) * refraction_strength;
	vec2 tangential = vec2(-dir.y, dir.x);
	vec2 distortion = dir * displacement * 0.035;
	distortion += tangential * (organic_noise + glitch * 0.3) * swirl_strength * (primary_ring + interior_fill);

	vec4 screen_color = texture(screen_texture, SCREEN_UV - distortion);

	float chroma_shift = chromatic_aberration * (1.0 + edge_flash * 0.2);
	float red_ring = ring_from_dist(warped_dist + chroma_shift * 0.6, radius, thickness, feather);
	float green_ring = primary_ring;
	float blue_ring = ring_from_dist(warped_dist - chroma_shift * 0.6, radius, thickness, feather);

	vec3 ring_rgb = vec3(red_ring, green_ring, blue_ring) * color.rgb;
	vec3 echo_rgb = color.rgb * echo_ring * 0.55;
	vec3 fill_rgb = color.rgb * (interior_fill + trailing_band * 0.18);
	vec3 flash_rgb = mix(color.rgb, vec3(1.0), 0.4) * edge_flash * 0.75;

	float scanline = 0.92 + 0.08 * sin(UV.y * 360.0 + TIME * 8.0);
	scanline = mix(1.0, scanline, scanline_intensity);

	float sparkle = (noise(UV * 32.0 + vec2(TIME * 9.0, -TIME * 7.0)) - 0.5) * 0.16;
	sparkle *= noise_intensity * (primary_ring + edge_flash);

	vec3 emission = (ring_rgb + echo_rgb + fill_rgb + flash_rgb) * glow_strength * scanline;
	emission += color.rgb * sparkle;

	float blend = clamp(field + edge_flash * 0.2, 0.0, 1.0);
	vec3 final_color = mix(screen_color.rgb, screen_color.rgb + emission, blend);
	float alpha = clamp(field + edge_flash * 0.25, 0.0, 1.0) * color.a;
	alpha *= mix(0.82, 1.0, 1.0 - glitch * 0.4);

	COLOR = vec4(final_color, alpha);
}
