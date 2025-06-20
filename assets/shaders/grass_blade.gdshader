shader_type spatial;
render_mode cull_disabled;

// Base geometrical params
group_uniforms Shape;
uniform float control_x : hint_range(-1.0, 1.0) = 0.25;
uniform float control_y : hint_range(-2.0, 2.0) = 0.75;
uniform float base_width: hint_range(0.0, 1.0) = 0.7;
uniform float middle_width: hint_range(0.0, 1.0) = 0.135;
uniform float side_thickness: hint_range(0.0, 10.0) = 4.0;
group_uniforms;

// Lighting/aesthetical params
group_uniforms Lighting;
uniform vec3 base_color: source_color = vec3(0.46, 0.53, 0.2);
uniform vec3 tip_color: source_color = vec3(0.76, 0.87, 0.33);
uniform float details_effect_strength: hint_range(0.0, 0.6) = 0.1;
uniform float ridge_smoothness: hint_range(0.0, 0.3) = 0.03;
uniform float rim_thickness: hint_range(0.3, 0.5) = 0.49;
uniform float rim_smoothness: hint_range(0.0, 0.3) = 0.1;
uniform float gloss_amount: hint_range(0.0, 1.0) = 0.5;
uniform float clearcoat_level: hint_range(0.0, 1.0) = 0.05;
uniform float clearcoat_roughness: hint_range(0.0, 1.0) = 0.2;
uniform float base_ao: hint_range(0.0, 1.0) = 0.25;
uniform float veins_strength: hint_range(0.0, 1.0) = 0.3;
uniform sampler2D veins_texture;
group_uniforms;

// Wind
group_uniforms Wind;
uniform sampler2D wind_texture;
uniform float wind_tex_scale: hint_range(1.0, 500.0) = 75.0;
uniform float wind_direction_randomness: hint_range(0.0, 10.0) = 1.5;
uniform float wind_texture_speed_x: hint_range(-1.0, 1.0) = 0.15;
uniform float wind_texture_speed_y: hint_range(-1.0, 1.0) = -0.08;
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

group_uniforms Interaction;
global uniform sampler2D footpath_tex;
global uniform vec2      footpath_origin;
global uniform float     footpath_size;
group_uniforms;

// Varyings
varying vec3 world_position;
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

vec2 normal_adjustment_coeff(vec2 uv) {
	// Adjustment along the width of the blade (u coord)
	float u_coord_centered = -uv.x + 0.5;
	float band = smoothstep(-ridge_smoothness, ridge_smoothness, u_coord_centered);
	float band_inv = 1.0 - band;
	float rim = abs(u_coord_centered); // TODO: edge values seem broken
	rim = smoothstep(rim_thickness, rim_thickness-rim_smoothness, rim);
	float u_coeff = mix(1, -1, mix(band_inv, band, rim));

	// First element adjusts in TANGENT direction, second element in BINORMAL direction
	return vec2(u_coeff, 0.0) * details_effect_strength;
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

float sample_wind_strength(vec3 world_pos, float rand_num) {
	vec2 wind_direction = (vec2(wind_texture_speed_x, wind_texture_speed_y))*wind_texture_speed;
	vec2 wind_direction_offset = normalize(vec2(sin(rand_num*PI), cos(rand_num*PI))) * wind_direction_randomness;
	vec2 wind_base_uv = (world_pos.xz + wind_direction_offset) / wind_tex_scale;
	vec2 wind_uv = panner(wind_base_uv, wind_direction, TIME); // TODO: could use more textures and average between them
	return texture(wind_texture, wind_uv).r;
}

mat2 pivot_blade(float wind_strength, float t, mat4 inverse_model_matrix) {
	float pivot_strength = wind_strength * wind_pivot_amplitude;
	vec3 wind_direction_world = vec3(wind_texture_speed_x, 0.0, wind_texture_speed_y);
	vec3 wind_direction_model = normalize((inverse_model_matrix * vec4(wind_direction_world, 0.0)).xyz );

	const vec2 base_blade_direction = vec2(1.0, 0.0);
	vec2 wind_blade_direction = -(vec2(wind_direction_model.x, wind_direction_model.z));

	vec2  final_blade_direction = mix(base_blade_direction, wind_blade_direction, pivot_strength);
	float pivot_angle = atan(final_blade_direction.y, final_blade_direction.x);

	float pivot_length_coeff = clamp(pow(t, 2.0) + 0.05, 0.0, 1.0);
	return rotate_y(pivot_angle * pivot_length_coeff);
}

float sample_crushed_factor_cpu(vec3 world_pos) {
	vec2 footpath_uv = (world_pos.xz - footpath_origin) / footpath_size;
	float imprint = texture(footpath_tex, footpath_uv).r;
	return imprint;
}

//global uniform int POS_ARRAY_LENGTH;
//global uniform sampler2D position_array_tex;
//global uniform int position_array_index;
//uniform float footprint_radius : hint_range(0.1, 5.0) = 1.5;
//float sample_crushed_factor_gpu(vec3 world_pos) {
	//float final_imprint = 0.0;
//
	//for (int i = 0; i < POS_ARRAY_LENGTH; i++) {
		//vec4 pos_data = texelFetch(position_array_tex, ivec2(i, 0), 0);
//
		//if (pos_data.a > 0.5) {
			//vec3 history_pos = pos_data.rgb;
//
			//// Use the 'world_pos' argument instead of the global WORLD_POSITION
			//float dist = distance(world_pos.xz, history_pos.xz);
//
			//float spatial_brightness = 1.0 - smoothstep(0.0, footprint_radius, dist);
//
			//int age = (position_array_index - 1 - i + POS_ARRAY_LENGTH) % POS_ARRAY_LENGTH;
			//float temporal_brightness = 1.0 - (float(age) / float(POS_ARRAY_LENGTH));
//
			//float footprint_brightness = spatial_brightness * temporal_brightness;
			//final_imprint = max(final_imprint, footprint_brightness);
		//}
	//}
//
	//return final_imprint;
//}


void vertex() {
	// Useful variables used throughout vertex shader
	mat4 inverse_model_matrix = inverse_model_matrix(MODEL_MATRIX);
	world_position = MODEL_MATRIX[3].xyz;
	float rand_num = (hash13(world_position) - 0.5)*2.0; // [-1, 1] range
	float crushed_factor = (1.0 - sample_crushed_factor_cpu(world_position));
	float t = VERTEX.x;


	// Define initial control points that will be used to curve the plane through a Bezier curve
	vec2 p0 = p0_base;
	vec2 p1 = vec2(control_x, control_y);
	vec2 p2 = p2_base;

	// Pinch z axis so plane has the format of a blade
	float pinching_coeff = (1.0 - t) * middle_width * (t + base_width);
	VERTEX.z *= pinching_coeff;

	// Wind: we create the impression of wind by changing the position
	//       of the control points and pivoting the blade over time
	float wind_strength = sample_wind_strength(world_position, rand_num); //* crushed_factor;

	// For the control point manipulation, there are two types of motion: swelling and fluttering.
	// Primary wind motion: swell, ranging from [-grass_swell_amplitude, 0]
	// Corresponds to vertical "bobbing" of the entire blade, according to a texture map
	float grass_swell = (wind_strength - 0.5)*2.0;
	grass_swell = -(sin(grass_swell*PI)+1.0) * grass_swell_amplitude / 2.0;

	// Secondary wind motion: flutter, ranging from [-flutter_amplitude/2, flutter_amplitude/2]
	// Flutter increases over blade length, and is determined (somewhat) randomly for each blade
	float grass_flutter = (t + flutter_speed*TIME) * flutter_frequency + rand_num;
	grass_flutter = (sin(grass_flutter*PI)) * flutter_amplitude / 2.0;

	// We update the control points with the wind influence
	vec2 p1_wind_effect = vec2(0, grass_swell);
	p1 += p1_wind_effect * wind_effect_base_amplitude * wind_effect_mid_amplitude;
	p1 = max(vec2(0.0), p1);
	vec2 p2_wind_effect = vec2(grass_swell, grass_swell+grass_flutter);
	p2 += p2_wind_effect * wind_effect_base_amplitude * wind_effect_tip_amplitude;
	p2 = max(vec2(0.0), p2);

	// Reduce height of crushed blades
	p2.y *= min(1.0, crushed_factor);
	p1.y *= min(1.0, crushed_factor);

	// Calculate the bezier curves, and deform the xy axes accordingly
	vec2 bezier_vec = bezier(t, p0, p1, p2);
	vec2 bezier_normal_vec = bezier_normal(t, p0, p1, p2);
	// Length estimative: guarantee that wind deformations still maintain the same blade length
	float approx_blade_length = 1.0; // (2.0*length(p2 - p0) + length(p1 - p0) + length(p2 - p1)) / 3.0;
	VERTEX.xy = vec2(bezier_vec.x, bezier_vec.y) / approx_blade_length;
	NORMAL.xy = vec2(bezier_normal_vec.x, bezier_normal_vec.y);

	// Tertiary wind motion: pivoting the blade to face the wind
	mat2 grass_pivot = pivot_blade(wind_strength, t, inverse_model_matrix);
	VERTEX.xz  = grass_pivot * VERTEX.xz;
	NORMAL.xz  = grass_pivot * NORMAL.xz;
	TANGENT.xz = grass_pivot * TANGENT.xz;

	// View dependent thickening: twist the blade when looking at it exactly sideways
	vec3 camera_direction_model = (inverse_model_matrix * vec4(CAMERA_DIRECTION_WORLD, 0.0)).xyz;
	float alignment_coeff = VERTEX.z * camera_direction_model.z;
	float length_adjustment_coeff = clamp(pow(1.0-t, 1.5)*t+0.05, 0.0, 1.0);
	float tilt_coeff = alignment_coeff * length_adjustment_coeff * side_thickness;
	float tilt_vector = normalize(NORMAL.y) * tilt_coeff;
	VERTEX.y -= tilt_vector;
}


// FIXME: axis used for mesh makes UV inverted... so currently we are doing vec.yx for a lot of stuff
void fragment() {
	// Add a normal component along the x axis, to give the impression of a central ridge and outer rims.
	// First we need to calculate how "strong" this new component is going to be for every pixel
	// Then we pertube the NORMAL vec, by adding a scaled TANGENT vec (which already points towards the u axis)
	vec2 adjustment_coeffs = normal_adjustment_coeff(UV.yx).yx;
	vec3 normal_adjustment_vec = TANGENT*adjustment_coeffs.x + BINORMAL*adjustment_coeffs.y;
	NORMAL = normalize(NORMAL + normal_adjustment_vec);

	// Color and texture
	// Texture is a one pixel tall greyscale noise, that gets stretched over the length of the blade
    vec3 tex_colour = texture(veins_texture, UV.yx).rgb;
	// We change the color according to the texture
	vec3 albedo_colour = mix(base_color, tip_color, UV.x - 0.5);
	ALBEDO = mix(albedo_colour, (1.0-veins_strength)*albedo_colour, tex_colour);;
	//ALBEDO = debug_color;

    // Lightning
	float gloss = clamp(gloss_amount*UV.x, 0.0, 1.0);
    ROUGHNESS = mix(0.8, 0.05, gloss);
    SPECULAR = mix(0.05, 0.25, gloss);
    CLEARCOAT = clearcoat_level * gloss;
    CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	AO = mix(base_ao, 1.0, UV.x);
}