@tool class_name QBox extends MeshInstance3D

@export var world : QoxelWorld;

@export var qbox_size = 128:
	set(v):
		if v != qbox_size:
			qbox_size = v;
			if Engine.is_editor_hint():
				generate();

@export var resolution = 1.0:
	set(v):
		if v != resolution:
			resolution = v;
			if Engine.is_editor_hint():
				generate();

var is_generates = false;

func _ready() -> void:
	var parent = get_parent();
	if parent is QoxelWorld:
		world = parent;
	generate();

func is_generated() -> bool:
	return mesh != null;

func _physics_process(delta: float) -> void:
	pass;

func generate():
	if !is_generates:
		is_generates = true;
		if is_instance_valid(world):
			qbox_size = world.world_size;
			resolution = world.world_resolution;
		
		mesh = QoxelThreeQuads.create(qbox_size, qbox_size * resolution);
		
		if material_override is ShaderMaterial:
			material_override.set_shader_parameter("world_size", qbox_size * Vector3.ONE);
		
		is_generates = false;

func update(world_instance : QoxelWorld = world, mask = null):
	world = world_instance;
	print("MASK:",mask)
	if material_override is ShaderMaterial && is_instance_valid(world):
		material_override.set_shader_parameter("tileset_normalmap", world.tileset_normalmap);
		material_override.set_shader_parameter("tileset", world.tileset_albedo);
		material_override.set_shader_parameter("tileset", world.tileset_albedo);
		material_override.set_shader_parameter("compressed_tex", mask);
		
		
