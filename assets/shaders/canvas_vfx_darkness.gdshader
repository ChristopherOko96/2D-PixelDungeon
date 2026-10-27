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
	COLOR = vec4(shade_color.rgb, darkness * (1.0 - clamp(lit, 0.0, 1.0)));
}
