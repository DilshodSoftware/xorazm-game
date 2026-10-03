class_name BuildingSelfTest
extends Node
## Tandirchi binolarining avtomatik tekshiruvi.
##
##     godot --headless --path . -- --test-buildings
##
## Nima uchun bu alohida: 4-bosqichda uyning markazi "ko'cha chegarasi"
## deb olingan edi (maydon o'rtasi emas) va hamma uy ko'chadan 7,5 m
## uzoqlashib ketdi. Hech qanday ogohlantirish yo'q edi — rasm har
## doim "biror narsa bor" ko'rinardi. Bu test aynan shu xil
## ko'rinmas xatolarni ushlaydi.

var host: Node

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()


func _run() -> void:
	print_rich("\n[b]=== TANDIRCHI TEKSHIRUVI ===[/b]")

	_test_layout_exists()
	_test_player_house()
	_test_no_overlap()
	_test_houses_facing_street()
	await _test_houses_stand_on_ground()
	_test_geometry_bounds()
	await _test_player_house_interior()

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


# ------------------------------------------------------------------- Testlar

## Tarmoq umuman bormi va miqdori mantiqiylimikan.
func _test_layout_exists() -> void:
	var streets := Tandirchi.streets()
	var plots := Tandirchi.plots()
	_check("Ko'chalar mavjud", streets.size() >= 5, "(%d ta)" % streets.size())
	_check("Uy joylari mavjud", plots.size() >= 60, "(%d ta)" % plots.size())

	var total := 0.0
	for plot: Dictionary in plots:
		total += float(plot["front"]) * float(plot["chuqur"])
	print_rich("     [color=#a89d8a]mahalla umumiy maydoni: %.0f m²[/color]" % total)

	# Har bir joyda kerakli maydonlar bormi
	var bad := 0
	for plot: Dictionary in plots:
		if float(plot["front"]) < 8.0 or float(plot["chuqur"]) < 10.0:
			bad += 1
	_check("Joy o'lchamlari real", bad == 0,
		"(chiziqli bo'lmagan joy: %d)" % bad)


## O'yinchi uyi bormi va o'yinchi tug'ilish nuqtasiga yaqinmi.
func _test_player_house() -> void:
	var plot := Tandirchi.player_plot()
	_check("O'yinchi uyi joyi belgilangan", not plot.is_empty())
	if plot.is_empty():
		return

	var spawn := WorldMap.PLAYER_SPAWN
	var centre: Vector2 = plot["markaz"]
	var distance: float = centre.distance_to(spawn)
	# Uy markazi ko'chadan (kenglik/2 + chuqur/2) masofada bo'lishi kerak.
	# Chuqur ~15 m, ko'cha 7 m → markaz ko'chadan ~11 m da.
	_check("O'yinchi uyi ko'cha yonida", distance > 6.0 and distance < 20.0,
		"(%.1f m)" % distance)

	# Uy markazi janubga (ko'cha ichkarisiga) qaragan bo'lishi kerak —
	# ya'ni Kosiblar ko'chasidan orqada
	var street: PackedVector2Array = Tandirchi.streets()[0]["nuqta"]
	var nearest: Vector2 = _closest_on(street, centre)
	var offset: Vector2 = centre - nearest
	_check("O'yinchi uyi ko'chadan tashqarida", offset.length() > 6.0,
		"(%.1f m)" % offset.length())


## Ikki joy ustma-ust tushmasligi kerak (mustaqil SAT tekshiruvi).
func _test_no_overlap() -> void:
	var plots := Tandirchi.plots()
	var clashes := 0
	for i in plots.size():
		for j in range(i + 1, plots.size()):
			var a: Dictionary = plots[i]
			var b: Dictionary = plots[j]
			if _overlap(a, b):
				clashes += 1
				if clashes <= 3:
					print_rich("     [color=#c8452f]chessh %d va %d: (%.1f, %.1f) va (%.1f, %.1f)[/color]" % [
						i, j, a["markaz"].x, a["markaz"].y,
						b["markaz"].x, b["markaz"].y])
	_check("Joylar ustma-ust tushmaydi", clashes == 0,
		"(%d ta kesishma)" % clashes)


## Har bir uy ko'chaga QARAB turishi kerak — darvoza ko'chada bo'lishi uchun.
func _test_houses_facing_street() -> void:
	var streets := Tandirchi.streets()
	var plots := Tandirchi.plots()
	var far := 0
	var worst := 0.0
	for plot: Dictionary in plots:
		var centre: Vector2 = plot["markaz"]
		var best := INF
		for street: Dictionary in streets:
			var d: float = _closest_on(street["nuqta"], centre).distance_to(centre)
			best = minf(best, d)
		# Ko'cha yarim kengligi + uy chuqurligi/2 = markazgacha masofa
		var expected: float = float(plot["chuqur"]) * 0.5
		if best > expected + 14.0:
			far += 1
		worst = maxf(worst, best - expected)
	_check("Hammasi ko'chaga yaqin", far == 0,
		"(ortiqcha uzoqda: %d, eng ko'pi %.1f m)" % [far, worst])


## Uylar yer ostida qolmagan bo'lishi kerak.
##
## DIQQAT: bu test uyning BARCHA cho'qqalarini tekshiradi. Agar uy
## markazi noto'g'ri hisoblansa, u yer ostiga kirib ketadi — aynan
## shunday xato 4-bosqichda bo'lgan edi.
func _test_houses_stand_on_ground() -> void:
	var plots := Tandirchi.plots()
	var buried := 0
	var floating := 0
	var worst_buried := 0.0
	var worst_floating := 0.0

	for plot: Dictionary in plots:
		var centre: Vector2 = plot["markaz"]
		var yaw: float = plot["yaw"]
		var front: float = plot["front"]
		var depth: float = plot["chuqur"]
		var basis := Basis(Vector3.UP, yaw)
		# To'rt burchak — uy chegarasida
		for corner: Vector2 in [
			Vector2(-front * 0.5, -depth * 0.5),
			Vector2(front * 0.5, -depth * 0.5),
			Vector2(front * 0.5, depth * 0.5),
			Vector2(-front * 0.5, depth * 0.5),
		]:
			var world: Vector3 = Vector3(centre.x, 0.0, centre.y) + basis * Vector3(corner.x, 0, corner.y)
			var ground: float = TerrainGen.height_at(world.x, world.z)
			var base: float = TerrainGen.height_at(centre.x, centre.y)
			var delta: float = base - ground
			if delta < -0.6:
				buried += 1
				worst_buried = minf(worst_buried, delta)
			elif delta > 1.2:
				floating += 1
				worst_floating = maxf(worst_floating, delta)

	_check("Uylar yer ostida emas", buried == 0,
		"(%d ta burchak, eng chuquri %.2f m)" % [buried, worst_buried])
	_check("Uylar havoda emas", floating == 0,
		"(%d ta burchak, eng balandligi %.2f m)" % [floating, worst_floating])


## Bitta uyning geometriyasi mantiqiy chegarada bo'lishi kerak.
func _test_geometry_bounds() -> void:
	var builder := MeshBuilder.new()
	# Collision yig'ish yoqilgan bo'lsa, `faces` bo'sh qoladi va
	# tekshiruv o'z-o'zidan chalgitadi.
	builder.want_collision = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var centre := Vector2(-1350.0, -607.0)
	CourtyardHouse.build(builder, centre, 0.3, 12.5, 15.0, 2, rng,
		CourtyardHouse.Style.MODERN)

	_check("Uy geometriyasi qurildi", builder.triangle_count() > 300,
		"(%d uchburchak, %d cho'qqa)" % [
			builder.triangle_count(), builder.vertices.size()])

	var basis := Basis(Vector3.UP, 0.3)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v: Vector3 in builder.vertices:
		lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
		hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
	var size := hi - lo
	# 12,5 × 15,0 m maydon + daraxt (≈3 m) → balandlik ~9,5 m.
	# Chegara keng: bu bino, aniq arxitektura emas.
	_check("Uy o'lchamlari real", size.x < 20.0 and size.z < 22.0 and size.y < 13.0,
		"(%.1f × %.1f × %.1f m)" % [size.x, size.y, size.z])

	# Uyning markazi maydonning o'rtasida bo'lishi kerak
	var midpoint: Vector3 = (lo + hi) * 0.5
	var offset: Vector3 = midpoint - Vector3(centre.x, TerrainGen.height_at(centre.x, centre.y), centre.y)
	var flat: float = Vector2(offset.x, offset.z).length()
	_check("Uy maydonning o'rtasida", flat < 3.0,
		"(siljish %.2f m)" % flat)

	# Collision ham bo'lishi kerak
	_check("Uy collision bor", builder.faces.size() > 100,
		"(%d uchburchak nuqtasi)" % (builder.faces.size() / 3))


## O'yinchi uyining ichida hech narsa havoda suzib qolmasligi kerak.
##
## DIQQAT: bu test NIMAGA uchun muhim. 4-bosqichda `_w` va
## `PlayerHouse` yordamchilarida `origin.y` ga yana `ground` qo'shilgan
## edi, shuning uchun BARCHA mebel va chiroq 2 × balandlikda, shift
## ustida turardi. Ko'rishda bu sezilmaydi — mebel bor, lekin to'g'ri
## joyda emas. Soniq esa darhol ko'rsatadi.
func _test_player_house_interior() -> void:
	var plot := Tandirchi.player_plot()
	if plot.is_empty():
		_check("O'yinchi uyi bor", false)
		return

	var centre: Vector2 = plot["markaz"]
	var ground: float = TerrainGen.height_at(centre.x, centre.y)
	var builder := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# `inspect = true` — shift chizilmaydi, faqat ichki ko'rinadi
	PlayerHouse.build_geometry(builder, plot, rng, true)

	var low := INF
	var high := -INF
	var on_floor := 0
	for v: Vector3 in builder.vertices:
		var above: float = v.y - ground
		low = minf(low, above)
		high = maxf(high, above)
		# Mebellarning eng pastki qismi pol o'rtasida ±30 sm
		if absf(above - 0.15) < 0.30:
			on_floor += 1

	_check("Uy ichida narsa pol darajasida bor", on_floor > 40,
		"(%d ta nuqta 0,15 m ±0,30 da)" % on_floor)
	# Shift ustidagi eng baland narsa: devor 5,9 m + chiroq 2,72 m
	# `low` va `high` YER USTIDAN o'lchangan (nisbiy) — shuning uchun
	# 0 bilan solishtiriladi, `ground` bilan emas.
	_check("Uy ichida hech narsa shift ustida emas", high < 6.4,
		"(eng baland: yerdan %.2f m)" % high)
	_check("Hech narsa yer ostida emas", low > -0.6,
		"(eng past: yerdan %.2f m)" % low)


# ------------------------------------------------------------------- Yordam

static func _closest_on(points: PackedVector2Array, p: Vector2) -> Vector2:
	var best := points[0]
	var best_distance := INF
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var ab: Vector2 = b - a
		var length_sq: float = ab.length_squared()
		if length_sq < 0.0001:
			continue
		var t: float = clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
		var projected: Vector2 = a + ab * t
		var d: float = projected.distance_squared_to(p)
		if d < best_distance:
			best_distance = d
			best = projected
	return best


## Ikki joyning to'g'ri to'rtburchagi kesishadimi (2D SAT).
static func _overlap(a: Dictionary, b: Dictionary) -> bool:
	var ua: Vector2 = Vector2(sin(a["yaw"]), cos(a["yaw"]))
	var va: Vector2 = ua.orthogonal()
	var ub: Vector2 = Vector2(sin(b["yaw"]), cos(b["yaw"]))
	var vb: Vector2 = ub.orthogonal()
	var delta: Vector2 = b["markaz"] - a["markaz"]
	# 30 sm bo'shliq ruxsat etiladi — generator bilan bir xil qoida
	const GAP := 0.3
	var ha := Vector2(a["front"] * 0.5 - GAP, a["chuqur"] * 0.5 - GAP)
	var hb := Vector2(b["front"] * 0.5 - GAP, b["chuqur"] * 0.5 - GAP)

	for axis: Vector2 in [ua, va, ub, vb]:
		var gap: float = absf(delta.dot(axis))
		var reach: float = ha.x * absf(ua.dot(axis)) + ha.y * absf(va.dot(axis)) \
			+ hb.x * absf(ub.dot(axis)) + hb.y * absf(vb.dot(axis))
		if gap >= reach:
			return false
	return true