shader_type canvas_item;
// Full-screen menu background: the old sprite-mask filigree, adapted to paint
// every pixel. The black/white half split and the sprite-alpha gate are gone;
// colours and master fade are uniforms so the menu can tint and fade it in.

uniform float speed : hint_range(0.0, 2.0) = 0.35;
uniform vec3 tint_bg = vec3(0.0627, 0.0824, 0.0549);
uniform vec3 tint_line = vec3(0.3098, 0.3647, 0.2667);
uniform vec3 tint_glow = vec3(1.0, 0.8431, 0.4157);
uniform float glow : hint_range(0.0, 3.0) = 0.6;
uniform float vignette : hint_range(0.0, 2.0) = 0.8;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float softNoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

mat2 rot(float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

void fragment() {
	float FlowSpeed = 0.575;
	float ChaosMotion = 0.5;
	float Stripe = 18.0;
	float Filling = 8.2;
	float ShapeWarp = 0.5;
	float WarpFlow = 1.0;
	float TwistFlow = 1.0;
	float TwistPoles = 2.0;
	float density = 3.5;
	float MicroChaos = 3.5;
	float NoiseOverlay = 4.0;

	vec2 RENDERSIZE = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = (FRAGCOORD.xy - 0.5 * RENDERSIZE.xy) / RENDERSIZE.y;
	float t = TIME * 0.42 * FlowSpeed * (speed / 0.35);

	// Organic global drift.
	vec2 chaos = vec2(
		softNoise(uv * 3.0 + t * 0.5),
		softNoise(uv * 3.0 - t * 0.6)
	);
	uv += (chaos - 0.5) * ChaosMotion * 0.3;

	// Shape warp.
	float dn = softNoise(uv * (2.5 + ShapeWarp * 3.0) + t);
	uv += vec2(
		sin(uv.y * 3.0 + dn * 2.5 + t) * 0.18 * ShapeWarp,
		sin(uv.x * 3.0 - dn * 2.2 - t) * 0.18 * ShapeWarp
	);

	// Twist, single plus multipolar.
	float localN = softNoise(uv * (1.5 + ShapeWarp * 1.8) + t * 0.7);
	float radius = length(uv) + 0.001;
	float singleTwistAngle = sin(radius * 6.0 - t * 1.2) * 0.5 * TwistFlow + localN * TwistFlow * 0.6;
	float angle = atan(uv.y, uv.x);
	float polarComponent = sin(angle * TwistPoles * 2.0 + t * 1.5) *
			cos(radius * TwistPoles * 1.3 - t * 0.8) *
			0.35 * TwistFlow;
	uv = rot(singleTwistAngle + polarComponent) * uv;

	// Flow warp.
	uv += vec2(
		sin(uv.y * 2.2 + t * 1.5) * 0.12 * WarpFlow,
		cos(uv.x * 2.8 - t * 1.2) * 0.12 * WarpFlow
	);

	// Filament field.
	float nField = softNoise(uv * Filling * 1.4 + t * 0.3);
	float swirl = sin(uv.x * Stripe + nField * 5.0 + t * 1.1) +
			cos(uv.y * Stripe * 0.6 - nField * 4.0 + t * 0.7);
	swirl += softNoise(uv * density + t) * 2.0;
	swirl += softNoise(uv * 8.0 + t * 2.0) * MicroChaos;
	float fil = abs(sin(swirl)) * 0.6 + (nField * 0.4);

	float pulseMod = sin(t * 1.4 + nField * 8.0) * 0.5 + 0.5;
	float field = fil * pulseMod;

	// Noise overlay, lighten/darken.
	float overlayNoise = softNoise(uv * 12.0 + t * 2.0) * 2.0 - 1.0;
	field = overlayNoise > 0.0 ? max(field, field + overlayNoise * NoiseOverlay) : min(field, field + overlayNoise * NoiseOverlay);

	vec3 col = mix(tint_bg, tint_line, clamp(field, 0.0, 1.0));
	col += tint_glow * pow(field, 2.5) * glow;
	col *= (1.0 - vignette * length(uv));
	COLOR = vec4(col * intensity, 1.0);
}
