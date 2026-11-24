shader_type spatial;
render_mode specular_schlick_ggx;
uniform float night_amount = 0.4;
varying vec3 world_normal;
varying vec3 world_position;
varying vec3 building_color;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
 building_color = COLOR.rgb;
}
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 plane = vec2(abs(world_normal.x)>0.5 ? world_position.z : world_position.x,world_position.y);
 vec2 cell = plane/vec2(3.6,3.4);
 vec2 grid = fract(cell);
 float wall = 1.0-step(0.6,abs(world_normal.y));
 float window = step(0.17,grid.x)*step(grid.x,0.83)*step(0.2,grid.y)*step(grid.y,0.77)*wall;
 float lit = step(0.53,hash21(floor(cell)));
 float variation = hash21(floor(plane/vec2(21.6,80.0)));
 // Narrow pilasters and horizontal spandrels break up the modular window grid.
 float pilaster = 1.0-smoothstep(0.035,0.075,abs(fract(plane.x/7.2)-0.5));
 float floor_band = 1.0-smoothstep(0.035,0.075,abs(grid.y-0.08));
 float sill = step(0.76,grid.y)*step(grid.y,0.82)*step(0.12,grid.x)*step(grid.x,0.88)*wall;
 vec3 masonry = building_color*mix(0.48,0.66,variation);
 masonry *= 1.0-pilaster*wall*0.25-floor_band*wall*0.18;
 masonry = mix(masonry,masonry*1.2,sill);
 vec3 glass = mix(vec3(0.027,0.047,0.063),vec3(0.085,0.13,0.16),grid.y);
 glass *= mix(0.65,1.0,hash21(floor(cell)+2.0));
 // Street-level doors and display windows have taller, wider divisions.
 float street = (1.0-step(3.55,world_position.y))*wall;
 float shop = step(0.1,fract(plane.x/5.4))*step(fract(plane.x/5.4),0.89)*step(0.45,world_position.y)*street;
 ALBEDO = mix(masonry,glass,window);
 ALBEDO = mix(ALBEDO,vec3(0.025,0.045,0.052),shop);
 ROUGHNESS = mix(0.88,0.38,max(window,shop));
 METALLIC = max(window,shop)*0.12;
 SPECULAR = 0.28;
 AO = mix(0.78,0.92,window)*(1.0-street*0.18);
 EMISSION = vec3(1.0,0.59,0.25)*(window*lit*0.35+shop*0.13)*night_amount;
}
