@tool
extends Node3D

var _prev_pos : Vector3;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_prev_pos = $Player.global_position;


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	var curr_pos : Vector3 = $Player.global_position
	var vel      : Vector3 = (curr_pos - _prev_pos) / delta
	_prev_pos = curr_pos
	RenderingServer.global_shader_parameter_set('player_position', curr_pos)
	RenderingServer.global_shader_parameter_set('player_velocity', vel)
