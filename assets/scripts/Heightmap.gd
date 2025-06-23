extends Node

var image:Image = load(ProjectSettings.get_setting("shader_globals/heightmap").value).get_image()
var image_size = image.get_width()
var amplitude:float = ProjectSettings.get_setting("shader_globals/amplitude").value

func _get_height(x: int, z: int) -> float:
	return image.get_pixel(fposmod(x, image_size), fposmod(z, image_size)).r * amplitude + 0.5

func get_height(x: float, z: float) -> float:
	var x0 = floori(x)
	var x1 = x0 + 1
	var z0 = floori(z)
	var z1 = z0 + 1
	
	var h00 = _get_height(x0, z0)
	var h10 = _get_height(x1, z0)
	var h01 = _get_height(x0, z1)
	var h11 = _get_height(x1, z1)
	
	var tx = x - x0
	var tz = z - z0
	
	var h0 = lerp(h00, h10, tx)
	var h1 = lerp(h01, h11, tx)
	
	return lerp(h0, h1, tz)

	
