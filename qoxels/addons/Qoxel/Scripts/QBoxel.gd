@tool

class_name QBoxel extends MeshInstance3D

enum Axis { AXIS_X, AXIS_Y, AXIS_Z }

@export var quad_size = 128;
@export var quad_count = 128;

@export var update_mesh = false:
	set(v):
		update_mesh = false;
		if v:
			_update_mesh();

func _update_mesh():
	mesh = create_combined_mesh();

func create_quad_mesh(quad_index : float, axis : Axis) -> ArrayMesh:
	var st := ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var vertices = []
	
	var uvs = [
		Vector2(0, 1), Vector2(0, 0), Vector2(1, 0),
		Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)
	]
	
	var uvs2 = [
		Vector2(quad_index, 0.0),Vector2(quad_index, 0.0),Vector2(quad_index, 0.0),
		Vector2(quad_index, 0.0),Vector2(quad_index, 0.0),Vector2(quad_index, 0.0)
	]
	
	
	match axis:
		Axis.AXIS_X:
			vertices = [
				Vector3(0, 0.5 * quad_size, -0.5 * quad_size), Vector3(0, -0.5 * quad_size, -0.5 * quad_size), Vector3(0, -0.5 * quad_size, 0.5 * quad_size),
				Vector3(0, 0.5 * quad_size, -0.5 * quad_size), Vector3(0, -0.5 * quad_size, 0.5 * quad_size), Vector3(0, 0.5 * quad_size, 0.5 * quad_size)
			]
			
			var qidx = 1.0-quad_index;
			
			
			uvs2 = [
				Vector2(0, 1), Vector2(0, 0), Vector2(1, 0),
				Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)
			]
			
			uvs = [
				Vector2(qidx, 1), Vector2(qidx, 0), Vector2(qidx, 0),
				Vector2(qidx, 1), Vector2(qidx, 0), Vector2(qidx, 1)
			]
			
			for i in uvs.size():
				var b = uvs[i];
				uvs[i] = Vector2(uvs[i].x, uvs[i].y);
			
			
		Axis.AXIS_Y:
			vertices = [
				Vector3(-0.5 * quad_size, 0, -0.5 * quad_size), Vector3(-0.5 * quad_size, 0, 0.5 * quad_size), Vector3(0.5 * quad_size, 0, 0.5 * quad_size),
				Vector3(-0.5 * quad_size, 0, -0.5 * quad_size), Vector3(0.5 * quad_size, 0, 0.5 * quad_size), Vector3(0.5 * quad_size, 0, -0.5 * quad_size)
			]
			
		Axis.AXIS_Z:
			vertices = [
				Vector3(-0.5 * quad_size, 0.5 * quad_size, 0), Vector3(-0.5 * quad_size, -0.5 * quad_size, 0), Vector3(0.5 * quad_size, -0.5 * quad_size, 0),
				Vector3(-0.5 * quad_size, 0.5 * quad_size, 0), Vector3(0.5 * quad_size, -0.5 * quad_size, 0), Vector3(0.5 * quad_size, 0.5 * quad_size, 0)
			]
			
			var qidx = 1.0-quad_index;
			
			
			uvs2 = [
				Vector2(0, 1), Vector2(0, 0), Vector2(1, 0),
				Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)
			]
			
			uvs = [
				Vector2(qidx, 1), Vector2(qidx, 0), Vector2(qidx, 0),
				Vector2(qidx, 1), Vector2(qidx, 0), Vector2(qidx, 1)
			]
			
			for i in uvs.size():
				var b = uvs[i];
				uvs[i] = Vector2(uvs[i].y, 1.0-uvs[i].x);
				
	
	
	
	for i in range(vertices.size()):
		surface_tool.set_uv2(uvs2[i]);
		surface_tool.set_uv(uvs[i])
		surface_tool.add_vertex(vertices[i])
	
	
	surface_tool.index()
	
	surface_tool.generate_normals();
	
	surface_tool.commit(st)

	return st

func create_combined_mesh() -> Mesh:
	var combined_mesh := ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for axis in [Axis.AXIS_X]:
		var offset = Vector3(0, 1, 0);
		var aaxis = Vector3(0, 1, 0);
		match(axis):
			Axis.AXIS_X:
				aaxis = Vector3(1, 0, 0);
			Axis.AXIS_Y:
				aaxis = Vector3(0, 1, 0);
				rotation_degrees = Vector3(-180, 0, 0);
			Axis.AXIS_Z:
				aaxis = Vector3(0, 0, 1);
			
		
		var qcount = quad_count + 1;
		
		for i in range(qcount):
			var quad_index := float(i) / float(qcount - 1)  # Normalize quad index
			var quad_mesh := create_quad_mesh(quad_index, axis)
			var transf := Transform3D(Basis(), (aaxis * (i * (quad_size/(qcount-1.0))) ) - (aaxis * quad_size/2) )
			surface_tool.append_from(quad_mesh, 0, transf)

	surface_tool.commit(combined_mesh)
	return combined_mesh
