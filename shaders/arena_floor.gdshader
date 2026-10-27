shader_type canvas_item;
// Draws the paintable floor from a tiny data texture:
//   R = cell code * 50 (0 nobody, 1 team A, 2 team B, 3 wall, 4 void)
//   G = "fresh paint" flash (0..1)
// Walls/void are discarded here and drawn by the arena view.

uniform sampler2D cells : filter_nearest;
uniform vec2 grid = vec2(22.0, 32.0);
uniform vec4 team_a : source_color = vec4(0.30, 0.76, 0.42, 1.0);
uniform vec4 team_b : source_color = vec4(0.64, 0.35, 0.90, 1.0);
uniform vec4 neutral : source_color = vec4(0.86, 0.84, 0.76, 1.0);
uniform float time = 0.0;

void fragment() {
	vec2 cell = UV * grid;
	vec2 ci = floor(cell);
	vec2 f = fract(cell);
	vec4 s = texture(cells, (ci + 0.5) / grid);
	float code = floor(s.r * 255.0 / 50.0 + 0.5);
	if (code >= 2.5) {
		discard;
	}
	vec3 c = code < 0.5 ? neutral.rgb : (code < 1.5 ? team_a.rgb : team_b.rgb);
	// Checker variation like painted tiles.
	float chk = mod(ci.x + ci.y, 2.0);
	c *= 0.92 + 0.08 * chk;
	// Soft bevel per tile.
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	c *= mix(0.74, 1.0, smoothstep(0.0, 0.12, edge));
	c += 0.07 * (1.0 - smoothstep(0.0, 0.18, min(f.x, f.y)));
	// Gentle shimmer so the field feels alive.
	c *= 1.0 + 0.025 * sin(time * 1.5 + ci.x * 0.7 + ci.y * 0.45);
	// Fresh paint pop.
	c = mix(c, vec3(1.0), s.g * 0.5);
	COLOR = vec4(c, 1.0);
}
