shader_type spatial;
uniform float wetness = 0.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(41.2,19.7)))*9514.7); }
void fragment() {
 float grain = hash(floor(world_position.xz*12.0));
 float seams = step(0.985,fract(world_position.x/13.0))*0.018;
 float puddle = smoothstep(0.4,0.7,sin(world_position.x*0.09)*sin(world_position.z*0.07));
 ALBEDO = mix(vec3(0.11,0.135,0.15),vec3(0.055,0.074,0.09),wetness) + grain*0.028-seams;
 ROUGHNESS = mix(0.92,0.19,wetness*(0.55+puddle*0.45));
 METALLIC = wetness*0.15;
 SPECULAR = mix(0.2,0.8,wetness);
}
