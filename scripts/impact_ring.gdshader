shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Camera-facing shock ring for a landed hit (arena_3d.gd): a thin bright
// rim that thins and fades as `progress` runs 0 -> 1.
uniform vec3 color : source_color = vec3(1.0, 0.85, 0.5);
uniform float progress = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]) * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float edge = 0.55 + 0.45 * progress;
	float width = mix(0.22, 0.05, progress);
	float rim = smoothstep(edge - width, edge, r) * (1.0 - smoothstep(edge, edge + 0.04, r));
	float fade = 1.0 - progress;
	ALBEDO = color * rim * fade * 0.9;
	ALPHA = rim * fade * 0.7;
}
