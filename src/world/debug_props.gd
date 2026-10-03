class_name DebugProps
extends Node3D
## VAQTINCHALIK — 0-bosqich materiallarini tekshirish uchun.
##
## Ochilgan joyda turadi va masofa bo'yicha terilgan bo'lib, quyidagilarni
## ko'rsatadi: soya uzunligi, ranglar, tumanning masofaga ta'siri.
## 1-bosqichda o'chiriladi (uyning haqiqiy ko'rinishi bilan).
##
##     BoxMesh  — qum tepaligi
##     Cylinder — Kalta Minor (ko'k kafel)
##     Sphere   — to'qog'oy (terak)
##     Box      — saman devor, marshrutka


func _ready() -> void:
	# Xarakterli obyekt: saman devor (Xiva uslubi)
	_box(Vector3(0, 2.0, 0), Vector3(10, 4, 0.6), Palette.SAMAN)

	# Kalta Minor — ko'k kafel, 29 m (asl o'lcham)
	_minor(Vector3(26, 0, -14), 29.0, 14.0)

	# Marshrutka o'lchamida minibus (oq)
	_box(Vector3(-16, 1.4, 6), Vector3(6.5, 2.8, 2.4), Palette.CAR_TANTA_MARSHRUTKA)

	# Chevrolet Spark o'lchamida kichik mashina
	_box(Vector3(-9, 0.8, 9), Vector3(4.0, 1.6, 1.7), Palette.CAR_WHITE)

	# To'qog'ay — terak (yashil shar + qoronti tana)
	_tree(Vector3(16, 0, 10), 7.0)

	# Uzoqdagi obyektlar — tuman masofasini o'lchash uchun
	_tree(Vector3(120, 0, -60), 8.0)
	_box(Vector3(200, 1.5, 40), Vector3(3, 3, 3), Palette.BRICK)
	_minor(Vector3(340, 0, 20), 20.0, 9.0)
	_tree(Vector3(600, 0, 120), 9.0)
	_box(Vector3(900, 2.0, 200), Vector3(4, 4, 4), Palette.TILE_TURQUOISE)


func _box(position: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := _material(color)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = position
	add_child(node)


func _minor(position: Vector3, height: float, diameter: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = diameter * 0.5 * 0.72   # minoralar yuqoriga torayadi
	mesh.bottom_radius = diameter * 0.5
	mesh.height = height
	mesh.radial_segments = 12                  # low-poly — Intel UHD uchun
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(Palette.TILE_TURQUOISE)
	node.position = position + Vector3(0, height * 0.5, 0)
	add_child(node)


func _tree(position: Vector3, height: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.28
	trunk.bottom_radius = 0.4
	trunk.height = height * 0.45
	trunk.radial_segments = 6
	var trunk_node := MeshInstance3D.new()
	trunk_node.mesh = trunk
	trunk_node.material_override = _material(Palette.TRUNK)
	trunk_node.position = position + Vector3(0, height * 0.22, 0)
	add_child(trunk_node)

	var canopy := SphereMesh.new()
	canopy.radius = height * 0.42
	canopy.height = height * 0.9
	canopy.radial_segments = 8
	canopy.rings = 4
	var canopy_node := MeshInstance3D.new()
	canopy_node.mesh = canopy
	canopy_node.material_override = _material(Palette.TUGAY)
	canopy_node.position = position + Vector3(0, height * 0.68, 0)
	add_child(canopy_node)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
