class_name MeshBuilder
extends RefCounted
## Protsedural geometriya uchun yagona yig'uvchi.
##
## Nima uchun alohida sinf: yo'llar, binolar, daraxtlar, ichki mebeller —
## hammasi bir xil ishni qiladi: nuqta va rang to'playdi, keyin bitta
## mesh qiladi. Har biri o'z yig'uvchisini yozsa, kod takrorlanadi va
## xatolar ko'payadi (3-bosqichda yo'l lentasida bo'lgan aynan shu
## holda vertex tartibi xatosi uchta alohida tuzatish talab qildi).
##
## BURCHAK QOIDASI (muhim!)
## `add_quad(a, b, c, d)` — a→b→c→d tartibi VERTIKAL QARASHDA
## soat mili bo'lishi kerak. Aks holda yuzaga qarama-qarashi teskari
## bo'ladi va ko'rinmaydi (3-bosqichda chiziqlar aynan shuning uchun
## butun yo'lda ko'rinmas edi).

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colours := PackedColorArray()
var indices := PackedInt32Array()

## Collision uchun uchburchak nuqtalari: har uchburchakka uchta nuqta.
## Yo'llar uchun kerak emas (yer ular ostida tekislangan), binolar
## uchun esa zarur.
var faces := PackedVector3Array()
var want_collision := false


func vertex_count() -> int:
	return vertices.size()


func is_empty() -> bool:
	return vertices.is_empty()


func triangle_count() -> int:
	return indices.size() / 3


# ------------------------------------------------------------------ Asosiy

func add_vertex(position: Vector3, colour: Color,
		normal: Vector3 = Vector3.UP) -> void:
	vertices.append(position)
	normals.append(normal)
	colours.append(colour)


## Uchburchak. Uchta nuqta VERTIKAL QARASHDA soat mili bo'lishi shart.
func add_triangle(a: Vector3, b: Vector3, c: Vector3, colour: Color,
		normal: Vector3 = Vector3.UP, collision: bool = true) -> void:
	var base := vertices.size()
	add_vertex(a, colour, normal)
	add_vertex(b, colour, normal)
	add_vertex(c, colour, normal)
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	if want_collision and collision:
		faces.append(a)
		faces.append(b)
		faces.append(c)


## Kvadrat: a → b → c → d VERTIKAL QARASHDA soat mili bo'lishi shart.
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color,
		normal: Vector3 = Vector3.UP, collision: bool = true) -> void:
	add_triangle(a, b, c, colour, normal, collision)
	add_triangle(a, c, d, colour, normal, collision)


## Ikki qatlamli kvadrat: yuqori yuzasi va pastki yuzasi.
## Yer ostidagi to'shlar (masalan, ko'prik ushigining tagi) uchun.
func add_slab(top_a: Vector3, top_b: Vector3, top_c: Vector3, top_d: Vector3,
		bottom: float, colour: Color) -> void:
	var drop := Vector3(0, bottom, 0)
	add_quad(top_a, top_b, top_c, top_d, colour)
	add_quad(top_d + drop, top_c + drop, top_b + drop, top_a + drop, colour)


# ------------------------------------------------------------------ Shakllar

## Parallelepiped. `centre` — markazi, `size` — tam o'lchamlari.
func add_box(centre: Vector3, size: Vector3, colour: Color,
		yaw: float = 0.0, collision: bool = true) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	# Burilishni oldindan hisoblab, keyin aylantiramiz
	var basis := Basis(Vector3.UP, yaw)
	for sx in [-1.0, 1.0]:
		for sy in [-0.5, 0.5]:
			for sz in [-1.0, 1.0]:
				corners.append(
					centre + basis * Vector3(h.x * sx, size.y * sy, h.z * sz))
	var c := _order_box(corners)
	# c[0..3] pastki (y0), c[4..7] yuqori (y1); har yuzada VERTIKAL QARASHDA
	# soat mili bo'lishi uchun quyidagi tartib ishlatiladi.
	add_quad(c[0], c[1], c[2], c[3], colour, -Vector3.UP, collision)   # past
	add_quad(c[7], c[6], c[5], c[4], colour, Vector3.UP, collision)    # yuqori
	add_quad(c[4], c[5], c[1], c[0], colour, -basis.z, collision)      # orqa
	add_quad(c[6], c[7], c[3], c[2], colour, basis.z, collision)       # old
	add_quad(c[5], c[6], c[2], c[1], colour, basis.x, collision)       # o'ng
	add_quad(c[7], c[4], c[0], c[3], colour, -basis.x, collision)      # chap


## Kubning 8 burchagini 4 pastki + 4 yuqori bo'lib qaytaradi.
static func _order_box(corners: Array[Vector3]) -> Array:
	# corners tartibi: sx(-1,+1) × sy(-.5,+.5) × sz(-1,+1)
	# → 0:(-,-,-) 1:(-,-,+) 2:(-,+,-) 3:(-,+,+) 4:(+,-,-) 5:(+,-,+)
	#   6:(+,+,-) 7:(+,+,+)
	return [
		corners[0], corners[1], corners[3], corners[2],   # past
		corners[4], corners[5], corners[7], corners[6],   # yuqori
	]


## Silindr (tarona, daraxt poyi, quvur). Uchlari beriladi.
func add_cylinder(bottom: Vector3, top: Vector3, radius: float, sides: int,
		colour: Color, collision: bool = true) -> void:
	if sides < 3:
		sides = 3
	var axis := top - bottom
	if axis.length_squared() < 0.0001:
		return
	var up := axis.normalized()
	# Yotay o'qga perpendikulyar ikkita vektor
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.0001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var other := up.cross(side).normalized()

	var previous_bottom := Vector3.ZERO
	var previous_top := Vector3.ZERO
	for i in range(sides + 1):
		var angle: float = TAU * float(i % sides) / float(sides)
		var offset: Vector3 = (side * cos(angle) + other * sin(angle)) * radius
		var ring_bottom: Vector3 = bottom + offset
		var ring_top: Vector3 = top + offset
		if i > 0:
			add_quad(previous_bottom, ring_bottom, ring_top, previous_top,
				colour, offset.normalized(), collision and i < sides)
		previous_bottom = ring_bottom
		previous_top = ring_top

	# Ust va tag yopishlari
	_add_cap(top, up, radius, sides, side, other, colour, false)
	_add_cap(bottom, -up, radius, sides, side, other, colour, collision)


func _add_cap(centre: Vector3, normal: Vector3, radius: float,
		sides: int, side: Vector3, other: Vector3, colour: Color,
		collision: bool) -> void:
	var first := centre
	for i in range(1, sides + 1):
		var a1: float = TAU * float(i - 1) / float(sides)
		var a2: float = TAU * float(i) / float(sides)
		var p1: Vector3 = centre + (side * cos(a1) + other * sin(a1)) * radius
		var p2: Vector3 = centre + (side * cos(a2) + other * sin(a2)) * radius
		if normal.y >= 0.0:
			add_triangle(first, p1, p2, colour, normal, collision)
		else:
			add_triangle(first, p2, p1, colour, normal, collision)


## G'isht yoki suvaloq devori: berilgan ikki nuqta orasida.
##
## Devor XZ tekisligida `from` dan `to` gacha cho'ziladi va `base_y` dan
## ko'tariladi. Ko'cha bo'yidagi devorlarda shu funksiya ishlatiladi.
func add_wall(from: Vector2, to: Vector2, base_y: float, height: float,
		thickness: float, colour: Color, collision: bool = true) -> void:
	var direction: Vector2 = to - from
	if direction.length_squared() < 0.0001:
		return
	# Devor qalinligi yo'l bo'ylab emas, DEVOR YO'NALIGI bo'ylab yotadi
	var side := direction.orthogonal().normalized() * (thickness * 0.5)
	var n := Vector3(side.x, 0.0, side.y)

	var a := Vector3(from.x, base_y, from.y)
	var b := Vector3(to.x, base_y, to.y)
	var h := Vector3(0, height, 0)

	# Ikki yon + yuqori + pastki
	add_quad(a - n, b - n, b + h - n, a + h - n, colour, -n, collision)
	add_quad(a + n, b + n, b + h + n, a + h + n, colour, n, collision)
	add_quad(a + h - n, b + h - n, b + h + n, a + h + n,
		colour, Vector3.UP, false)
	add_quad(a - n, b - n, b + n, a + n, colour, -Vector3.UP, false)


## Gorizontal plita (tom, shift, ko'prik ushigining tagi).
func add_plate(from: Vector2, to: Vector2, y: float, thickness: float,
		colour: Color, collision: bool = true) -> void:
	var direction: Vector2 = to - from
	if direction.length_squared() < 0.0001:
		return
	var side := direction.orthogonal().normalized() * (thickness * 0.5)
	var n := Vector3(side.x, 0.0, side.y)
	var a := Vector3(from.x, y, from.y)
	var b := Vector3(to.x, y, to.y)

	add_slab(a - n, b - n, b + n, a + n, thickness, colour)

	if not collision:
		return
	# Plitaning yon devorlari ham collision'ga kerak — ustiga qadam
	# tushishi kerak, ichiga emas
	var drop := Vector3(0, -thickness, 0)
	faces.append(a - n)
	faces.append(b - n)
	faces.append(b - n + drop)
	faces.append(a - n)
	faces.append(b - n + drop)
	faces.append(a - n + drop)

	faces.append(b + n)
	faces.append(a + n)
	faces.append(a + n + drop)
	faces.append(b + n)
	faces.append(a + n + drop)
	faces.append(b + n + drop)


# ------------------------------------------------------------------ Natija

func build_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## MeshInstance3D qilib sahnaga qo'yadi.
##
## DIQQAT: CULL_DISABLED — ataylab. Sabablari:
##   * Barglar ikki tomonli bo'lishi kerak (bargning orqasi ham ko'rinadi)
##   * Uyning ichida shiftni ostidan ko'rish kerak — cull bo'lsa
##     shift yo'q bo'lib ko'rinadi
##   * Vertex tartibi xatosi butun geometriyani ko'rinmay qoldiradi;
##     3-bosqichda yo'l chiziqlari aynan shuning uchun butun yo'lda
##     ko'rinmagan edi. Cull o'chirilsa, bu xila kamroq bo'ladi.
func commit(parent: Node3D, node_name: String,
		roughness: float = 0.92) -> MeshInstance3D:
	if is_empty():
		return null

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = build_mesh()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


## Collision tanasini qo'shadi (ixtiyoriy).
func commit_collision(parent: Node3D, node_name: String) -> StaticBody3D:
	if faces.is_empty():
		return null

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var col := CollisionShape3D.new()
	col.shape = shape

	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.add_child(col)
	parent.add_child(body)
	return body


## Mesh va collision'ni bitta tugunga joylaydi.
func commit_all(parent: Node3D, node_name: String, roughness: float = 0.92) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	parent.add_child(holder)
	commit(holder, "Mesh", roughness)
	commit_collision(holder, "Kolpasi")
	return holder