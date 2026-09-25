shader_type spatial;
// Keep the artist's baked colour; add small-scale stone grain and wear in
// world space so large surfaces do not read as perfectly smooth plastic.
uniform sampler2D color_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.85;
uniform float wetness = 0.0;
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
	float grain = noise(world_pos * 32.0);
	float weather = noise(world_pos * 1.8);
	float damp = wetness * smoothstep(0.42, 0.72, weather) * max(world_normal.y, 0.0);
	ALBEDO = texture(color_texture, UV).rgb * tint.rgb * (0.88 + grain * 0.16) * (1.0 - damp * 0.22);
	ROUGHNESS = clamp(roughness + grain * 0.1 - damp * 0.45, 0.22, 1.0);
	// Derivative bump keeps grain subtle at distance and avoids noisy normal maps.
	vec3 bump = cross(dFdx(VERTEX), NORMAL) * dFdy(grain) + cross(NORMAL, dFdy(VERTEX)) * dFdx(grain);
	NORMAL = normalize(NORMAL + bump * 0.12);
}
