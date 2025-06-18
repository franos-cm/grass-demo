extends Camera3D

@export var mouse_sensitivity := 0.1
@export var speed := 10.0

var rotation_x := 0.0  # Rotação no eixo vertical (pitch)
var rotation_y := 0.0  # Rotação no eixo horizontal (yaw)

func _ready():
	# Captura o mouse (esconde o cursor e tranca ele no centro da tela)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	# Liberar o mouse ao apertar Esc
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Captura o movimento do mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_y -= event.relative.x * mouse_sensitivity * 0.01
		rotation_x -= event.relative.y * mouse_sensitivity * 0.01
		rotation_x = clamp(rotation_x, deg_to_rad(-89), deg_to_rad(89))  # Limitar olhar pra cima/baixo
		rotation = Vector3(rotation_x, rotation_y, 0)

func _process(delta):
	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += transform.basis.x

	if input_dir.length() > 0:
		translate(input_dir.normalized() * speed * delta)
