@tool

#Чим нижче тим більша різниця у висотах

class_name QoxelWorld extends Node3D

@export var regenerate = false : 
	set(v):
		regenerate = false;
		if v:
			_ready();

@export var qboxes_container : Node3D; 
@export var seed = 100.5;
@export var world_size : int = 128: 
	set(v):
		if v != world_size:
			world_size = v;
			if is_inside_tree():
				_ready();

@export var world_resolution = 1.0;

@export_range(0.01, 1.0, 0.01) var slider = 0.0 : 
	set(v):
		slider = v;
		if is_inside_tree():
			for ch in qboxes_container.get_children():
				if ch is QBox:
					ch.material_override.set_shader_parameter("erase_level", slider);

@export_range(-2, 2.0, 0.001) var normal_slider = 0.0 : 
	set(v):
		normal_slider = v;
		if is_inside_tree():
			for ch in qboxes_container.get_children():
				if ch is QBox:
					ch.material_override.set_shader_parameter("normal", normal_slider);

@export var world_mask : ImageTexture;

@export var use_noise = true;
@export var noise : FastNoiseLite;

@export_group("Textures")

@export var tileset_albedo : CompressedTexture2DArray:
	set(v):
		tileset_albedo = v;
		if is_inside_tree():
			_update_qboxes();

@export var tileset_normalmap : CompressedTexture2DArray:
	set(v):
		tileset_normalmap = v;
		if is_inside_tree():
			_update_qboxes();

var wait_to_commit = false;

var thread: Thread = Thread.new();

func _ready() -> void:
	_update_world_mask();
	_update_qboxes();

func _exit_tree() -> void:
	if thread:
		thread.wait_to_finish();

func _physics_process(delta: float) -> void:
	#_update_qboxes()
	#var a = 8192;
	#var b = 8192;
	#var meta_a = 7;
	#var meta_b = 7;
	
	#var compressed = set_compressed(a, b, meta_a, meta_b);
	#var decompressed = get_compressed(compressed);
	#print([a, b, meta_a, meta_b],">",compressed, "=", decompressed)
	
	$fps.text = str(Engine.get_frames_per_second(), "/", snapped($Character.global_position, Vector3(0.1, 0.1, 0.1)),"/", Qoxel.new(self, $Character.global_position).position);
	if wait_to_commit:
		wait_to_commit = false;
		_qoxel_apply_commit();

func _update_world_mask():
	if !thread:
		thread = Thread.new();
	if thread.is_started():
		thread.wait_to_finish();
	thread.start(_update_world_mask_t);

func _update_world_mask_t():
	print("START")
	
	var compresser = ImageCompresser.new();
	compresser.seed = seed;
	compresser.offset = Vector3(0.0, 0.0, 0.0);
	compresser.scale = 3.0;
	compresser.cube_size = float(world_size);
	
	compresser.start_pipeline();
	print("Compressed:", compresser.output_texture);
	world_mask = compresser.output_texture;
	_update_qboxes();
	print("END")

func _update_qboxes():
	if !is_instance_valid(qboxes_container):
		qboxes_container = self;
	
	for ch in qboxes_container.get_children():
		if ch is QBox:
			ch.update(self, world_mask);
			if !ch.is_generated() || (world_size != ch.qbox_size || world_resolution != ch.resolution):
				ch.generate();

func qoxel_get(qoxel : Qoxel) -> Vector4:
	var voxel : Vector4 = Vector4(0, 0, 0, 0);
	
	var ipos = qoxel.position;
	
	if ipos.y < world_size && ipos.y > 0:
		voxel = decompress(world_mask.get_image(), Vector2(ipos.x, ipos.z) / world_size, world_size, ipos.y);
	
	return voxel;

func qoxel_set(pos : Vector3, color : Color):
	var qoxel : Qoxel = Qoxel.new(self, Vector3(pos));
	
	var ipos = qoxel.position;
	
	pass;# [WARNING] DO IT

func qoxel_commit():
	wait_to_commit = true;

func _qoxel_apply_commit():
	var t = Time.get_ticks_msec();
	#[WARNING] Replace that
	#world_mask.update(world_layers);
	
	print("Commit time",Time.get_ticks_msec() - t);

func voxel_is_solid(coordinate : Qoxel):
	var vox = qoxel_get(coordinate);
	return vox.x > 0.0 && !(slider > vox.x / 8191.0);

func is_qoxel_blocking(pos : Vector3):
	return voxel_is_solid(Qoxel.new(self, Vector3(pos)));

func ray_cast(start : Vector3, end : Vector3) -> Dictionary:
	var direction = start.direction_to(end);
	var distance = start.distance_to(end);
	var current_pos = start;
	
	var steps = int(distance * world_resolution);
	
	for i in steps + 1:
		if is_qoxel_blocking(current_pos):
			return {position = current_pos};
		
		current_pos += direction;
	
	return {};

static func set_compressed(a: float, b: float, meta1: float, meta2: float) -> float:
	# Обмежуємо значення a, b, meta1, meta2 в межах від 0 до відповідних максимумів
	a = clamp(a, 0.0, 8191.0)
	b = clamp(b, 0.0, 8191.0)
	meta1 = clamp(meta1, 0.0, 7.0)
	meta2 = clamp(meta2, 0.0, 7.0)

	# Стискаємо значення, використовуючи 13 біт для a, 13 біт для b, і по 3 біти для кожного метаданого
	return floor(a) * 8192 + floor(b) + floor(meta1) * 8192 * 8192 + floor(meta2) * 8192 * 8192 * 8

static func get_compressed(compressed: float) -> Vector4:
	# Виділяємо метадані meta2
	var meta2 = floor(compressed / (8192.0 * 8192.0 * 8.0))
	compressed -= meta2 * 8192.0 * 8192.0 * 8.0

	# Виділяємо метадані meta1
	var meta1 = floor(compressed / (8192.0 * 8192.0))
	compressed -= meta1 * 8192.0 * 8192.0

	# Виділяємо значення b
	var b = int(compressed) % 8192

	# Виділяємо значення a
	var a = floor(compressed / 8192.0)

	return Vector4(a, b, meta1, meta2)

# Повертає дані для шару [layer] та [layer + 1]
func decompress(compressed_tex: Image, uv: Vector2, cube_size: float, layer: int) -> Vector4:
	var size: float = 1.0 / (cube_size / 8.0)
	var l_div_8: int = layer / 8
	var l_mod_8: int = layer % 8

	# Обчислення зміщеного UV
	var compressed_uv: Vector2 = Vector2(uv.x * size + float(l_div_8) * size, uv.y)
	var compressed: Color = compressed_tex.get_pixelv(Vector2i(compressed_uv * cube_size))

	# Отримання значення каналу і модифікованого layer
	var channel: int = l_mod_8 / 2
	var decompressed: Vector4 = get_compressed(compressed[channel])

	# Витягування необхідних значень
	var idx: float = decompressed[l_mod_8 % 2]
	var meta: float = decompressed[(l_mod_8 % 2) + 2]

	var second_idx: float = decompressed[(l_mod_8 + 1) % 2]
	var second_meta: float = decompressed[((l_mod_8 + 1) % 2) + 2]

	return Vector4(idx, meta, second_idx, second_meta)

func compress():
	pass;
