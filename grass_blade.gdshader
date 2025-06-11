shader_type spatial;
render_mode cull_disabled, shadows_disabled;


// Base geometrical params
group_uniforms Shape;
uniform float control_x : hint_range(-1.0, 1.0) = 0.25;
uniform float control_y : hint_range(-1.0, 1.0) = 0.75;
uniform float base_width: hint_range(0.0, 1.0) = 0.12;
uniform float middle_width: hint_range(0.0, 1.0) = 0.15;
group_uniforms;

// Lighting/aesthetical params
group_uniforms Lighting;
uniform vec3 base_color: source_color = vec3(0.56, 0.63, 0.22);
uniform float ridge_smoothness: hint_range(0.0, 0.3) = 0.03;
uniform float rim_thickness: hint_range(0.3, 0.5) = 0.49;
uniform float rim_smoothness: hint_range(0.0, 0.3) = 0.1;
uniform float side_thickness: hint_range(0.3, 2.0) = 0.6;
uniform sampler2D veins_texture;
group_uniforms;

// Wind
group_uniforms Wind;
uniform sampler2D wind_texture;
uniform sampler2D wind_texture_debug;
uniform float wind_tex_scale = 75.0;
uniform float wind_distance_offset: hint_range(0.0, 200.0) = 100.0;
uniform float wind_texture_speed_x: hint_range(-1.0, 1.0) = 1.0;
uniform float wind_texture_speed_y: hint_range(-1.0, 1.0) = 0.2;
uniform float wind_texture_speed: hint_range(0.0, 10.0) = 0.7;
uniform float grass_swell_amplitude: hint_range(0.0, 1.0) = 0.4;
uniform float grass_flutter_speed: hint_range(0.0, 10.0) = 2.0;
uniform float grass_flutter_base_amplitude: hint_range(0.0, 1.0) = 0.5;
uniform float grass_flutter_amplitude: hint_range(0.0, 1.0) = 0.03;
uniform float wind_effect_base_amplitude: hint_range(0.0, 10.0) = 1.0;
uniform float wind_effect_mid_amplitude: hint_range(0.0, 5.0) = 1.0;
uniform float wind_effect_tip_amplitude: hint_range(0.0, 5.0) = 1.0;
group_uniforms;

// Varyings
varying vec3 debug_color;
varying vec3 world_pos_debug;

// Constants
const vec2 p0_base = vec2(0.0, 0.0);
const vec2 p2_base = vec2(1.2, 0.75);


uint baseHash(uvec3 p)
{
    p = 1103515245U*((p.xyz >> 1U)^(p.yzx));
    uint h32 = 1103515245U*((p.x^p.z)^(p.y>>3U));
    return h32^(h32 >> uint(16));
}
uint baseHash(uvec2 p)
{
    p = 1103515245U*((p >> 1U)^(p.yx));
    uint h32 = 1103515245U*((p.x)^(p.y>>3U));
    return h32^(h32 >> uint(16));
}
uint baseHash(uint p)
{
    p = 1103515245U*((p >> 1U)^(p));
    uint h32 = 1103515245U*((p)^(p>>3U));
    return h32^(h32 >> uint(16));
}
vec3 hash32(vec2 x) {
	uvec2 p = floatBitsToUint(x);
    uint n = baseHash(p);
    uvec3 rz = uvec3(n, n*16807U, n*48271U);
    return vec3((rz >> uint(1)) & uvec3(0x7fffffffU))/float(0x7fffffff);
}
vec2 hash23(vec3 x) {
	uvec3 p = floatBitsToUint(x);
    uint n = baseHash(p);
    uvec2 rz = uvec2(n, n*48271U); //see: http://random.mat.sbg.ac.at/results/karl/server/node4.html
    return vec2((rz.xy >> uint(1)) & uvec2(0x7fffffffU))/float(0x7fffffff);
}
float hash12(vec2 x) {
	uvec2 p = floatBitsToUint(x);
    uint n = baseHash(p);
    return float(n)*(1.0/float(0xffffffffU));
}
float hash13(vec3 x) {
	uvec3 p = floatBitsToUint(x);
    uint n = baseHash(p);
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

vec2 panner(vec2 coords, vec2 speed, float time) {
	return coords + (speed*time);
}


void vertex() {
	vec3 world_position = MODEL_MATRIX[3].xyz;
	world_pos_debug = world_position;
	float rand_num = (hash12(world_position.xz) - 0.5)*2.0; // [-1, 1] range
	float t = VERTEX.x;
	
	// Pinch x axis so quad has the format of a blade
	float pinching_coeff = (1.0 - t) * middle_width * (t + base_width);
	VERTEX.z *= pinching_coeff;
	
	// Wind, direction
	vec2 rand_distance = normalize(vec2(sin(rand_num*PI), cos(rand_num*PI))) * wind_distance_offset;

	vec2 wind_base_uv = (world_position.xz) / wind_tex_scale;
	vec2 wind_direction = (vec2(wind_texture_speed_x, wind_texture_speed_y))*wind_texture_speed;
	vec2 wind_uv_1 = panner(wind_base_uv, vec2(0.22, 0.18)*wind_direction, TIME);
	vec2 wind_uv_2 = panner(wind_base_uv, vec2(0.15, 0.28)*wind_direction, TIME);
	vec2 wind_uv_3 = panner(wind_base_uv, vec2(0.30, 0.20)*wind_direction, TIME);
	
	// Seems very arbitrary
	// Primary wind motion: swell
	float grass_swell = (
		texture(wind_texture, wind_uv_1).r
	);
	grass_swell = (grass_swell - 0.5)*2.0;
	// Remapping to [0, grass_swell_amplitude]
	grass_swell = -(sin(grass_swell*PI)+1.0) * grass_swell_amplitude / 2.0;
	
	

	// Secondary wind motion: flutter
	// Flutter increases over blade length, and varies over time
	float grass_flutter = (grass_flutter_base_amplitude * t + TIME) * grass_flutter_speed + rand_num;
	grass_flutter = (sin(grass_flutter*PI)) * grass_flutter_amplitude / 2.0;
	
	// The more swell we have, the less flutter we have
	float wind_effect = (grass_swell) * wind_effect_base_amplitude;
	


	// Curve the blade through a Bezier curve
	vec2 p0 = p0_base;
	vec2 p1 = vec2(control_x, control_y);
	vec2 p2 = p2_base;
	p1 += vec2(wind_effect*wind_effect_mid_amplitude);
	p2 += vec2(wind_effect*wind_effect_tip_amplitude);
	
	vec2 bezier_vec = bezier(t, p0, p1, p2);
	vec2 bezier_normal_vec = bezier_normal(t, p0, p1, p2);
	VERTEX.xy = vec2(bezier_vec.x, bezier_vec.y);
	NORMAL.xy = vec2(bezier_normal_vec.x, bezier_normal_vec.y);
	

	
	
	
	// Wind debug
	vec3 red_vec = vec3(1.0, 0.0, 0.0); // Red
	vec3 green_vec = vec3(0.0, 1.0, 0.0); // Green
	vec3 blue_vec = vec3(0.0, 0.0, 1.0); // Blue

    vec3 final_color;
    if (grass_swell < 0.5) {
        float d = grass_swell / 0.5;
        final_color = mix(red_vec, green_vec, d);
    } else {
        float d = (grass_swell - 0.5) / 0.5;
        final_color = mix(green_vec, blue_vec, d);
    }
	debug_color = vec3(final_color);
	


	// View dependent thickening: twist the blade when looking at it exactly sideways
	mat4 inverse_model_matrix = inverse_model_matrix(MODEL_MATRIX);
	vec3 camera_direction_model = (inverse_model_matrix * vec4(CAMERA_DIRECTION_WORLD, 0.0)).xyz;
	float alignment_coeff = VERTEX.z * camera_direction_model.z;
	float length_adjustment_coeff = clamp((pow(1.0-t, 0.5)*pow(t+0.05, 0.33)), 0.0, 1.0);
	float tilt_coeff = alignment_coeff * length_adjustment_coeff * side_thickness;
	float tilt_vector = normalize(NORMAL.y) * tilt_coeff;
	//VERTEX.y -= tilt_vector;
	
	

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
    ALBEDO = mix(base_color, 1.0*base_color, tex_color);
	// ALBEDO = debug_color.rgb;
	
	
	
	ALBEDO = world_pos_debug.rgb;
	ALBEDO = texture(wind_texture, (world_pos_debug.xz + TIME) / 10.0).rgb;
	//ALBEDO = texture(wind_texture_debug, world_pos_debug.xz / 10.0).rgb;
	ALBEDO = debug_color.rgb;
	ALBEDO = mix(base_color, 0.65*base_color, tex_color);

	// Lighting.
	// Honestly, this seems to make just a very small difference, and not sure if its for the better
	//ROUGHNESS = mix(0.6, 0.8, length(tex_color));
    //SPECULAR = mix(0.6, 0.5, length(tex_color));
}