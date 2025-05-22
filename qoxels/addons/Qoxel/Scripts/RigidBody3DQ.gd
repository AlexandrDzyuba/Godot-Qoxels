class_name RigidBody3DQ extends RigidBody3D

@export var world : QoxelWorldGenerator;
@export var collider_radius = 0.5;
@export_range(0.0, 0.99) var collide_bounce = 0.5;

var collide_point = Vector3(0, 0, 0);
var collide_direction = Vector3(0, 0, 0);
var collided = Vector3(0, 0, 0);

const AXIES = [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z];  

func rigid_update(delta):
	var current_pos = global_position;
	
	var collide_radius = (collider_radius) * scale[scale.max_axis_index()];
	
	for axis in AXIES:
		var offset = Vector3.ZERO;
		offset[axis] = linear_velocity[axis];
		var new_position_axis = current_pos + offset * delta;
		
		var target_offset = Vector3.ZERO;
		target_offset[axis] = collide_radius * sign(linear_velocity[axis]);
		
		if get_qworld().is_qoxel_blocking(new_position_axis + target_offset):
			linear_velocity[axis] = -linear_velocity[axis] * collide_bounce;
			
			if collided[axis] == 0:
				collide_point[axis] = global_position[axis];
				collide_direction[axis] = sign(linear_velocity[axis]);
				collided[axis] = 1;
			elif (collide_direction[axis] > 0 && global_position[axis] > collide_point[axis]) || (collide_direction[axis] > 0 && global_position[axis] < collide_point[axis]):
				global_position[axis] = collide_point[axis];
		else:
			collided[axis] = 0;
	
	###--- Old collision
	## X-move
	#var new_position_x = current_pos + Vector3(linear_velocity.x, 0, 0) * get_physics_process_delta_time()
	#if get_qworld().is_qoxel_blocking(new_position_x + Vector3(collide_radius * sign(linear_velocity.x), 0, 0)):
		#linear_velocity.x = -linear_velocity.x * collide_bounce;
		#
	## Y-move
	#var new_position_y = current_pos + Vector3(0, linear_velocity.y, 0) * get_physics_process_delta_time()
	#if get_qworld().is_qoxel_blocking(new_position_y + Vector3(0, clamp(collide_radius * sign(linear_velocity.y), 0.0, collide_radius), 0)):
		#linear_velocity.y = -linear_velocity.y * collide_bounce;
		#
	## Z-move
	#var new_position_z = current_pos + Vector3(0, 0, linear_velocity.z) * get_physics_process_delta_time()
	#if get_qworld().is_qoxel_blocking(new_position_z + Vector3(0, 0, collide_radius * sign(linear_velocity.z))):
		#linear_velocity.z = -linear_velocity.z * collide_bounce;
		#

func _physics_process(delta: float) -> void:
	if is_instance_valid(get_qworld()):
		rigid_update(delta);
	else:
		printerr("RigidBody3D-Qoxel want get_qworld() node:", self, ", ", self.name);

func get_qworld():
	return world;
