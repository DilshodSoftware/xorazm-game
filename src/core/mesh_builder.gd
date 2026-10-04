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


# ------------------------------------------------------------------ Shakllar

## Parallelepiped. `centre` — markazi, `size` — tam o'lchamlari.
func add_box(centre: Vector3, size: Vector3, colour: Color,
		yaw: float = 0.0, collision: bool = true) -> void:
	var h := size * 0.5
	var b := Basis(Vector3.UP, yaw)
	var at := func(sx: float, sy: float, sz: float) -> Vector3:
		return centre + b * Vector3(h.x * sx, h.y * sy, h.z * sz)

	# 8 burchak. Har bir yuzada to'rtta burchak bir tekislikda bo'lishi
	# SHART — aks holda "galtaq bow" (o'ziga o'ralgan) kvadrat chiqadi.
	# DIQQAT: `at.call()` Variant qaytaradi, shuning uchun tur
	# aniq ko'rsatiladi (`var a: Vector3 = ...`) — aks holda GDScript
	# ogohlantirish beradi va loyiha xato sifatida to'xtaydi.
	var a: Vector3 = at.call(-1, -1, -1)   # chap-yuqori-old
	var c: Vector3 = at.call(1, -1, -1)    # o'ng-yuqori-old
	var e: Vector3 = at.call(1, 1, -1)     # o'ng-past-old
	var g: Vector3 = at.call(-1, 1, -1)    # chap-past-old
	var b2: Vector3 = at.call(-1, -1, 1)   # chap-yuqori-orqa
	var d: Vector3 = at.call(1, -1, 1)     # o'ng-yuqori-orqa
	var f: Vector3 = at.call(1, 1, 1)      # o'ng-past-orqa
	var h2: Vector3 = at.call(-1, 1, 1)    # chap-past-orqa

	add_face(a, c, e, g, -b.z, colour, collision)      # old
	add_face(d, f, h2, b2, b.z, colour, collision)     # orqa
	add_face(a, b2, d, c, -b.y, colour, collision)     # yuqori
	add_face(g, e, f, h2, b.y, colour, collision)      # past
	add_face(c, d, f, e, b.x, colour, collision)      # o'ng
	add_face(a, g, h2, b2, -b.x, colour, collision)    # chap


## Yuzani chizadi — burilish TASHQARIGA qarab bo'lishini o'zi
## tekshiradi. Barcha shakllar shundan foydalanadi.
##
## DIQQAT: bu qat'iy tekshiruv chiqarmasligimiz uchun muhim. Avval
## burchaklar qo'lda ketma-ket yozilgan edi va 6 yuzadan ikkitasi
## o'ziga o'ralgan "bowtie" bo'lib chiqardi (natija: noto'g'ri
## yoritilish va geometriya buzilishi). Endi tartibni funksiya
## o'zi to'g'rilaydi — yangi yuz qo'shsak ham xato chiqmaydi.
func add_face(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		outward: Vector3, colour: Color, collision: bool = true) -> void:
	var normal := (b - a).cross(c - a)
	if normal.dot(outward) < 0.0:
		add_quad(a, d, c, b, colour, outward, collision)
	else:
		add_quad(a, b, c, d, colour, outward, collision)


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

	# Ust va tag yopishlari.
	# DIQQAT: qaysi tomon burilishi `outward` VECTORI bo'yicha
	# aniqlanadi. Avval `normal.y >= 0` qilib tekshirilardi — bu
	# faqat vertikal silindrda to'g'ri. Diagonal silindrda (masalan
	# yotqotilgan mozdok) noto'g'ri buriladi.
	_cap(top, up, radius, sides, side, other, colour, false)
	_cap(bottom, -up, radius, sides, side, other, colour, collision)


func _cap(centre: Vector3, outward: Vector3, radius: float,
		sides: int, side: Vector3, other: Vector3, colour: Color,
		collision: bool) -> void:
	for i in range(1, sides + 1):
		var a1: float = TAU * float(i - 1) / float(sides)
		var a2: float = TAU * float(i) / float(sides)
		var p1: Vector3 = centre + (side * cos(a1) + other * sin(a1)) * radius
		var p2: Vector3 = centre + (side * cos(a2) + other * sin(a2)) * radius
		var normal := (p1 - centre).cross(p2 - centre)
		if normal.dot(outward) < 0.0:
			add_triangle(centre, p2, p1, colour, outward, collision)
		else:
			add_triangle(centre, p1, p2, colour, outward, collision)


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
##
## DIQQAT: yon devorlari ham chiziladi. Avval faqat yuqori va pastki
## yuzalar qurilardi, yon devorlar esa qo'lda `faces` ga qo'shilar edi
## — ya'ni KO'RINMAYDIGAN collision. Natijada shiftlar qog'ozdek
## bir yuzali, chetlari yo'q edi. Endi yon devorlar ham geometriya
## (va shu bilan ko'rinadigan ham, uriladigan ham).
func add_plate(from: Vector2, to: Vector2, y: float, thickness: float,
		colour: Color, collision: bool = true) -> void:
	var direction: Vector2 = to - from
	if direction.length_squared() < 0.0001:
		return
	var side := direction.orthogonal().normalized() * (thickness * 0.5)
	var n := Vector3(side.x, 0.0, side.y)
	var a := Vector3(from.x, y, from.y)
	var b := Vector3(to.x, y, to.y)
	var drop := Vector3(0, -thickness, 0)

	var a_out := a - n
	var b_out := b - n
	var a_in := a + n
	var b_in := b + n

	# Yuqori va pastki yuzalar
	add_quad(a_out, b_out, b_in, a_in, colour, Vector3.UP, collision)
	add_quad(a_in + drop, b_in + drop, b_out + drop, a_out + drop,
		colour, -Vector3.UP, collision)
	# Yon devorlar — qalinlik ko'rinadi
	add_face(a_out, b_out, b_out + drop, a_out + drop, -n, colour, collision)
	add_face(b_in, a_in, a_in + drop, b_in + drop, n, colour, collision)
	add_face(b_out, b_in, b_in + drop, b_out + drop, b - a, colour, collision)
	add_face(a_in, a_out, a_out + drop, a_in + drop, a - b, colour, collision)


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
## Mesh tugunini yaratadi va materialni qo'yadi.
##
## DIQQAT: materialni qo'yish SHART. `MeshInstance3D` ni qo'lda
## yaratib, faqat `mesh` qo'yilsa, standart material ishlatiladi —
## u vertex ranglarini YO'Q qiladi (oq ko'rinadi) va orqa yuzalarni
## cull qiladi (ichkarisi ko'rinib qoladi). Mashinada bu aniq
## natija berdi: kuzov quyoshdan oq, pastki qismi qum rangida
## yoritilgan (pastdan yorituvchi to'ldiruvchi nur ichkariga
## tushib qolgan).
##
## [param cast_shadow] — soya berish. Yo'llar va uylar uchun
## `false` (soya katta va foydasiz), mashinalar uchun `true`
## (mashina yonida yotgan soya uning yerga tegganini ko'rsatadi).
## [param paint] — bo'yalgan metal: biroz yaltiroq. Xatchopning
## kuzovi ham bo'yalgan, lekin u shundan ancha farq qilmaydi.
func commit(parent: Node3D, node_name: String, roughness: float = 0.92,
		cast_shadow: bool = false, paint: bool = false) -> MeshInstance3D:
	if is_empty():
		return null

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX if paint \
		else BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = build_mesh()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
