shader_type canvas_item;

// gif-02 style wipe: black is only ever the union of circles that spawn at the
// edges and grow inward. The CPU bakes, per pixel, the factor at which that
// pixel gets swallowed, so this is a single lookup and threshold - there is no
// solid region sweeping the screen, only growing circles.
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float factor : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform sampler2D field_texture;
uniform float edge : hint_range(0.0, 0.2, 0.001) = 0.02;

void fragment() {
	float t = texture(field_texture, UV).r;
	COLOR.rgb = base_color.rgb;
	COLOR.a = smoothstep(t, t + edge, factor) * base_color.a;
}
