@tool

class_name QoxelWorldGenerator extends Node3D

signal chunk_ready(chunk_id : Vector3i, chunk : QoxelChunk); 

## To-do
## Clean-up addon
## Add support for ray-marching for cubes to support voxel models from atlases
## Add support for transparent layer, possibly divide rendering for some count of layers
## Memory clearing requires

@export var clear = false:
	set(v):
		clear = false;
		if v:
			deinit();

@export var enabled = false :
	set(v):
		if is_valid():
			enabled = v;
			if v:
				init();
			elif initialized:
				deinit();
		else:
			enabled = false;

@export var enable_debuging = false:
	set(v):
		if v !=enable_debuging:
			enable_debuging = v;
			initialize_chunks();

@export var save_chunks = false;

@export var properties : QoxelGenerationProperties;

@export var pipeline : QoxelGeneratorPipeline;
@export var chunks_material : ShaderMaterial;
@export var world_save_path : String = "user://qoxel_worlds/";

@export_range(3, 3 * 10, 2) var chunks_rendering_range = 3 : 
	set(v):
		if chunks_rendering_range != v:
			chunks_rendering_range = v;
			initialize_chunks();

@export_range(0, 3 * 10, 2) var chunks_caching_range = 0 : 
	set(v):
		if chunks_caching_range != v:
			chunks_caching_range = v;
			initialize_chunks();


@export var track_object : Node3D; 

@export_range(0, 128, 1) var threads_treshold = 6;
@export var slider = 0.05:
	set(v):
		slider = v;
		RenderingServer.global_shader_parameter_set("erase_level", v);
var save_world_directory : String = "user://qoxel_worlds/nan/";
var save_world_properties_directory : String = "user://qoxel_worlds/nan/properties.res";
var save_world_chunks_directory : String = "user://qoxel_worlds/nan/chunks/";

var initialized = false;

@export var thread : ThreadsWorker;

@export_group("Optimizations")
@export var skip_empty_chunks = true;
@export var use_visibility_notifier = true;

## Contain chunks data as Vector3i : ChunkData [WARNING] IMPLEMENT far chunks unloading from memory
var chunks_memory = {};
var chunks_waitlist : Array[Vector3i] = [];
var chunks_in_tree : Array = [];
var chunks_in_tree_by_id : Dictionary = {};
var center_chunk_id : Vector3i = Vector3i.ZERO;

var previous_camera_chunk_id : Vector3i;
var forced_chunks_update = false;

var updates_per_frame = 32;

func _ready() -> void:
	chunk_ready.connect(_on_chunk_ready);
	if !Engine.is_editor_hint():
		enabled = true;

var t = 0.1;

func _physics_process(delta: float) -> void:
	
	if initialized && enabled:
		thread.update(delta);
		
		if Engine.is_editor_hint() && enable_debuging:
			if t < 0.0:
				t = 0.5;
				
				var chunk_id = position_to_chunk_id(track_object.global_position);
				var voxel_position = get_voxel_position(track_object.global_position);
				
				$"../cube".global_position = voxel_to_global(voxel_position[0], voxel_position[1]);
				#print(voxel_position, ", block :",is_qoxel_blockingv(voxel_position))
			else:
				t -= delta;
		
		if track_object:
			var camera_chunk_id = position_to_chunk_id(track_object.global_position);
			
			if forced_chunks_update || previous_camera_chunk_id != camera_chunk_id:
				center_chunk_id = camera_chunk_id;
				place_objects_around_point(chunks_in_tree, chunks_rendering_range / 2);
				previous_camera_chunk_id = camera_chunk_id;
				forced_chunks_update = false;
		
		if Input.is_key_pressed(KEY_F1):
			enabled = false;
		if Input.is_key_pressed(KEY_F2):
			clear = true;
			enabled = true;
		if Input.is_key_pressed(KEY_F3):
			print_orphan_nodes()
			
		


func _exit_tree() -> void:
	deinit();

func initialize_chunks():
	if is_valid() && enabled:
		for ch in get_children():
			ch.queue_free();
		
		var quads_mesh = QoxelThreeQuads.create(properties.cube_size * properties.resolution, properties.cube_size);
		
		var bounds_mesh := BoxMesh.new();
		bounds_mesh.size = Vector3(properties.chunk_size) * 0.99;
		 
		var label := Label3D.new();
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED;
		label.pixel_size *= 2.0;
		label.position = properties.chunk_size/2;
		
		chunks_in_tree.clear();
		
		print("Chunks adding")
		
		for i in pow(chunks_rendering_range, 3):
			var chunk = MeshInstance3D.new();
			chunk.mesh = quads_mesh;
			chunk.material_override = chunks_material.duplicate();
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;
			chunk.lod_bias = 1000.0;
			add_child(chunk);
			
			if use_visibility_notifier:
				var VOSE = VisibleOnScreenEnabler3D.new();
				VOSE.aabb.size = Vector3.ONE * properties.cube_size;
				VOSE.aabb.position = Vector3.ZERO;
				chunk.add_child(VOSE);
				VOSE.owner = owner;
			
			if enable_debuging:
				var bounds = MeshInstance3D.new();
				bounds.mesh = bounds_mesh;
				bounds.transparency = 0.5;
				bounds.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF;
				bounds.position = properties.chunk_size/2;
				chunk.call_deferred("add_child", label.duplicate());
				
				chunk.call_deferred("add_child", bounds);
			
			chunk.owner = owner;
			chunks_in_tree.append(chunk);
		
		label.queue_free();
		
		previous_camera_chunk_id = Vector3i.ZERO;
		forced_chunks_update = true;

func update_chunk_mesh(mesh : MeshInstance3D, chunk : QoxelChunk):
	mesh.visible = chunk != null && (chunk.solid_voxels > 0 || !skip_empty_chunks);
	
	if chunk != null:
		mesh.material_override.set_shader_parameter("compressed_tex", chunk.image);
		mesh.material_override.set_shader_parameter("world_size", Vector3.ONE * properties.cube_size);
		

func get_chunk_at(chunk_id : Vector3i) -> QoxelChunk:
	if chunk_id in chunks_memory:
		return chunks_memory[chunk_id];
	elif chunk_id in chunks_waitlist:
		return null;
	
	chunks_waitlist.append(chunk_id);
	
	if thread:
		#if chunk_is_stored(chunk_id):
			#load_chunk(chunk_id);
		#else:
		
		thread.add_task(load_chunk.bind(chunk_id), chunk_id)
	else:
		return load_chunk(chunk_id);
	
	return null;

func chunk_is_stored(chunk_id : Vector3i):
	var chunk_name = vector_to_str(chunk_id);
	var chunk_path = str(save_world_chunks_directory,chunk_name,".res");
	return FileAccess.file_exists(chunk_path);

func load_chunk(chunk_id : Vector3i):
	var chunk : QoxelChunk;
	
	var chunk_name = vector_to_str(chunk_id);
	var chunk_path = str(save_world_chunks_directory,chunk_name,".res");
	
	#Firstly check if the file exists
	if FileAccess.file_exists(chunk_path):
		var loaded = ResourceLoader.load(chunk_path);
		
		if loaded != null:#If yes, load it
			chunk = loaded;
	
	#or else create new and save it
	if !chunk && enabled:
		chunk = QoxelChunk.new();
		chunk.world = self;
		chunk.chunk_path = chunk_path;
		chunk.chunk_name = chunk_name;
		chunk = pipeline.generate(chunk, chunk_id, properties, true);
		
		chunk.world = self
		chunk.call("loaded", self, chunk_name, chunk_path);
	else:
		chunk.call("loaded", self, chunk_name, chunk_path);
	
	if chunk_id in chunks_waitlist:
		chunks_waitlist.remove_at(chunks_waitlist.find(chunk_id));
	
	call_thread_safe("emit_signal", "chunk_ready", chunk_id, chunk)
	
	update_chunk.call_deferred(chunk_id);
	
	#chunk_ready.emit(chunk_id, chunk);
	return true;

func print_chunk(chunk : QoxelChunk):
	pass;
	

func _on_chunk_ready(chunk_id : Vector3i, chunk : QoxelChunk):
	chunks_memory[chunk_id] = chunk;

func place_objects_around_point(objects: Array, num_chunks: int):
	# Індекс для об'єктів (пулу)
	var object_index = 0
	chunks_in_tree_by_id.clear();
	 # Обчислюємо межі для діапазону з урахуванням нечітної кількості чанків
	
	var cnchunks = chunks_caching_range + num_chunks;
	if chunks_caching_range > 0:
		# Перебираємо по осі X, Y, Z у радіусі навколо точки
		for x in range(center_chunk_id.x - cnchunks, center_chunk_id.x + cnchunks + 1, 1):
			for y in range(center_chunk_id.y - cnchunks, center_chunk_id.y + cnchunks + 1, 1):
				for z in range(center_chunk_id.z - cnchunks, center_chunk_id.z + cnchunks + 1, 1):
					if x > center_chunk_id.x - num_chunks && x < center_chunk_id.x + num_chunks + 1:
						continue;
					if y > center_chunk_id.y - num_chunks && y < center_chunk_id.y + num_chunks + 1:
						continue;
					if z > center_chunk_id.z - num_chunks && z < center_chunk_id.z + num_chunks + 1:
						continue;
					
					var chunk_id = Vector3i(x, y, z);
					var chunk = get_chunk_at(chunk_id);
	
	var chunks_order := generate_chunks_in_range(center_chunk_id, num_chunks);
	
	for chunk_id in chunks_order:
		# Перевіряємо, чи є ще об'єкти в пулі
		if object_index >= objects.size():
			return
		
		chunks_in_tree_by_id[chunk_id] = objects[object_index];
		
		var chunk = get_chunk_at(chunk_id);
		
		update_chunk(chunk_id);
		
		object_index += 1

func update_chunk(chunk_id):
	if chunk_id in chunks_in_tree_by_id:
		var object = chunks_in_tree_by_id[chunk_id];
		
		var chunk_pos = chunk_id_to_position(chunk_id)
		
		if center_chunk_id == chunk_id:
			object.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF;
		else:
			object.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF;
		
		object.global_position = chunk_pos;
		
		
		if chunk_id in chunks_memory:
			update_chunk_mesh.call_deferred(object, chunks_memory[chunk_id]);
		else:
			update_chunk_mesh.call_deferred(object, null);
		
		if object.get_child_count() > 0:
			if chunk_id in chunks_memory:
				object.get_child(0).set("text", str([chunk_id, chunks_memory[chunk_id].solid_voxels]));
				update_chunk_mesh.call_deferred(object, chunks_memory[chunk_id]);
			else:
				object.get_child(0).set("text", str(chunk_id));
		

## Function return relative position 
func get_voxel_position(global_pos: Vector3) -> Array[Vector3i]:
	var chunk_size = properties.chunk_size;
	
	var chunk_sizef = Vector3(chunk_size);
	
	var chunk_id = position_to_chunk_id(global_pos);
	
	var global_posi := Vector3i(floor(global_pos));
	
	var chunk_center_pos = chunk_id * chunk_size;
	
	var relative = abs(global_posi - (chunk_center_pos));
	
	return [relative, chunk_id];

## Funcation convert voxel and chunk_id to global voxel positon
func voxel_to_global(voxel : Vector3i, chunk_id : Vector3i) -> Vector3:
	var chunk_center_pos = chunk_id * properties.chunk_size;
	return Vector3(chunk_center_pos + voxel) + Vector3.ONE/2.0;

func get_voxel(_global_position : Vector3i) -> Color:
	var voxel_position = get_voxel_position(_global_position);
	
	if voxel_position[1] in chunks_memory:
		var chunk : QoxelChunk = chunks_memory[voxel_position[1]];
		var vp = voxel_position[0];
		vp.y = properties.chunk_size.y - vp.y - 1;
		
		return chunk.get_voxel(vp);
	
	return Color(1000, 1000, 1000, 1);

func get_voxelv(voxel_position : Array[Vector3i]) -> Color:
	if voxel_position[1] in chunks_memory:
		var chunk : QoxelChunk = chunks_memory[voxel_position[1]];
		var vp = voxel_position[0];
		vp.y = properties.chunk_size.y - vp.y - 1;
		
		return chunk.get_voxel(vp);
	
	return Color.BLACK;

func set_voxel(voxel_position : Array[Vector3i], color : Color):
	if voxel_position[1] in chunks_memory:
		var chunk : QoxelChunk = chunks_memory[voxel_position[1]];
		var vp = voxel_position[0];
		vp.y = properties.chunk_size.y - vp.y - 1;
		
		chunk.set_voxel(vp, color);
		update_chunk(voxel_position[1]);
	else:
		#[WARNING] - Add fast fill for non generated chunk
		pass;

func voxel_is_solid(_global_position : Vector3):
	var vox = get_voxel(round_to_voxel(_global_position));
	return vox.r > 0.0 && !(slider > (vox.r / 8191.0));

func is_qoxel_blocking(_global_position : Vector3):
	return voxel_is_solid(_global_position);

func is_qoxel_blockingv(voxel_position : Array[Vector3i]) -> bool:
	var vox = get_voxelv(voxel_position);
	return vox.r > 0.0 && !(slider > (vox.r / 8191.0));

func round_to_voxel(_global_position : Vector3) -> Vector3i:
	return Vector3i(floor(_global_position));

func ray_cast(start : Vector3, end : Vector3) -> Dictionary:
	var direction = start.direction_to(end);
	var distance = start.distance_to(end);
	var current_pos = start;
	var prevpos = start;
	var steps = int(distance);
	var step = [];
	
	for i in steps + 1:
		var voxel_position := get_voxel_position(floor(current_pos));
		
		if (distance > properties.cube_size && voxel_position[1] in chunks_memory && chunks_memory[voxel_position[1]].solid_voxels == 0):
			pass;
		else:
			var vox := get_voxelv(voxel_position);
			
			var is_solid = vox.r > 0.0 && !(slider > (vox.r / 8191.0));
			
			step.append(voxel_position);
			
			if is_solid:
				return {
						position = current_pos, 
						voxel_position = voxel_position, 
						color = vox,
						normal = -get_hit_normal(current_pos, prevpos, direction),
						passed_voxels = step,
					};
		
		prevpos = current_pos;
		
		current_pos += direction;
		
	
	return {};

func get_hit_normal(hit_position: Vector3, previous_position: Vector3, ray_direction: Vector3) -> Vector3:
	# Різниця між поточною і попередньою позицією визначає напрямок
	var delta = hit_position - previous_position
	
	# Перевіряємо на яку вісь найбільше вплинув рух
	if abs(delta.x) > abs(delta.y) && abs(delta.x) > abs(delta.z):
		return Vector3(sign(ray_direction.x), 0, 0)  # Нормаль на стороні X
	elif abs(delta.y) > abs(delta.x) && abs(delta.y) > abs(delta.z):
		return Vector3(0, sign(ray_direction.y), 0)  # Нормаль на стороні Y
	else:
		return Vector3(0, 0, sign(ray_direction.z))  # Нормаль на стороні Z

func position_to_chunk_id(global_pos: Vector3) -> Vector3i:
	var chunk_size = Vector3(properties.chunk_size);
	return Vector3i(floor(global_pos / chunk_size));

func chunk_id_to_position(chunk_id: Vector3i) -> Vector3i:
	return (chunk_id * properties.cube_size)

func vector_to_str(vector : Vector3):
	return str(vector.x, "_", vector.y, "_", vector.z);

func is_valid():
	return properties && pipeline;

static func sort_by_distance(arr : Array, mean = sum_arr(arr) / arr.size()) -> Array:
	if !arr.is_empty():
		arr.sort_custom(_compare_by_distance.bind(mean));
	return arr;

static func _compare_by_distance(a, b, mean):
	var dist_a = abs(a - mean);
	var dist_b = abs(b - mean);
	
	return dist_a > dist_b;

static func sum_arr(arr : Array) -> float:
	var s = 0;
	for i in arr:
		s += i;
	return s;

# Функція для отримання усіх чанків у порядку від центру
func generate_chunks_in_range(center: Vector3i, range: int) -> Array:
	var chunks = []
	
	# Перебір усіх векторів в межах куба (від -range до range по кожній осі)
	for x in range(-range, range + 1):
		for y in range(-range, range + 1):
			for z in range(-range, range + 1):
				var chunk_position = center + Vector3i(x, y, z)
				chunks.append(chunk_position)
	
	# Сортуємо масив чанків за відстанню від центру
	chunks.sort_custom(_compare_distances.bind(center))
	
	return chunks

# Допоміжна функція для порівняння відстаней
func _compare_distances(a: Vector3i, b: Vector3i, center: Vector3i) -> bool:
	var dist_a = center.distance_to(a)
	var dist_b = center.distance_to(b)
	
	return dist_a > dist_b


func init():
	initialized = true;
	
	if thread:
		thread._init();
	
	#for chunk in chunks_memory.values():
		#pass;
	chunks_memory.clear();
	
	initialize_chunks();
	var zero_chunk = get_chunk_at(Vector3.ZERO);
	
	save();

func deinit():
	if enabled:
		enabled = false;
	
	if thread:
		thread.shutdown();
	
	for ch in get_children():
		ch.queue_free();
	
	chunks_memory.clear();
	
	if initialized:
		initialized = false;
		
		save();

func save():
	if is_valid():
		save_world_directory = str(world_save_path, properties.world_name, "/");
		save_world_properties_directory = save_world_directory + "properties.res";
		save_world_chunks_directory = save_world_directory + "chunks/";
		
		DirAccess.make_dir_recursive_absolute(save_world_chunks_directory);
		ResourceSaver.save(properties, save_world_properties_directory);
