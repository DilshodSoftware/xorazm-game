class_name MeshSelfTest
extends Node
## Geometriya yordamchilarining avtomatik tekshiruvi.
##
##     godot --headless --path . -- --test-mesh
##
## NIMA UCHUN BU ALOHIDA
## `MeshBuilder` — butun o'yinning asosi: yo'llar, uylar, mebellar,
## daraxtlar hammasi shundan o'tadi. Uning xatosi butun o'yinni
## buzadi va ko'pincha KO'RINMAYDI: 4-bosqichda `add_box` ning oltita
## yuzasidan ikkitasi o'ziga o'ralgan "bowtie" bo'lib chiqandi —
## geometriya buzilgan, lekin hech qanday belgi yo'q edi.
##
## Shuning uchun bu yerda har bir shakl tekshiriladi:
##   * uchburchak YO'Q bo'lmagan (chiziq emas, maydon emas)
##   * har bir yuzaning normali TASHQARIGA qaragan
##   * hech bir yuzada o'ziga o'ralish yo'q

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()


func _run() -> void:
	print_rich("\n[b]=== GEOMETRIYA TEKSHIRUVI ===[/b]")

	_test_box_is_closed()
	_test_box_faces_outward()
	_test_wall_is_closed()
	_test_plate_is_closed()
	_test_cylinder_is_closed()
	_test_no_degenerate_triangles()
	_test_quads_are_flat_rectangles()

	print("----------------------------------------")
	print_rich("O'tdi: [color=#7fbf6a]%d[/color]   Xato: [color=#%s]%d[/color]" % [
		_passed, "c8452f" if _failed > 0 else "7fbf6a", _failed])
	print("")
	get_tree().quit(0 if _failed == 0 else 1)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print_rich("  [color=#7fbf6a]OK[/color]   %s [color=#a89d8a]%s[/color]" % [
			label, detail])
	else:
		_failed += 1
		print_rich("  [color=#c8452f]FAIL[/color] %s %s" % [label, detail])


# ------------------------------------------------------------------- Yordam

## Barcha uchburchaklarni tekshiruv uchun yig'adi.
static func _triangles(builder: MeshBuilder) -> Array:
	var out: Array = []
	for i in range(0, builder.indices.size(), 3):
		var a: Vector3 = builder.vertices[builder.indices[i]]
		var b: Vector3 = builder.vertices[builder.indices[i + 1]]
		var c: Vector3 = builder.vertices[builder.indices[i + 2]]
		out.append({"a": a, "b": b, "c": c})
	return out


# ------------------------------------------------------------------- Testlar

## Kub yopiq bo'lishi kerak: har bir uchburchakning markazi kub
## ichida, lekin hech biri markazda emas.
func _test_box_is_closed() -> void:
	var builder := MeshBuilder.new()
	var centre := Vector3(1, 2, 3)
	var half := Vector3(0.5, 0.6, 0.4)
	builder.add_box(centre, half * 2.0, Color.WHITE)

	var tris := _triangles(builder)
	_check("Kub 12 ta uchburchak beradi", tris.size() == 12,
		"(%d ta)" % tris.size())

	var on_surface := 0
	var outside := 0
	for t: Dictionary in tris:
		var mid: Vector3 = (t["a"] + t["b"] + t["c"]) / 3.0
		var d: Vector3 = (mid - centre).abs()
		if d.x > half.x + 0.001 or d.y > half.y + 0.001 or d.z > half.z + 0.001:
			outside += 1
		elif d.x > half.x - 0.02 or d.y > half.y - 0.02 or d.z > half.z - 0.02:
			on_surface += 1
	_check("Barcha uchburchaklar kub yuzasida", outside == 0,
		"(tashqarida: %d)" % outside)
	_check("Barcha uchburchaklar yuzaga tegadi (bowtie yo'q)", on_surface == tris.size(),
		"(%d/%d)" % [on_surface, tris.size()])


## Har bir uchburchakning normali o'sha yuzadan TASHQARIGA qarab
## turishi kerak. Ichkariga qaragan yuz — teskari chizilgan (qorong'i
## yoritiladi).
##
## DIQQAT: yuzani burchakning o'ziga qarab aniqlash kerak, balki
## markazga nisbatan chiqadigan "diagonal" yo'nalish bo'yicha emas —
## diagonal hech qachon yuzaning normaliga to'g'ri kelmaydi va
## tekshiruv har doim yolg'on xato beradi.
func _test_box_faces_outward() -> void:
	for yaw in [0.0, 0.7, 1.9, 3.1]:
		var builder := MeshBuilder.new()
		var half := Vector3(1.0, 0.8, 0.6)
		builder.add_box(Vector3.ZERO, half * 2.0, Color.WHITE, yaw)
		var basis := Basis(Vector3.UP, yaw)

		var wrong := 0
		for t: Dictionary in _triangles(builder):
			var a: Vector3 = t["a"]
			var b: Vector3 = t["b"]
			var c: Vector3 = t["c"]
			var normal := (b - a).cross(c - a)
			if normal.length_squared() < 0.000001:
				continue
			var mid: Vector3 = (a + b + c) / 3.0
			# Kubning o'z tizimidagi koordinatalar (burilishni hisobga olib)
			var local: Vector3 = basis.inverse() * mid
			var relative := Vector3(
				absf(local.x) / half.x, absf(local.y) / half.y,
				absf(local.z) / half.z)
			# Qaysi yuzada turgani: eng to'yingan o'q
			var axis := 0
			if relative.y > relative.x and relative.y > relative.z:
				axis = 1
			elif relative.z > relative.x:
				axis = 2
			var expected := Vector3.ZERO
			expected[axis] = signf(local[axis])
			if (basis.inverse() * normal.normalized()).dot(expected) < 0.99:
				wrong += 1
		_check("Kub yuzalari tashqariga qaragan (yaw %.1f)" % yaw, wrong == 0,
			"(teskari: %d)" % wrong)


func _test_wall_is_closed() -> void:
	var builder := MeshBuilder.new()
	builder.add_wall(Vector2(0, 0), Vector2(5, 0), 0.0, 3.0, 0.3, Color.WHITE)
	var tris := _triangles(builder)
	_check("Devor 8 ta uchburchak beradi", tris.size() == 8, "(%d ta)" % tris.size())

	# Devor 5 m uzun, 3 m baland, 0,3 m qalin
	var lo := Vector3(0.15, 0, -0.15)
	var hi := Vector3(4.85, 3.0, 0.15)
	var outside := 0
	for t: Dictionary in tris:
		var mid: Vector3 = (t["a"] + t["b"] + t["c"]) / 3.0
		if mid.x < lo.x - 0.01 or mid.x > hi.x + 0.01 \
				or mid.z < lo.z - 0.01 or mid.z > hi.z + 0.01 \
				or mid.y < -0.01 or mid.y > 3.01:
			outside += 1
	_check("Devor o'lchamlari to'g'ri", outside == 0, "( chegaradan tashqarida: %d)" % outside)


## Plita yopiq bo'lishi SHART: yuqori, pastki va to'rtta yon devor.
## Avval faqat 4 ta uchburchak chiqardi (yon devorlar yo'q edi) —
## shiftlar qog'ozdek bir yuzali ko'rinardi.
func _test_plate_is_closed() -> void:
	var builder := MeshBuilder.new()
	builder.add_plate(Vector2(0, 0), Vector2(4, 0), 2.0, 0.25, Color.WHITE)
	var tris := _triangles(builder)
	# 2 (yuqori) + 2 (pastki) + 4 yon devor × 2 = 12
	_check("Plita yopiq (12 ta uchburchak)", tris.size() == 12, "(%d ta)" % tris.size())

	var low := INF
	var high := -INF
	var outside := 0
	for t: Dictionary in tris:
		var pa: Vector3 = t["a"]
		var pb: Vector3 = t["b"]
		var pc: Vector3 = t["c"]
		for v: Vector3 in [pa, pb, pc]:
			low = minf(low, v.y)
			high = maxf(high, v.y)
			if v.y < 1.75 - 0.001 or v.y > 2.0 + 0.001:
				outside += 1
	_check("Plita balandligi to'g'ri", absf(high - 2.0) < 0.01 and absf(low - 1.75) < 0.01,
		"(%.2f … %.2f)" % [low, high])
	_check("Plita nuqtalari chegaradan tashqarida emas", outside == 0,
		"(%d ta)" % outside)

	# Yon devorlar bor-yo'qligi: gorizontalga yaqin normali bor
	# uchburchaklar soni 8 bo'lishi SHART (4 yon devor × 2 uchburchak).
	# Faqat 0 bo'lsa — plita ochiq, chetlari ko'rinmaydi.
	var side_tris := 0
	for t: Dictionary in tris:
		var pa: Vector3 = t["a"]
		var pb: Vector3 = t["b"]
		var pc: Vector3 = t["c"]
		var n: Vector3 = (pb - pa).cross(pc - pa)
		if n.length_squared() < 0.000001:
			continue
		if absf(n.normalized().y) < 0.5:
			side_tris += 1
	_check("Plitada yon devorlar bor", side_tris == 8,
		"(%d ta yon uchburchak)" % side_tris)


func _test_cylinder_is_closed() -> void:
	var builder := MeshBuilder.new()
	builder.add_cylinder(Vector3(0, 0, 0), Vector3(0, 3, 0), 0.5, 8, Color.WHITE)
	var tris := _triangles(builder)
	# 8 ta yon + 6 + 6 ta yopish = 20 ta kvadratdan... yon kvadrat 2 ta
	# uchburchak, yopish 1 ta
	_check("Silindr uchburchak soni", tris.size() == 8 * 2 + 8 + 8,
		"(%d ta)" % tris.size())

	# Har bir uchburchak o'q atrofida radius ichida bo'lishi kerak
	var bad := 0
	for t: Dictionary in tris:
		for key: String in ["a", "b", "c"]:
			var p: Vector3 = t[key]
			var r: float = Vector2(p.x, p.z).length()
			if r > 0.51:
				bad += 1
	_check("Silindr yuzasi radius ichida", bad == 0,
		"(radiusdan tashqarida: %d ta nuqta)" % bad)


## Nol yuzali (chiziq yoki nuqta) uchburchaklar bo'lmasligi kerak —
## ular GPUda chiziladi, lekin ko'rinmaydi va xotirani yeydi.
func _test_no_degenerate_triangles() -> void:
	var total := 0
	var degenerate := 0

	var box := MeshBuilder.new()
	box.add_box(Vector3(1, 1, 1), Vector3(2, 2, 2), Color.WHITE, 0.6)
	var wall := MeshBuilder.new()
	wall.add_wall(Vector2(0, 0), Vector2(4, 3), 0.0, 2.5, 0.3, Color.WHITE)
	var plate := MeshBuilder.new()
	plate.add_plate(Vector2(0, 0), Vector2(4, 3), 1.0, 0.2, Color.WHITE)
	var pipe := MeshBuilder.new()
	pipe.add_cylinder(Vector3(0, 0, 0), Vector3(2, 1, 0), 0.4, 10, Color.WHITE)

	var builders: Array[MeshBuilder] = [box, wall, plate, pipe]
	for builder: MeshBuilder in builders:
		for t: Dictionary in _triangles(builder):
			total += 1
			var pa: Vector3 = t["a"]
			var pb: Vector3 = t["b"]
			var pc: Vector3 = t["c"]
			if (pb - pa).cross(pc - pa).length_squared() < 0.0000001:
				degenerate += 1

	_check("Nol yuzali uchburchak yo'q", degenerate == 0,
		"(%d / %d ta)" % [degenerate, total])


## `add_quad` TO'RTBURCHAK qurishi kerak — hamma burchak bir tekislikda
## va to'rt tomoni teng. Bu 4-bosqichda ikki marta buzilgan edi
## (`niche` va daraxt bargi) — har ikkisi ham "bowtie" bo'lib chiqqan.
func _test_quads_are_flat_rectangles() -> void:
	var flat := 0
	var not_flat := 0
	for yaw in [0.0, 0.5, 1.3, 2.2, 3.0]:
		var builder := MeshBuilder.new()
		var b := Basis(Vector3.UP, yaw)
		var at := func(x: float, y: float) -> Vector3:
			return b * Vector3(x, y, 0.0)
		builder.add_quad(at.call(-0.4, -0.2), at.call(0.4, -0.2),
			at.call(0.4, 0.5), at.call(-0.4, 0.5), Color.WHITE)

		for t: Dictionary in _triangles(builder):
			# Uchburchakning normali kvadrat tekisligiga perpendikulyar
			# bo'lishi SHART (kvadrat tekislikda bo'lgani uchun)
			var a: Vector3 = t["a"]
			var bb: Vector3 = t["b"]
			var c: Vector3 = t["c"]
			var normal := (bb - a).cross(c - a)
			if normal.normalized().dot(b.z) > 0.99:
				flat += 1
			else:
				not_flat += 1

	_check("Kvadrat tekislikda qoladi", not_flat == 0,
		"(%d yaxshi, %d yomon)" % [flat, not_flat])