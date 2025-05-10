shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 base_color: source_color = vec3(0.0f);

uniform vec2 p_middle = vec2(0.5, 0.0);
uniform float middle_width = 1.5;
uniform float base_width = 1.0;

void vertex() {
	vec3 pm = vec3(middle_width, p_middle.x, p_middle.y);
	vec3 p1 = mix(vec3(base_width, 0.0, 0.0), pm, VERTEX.y);
	vec3 p2 = mix(pm, vec3(0.0, 1.0, 0.0), VERTEX.y);
	vec3 p = mix(p1, p2, VERTEX.y);

	VERTEX.x *= p.x;
	VERTEX.y = p.y;
	VERTEX.z = p.z;
}

void fragment() {
	ALBEDO = base_color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
