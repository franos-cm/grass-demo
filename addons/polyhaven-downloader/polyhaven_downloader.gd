@tool
@icon("res://addons/polyhaven-downloader/polyhaven_icon.png")
extends Node

const PREFIX := "https://polyhaven.com/a/"
## The Slug of the texture to download. For example, if you want to download the texture "https://polyhaven.com/a/granite_tile_02" this value should be "granite_tile_02"
@export var requested_texture: String:
	set(value):
		value = value.strip_edges().to_lower()
		if value.begins_with(PREFIX):
			requested_texture = value.substr(PREFIX.length())
		else:
			requested_texture = value

## The size of the texture to download.
@export_enum("1k", "2k", "4k", "8k") var texture_size: String = "1k"

## The directory where the imported materials will be saved.
@export_dir var materials_dir: String = "res://assets/materials"

## The blueprint material to use as a base for the imported materials. It will be duplicated and the textures will be replaced.
@export var blueprint: ORMMaterial3D = preload("res://addons/polyhaven-downloader/blueprint.tres")

## Check this to download the texture. It will instantly uncheck itself. Look into the output for the progress or errors.
@export var download: bool = false:
	set(value):
		if value:
			print("Downloading texture...")
			print(requested_texture)
			download_texture()
		download = false

func ensure_dir():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(materials_dir))

func download_texture():
	if not requested_texture or requested_texture == "":
		printerr("Requested Texture is empty")
		return

	ensure_dir()

	var material: ORMMaterial3D = blueprint.duplicate(true)
	material.normal_enabled = true
	material.ao_enabled = true

	material.albedo_texture = await get_texture("jpg", "diff")
	material.normal_texture = await get_texture("jpg", "nor_gl")
	material.orm_texture = await get_texture("jpg", "arm")

	material.uv1_world_triplanar

	print("Saving textures")
	ResourceSaver.save(material, materials_dir + "/" + requested_texture + ".res")


func get_texture(format: String, type: String) -> Texture:
	print("Creating HTTP request")
	var http = HTTPRequest.new()
	add_child(http)

	var link = "https://dl.polyhaven.org/file/ph-assets/Textures/" + format + "/" + texture_size + "/" + requested_texture + "/" + requested_texture + "_" + type + "_" + texture_size + "." + format
	print(link)

	var request = http.request(link)
	if request != OK:
		push_error("Http request error")
	else:
		print("requested")

	print('awaiting completed')
	var res = await http.request_completed
	print("got response")
	var result = res[0]
	var response_code = res[1]
	var headers = res[2]
	var body = res[3]

	if response_code == 404 and type == "diff":
		print("diff not found, trying with diffuse")
		return await get_texture(format, "diffuse")

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")
	print("Request completed")
	prints(response_code)

	var image = Image.new()

	var error: int
	match format:
		"jpg":
			error = image.load_jpg_from_buffer(body)
		"png":
			error = image.load_png_from_buffer(body)
		_:
			push_error("Unsupported format")

	if error != OK:
		push_error("Couldn't load the image.")

	var texture = ImageTexture.create_from_image(image)
	return texture
