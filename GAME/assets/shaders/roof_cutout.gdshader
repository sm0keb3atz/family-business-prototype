shader_type canvas_item;

uniform vec2 player_pos; // Screen space pixel coordinates
uniform vec2 cursor_pos; // Screen space pixel coordinates
uniform float radius = 150.0;
uniform float softness = 0.8;
uniform float player_occlusion : hint_range(0.0, 1.0) = 0.0;
uniform float cursor_occlusion : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    float dist_player = distance(FRAGCOORD.xy, player_pos);
    float dist_cursor = distance(FRAGCOORD.xy, cursor_pos);
    
    float mask_player = smoothstep(radius * (1.0 - softness), radius, dist_player);
    float mask_cursor = smoothstep(radius * (1.0 - softness), radius, dist_cursor);
    
    // Apply masks independently based on their respective strengths
    float d_player = mix(1.0, mask_player, player_occlusion);
    float d_cursor = mix(1.0, mask_cursor, cursor_occlusion);
    
    // Combine: use the most transparent value
    float final_alpha = min(d_player, d_cursor);
    
    COLOR.a *= final_alpha;
}
