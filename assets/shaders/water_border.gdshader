// Water border animation shader for TileMapLayer
// Apply this to the TileMapLayer that contains water border tiles.
// It detects the blue/orange water pixels and animates them with a ripple effect.

shader_type canvas_item;

uniform float wave_speed : hint_range(0.5, 5.0) = 2.0;
uniform float wave_amplitude : hint_range(0.0, 0.02) = 0.004;
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;

bool is_water_pixel(vec4 color) {
	// Detects blue water pixels: more blue than red, and has some alpha
	return (color.b > color.r + 0.1) && (color.a > 0.5) &&
		   (color.b > 0.35) && (color.r < 0.75);
}

void fragment() {
	float t = TIME * wave_speed;

	vec4 base_color = texture(TEXTURE, UV);

	vec2 wave_uv = UV;

	// Apply UV wave distortion
	float wave_x = sin(UV.y * wave_frequency * TEXTURE_PIXEL_SIZE.y * 200.0 + t) * wave_amplitude;
	float wave_y = cos(UV.x * wave_frequency * TEXTURE_PIXEL_SIZE.x * 200.0 + t * 0.7) * wave_amplitude * 0.5;
	wave_uv += vec2(wave_x, wave_y);

	// Clamp to stay within texture bounds
	wave_uv = clamp(wave_uv, TEXTURE_PIXEL_SIZE, vec2(1.0) - TEXTURE_PIXEL_SIZE);

	vec4 wave_color = texture(TEXTURE, wave_uv);

	// Only apply wave to blue water pixels, leave grass unchanged
	if (is_water_pixel(base_color)) {
		COLOR = wave_color;
		// Add subtle brightness pulse for water feel
		float pulse = 0.95 + 0.05 * sin(t * 1.5 + UV.x * 50.0);
		COLOR.rgb *= pulse;
	} else {
		COLOR = base_color;
	}
}
