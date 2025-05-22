@tool class_name QoxelChunk extends Resource

@export var img : Image;
@export var image : ImageTexture;
@export var buffer_data : PackedInt32Array = [0, 0, 0, 0];
@export var size : Vector2;

var world : QoxelWorldGenerator;
var cache : Dictionary = {};

var solid_voxels = 0;

var delayed_commit : SceneTreeTimer;

var chunk_name : String;
var chunk_path : String;

func _init():
	pass;

func loaded(_world : QoxelWorldGenerator, _chunk_name : String, _chunk_path : String) -> void:
	size = image.get_size();
	world = _world;
	chunk_name = _chunk_name;
	chunk_path = _chunk_path;
	update_buffer_data();

func get_voxel(voxel_position : Vector3i) -> Color:
	var x = voxel_position.x + (size.y * (voxel_position.y));
	var imp = Vector2(x, voxel_position.z);
	
	if imp.x < size.x && imp.y < size.y && imp.x >= 0.0 && imp.y >= 0.0:
		return img.get_pixelv(imp);
	return Color.BLACK;

func set_voxel(voxel_position : Vector3i, color : Color) -> void:
	var x = voxel_position.x + (size.y * (voxel_position.y));
	var imp = Vector2(x, voxel_position.z);
	
	if imp < size && imp.x >= 0.0 && imp.y >= 0.0:
		if color.r > 0.0:
			## Add solid block
			if img.get_pixelv(imp).r <= 0.0:
				buffer_data[0] += 1
				update_buffer_data();
		else:
			 ## Remove solid block
			if img.get_pixelv(imp).r > 0.0:
				buffer_data[0] -= 1;
				update_buffer_data();
		
		img.set_pixelv(imp, color);
		commit_request();

func set_chunk(new_img : Image, new_solid_voxels_count = buffer_data[0]):
	new_img.convert(Image.FORMAT_RGBAF);
	image.set_image(new_img);
	img = new_img;
	buffer_data[0] = new_solid_voxels_count;
	#commit_request();

func update_buffer_data():
	solid_voxels = buffer_data[0];

func commit_request():
	QoxelManager.callp(commit);

func commit():
	delayed_commit = null;
	image.set_image(img);
	if world.save_chunks:
		save();

func save():
	ResourceSaver.save(self, chunk_path, ResourceSaver.FLAG_COMPRESS);
