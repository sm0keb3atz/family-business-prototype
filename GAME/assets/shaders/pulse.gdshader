shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float radius : hint_range(0.0, 1.0) = 0.0;
uniform float thickness : hint_range(0.0, 1.0) = 0.05;
uniform vec4 color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float feather : hint_range(0.0, 1.0) = 0.05;

// Polished subtle uniforms
uniform float secondary_radius_offset : hint_range(0.0, 0.5) = 0.05;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.01;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.05;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.02;

// Advanced Polish
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.05;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;

float get_ring(vec2 uv, float r, float t, float f) {
    float dist = distance(uv, vec2(0.5));
    float inner = r - t * 0.5;
    float outer = r + t * 0.5;
    return smoothstep(inner - f, inner, dist) - smoothstep(outer, outer + f, dist);
}

// Simple noise function
float noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    float current_glitch = glitch_intensity * (noise(vec2(TIME, 0.0)) > 0.8 ? 1.0 : 0.1);
    vec2 uv = UV;
    
    // Very subtle organic jitter + glitch offset
    if (noise_intensity > 0.0 || current_glitch > 0.0) {
        float offset_x = noise(uv + TIME * 0.05) - 0.5;
        float offset_y = noise(uv.yx - TIME * 0.05) - 0.5;
        uv += vec2(offset_x, offset_y) * (noise_intensity + current_glitch * 0.5) * radius;
    }

    // --- Refraction Logic ---
    // We displace the SCREEN_UV based on the ring intensity
    float ring_displacement = get_ring(uv, radius, thickness * 2.0, feather * 2.0);
    vec2 normal = normalize(uv - 0.5);
    vec2 displaced_screen_uv = SCREEN_UV - normal * ring_displacement * refraction_strength * (1.0 - radius);
    vec4 screen_color = texture(screen_texture, displaced_screen_uv);

    // Chromatic Aberration
    float r_ring = get_ring(uv - chromatic_aberration * (uv - 0.5), radius, thickness, feather);
    float g_ring = get_ring(uv, radius, thickness, feather);
    float b_ring = get_ring(uv + chromatic_aberration * (uv - 0.5), radius, thickness, feather);
    
    // Secondary Echo (more subtle)
    float second_r = max(0.0, radius - secondary_radius_offset);
    float second_alpha = 0.3 * (1.0 - radius);
    float r_echo = get_ring(uv - chromatic_aberration * (uv - 0.5), second_r, thickness * 0.5, feather);
    float g_echo = get_ring(uv, second_r, thickness * 0.5, feather);
    float b_echo = get_ring(uv + chromatic_aberration * (uv - 0.5), second_r, thickness * 0.5, feather);

    vec3 main_rgb = vec3(r_ring, g_ring, b_ring) * color.rgb;
    vec3 echo_rgb = vec3(r_echo, g_echo, b_echo) * color.rgb * second_alpha;
    
    vec3 blended_rgb = main_rgb + echo_rgb;
    
    // Sonar Trailing Effect (inside ring)
    float dist = distance(uv, vec2(0.5));
    float trail = smoothstep(radius - thickness * 1.5, radius, dist) * (1.0 - smoothstep(radius, radius + feather, dist));
    blended_rgb += color.rgb * trail * 0.15 * (1.0 - radius);

    // Subtle Scanlines
    float scanline = sin(uv.y * 400.0) * 0.5 + 0.5;
    blended_rgb *= mix(1.0, scanline, scanline_intensity);

    // Mix with Screen Color (Refraction)
    // We want the pulse to be additive/screen-like on top of the distorted background
    vec3 final_color = mix(screen_color.rgb, blended_rgb, max(max(blended_rgb.r, blended_rgb.g), blended_rgb.b));
    final_color += blended_rgb * 0.5; // Slight glow boost

    float final_alpha = max(max(blended_rgb.r, blended_rgb.g), blended_rgb.b);
    // Flicker effect on alpha for glitch feel
    if (glitch_intensity > 0.0) {
        final_alpha *= mix(0.7, 1.0, noise(vec2(TIME * 20.0)));
    }

    COLOR = vec4(final_color, final_alpha * color.a * (1.0 - radius * 0.5));
}
