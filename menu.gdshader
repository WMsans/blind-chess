shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 tex_color = texture(TEXTURE,UV);
	float Speed = 1.0;
	float Blur = 0.7;
	float Angle = 0.78;
	float Zoom = 15.0;
    vec2 RENDERSIZE = 1.0/SCREEN_PIXEL_SIZE;
    vec2 uv = (FRAGCOORD.xy-0.5*RENDERSIZE.xy)/RENDERSIZE.y;
    
    vec3 col = vec3(0);
    
    
    float a = Angle;
    float s = sin(a);
    float c = cos(a);
    uv *= mat2(vec2(c, -s), vec2(s, c));
    
    
    uv *=Zoom;
    
    vec2 gv = fract ( uv )-0.5;
    vec2 id = floor(uv);
    
    float m = 0.;
    
    float t = TIME*Speed;
    
    
    for(float y =-1.; y <=1.0; y++){
        for(float x =-1.; x <=1.0; x++){
            vec2 offs = vec2(x, y);
            
            float d = length(gv-offs);
            
            float dist = length(id+offs)*.3;
            
            float r = mix(0.3, 1.5, sin(dist-t)*0.5+0.5);
            
            m = mod(m + smoothstep(r,r*Blur,d),2.0);
           
            }
        }
    //col.rg = gv;
    
    col += m;
    if (tex_color.a > 0.0)
	{
    	COLOR = vec4(col,1.0);
	}
}


//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
