@tool

class_name Viewport3D extends Node

@export var texture : Texture3D;

@export_file("*.glsl") var shader : String = "";

@export var update_mode : SubViewport.UpdateMode = SubViewport.UpdateMode.UPDATE_ALWAYS;

@export var updated = false;

func update():
	print("Ready to update");
	
	
	updated = true;

func _physics_process(delta: float) -> void:
	var can_update = updated && update_mode == SubViewport.UpdateMode.UPDATE_ALWAYS;
	
	if can_update:
		updated = false;
		call_thread_safe("update");
