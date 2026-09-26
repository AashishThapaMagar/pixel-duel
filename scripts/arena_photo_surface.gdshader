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
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x), mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x), mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
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
	// Rain-darkened patches on upward faces at night.
	float damp = wetness * smoothstep(0.45, 0.75, noise(world_pos * 1.6)) * max(n.y, 0.0);
	float grey = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(vec3(grey), col, saturation);
	ALBEDO = col * tint.rgb * (1.0 - damp * 0.25);
	ROUGHNESS = clamp(rough - damp * 0.5, 0.2, 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
}
