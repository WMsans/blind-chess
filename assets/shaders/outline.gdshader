shader_type canvas_item;
// Rim outline for the selected piece only. Samples the silhouette around every
// texel; the piece SVGs carry ~25% transparent padding, so the halo has room to
// draw outside the stroke without clipping. outline_size is animated from zero
// by juice.gd, so an unselected piece pays nothing visible.
//
// No early return: Godot's shading language forbids returning from fragment().

uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.34, 1.0);
uniform float outline_size : hint_range(0.0, 12.0) = 0.0;
uniform float outline_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float ring = 0.0;
	if (outline_size > 0.001) {
		vec2 off = TEXTURE_PIXEL_SIZE * outline_size;
		float neighbor = 0.0;
		neighbor = max(neighbor, texture(TEXTURE, UV + vec2(off.x, 0.0)).a);
		neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-off.x, 0.0)).a);
		neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, off.y)).a);
		neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, -off.y)).a);
		neighbor = max(neighbor, texture(TEXTURE, UV + off).a);
		neighbor = max(neighbor, texture(TEXTURE, UV - off).a);
		neighbor = max(neighbor, texture(TEXTURE, UV + vec2(off.x, -off.y)).a);
		neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-off.x, off.y)).a);
		ring = clamp(neighbor - base.a, 0.0, 1.0) * outline_alpha;
	}
	COLOR = base;
	COLOR.rgb = mix(COLOR.rgb, outline_color.rgb, ring);
	COLOR.a = max(COLOR.a, ring);
}
