class_name DebugProps
extends Node3D
## VAQTINCHALIK — materiallar, soya va tuman masofasini tekshirish uchun.
##
## Xorazm uslubidagi sinov obyektlari: saman devor, Kalta Minor (ko'k
## kafel), marshrutka o'lchamida minibus, Chevrolet Spark o'lchamida
## mashina, to'qog'oy (terak).
##
## Barchasi o'z o'rnini TerrainGen dan oladi — shuning uchun 2-bosqichdan
## keyin relyef tekis bo'lsa ham ular yer ustidagi qoladi.
##
## 3-bosqichda Tandirchi haqiqiy uyi bilan almashtiriladi.

## Markaziy nuqta — Tandirchi mahallasi, sharqqa qarab.
const CENTRE := Vector2(-1196.0, -452.0)


func _ready() -> void:
	# --- Xiva uslubi: saman devor (10 m uzunlik, 4 m balandlik) ---
	var wall := CENTRE + Vector2(0.0, 0.0)
	_box(wall, Vector3(10.0, 4.0, 0.6), Palette.SAMAN)

	# --- Kalta Minor: 29 m, Ø 14 m, ko'k kafel ---
	_minor(CENTRE + Vector2(26.0, -14.0), 29.0, 14.0)

	# --- Saman uy (mahalla uslubi: 2 qavat, to'rtburchak hovli) ---
	_house(CENTRE + Vector2(-24.0, -18.0), 11.0, 9.0, 7.0)

	# --- Marshrutka (6,5 m) ---
	_box(CENTRE + Vector2(-16.0, 6.0), Vector3(6.5, 2.8, 2.4),
		Palette.CAR_TANTA_MARSHRUTKA, Vector3(0.0, 0.4, 0.0))

	# --- Chevrolet Spark (4,0 m) ---
	_box(CENTRE + Vector2(-9.0, 9.0), Vector3(4.0, 1.6, 1.7),
		Palette.CAR_WHITE, Vector3(0.0, 0.25, 0.0))

	# --- To'qog'oy: terak ---
	_tree(CENTRE + Vector2(16.0, 10.0), 7.0)

	# --- Uzoqlik bo'yicha: tuman masofasini o'lchash uchun ---
	_tree(CENTRE + Vector2(120.0, -60.0), 8.0)
	_box(CENTRE + Vector2(200.0, 40.0), Vector3(3.0, 3.0, 3.0), Palette.BRICK)
	_minor(CENTRE + Vector2(340.0, 20.0), 20.0, 9.0)
	_tree(CENTRE + Vector2(600.0, 120.0), 9.0)
	_box(CENTRE + Vector2(900.0, 200.0), Vector3(4.0, 4.0, 4.0), Palette.TILE_TURQUOISE)


## Berilgan XZ nuqtadagi yerga qo'yish.
func _ground(p: Vector2) -> float:
	return TerrainGen.height_at(p.x, p.y)


func _place(node: Node3D, p: Vector2, lift: float = 0.0) -> void:
	node.position = Vector3(p.x, _ground(p) + lift, p.y)
	add_child(node)


func _box(p: Vector2, size: Vector3, color: Color, offset: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color)
	_place(node, p, offset.y + size.y * 0.5)
	# Oyoq ostidagi collision — o'yinchi ustiga chiqmasin
	_static_box(p, Vector3(size.x, size.y, size.z), offset.y + size.y * 0.5)


func _minor(p: Vector2, height: float, diameter: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = diameter * 0.5 * 0.72    # minoralar yuqoriga torayadi
	mesh.bottom_radius = diameter * 0.5
	mesh.height = height
	mesh.radial_segments = 12                  # low-poly — Intel UHD uchun
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(Palette.TILE_TURQUOISE)
	_place(node, p, height * 0.5)
	_static_box(p, Vector3(diameter * 0.8, height, diameter * 0.8), height * 0.5)


## 2 qavatli saman uy — mahalla arxitekturasi.
func _house(p: Vector2, width: float, depth: float, height: float) -> void:
	_box(p, Vector3(width, height, depth), Palette.SAMAN)
	# Xona tayoqlari (karnish) — Xiva uslubidagi yagona chiziq
	_box(p + Vector2(0.0, 0.0), Vector3(width + 0.7, 0.35, depth + 0.7),
		Palette.SAMAN_DARK, Vector3(0.0, height + 0.17, 0.0))


func _tree(p: Vector2, height: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.28
	trunk.bottom_radius = 0.40
	trunk.height = height * 0.45
	trunk.radial_segments = 6
	var trunk_node := MeshInstance3D.new()
	trunk_node.mesh = trunk
	trunk_node.material_override = _material(Palette.TRUNK)
	_place(trunk_node, p, height * 0.22)

	var canopy := SphereMesh.new()
	canopy.radius = height * 0.42
	canopy.height = height * 0.9
	canopy.radial_segments = 8
	canopy.rings = 4
	var canopy_node := MeshInstance3D.new()
	canopy_node.mesh = canopy
	canopy_node.material_override = _material(Palette.TUGAY)
	_place(canopy_node, p, height * 0.68)

	_static_box(p, Vector3(0.6, height * 0.9, 0.6), height * 0.45)


func _static_box(p: Vector2, size: Vector3, lift: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape

	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.add_child(col)
	_place(body, p, lift)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
