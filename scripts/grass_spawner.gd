extends Node3D

@export var hterrain: Node3D  # Arraste aqui o seu HTerrain
@export var grass_scene: PackedScene  # Arraste aqui a cena da grama (grass_scene.tscn)
@export var density: int = 1000  # Quantidade de gramas
@export var area_min: Vector2 = Vector2(0, 0)  # Limite mínimo (x,z)
@export var area_max: Vector2 = Vector2(2049, 2049)  # Limite máximo (x,z)
@export var max_height: float = 200.0  # Altura limite para a grama aparecer

func _ready():
	randomize()
	var printed = false
	for i in range(density):
		var x = randf_range(area_min.x, area_max.x)
		var z = randf_range(area_min.y, area_max.y)
		var y = hterrain.get_height(x, z)
		
		if y > max_height:
			continue  # Não colocar grama em locais muito altos (ex: montanhas)

		var grass_instance = grass_scene.instantiate()
		grass_instance.global_position = Vector3(x, y, z)
		grass_instance.rotation.y = randf_range(0, TAU)
		add_child(grass_instance)
		
		if not printed:
			printed = true
			print("X = " + str(x) + "\nY = " + str(y) + "\nZ = " + str(z))
