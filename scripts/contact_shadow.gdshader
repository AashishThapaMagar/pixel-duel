shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
// Soft blob under each fighter (arena_3d.gd): grounds them on the dais
// whatever the moon or lamps are doing, and shrinks and fades as they jump.
uniform float strength = 0.55;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float blob = 1.0 - smoothstep(0.2, 1.0, r);
	blob *= blob;
	ALBEDO = vec3(0.02, 0.02, 0.035);
	ALPHA = strength * blob;
}
