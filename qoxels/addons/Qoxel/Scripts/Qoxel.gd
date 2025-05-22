class_name Qoxel

var position : Vector3i;
var world_position : Vector3i;
var world : QoxelWorld;

func _init(qoxel_world : QoxelWorld, coordinate : Vector3):
	world = qoxel_world;
	position = (int(world.world_size / 2) * Vector3i.ONE) - Vector3i(Vector3(coordinate.floor()) * Vector3(-1, 1, -1));
	position.y -= 1;
	
	#if coordinate.x < 0:
		#position.x -= 1;
	#
	#if coordinate.z < 0:
		#position.z -= 1;
	
	#print(position)
	
	world_position = Vector3i(coordinate);
