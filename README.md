# Overview

This project was developed as part of the **PCS3539 - Tecnologia de Computação Gráfica** course, during the 2025.1 semester. 

The goal of the project was to render realistic grass fields for real-time computer graphics applications, primarily targeting video games.
The project was entirely developed using the Godot game engine, and it was heavily inspired by [this talk given by the developers of Ghost of Tsushima in 2021](https://www.youtube.com/watch?v=Ibe1JBF5i5Y), as well as by other projects exploring similar ideas.

# 1. Running the demo

The demo is available as a static website [here](https://franos-cm.github.io/whitman/). We recommend using a computer, since controls require a keyboard.

Alternatively, one could simply [download Godot](https://godotengine.org/), clone the repository:
```cmd
git clone https://github.com/guissalustiano/grass-demo.git
```

and open it as a Godot project. **Note that the project was developed and tested using Godot 4.4.1.**

### Controls

Because the project focuses on grass rendering itself, player controls are kept very simple and provide minimal interaction:

| Key / Input     | Action                   |
|-----------------|--------------------------|
| `W` `A` `S` `D` | Move character           |
| `Spacebar`      | Jump                     |
| `Mouse`         | Rotate the camera        |



# 2. Key points

## 2.1. Grass blades

The grass fields are composed of individual grass blades which are instantiated by the GPU. Each grass blade is a simple quad mesh with one-dimensional, length-wise subdivisions. This mesh is then manipulated by a custom shader to simulate the grass geometry and movement. An overview of this shader is given in this section.

### Shape

Changing the shape of the original mesh requires not only changing its ```VERTEX``` vector, but also its ```NORMAL``` vector so that lighting can be reflected accurately. Therefore, we ideally want the blade to have a robust geometrical definition, with easily calculated normals, and that can be customized on a per-instance level.

To that end, a quadratic Bezier curve with a customizable control midpoint is used to deform the mesh:
```glsl
uniform float control_x : hint_range(-1.0, 1.0) = 0.25;
uniform float control_y : hint_range(-2.0, 2.0) = 0.75;
...
const vec2 p0_base = vec2(0.0, 0.0);
const vec2 p2_base = vec2(1.2, 0.75);
...

void vertex() {
    float t = VERTEX.x;
    ...
    vec2 p0 = p0_base;
    vec2 p1 = vec2(control_x, control_y);
    vec2 p2 = p2_base;
    ...
    vec2 bezier_vec = bezier(t, p0, p1, p2);
    vec2 bezier_normal_vec = bezier_normal(t, p0, p1, p2);
    VERTEX.xy = vec2(bezier_vec.x, bezier_vec.y);
    NORMAL.xy = vec2(bezier_normal_vec.x, bezier_normal_vec.y);
    ...
}
```

To better resemble a blade of grass, we also "pinch off" the axis corresponding to the width of the blade. To make sure that different blades have slightly different shapes, the coefficient responsible for this pinching is perturbed randomly for each instance.
```glsl
uniform float avg_base_width: hint_range(0.0, 1.0) = 0.7;
uniform float avg_middle_width: hint_range(0.0, 1.0) = 0.135;
...

void vertex() {
    ...
    instance_rand_num_1 = hash13(world_position.xyz);
    instance_rand_num_2 = (hash13(world_position.zyx)- 0.5)*2.0;
    float remapped_rand_num_1 = (instance_rand_num_1 - 0.5)*2.0;
    ...
    float middle_width = (1.0 + 0.25*remapped_rand_num_1) * avg_middle_width;
    float base_width = (1.0 + 0.25*instance_rand_num_2) * avg_base_width;
    float pinching_coeff = (1.0 - t) * middle_width * (t + base_width);
    VERTEX.z *= pinching_coeff;
    ...
}
```

Finally, although the blade is still a two-dimensional mesh with no volume, we can simulate thickness by bending the grass to face the camera when viewed sideways. This approach, which we call **view-dependent thickness**, is conceptually similar to billboarding, and it allows for us to simulate denser fields in a more performant way than having extra vertices for thickness. We perform the necessary calculations in the model space, which requires some additional transformations:
```glsl
uniform float side_thickness: hint_range(0.0, 10.0) = 4.0;
...

void vertex() {
    mat4 inverse_model_matrix = inverse_model_matrix(MODEL_MATRIX);
    ...
    vec3 camera_direction_model = (inverse_model_matrix * vec4(CAMERA_DIRECTION_WORLD, 0.0)).xyz;
    float alignment_coeff = VERTEX.z * camera_direction_model.z;
    float length_adjustment_coeff = clamp(pow(1.0-t, 1.5)*t+0.05, 0.0, 1.0);
    float tilt_coeff = alignment_coeff * length_adjustment_coeff * side_thickness;
    float tilt_vector = normalize(NORMAL.y) * tilt_coeff;
    VERTEX.y -= tilt_vector;
}
```

### Wind
The wind effect is implemented through three different kinds of mesh manipulation. **Swelling** is the vertical bobbing of the entire blade according to wind strength, **fluttering** is another vertical movement applied only to the tip to simulate turbulence, and **pivoting** is rotating the entire blade on its vertical axis to face the wind direction. Both swelling and fluttering motions can be done by modulating the control points of the Bezier curve previously calculated, which then changes the blade shape as a whole. The wind strength is computed by sampling a fixed 2D Perlin noise texture, and the wind direction corresponds to the scroll direction of that same texture.

Again, a degree of randomness is added to all three motions, by using a per-instance random number.

```glsl
uniform float grass_swell_amplitude: hint_range(0.0, 1.0) = 0.3;
uniform float flutter_frequency: hint_range(0.0, 10.0) = 2.0;
uniform float flutter_speed: hint_range(0.0, 10.0) = 0.5;
uniform float flutter_amplitude: hint_range(0.0, 1.0) = 0.03;
uniform float wind_effect_base_amplitude: hint_range(0.0, 2.0) = 0.4;
uniform float wind_effect_mid_amplitude: hint_range(0.0, 5.0) = 1.6;
uniform float wind_effect_tip_amplitude: hint_range(0.0, 5.0) = 1.0;
...

void vertex() {
    ...
    float wind_strength = sample_wind_strength(world_position, remapped_rand_num);

    float grass_swell = (wind_strength - 0.5)*2.0;
    grass_swell = -(sin(grass_swell*PI)+1.0) * grass_swell_amplitude / 2.0;

    float grass_flutter = (t + flutter_speed*TIME) * flutter_frequency + remapped_rand_num;
    grass_flutter = (sin(grass_flutter*PI)) * flutter_amplitude / 2.0;

    vec2 p1_wind_effect = vec2(0, grass_swell);
    p1 += p1_wind_effect * wind_effect_base_amplitude * wind_effect_mid_amplitude;
    p1 = max(vec2(0.0), p1);
    vec2 p2_wind_effect = vec2(grass_swell, grass_swell+grass_flutter);
    p2 += p2_wind_effect * wind_effect_base_amplitude * wind_effect_tip_amplitude;
    p2 = max(vec2(0.0), p2);
    ...
    mat2 grass_pivot = pivot_blade(wind_strength, t, inverse_model_matrix);
    VERTEX.xz  = grass_pivot * VERTEX.xz;
    NORMAL.xz  = grass_pivot * NORMAL.xz;
    TANGENT.xz = grass_pivot * TANGENT.xz;
    ...
}
```

### Player interaction

The grass reacts to player movement by being "pressed down" or "crushed" when the player walks over it. Additionally, when the player moves out of that position, the blades smoothly return to its original height. This is implemented by having a 2D RGBA texture that acts as a circular buffer that stores the historical position of the player. The buffer data is then used by a SubViewport to draw circles into a fixed-sized, single-channel texture, which is centered on the player's world position.

Finally, the texture is then sampled by the shader to manipulate the control points, similarly to the wind effect:

```glsl
global uniform sampler2D footpath_tex: repeat_disable;
global uniform vec2      footpath_origin;
global uniform float     footpath_size;
...

float sample_crushed_factor(vec3 world_pos) {
    vec2 footpath_uv = (world_pos.xz - footpath_origin) / footpath_size;
    float imprint = texture(footpath_tex, footpath_uv).r;
    return imprint;
}

void vertex() {
    ...
    float crushed_factor = (1.0 - sample_crushed_factor(world_position));
    ...
    p2.y *= min(1.0, crushed_factor + 0.05);
    p1.y *= min(1.0, crushed_factor + 0.05);
    ...
}
```
The circles themselves are drawn "faded" on the texture, according to how long they have been in the buffer, in order to provide a temporal fade to the effect. 

This combined buffer+texture approach provides several upsides. Firstly, the shader avoids doing the computationally expensive task of reading the entire buffer in order to decide if it should deform the grass or not; instead, it simply samples a texture. Moreover, by centering this texture on the player, we are able to perform effects on grass fields of unspecified size with arbitrarily high resolution, without having to change the size of the texture. Finally, by fixing the size of this texture, we also avoid computing effects caused by objects far away, striking a compromise between realism and computational resources.


### Color and fine details

The color of the blade is a gradient between a base color and a tip color. Both the base and tip colors are themselves based on one of three color schemes (i.e. different shades of green and yellow), and we randomly decide which one to apply based on the world position of the mesh. Another element of randomness is also added to the gradient, guaranteeing that every blade has a unique color.

```glsl
uniform vec3 prim_base_color: source_color = vec3(0.46, 0.53, 0.2);
uniform vec3 prim_tip_color: source_color = vec3(0.76, 0.87, 0.33);
uniform vec3 seco_base_color: source_color = vec3(0.55, 0.50, 0.19);
uniform vec3 seco_tip_color: source_color = vec3(0.59, 0.50, 0.19);
uniform vec3 tert_base_color: source_color = vec3(0.55, 0.56, 0.18);
uniform vec3 tert_tip_color: source_color = vec3(0.68, 0.71, 0.33);
uniform float prim_color_ratio: hint_range(0.0, 1.0) = 0.7;
uniform float seco_color_ratio: hint_range(0.0, 1.0) = 0.5;
...

void fragment() {
    ...
    vec3 base_color, tip_color;
    float prim_color_flag = step(prim_color_ratio, instance_rand_num);
    float seco_color_flag = step((1.0-prim_color_ratio)*seco_color_ratio + prim_color_ratio, instance_rand_num);
    base_color = mix(mix(prim_base_color, seco_base_color, prim_color_flag), tert_base_color, seco_color_flag);
    tip_color = mix(mix(prim_tip_color, seco_tip_color, prim_color_flag), tert_tip_color, seco_color_flag);
    float rand_coeff_base = (hash13(world_position.zyx) - 0.5)*2.0;
    float rand_coeff_tip = (hash13(world_position.yzx) - 0.5)*2.0;
    base_color += rand_coeff_base/15.0;
    tip_color += rand_coeff_tip/15.0;
    vec3 albedo_color = mix(base_color, tip_color, UV.x - 0.5);
    ...
}
```

>**Note** that this level of color variation can be too elaborate and probably unnecessary for most applications. While not very damaging to the overall performance of the shader, it could be made generally more efficient, for example, by avoiding randomness, or using just one color scheme.

We add more detail to the mesh by using two complementary strategies. The first is drawing darker "veins" on the blade by sampling a 1D noise that we stretch over the length of the mesh:

```glsl
uniform float veins_strength: hint_range(0.0, 1.0) = 0.3;
...

void fragment() {
    ...
    vec3 tex_color = texture(veins_texture, UV.yx).rgb;
    ALBEDO = mix(albedo_color, (1.0-veins_strength)*albedo_color, tex_color);
    ...
}
```

Finally, we give the impression of a more complex shape to the blade by reflecting light differently along its width, creating a central ridge and outer rims on the blade. We do this by slightly perturbing the ```NORMAL``` vector either towards the axis of the blade (in the case of the ridge) or away from it (in the case of the rim):

```glsl
void fragment() {
    ...
    vec2 adjustment_coeffs = normal_adjustment_coeff(UV.yx).yx;
    vec3 normal_adjustment_vec = TANGENT*adjustment_coeffs.x + BINORMAL*adjustment_coeffs.y;
    NORMAL = normalize(NORMAL + normal_adjustment_vec);
    ...
}
```

Again, this solution avoids drawing extra vertices, which would be computationally more expensive.


## 2.2. Instantiation

## 2.3. Terrain

## 2.4. Environmental extras

In order to have a more immersive environment, some additional features were included in the project. Specifically, a dynamic day-night cycle was added onto the game, by using the [Sky3D open-source Godot add-on](https://github.com/TokisanGames/Sky3D). This provides more diverse lighting conditions in which our grass can be analyzed.

Moreover, a "firefly" effect was developed by using a simple ```GPUParticles3D``` that generates small, flickering lights that fly over the grass. This effect interacts with the day-night cycle code, to guarantee that fireflies only spawn during night time.


# 3. Performance and results

Although there is no strict metric for measuring realism in grass rendering, we believe the results achieved here convey a natural and dynamic appearance. The blades vary in shape and color, respond to wind, and visibly deform under the player's weight. In addition to replicating common techniques used in real-time graphics, the project also explores more advanced features, such as deformation based on the player's movement history rather than just their current position.

# 4. Future improvements

Several improvements could be made to provide more realistic &mdash; or at the very least, more complex &mdash; grass fields.

### More complex player interaction

At the moment, the player interacts with the grass blades by simply "crushing" them. In a more realistic implementation, grass blades (especially taller ones) would not be entirely crushed, and would instead "wave" or oscillate when the player is nearby, which is an effect typical in videogames. This would probably require, instead of custom shader logic, some kind of collision detection between the player and the blades, which could become computationally prohibitive depending on the density of the field.

Other interactions, such as cutting down blades depending on the player's actions, could potentially be implemented on the shader, and would be another improvement.

### Environmental interactions

The same buffer+texture approach described before for player interaction could be similarly used to affect the grass in different ways, such as burning it or making it wet. We could simulate burning grass by using a texture that, instead of changing the blade geometry, makes it darker and applies some ember particle effect. Simulating wetness is equivalent, but requires changing the lighting of the blades to make it glossier.

# References

- [UE5 Procedural Grass using Bezier Curves](https://youtube.com/playlist?list=PLfi0x1Dte6TnY1NIotJyD5ERpBozTnCUp&si=3-OGLLH4P4objgy7)
- [Infinite Grass - Devlog](https://www.youtube.com/watch?v=cesPK0kYkyE)
- [Interactive Grass in Godot](https://notcoding.today/blog/godot-interactive-grass)
- [GodotGrass](https://github.com/2Retr0/GodotGrass)