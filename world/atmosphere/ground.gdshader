// Ground look for the terrain TileMapLayer (visual only): zone colour grade, grime, pixel grit,
// a dark ambient with a dithered warm light pool around the player, and muzzle-flash light.
// Everything is computed on the 1-world-px grid (= one tile texel), so it stays pixel art.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 shade : source_color = vec4(0.04, 0.05, 0.07, 1.0);
uniform float darkness = 0.5;
uniform float saturation = 0.6;
uniform vec2 light_pos = vec2(0.0);
uniform float light_radius = 120.0;
uniform vec4 light_color : source_color = vec4(1.0, 0.8, 0.58, 1.0);
uniform vec2 flash_pos = vec2(0.0);
uniform float flash = 0.0;

varying vec2 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 4x4 ordered dither threshold in [0, 1).
float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[y * 4 + x]) / 16.0;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 px = floor(world) + 0.5;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(vec3(l), c.rgb, saturation) * tint.rgb;
	// Grime: large dark patches and mid-scale mottling break up the tile repeat; binary grit
	// per texel keeps the surface crunchy instead of smooth.
	col *= 0.74 + 0.34 * noise(px / 46.0);
	col *= 0.90 + 0.14 * noise(px / 9.0 + 17.0);
	col *= 0.93 + 0.09 * step(0.55, hash(px));
	// Light: dark ambient everywhere, a warm pool around the player with dithered bands.
	float lit = clamp(1.0 - distance(px, light_pos) / light_radius, 0.0, 1.0);
	lit = clamp(floor(lit * 5.0 + bayer(px)) / 5.0, 0.0, 1.0);
	vec3 dark = mix(col, shade.rgb, darkness);
	vec3 bright = col * mix(vec3(1.0), light_color.rgb, 0.3) * 1.06;
	col = mix(dark, bright, lit);
	float f = flash * clamp(1.0 - distance(px, flash_pos) / 56.0, 0.0, 1.0);
	col += vec3(1.0, 0.55, 0.25) * floor(f * 4.0 + bayer(px)) / 4.0 * 0.55;
	COLOR = vec4(col, c.a);
}
