extends Node3D

var show_gui := false

const GRASS_MAT := preload('res://assets/materials/grass_blade.tres')
@onready var grass_type := [GRASS_MAT.get_shader_parameter('grass_type')]
@onready var prim_base_color := _color_to_array(GRASS_MAT.get_shader_parameter('prim_base_color'))
@onready var prim_tip_color := _color_to_array(GRASS_MAT.get_shader_parameter('prim_tip_color'))
@onready var prim_color_ratio := [GRASS_MAT.get_shader_parameter('prim_color_ratio')]
@onready var wind_texture_speed := [GRASS_MAT.get_shader_parameter('wind_texture_speed')]
@onready var wind_effect_base_amplitude := [GRASS_MAT.get_shader_parameter('wind_effect_base_amplitude')]
var sky: WorldEnvironment

func _color_to_array(c: Color) -> Array:
	return [c.r, c.g, c.b]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GrassField/GrassFieldMultiMesh.init_with_player($Player)
	sky = $Sky3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_render_imgui()


func _render_imgui() -> void:
	if not show_gui:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var window_size = Vector2(1200, 900)  # You may tweak this
	var window_pos = (viewport_size - window_size) * 0.5

	ImGui.SetNextWindowSize(window_size)
	ImGui.SetNextWindowPos(window_pos)
	ImGui.PushStyleVar(ImGui.StyleVar_Alpha, 0.6)
	ImGui.Begin("HUD", [], ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove | ImGui.WindowFlags_AlwaysAutoResize)
	ImGui.SetWindowFontScale(1.5)
	ImGui.PushStyleColor(ImGui.Col_Text, Color.WEB_GRAY)

	ImGui.Text("FPS: %d" % Engine.get_frames_per_second())
	ImGui.PopStyleColor()
	ImGui.SeparatorText('Grass Type')

	if ImGui.RadioButton("Default", grass_type[0] == 0):
		grass_type[0] = 0
		GRASS_MAT.set_shader_parameter('grass_type', grass_type[0])
	ImGui.SameLine();
	if ImGui.RadioButton("Toon", grass_type[0] == 1):
		grass_type[0] = 1
		GRASS_MAT.set_shader_parameter('grass_type', grass_type[0])
		
	ImGui.SeparatorText('Grass Color')
	if ImGui.ColorEdit3("Primary Base Color", prim_base_color):
		GRASS_MAT.set_shader_parameter("prim_base_color", Color(prim_base_color[0], prim_base_color[1], prim_base_color[2]))
	if ImGui.ColorEdit3("Primary Tip Color", prim_tip_color):
		GRASS_MAT.set_shader_parameter("prim_tip_color", Color(prim_tip_color[0], prim_tip_color[1], prim_tip_color[2]))
	if ImGui.SliderFloat("Primary Color Ratio", prim_color_ratio, 0.0, 1.0):
		GRASS_MAT.set_shader_parameter("prim_color_ratio", prim_color_ratio[0])
		
	ImGui.SeparatorText('Wind')
	if ImGui.SliderFloat("Wind Speed", wind_texture_speed, 0.0, 1.0):
		GRASS_MAT.set_shader_parameter("wind_texture_speed", wind_texture_speed[0])
	if ImGui.SliderFloat("Wind Strength", wind_effect_base_amplitude, 0.0, 1.0):
		GRASS_MAT.set_shader_parameter("wind_effect_base_amplitude", wind_effect_base_amplitude[0])
		
	ImGui.SeparatorText("Time Control")
	var enabled := [sky.enable_game_time]
	if ImGui.Checkbox("Enable Game Time", enabled):
		sky.set_game_time_enabled(enabled[0])


	ImGui.End()
	ImGui.PopStyleVar()


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		show_gui = !show_gui
