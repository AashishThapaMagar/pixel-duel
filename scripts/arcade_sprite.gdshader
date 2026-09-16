shader_type canvas_item;
uniform vec4 clip_0 = vec4(0.0);
uniform vec4 clip_1 = vec4(0.0);
uniform vec4 clip_2 = vec4(0.0);
uniform vec4 clip_3 = vec4(0.0);
uniform vec4 clip_4 = vec4(0.0);
uniform vec4 clip_5 = vec4(0.0);
uniform vec4 clip_6 = vec4(0.0);
uniform vec4 clip_7 = vec4(0.0);
uniform vec4 clip_8 = vec4(0.0);
uniform vec4 clip_9 = vec4(0.0);
uniform vec4 clip_10 = vec4(0.0);
uniform vec4 clip_11 = vec4(0.0);
uniform vec4 clip_12 = vec4(0.0);
uniform vec4 clip_13 = vec4(0.0);
uniform vec4 clip_14 = vec4(0.0);
uniform vec4 clip_15 = vec4(0.0);
bool inside_clip(vec2 uv, vec4 bounds) {
	return uv.x >= bounds.x && uv.y >= bounds.y && uv.x < bounds.z && uv.y < bounds.w;
}
// Generated source sheets remain intact; discard their chroma-key backdrop.
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float rb = min(texel.r, texel.b);
	float key = smoothstep(0.35, 0.60, rb - texel.g) * smoothstep(0.60, 0.80, rb);
	// COLOR already contains the sampled texture and the fighter's modulation.
	COLOR.a *= 1.0 - key;
	// Suppress chroma spill on dark antialiased outlines without recoloring
	// opaque costume pixels: only near-magenta, low-green edge pixels qualify.
	float spill = smoothstep(0.08, 0.25, rb - texel.g) * (1.0 - smoothstep(0.04, 0.14, texel.g));
	COLOR.rgb = mix(COLOR.rgb, vec3(COLOR.g), spill);
	if (inside_clip(UV, clip_0) || inside_clip(UV, clip_1) || inside_clip(UV, clip_2) || inside_clip(UV, clip_3) || inside_clip(UV, clip_4) || inside_clip(UV, clip_5) || inside_clip(UV, clip_6) || inside_clip(UV, clip_7) || inside_clip(UV, clip_8) || inside_clip(UV, clip_9) || inside_clip(UV, clip_10) || inside_clip(UV, clip_11) || inside_clip(UV, clip_12) || inside_clip(UV, clip_13) || inside_clip(UV, clip_14) || inside_clip(UV, clip_15)) {
		COLOR.a = 0.0;
	}
}
