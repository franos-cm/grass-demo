#@tool
extends GeometryInstance3D

var player: CharacterBody3D
@export var high_density: float = 0.2
@export var high_quality: int = 4
@export var chunks_number: int = 7
@export var chunk_size: float = 40

class Chunk:
	var index: Vector2i
	var quality: float
	var density: float
	var mmi: MultiMeshInstance3D
	var mesh: PlaneMesh
	
	static func new_with(index: Vector2i, mmi: MultiMeshInstance3D, mesh: PlaneMesh, quality:int, density:float) -> Chunk:
		var c = Chunk.new()
		c.index = index
		c.mmi = mmi
		c.mesh = mesh
		c.quality = quality
		c.density = density
		return c

var chunks: Array[Chunk]

func _ready():
	pass

func init_with_player(p: Node3D) -> void:
	player = p
	for i in range(-chunks_number, chunks_number):
		for j in range(-chunks_number, chunks_number):
			var chunk = instance_chunk(Vector2i(i, j))
			maybe_fill_chunk(chunk, player.global_position)
			chunks.push_back(chunk)

func instance_chunk(index: Vector2i) -> Chunk:
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = MultiMesh.new()
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mmi.top_level = true # only absolute position
	mmi.multimesh.instance_count = 0
	
	var mesh = PlaneMesh.new()
	mesh.center_offset = Vector3(0.5, 0.0, 0.0)
	mesh.size = Vector2(1.0, 1.0)
	mesh.material = preload("res://assets/materials/grass_blade.tres")
	
	mmi.multimesh.mesh = mesh
	add_child(mmi)
	
	return Chunk.new_with(index, mmi, mesh, -1, -1)
	
func maybe_fill_chunk(chunk: Chunk, player_position: Vector3):
	var chunk_center: Vector2 = Vector2(chunk.index) + Vector2(chunk_size/2, chunk_size/2)
	var distance: float = player_position.distance_to(Vector3(chunk_center.x, 0, chunk_center.x))
	
	var quality: int = high_quality;
	var density: float = high_density;
	#if distance < chunk_size:
		#quality /= 1
		#density *= 1
	#elif distance < chunk_size*4:
		#quality /= 2
		#density *= 1
	#else:
		#quality /= 4
		#density *= 1
	
	if chunk.density == density and chunk.quality == quality:
		# same, no need to change
		return
		
	print("drawing ", chunk.index)
	
	var count_side: int = ceil(chunk_size/density)
	chunk.mmi.multimesh.instance_count = count_side*count_side
	chunk.mesh.subdivide_width = quality

	
	for i in range(0, count_side):
		for j in range(0, count_side):
			var x = i*density + chunk_size*chunk.index.x + randf_range(-density, density)
			var z = j*density + chunk_size*chunk.index.y + randf_range(-density, density)
			var y = Heightmap.get_height(x, z)
			var rotation = Basis().rotated(Vector3.UP, randf() * TAU)
			var t = Transform3D(rotation, Vector3(x, y, z))
			chunk.mmi.multimesh.set_instance_transform(i*count_side+j, t)
	
	chunk.density = density
	chunk.quality = quality
	

func _process(_delta: float) -> void:
	for chunk in chunks:
		maybe_fill_chunk(chunk, player.global_position)
	#print("fps: ", Engine.get_frames_per_second())
