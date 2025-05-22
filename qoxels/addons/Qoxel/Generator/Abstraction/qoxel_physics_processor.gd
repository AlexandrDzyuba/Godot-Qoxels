@tool class_name QoxelPhysicsProcessor extends Node3D

@export var world : QoxelWorldGenerator;

@export var physical_material : ShaderMaterial;

@export_range(0, 32) var physics_threads = 1:
	set(v):
		if v != physics_threads:
			physics_threads = v;
			_initialize();

@export var reload = false:
	set(v):
		reload = false;
		if v:
			_initialize();

@export var handle_ticks = 5;

@export var works = false;

var want_reinit_after_ready = false;

var busy_viewports : Array[SubViewport] = [];
var free_viewports : Array[SubViewport] = [];

var tasks : Array[Vector3i] = [];

func _ready() -> void:
	_initialize();

func can_work() -> bool:
	return physical_material != null && is_instance_valid(world) && world.is_valid();

func _initialize():
	works = false;
	if can_work():
		for ch in get_children():
			ch.queue_free();
		
		busy_viewports.clear();
		free_viewports.clear();
		
		for i in physics_threads:
			var viewport := SubViewport.new();
			viewport.use_hdr_2d = true;
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED;
			viewport.size = Vector2(world.properties.cube_size, world.properties.cube_size) * Vector2(world.properties.cube_size, 1);
			viewport.transparent_bg = true;
			viewport.disable_3d = true;
			viewport.canvas_item_default_texture_filter = SubViewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;
			
			add_child(viewport);
			viewport.owner = owner;
			
			
			var handle_area := ColorRect.new();
			handle_area.set_anchors_preset(Control.PRESET_FULL_RECT);
			handle_area.material = physical_material.duplicate();
			viewport.call_deferred("add_child", handle_area);
			handle_area.set_deferred("owner", owner);
			
			
			free_viewports.append(viewport);
		set_deferred("works", true);
	else:
		want_reinit_after_ready = true;

func _physics_process(delta: float) -> void:
	if can_work() && works:
		if want_reinit_after_ready:
			_initialize();
			want_reinit_after_ready = false;
		
		for chunk_id in world.chunks_in_tree_by_id:
			if !chunk_id in tasks:
				tasks.append(chunk_id);
		
		for i in free_viewports.size():
			for j in tasks.size():
				if !tasks[0] in world.chunks_in_tree_by_id:
					tasks.remove_at(0);
				else:
					if !free_viewports.is_empty():
						start_task(free_viewports[0], tasks[0]);
						free_viewports.remove_at(0);
						tasks.remove_at(0);
		
		for i in range(busy_viewports.size() -1, -1, -1):
			var ticks_to_output = busy_viewports[i].get_meta("ticks_to_output", 0);
			if ticks_to_output <= 0:
				finish_task(busy_viewports[i]);
				free_viewports.append(busy_viewports[i]);
				busy_viewports.remove_at(i);
			else:
				busy_viewports[i].set_meta("ticks_to_output", ticks_to_output - 1);

func start_task(viewport : SubViewport, chunk_id : Vector3i):
	var task_material : ShaderMaterial = viewport.get_child(0).material;
	task_material.set_shader_parameter("input", world.chunks_memory[chunk_id].image);
	task_material.set_shader_parameter("input_size", viewport.size);
	task_material.set_shader_parameter("layers", int(viewport.size.x / viewport.size.y));
	
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;
	viewport.set_meta("ticks_to_output", handle_ticks);
	viewport.set_meta("handled_chunk_id", chunk_id);
	
	busy_viewports.append(viewport);

func finish_task(viewport : SubViewport):
	if can_work():
		var chunk_id = viewport.get_meta("handled_chunk_id");
		if chunk_id in world.chunks_memory:
			var chunk : QoxelChunk = world.chunks_memory[chunk_id];
			chunk.set_chunk(viewport.get_texture().get_image());
