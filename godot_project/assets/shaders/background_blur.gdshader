shader_type canvas_item;

// Background Blur and Darken Shader
// Uses multi-sample blur on the node's texture

uniform float blur_strength : hint_range(0.0, 20.0) = 8.0;
uniform float darken_amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 ps = TEXTURE_PIXEL_SIZE;
    vec4 col = vec4(0.0);
    float total = 0.0;
    
    // Multi-pass blur (25 samples for smooth blur)
    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            float weight = 1.0 - length(vec2(x, y)) * 0.2;
            weight = max(weight, 0.1);
            col += texture(TEXTURE, UV + vec2(x, y) * ps * blur_strength) * weight;
            total += weight;
        }
    }
    col /= total;
    
    // Apply darkening
    col.rgb *= (1.0 - darken_amount);
    
    COLOR = col;
}
