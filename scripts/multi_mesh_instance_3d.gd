# Attach this script to your MultiMeshInstance3D node in Godot.
extends MultiMeshInstance3D

@export var instance_count: int = 10000 # Number of instances to create
@export var spawn_radius: float = 200.0 # Radius within which instances will spawn

func _ready():
	# Ensure the MultiMesh resource exists and is properly configured.
	# If you created the MultiMesh resource in the inspector, it will already be set.
	# If not, you might need to create it here:
	print("AAAAAAAAAAAAA")
	if not multimesh:
		print("BBBBBBBBBBBBB")
		multimesh = MultiMesh.new()
		# You MUST set the mesh here if you are creating the MultiMesh in code.
		# Example: multimesh.mesh = preload("res://path/to/your/mesh.res")
		multimesh.mesh = preload("res://grass_mesh.tres")
		# For this example, let's assume the mesh is set in the editor or will be
		# assigned dynamically elsewhere.
		
		# Set the transform format (important for position, rotation, scale)
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		# Set custom data format if needed
		# multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT

	# Set the total number of instances.
	# This will allocate memory for all instances.
	multimesh.instance_count = instance_count

	# Iterate through each instance and set its properties.
	for i in range(instance_count):
		# 1. Create a random position within the spawn radius.
		var random_x = randf_range(-spawn_radius, spawn_radius)
		var random_y = randf_range(-spawn_radius, spawn_radius)
		var random_z = randf_range(-spawn_radius, spawn_radius)
		var position = Vector3(random_x, random_y, random_z)

		# 2. Create a random rotation.
		var rotation = Basis()
		rotation = rotation.rotated(Vector3.UP, randf() * TAU)      # Rotate around Y-axis
		
		# 3. Create a random scale (e.g., between 0.5 and 1.5).
		var scale_factor = randf_range(0.5, 1.5)
		var scale = Vector3(scale_factor, scale_factor, scale_factor)

		# 4. Combine position, rotation, and scale into a Transform3D.
		var transform = Transform3D(rotation, position)
		#transform = transform.scaled(scale)

		# 5. Set the transform for the current instance.
		multimesh.set_instance_transform(i, transform)

		# 6. (Optional) Set a random color for the instance.
		# This requires the MultiMesh's color_format to be set to COLOR_8BIT or COLOR_FLOAT.
		#var random_color = Color(randf(), randf(), randf(), 1.0)
		#multimesh.set_instance_color(i, random_color)

		# 7. (Optional) Set custom data (e.g., to pass to a shader).
		# This requires the MultiMesh's custom_data_format to be set.
		# var custom_data_vec4 = Color(randf(), randf(), randf(), randf())
		# multimesh.set_instance_custom_data(i, custom_data_vec4)

	print("MultiMeshInstance3D ainstances generated: %d" % instance_count)

func _process(delta):
	# Example of dynamic updating: rotate all instances slightly over time.
	# Be careful with per-instance updates in _process, as it can still be CPU intensive
	# if you have an extremely high instance count and complex calculations per instance.
	# For very large counts, consider using shaders for animation.

	# Example: Rotate instances around the Y-axis.
	# To avoid creating a new Transform3D for every instance every frame,
	# it's more efficient to retrieve the existing transform, modify it, and set it back.
	# for i in range(multimesh.instance_count):
	#    var current_transform = multimesh.get_instance_transform(i)
	#    var rotation_speed = 0.5 # radians per second
	#    current_transform = current_transform.rotated(Vector3.UP, rotation_speed * delta)
	#    multimesh.set_instance_transform(i, current_transform)

	# Example: Change instance colors based on some condition.
	# var time_val = Engine.get_physics_frames() * 0.01 # Or OS.get_ticks_msec()
	# for i in range(multimesh.instance_count):
	#    var r = sin(time_val + i * 0.1) * 0.5 + 0.5
	#    var g = cos(time_val + i * 0.05) * 0.5 + 0.5
	#    var b = sin(time_val + i * 0.15) * 0.5 + 0.5
	#    multimesh.set_instance_color(i, Color(r, g, b, 1.0))
	pass
