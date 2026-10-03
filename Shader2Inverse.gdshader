shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}
float softNoise(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash21(i);
    float b = hash21(i+vec2(1.0,0.0));
    float c = hash21(i+vec2(0.0,1.0));
    float d = hash21(i+vec2(1.0,1.0));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}

mat2 rot(float a){
    float c = cos(a), s = sin(a);
    return mat2(vec2(c,-s),vec2(s,c));
}
uniform float rotation_angle : hint_range(0.0, 6.28318) = 0.0; // Angle in radians
vec2 transform_uv(vec2 uv, vec2 pivot, float angle, vec2 offset, vec2 scale) {
    uv -= pivot;
    uv *= scale;
    
    mat2 rotation = mat2(
        vec2(sin(angle), -cos(angle)), 
        vec2(cos(angle), sin(angle))
    );
    uv = uv * rotation;
    
    uv += pivot - offset; 
    return uv;
}
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);

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
	float Glow = 3.0;
	float MicroChaos = 3.5;
	float NoiseOverlay = 4.0;
	float OverlayTwist = 0.0;
	vec2 RENDERSIZE = 1.0/(SCREEN_PIXEL_SIZE*2.0);
    vec2 uv = (FRAGCOORD.xy - 0.5 * RENDERSIZE.xy) / RENDERSIZE.y;
    float t = TIME * 0.42 * FlowSpeed;

    //----------------------------------------------------
    // ChaosMotion - mouvement global organique
    //----------------------------------------------------
    vec2 chaos = vec2(
        softNoise(uv*3.0 + t*0.5),
        softNoise(uv*3.0 - t*0.6)
    );
    uv += (chaos - 0.5) * ChaosMotion * 0.3;

    //----------------------------------------------------
    // 1. ShapeWarp
    //----------------------------------------------------
    float dn = softNoise(uv * (2.5 + ShapeWarp*3.0) + t);
    uv += vec2(
        sin(uv.y * 3.0 + dn*2.5 + t)*0.18*ShapeWarp,
        sin(uv.x * 3.0 - dn*2.2 - t)*0.18*ShapeWarp
    );

    //----------------------------------------------------
    // 2. TwistFlow
    //----------------------------------------------------
    float localN = softNoise(uv * (1.5 + ShapeWarp*1.8) + t*0.7);
    float radius = length(uv) + 0.001;
    float singleTwistAngle = sin(radius * 6.0 - t*1.2) * 0.5 * TwistFlow + localN * TwistFlow * 0.6;

    //----------------------------------------------------
    // 3. Twist multipolaire
    //----------------------------------------------------
    float angle = atan(uv.y, uv.x);
    float polarComponent = sin(angle * TwistPoles * 2.0 + t*1.5) *
                           cos(radius * TwistPoles * 1.3 - t*0.8) *
                           0.35 * TwistFlow;
    float totalTwist = singleTwistAngle + polarComponent;
    uv = rot(totalTwist) * uv;

    //----------------------------------------------------
    // 4. WarpFlow
    //----------------------------------------------------
    uv += vec2(
        sin(uv.y*2.2 + t*1.5)*0.12*WarpFlow,
        cos(uv.x*2.8 - t*1.2)*0.12*WarpFlow
    );

    //----------------------------------------------------
    // 5. Filaments field (densité + micro chaos)
    //----------------------------------------------------
    float nField = softNoise(uv * Filling * 1.4 + t*0.3);
    float swirl = sin(uv.x * Stripe + nField*5.0 + t*1.1) +
                  cos(uv.y * Stripe*0.6 - nField*4.0 + t*0.7);
    swirl += softNoise(uv*density + t)*2.0;
    swirl += softNoise(uv*8.0 + t*2.0) * MicroChaos; // micro chaos
    float fil = abs(sin(swirl)) * 0.6 + (nField * 0.4);

    //----------------------------------------------------
    // 6. Pulsation simple
    //----------------------------------------------------
    float pulseMod = sin(t*1.4 + nField*8.0)*0.5 + 0.5;
    float field = fil * pulseMod;

    //----------------------------------------------------
    // 7. NoiseOverlay noir et blanc avec OverlayTwist
    //----------------------------------------------------
    // Coordonnées centrées pour tourbillon
    vec2 uvOverlay = uv;
    float angleOverlay = atan(uvOverlay.y, uvOverlay.x);
    float radiusOverlay = length(uvOverlay);
    uvOverlay = vec2(cos(angleOverlay + t*OverlayTwist), sin(angleOverlay + t*OverlayTwist)) * radiusOverlay;

    float overlayNoise = softNoise(uvOverlay*12.0 + t*2.0)*2.0 - 1.0; // [-1,1]

    // Lighten/Darken effect en noir et blanc
    field = overlayNoise > 0.0 ? max(field, field + overlayNoise*NoiseOverlay) : min(field, field + overlayNoise*NoiseOverlay);

    //----------------------------------------------------
    // 8. Colors + Glow
    //----------------------------------------------------
	vec2 modified_uv = transform_uv(UV, vec2(0.5), rotation_angle, uv_offset, uv_scale);
    float bw_intensity = step(0.5,modified_uv.x);
	vec3 col = vec3(bw_intensity);

    // Glow effect
    col += pow(field, 2.5) * Glow;
	vec4 tex_color = texture(TEXTURE,UV);
	if (tex_color.a > 0.0)
	{
    COLOR = vec4(1.0-col, 1.0);
	}
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
