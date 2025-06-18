extends CharacterBody3D

@export var speed: float = 50.0
@export var jump_velocity: float = 2.0
@export var mouse_sensitivity: float = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var rotation_x = 0.0
var mouse_captured = true  # ← Estado inicial: mouse capturado

@onready var neck = $Neck

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion and mouse_captured:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, -1.5, 1.5)
		neck.rotation.x = rotation_x

	# ESC para liberar o mouse
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false

	# Se quiser: clique do mouse para voltar a capturar
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true

func _physics_process(delta):
	var direction = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += transform.basis.x

	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
