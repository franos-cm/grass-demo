shader_type spatial;
render_mode cull_disabled;

uniform vec2 p1 = vec2(1.0, 1.0);  // Bezier control point
uniform float base_width: hint_range(0.0, 1.0) = 1.0;
uniform float middle_width: hint_range(0.0, 1.0) = 1.0;
uniform vec3 base_color: source_color = vec3(0.0f);

const vec2 p0 = vec2(0.0, 0.0); // start point, always on origin
const vec2 p2 = vec2(1.0, 0.0); // end point, always on top. We can move it using rotation tranformation.

varying float t_var;


vec2 bezier(float t) {
	vec2 p01 = mix(p0, p1, t);
	vec2 p12 = mix(p1, p2, t);
	vec2 p = mix(p01, p12, t);
	return p;
}

vec2 bezier_normal(float t) {
	vec2 p10 = p1 - p0;
	vec2 p21 = p2 - p1;
	vec2 derivative = 2.0*mix(p10, p21, t);
	vec2 normal = normalize(vec2(-derivative.y, derivative.x));
	return normal;
}


void vertex() {
	float t = VERTEX.y; // goes from 0 to 1, param to bezier curve
	vec2 bezier_vec = bezier(t);

	VERTEX.x *= (1.0 - t) * middle_width * (t + base_width);
	VERTEX.y = bezier_vec.x;
	VERTEX.z = bezier_vec.y;

	// Pass varyings to fragment shader
	t_var = t;
}

void fragment() {
	vec2 bezier_normal_vec = bezier_normal(t_var);
	vec3 normal_vec = vec3(0.0, bezier_normal_vec.x, bezier_normal_vec.y);
	// In theory, we need to apply the next line, but it looks weird
	// normal_vec = FRONT_FACING ? normal_vec : -normal_vec;
	NORMAL = normal_vec;

	ALBEDO = base_color;
}

