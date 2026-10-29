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
// Zone look (0 Maple Hollow, 1 Lowtide, 2 Greywood, 3 Sunnyseed Labs) and the atlas columns of
// the terrains it restyles; Atmosphere fills these from the tileset. Colour only, never geometry.
// 1 only on the terrain layer; decals and corpses share the grade but keep their own colours.
uniform float restyle = 0.0;
uniform int zone = 0;
uniform float columns = 21.0;
uniform float col_road = 0.0;
uniform float col_grass = 1.0;
uniform float col_tall = 2.0;
uniform float col_wall = 4.0;
uniform float col_house = 5.0;
// -1 = not in this tileset (never matches).
uniform float col_fence = -1.0;
uniform float col_door = -1.0;
uniform float col_door_open = -1.0;
uniform float col_barricade = -1.0;
uniform float col_tree = -1.0;
uniform float col_living = -1.0;
uniform float col_gate = -1.0;

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

bool is_col(float a, float b) {
	return abs(a - b) < 0.5;
}

// Replaces the flat greybox colour of roads, grass, walls and houses with a per-zone surface.
// Patterns are in world pixels (not per tile), so a 4x4 block of house tiles reads as one roof.
vec3 zone_surface(vec3 base, float col, vec2 px) {
	vec2 loc = mod(px, 16.0);
	float tile_edge = step(loc.x, 1.0) + step(loc.y, 1.0);
	float n = noise(px / 11.0);
	float big = noise(px / 29.0 + 5.0);
	float h = hash(floor(px / 2.0));
	if (is_col(col, col_house)) {
		float row = floor(px.y / 3.0);
		float shingle = hash(vec2(floor((px.x + mod(row, 2.0) * 3.0) / 6.0), row));
		float gap = step(mod(px.y, 3.0), 0.99);
		vec3 roof;
		if (zone == 0) {
			roof = vec3(0.50, 0.40, 0.36) * (0.8 + 0.35 * shingle);
		} else if (zone == 1) {
			roof = vec3(0.30, 0.46, 0.48) * (0.82 + 0.3 * shingle);
			roof *= 1.0 - 0.35 * smoothstep(0.55, 0.8, big);  // water stains
		} else if (zone == 2) {
			// Rotting wood shingles, moss only in patches, so a roof still stands out from the grass.
			roof = mix(vec3(0.36, 0.31, 0.25), vec3(0.2, 0.32, 0.16), smoothstep(0.55, 0.75, big + 0.25 * n)) * (0.8 + 0.3 * shingle);
		} else {
			roof = vec3(0.66, 0.7, 0.74) * (0.94 + 0.08 * shingle);
			roof *= 1.0 - 0.18 * step(mod(px.x, 8.0), 0.99) - 0.18 * step(mod(px.y, 8.0), 0.99);
			roof = mix(roof, vec3(0.8, 0.12, 0.12), step(0.985, hash(floor(px / 4.0))));
		}
		return roof * (1.0 - 0.26 * gap) * (1.0 - 0.14 * tile_edge);
	}
	if (is_col(col, col_wall)) {
		if (zone == 0) {
			float seam = step(mod(px.y, 4.0), 0.99) + step(mod(px.x + mod(floor(px.y / 4.0), 2.0) * 4.0, 8.0), 0.99);
			return vec3(0.5, 0.48, 0.45) * (0.9 + 0.2 * h) * (1.0 - 0.3 * clamp(seam, 0.0, 1.0));
		} else if (zone == 1) {
			float drip = noise(vec2(px.x * 1.7, px.y / 22.0));
			return vec3(0.34, 0.5, 0.52) * (0.7 + 0.5 * drip) * (0.92 + 0.1 * h);
		} else if (zone == 2) {
			float leaf = noise(px / 3.0);
			return mix(vec3(0.1, 0.24, 0.1), vec3(0.24, 0.46, 0.16), leaf) * (0.85 + 0.25 * h);
		}
		vec3 steel = vec3(0.56, 0.6, 0.66) * (0.94 + 0.1 * h);
		steel *= 1.0 - 0.3 * (step(mod(px.x, 8.0), 0.99) + step(mod(px.y, 8.0), 0.99)) * 0.5;
		float hazard = step(28.0, mod(px.y, 32.0)) * step(mod(px.x + px.y, 8.0), 3.99);
		float band = step(28.0, mod(px.y, 32.0));
		return mix(steel, mix(vec3(0.14), vec3(0.85, 0.68, 0.1), hazard), band);
	}
	if (is_col(col, col_fence)) {
		// Weathered boards with dark gaps and two rails; Greywood's are a log palisade, the
		// Labs' a steel mesh panel. Solid all over: a fence never shows ground through it.
		float frame = step(loc.x, 0.99) + step(14.99, loc.x) + step(loc.y, 0.99) + step(14.99, loc.y);
		if (zone == 3) {
			float mesh = step(mod(px.x + px.y, 4.0), 0.99) + step(mod(px.x - px.y, 4.0), 0.99);
			vec3 plate = vec3(0.34, 0.36, 0.4) * (1.0 - 0.3 * clamp(mesh, 0.0, 1.0));
			return mix(plate, vec3(0.55, 0.58, 0.62), clamp(frame, 0.0, 1.0));
		}
		float along = zone == 2 ? loc.y : loc.x;
		float across = zone == 2 ? loc.x : loc.y;
		float board_id = floor(along / 3.0) + floor((zone == 2 ? px.y : px.x) / 16.0) * 5.0;
		float bh = hash(vec2(board_id, zone == 2 ? floor(px.x / 16.0) : floor(px.y / 16.0)));
		float gap = step(mod(along, 3.0), 0.99);
		vec3 wood = vec3(0.4, 0.31, 0.22);
		if (zone == 0) {  // white paint flaking off grey wood
			wood = mix(vec3(0.66, 0.63, 0.57), vec3(0.38, 0.32, 0.26), step(0.56, noise(px / vec2(2.0, 4.0) + bh * 9.0)));
		} else if (zone == 1) {  // salt-grey driftwood, green slime low down
			wood = mix(vec3(0.46, 0.47, 0.45), vec3(0.18, 0.32, 0.26), step(12.0, loc.y) * step(0.4, h));
		} else if (zone == 2) {
			wood = vec3(0.3, 0.21, 0.13) * (1.0 - 0.25 * step(mod(across + bh * 7.0, 6.0), 0.99));
		}
		wood *= 0.82 + 0.3 * bh;
		float rail = zone == 2 ? 0.0 : step(3.0, loc.y) * step(loc.y, 4.99) + step(11.0, loc.y) * step(loc.y, 12.99);
		wood = mix(wood, wood * 0.62, clamp(rail, 0.0, 1.0));
		return wood * (1.0 - 0.6 * gap);
	}
	if (is_col(col, col_door)) {
		// Boarded-up door: dark planks, two lighter boards nailed across, a frame.
		vec3 planks = vec3(0.24, 0.16, 0.1) * (0.85 + 0.25 * hash(vec2(floor(loc.x / 4.0), floor(px.y / 16.0))));
		planks *= 1.0 - 0.4 * step(mod(loc.x, 4.0), 0.99);
		float board = step(3.0, loc.y) * step(loc.y, 5.99) + step(10.0, loc.y) * step(loc.y, 12.99);
		vec3 c = mix(planks, vec3(0.48, 0.36, 0.24), clamp(board, 0.0, 1.0));
		c = mix(c, vec3(0.75, 0.72, 0.65), board * step(abs(loc.x - 3.5), 0.5));
		c = mix(c, vec3(0.75, 0.72, 0.65), board * step(abs(loc.x - 12.5), 0.5));
		if (zone == 3) {  // sealed lab door: steel with a red lock light
			c = vec3(0.4, 0.42, 0.46) * (1.0 - 0.3 * step(abs(loc.x - 7.5), 0.6));
			c = mix(c, vec3(0.9, 0.15, 0.12), step(abs(loc.x - 11.5), 0.6) * step(abs(loc.y - 7.5), 0.6));
		}
		return mix(c, vec3(0.08, 0.08, 0.09), clamp(step(loc.x, 0.99) + step(14.99, loc.x), 0.0, 1.0));
	}
	if (is_col(col, col_door_open)) {
		// Broken-open doorway: dark interior inside the frame, splinters on the threshold.
		vec3 c = vec3(0.07, 0.075, 0.09) + 0.05 * step(0.93, h);
		c = mix(c, vec3(0.3, 0.2, 0.12), clamp(step(loc.x, 0.99) + step(14.99, loc.x), 0.0, 1.0));
		return c;
	}
	if (is_col(col, col_barricade)) {
		// Scrap barricade: diagonal planks over a rusted sheet.
		float diag = mod(px.x + px.y, 6.0);
		vec3 sheet = mix(vec3(0.42, 0.28, 0.2), vec3(0.64, 0.28, 0.2), step(0.6, noise(px / 3.0)));
		vec3 plank = vec3(0.5, 0.38, 0.25) * (0.85 + 0.25 * hash(vec2(floor((px.x + px.y) / 6.0), 1.0)));
		vec3 c = mix(sheet, plank, step(diag, 3.49));
		return c * (1.0 - 0.35 * step(abs(diag - 3.5), 0.5));
	}
	if (is_col(col, col_tree)) {
		// Canopy: leaf clusters, dark gaps, a few lit leaves. One colour set per zone.
		float leaf = noise(px / 3.2) * 0.6 + noise(px / 7.0 + 3.0) * 0.4;
		vec3 dark = vec3(0.07, 0.12, 0.07);
		vec3 mid = vec3(0.2, 0.3, 0.14);
		vec3 lit = vec3(0.34, 0.42, 0.2);
		if (zone == 0) {
			mid = vec3(0.3, 0.3, 0.16); lit = vec3(0.45, 0.4, 0.22);  // dying, brown-edged
		} else if (zone == 1) {
			mid = vec3(0.14, 0.28, 0.24); lit = vec3(0.26, 0.4, 0.34);
		} else if (zone == 2) {
			dark = vec3(0.03, 0.07, 0.04); mid = vec3(0.1, 0.22, 0.1); lit = vec3(0.2, 0.34, 0.15);
		} else {
			mid = vec3(0.26, 0.2, 0.24); lit = vec3(0.4, 0.26, 0.3);  // grey-purple, infected
		}
		vec3 c = mix(dark, mid, smoothstep(0.3, 0.5, leaf));
		return mix(c, lit, step(0.72, leaf) * step(0.4, h));
	}
	if (is_col(col, col_living)) {
		// Living wall: dried-blood flesh, slowly pulsing veins, dark nodules.
		float vein = 1.0 - smoothstep(0.0, 0.07, abs(noise(px / 5.0) - 0.5));
		float pulse = 0.75 + 0.25 * sin(TIME * 2.2 + noise(px / 13.0) * 6.28);
		vec3 c = vec3(0.43, 0.15, 0.17) * (0.8 + 0.3 * n);
		c = mix(c, vec3(0.82, 0.24, 0.24) * pulse, vein);
		return mix(c, vec3(0.1, 0.06, 0.07), step(0.975, hash(floor(px / 2.0))));
	}
	if (is_col(col, col_gate)) {
		// Exit gate keeps its bright hazard yellow (it must be easy to find); black chevrons, rust.
		float stripe = step(mod(px.x + px.y, 8.0), 3.49);
		vec3 c = mix(vec3(0.9, 0.72, 0.18), vec3(0.12, 0.11, 0.1), stripe * 0.85);
		return mix(c, vec3(0.6, 0.3, 0.16), step(0.8, noise(px / 4.0)) * 0.6);
	}
	bool road = is_col(col, col_road);
	bool grass = is_col(col, col_grass);
	bool tall = is_col(col, col_tall);
	if (zone == 0) {
		if (grass) {
			base = mix(base, vec3(0.5, 0.5, 0.36), 0.55) * (0.88 + 0.22 * n);  // dry suburban lawn
		} else if (road) {
			// Dark, sun-bleached asphalt with lighter aggregate.
			base = mix(base, vec3(0.42, 0.42, 0.43), 0.6) * (0.9 + 0.15 * n) + 0.05 * step(0.9, h);
		}
	} else if (zone == 1) {
		if (road) {
			float wet = smoothstep(0.5, 0.62, big + 0.3 * n);
			base = mix(base * 0.95, base * vec3(0.55, 0.75, 0.8), wet) + 0.07 * step(0.96, h) * wet;
		} else if (grass) {
			base = mix(base, vec3(0.26, 0.5, 0.46), 0.55) * (0.85 + 0.3 * n);
		}
	} else if (zone == 2) {
		if (road) {
			base = mix(base, vec3(0.43, 0.32, 0.2), 0.65);
			base = mix(base, vec3(0.16, 0.34, 0.12), smoothstep(0.52, 0.68, big + 0.3 * n) * 0.8);
		} else if (grass) {
			base = mix(base, vec3(0.16, 0.4, 0.13), 0.55) * (0.78 + 0.35 * n);
		}
	} else if (zone == 3) {
		if (road || grass) {
			vec3 floor_col = road ? vec3(0.64, 0.68, 0.72) : vec3(0.4, 0.45, 0.52);
			float checker = mod(floor(px.x / 16.0) + floor(px.y / 16.0), 2.0);
			base = floor_col * (0.95 + 0.07 * checker) * (1.0 - 0.2 * tile_edge) * (0.97 + 0.05 * h);
		} else if (tall) {
			base = mix(base, vec3(0.45, 0.1, 0.14), 0.45);  // infected growth
		}
	}
	// Cracked asphalt / concrete: thin wandering cracks, only in some patches of the road.
	// The line where a noise field crosses 0.5, about 1 px wide wherever the field is steep or flat.
	if (road && zone != 2) {
		vec2 q = px / 9.0 + 3.1;
		float c0 = noise(q);
		float slope = abs(noise(q + vec2(1.0 / 9.0, 0.0)) - c0) + abs(noise(q + vec2(0.0, 1.0 / 9.0)) - c0);
		float crack = step(abs(c0 - 0.5), max(slope * 0.55, 0.002));
		base *= 1.0 - 0.45 * crack * step(zone == 3 ? 0.68 : 0.6, noise(px / 31.0 + 9.0));
	}
	return base;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 px = floor(world) + 0.5;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 surface = restyle > 0.5 ? zone_surface(c.rgb, floor(UV.x * columns), px) : c.rgb;
	l = dot(surface, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(vec3(l), surface, saturation) * tint.rgb;
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
