shader_type spatial;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 p = world_position.xz;
	vec2 slab = p / 1.5;
	vec2 edge = min(fract(slab), 1.0 - fract(slab));
	float seam = 1.0 - smoothstep(0.005, 0.018, min(edge.x, edge.y));
	float variation = hash21(floor(slab));
	float grain = hash21(floor(p * 110.0)) - 0.5;
	ALBEDO = mix(vec3(0.37,0.38,0.35),vec3(0.46,0.45,0.41),variation) + grain * 0.018;
	ALBEDO *= 1.0 - seam * 0.24;
	ROUGHNESS = 0.94;
	SPECULAR = 0.16;
}
