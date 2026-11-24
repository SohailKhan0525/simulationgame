shader_type spatial;
uniform float night_amount = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 facade = vec2(abs(world_normal.x)>0.5 ? world_position.z : world_position.x, world_position.y);
	vec2 cell = floor(facade / vec2(3.8,3.15));
	float occupied = step(0.66,fract(sin(dot(cell,vec2(12.7,91.3)))*43758.5));
	ALBEDO = vec3(0.065,0.105,0.13);
	METALLIC = 0.28;
	ROUGHNESS = 0.28;
	SPECULAR = 0.55;
	EMISSION = vec3(0.75,0.47,0.21)*occupied*night_amount*0.65;
}
