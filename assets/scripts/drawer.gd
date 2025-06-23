# res://scripts/drawer.gd   (attach to the Node2D called Drawer)
@tool
extends Node2D
"""
Keeps a small splat-map centred on the player and paints white circles
(footprints).  Compatible with Godot 4.4 – uses clear_mode = CLEAR_MODE_ONCE.
"""

# ───────────────── Tunables ─────────────────
@export var map_size        : float = 50.0      # metres (edge length)
@export var footprint_r_m   : float = 1.6       # footprint radius (m)
@export var linger_frames   : int = 20          #   30 frames  ≈ 0.5 s at 60 fps
@export var fade_curve      : Curve
var fade_frames             : int
var history_length          : int

# Scene references
var player: CharacterBody3D
# ────────────────────────────────────────────

@onready var vp      : SubViewport = get_viewport()  # the FootMap viewport
@onready var vp_size : Vector2     = vp.size         # e.g. (512, 512)
var map_origin       : Vector3                       # bottom-left corner of the square

func _ready() -> void:
	player = get_node("../../Player")
	if player:
		_recenter(player.global_position)
		history_length = player.POS_ARRAY_LENGTH
		fade_frames = player.POS_ARRAY_LENGTH - linger_frames

	RenderingServer.global_shader_parameter_set("footpath_size",  map_size)
	RenderingServer.global_shader_parameter_set("footpath_tex", vp.get_texture())
	set_physics_process(true)

# ───────── Main loop ─────────
func _physics_process(_delta: float) -> void:
	if not player: return
	RenderingServer.global_shader_parameter_set("PLAYER_POSITION", player.global_position)
	_recenter(player.global_position)
	_update_shader_uniforms()
	queue_redraw()

func _recenter(pos: Vector3) -> void:
	# move the square so the player is centred in it
	map_origin = Vector3(pos.x - map_size * 0.5, 0.0, pos.z - map_size * 0.5)


func _update_shader_uniforms() -> void:
	RenderingServer.global_shader_parameter_set("footpath_origin", Vector2(map_origin.x, map_origin.z))
	

# ───────── Helpers ─────────
func _world_to_tex(world_pos: Vector3) -> Vector2:
	return Vector2(
		(world_pos.x - map_origin.x) / map_size,
		(world_pos.z - map_origin.z) / map_size
	) * vp_size;

	
func _draw() -> void:
	if not is_instance_valid(player) or not player.get("position_image"):
		return

	var history_image: Image = player.position_image
	var current_write_index: int = player.position_array_index

	var r_px := footprint_r_m / map_size * vp_size.x

	# --- NEW, CORRECTED LOOP ---
	# We now loop through the "age" of the footprints, from oldest to newest.
	# The range() goes from (127) down to (0).
	# This ensures we draw the dimmest circles first, and the brightest one last.
	for age_step in range(history_length - 1, -1, -1):
		# Calculate the actual index in the buffer based on its age
		var buffer_index = (current_write_index - 1 - age_step + history_length) % history_length
		# Get the pixel data from the correct index
		var pos_color: Color = history_image.get_pixel(buffer_index, 0)
		
		if pos_color.a > 0.5:
			var brightness : float
			if age_step < linger_frames:
				brightness = 1.0                        # hold at full bend
			else:
				var t = float(age_step - linger_frames) / float(max(fade_frames, 1))
				brightness = clamp(fade_curve.sample(t), 0.0, 1.0)
			
			if brightness == 0.0:
				continue
			
			# Brightness is now directly related to the age_step
			#var brightness = 1.0 - (float(age_step) / float(history_length))
			var trail_color = Color(brightness, brightness, brightness)
			
			var world_pos := Vector3(pos_color.r, pos_color.g, pos_color.b)
			var center_px := _world_to_tex(world_pos)
			
			draw_circle(center_px, r_px, trail_color)
