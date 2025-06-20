@tool
extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var camera := $SpringArmPivot/Camera3D
@onready var gobot := $GobotSkin
@onready var springarm := $SpringArmPivot
@export var POS_ARRAY_LENGTH = 256

var position_image: Image
var position_array_tex: ImageTexture
var position_array_index := 0

func _ready():
	_initialize_position_array()


func _physics_process(delta: float) -> void:
	# Player position
	_update_position_array()
	
	
	if Engine.is_editor_hint():
		return
	
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		gobot.jump()

	# Input movement
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	direction = direction.rotated(Vector3.UP, camera.global_rotation.y)

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		gobot.run()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		gobot.idle()

	# Falling
	if velocity.y < -1 and not is_on_floor():
		gobot.fall()
		
	var target_yaw = springarm.global_rotation.y + PI
	gobot.rotation.y = lerp_angle(gobot.rotation.y, target_yaw, delta * 10.0) 

	move_and_slide()
	
	
func _initialize_position_array():
	position_image = Image.create(POS_ARRAY_LENGTH, 1, false, Image.FORMAT_RGBAF)
	position_image.fill(Color(0, 0, 0, 0))
	position_array_tex = ImageTexture.create_from_image(position_image)
	RenderingServer.global_shader_parameter_set("POS_ARRAY_LENGTH", POS_ARRAY_LENGTH)
	RenderingServer.global_shader_parameter_set("position_array_tex", position_array_tex)
	RenderingServer.global_shader_parameter_set("position_array_index", position_array_index)

func _update_position_array():
	var global_pos: Vector3 = global_position
	var alpha : float = 1.0 if Engine.is_editor_hint() else is_on_floor()

	position_image.set_pixel(position_array_index, 0, Color(global_pos.x, global_pos.y, global_pos.z, alpha))
	position_array_index = (position_array_index + 1) % POS_ARRAY_LENGTH

	position_array_tex.update(position_image)
	RenderingServer.global_shader_parameter_set("position_array_tex", position_array_tex)
	RenderingServer.global_shader_parameter_set("position_array_index", position_array_index)
