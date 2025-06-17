extends SpringArm3D

@export var mouse_sensibility : float = 0.005
@export_range (-90.0, 0.0, 0.1, "radians_as_degress") var min_vertical_angle: float = -PI/2
@export_range (0.0, 90.0, 0.1, "radians_as_degress") var max_vertical_angle: float = PI/4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * mouse_sensibility
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		
		rotation.x -= event.relative.y * mouse_sensibility
		rotation.x = wrapf(rotation.x, min_vertical_angle, max_vertical_angle)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
