shader_type canvas_item;

// Liquid Glass Shader for DialogBox
// Inspired by iOS "Liquid Glass" concept

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 5.0) = 2.5;
uniform vec4 tint_color : source_color = vec4(0.02, 0.03, 0.06, 0.85);
uniform float distortion_strength : hint_range(0.0, 0.02) = 0.003;
uniform float distortion_speed : hint_range(0.1, 3.0) = 0.8;
uniform float edge_glow_strength : hint_range(0.0, 1.0) = 0.15;
uniform vec4 edge_color : source_color = vec4(0.4, 0.9, 0.7, 0.4);

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Liquid distortion using sine waves
    float time = TIME * distortion_speed;
    float wave1 = sin(uv.y * 15.0 + time) * distortion_strength;
    float wave2 = cos(uv.x * 12.0 + time * 0.7) * distortion_strength * 0.5;
    float wave3 = sin((uv.x + uv.y) * 8.0 + time * 1.3) * distortion_strength * 0.3;
    
    vec2 distorted_uv = uv + vec2(wave1 + wave3, wave2 + wave3);
    
    // Sample blurred background
    vec4 blurred_bg = textureLod(screen_texture, distorted_uv, blur_lod);
    
    // Mix with tint color
    vec4 glass_color = mix(blurred_bg, tint_color, tint_color.a);
    
    // Edge glow effect (subtle highlight at edges)
    float edge_x = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x);
    float edge_y = smoothstep(0.0, 0.06, UV.y) * smoothstep(0.0, 0.06, 1.0 - UV.y);
    float edge_mask = 1.0 - (edge_x * edge_y);
    
    vec4 final_color = glass_color + edge_color * edge_mask * edge_glow_strength;
    final_color.a = tint_color.a + edge_mask * 0.1;
    
    COLOR = final_color;
}
