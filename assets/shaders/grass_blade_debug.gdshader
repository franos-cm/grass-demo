shader_type spatial;
render_mode cull_disabled;

// Base geometrical params
group_uniforms Shape;
uniform float control_x : hint_range(-1.0, 1.0) = 0.25;
uniform float control_y : hint_range(-2.0, 2.0) = 0.75;
uniform float base_width: hint_range(0.0, 1.0) = 0.7;
uniform float middle_width: hint_range(0.0, 1.0) = 0.135;
uniform float side_thickness: hint_range(0.0, 2.0) = 1.0;
group_uniforms;

// Lighting/aesthetical params
group_uniforms Lighting;
uniform vec3 base_color: source_color = vec3(0.55, 0.63, 0.24);
uniform float details_effect_strength: hint_range(0.0, 0.6) = 0.1;
uniform float ridge_smoothness: hint_range(0.0, 0.3) = 0.03;
uniform float rim_thickness: hint_range(0.3, 0.5) = 0.49;
uniform float rim_smoothness: hint_range(0.0, 0.3) = 0.1;
uniform sampler2D veins_texture;
group_uniforms;

// Wind
group_uniforms Wind;
uniform sampler2D wind_texture;
uniform float wind_tex_scale: hint_range(1.0, 500.0) = 75.0;
uniform float wind_direction_randomness: hint_range(0.0, 10.0) = 1.5;
uniform float wind_texture_speed_x: hint_range(-1.0, 1.0) = -1.0;
uniform float wind_texture_speed_y: hint_range(-1.0, 1.0) = -0.2;
uniform float wind_texture_speed: hint_range(0.0, 10.0) = 0.4;
uniform float grass_swell_amplitude: hint_range(0.0, 1.0) = 0.5;
uniform float flutter_frequency: hint_range(0.0, 10.0) = 2.0;
uniform float flutter_speed: hint_range(0.0, 10.0) = 0.5;
uniform float flutter_amplitude: hint_range(0.0, 1.0) = 0.03;
uniform float wind_effect_base_amplitude: hint_range(0.0, 2.0) = 0.4;
uniform float wind_effect_mid_amplitude: hint_range(0.0, 5.0) = 1.6;
uniform float wind_effect_tip_amplitude: hint_range(0.0, 5.0) = 1.0;
uniform float wind_pivot_amplitude : hint_range(0.0, 1.0) = 0.6;
group_uniforms;

// Varyings
varying vec3 debug_color;

// Constants
const vec2 p0_base = vec2(0.0, 0.0);
const vec2 p2_base = vec2(1.2, 0.75);


float hash13(vec3 x) {
	uvec3 p = floatBitsToUint(x);
	p = 1103515245U*((p.xyz >> 1U)^(p.yzx));
    uint h32 = 1103515245U*((p.x^p.z)^(p.y>>3U));
    uint n = h32^(h32 >> uint(16));
    return float(n)*(1.0/float(0xffffffffU));
}

vec2 bezier(float t, vec2 p0, vec2 p1, vec2 p2) {
	vec2 p01 = mix(p0, p1, t);
	vec2 p12 = mix(p1, p2, t);
	vec2 p = mix(p01, p12, t);
	return p;
}

vec2 bezier_normal(float t, vec2 p0, vec2 p1, vec2 p2) {
	vec2 p10 = p1 - p0;
	vec2 p21 = p2 - p1;
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
	return coeff * details_effect_strength;
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

vec2 panner(vec2 coords, vec2 speed, float time) {
	return coords + (speed*time);
}

mat2 rotate_y(float angle) {
  float s = sin(angle), c = cos(angle);
  return mat2(vec2(c, s), vec2(-s, c));
}


void vertex() {
	// Useful variables used throughout vertex shader
	mat4 inverse_model_matrix = inverse_model_matrix(MODEL_MATRIX);
	vec3 world_position = MODEL_MATRIX[3].xyz;
	float rand_num = (hash13(world_position) - 0.5)*2.0; // [-1, 1] range
	float t = VERTEX.x;

	// Pinch z axis so plane has the format of a blade
	float pinching_coeff = (1.0 - t) * middle_width * (t + base_width);
	VERTEX.z *= pinching_coeff;

	// Define initial control points that will be used to curve the plane through a Bezier curve
	vec2 p0 = p0_base;
	vec2 p1 = vec2(control_x, control_y);
	vec2 p2 = p2_base;

	// Wind: we create the impression of wind by changing the position
	//       of the control points and pivoting the blade over time
	vec2 wind_direction = (vec2(wind_texture_speed_x, wind_texture_speed_y))*wind_texture_speed;
	vec2 wind_direction_offset = normalize(vec2(sin(rand_num*PI), cos(rand_num*PI))) * wind_direction_randomness;
	vec2 wind_base_uv = (world_position.xz + wind_direction_offset) / wind_tex_scale;
	vec2 wind_uv = panner(wind_base_uv, wind_direction, TIME); // TODO: could use more and average between them
	float wind_strength = texture(wind_texture, wind_uv).r;

	// For the control point manipulation, there are two types of motion: swelling and fluttering.
	// Primary wind motion: swell, ranging from [-grass_swell_amplitude, 0]
	// Corresponds to vertical "bobbing" of the entire blade, according to a texture map
	float grass_swell = (wind_strength - 0.5)*2.0;
	grass_swell = -(sin(grass_swell*PI)+1.0) * grass_swell_amplitude / 2.0;

	// Secondary wind motion: flutter, ranging from [-flutter_amplitude/2, flutter_amplitude/2]
	// Flutter increases over blade length, and is determined (somewhat) randomly for each blade
	float grass_flutter = (t + flutter_speed*TIME) * flutter_frequency + rand_num;
	grass_flutter = (sin(grass_flutter*PI)) * flutter_amplitude / 2.0;

	// Total wind effect is a combination of primary and secondary movements
	// We update the control points with the wind influence
	vec2 p1_wind_effect = vec2(0, grass_swell);
	p1 += p1_wind_effect * wind_effect_base_amplitude * wind_effect_mid_amplitude;
	vec2 p2_wind_effect = vec2(grass_swell, grass_swell+grass_flutter);
	p2 += p2_wind_effect * wind_effect_base_amplitude * wind_effect_tip_amplitude;
	
	// Length estimative: guarantee that deformations still maintain the same blade length
	// At the moment, I think it makes the visuals overall worse, and at a cost to performance
	float approx_blade_length = 1.0;
	// approx_blade_length = (2.0*length(p2 - p0) + length(p1 - p0) + length(p2 - p1)) / 3.0;

	// Calculate the bezier curves, and deform the xy axes accordingly
	vec2 bezier_vec = bezier(t, p0, p1, p2) / approx_blade_length;
	vec2 bezier_normal_vec = bezier_normal(t, p0, p1, p2);
	VERTEX.xy = vec2(bezier_vec.x, bezier_vec.y);
	NORMAL.xy = vec2(bezier_normal_vec.x, bezier_normal_vec.y);

	
	// Turn
	vec3 wind_direction_world = vec3(wind_texture_speed_x, 0.0, wind_texture_speed_y);
	vec3 wind_direction_model = normalize( (inverse_model_matrix * vec4(wind_direction_world, 0.0)).xyz );
	const vec2 base_blade_direction = vec2(1.0, 0.0);

	vec2 wind_vec = -(vec2(wind_direction_model.x, wind_direction_model.z));
	
	float pivot_strength = wind_strength * wind_pivot_amplitude;
	vec2  blended_direction   = (mix(base_blade_direction, wind_vec, pivot_strength));
	float pivot_angle = atan(blended_direction.y, blended_direction.x);

	float k = clamp(pow(t, 2.0) + 0.05, 0.0, 1.0);
	float yaw = pivot_angle * k;
	mat2 rot = rotate_y(yaw);
	
	VERTEX.xz  = rot * VERTEX.xz;
	NORMAL.xz  = rot * NORMAL.xz;
	TANGENT.xz = rot * TANGENT.xz;

	
	// View dependent thickening: twist the blade when looking at it exactly sideways
	vec3 camera_direction_model = (inverse_model_matrix * vec4(CAMERA_DIRECTION_WORLD, 0.0)).xyz;
	float alignment_coeff = VERTEX.z * camera_direction_model.z;
	float length_adjustment_coeff = clamp(pow(1.0-t, 1.5)*t+0.05, 0.0, 1.0);
	float tilt_coeff = alignment_coeff * length_adjustment_coeff * side_thickness;
	float tilt_vector = normalize(NORMAL.y) * tilt_coeff;
	VERTEX.y -= tilt_vector;
}


void fragment() {
	// Add a normal component along the x axis, to give the impression of a central ridge and outer rims.
	// First we need to calculate how "strong" this new component is going to be for every pixel
	float u_coeff = normal_u_coeff(UV.y);
	// Then we pertube the NORMAL vec, by adding a scaled TANGENT vec (which already points towards the u axis)
	NORMAL = normalize(NORMAL + TANGENT * u_coeff);

	// Color and texture
	// Texture is a one pixel tall greyscale noise, that gets stretched over the length of the blade
    vec3 tex_color = texture(veins_texture, UV.yx).rgb;
	// We change the color according to the texture
	ALBEDO = mix(base_color, 0.65*base_color, tex_color);
	//ALBEDO = debug_color.rgb;

	// Lighting.
	ROUGHNESS = mix(0.3, 0.7, length(tex_color));
	//SPECULAR = mix(0.3, 0.2, length(tex_color));
	//ROUGHNESS = 0.7;
    SPECULAR = 0.15;
}