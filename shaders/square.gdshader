shader_type spatial;
render_mode cull_disabled;


// Base geometrical params
group_uniforms Shape;
uniform float control_x : hint_range(0.0, 1.0) = 0.65;
uniform float control_y : hint_range(0.0, 1.0) = 0.5;
uniform float base_width: hint_range(0.0, 1.0) = 0.128;
uniform float middle_width: hint_range(0.0, 1.0) = 0.366;
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

#if 1
//Modified from: iq's "Integer Hash - III" (https://www.shadertoy.com/view/4tXyWN)
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
#else
//XXHash32 based (https://github.com/Cyan4973/xxHash)
uint baseHash(uvec3 p)
{
	const uint PRIME32_2 = 2246822519U, PRIME32_3 = 3266489917U;
	const uint PRIME32_4 = 668265263U, PRIME32_5 = 374761393U;
	uint h32 =  p.z + PRIME32_5 + p.x*PRIME32_3;
	h32 = PRIME32_4*((h32 << 17) | (h32 >> (32 - 17)));
	h32 += p.y * PRIME32_3;
	h32 = PRIME32_4*((h32 << 17) | (h32 >> (32 - 17))); //Initial testing suggests this line could be omitted for extra perf
    h32 = PRIME32_2*(h32^(h32 >> 15));
    h32 = PRIME32_3*(h32^(h32 >> 13));
    return h32^(h32 >> uint(16));
}
uint baseHash(uvec2 p)
{
    const uint PRIME32_2 = 2246822519U, PRIME32_3 = 3266489917U;
	const uint PRIME32_4 = 668265263U, PRIME32_5 = 374761393U;
    uint h32 = p.y + PRIME32_5 + p.x*PRIME32_3;
    h32 = PRIME32_4*((h32 << 17) | (h32 >> (32 - 17))); //Initial testing suggests this line could be omitted for extra perf
    h32 = PRIME32_2*(h32^(h32 >> 15));
    h32 = PRIME32_3*(h32^(h32 >> 13));
    return h32^(h32 >> uint(16));
}
uint baseHash(uint p)
{
	const uint PRIME32_2 = 2246822519U, PRIME32_3 = 3266489917U;
	const uint PRIME32_4 = 668265263U, PRIME32_5 = 374761393U;
	uint h32 = p + PRIME32_5;
	h32 = PRIME32_4*((h32 << 17) | (h32 >> (32 - 17))); //Initial testing suggests this line could be omitted for extra perf
    h32 = PRIME32_2*(h32^(h32 >> 15));
    h32 = PRIME32_3*(h32^(h32 >> 13));
    return h32^(h32 >> uint(16));
}
#endif

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



void vertex() {
	//float t = VERTEX.y;
//
	//// Pinch x axis so quad has the format of a blade
	//float pinching_coeff = (1.0 - t) * middle_width * (t + base_width);
	//VERTEX.x *= pinching_coeff;
//
	//// Curve the blade through a Bezier curve
	//vec2 control_p = vec2(control_x, control_y);
	//vec2 bezier_vec = bezier(t, control_p);
	//vec2 bezier_normal_vec = bezier_normal(t, control_p);
	//VERTEX.yz = vec2(bezier_vec.x, bezier_vec.y);
	//NORMAL.yz = vec2(bezier_normal_vec.x, bezier_normal_vec.y);
//
	//// View dependent thickening: twist the blade when looking at it sideways
	//mat4 inverse_model_matrix = inverse_model_matrix(MODEL_MATRIX);
	//vec3 camera_direction_model = (inverse_model_matrix * vec4(CAMERA_DIRECTION_WORLD, 0.0)).xyz;
	//float alignment_coeff = VERTEX.x * camera_direction_model.x;
	//float length_adjustment_coeff = clamp((pow(1.0-t, 0.5)*pow(t+0.05, 0.33)), 0.0, 1.0);
	//float tilt_coeff = alignment_coeff * length_adjustment_coeff * side_thickness;
	//float tilt_vector = normalize(NORMAL.z) * tilt_coeff;
	//VERTEX.z -= tilt_vector;
}


void fragment() {
	// Add a normal component along the x axis, to give the impression of a central ridge and outer rims.
	// First we need to calculate how "strong" this new component is going to be for every pixel
	//float u_coeff = normal_u_coeff(UV.x);
	//// Then we pertube the NORMAL vec, by adding a scaled TANGENT vec (which already points towards the u axis)
	//NORMAL = normalize(NORMAL + TANGENT * u_coeff);

	// Color and texture
	// Texture is a one pixel tall greyscale noise, that gets stretched over the length of the blade
    vec3 tex_color = texture(veins_texture, UV + TIME/3.0).rgb;
	// We change the color according to the texture
    // ALBEDO = tex_color;
	//ALBEDO = hash32(UV.xy);

	// Lighting.
	// Honestly, this seems to make just a very small difference, and not sure if its for the better
	//ROUGHNESS = mix(0.6, 0.8, length(tex_color));
    //SPECULAR = mix(0.6, 0.5, length(tex_color));
}
