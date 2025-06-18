@tool
extends GeometryInstance3D

@export var density: float = 1
@export var player: Node3D
@export var chunks_number: int = 2
@export var chunk_size: float = 1000

var chunks: Dictionary[Vector2i, MultiMeshInstance3D]

func _ready():
	for i in range(-chunks_number, chunks_number):
		for j in range(-chunks_number, chunks_number):
			var index = Vector2i(i, j)
			var chunk = seed_chunk(index, density, chunk_size, 2)
			chunks[index] = chunk
			add_child(chunk)
		
func seed_chunk(index: Vector2i, density: float, chunk_size: float, quality: int):
	var count_side: int = ceil(chunk_size/density)
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = MultiMesh.new()
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mmi.multimesh.instance_count = count_side*count_side
	
	var mesh = PlaneMesh.new()
	mesh.center_offset = Vector3(0.5, 0.0, 0.0)
	mesh.size = Vector2(1.0, 1.0)
	mesh.subdivide_width = quality
	mesh.material = preload("res://assets/materials/grass_blade.tres")
	
	mmi.multimesh.mesh = mesh
	
	for i in range(0, count_side):
		for j in range(0, count_side):
			var x = i*density + chunk_size*index.x-chunk_size/2
			var z = j*density + chunk_size*index.y-chunk_size/2
			var t = Transform3D(Basis(), Vector3(x, 0, z))
			mmi.multimesh.set_instance_transform(i*count_side+j, t)
	
	return mmi
	
#
func _process(_delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	print("fps: ", fps)
