shader_type canvas_item;

uniform float noise_amount = 0.05;
uniform float offset_intensity = 0.02;
uniform float color_offset = 0.05;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Y軸による横ズレ
    float glitch_offset = (rand(vec2(TIME * 2.0, floor(uv.y * 50.0))) - 0.5) * offset_intensity;
    // 特定のタイミングで大きなズレ
    if (rand(vec2(TIME, 1.0)) > 0.95) {
        glitch_offset *= 5.0;
    }
    uv.x += glitch_offset;
    
    // RGBのズレ
    vec4 col;
    col.r = texture(screen_texture, vec2(uv.x + color_offset, uv.y)).r;
    col.g = texture(screen_texture, uv).g;
    col.b = texture(screen_texture, vec2(uv.x - color_offset, uv.y)).b;
    col.a = texture(screen_texture, uv).a;
    
    // ホワイトノイズ
    float n = rand(uv + vec2(TIME, -TIME));
    col.rgb = mix(col.rgb, vec3(n), noise_amount);
    
    // 走査線（スキャンライン）
    float scanline = sin(uv.y * 800.0) * 0.04;
    col.rgb -= scanline;
    
    COLOR = col;
}
