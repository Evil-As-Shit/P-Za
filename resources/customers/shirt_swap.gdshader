// Recolors the pawn sprite's teal shirt, keeping its shading, so customers look apart from
// staff (placeholder until customers have their own art).
shader_type canvas_item;

uniform vec3 shirt_color : source_color = vec3(0.7, 0.2, 0.2);
// Brightness of the sheet's main shirt color (#017564), so its shading maps onto 1.0.
const float BASE_BRIGHTNESS = 0.3;

void fragment() {
	vec4 c = COLOR;
	// The shirt is the only teal on the sheet: green and blue well above red.
	if (c.a > 0.0 && c.r < 0.4 && c.g > c.r + 0.2 && c.b > c.r + 0.15) {
		float shade = dot(c.rgb, vec3(0.299, 0.587, 0.114)) / BASE_BRIGHTNESS;
		c.rgb = clamp(shirt_color * shade, 0.0, 1.0);
	}
	COLOR = c;
}
