shader_type spatial;

render_mode unshaded, cull_back;

// size
uniform float blade_height = 0.5f;
uniform float blade_width = 0.005f;
uniform float density = 0.1; // [0, 1]

// color
uniform vec3 base_color: source_color = vec3(0.0f);
uniform vec3 tip_color: source_color = vec3(0.0f);

varying float height_ratio; // scales the color of the blades base on height

uniform float wind_strength = 0.2;
uniform float rnd_multiplier = 10.0; // act as random value to generate grass

float rand(vec2 cordinates) {
	return fract(sin(dot(cordinates.xy, vec2(12.9898, 78.233))) * 43758.5453); // random number
}

void vertex() {
	float rnd = rand(VERTEX.xz * rnd_multiplier);
	if (rnd > 1.0 - density) {
		float h = blade_height * (0.5 + rand(vec2(VERTEX.z, VERTEX.x)) * 0.5);
		float sway = sin(TIME + VERTEX.x * 2.0 + rnd * 10.0) * wind_strength;

		VERTEX.y += h;
		VERTEX.x += sin(rnd * rnd_multiplier) * blade_width + sway;
		VERTEX.z += sin(rnd * rnd_multiplier) * blade_width;

		height_ratio = clamp(VERTEX.y / (blade_height * 2.0), 0.2, 1.0);
	} else {
		height_ratio = 0.0;
	}
}

void fragment() {
	ALBEDO = mix(base_color, tip_color, height_ratio);
}
