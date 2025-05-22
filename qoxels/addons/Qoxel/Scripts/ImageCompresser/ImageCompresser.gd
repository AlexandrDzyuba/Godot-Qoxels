@tool class_name ImageCompresser extends Node

signal image_rendered(output);

@export var output_texture : Texture2D;

@export var output_data : Array;

@export var compress = false :
	set(v):
		compress = false;
		if v:
			_compress();

@export var seed = 0.0;
@export var offset = Vector3(0.0, 0.0, 0.0);

@export var scale = 1.0;
@export var cube_size = 128.0;
@export var noise_slider = 0.04;


@export var mode : COMPRESS_MODE = COMPRESS_MODE.R8;

@export_file("*.glsl") var shader : String;

enum COMPRESS_MODE {
	R8, RGBA2
}

const image_format_to_compute_format = {
	Image.FORMAT_RGBA8 : RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB,
	Image.FORMAT_RGBAF : RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
}

const compresser_shader : Shader = preload("res://addons/Qoxel/Scripts/ImageCompresser/ViewportImageCompresser.gdshader");

var is_compressing = false;

func calculate_atlas_size(x: int, y: int, z: int, compression_z: int) -> Vector2:
	var atlas_size = Vector2(x * (z / compression_z), y);

	return atlas_size

func _compress():
	if !is_compressing:
		is_compressing = true;
		start_pipeline();

func start_pipeline(chunk : QoxelChunk = null):
	is_compressing = false;
	
	var image_size = Vector2i(cube_size * cube_size, cube_size);
	var input_image : Image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBAF);
	input_image.fill(Color.BLACK);
	
	var compute_shader := ComputeHelper.create(shader)
	
	var uniform_input_texture := ImageUniform.create(input_image)
	
	var uniform_output_texture := ImageUniform.create(input_image)
	
	var uoutput_texture := SharedImageUniform.create(uniform_output_texture)
	
	var params := PackedFloat32Array([
		seed, scale, offset.x, offset.y, offset.z, cube_size, noise_slider
	]).to_byte_array();
	
	var parameters_buffer = StorageBufferUniform.create(params);
	
	var output_params := PackedInt32Array([
		0, 0, 0, 0,
	]).to_byte_array();
	
	var output_buffer = StorageBufferUniform.create(output_params);
	#
	compute_shader.add_uniform_array([uniform_input_texture, uoutput_texture, parameters_buffer, output_buffer])
	
	var work_groups := Vector3i(image_size.x / 8, image_size.y / 8, 1)
	RenderingServer.call_on_render_thread(compute_shader.run.bind(work_groups))
	
	ComputeHelper.sync()
	
	output_texture = ImageTexture.new();
	chunk.img = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBAF);
	output_texture.set_image(chunk.img);
	output_data = output_params.to_int32_array();
	
	RenderingServer.call_on_render_thread(_on_image_rendered.bind(chunk, compute_shader, output_buffer, uoutput_texture));
	RenderingServer.call_on_render_thread(compute_shader.free);
	

func _on_image_rendered(chunk : QoxelChunk, compute_shader : ComputeHelper, output_buffer : StorageBufferUniform, uoutput_texture : SharedImageUniform):
	var image := uoutput_texture.get_image();
	chunk.img.set_data(image.get_width(), image.get_height(), false, image.get_format(), image.get_data());
	output_data = output_buffer.get_data().to_int32_array();
	chunk.buffer_data = output_data;
	chunk.update_buffer_data();
	chunk.commit_request();
	queue_free();
