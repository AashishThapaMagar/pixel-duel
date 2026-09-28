shader_type spatial;
// Photo-scanned surface (Poly Haven CC0, see assets/arenas/textures/) laid
// out in world space at its real-world size, so the imported models need no
// special UVs and bricks stay brick-sized on every surface.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap, repeat_enable;
// Metres covered by one repeat of the texture.
uniform float world_size = 2.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_strength = 1.0;
uniform float wetness = 0.0;
// Pushes colour away from grey; the scans are shot under flat, neutral light.
uniform float saturation = 1.0;
// How strongly the large-scale variation breaks up repeats (0 = off).
uniform float macro_strength = 0.55;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	// The arenas are almost all flat faces, so project from the one axis the
	// face points along: one texture fetch per map instead of three.
	vec3 an = abs(n);
	vec3 p = world_pos / world_size;
	vec2 uv;
	vec3 tangent;
	vec3 bitangent;
	if (an.y >= an.x && an.y >= an.z) {
		uv = vec2(p.x, p.z * sign(n.y));
		tangent = vec3(1.0, 0.0, 0.0);
		bitangent = vec3(0.0, 0.0, sign(n.y));
	} else if (an.x >= an.z) {
		uv = vec2(p.z * sign(n.x), -p.y);
		tangent = vec3(0.0, 0.0, sign(n.x));
		bitangent = vec3(0.0, -1.0, 0.0);
	} else {
		uv = vec2(-p.x * sign(n.z), -p.y);
		tangent = vec3(-sign(n.z), 0.0, 0.0);
		bitangent = vec3(0.0, -1.0, 0.0);
	}
	vec3 col = texture(albedo_map, uv).rgb;
	float rough = texture(roughness_map, uv).r;
	vec3 t = texture(normal_map, uv).rgb * 2.0 - 1.0;
	// OpenGL-style normal map: +Y points up the texture, opposite to v.
	vec3 bent = normalize(tangent * t.x * normal_strength - bitangent * t.y * normal_strength + n * max(t.z, 0.2));
	// Anti-tiling: the same scan sampled ~7x larger and rotated acts as a soft
	// light/dark map, so identical repeats never line up across a wall or
	// floor. Its tiniest mip is the scan's average, used to centre it. Two
	// cheap texture reads instead of per-pixel procedural noise.
	const vec3 LUMA = vec3(0.3, 0.59, 0.11);
	vec2 macro_uv = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * (uv * 0.137) + vec2(0.37, 0.61);
	float macro = dot(texture(albedo_map, macro_uv).rgb, LUMA);
	float average = max(dot(textureLod(albedo_map, vec2(0.5), 12.0).rgb, LUMA), 0.02);
	float variation = clamp(macro / average, 0.6, 1.45);
	col *= mix(1.0, variation, macro_strength);
	// Rain-darkened patches on upward faces at night, from the same map.
	float damp = 0.0;
	if (wetness > 0.0) {
		damp = wetness * smoothstep(0.95, 1.2, variation) * max(n.y, 0.0);
	}
	float grey = dot(col, LUMA);
	col = mix(vec3(grey), col, saturation);
	// Contact grime: walls darken toward the ground they stand on, and the
	// underside of every ledge is shaded, standing in for the ambient
	// occlusion the Compatibility renderer cannot compute on screen.
	float upright = 1.0 - abs(n.y);
	float footing = (1.0 - smoothstep(-0.2, 1.1, world_pos.y)) * upright;
	float underside = smoothstep(-0.2, -0.9, n.y);
	float occlusion = 1.0 - footing * 0.35 - underside * 0.45;
	ALBEDO = col * tint.rgb * (1.0 - damp * 0.25) * occlusion;
	AO = occlusion;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = clamp(rough - damp * 0.5, 0.2, 1.0);
	// Wet stone and fired brick both pick up a small, tight highlight.
	SPECULAR = mix(0.28, 0.55, damp);
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
}
