shader_type spatial;
render_mode cull_disabled;


// Base geometrical params
group_uniforms Shape;
uniform float control_x : hint_range(0.0, 1.0) = 0.65;
uniform float control_y : hint_range(0.0, 1.0) = 0.5;
uniform float base_width: hint_range(0.0, 1.0) = 0.128;
uniform float middle_width: hint_range(0.0, 1.0) = 0.366;
group_uniforms;

group_uniforms Wind;
uniform float wind_strength: hint_range(0.0, 2.0) = 0.5;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_frequency: hint_range(0.1, 5.0) = 1.0;
uniform float wind_turbulence: hint_range(0.0, 1.0) = 0.3;
group_uniforms;

// Lighting/aesthetical params
group_uniforms Lighting;
uniform vec3 base_color: source_color = vec3(0.388235, 0.682353, 0.27451);
uniform float ridge_smoothness: hint_range(0.0, 0.3) = 0.03;
uniform float rim_thickness: hint_range(0.3, 0.5) = 0.49;
uniform float rim_smoothness: hint_range(0.0, 0.3) = 0.1;
uniform float side_thickness: hint_range(0.3, 2.0) = 0.6;
uniform sampler2D veins_texture;
group_uniforms;


// Constants
const vec2 p0 = vec2(0.0, 0.0); // start point, always on origin
const vec2 p2 = vec2(1.0, 0.0); // end point, always on top. We can move it using rotation tranformation.


vec2 bezier(float t, vec2 control_p) {
	vec2 p01 = mix(p0, control_p, t);
	vec2 p12 = mix(control_p, p2, t);
	vec2 p = mix(p01, p12, t);
	return p;
}

vec2 bezier_normal(float t, vec2 control_p) {
	vec2 p10 = control_p - p0;
	vec2 p21 = p2 - control_p;
	vec2 derivative = 2.0*mix(p10, p21, t);
	vec2 normal = normalize(vec2(-derivative.y, derivative.x));
	return normal;
}

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

// TODO: could be good to have this pre-calculated
mat4 inverse_model_matrix(mat4 model) {
    // Extract and transpose the rotation part
    mat3 rotation_inv = transpose(mat3(model));
    mat4 inv_model = mat4(rotation_inv);
    // Compute inverse translation: -Rᵀ * T
    inv_model[3] = vec4(-(rotation_inv * model[3].xyz), 1.0);
    return inv_model;
}


void vertex() {
	float t = VERTEX.y;

	// Wind calculation
    float time = TIME * wind_frequency;
    vec2 wind_wave = wind_direction * sin(time + VERTEX.x * 10.0) * wind_strength;
    vec2 wind_turb = vec2(sin(time * 1.7 + VERTEX.x * 12.0),
                         cos(time * 1.3 + VERTEX.x * 8.0)) * wind_turbulence;

	// Pinch x axis so quad has the format of a blade
	float pinching_coeff = (1.0 - t) * middle_width * (t + base_width);
	VERTEX.x *= (pinching_coeff);

	// Curve the blade through a Bezier curve
	vec2 control_p = vec2(control_x, control_y);
	control_p += wind_wave * t; // More effect at top of blade
    control_p += wind_turb * t * 0.3;

	vec2 bezier_vec = bezier(t, control_p);
	vec2 bezier_normal_vec = bezier_normal(t, control_p);
	VERTEX.yz = vec2(bezier_vec.x, bezier_vec.y);
	NORMAL.yz = vec2(bezier_normal_vec.x, bezier_normal_vec.y);

	// View dependent thickening: twist the blade when looking at it sideways
	mat4 inverse_model_matrix = inverse_model_matrix(MODEL_MATRIX);
	vec3 camera_direction_model = (inverse_model_matrix * vec4(CAMERA_DIRECTION_WORLD, 0.0)).xyz;
	float alignment_coeff = VERTEX.x * camera_direction_model.x;
	float length_adjustment_coeff = clamp((pow(1.0-t, 0.5)*pow(t+0.05, 0.33)), 0.0, 1.0);
	float tilt_coeff = alignment_coeff * length_adjustment_coeff * side_thickness;
	float tilt_vector = normalize(NORMAL.z) * tilt_coeff;
	VERTEX.z -= tilt_vector;
}


void fragment() {
	// Add a normal component along the x axis, to give the impression of a central ridge and outer rims.
	// First we need to calculate how "strong" this new component is going to be for every pixel
	float u_coeff = normal_u_coeff(UV.x);
	// Then we pertube the NORMAL vec, by adding a scaled TANGENT vec (which already points towards the u axis)
	NORMAL = normalize(NORMAL + TANGENT * u_coeff);

	// Color and texture
	// Texture is a one pixel tall greyscale noise, that gets stretched over the length of the blade
    vec3 tex_color = texture(veins_texture, UV).rgb;
	// We change the color according to the texture
    ALBEDO = mix(base_color, 0.65*base_color, tex_color);

	// Lighting.
	// Honestly, this seems to make just a very small difference, and not sure if its for the better
	ROUGHNESS = mix(0.6, 0.8, length(tex_color));
    SPECULAR = mix(0.6, 0.5, length(tex_color));
}
