extends Node

var image:Image = load(ProjectSettings.get_setting("shader_globals/heightmap").value).get_image()
var image_size = image.get_width()
var amplitude:float = ProjectSettings.get_setting("shader_globals/amplitude").value

func get_height(x, z):
	return image.get_pixel(fposmod(x, image_size), fposmod(z, image_size)).r * amplitude
