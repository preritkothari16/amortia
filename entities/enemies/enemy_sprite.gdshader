// Runner sprite recolour (visual only): genes tint the rotting skin and brighten the bloom, and a
// hit flashes the sprite white. Skin = green-dominant pixels, bloom = bright red-dominant pixels.
shader_type canvas_item;

uniform vec4 skin_tint : source_color = vec4(1.0);
uniform float bloom_boost = 1.0;
uniform float flash = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float skin = step(c.r + 0.02, c.g) * step(c.b, c.g);
	float bloom = step(c.g + 0.15, c.r) * step(0.5, c.r);
	vec3 col = mix(c.rgb, c.rgb * skin_tint.rgb, skin);
	col = mix(col, min(col * bloom_boost, vec3(1.0)), bloom);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, c.a) * COLOR;
}
