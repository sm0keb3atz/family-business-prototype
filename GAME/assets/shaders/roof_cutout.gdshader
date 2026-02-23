shader_type canvas_item;

uniform vec2 player_pos; // Screen space pixel coordinates
uniform float radius = 150.0;
uniform float softness = 0.8;
uniform float occlusion_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    float dist = distance(FRAGCOORD.xy, player_pos);
    
    // smoothstep(edge0, edge1, x) returns 0.0 if x <= edge0 and 1.0 if x >= edge1
    // We want it to be transparent (0.0) near the player and opaque (1.0) far away.
    float alpha_mask = smoothstep(radius * (1.0 - softness), radius, dist);
    
    // Modulate the mask by occlusion_strength (0.0 = fully opaque, 1.0 = full mask)
    float final_alpha = mix(1.0, alpha_mask, occlusion_strength);
    
    COLOR.a *= final_alpha;
}
