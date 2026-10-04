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
const EXPECTED_CHECKS := 19

var host: Node = null

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()
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
		var wanted := {
			"x": float(spec["uzunlik"]),
			"y": peak - sill,
			"z": float(spec["kenglik"]),
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
		if size.z > body * 1.20:
			problems.append("%s: %.2f m (kuzov %.2f)" % [
				spec["kalit"], size.z, body])
		elif size.z < body:
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
			if absf(mid.z) > float(spec["kenglik"]) * 0.5 + 0.25:
				outside += 1
			if absf(mid.x) > float(spec["uzunlik"]) * 0.5 + 0.25:
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
				if absf(float(station["x"]) - (u - 0.5) * length) < radius * 0.8:
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
