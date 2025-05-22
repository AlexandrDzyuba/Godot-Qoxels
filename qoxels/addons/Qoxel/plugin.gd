@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("QoxelManager", "res://addons/Qoxel/QoxelManager.gd");
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_autoload_singleton("QoxelManager");
