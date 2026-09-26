shader_type spatial;
render_mode cull_disabled;
// Distant terrain: grass and forest on the low slopes, bare rock on steep
// faces, snow on high ground that isn't too steep to hold it. Aerial scans
// (Poly Haven CC0) are laid on from above at kilometre scale, and the whole
// surface fades toward the sky colour with distance (aerial perspective).
uniform sampler2D snow_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_map : source_color, filter_linear_mipmap, repeat_enable;
uniform float snow_line = 999.0;
uniform float terraces = 0.0;
uniform vec3 haze_color : source_color = vec3(0.7, 0.8, 0.9);
uniform float haze_start = 60.0;
uniform float haze_density = 0.004;
uniform float haze_max = 0.7;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	vec2 top = world_pos.xz;
	vec3 grass = texture(grass_map, top / 60.0).rgb * vec3(0.75, 0.95, 0.6);
	// Darker conifer patches break up the green slopes.
	float forest = smoothstep(0.45, 0.7, noise(top / 28.0));
	grass = mix(grass, grass * vec3(0.45, 0.6, 0.42), forest);
	vec3 rock = texture(rock_map, top / 90.0).rgb * vec3(0.78, 0.76, 0.8);
	vec3 snow = texture(snow_map, top / 140.0).rgb * 1.08;
	// Grass gives way to rock with height and steepness.
	float rocky = smoothstep(0.35, 0.65, slope) + smoothstep(12.0, 30.0, world_pos.y);
	vec3 col = mix(grass, rock, clamp(rocky, 0.0, 1.0));
	// Snow settles above the snow line, thinning out on steep faces.
	float line = snow_line + (noise(top / 18.0) - 0.5) * 14.0;
	float snowy = smoothstep(line, line + 10.0, world_pos.y) * (1.0 - smoothstep(0.55, 0.85, slope));
	col = mix(col, snow, snowy);
	// Rice-terrace lines along the contours of the foothills.
	if (terraces > 0.5) {
		float band = fract(world_pos.y / 1.4);
		float edge = smoothstep(0.0, 0.08, band) * smoothstep(1.0, 0.85, band);
		col *= mix(0.72, 1.0, edge) * mix(1.0, 1.0, slope);
	}
	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	float haze = clamp(1.0 - exp(-max(dist - haze_start, 0.0) * haze_density), 0.0, haze_max);
	ALBEDO = mix(col, haze_color, haze * 0.35);
	ROUGHNESS = mix(0.95, 0.6, snowy);
	// Haze also veils the lighting itself, so far peaks go soft and pale.
	EMISSION = haze_color * haze * 0.55;
}
