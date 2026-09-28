shader_type canvas_item;
// Finishing pass drawn over the 3D arena and under the HUD (see
// nepal_stage_3d.gd _grade): the per-arena colour grade, a soft vignette,
// and the short punch that sells an impact. One full-screen read, so it
// costs the same on every quality level and every renderer.
uniform sampler2D screen : hint_screen_texture, filter_linear;
// Lift and gain: what the darks and the brights are pushed toward.
uniform vec3 shadow_tint : source_color = vec3(1.0);
uniform vec3 highlight_tint : source_color = vec3(1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float vignette = 0.3;
// Impact punch: a soft ring of light spreading out from the hit, fading
// with `punch` (1 at the moment of contact).
uniform float punch = 0.0;
uniform vec2 punch_center = vec2(0.5, 0.5);
uniform vec3 punch_color : source_color = vec3(1.0, 0.85, 0.6);
// Whole-screen flash and drain of colour (round-ending knockouts).
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float drain = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_hit = uv - punch_center;
	from_hit.x *= 1.777;
	vec3 col = texture(screen, uv).rgb;
	if (punch > 0.002) {
		// A soft, brief pressure ring spreading from the hit: no colour
		// fringing or glitching, just a breath of light across the scene.
		float radius = (1.0 - punch) * 0.45 + 0.05;
		float ring = exp(-pow((length(from_hit) - radius) * 14.0, 2.0)) * punch * 0.12;
		col += punch_color * ring;
	}
	float luma = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(vec3(luma), col, saturation * (1.0 - drain));
	col = max((col - 0.5) * contrast + 0.5, vec3(0.0));
	col *= mix(shadow_tint, highlight_tint, smoothstep(0.0, 0.85, luma));
	vec2 centred = (uv - 0.5) * vec2(1.2, 1.0);
	col *= 1.0 - vignette * smoothstep(0.42, 0.98, length(centred));
	col = mix(col, flash_color, flash);
	COLOR = vec4(col, 1.0);
}
