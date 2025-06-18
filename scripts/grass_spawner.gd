extends Node3D

@export var hterrain: Node3D
@export var grass_scene: PackedScene
@export var density: int = 5000
@export var area_min: Vector2 = Vector2(0, 0)
@export var area_max: Vector2 = Vector2(2049, 2049)
@export var max_height: float = 1000.0
@export var splat_texture: Texture2D  # Arraste aqui o splat.png

@export var red_threshold: float = 0.5  # Quanto da Texture0 (vermelho) precisa ter para permitir grama

var splat_image: Image

func _ready():
	# Carrega o splatmap como Image para acessar os pixels
	if splat_texture:
		splat_image = splat_texture.get_image()
	else:
		print("Nenhum splat_texture definido!")

	randomize()

	for i in range(density):
		var x = randf_range(area_min.x, area_max.x)
		var z = randf_range(area_min.y, area_max.y)
		var y = hterrain.get_height(x, z)

		if y > max_height:
			continue

		# Verificar o canal R do splatmap (Texture 0)
		if splat_image:
			var pixel_color = get_pixel_color(x, z)

			# Filtra pela quantidade de Texture 0 (vermelho)
			if pixel_color.r < red_threshold:
				continue

		# Instancia a grama
		var grass_instance = grass_scene.instantiate()
		add_child(grass_instance)
		grass_instance.global_position = Vector3(x, y, z)
		grass_instance.rotation.y = randf_range(0, TAU)
		

func get_pixel_color(x: float, z: float) -> Color:
	var tex_width = splat_image.get_width()
	var tex_height = splat_image.get_height()

	# Normalizando x e z para a resolução da textura
	var u = clamp(x / area_max.x, 0.0, 1.0)
	var v = clamp(z / area_max.y, 0.0, 1.0)

	var tex_x = int(u * (tex_width - 1))
	var tex_y = int(v * (tex_height - 1))

	var pixel_color = splat_image.get_pixel(tex_x, tex_y)	
	return pixel_color
