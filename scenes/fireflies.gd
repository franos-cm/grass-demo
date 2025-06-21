@tool
extends GPUParticles3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var sky := get_node("../../../Sky3D/Skydome")         # Skydome node
	sky.day_night_changed.connect(_on_day_night_changed)
	# initialise to current state
	visible = true
	_on_day_night_changed(sky.is_day())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_day_night_changed(is_day: bool) -> void:
	emitting = !is_day
