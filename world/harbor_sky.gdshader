shader_type sky;

uniform sampler2D clouds : source_color, filter_linear_mipmap, repeat_enable;
uniform float evening : hint_range(0.0, 1.0);
uniform float night : hint_range(0.0, 1.0);

void sky() {
	vec3 daylight = texture(clouds, SKY_COORDS).rgb;
	float height = max(EYEDIR.y, 0.0);
	float horizon = exp(-height * 4.5);
	float west = pow(max(dot(EYEDIR, normalize(vec3(-0.86, 0.08, 0.49))), 0.0), 2.5);
	vec3 dusk = daylight * vec3(0.89, 0.56, 0.49) + vec3(0.52, 0.22, 0.075) * west * horizon;
	vec3 midnight = mix(vec3(0.009, 0.019, 0.055), vec3(0.10, 0.15, 0.225), horizon);
	midnight += daylight * vec3(0.03, 0.04, 0.066);
	float moon = smoothstep(0.99978,0.99992,dot(EYEDIR, normalize(vec3(0.37,0.38,-0.85))));
	midnight += vec3(0.82, 0.86, 0.88)*moon;
	COLOR = mix(mix(daylight, dusk, evening), midnight, night);
}
