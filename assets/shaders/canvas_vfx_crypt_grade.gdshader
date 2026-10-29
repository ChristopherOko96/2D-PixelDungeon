// Crypt colour filter (Claude Code session, 2026-10-29).
// Purpose: makes the Krypta der Verdammten darker and void-touched. It sits on
// the room layer only (baked floor and walls, torches, candle columns, doors),
// so heroes, enemies and shots keep their own colours. Dark tones lean toward
// the 0x72 violet (#473579), mid tones lose some brown and sink; bright pixels
// (flames, highlights) keep their brightness. Pure per-pixel colour mapping:
// no blur, no sampling of neighbours, so pixel edges stay hard.
// Target: every desktop renderer; no extra texture reads.
// Values come from assets/data/vfx_crypt_atmosphere.json "grade" via
// src/vfx/crypt_atmosphere.gd.
shader_type canvas_item;

group_uniforms grade;
// Brightness of dark and mid tones (1 = unchanged).
uniform float exposure : hint_range(0.0, 1.5) = 0.8;
// Luminance range over which the exposure fades out, so bright pixels keep
// their brightness (flame cores, light shafts).
uniform float highlight_from : hint_range(0.0, 1.0) = 0.55;
uniform float highlight_to : hint_range(0.0, 1.0) = 0.9;
// Contrast around the pivot luminance (1 = unchanged).
uniform float contrast : hint_range(0.5, 2.0) = 1.14;
uniform float pivot : hint_range(0.0, 1.0) = 0.32;
// Colour saturation (1 = unchanged, 0 = grey).
uniform float saturation : hint_range(0.0, 2.0) = 0.82;
// Hue the dark tones lean toward, at the pixel's own brightness.
uniform vec4 tint_color : source_color = vec4(0.278, 0.208, 0.475, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.55;
// Pixels darker than this luminance get the tint, fading out toward it.
uniform float tint_range : hint_range(0.01, 1.0) = 0.5;
group_uniforms;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	// COLOR already holds texture * modulate for sprites and the flat colour
	// for rectangles and polygons.
	vec3 c = COLOR.rgb;
	float l = dot(c, LUMA);
	// Violet shadows: the tint colour scaled to this pixel's luminance.
	vec3 tinted = clamp(tint_color.rgb * (l / max(dot(tint_color.rgb, LUMA), 0.001)), 0.0, 1.0);
	c = mix(c, tinted, (1.0 - smoothstep(0.0, tint_range, l)) * tint_strength);
	c = mix(vec3(dot(c, LUMA)), c, saturation);
	c = (c - pivot) * contrast + pivot;
	c *= mix(exposure, 1.0, smoothstep(highlight_from, max(highlight_to, highlight_from + 0.001), l));
	COLOR.rgb = clamp(c, 0.0, 1.0);
}
