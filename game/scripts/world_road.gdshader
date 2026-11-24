shader_type spatial;
uniform float wetness = 0.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(41.2,19.7)))*9514.7); }
float noise(vec2 p) {
 vec2 i = floor(p), f = fract(p);
 f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p = world_position.xz;
 float grain = noise(p*48.0)-0.5;
 float wear = noise(p*0.17);
 float puddle = smoothstep(0.55,0.76,noise(p*0.14));
 float seam = (1.0-smoothstep(0.015,0.055,abs(fract(p.x/23.0)-0.5)))*0.012;
 vec3 asphalt = vec3(0.105,0.111,0.112) + grain*0.022 + wear*0.028-seam;
 ALBEDO = asphalt * mix(1.0,0.62,wetness);
 ROUGHNESS = mix(0.93,0.16,wetness*(0.44+puddle*0.56));
 METALLIC = 0.0;
 SPECULAR = mix(0.25,0.62,wetness);
}
