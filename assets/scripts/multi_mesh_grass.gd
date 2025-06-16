@tool
extends GeometryInstance3D

@export var density: float = 0.2
@export var high_definition_radius: float = 25.0
@export var medium_definition_radius: float = 500.0 

const big_number = 1000
func _ready():
	var high = new_mesh(16, estimate_number_of_instances_in_the_circle(high_definition_radius/density))
	var high_count = 0
	var medium = new_mesh(0, estimate_number_of_instances_in_the_circle(high_definition_radius/density))
	var medium_count = 0;
	var low = new_mesh(0, big_number*big_number)
	var low_count = 0;

	for i in range(big_number*big_number):
		var x = (i/big_number - big_number/2)*density
		var y = (i%big_number - big_number/2)*density
		var offset = Vector2(x, y)
		var t = Transform3D(Basis(), Vector3(offset.x, 0, offset.y))
		
		var distance = offset.distance_squared_to(Vector2(0, 0));
		if distance < high_definition_radius: 
			high.multimesh.set_instance_transform(high_count, t)
			high_count += 1
		elif distance < medium_definition_radius:
			medium.multimesh.set_instance_transform(medium_count, t)
			medium_count += 1
		else:
			low.multimesh.set_instance_transform(low_count, t)
			low_count += 1
	
	high.multimesh.visible_instance_count = high_count
	medium.multimesh.visible_instance_count = medium_count
	low.multimesh.visible_instance_count = low_count
	
	add_child(high)
	add_child(medium)
	add_child(low)
#
#func _process(delta: float) -> void:
	#var fps = Engine.get_frames_per_second()
	#print("fps: ", fps)
	
func new_mesh(subdivision_with: int, instance_count: int) -> MultiMeshInstance3D:
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = MultiMesh.new()
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mmi.multimesh.instance_count = instance_count
	
	var mesh = PlaneMesh.new()
	mesh.center_offset = Vector3(0.5, 0.0, 0.0)
	mesh.size = Vector2(1.0, 1.0)
	mesh.subdivide_width = subdivision_with
	mesh.material = preload("res://assets/materials/grass_blade.tres")
	
	mmi.multimesh.mesh = mesh
	return mmi

func estimate_number_of_instances_in_the_circle(radius: float) -> int:
	return ceil(radius * radius * PI)
