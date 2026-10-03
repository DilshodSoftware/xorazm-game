class_name TerrainSelfTest
extends Node
## Xorazm relyefining avtomatik tekshiruvi.
##
##     godot --headless --path . -- --test-terrain
##
## Eng muhimi: collision balandligi TerrainGen bilan BITTA xil bo'lishi
## kerak. Chunk mesh'i HeightMapShape3D ni masshtablash orqali quradi —
## agar masshtab xato bo'lsa, o'yinchi yerga bosib kirdi yoki havoda
## turib qoladi. Shu sabab bu yerda raycast bilan tekshiriladi.

var host: Node

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()


func _run() -> void:
	print_rich("\n[b]=== XORAZM RELYEFI TEKSHIRUVI ===[/b]")

	_test_determinism()
	_test_flatness()
	_test_cities_above_water()
	_test_cities_are_flat()
	_test_river_and_lakes()
	await _test_collision_matches_height()   # await MUHIM: funksiya ichida await bor
	await _test_no_hole_under_player()
	_test_streaming()

	print("----------------------------------------")
	print_rich("O'tdi: [color=#7fbf6a]%d[/color]   Xato: [color=#%s]%d[/color]" % [
		_passed, "c8452f" if _failed > 0 else "7fbf6a", _failed
	])
	print("")
	get_tree().quit(0 if _failed == 0 else 1)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print_rich("  [color=#7fbf6a]OK[/color]   %s [color=#a89d8a]%s[/color]" % [label, detail])
	else:
		_failed += 1
		print_rich("  [color=#c8452f]FAIL[/color] %s %s" % [label, detail])


# ------------------------------------------------------------------- Testlar

## Bir xil nuqta har doim bir xil balandlik berishi kerak. Aks holda
## chunklar orasida yoriq (darq) paydo bo'ladi.
func _test_determinism() -> void:
	var same := true
	for i in 200:
		var x := randf_range(-2500.0, 2500.0)
		var z := randf_range(-2200.0, 2200.0)
		if TerrainGen.height_at(x, z) != TerrainGen.height_at(x, z):
			same = false
			break
	_check("Balandlik barqaror (darq yo'q)", same)

	# Chekkalarda ziddiyat bo'lmasligi kerak
	var continuous := true
	for i in 200:
		var x := randf_range(-2500.0, 2500.0)
		var z := randf_range(-2200.0, 2200.0)
		var step := 0.5
		var d: float = absf(TerrainGen.height_at(x, z) - TerrainGen.height_at(x + step, z))
		if d > 0.5:      # 0,5 m da ko'proq sakrash tabiiy emas
			continuous = false
			break
	_check("Balandlik uzluksiz", continuous)


## Xorazm — O'zbekistondagi eng tekis viloyat. Tog'lar bo'lsa,
## butun vizual qaror (va boshqaruv) noto'g'ri bo'lardi.
func _test_flatness() -> void:
	var highest := -INF
	var lowest := INF
	for i in 4000:
		var x := randf_range(-2600.0, 2600.0)
		var z := randf_range(-2300.0, 2300.0)
		var h: float = TerrainGen.height_at(x, z)
		highest = maxf(highest, h)
		lowest = minf(lowest, h)
	var range_m: float = highest - lowest

	_check("Tog' yo'q (balandlik < 40 m)", highest < 40.0,
		"(eng baland %.1f m, eng past %.1f m, diapazon %.1f m)" % [highest, lowest, range_m])
	_check("Relyef juda tekis (diapazon < 30 m)", range_m < 30.0,
		"(%.1f m)" % range_m)


## Barcha shaharlar quruq yerda bo'lishi shart.
func _test_cities_above_water() -> void:
	for id: String in WorldMap.CITIES:
		var p: Vector2 = WorldMap.city_position(id)
		var centre_h: float = TerrainGen.height_at(p.x, p.y)
		var lowest := centre_h
		# Shahar chegarasining eng past nuqtasi ham suv ustida bo'lishi kerak
		var radius: float = WorldMap.CITIES[id]["radius"]
		for a in 12:
			var angle: float = a / 12.0 * TAU
			var h: float = TerrainGen.height_at(
				p.x + cos(angle) * radius, p.y + sin(angle) * radius
			)
			lowest = minf(lowest, h)
		_check("%s quruq yerda" % WorldMap.city_name(id), lowest > 0.3,
			"(markaz %.1f m, chegaraning eng past nuqtasi %.1f m)" % [centre_h, lowest])


## Shahar ichida tekislik bo'lishi kerak — binolar va ko'chalar uchun.
func _test_cities_are_flat() -> void:
	for id: String in ["urganch", "khiva"]:
		var p: Vector2 = WorldMap.city_position(id)
		var radius: float = WorldMap.CITIES[id]["radius"]
		var lo := INF
		var hi := -INF
		for a in 16:
			for r in [0.0, radius * 0.5, radius]:
				var angle: float = a / 16.0 * TAU
				var h: float = TerrainGen.height_at(
					p.x + cos(angle) * r, p.y + sin(angle) * r
				)
				lo = minf(lo, h)
				hi = maxf(hi, h)
		_check("%s tekis" % WorldMap.city_name(id), hi - lo < 2.5,
			"(diametr bo'ylab %.2f m farq)" % (hi - lo))


## Amudaryo janubda, sho'r ko'llar pastda bo'lishi kerak.
func _test_river_and_lakes() -> void:
	var river_deep := 0
	for i in 40:
		var x := -2400.0 + i * 120.0
		var z: float = TerrainGen.RIVER_CENTER_Z + sin(x / TerrainGen.RIVER_WAVE_PERIOD) \
			* TerrainGen.RIVER_WAVE
		if TerrainGen.height_at(x, z) < -6.0:
			river_deep += 1
	_check("Amudaryo janubda chuqur", river_deep > 30,
		"(%d/40 nuqta 6 m dan chuqur)" % river_deep)

	for lake: Dictionary in TerrainGen.SALT_LAKES:
		var p: Vector2 = lake["pos"]
		var h: float = TerrainGen.height_at(p.x, p.y)
		_check("Sho'r ko'l pastda (%.0f, %.0f)" % [p.x, p.y], h < 0.0,
			"(%.1f m)" % h)

	# Kanallar — Xorazmning sug'orish tarmog'i
	var canal_ok := 0
	for canal: Dictionary in TerrainGen.CANALS:
		var mid: Vector2 = (canal["a"] + canal["b"]) * 0.5
		var cx: float = _distance_to_segment(mid, canal["a"], canal["b"])
		if TerrainGen.height_at(mid.x, mid.y) < TerrainGen.BASE_HEIGHT - 1.0 and cx < 1.0:
			canal_ok += 1
	_check("Kanallar o'yilgan", canal_ok == TerrainGen.CANALS.size(),
		"(%d/%d)" % [canal_ok, TerrainGen.CANALS.size()])


## ENG MUHIM: collision balandligi TerrainGen bilan bitta xil bo'lishi kerak.
func _test_collision_matches_height() -> void:
	var chunks: ChunkManager = host.chunks
	var probes := [
		Vector3(-1196.0, 0.0, -700.0),   # Tandirchi (sinov devoridan uzoq)
		Vector3(-745.0, 0.0, 13.0),     # Urganch markazi
		Vector3(-1845.0, 0.0, 864.0),   # Xiva
		Vector3(0.0, 0.0, 1200.0),      # ochiq dasht
		Vector3(-2000.0, 0.0, 500.0),   # qum tepaligi (g'arb)
	]
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	var worst := 0.0

	for p: Vector3 in probes:
		chunks.force_load_all(p)
		await get_tree().physics_frame

		var params := PhysicsRayQueryParameters3D.create(
			Vector3(p.x, 120.0, p.z), Vector3(p.x, -60.0, p.z)
		)
		params.collision_mask = PhysicsLayers.WORLD
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			_check("Raycast urildi (%.0f, %.0f)" % [p.x, p.z], false)
			continue

		var actual: float = (hit["position"] as Vector3).y
		var expected: float = TerrainGen.height_at(p.x, p.z)
		var error: float = absf(actual - expected)
		worst = maxf(worst, error)
		# Collision to'ri 8,3 m: oraliq nuqtalar interpolatsiya qilinadi
		_check("Collision = TerrainGen (%.0f, %.0f)" % [p.x, p.z], error < 0.6,
			"(kutilgan %.2f, raycast %.2f, farq %.2f m)" % [expected, actual, error])

	print("     [color=#a89d8a]eng katta farq: %.3f m[/color]" % worst)


## Chunklar hech qachon o'yinchi ostida teshik qoldirmasligi kerak.
##
## Bu test bir haqiqiy xatoni ushlaydi: `force_load_all` chog'ida markaz
## noto'g'ri belgilangan edi, shuning uchun barcha chunklar "uzoq" sifatda
## yaratilardi. Keyingi kadrda 9 ta yaqin chunk "LOD uchun" bo'shatilib,
## 1 kadr/kadr qaytadan qurilardi — o'yinchi ostida bir necha kadrga yer
## bo'lmasdi va u havoga tushib ketardi. Chunklar soni o'zgarganini
## ko'rib bo'lmaydi, shuning uchun alohida tekshiriladi.
func _test_no_hole_under_player() -> void:
	var chunks: ChunkManager = host.chunks
	# ChunkManager bitta nishonni kuzatadi. Biz har bir nuqtada
	# tekshiramiz, shuning uchun vaqtincha nishonni shu nuqtaga
	# ko'chiramiz — aks holda manager o'yinchini kuzatib, tekshirilayotgan
	# chunklarni bo'shatib yuboradi.
	var dummy := Node3D.new()
	dummy.name = "TekshiruvNishoni"
	add_child(dummy)

	for spot: Vector3 in [
		Vector3(0, 0, 0), Vector3(1500, 0, -900), Vector3(-2000, 0, 1800)
	]:
		dummy.position = spot
		chunks.target = dummy
		chunks.force_load_all(spot)
		var centre := Vector2i(floori(spot.x / Settings.CHUNK_SIZE), floori(spot.z / Settings.CHUNK_SIZE))

		# Markazdagi chunk darhol bo'lishi SHART va u "yaqin" bo'lishi SHART
		var centre_chunk: WorldChunk = chunks.chunk_at(centre)
		_check("Markazdagi chunk darhol bor (%.0f, %.0f)" % [spot.x, spot.z],
			centre_chunk != null, "(radius 2 da 21 ta kutilgan edi)")
		if centre_chunk != null:
			_check("Markazdagi chunk batafsil (%.0f, %.0f)" % [spot.x, spot.z],
				centre_chunk.detail,
				"(detail = %s)" % str(centre_chunk.detail))

		# Navbatda qolgan chunk bo'lmasligi kerak — aks holda keyingi
		# kadrda teshik paydo bo'ladi
		_check("Qolgan navbat bo'sh (%.0f, %.0f)" % [spot.x, spot.z],
			chunks.pending_count() == 0,
			"(%d ta navbatda)" % chunks.pending_count())

		# O'yinchi ostidagi yer bir necha kadr davomida YO'QOLMASLIGI kerak.
		# (LOD yangilash vaqtida eski chunk avval bo'shatilardi —
		#  aynan shu teshik haqiqiy xatoni keltirib chiqardi.)
		var never_missing := true
		for _i in 20:
			await get_tree().process_frame
			if chunks.chunk_at(centre) == null:
				never_missing = false
		_check("Markazdagi chunk hech qachon yo'qolmaydi (%.0f, %.0f)" % [spot.x, spot.z],
			never_missing)

		# Va shu nuqtada yer o'zi ham bor bo'lishi kerak
		var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
		var params := PhysicsRayQueryParameters3D.create(
			Vector3(spot.x, 80.0, spot.z), Vector3(spot.x, -40.0, spot.z))
		params.collision_mask = PhysicsLayers.WORLD
		var hit: Dictionary = space.intersect_ray(params)
		_check("Yer o'zi ham bor (%.0f, %.0f)" % [spot.x, spot.z], not hit.is_empty(),
			"" if hit.is_empty() else "(y = %.2f)" % (hit["position"] as Vector3).y)

	dummy.queue_free()
	chunks.target = host.player          # haqiqiy o'yinchiga qaytamiz
	chunks.force_load_all(host.player.global_position)
	await get_tree().process_frame


## Chunk yuklanishi va bo'shatilishi.
func _test_streaming() -> void:
	var chunks: ChunkManager = host.chunks
	chunks.force_load_all(Vector3(0, 0, 0))
	var loaded := chunks.loaded_count()
	var radius: int = Settings.load_radius()
	# Doira yuzasi: radius 2 -> atigi 21 ta
	_check("Chunklar yuklandi", loaded > 0, "(%d ta)" % loaded)
	_check("Chunk soni chegarada", loaded <= (radius * 2 + 1) * (radius * 2 + 1),
		"(radius %d, yuklangan %d)" % [radius, loaded])

	# Boshqa nuqtaga ko'chganda eskisi bo'shatilishi kerak
	chunks.force_load_all(Vector3(2000.0, 0.0, 1500.0))
	var after := chunks.loaded_count()
	_check("Teleportdan keyin yangilandi", after > 0,
		"(%d ta, jami %d ta generatsiya qilindi)" % [after, chunks.generated_total()])
	_check("Eski chunklar to'plandi", chunks.generated_total() > loaded,
		"(%d > %d)" % [chunks.generated_total(), loaded])


# ------------------------------------------------------------------- Yordamchi

static func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq < 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
