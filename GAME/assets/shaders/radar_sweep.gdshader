shader_type canvas_item;

// ── Configurable Uniforms ─────────────────────────────────────────────
uniform vec4 sweep_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);
uniform float sweep_speed : hint_range(0.5, 8.0) = 2.0;
uniform float trail_length : hint_range(0.1, 3.14159) = 1.2;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float sweep_glow : hint_range(0.0, 1.0) = 0.6;

void fragment() {
    // Map UV (0-1) to centered coordinates (-0.5 to 0.5)
    vec2 centered = UV - 0.5;
    float dist = length(centered);

    // Discard pixels outside the unit circle (radius 0.5 in UV space)
    if (dist > 0.5) {
        discard;
    }

    // Normalised distance (0 at center, 1 at edge)
    float norm_dist = dist / 0.5;

    // ── Sweep angle ───────────────────────────────────────────────────
    float angle = atan(centered.y, centered.x); // -PI to PI
    float sweep_angle = mod(TIME * sweep_speed, TAU) - PI; // -PI to PI

    // Angular difference wrapped to [-PI, PI]
    float diff = angle - sweep_angle;
    diff = mod(diff + PI, TAU) - PI;

    // Trail: bright at leading edge (diff ~ 0), fading behind (diff < 0)
    // The trail extends in the negative-diff direction (behind the sweep)
    float trail = 0.0;
    if (diff >= -trail_length && diff <= 0.0) {
        // 1.0 at leading edge, 0.0 at trail end
        trail = 1.0 - abs(diff) / trail_length;
        // Smooth falloff curve
        trail = trail * trail;
    }
    // Thin bright leading edge
    float edge = smoothstep(0.03, 0.0, abs(diff)) * 0.5;
    trail = max(trail, edge);

    // Fade trail toward center so it looks like a proper wedge
    trail *= smoothstep(0.0, 0.15, norm_dist);


    // ── Soft edge fade ────────────────────────────────────────────────
    float edge_fade = 1.0 - smoothstep(0.43, 0.5, dist);

    // ── Compose final color ───────────────────────────────────────────
    float alpha = 0.0;
    // Base fill (very subtle)
    alpha += base_alpha * edge_fade * 0.5;
    // Sweep trail
    alpha += trail * sweep_glow * edge_fade;



    // Clamp
    alpha = clamp(alpha, 0.0, 1.0);

    COLOR = vec4(sweep_color.rgb, alpha * sweep_color.a);
}
