@tool class_name QoxelGenerationProperties extends Resource

@export var seed : int = 100;
@export var cube_size : int = 128 :
	set(v):
		cube_size = v;
		chunk_size = Vector3i.ONE * cube_size;

@export var world_name : String = "";
@export var scale : float = 1.0;
@export var resolution : float = 1.0;

var chunk_size : Vector3i = Vector3i.ONE * cube_size;
