shader_type spatial;
render_mode unshaded, cull_front, blend_mix;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.42);
uniform float outline_width = 4.0;

void vertex() {
	// Hard-edged meshes duplicate corner vertices with a different normal for
	// each face. Expanding along NORMAL separates those faces and leaves gaps
	// in the outline. A shared radial direction keeps the enlarged hull closed,
	// while applying the offset in clip space gives every edge the same
	// thickness on screen.
	float vertex_distance = length(VERTEX);
	if (vertex_distance > 0.0001) {
		vec4 view_vertex = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vec3 radial_view = normalize(
			(MODELVIEW_MATRIX * vec4(VERTEX / vertex_distance, 0.0)).xyz
		);
		vec4 clip_vertex = PROJECTION_MATRIX * view_vertex;
		vec4 clip_radial = PROJECTION_MATRIX * vec4(
			view_vertex.xyz + radial_view, 1.0
		);
		vec2 screen_direction = (
			clip_radial.xy / clip_radial.w
			- clip_vertex.xy / clip_vertex.w
		);
		float direction_length = length(screen_direction);
		if (direction_length > 0.0001) {
			screen_direction /= direction_length;
			clip_vertex.xy += (
				screen_direction
				* outline_width
				* (2.0 / VIEWPORT_SIZE)
				* clip_vertex.w
			);
		}
		POSITION = clip_vertex;
	}
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
