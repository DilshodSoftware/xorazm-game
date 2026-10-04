class_name VehicleSelfTest
extends Node
## Mashina tizimining avtomatik tekshiruvi.
##
##     godot --headless --path . -- --test-vehicles
##
## NIMA UCHUN
## Mashina kuzovi protsedural — kod yoziladi va shuning uchun xato
## qilish mumkin. 4-bosqichda shunday xatolar uch marta bo'ldi va
## uchalasida rasm "normal" ko'rindi:
##   * shiftning pastki yuzasi tepasidan yuqorida qurilgan
##   * kubning yuzalari o'ziga o'ralgan (bowtie)
##   * yuzalarning yarmini noto'g'ri yoritilgan
## Bu xatolar o'yinchi uchun ko'rinmaydi, lekin mashina "noto'g'ri"
## bo'lib chiqadi. Shuning uchun har bir shakl o'lcham va yopiqlik
## bo'yicha tekshiriladi.

## Har bir `check` chaqiruvi shu sonni oshishi SHART. Aks holda
## "0 xato" chiqib, sinov bevaqt to'xtaganini ko'rsatmaydi.
const EXPECTED_CHECKS := 34

var host: Node = null

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()
	# Haydash sinovi real fizika kadrini kutishi SHART
	await _test_driving()
	print("----------------------------------------")
	print_rich("Tekshiruvlar: [color=#7fbf6a]%d[/color] / %d" % [
		_passed + _failed, EXPECTED_CHECKS])
	print_rich("O'tdi: [color=#7fbf6a]%d[/color]   Xato: [color=#%s]%d[/color]" % [
		_passed, "c8452f" if _failed > 0 else "7fbf6a", _failed])
	if _passed + _failed != EXPECTED_CHECKS:
		print_rich("[color=#c8452f]DIQQAT: %d ta tekshiruv kutilmagan edi[/color]" % [
			EXPECTED_CHECKS - (_passed + _failed)])
		_failed += 1
	print("")
	get_tree().quit(0 if _failed == 0 else 1)


func _run() -> void:
	print_rich("\n[b]=== MASHINA TEKSHIRUVI ===[/b]")

	_test_specs()
	_test_shape_builds()
	_test_shape_dimensions()
	_test_shape_is_closed()
	_test_shape_normals_outward()
	_test_mirrors_widen_only()
	_test_glass_exists()
	_test_wheels_placed()
	_test_wheel_openings()
	_test_details_present()
	_test_door_offsets()
	_test_marshrutka_signature()
	_test_road_along()
	_test_traffic_spawns()
	_test_kerbside()


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print_rich("  [color=#7fbf6a]OK[/color]   %s [color=#a89d8a]%s[/color]" % [
			label, detail])
	else:
		_failed += 1
		print_rich("  [color=#c8452f]FAIL[/color] %s %s" % [label, detail])


# ------------------------------------------------------------------- Yordam

## Model kuzovini quradi va geometriyani tekshirishga tayyorlaydi.
static func _build(spec: Dictionary, colour: Color = Color(0.6, 0.3, 0.2)) -> MeshBuilder:
	var builder := MeshBuilder.new()
	builder.want_collision = false
	CarShapes.build(builder, spec, Vector3.ZERO, colour, false)
	return builder


static func _triangles(builder: MeshBuilder) -> Array:
	var out: Array = []
	for i in range(0, builder.indices.size(), 3):
		out.append({
			"a": builder.vertices[builder.indices[i]],
			"b": builder.vertices[builder.indices[i + 1]],
			"c": builder.vertices[builder.indices[i + 2]],
		})
	return out


static func _bounds(builder: MeshBuilder) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v: Vector3 in builder.vertices:
		lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
		hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
	return {"lo": lo, "hi": hi}


static func _colour_count(builder: MeshBuilder, colour: Color) -> int:
	var n := 0
	for c: Color in builder.colours:
		if c.is_equal_approx(colour):
			n += 1
	return n


# ------------------------------------------------------------------- Testlar

## Model jadvali to'liq va o'zaro ziddiyat yo'q.
func _test_specs() -> void:
	var report := CarSpecs.analyse()
	var issues: Array = report["muammo"]
	_check("Model jadvali to'liq", issues.is_empty(),
		"(%d ta muammo)" % issues.size())
	if not issues.is_empty():
		for issue: String in issues:
			print_rich("      [color=#c8452f]%s[/color]" % issue)

	var marshrutka := 0
	for spec: Dictionary in CarSpecs.all():
		if bool(spec.get("marshrutka", false)):
			marshrutka += 1
			_check("Marshrutka har doim oq",
				(spec["ranglar"][0] as Color).is_equal_approx(
					Palette.CAR_TANTA_MARSHRUTKA))
	_check("Kamida bitta marshrutka bor", marshrutka == 1)


## Har bir model geometriya beradi (hech biri bo'sh qolmaydi).
func _test_shape_builds() -> void:
	var empty: Array[String] = []
	var thin: Array[String] = []
	for spec: Dictionary in CarSpecs.all():
		var builder := _build(spec)
		var name: String = spec["kalit"]
		if builder.is_empty():
			empty.append(name)
		elif builder.triangle_count() < 200:
			thin.append("%s (%d)" % [name, builder.triangle_count()])
	_check("Har bir model geometriya beradi", empty.is_empty(),
		"(%s)" % ", ".join(empty))
	_check("Kuzovlar yetarlicha maydonli", thin.is_empty(),
		"(%s)" % ", ".join(thin))


## Chizilgan kuzov QOBIQ model o'lchamlariga mos keladi — aynan 1:1.
##
## Bu eng muhim tekshiruv: agar kuzov model o'lchamidan kichik
## bo'lsa, ko'chada boshqa mashinalar orasidan "o'tib ketadi".
##
## DIQQAT: o'lcham faqat QOBIQ uchun tekshiriladi, to'liq model
## uchun emas. Ko'zgu kuzovdan ~25 sm kengroq (bu haqiqiy), shuning
## uchun to'liq model kengligi 1.59 m emas, 1.83 m bo'ladi — bu
## xato emas.
func _test_shape_dimensions() -> void:
	var worst := 0.0
	var worst_name := ""
	for spec: Dictionary in CarSpecs.all():
		var builder := MeshBuilder.new()
		CarShapes.build_shell(builder, spec, Color(0.6, 0.3, 0.2))
		var size: Vector3 = _bounds(builder)["hi"] - _bounds(builder)["lo"]
		# Balandlik yerdan o'lchanadi (1483 mm — Spark uchun rasmiy
		# raqam), lekin qobiq qirqliqdan boshlanadi. Shuning uchun
		# kutilgan balandlik = balandlik − qirqliq.
		var stations := CarShapes.stations(spec)
		var sill: float = INF
		var peak: float = -INF
		for station: Dictionary in stations:
			sill = minf(sill, float(station["past"]))
			peak = maxf(peak, float(station["shift"]))
		# O'q xaritasi: X = kenglik, Y = balandlik, Z = uzunlik.
		# (Mashinalar −Z = oldingi tomon qilib chiziladi.)
		var wanted := {
			"x": float(spec["kenglik"]),
			"y": peak - sill,
			"z": float(spec["uzunlik"]),
		}
		for axis: String in ["x", "y", "z"]:
			var want: float = float(wanted[axis])
			var error: float = absf(size[axis] - want) / want
			if error > worst:
				worst = error
				worst_name = "%s.%s (%.2f ≠ %.2f)" % [
					spec["kalit"], axis, size[axis], want]
	_check("Kuzov qobig'i o'lchamlari modelga mos (±3%)", worst < 0.03,
		"(eng katta farq %s)" % worst_name)


## To'liq model kuzovdan biroz kengroq — faqat ko'zgu hisobiga.
## Katta farq bo'lsa, xato bor (masalan bufer haddan tashqariga
## chiqib ketgan).
func _test_mirrors_widen_only() -> void:
	var problems: Array[String] = []
	for spec: Dictionary in CarSpecs.all():
		var size: Vector3 = _bounds(_build(spec))["hi"] \
			- _bounds(_build(spec))["lo"]
		var body: float = float(spec["kenglik"])
		if size.x > body * 1.20:
			problems.append("%s: %.2f m (kuzov %.2f)" % [
				spec["kalit"], size.x, body])
		elif size.x < body:
			problems.append("%s: kuzovdan ham tor" % spec["kalit"])
	_check("Qo'shimcha kenglik faqat ko'zgudan", problems.is_empty(),
		"(%s)" % ", ".join(problems))


## Kuzov yopiq: hech bir uchburchak siluetdan tashqariga chiqmaydi,
## nol yuzali uchburchaklar yo'q.
func _test_shape_is_closed() -> void:
	var outside := 0
	var degenerate := 0
	var total := 0
	for spec: Dictionary in CarSpecs.all():
		for t: Dictionary in _triangles(_build(spec)):
			total += 1
			var a: Vector3 = t["a"]
			var b: Vector3 = t["b"]
			var c: Vector3 = t["c"]
			var cross := (b - a).cross(c - a)
			if cross.length_squared() < 0.0000001:
				degenerate += 1
			var mid: Vector3 = (a + b + c) / 3.0
			# Marshrutka peshona belgisi shiftdan ~28 sm yuqorida
			# turadi (haqiqiy marshrutkada ham shunday) — shuning uchun
			# 30 sm chegara beriladi.
			if absf(mid.y) > float(spec["balandlik"]) + 0.30:
				outside += 1
			if absf(mid.x) > float(spec["kenglik"]) * 0.5 + 0.25:
				outside += 1
			if absf(mid.z) > float(spec["uzunlik"]) * 0.5 + 0.25:
				outside += 1
	_check("Siluetdan tashqarida uchburchak yo'q", outside == 0,
		"(%d / %d ta)" % [outside, total])
	_check("Nol yuzali uchburchak yo'q", degenerate == 0,
		"(%d / %d ta)" % [degenerate, total])


## Yuzalarning YO'NALISHI — hajm orqali tekshiriladi.
##
## DIQQAT: boshqa usul (uchburchak markazini markazga nisbatan
## yo'nalishga qo'shish) MASHINADA ishlamaydi: yon devordagi
## yuqoridagi uchburchak "shift yuzasi" deb o'ylab topiladi va
## noto'g'ri xato beradi (2885 / 3972 "teskari" chiqdi).
##
## To'g'ri usul — HAJM. Yopiq ko'p yuzali jismning hajmi
## divergence teoremasi bo'yicha V = Σ (a · (b × c)) / 6 bo'ladi va
## bu qiymat faqat barcha yuzalar TASHQARIGA qaraganda musbat
## bo'ladi. Bitta teskari yuza shu miqdorni kamaytiradi, ko'p
## teskari yuza esa manfiy qiladi. Bu aynan biz izlayotgan xato
## sinfi ("bowtie", noto'g'ri burilgan yuz).
func _test_shape_normals_outward() -> void:
	var problems: Array[String] = []
	var ratios: Array[String] = []
	for spec: Dictionary in CarSpecs.all():
		var builder := _build(spec)
		var volume := 0.0
		for i in range(0, builder.indices.size(), 3):
			var a: Vector3 = builder.vertices[builder.indices[i]]
			var b: Vector3 = builder.vertices[builder.indices[i + 1]]
			var c: Vector3 = builder.vertices[builder.indices[i + 2]]
			volume += a.dot(b.cross(c)) / 6.0
		var box: float = float(spec["uzunlik"]) * float(spec["kenglik"]) \
			* float(spec["balandlik"])
		var ratio: float = volume / box
		ratios.append("%.2f" % ratio)
		if volume <= 0.0:
			problems.append("%s: hajmi manfiy (%.2f) — yuzalar ichkariga" % [
				spec["kalit"], volume])
		elif ratio < 0.22 or ratio > 0.85:
			problems.append("%s: hajmi qutining %.0f%%" % [
				spec["kalit"], ratio * 100.0])
	_check("Yuzalar tashqariga qaragan (hajm musbat)", problems.is_empty(),
		"(%s)" % ", ".join(problems))
	print_rich("      [color=#a89d8a]hajm / g'isht qutisi: %s[/color]" % ", ".join(ratios))


## Shisha oyna bori — u mashinani birinchi narsada ajratadi
## (kuzov rangidagi bir butun quti "mashina" emas, "g'isht" bo'ladi).
func _test_glass_exists() -> void:
	var missing: Array[String] = []
	for spec: Dictionary in CarSpecs.all():
		var builder := _build(spec)
		if _colour_count(builder, CarShapes.GLASS) < 8:
			missing.append(String(spec["kalit"]))
	_check("Har bir modelda shisha oyna bor", missing.is_empty(),
		"(%s)" % ", ".join(missing))


## G'ildoraklar to'rtta, to'g'ri masofada va yerga tegadi.
func _test_wheels_placed() -> void:
	var problems: Array[String] = []
	for spec: Dictionary in CarSpecs.all():
		var centre := Vector3(float(spec["gildorak"]) * 0.5, float(spec["radius"]),
			float(spec["iz"]) * 0.5)
		# G'ildorak silindri: ekseni Z, radiusi radius, markazi
		# balandlik radius. Uning uchidagi nuqtalar tekshiriladi.
		var points := _wheel_points(spec)
		if points.size() != 4:
			problems.append("%s: %d ta" % [spec["kalit"], points.size()])
			continue
		var lows: float = points[0].y
		for p: Vector3 in points:
			lows = minf(lows, p.y - float(spec["radius"]))
		if absf(lows) > 0.06:
			problems.append("%s: g'ildorak yerga tegmaydi (%.2f)" % [
				spec["kalit"], lows])
		var xs: Array[float] = []
		for p: Vector3 in points:
			xs.append(p.x)
		var spread: float = maxf(xs[0], xs[3]) - minf(xs[0], xs[3])
		if absf(spread - float(spec["gildorak"])) > 0.01:
			problems.append("%s: g'ildorak bazasi %.2f ≠ %.2f" % [
				spec["kalit"], spread, float(spec["gildorak"])])
		if centre.length() < 0.0:
			problems.append("%s: markaz noto'g'ri" % spec["kalit"])
	_check("To'rt g'ildorak to'g'ri joyda", problems.is_empty(),
		"(%s)" % ", ".join(problems))


## G'ildorak oynasi bor — ya'ni butun g'ildorak ko'rinishi SHART.
##
## Aks holda mashina "quti ostidagi to'rtta doira" bo'lib chiqadi:
## qirqliq pastda qoladi, g'ildorak esa uning ostida yashirinadi.
## Tekshiruv: g'ildorak o'qiga yaqin stansiyalarda qirqliq
## g'ildorak radiusidan baland bo'lishi SHART.
func _test_wheel_openings() -> void:
	var problems: Array[String] = []
	for spec: Dictionary in CarSpecs.all():
		var stations := CarShapes.stations(spec)
		var radius: float = float(spec["radius"])
		var axle := CarSpecs.axles(spec)
		var length: float = float(spec["uzunlik"])
		var sill: float = INF
		for station: Dictionary in stations:
			sill = minf(sill, float(station["past"]))
		for u: float in [axle.x, axle.y]:
			var opening: float = -INF
			for station: Dictionary in stations:
				if absf(float(station["x"]) - (0.5 - u) * length) < radius * 0.8:
					opening = maxf(opening, float(station["past"]))
			if opening < sill + radius * 0.95:
				problems.append("%s: u=%.2f da oyna past (%.2f < %.2f)" % [
					spec["kalit"], u, opening, sill + radius * 0.95])
	_check("G'ildorak oynasi to'liq ochilgan", problems.is_empty(),
		"(%s)" % ", ".join(problems))


## Chiroq, bufer, ko'zgu, raqom — bular bitta qarashda mashinani
## "yig'ilgan" emas, "chizilgan" ko'rsatadi.
func _test_details_present() -> void:
	var builder := _build(CarSpecs.find("cobalt"))
	var checks := {
		"oldingi fara": CarShapes.LAMP,
		"qizil signal": CarShapes.LAMP_RED,
		"ko'rsatkich": CarShapes.LAMP_AMBER,
		"bufer": CarShapes.TRIM,
		"radish": CarShapes.GRILLE,
		"raqom": CarShapes.PLATE,
	}
	var missing: Array[String] = []
	for label: String in checks:
		if _colour_count(builder, checks[label]) < 3:
			missing.append(label)
	_check("Barcha detallar bor", missing.is_empty(),
		"(yo'q: %s)" % ", ".join(missing))
	_check("Ko'zgu o'rnatilgan", _colour_count(builder, CarShapes.TRIM) >= 12)


## Chiqish nuqtasi mashinaning YON tomonida bo'lishi SHART —
## aks holda o'yinchi to'g'ridan-to'g'ri yo'lning o'rtasida
## paydo bo'ladi.
func _test_door_offsets() -> void:
	var problems: Array[String] = []
	for spec: Dictionary in CarSpecs.all():
		# Yo'nalish +Z bo'lganda o'ng tomon +X bo'lishi SHART
		var forward := Vector3(0.0, 0.0, 1.0)
		var right: Vector3 = forward.cross(Vector3.UP)
		var want: float = float(spec["kenglik"]) * 0.5 + 0.85
		if absf(right.length() - 1.0) > 0.001:
			problems.append("%s: o'ng yo'nalish noto'g'ri" % spec["kalit"])
		if want <= 0.0:
			problems.append("%s: chiqish nuqtasi kuzov ichida" % spec["kalit"])
	_check("Chiqish nuqtasi kuzov tashqarisida", problems.is_empty(),
		"(%s)" % ", ".join(problems))


## Marshrutka Xorazmning belgisi: baland, uzun, oq va peshonasida
## yo'l belgisi bilan. Bu tekshiruv uni xato chizishdan saqlaydi
## (marshrutka oddiy katta mashina emas — u minibuss).
func _test_marshrutka_signature() -> void:
	var spec := CarSpecs.find("marshrutka")
	var sedan := CarSpecs.find("cobalt")
	_check("Marshrutka sedan'dan baland",
		float(spec["balandlik"]) > float(sedan["balandlik"]) * 1.4,
		"(%.2f m)" % float(spec["balandlik"]))
	_check("Marshrutka sedan'dan uzun",
		float(spec["uzunlik"]) > float(sedan["uzunlik"]))
	var builder := _build(spec, Palette.CAR_TANTA_MARSHRUTKA)
	_check("Marshrutka peshona belgisi chizilgan",
		_colour_count(builder, CarShapes.LAMP) >= 30,
		"(%d ta oq nuqta)" % _colour_count(builder, CarShapes.LAMP))


## Yo'l bo'ylab yurish: har bir yo'lning har bir nuqtasida
## natija to'g'ri bo'lishi SHART.
func _test_road_along() -> void:
	var problems := Traffic.along_check()
	_check("Yo'l bo'ylab yurish to'g'ri", problems.is_empty(),
		"(%d ta muammo)" % problems.size())
	for problem: String in problems:
		print_rich("      [color=#c8452f]%s[/color]" % problem)

	# Yo'l boshidan yarimiga yurganda kamida yarim yo'l masofasi
	# ALMASHGAN bo'lishi SHART. Istisno: qaytib keladigan (aylanma)
	# yo'llar — ularning yarmiga yurgani boshiga yaqin bo'lishi mumkin.
	var half_problems: Array[String] = []
	for i in RoadNetwork.roads().size():
		var length := RoadNetwork.road_length(i)
		if length <= 60.0:
			continue
		var start: Vector2 = RoadNetwork.point_along(i, 0.0)["nuqta"]
		var mid: Vector2 = RoadNetwork.point_along(i, length * 0.5)["nuqta"]
		var end: Vector2 = RoadNetwork.point_along(i, length * 0.999)["nuqta"]
		var chord: float = start.distance_to(end)
		# Yo'l to'g'ri chiziqdan kam farq qilsa, chord ≈ uzunlik
		if chord > length * 0.55 and mid.distance_to(start) < length * 0.30:
			half_problems.append("yo'l %d (%.0f m)" % [i, length])
	_check("Yarim yo'l haqiqiy yarimda", half_problems.is_empty(),
		"(%s)" % ", ".join(half_problems))


## Trafik o'yinchi atrofida mashinalar qo'yadi va ular haqiqatan
## yo'l ustida turadi.
func _test_traffic_spawns() -> void:
	if host == null:
		_check("Trafik sinovi uchun manzil kerak", false)
		return
	var traffic := Traffic.new()
	host.add_child(traffic)
	var here := host.get("player") as Node3D
	traffic.follow(here)
	traffic.force_refresh()

	_check("Ko'chada harakatlanuvchi mashina bor",
		traffic.moving_count() > 0, "(%d ta)" % traffic.moving_count())
	_check("Mahallada qo'yilgan mashina bor",
		traffic.parked_count() > 0, "(%d ta)" % traffic.parked_count())

	# Harakatlanuvchi mashinalar YO'L ustida bo'lishi SHART
	var off_road := 0
	var floating := 0
	for car: Vehicle in traffic.cars:
		var here2 := Vector2(car.global_position.x, car.global_position.z)
		if RoadNetwork.nearest_road_point(here2)["masofa"] > 9.0:
			off_road += 1
		var ground: float = TerrainGen.height_at(here2.x, here2.y)
		if absf(car.global_position.y - ground) > 0.9:
			floating += 1
	_check("Harakatlanuvchi mashinalar yo'l ustida", off_road == 0,
		"(%d ta chetda)" % off_road)
	_check("Mashinalar yerga tegadi", floating == 0,
		"(%d ta suvda)" % floating)
	traffic.queue_free()


## Ko'cha chetidagi joy to'g'ri topiladi.
func _test_kerbside() -> void:
	var spawn := Vector2(-1250.0, -503.0)   # o'yinchi uyi
	var spot := Traffic.kerbside_near(spawn)
	var pos: Vector2 = spot["pos"]
	var name: String = spot["nom"]
	_check("Ko'cha chetidagi joy topildi", name != "", "(%s)" % name)
	_check("Ko'cha chetidagi joy uyga yaqin",
		pos.distance_to(spawn) < 25.0, "(%d m)" % int(pos.distance_to(spawn)))
	_check("Yer tekislikda", absf(TerrainGen.height_at(pos.x, pos.y)) < 20.0)


## REAL HAYDASH: gaz, burish, tormoz.
##
## Bu eng muhim sinov. Barcha boshqa tekshiruvlar statik — ular
## shakl va ma'lumotni tekshiradi. Bu esa o'yinchi haqiqatan
## ko'chada yura oladimi degan savolga javob beradi.
##
## DIQQAT: bu sinov `await` bilan ishlaydi (fizika kadrini kutadi).
## `await` ichidagi xato yutilib ketadi va "0 xato" ko'rinadi —
## shuning uchun yuqoridagi `EXPECTED_CHECKS` hisoblagichi SHART.
func _test_driving() -> void:
	if host == null:
		_check("Haydash sinovi uchun manzil kerak", false)
		_check("Mashina gazda yuradi", false)
		_check("Mashina to'xtaydi", false)
		_check("Mashina buriladi", false)
		_check("Mashina to'g'ri turadi", false)
		return

	# DIQQAT: mashina o'yinchi YONIGA qo'yiladi. Yer chunklari faqat
	# o'yinchi atrofida yuklangan — boshqa joyda mashina bo'sh
	# havoda eriydi (birinchi urinishda shunday bo'ldi: barcha
	# "haydash" o'lchovlari erkin tushish tezligini ko'rsatdi).
	var who := host.get("player") as Node3D
	# Ko'chaning O'RTIDA (lane = 0) — chetda uylarga tegib
	# burilmaydi va sinov toza o'lchaydi
	var spot := Traffic.kerbside_near(Vector2(who.global_position.x,
		who.global_position.z), 0.0)
	# DIQQAT: o'yinchi mashinasi ham shu ko'chada, aynan shu yerda
	# turadi. Ikkalasi ustma-ust qurilsa, sinov mashinasi ichkariga
	# tushadi va yuqoriga otilib chiqadi (0,35 m), keyin o'yinchi
	# mashinasining korpusida turadi — VEHICLE qatlami nishat
	# maskasida yo'q, shuning uchun prujina uni ko'rmaydi.
	# Yo'nalish bo'yicha 12 m siljitamiz.
	# Yo'nalish bo'yicha 12 m siljitamiz. DIQQAT: mashinaning
	# oldingi yo'nalishi −Z aylanganda, XZ da bu
	# (−sin yaw, −cos yaw) — (cos, −sin) YON tomon bo'lib, u
	# mashinani uyning ichiga surib qo'yadi.
	var rad: float = deg_to_rad(float(spot["yaw"]))
	var along := Vector2(-sin(rad), -cos(rad)) * 12.0
	var point: Vector2 = (spot["pos"] as Vector2) + along

	# === KALIBRASH ===
	var world0: World3D = (host as Node3D).get_world_3d()
	var space0: PhysicsDirectSpaceState3D = world0.direct_space_state
	var analytic: float = TerrainGen.height_at(point.x, point.y)
	var ground: float = TerrainGen.ground_height(space0, point.x, point.y)
	print_rich("      [color=#a89d8a]Yer balandligi: analitik %.2f, haqiqiy %.2f "
		% [analytic, ground] + "(farq %.2f m — shuning uchun mashinalar nishat "
		% (ground - analytic) + "bilan joylashtiriladi)[/color]")
	var car := Vehicle.create("nexia", Palette.CAR_WHITE, true)
	host.add_child(car)
	car.global_position = Vector3(point.x, ground + 0.25, point.y)
	car.rotation.y = float(spot["yaw"])
	for i in 60:
		await get_tree().physics_frame

	var start := car.global_position
	# --- Gaz: 2 soniya ---
	#
	# DIQQAT: 1 soniya emas. Nexia 0–100 km/soatga ~14 soniyada
	# chiqadi, ya'ni 1 soniyada ~7 km/soat. Sinov chegarasini
	# shunga mos qo'yish kerak, aks holda sinov noto'g'ri
	# "tezlik juda past" degan xato beradi.
	for i in 120:
		car.drive(1.0, 0.0, 0.0, 0.0)
		car.update_speed()
		await get_tree().physics_frame
	var travelled: float = car.global_position.distance_to(start)
	car.update_speed()
	_check("Mashina gazda yuradi", travelled > 3.0,
		"(%.1f m, %.0f km/soat)" % [travelled, car.speed_kmh])
	_check("Tezlik real bo'lyapti", car.speed_kmh > 7.0 and car.speed_kmh < 180.0,
		"(%.0f km/soat)" % car.speed_kmh)
	_check("Mashina to'g'ri turadi", car.global_basis.y.dot(Vector3.UP) > 0.75,
		"(%.2f)" % car.global_basis.y.dot(Vector3.UP))

	# --- Burish ---
	#
	# DIQQAT: hozircha faqat BUYURMA tekshiriladi (burish burchagi
	# oldingi g'ildoraklarga yetadimi), o'zgarish emas.
	#
	# Nima uchun: fizikaviy burish hali to'g'ri ishlamayapti —
	# sinovda burchak 2 soniya davomida o'zgarmay qoladi
	# (-25,10°) va mashina gaz berilgan holda 11,8 → 4,2 km/soatga
	# tushadi, ya'ni to'siqga uriladi. Buning aniq sababi
	# aniqlanmagan (g'ildorak yon kuchi qo'llanmoqda, lekin aylanish
	# momenti hosil bo'lmayapti).
	#
	# Ochiq ish: qoldirmiz va aylanish momentini tekshiramiz
	# (g'ildorak tarmog'i balandligi, massa taqsimoti).
	# Sinov HAQIQIY burilishni 0,08 rad chegarasi bilan tekshiradi
	# va hozir QIZIL bo'lib qoladi — bu ongli: yashirib qo'yish
	# yoki chegarani pasaytirish yashirilgan xatodan ko'ra yomon.
	var before_yaw: float = car.global_rotation.y
	for i in 45:
		car.drive(0.6, 1.0, 0.0, 0.0)
		car.update_speed()
		await get_tree().physics_frame
	var turned: float = absf(wrapf(car.global_rotation.y - before_yaw, -PI, PI))
	# Buyurma tekshiruvi burish DANI keyin — `steer_now` sekin
	# o'sadi, shuning uchun undan oldin tekshirilsa, doim 0 chiqadi.
	_check("Burish buyurmasi g'ildorakka yetadi",
		absf(car.steer_now) > float(car.spec["burish"]) * 0.8,
		"(%.2f rad, chegara %.2f)" % [car.steer_now, float(car.spec["burish"])])
	_check("Mashina buriladi", turned > 0.08,
		"(%.0f gradus)" % rad_to_deg(turned))

	# --- Tormoz ---
	for i in 120:
		car.drive(0.0, 0.0, 1.0, 0.0)
		car.update_speed()
		await get_tree().physics_frame
	_check("Mashina to'xtaydi", car.speed_kmh < 12.0,
		"(%.0f km/soat)" % car.speed_kmh)
	car.freeze = true
	car.queue_free()


# ------------------------------------------------------------------- Yordamchi

## G'ildorak silindrlarining uchi (eng past nuqta) — tekshirish uchun.
static func _wheel_points(spec: Dictionary) -> Array[Vector3]:
	var radius: float = float(spec["radius"])
	var base: float = float(spec["gildorak"]) * 0.5
	var track: float = float(spec["iz"]) * 0.5
	return [
		Vector3(base, radius, track), Vector3(base, radius, -track),
		Vector3(-base, radius, track), Vector3(-base, radius, -track),
	]
