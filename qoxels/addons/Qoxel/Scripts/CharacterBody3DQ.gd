class_name CharacterBody3DQ extends CharacterBody3D

@export var collider_radius = 0.5;
@export var world : QoxelWorldGenerator;

func qis_on_floor() -> bool:
	return get_qworld().is_qoxel_blocking(global_position - Vector3(0, 1.0, 0));

func qmove_and_slide():
	var current_pos = global_position;
	
	# X-move
	var new_position_x = current_pos + Vector3(velocity.x, 0, 0) * get_physics_process_delta_time()
	if world.is_qoxel_blocking(new_position_x + Vector3(collider_radius * sign(velocity.x), 0, 0)):
		velocity.x = 0
	# Y-move
	var new_position_y = current_pos + Vector3(0, velocity.y, 0) * get_physics_process_delta_time()
	if world.is_qoxel_blocking(new_position_y + Vector3(0, clamp(collider_radius * sign(velocity.y), 0.0, collider_radius), 0)):
		velocity.y = 0
	# Z-move
	var new_position_z = current_pos + Vector3(0, 0, velocity.z) * get_physics_process_delta_time()
	if world.is_qoxel_blocking(new_position_z + Vector3(0, 0, collider_radius * sign(velocity.z))):
		velocity.z = 0
	
	if velocity != Vector3.ZERO:
		move_and_slide()

func get_qworld():
	return world;
