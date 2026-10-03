class_name RoadSelfTest
extends Node
## Yo'l tarmog'ining avtomatik tekshiruvi.
##
##     godot --headless --path . -- --test-roads
##
## Eng muhimi: yo'l ostidagi yer TEKIS bo'lishi va ko'priksiz qismlarda
## suv bo'lmasligi. Aks holda mashina yo'lda "cho'kib" qoladi yoki
## ko'prigsiz kanaldan o'tib ketadi.

var host: Node

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()


func _run() -> void:
	print_rich("\n[b]=== YO'L TARMOG'I TEKSHIRUVI ===[/b]")

	var problems := RoadNetwork.verify_index()
	_check("To'r butun: har bir nuqta o'z yo'lini topadi", problems.is_empty(),
		"(%d muammo)" % problems.size())
	for line in problems:
		print_rich("     [color=#c8452f]%s[/color]" % line)

	_test_network_shape()
	await _test_roads_are_flat()
	await _test_no_road_crosses_open_water()
	_test_cities_stay_flat()

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

## Tarmoq to'g'ri tuzilganmi: halqa yopiq, har yo'lda kamida 2 nuqta.
func _test_network_shape() -> void:
	var roads := RoadNetwork.roads()
	_check("Yo'llar mavjud", roads.size() > 10, "(%d ta)" % roads.size())

	var total := RoadNetwork.total_length()
	_check("Yo'llar uzunligi mantiqiy", total > 20_000.0 and total < 200_000.0,
		"(%.1f km)" % (total / 1000.0))

	var ring: PackedVector2Array = roads[0]["nuqta"]
	_check("Halqa yopiq", ring[0].distance_to(ring[ring.size() - 1]) < 1.0,
		"(farq %.2f m)" % ring[0].distance_to(ring[ring.size() - 1]))

	var bad := 0
	for road: Dictionary in roads:
		if (road["nuqta"] as PackedVector2Array).size() < 2:
			bad += 1
	_check("Har bir yo'lda kamida 2 nuqta", bad == 0, "(%d ta yomon yo'l)" % bad)

	# Halqa barcha asosiy shaharlarni o'rab olishi kerak
	var ring_rx := 0.0
	var ring_rz := 0.0
	for p: Vector2 in ring:
		ring_rx = maxf(ring_rx, absf(p.x))
		ring_rz = maxf(ring_rz, absf(p.y))
	for id: String in ["urganch", "khiva", "xonqa", "xazorasp", "shovot"]:
		var c: Vector2 = WorldMap.city_position(id)
		_check("%s halqa ichida" % WorldMap.city_name(id),
			absf(c.x) < ring_rx - 150.0 and absf(c.y) < ring_rz - 150.0,
			"|x|=%.0f < %.0f, |z|=%.0f < %.0f" % [
				absf(c.x), ring_rx - 150.0, absf(c.y), ring_rz - 150.0])


## Yo'lda tik ko'tarilish (gradient) chegaradan oshmasligi kerak.
##
## DIQQAT: chegara 100 m da 3,0 m — ya'ni 3% gradient. Real yo'llarda
## shundan katta gradient ruxsat etilmaydi; Xorazmda esa tekislik
## sababli 1% dan ham kam bo'lishi kerak. Bu qiymat o'yin uchun
## ixcham, lekin "yo'l tepaga chiqib ketayotgan" xatoni ushlaydi.
func _test_roads_are_flat() -> void:
	var worst_road := ""
	var worst_grade := 0.0
	var worst_along := 0.0
	var worst_across := 0.0

	for road: Dictionary in RoadNetwork.roads():
		if road["tur"] == RoadNetwork.DIRT:
			continue
		var points: PackedVector2Array = road["nuqta"]
		var half: float = RoadNetwork.HALF_WIDTH[road["tur"]]
		var grade := 0.0
		var along := 0.0
		var across := 0.0

		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var length: float = a.distance_to(b)
			if length < 1.0:
				continue
			var steps := maxi(1, int(length / 10.0))
			var spacing: float = length / float(steps)
			var last_y: float = TerrainGen.height_at(a.x, a.y)
			var normal := (b - a).normalized().orthogonal()

			for s in range(1, steps + 1):
				var p: Vector2 = a.lerp(b, s / float(steps))
				var y: float = TerrainGen.height_at(p.x, p.y)
				# 100 m ga necha metr ko'tarilish
				var g_along: float = absf(y - last_y) / spacing * 100.0
				along = maxf(along, g_along)
				last_y = y

				# Yo'l YON chetkasi markaz bilan bir xalqda bo'lishi kerak.
				# DIQQAT: chetka nuqtasini aynan BIR XIL nuqtadan olishimiz
				# kerak — aks holda segmenT boshi va oxiri solishtiriladi
				# va xato natija chiqadi.
				var edge: Vector2 = p + normal * half
				var edge_y: float = TerrainGen.height_at(edge.x, edge.y)
				var g_across: float = absf(edge_y - y) / half * 100.0
				if g_across > across:
					across = g_across
				along = maxf(along, g_along)

		grade = maxf(along, across)
		if grade > worst_grade:
			worst_grade = grade
			worst_road = road["nom"]
			worst_along = along
			worst_across = across

	_check("Yo'llarda tik ko'tarilish yo'q", worst_grade < 3.0,
		"(eng yomon: %s, %.2f m / 100 m — bo'ylab %.2f, yoniga %.2f)" % [
			worst_road, worst_grade, worst_along, worst_across])


## Ko'priksiz qismlarda yo'l suv ustida bo'lmasligi SHART.
## Kanallar ko'prik bilan, Amudaryo chekkasida esa umuman yo'l yo'q.
func _test_no_road_crosses_open_water() -> void:
	var open_crossings := 0
	var bridges_needed := 0
	var per_road := {}

	for road: Dictionary in RoadNetwork.roads():
		# Qishloq yo'llariga ko'prik qurilmaydi (tor, g'ishtli yo'l) —
		# RoadBuilder ham ularni o'tkazib yuboradi. Test ham xuddi shunday.
		if road["tur"] == RoadNetwork.DIRT:
			continue
		var points: PackedVector2Array = road["nuqta"]
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var length: float = a.distance_to(b)
			var steps := maxi(1, int(length / 5.0))
			var run_start := -1.0
			var walked := 0.0
			for s in range(steps + 1):
				var p: Vector2 = a.lerp(b, s / float(steps))
				var wet: bool = RoadNetwork.is_over_water(p.x, p.y)
				# Amudaryo va ko'llar keng — ulardan ko'prik qurib bo'lmaydi,
				# yo'l qayta yo'naltirilishi kerak
				if wet and RoadNetwork.is_major_water(p.x, p.y):
					open_crossings += 1
					per_road[road["nom"]] = int(per_road.get(road["nom"], 0)) + 1
				if wet and not RoadNetwork.is_major_water(p.x, p.y):
					if run_start < 0.0:
						run_start = walked
				elif run_start >= 0.0:
					if walked - run_start >= RoadBuilder.BRIDGE_MIN_SPAN:
						bridges_needed += 1
					run_start = -1.0
				walked += length / float(steps)

	_check("Yo'llar Amudaryoga tushmaydi", open_crossings == 0,
		"(%d ta ochiq kesishma)" % open_crossings)
	if open_crossings > 0:
		for name: String in per_road:
			print_rich("     [color=#c8452f]%s: %d ta[/color]" % [name, per_road[name]])
	_check("Ko'prik kerak bo'lgan joylar topildi", bridges_needed > 0,
		"(%d ta kanal kesishmasi)" % bridges_needed)


## Shahar ichida yo'llar bo'lsa, shahar tepaligi buzilmasligi kerak.
func _test_cities_stay_flat() -> void:
	for id: String in ["urganch", "khiva"]:
		var centre: Vector2 = WorldMap.city_position(id)
		var lo := INF
		var hi := -INF
		for a in 20:
			for r in [0.0, 200.0, 400.0, 600.0]:
				if r > WorldMap.CITIES[id]["radius"]:
					continue
				var angle: float = a / 20.0 * TAU
				var h: float = TerrainGen.height_at(
					centre.x + cos(angle) * r, centre.y + sin(angle) * r)
				lo = minf(lo, h)
				hi = maxf(hi, h)
		_check("%s tekis qolgan" % WorldMap.city_name(id), hi - lo < 2.5,
			"(diametr bo'ylab %.2f m)" % (hi - lo))
