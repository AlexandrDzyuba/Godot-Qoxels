@tool

## Class uses to create three quads with special UV and UV2 for using in shaders
##
class_name QoxelThreeQuads extends MeshInstance3D


enum Axis { AXIS_X, AXIS_Y, AXIS_Z }

@export var quad_size = 128;
@export var quad_count = 128;

@export var update_mesh = false:
	set(v):
		update_mesh = false;
		if v:
			_update_mesh();

func _update_mesh():
	mesh = create(quad_count, quad_size);

## Function create one quad with special uv by axis
static func create_quad_mesh(quad_index : float, axis : Axis, quad_size : float, quad_idx : int) -> ArrayMesh:
	var st := ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var vertices = []
	var uvs = [
		Vector2(0, 1), Vector2(0, 0), Vector2(1, 0),
		Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)
	]
	var axis_idx = float(axis)/3.0;
	
	var uvs2 = [
		Vector2(quad_index, 0), Vector2(quad_index, 0), Vector2(quad_index, 0),
		Vector2(quad_index, 0), Vector2(quad_index, 0), Vector2(quad_index, 0)
	]
	
	match axis:
		Axis.AXIS_X:
			vertices = [
				Vector3(0, 0.5 * quad_size, -0.5 * quad_size), Vector3(0, -0.5 * quad_size, -0.5 * quad_size), Vector3(0, -0.5 * quad_size, 0.5 * quad_size),
				Vector3(0, 0.5 * quad_size, -0.5 * quad_size), Vector3(0, -0.5 * quad_size, 0.5 * quad_size), Vector3(0, 0.5 * quad_size, 0.5 * quad_size)
			]
			
		Axis.AXIS_Y:
			vertices = [
				Vector3(-0.5 * quad_size, 0, -0.5 * quad_size), Vector3(-0.5 * quad_size, 0, 0.5 * quad_size), Vector3(0.5 * quad_size, 0, 0.5 * quad_size),
				Vector3(-0.5 * quad_size, 0, -0.5 * quad_size), Vector3(0.5 * quad_size, 0, 0.5 * quad_size), Vector3(0.5 * quad_size, 0, -0.5 * quad_size)
			]
			
			for i in uvs.size():
				uvs[i] = Vector2(uvs[i].x, 1.0-uvs[i].y)
			
			for i in uvs2.size():
				uvs2[i] = Vector2(1.0-quad_index, 0.0)
		Axis.AXIS_Z:
			vertices = [
				Vector3(-0.5 * quad_size, 0.5 * quad_size, 0), Vector3(-0.5 * quad_size, -0.5 * quad_size, 0), Vector3(0.5 * quad_size, -0.5 * quad_size, 0),
				Vector3(-0.5 * quad_size, 0.5 * quad_size, 0), Vector3(0.5 * quad_size, -0.5 * quad_size, 0), Vector3(0.5 * quad_size, 0.5 * quad_size, 0)
			]
			
	
	for i in range(vertices.size()):
		surface_tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT);
		surface_tool.set_custom(0, Color(quad_idx, 0.0, 0.0, 0.0));
		
		surface_tool.set_color(Color(axis_idx, quad_index, 0));
		surface_tool.set_uv2(uvs2[i]);
		surface_tool.set_uv(uvs[i]);
		surface_tool.add_vertex(vertices[i]);
	
	surface_tool.index()
	
	surface_tool.generate_normals();
	
	surface_tool.commit(st)

	return st

## Function create three quads with special UV and UV2 for using in shaders
static func create(quad_count : int, quad_size : float) -> Mesh:
	var combined_mesh := ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var offset = Vector3.ONE * quad_size/2;
	
	for axis in Axis.values():
		var qcount = quad_count;
		var qscount = quad_count;
		var aaxis = Vector3(0, 1, 0);
		match(axis):
			Axis.AXIS_X:
				aaxis = Vector3(1, 0, 0);
				qcount += 1;
			Axis.AXIS_Y:
				aaxis = Vector3(0, 1, 0);
				qcount += 1;
			Axis.AXIS_Z:
				aaxis = Vector3(0, 0, 1);
				qcount += 1;
		
		for i in range(qcount):
			var quad_index := float(i) / float(qscount);
			var quad_mesh := create_quad_mesh(quad_index, axis, quad_size, i);
			var transf := Transform3D(Basis(), ((aaxis * (i * (quad_size/(qscount))) ) - (aaxis * quad_size/2)) + offset);
			
			surface_tool.append_from(quad_mesh, 0, transf);

	surface_tool.commit(combined_mesh)
	return combined_mesh


static func create_with_lods(quad_count : int, quad_size : float, resolution : float) -> ArrayMesh:
	var array_mesh := ArrayMesh.new();
	
	var meshes : Array[ArrayMesh] = [];
	for i in resolution:
		var variant := create(quad_count * i, quad_size);
		
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, variant.surface_get_arrays(0), [], {i*2 : variant.surface_get_arrays(0)[3]})
	
	return array_mesh;
