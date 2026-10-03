shader_type canvas_item;
render_mode blend_mix, unshaded;
// Screen-space refraction ring (Nolkaloid-style). An annulus of the screen is
// pushed radially outward and sampled back, so the wave warps the board behind
// it instead of drawing a glowing ring. A bright rim rides the leading edge for
// the Celeste dash flash.
//
// Branchless on purpose: Godot's shading language forbids returning from
// fragment(), and when mask is zero the displacement and rim both vanish.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.777;
uniform float radius = 0.0;
uniform float thickness = 0.12;
uniform float softness = 0.06;
uniform float force = 0.0;
uniform float rim = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);

void fragment() {
	vec2 delta = SCREEN_UV - center;
	vec2 dir = delta / max(length(delta), 1e-5);
	float d = length(delta * vec2(aspect, 1.0));
	float outer = 1.0 - smoothstep(radius - softness, radius, d);
	float inner = smoothstep(radius - thickness - softness, radius - thickness, d);
	float mask = outer * inner;
	float lead = smoothstep(radius - thickness, radius, d);
	vec3 warped = texture(screen_texture, SCREEN_UV - dir * force * mask).rgb;
	COLOR = vec4(mix(warped, rim_color.rgb, rim * mask * lead), 1.0);
}
