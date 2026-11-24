shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float plant_variation;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x += sin(TIME*1.4+p.x*0.13+p.z*0.11)*0.035*max(0.0,VERTEX.y+0.5);
 VERTEX.z += cos(TIME*1.1+p.z*0.1)*0.02;
 plant_variation=0.88+fract(sin(dot(MODEL_MATRIX[3].xz,vec2(12.7,91.3)))*43758.5)*0.18;
}
void fragment() {
 vec4 leaf=texture(leaf_atlas,UV);
 ALBEDO=leaf.rgb*plant_variation;
 ALPHA=leaf.a;
 ALPHA_SCISSOR_THRESHOLD=0.5;
 ROUGHNESS=0.94;
 SPECULAR=0.12;
 AO=0.9;
}
