// Camera vignette (Claude Code session, 2026-10-28).
// Purpose: the room stays bright; only the edges of the camera view fall off
// softly into the crypt's blue-violet dark. Screen-space, drawn over the world
// (not over the HUD). Values come from balance.json "lighting.vignette".
// Target: every desktop renderer; one quad, no texture reads, no branches.
shader_type canvas_item;

group_uniforms vignette;
// Darkness at the very corners (0 = none, 1 = full shade colour).
uniform float strength : hint_range(0.0, 1.0) = 0.55;
// Where the darkening starts and where it is complete, as a share of the
// distance from the centre to a corner.
uniform float inner : hint_range(0.0, 1.5) = 0.55;
uniform float outer : hint_range(0.0, 2.0) = 1.0;
// Width / height of the view, so the falloff is round, not stretched.
uniform float aspect = 1.7778;
uniform vec4 shade_color : source_color = vec4(0.03, 0.02, 0.06, 1.0);
group_uniforms;

void fragment() {
	// Distance from the centre, 0 in the middle and 1 in a corner.
	vec2 offset = (UV - 0.5) * vec2(aspect, 1.0);
	float corner = length(vec2(aspect, 1.0) * 0.5);
	float edge = smoothstep(inner, outer, length(offset) / corner);
	COLOR = vec4(shade_color.rgb, edge * strength);
}
