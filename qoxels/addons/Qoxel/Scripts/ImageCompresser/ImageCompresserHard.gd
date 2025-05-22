@tool class_name ImageCompresserHard extends Node

signal image_rendered(output);

@export var input_texture : Texture2D;

@export var output_texture : Texture2D;

@export var compress = false :
	set(v):
		compress = false;
		if v:
			_compress();

@export var mode : COMPRESS_MODE = COMPRESS_MODE.R8;

enum COMPRESS_MODE {
	R8, RGBA2
}

const image_format_to_compute_format = {
	Image.FORMAT_RGBA8 : RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB,
	Image.FORMAT_RGBAF : RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
}

const compresser_shader : Shader = preload("res://addons/Qoxel/Scripts/ImageCompresser/ViewportImageCompresser.gdshader");

var is_compressing = false;

func _compress():
	
	if !is_compressing:
		for ch in get_children():
			queue_free();
		
		if input_texture != null:
			is_compressing = true;
			start_pipeline();

func start_pipeline():
	var rd := RenderingServer.create_local_rendering_device();
	
	var shader_file = load("res://addons/Qoxel/Scripts/ImageCompresser/compresser.glsl");
	var shader_spirv = shader_file.get_spirv();
	var shader = rd.shader_create_from_spirv(shader_spirv);
	var pipeline = rd.compute_pipeline_create(shader);
	
	var img := input_texture.get_image();
	var img_pba := img.get_data();
	
	var outimg := Image.create(img.get_width(), img.get_height(), false, img.get_format());
	var outimg_pba := outimg.get_data();
	
	var fmt = RDTextureFormat.new();
	fmt.width = input_texture.get_width();
	fmt.height = input_texture.get_height();
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT;
	
	var out_fmt = RDTextureFormat.new();
	out_fmt.width = input_texture.get_width();
	out_fmt.height = input_texture.get_height();
	out_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT;
	
	if img.get_format() in image_format_to_compute_format:
		fmt.format = image_format_to_compute_format[img.get_format()];
		out_fmt.format = image_format_to_compute_format[img.get_format()];
	else:
		printerr("Non valid format in image :", img.get_format(), " Not matched in: ", image_format_to_compute_format);
		is_compressing = false;
		return;
	
	var v_tex = rd.texture_create(fmt, RDTextureView.new(), [img_pba]);
	var o_tex = rd.texture_create(out_fmt, RDTextureView.new(), [outimg_pba]);
	
	var samp_state = RDSamplerState.new();
	samp_state.unnormalized_uvw = true;
	var samp = rd.sampler_create(samp_state);
	
	var output_uniform = RDUniform.new();
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	output_uniform.binding = 0;
	output_uniform.add_id(o_tex);
	
	
	var tex_uniform = RDUniform.new();
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;
	tex_uniform.binding = 1;
	tex_uniform.add_id(samp);
	tex_uniform.add_id(v_tex);
	
	var uniform_set = rd.uniform_set_create([output_uniform, tex_uniform], shader, 0);
	
	# Start compute list to start recording our compute commands
	var compute_list = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	
	rd.compute_list_dispatch(compute_list, fmt.width / 8, fmt.height / 8, 1);
	
	rd.compute_list_end();
	print("Sync and submit")
	#rd.submit();
	#rd.sync();
	
	
	var byte_data = rd.texture_get_data(o_tex, 0);
	#var output := byte_data.to_int32_array();
	print("OUTPUT:",byte_data);
	_on_image_rendered();
	
	RenderingServer.free_rid(rd);
	

func _on_image_rendered():
	print("GENERATED")
	is_compressing = false;


func _physics_process(delta: float) -> void:
	
	pass;
