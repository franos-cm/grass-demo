@tool
extends Node3D

const GRASS_MAT := preload('res://assets/materials/grass_blade.tres')

@onready var flat_color_emission_coeff := [GRASS_MAT.get_shader_parameter('flat_color_emission_coeff')]
@onready var grass_type := [GRASS_MAT.get_shader_parameter('grass_type')]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GrassField/GrassFieldMultiMesh.init_with_player($Player)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_render_imgui()


func _render_imgui() -> void:
	ImGui.Begin(' ', [], ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_NoMove)
	ImGui.SetWindowPos(Vector2(20, 20))
	ImGui.PushStyleColor(ImGui.Col_Text, Color.WEB_GRAY); 

	ImGui.Text("FPS: %d" % Engine.get_frames_per_second())
	ImGui.PopStyleColor()
	ImGui.SeparatorText('Grass')
	ImGui.Text("Render Mode")

	if ImGui.RadioButton("Default", grass_type[0] == 0):
		grass_type[0] = 0
		GRASS_MAT.set_shader_parameter('grass_type', grass_type[0])
	ImGui.SameLine();
	if ImGui.RadioButton("Toon", grass_type[0] == 1):
		grass_type[0] = 1
		GRASS_MAT.set_shader_parameter('grass_type', grass_type[0])


	ImGui.End()
