// Dark crypt overlay (Claude Code session, 2026-10-27).
// Purpose: darkens the live dungeon world except inside light circles (each
// player, braziers/torches, the Leerenrufer's beam, void bursts). The light
// falls off in a few hard bands on a 2-pixel grid so it matches the pixel art.
// Target: every desktop renderer (Forward+, Mobile, Compatibility); one quad,
// no texture reads, at most MAX_LIGHTS distance checks per fragment.
// Fed by src/vfx/darkness.gd; values come from balance.json "lighting".
shader_type canvas_item;

const int MAX_LIGHTS = 48;
// World pixels per light sample: the art is drawn at 2x.
const float PIXEL_GRID = 2.0;

group_uniforms lights;
// xy = world position, z = radius in world pixels, w = strength 0..1.
uniform vec4 lights[MAX_LIGHTS];
uniform int light_count = 0;
group_uniforms;

group_uniforms look;
// Opacity of the dark outside every light (0 = no darkness, 1 = black).
uniform float darkness : hint_range(0.0, 1.0) = 0.82;
// Colour of the dark: a cold blue-violet instead of pure black.
uniform vec4 shade_color : source_color = vec4(0.03, 0.02, 0.06, 1.0);
// Number of brightness steps inside a light (pixel-art banding).
uniform float light_bands : hint_range(2.0, 16.0) = 5.0;
group_uniforms;

group_uniforms fog;
// Fog instead of darkness (the Frostgruft): drifting wisps thin and thicken the
// overlay by up to this share (0 = a plain, even darkness as everywhere else).
uniform float fog_noise : hint_range(0.0, 1.0) = 0.0;
// World pixels per wisp and the drift in world px per second; time in seconds.
uniform float fog_scale = 420.0;
uniform vec2 fog_drift = vec2(22.0, 7.0);
uniform float time = 0.0;
group_uniforms;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, 0..1.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying vec2 world_position;

void vertex() {
	// The overlay node sits at the world origin, so local = world pixels.
	world_position = VERTEX;
}

void fragment() {
	vec2 cell = floor(world_position / PIXEL_GRID) * PIXEL_GRID + PIXEL_GRID * 0.5;
	float lit = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		// Unused slots count as zero without branching.
		float used = step(float(i) + 0.5, float(light_count));
		vec4 light = lights[i];
		float reach = 1.0 - distance(cell, light.xy) / max(light.z, 1.0);
		float strength = smoothstep(0.0, 1.0, clamp(reach, 0.0, 1.0)) * light.w * used;
		// Overlapping lights add up like two lamps: 1 - (1-a)(1-b).
		lit = 1.0 - (1.0 - lit) * (1.0 - strength);
	}
	// Quantise into bands, rounding up so a light's edge stays visible.
	lit = ceil(lit * light_bands) / light_bands;
	float wisps = 1.0;
	if (fog_noise > 0.0) {
		vec2 p = (cell - fog_drift * time) / fog_scale;
		float n = noise(p) * 0.65 + noise(p * 2.3 + vec2(time * 0.05, 3.7)) * 0.35;
		wisps = 1.0 - fog_noise + fog_noise * 2.0 * n;
	}
	COLOR = vec4(shade_color.rgb, clamp(darkness * (1.0 - clamp(lit, 0.0, 1.0)) * wisps, 0.0, 1.0));
}
