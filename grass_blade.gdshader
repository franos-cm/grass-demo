shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 base_color: source_color = vec3(0.0f);

const vec2 p0 = vec2(0.0, 0.0); // start point, always on origin
uniform vec2 p1 = vec2(1.0, 1.0);
const vec2 p2 = vec2(1.0, 0.0); // end point, always on top. We can move it using rotation tranformation.

uniform float base_width: hint_range(0.0, 1.0) = 1.0;
uniform float middle_width: hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float t = VERTEX.y; // goes from 0 to 1, param to bezier curve
	vec2 p01 = mix(p0, p1, t);
	vec2 p12 = mix(p1, vec2(1.0, 0.0), t);
	vec2 p = mix(p01, p12, t);

	VERTEX.x *= (1.0 - t) * middle_width * (t + base_width);
	VERTEX.y = p.x;
	VERTEX.z = p.y;
}

void fragment() {
	ALBEDO = base_color;
}
