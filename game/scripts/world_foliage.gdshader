shader_type spatial;
render_mode cull_disabled;
varying vec3 foliage_color;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x += sin(TIME*1.4+p.x*0.13+p.z*0.11)*0.035*max(0.0,VERTEX.y+0.5);
 VERTEX.z += cos(TIME*1.1+p.z*0.1)*0.02;
 foliage_color=COLOR.rgb;
}
void fragment() {
 ALBEDO=foliage_color*vec3(0.42,0.53,0.43);
 ROUGHNESS=1.0;
 SPECULAR=0.12;
 AO=0.78;
}
