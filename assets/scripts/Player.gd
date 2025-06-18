extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
@onready var camera := $SpringArmPivot/Camera3D
@onready var gobot := $GobotSkin
@onready var springarm := $SpringArmPivot

func _physics_process(delta: float) -> void:
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
