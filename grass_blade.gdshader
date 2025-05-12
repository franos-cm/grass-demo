shader_type spatial;
render_mode cull_disabled;


// Base geometrical params
group_uniforms Shape;
uniform vec2 control_p = vec2(1.0, 0.0);  // Bezier control point
uniform float base_width: hint_range(0.0, 1.0) = 0.128;
uniform float middle_width: hint_range(0.0, 1.0) = 0.366;
group_uniforms;

// Lighting/aesthetical params
group_uniforms Lighting;
uniform vec3 base_color: source_color = vec3(0.388235, 0.682353, 0.27451);
uniform float ridge_smoothness: hint_range(0.0, 0.3) = 0.03;
uniform float rim_thickness: hint_range(0.3, 0.5) = 0.49;
uniform float rim_smoothness: hint_range(0.0, 0.3) = 0.1;
group_uniforms;

uniform sampler2D veins_texture;


// Constants
const vec2 p0 = vec2(0.0, 0.0); // start point, always on origin
const vec2 p2 = vec2(1.0, 0.0); // end point, always on top. We can move it using rotation tranformation.


vec2 bezier(float t) {
	vec2 p01 = mix(p0, control_p, t);
	vec2 p12 = mix(control_p, p2, t);
	vec2 p = mix(p01, p12, t);
	return p;
}

vec2 bezier_normal(float t) {
	vec2 p10 = control_p - p0;
	vec2 p21 = p2 - control_p;
	vec2 derivative = 2.0*mix(p10, p21, t);
	vec2 normal = normalize(vec2(-derivative.y, derivative.x));
	return normal;
}

// TODO: turn smoothness params into uniforms
float normal_u_coeff(float u_coord) {
	// Centralize x_pos
	float u_coord_centered = -u_coord + 0.5;

	// Central band
	float band = smoothstep(-ridge_smoothness, ridge_smoothness, u_coord_centered);
	float band_inv = 1.0 - band;

	// Rim. TODO: edge values seem broken
	float rim = abs(u_coord_centered);
	rim = smoothstep(rim_thickness, rim_thickness-rim_smoothness, rim);

	float coeff = mix(1, -1, mix(band_inv, band, rim));

	float effect_strength = 0.5;
	return coeff * effect_strength;
}


void vertex() {
	float t = VERTEX.y; // goes from 0 to 1, param to bezier curve
	vec2 bezier_vec = bezier(t);
//
	VERTEX.x *= (1.0 - t) * middle_width * (t + base_width);
	VERTEX.y = bezier_vec.x;
	VERTEX.z = bezier_vec.y;
//
	//// Normal calculation needs to be done in vertex shader, since we are still in model space
	vec2 bezier_normal_vec = bezier_normal(t);
	NORMAL = vec3(0.0, bezier_normal_vec.x, bezier_normal_vec.y);
}


void fragment() {
	// Add a normal component along the x axis, to give the impression of a central ridge and outer rims.
	// First we need to calculate how "strong" this new component is going to be for every pixel
	float u_coeff = normal_u_coeff(UV.x);
	// Then we pertube the NORMAL vec, by adding a scaled TANGENT vec (which already points towards the u axis)
	NORMAL = normalize(NORMAL + TANGENT * u_coeff);
//
	// Color and texture
	// Texture is a one pixel tall greyscale noise, that gets stretched over the length of the blade
    vec4 tex_color = texture(veins_texture, UV);
	// We change the color according to the texture
    ALBEDO = mix(base_color, 0.66*base_color, tex_color.rgb);

	//ROUGHNESS = roughness;
    //SPECULAR = specular;
}
