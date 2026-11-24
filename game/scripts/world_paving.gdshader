shader_type spatial;
uniform sampler2D mineral_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mineral_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mineral_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mineral_ao : filter_linear_mipmap_anisotropic, repeat_enable;
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
	ALBEDO *= 0.85+texture(mineral_albedo,p/2.8).r*0.5;
	ROUGHNESS = texture(mineral_roughness,p/2.8).r;
	NORMAL_MAP=texture(mineral_normal,p/2.8).rgb;
	NORMAL_MAP_DEPTH=0.45;
	AO=texture(mineral_ao,p/2.8).r;
	SPECULAR = 0.16;
}
