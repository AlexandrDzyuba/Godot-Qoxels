@tool

class_name QoxelGrid extends Node3D

@export var qbox_size: Vector3 = Vector3(16, 16, 16)
@export var grid_radius: int = 1

var qboxes: Array[Node3D] = []

func _ready():
	create_grid()

func create_grid():
	# Очищаємо старі QBoxes, якщо вони є
	for qbox in qboxes:
		qbox.queue_free()
	qboxes.clear()
	
	# Створюємо нові QBoxes відповідно до grid_radius
	for x in range(-grid_radius, grid_radius):
		for y in range(-grid_radius, grid_radius):
			for z in range(-grid_radius, grid_radius):
				var qbox = QBox.new() # Використовуйте власний клас QBox
				qbox.position = Vector3(x, y, z) * qbox_size
				qboxes.append(qbox)
				add_child(qbox)

func update_grid_position(player_position: Vector3):
	var center_offset = Vector3(grid_radius, grid_radius, grid_radius) * qbox_size
	for qbox in qboxes:
		var local_pos = (qbox.global_transform.origin - player_position + center_offset) / qbox_size
		local_pos = local_pos.snapped(Vector3.ONE)
		
		# Перевірка на вихід за межі радіуса
		for i in range(3): # Перевіряємо по осям X, Y, Z
			if abs(local_pos[i]) > grid_radius:
				local_pos[i] = -grid_radius if local_pos[i] > 0 else grid_radius

		qbox.global_transform.origin = player_position + local_pos * qbox_size - center_offset
