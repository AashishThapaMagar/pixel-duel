shader_type canvas_item;
// Vignette and film grain over the 3D view (nepal_stage_3d.gd _apply_grade).
// One alpha-blended full-screen quad that never samples the screen, so it
// costs the same on an integrated GPU at any resolution scale.
// Premultiplied blend: result = COLOR.rgb + scene * (1 - COLOR.a), which
// lets one pass both darken (vignette, dark grain) and lift (light grain).
render_mode blend_premul_alpha, unshaded;

uniform float vignette = 0.4;   // corner darkening, 0..1
uniform float grain = 0.03;     // grain amplitude, 0..0.1

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	// Aspect-correct, so the falloff is round on a wide screen.
	vec2 centred = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float edge = smoothstep(0.32, 0.98, length(centred) * 1.1);
	float keep = 1.0 - vignette * edge * edge;
	// New grain 24 times a second, like film, not every frame.
	float frame = mod(floor(TIME * 24.0), 97.0);
	float n = (hash(floor(FRAGCOORD.xy) + frame * vec2(37.0, 17.0)) - 0.5) * 2.0 * grain;
	keep *= 1.0 - max(-n, 0.0);
	COLOR = vec4(vec3(max(n, 0.0) * 0.6 * keep), 1.0 - keep);
}
