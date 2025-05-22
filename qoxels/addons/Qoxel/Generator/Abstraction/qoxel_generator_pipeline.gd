## Class uses for generation 3D chunk texture
## Has stages: 
## 1 : Generate main data by using GPU glsl shader
## 2 : Generate override data as structures or special ores
@tool class_name QoxelGeneratorPipeline extends Resource

@export_file("*.glsl") var shader_path : String;

func generate(chunk : QoxelChunk, chunk_id : Vector3i, properties : QoxelGenerationProperties, use_shader_phase = true) -> QoxelChunk:
	var output_texture : ImageTexture;
	
	var format = Image.FORMAT_RGBAF;
	
	if use_shader_phase :
		var compresser = ImageCompresser.new();
		compresser.shader = shader_path;
		compresser.cube_size = properties.cube_size;
		compresser.seed = properties.seed;
		compresser.scale = properties.scale;
		compresser.offset = Vector3i(chunk_id.x, chunk_id.z, -chunk_id.y);
		compresser.start_pipeline(chunk);
		output_texture = compresser.output_texture;
	else:
		print("Create image")
		var image = Image.create(properties.cube_size * properties.cube_size, properties.cube_size, false, format);
		image.fill(Color(1000.0, 1000.0, 1000.0, 1.0));
		chunk.solid_voxels = properties.cube_size * properties.cube_size * properties.cube_size;
		output_texture = ImageTexture.create_from_image(image);
		chunk.buffer_data[0] = chunk.solid_voxels;
	
	chunk.image = output_texture;
	
	return chunk;
