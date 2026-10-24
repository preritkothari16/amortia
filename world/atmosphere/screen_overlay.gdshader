// Screen overlay above the world, below the HUD (visual only): drifting fog that thins around
// the player, a vignette, and a red edge pulse when the player is hurt. Chunky on purpose: fog
// is sampled on the 480 x 270 layout grid, like the rest of the pixel art.
shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.55, 0.6, 0.5, 1.0);
uniform float fog_amount = 0.14;
uniform float vignette = 0.6;
uniform float hurt = 0.0;
// World position of the screen centre, so the fog drifts with the world, not with the screen.
uniform vec2 view_origin = vec2(0.0);
uniform vec2 view_size = vec2(480.0, 270.0);

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

void fragment() {
	vec2 cell = floor(UV * view_size / 2.0) * 2.0;  // 2-px fog cells
	vec2 p = cell + view_origin;
	float n = noise(p / 52.0 + TIME * vec2(0.06, 0.025)) * 0.65 + noise(p / 17.0 - TIME * vec2(0.03, 0.05)) * 0.35;
	vec2 d = (UV - 0.5) * vec2(view_size.x / view_size.y, 1.0);
	float r = length(d);
	float clear = smoothstep(0.10, 0.55, r);
	float fog = fog_amount * n * (0.3 + 0.7 * clear);
	float vig = vignette * smoothstep(0.45, 1.05, r);
	float edge = hurt * 0.55 * smoothstep(0.35, 1.0, r);
	// Layer fog, then the dark vignette, then the hurt tint ("over", premultiplied).
	vec3 pm = fog_color.rgb * fog;
	float a = fog;
	pm = pm * (1.0 - vig);
	a = vig + a * (1.0 - vig);
	pm = vec3(0.5, 0.02, 0.02) * edge + pm * (1.0 - edge);
	a = edge + a * (1.0 - edge);
	COLOR = vec4(pm / max(a, 0.0001), a);
}
