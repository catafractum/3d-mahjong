shader_type spatial;
render_mode unshaded, cull_front, blend_mix;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.42);
uniform float outline_width = 0.025;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
