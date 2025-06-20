extends Node3D

@export var player:Node3D

func _physics_process(delta: float) -> void:
	global_position = player.global_position.round() * Vector3(1, 0, 1)
	
