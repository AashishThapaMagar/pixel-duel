shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float halo = pow(max(0.0, 1.0 - radius), 3.0);
	ALBEDO = vec3(1.0, 0.38, 0.075);
	ALPHA = halo * 0.24;
}
