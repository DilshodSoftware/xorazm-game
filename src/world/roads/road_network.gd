class_name RoadNetwork
extends RefCounted
## Xorazmning yo'l tarmog'i — bitta manba, ikki ishlatilish uchun:
##
##   1. TerrainGen.height_at uni chaqiradi va yo'l ostidagi yerni tekislaydi
##   2. RoadBuilder undan ko'rinadigan yo'l lentasini quradi
##
## Shuning uchun yo'l hech qachon yerga botib qolmaydi yoki havoda
## suzib qolmaydi — ikkalasi bitta hisobdan keladi.
##
## XORAZM HAQIDAGI ASOSLAR
##   * Halqa yo'i rasman yo'q. Lekin Amudaryo qirg'og'ida SEL-SUV
##     HIMOYA DAMBALARI aynan orol perimeterida qurilgan. Yo'llar ham
##     shu damlar ustida yuradi. Demi orol atrofidagi halqa — real va
##     mantiqiy.
##   * Viloyatda 2 750 km qattiq qoplamali yo'l bor, lekin kanallar
##     minglab. Asosiy yo'llar kanallarni DOIM kesib o'tadi, shuning
##     uchun ko'prik tez-tez bo'lishi normal.
##   * Urganch — markaz. Undan Xiva, Xonqa, Xazorasp, Pitnak yo'llari
##     chiqadi. Haqiqiy masofalar 1:20 ga siqilgan.

## --- Yo'llar turlari ---
const HIGHWAY := 0     ## Magistral: 4 tasma
const STREET := 1      ## Shahar ko'chasi: 2 tasma
const DIRT := 2        ## Qishloq yo'li (g'ishtli, changli)

## --- Yo'l o'lchamlari (yarim kenglik, m) ---
const HALF_WIDTH := {
	HIGHWAY: 7.0,     ## 14 m — 4 tasma
	STREET: 4.0,      ## 8 m — 2 tasma
	DIRT: 2.5,        ## 5 m — 1 ta keng yo'l
}

## Yo'l yoni — yurganlar uchun chetlar kengayadi
const SHOULDER := 1.8

## Koridorni tekislash: yo'l + yonida qancha metr ANIQ tekis bo'ladi va
## undan keyin qancha metrda tabiiy yerga o'tadi.
##
## Nima uchun bitta son emas, ikkita:
##   * FLAT_MARGIN — yo'lning ikki yoni ham bu masofagacha aniq tekis.
##     Shunda mashina yo'lda mayramaydi.
##   * FADE_WIDTH — undan keyin tabiiy yerga yumshoq o'tadi (tik "ariq"
##     hosil bo'lmasligi uchun).
##
## FADE_WIDTH nima uchun katta (26 m): KESISHMADA. Ikki yo'lning
## balandligi 0,5 m farq qilsa, kesishma ustida yer sakraydi. Tor
## o'tishda bu 0,5 m 10 m da bo'lib 5% gradient beradi — mashina
## sezadi. Keng o'tishda 0,5 m 35 m da bo'lib 1,4% ga tushadi.
## Xorazm tekis, shuning uchun keng koridor tabiatga ham yaqinroq.
##
## Bu chegara KESIMLARDA muhim. Agar boshqa yo'l ta'siri juda uzoqdan
## boshlanib, uzoqlab ketguday bo'lsa, yo'l markazida va 4 m yonida
## turgan nuqtalarda har xil natija chiqadi (0,5 m sakrash, 12% yon
## egilish) — mashina yo'lda "maydaydi". SHU uchun ta'sir zonasi
## yo'ning O'Z tekis tasmasi bilan CHEKLANGAN.
const FLAT_MARGIN := 3.0
const FADE_WIDTH := 26.0
const LEVELING_WIDTH := FLAT_MARGIN + FADE_WIDTH

## Tashqi halqa — orol atrofidagi damlar yo'li.
const RING_RX := 2450.0
const RING_RZ := 2150.0
const RING_NOISE := 90.0

## Ichki halqa — Urganch atrofida.
const INNER_R := 760.0

static var _roads: Array[Dictionary] = []
## Barcha yo'llarning barcha kesimlari bitta ro'yxatda
static var _segments: Array[Dictionary] = []
## Katak (500 m) -> u katakka tegadigan kesim indekslari
static var _grid: Dictionary = {}
static var _grid_size := 500.0
static var _profiles: Dictionary = {}
static var _coast_noise: FastNoiseLite
static var _ready := false


static func roads() -> Array[Dictionary]:
	_ensure()
	return _roads


# ================================================================== QURILISH

## Tashqi halqa — oral atrofidagi damlar yo'li.
##
## DIQQAT: halqa SUN'IY ELLIPSA EMAS. U har bir burchakda quruq yer
## qayerda tugashini tekshiradi va shundan 160 m ichkarida o'tadi.
##
## Nima uchun: janubda Amudaryo yoyilib yotadi. Doimiy radiusli halqa
## uning ichiga tushib, ko'priksiz qismda suv ustida qolardi (196 ta
## ochiq kesishma chiqdi). Haqiqiy dambalar esa QIRG'OQ bo'ylab
## yuradi — shuning uchun biz ham shuni qilamiz.
static func _build_ring() -> void:
	const SEGMENTS := 144
	var points := PackedVector2Array()

	# 1) Har bir burchakda radiusni topamiz
	var radii := PackedFloat32Array()
	radii.resize(SEGMENTS)
	for i in SEGMENTS:
		var angle: float = i / float(SEGMENTS) * TAU
		var reach: float = _land_reach(angle)
		radii[i] = maxf(700.0, reach - 220.0
			+ _coast_noise.get_noise_1d(i * 0.35) * RING_NOISE)

	# 2) Yumshtiramiz. Bu MUHIM, aks holda:
	#    * qo'shni nuqtalar keskin farq qiladi -> segment burchakni kesib
	#      o'tadi va yo'l quruq yerdan Amudaryoga tushadi (94 ta kesishma)
	#    * yo'l tik ko'tariladi (20 m / 100 m)
	#    Haqiqiy dambalar ham tekis buriladi.
	for _pass in 3:
		radii = _smooth_ring(radii, 4)

	for i in SEGMENTS:
		var angle: float = i / float(SEGMENTS) * TAU
		points.append(Vector2.from_angle(angle) * radii[i])
	points.append(points[0])   # yopiq halqa
	_roads.append({"nuqta": points, "tur": HIGHWAY, "nom": "Tashqi halqa"})


## Halqa radiuslarini halqaviy oynada o'rtalash (chegarali qiymat).
static func _smooth_ring(radii: PackedFloat32Array, window: int) -> PackedFloat32Array:
	var n := radii.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var sum := 0.0
		var count := 0
		for k in range(-window, window + 1):
			# Halqa yopiq — modul olish kerak, aks holda chekaran
			# notekislik halqaning bosh qismiga ko'chadi
			sum += radii[posmod(i + k, n)]
			count += 1
		out[i] = sum / float(count)
	return out


## Berilgan burchakda quruq yer qayerda tugaydi (dengiz sathidan
## yuqorida bo'lib qoladigan oxirgi radius). Ikki tomonlama qidiruv.
static func _land_reach(angle: float) -> float:
	return _land_reach_from(Vector2.ZERO, Vector2.from_angle(angle), 2900.0)


## Berilgan nuqtadan, berilgan yo'nalishda quruq yer qayerda tugaydi.
##
## DIQQAT: boshlanish nuqtasi MUHIM. Radial yo'llar Urganchdan chiqadi,
## halqa esa dunyo markazidan. Agar har doim markazdan o'lchab,
## radial yo'l 745 m oshib, Amudaryoga tushib ketardi.
static func _land_reach_from(origin: Vector2, direction: Vector2,
		max_radius: float) -> float:
	var lo := 0.0
	var hi := max_radius
	for _i in 18:
		var mid: float = (lo + hi) * 0.5
		if TerrainGen._base_height(
				origin.x + direction.x * mid,
				origin.y + direction.y * mid) > 1.2:
			lo = mid
		else:
			hi = mid
	return lo


## Urganchdan tashqi halqaga 6 ta radial.
static func _build_radials() -> void:
	var centre := WorldMap.city_position("urganch")
	# Burchaklar HAQIQIY shaharlarning yo'nalishiga qarab belgilangan.
	# Xonqa, Xazorasp va Pitnak deyarli bir yo'nalishda (30° atrofida) —
	# ularga alohida radial qilish kerak emas, ular g'ishtli yo'llar bilan
	# bog'lanadi (real xorazmda ham shunday).
	var spokes := [
		{"burchak": 30.0, "nom": "Janub-sharq yo'li"},
		{"burchak": 90.0, "nom": "Janub yo'li"},
		{"burchak": 145.0, "nom": "Xiva yo'li"},
		{"burchak": 205.0, "nom": "Shovot yo'li"},
		{"burchak": 250.0, "nom": "Yangibozor yo'li"},
		{"burchak": 340.0, "nom": "Shimoli-sharq yo'li"},
	]
	for spoke: Dictionary in spokes:
		var direction := Vector2.from_angle(deg_to_rad(spoke["burchak"]))
		# Radial URGANCHDAN chiqadi — shuning uchun quruq yerni shu
		# nuqtadan o'lchash kerak.
		var reach: float = _land_reach_from(centre, direction, 3400.0)
		var outer: float = maxf(INNER_R + 250.0, reach - 120.0)
		var points := PackedVector2Array()
		for step in 14:
			var t: float = step / 13.0
			points.append(centre + direction * lerpf(INNER_R, outer, t))
		_roads.append({"nuqta": points, "tur": STREET, "nom": spoke["nom"]})


## Urganch shahri: kvartal to'ri. 7-bosqichda binolar shu yerda qo'yiladi.
static func _build_urganch_grid() -> void:
	_build_grid(
		WorldMap.city_position("urganch"),
		WorldMap.CITIES["urganch"]["radius"],
		150.0, 130.0
	)


## Xiva markaziy ko'chasi. To'liq Ichan Qal'a 9-bosqichda.
static func _build_khiva_streets() -> void:
	var c := WorldMap.city_position("khiva")
	_roads.append({
		"nuqta": PackedVector2Array([c + Vector2(-560, 260), c + Vector2(480, 300)]),
		"tur": STREET, "nom": "Xiva markaziy",
	})


## Qishloq yo'llari — shaharlarni bog'lovchi g'ishtli yo'llar.
static func _build_dirt_roads() -> void:
	var links := [
		["urganch", "xonqa"], ["xonqa", "xazorasp"],
		["xazorasp", "pitnak"], ["urganch", "shovot"],
		["shovot", "qoshkopir"], ["qoshkopir", "khiva"],
		["urganch", "yangibozor"], ["yangibozor", "gurlan"],
	]
	for link: Array in links:
		var a: Vector2 = WorldMap.city_position(link[0])
		var b: Vector2 = WorldMap.city_position(link[1])
		# To'g'ri chiziq emas — yumshoq egilish (bor yo'llar ham shunday)
		var middle: Vector2 = (a + b) * 0.5 + (b - a).orthogonal() * 0.12
		_roads.append({
			"nuqta": PackedVector2Array([a, middle, b]),
			"tur": DIRT,
			"nom": "%s — %s" % [WorldMap.city_name(link[0]), WorldMap.city_name(link[1])],
		})


static func _build_grid(centre: Vector2, radius: float,
		block_x: float, block_z: float) -> void:
	var reach := radius * 1.02
	var lanes := maxi(2, int(ceil(reach / block_x)))

	for i in range(-lanes, lanes + 1):
		var offset: float = i * block_x
		if absf(offset) > reach:
			continue
		for axis in 2:
			var line := PackedVector2Array()
			for step in 16:
				var t: float = step / 15.0
				var along: float = lerpf(-reach, reach, t)
				var p: Vector2 = (centre + Vector2(offset, along)) if axis == 0 \
					else (centre + Vector2(along, offset))
				if p.distance_squared_to(centre) < radius * radius:
					line.append(p)
			if line.size() >= 2:
				_roads.append({"nuqta": line, "tur": STREET, "nom": "ko'cha"})


# ================================================================== INDEKS

## Kesimlarni fazilaviy to'rga joylaymiz.
##
## Nima uchun: balandlik funksiyasi har nuqtada barcha yo'llarni
## tekshirsa — 40 ta yo'l * 160 nuxta * 4 500 nuqta/chunk = millionlab
## hisob. To'r bilan har bir nuqta atigi 5–10 ta yaqin kesimni ko'radi.
static func _index() -> void:
	_grid.clear()
	_segments.clear()

	for index in _roads.size():
		var road: Dictionary = _roads[index]
		var points: PackedVector2Array = road["nuqta"]
		var half: float = HALF_WIDTH[road["tur"]]
		var reach: float = half + SHOULDER + LEVELING_WIDTH
		var walked := 0.0

		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var length: float = a.distance_to(b)
			_segments.append({
				"a": a, "b": b,
				"yo'l": index,
				"yarim": half,
				"boshlanish": walked,
				"uzunlik": length,
				"kvadrat": length * length,
			})
			_mark_segment(_segments.size() - 1, a, b, reach)
			walked += length


## Kesimning ta'sir zonasi barcha kataklarga yoziladi.
##
## DIQQAT: bu qism bir necha marta qayta yozildi, chunki har bir
## variantda bir xil xato qoldi:
##
##   1) Faqat burchak chegarasini to'ldirish — DIAGONAL kesim katak
##      chegarasini ichkarida kesib o'tsa, u katak belgilanmay qoladi.
##   2) Kesimni namuna qilib yurish — namunalar katak chegarasini
##      tushib qolishi mumkin.
##
## Natija bir xil bo'lardi: yo'lning MARKAZI tekislangan, 4–7 m yonidagi
## nuqta esa YO'Q (xom yer) qolardi. 0,5–0,8 m sakrash — 12% yon
## egilish, mashina yo'lda "maydaydi".
##
## Endi to'g'ri: kengaytirilgan burchakdagi HAR BIR katak uchun katakning
## o'ziga eng yaqin nuqta segmentga qancha masofada ekani aniq
## hisoblanadi. Masofa <= reach bo'lsa — belgilanadi. Ehtiyotkor (ortiqcha
## kataklar qo'shilishi mumkin), lekin ISE TUSHKAR emas.
static func _mark_segment(index: int, a: Vector2, b: Vector2, reach: float) -> void:
	# Kengaytirilgan burchak. DIQQAT: a - reach va b + reach dan HISOBLASH
	# noto'g'ri edi — diagonal kesimda bir uchi yuqorida, ikkinchisi
	# pastda bo'lsa, pastki yarim butunlay tushib qolardi. Masofa katta
	# bo'lgan segmentlarda bu bir necha yuz metrni yopadi.
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach)
	var ca := _cell_of(lo)
	var cb := _cell_of(hi)
	var ab: Vector2 = b - a
	var length_sq: float = ab.length_squared()
	# Katak ichidagi nuqtalar segmentga yaqin bo'lishi mumkin. Kengaytirilgan
	# chegara bu nuqtalarni ham qamrab oladi (chunki chegara katakning
	# o'zidan ham kengaytirilgan).
	var allowance: float = _grid_size * 0.5 + reach

	for gz in range(ca.y, cb.y + 1):
		for gx in range(ca.x, cb.x + 1):
			var corner := Vector2(gx, gz) * _grid_size
			# Katakning eng yaqin nuqtasini topamiz
			var nearest := Vector2(
				clampf(pick_nearest(a.x, b.x, corner.x), corner.x, corner.x + _grid_size),
				clampf(pick_nearest(a.y, b.y, corner.y), corner.y, corner.y + _grid_size)
			)
			var t: float = 0.0
			if length_sq > 0.0001:
				t = clampf((nearest - a).dot(ab) / length_sq, 0.0, 1.0)
			if (a + ab * t).distance_to(nearest) <= allowance:
				_mark_cell(index, Vector2i(gx, gz))


## [param p0], [param p1] — oralik; [param q] — qiymat oralig'i ichidami?
static func pick_nearest(p0: float, p1: float, q: float) -> float:
	return clampf(q, minf(p0, p1), maxf(p0, p1))


static func _mark_cell(index: int, key: Vector2i) -> void:
	if _grid.has(key):
		var list: PackedInt32Array = _grid[key]
		# Bitta kesim bir katakda bir necha marta qayt bo'lishi mumkin.
		# Ikki marta yozish tekshiruvni sekinlashtiradi, natijani
		# o'zgartirmaydi.
		if not list.has(index):
			list.append(index)
			_grid[key] = list
	else:
		_grid[key] = PackedInt32Array([index])


static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _grid_size), floori(p.y / _grid_size))


# ================================================================== TEKISLASH

## Nuqta yo'l koridorida yotdimi? Yer qanday bo'lishi kerak?
##
## DIQQAT: `_grid` katagi nuqta atrofini YO'L eniga kengaytirilgan
## holda indekslangan. Aks holda nuqta katak chegarasida bo'lganda
## tegishli kesim topilmaydi va yer tekishlanmaydi.
static func flatten(x: float, z: float, h: float) -> float:
	_ensure()

	var key := _cell_of(Vector2(x, z))
	var segments: PackedInt32Array = _grid.get(key, PackedInt32Array())
	if segments.is_empty():
		return h

	var p := Vector2(x, z)
	var weight_sum := 0.0
	var profile_sum := 0.0

	for i in segments:
		var segment: Dictionary = _segments[i]
		var a: Vector2 = segment["a"]
		var ab: Vector2 = segment["b"] - a
		var length_sq: float = segment["kvadrat"]

		var t: float = 0.0
		if length_sq > 0.0001:
			t = clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
		var distance: float = (a + ab * t).distance_to(p)

		var half: float = segment["yarim"]
		var reach: float = half + LEVELING_WIDTH
		if distance >= reach:
			continue

		# Og'irlik: yo'ning BUTUN kengligi bo'ylab 1, koridor chetida 0.
		# Bu kerak — yo'l kesimasi tekis bo'lishi shart, aks holda mashina
		# yo'lda mayraydi.
		if distance >= reach:
			continue
		var weight: float = smoothstep(reach, half, distance)

		weight_sum += weight
		profile_sum += weight * _profile_at(segment,
			segment["boshlanish"] + segment["uzunlik"] * t)

	if weight_sum <= 0.0001:
		return h

	# DIQQAT: barcha yaqin yo'llarning profillarini O'RTACHILAB
	# olamiz, eng kattasini emas. Aks holda kesishmada bitta yo'lning
	# profili, yonida esa ikkinchisining profili qo'llanadi — yer
	# kesishma ustida 10 m/100 m tik bo'lib chiqardi.
	var target: float = profile_sum / weight_sum
	var influence: float = clampf(weight_sum, 0.0, 1.0)

	# Yo'l balandroq bo'lsa — ko'taramiz, pastroq bo'lsa — pastga
	# tushiramiz (yo'l ko'ndigini kesib o'tadi).
	return lerpf(h, target, influence)


## Yo'lining tekislangan balandlik profili. Bir marta hisoblanib keshlanadi.
static func _profile_at(segment: Dictionary, distance: float) -> float:
	var index: int = segment["yo'l"]
	if not _profiles.has(index):
		_build_profile(index)
	return _sample_profile(_profiles[index], distance)


## Profil: har 12 m da bitta namuna, ±80 m oynada o'rtachalangan.
## Nima uchun oyna: Xorazm tekis, lekin mayin va qum tepaliklari bor —
## xom balandlik bo'yicha qurilgan yo'l to'lqinlanib, yoqalanib ketardi.
static func _build_profile(index: int) -> void:
	var road: Dictionary = _roads[index]
	var points: PackedVector2Array = road["nuqta"]

	# 1) Maydalangan namunalar
	var distances := PackedFloat32Array()
	var raw := PackedFloat32Array()
	var total := 0.0
	distances.append(0.0)
	raw.append(TerrainGen._base_height(points[0].x, points[0].y))
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var step_count := maxi(1, int(a.distance_to(b) / 12.0))
		for s in range(1, step_count + 1):
			var t: float = s / float(step_count)
			total += a.distance_to(b) / float(step_count)
			distances.append(total)
			var p: Vector2 = a.lerp(b, t)
			raw.append(TerrainGen._base_height(p.x, p.y))

	# 2) Oyna bilan o'rtalash — BIR NECHTA MARTA.
	#
	# Bitta oyna yetarli emas: mayinlari yumshatish uchun keng oyna kerak
	# (200 m), lekin keng oyna o'zida profilning mahalliy tik qismlarini
	# qoldiradi. Natijada yo'ning markazi va chetkasi 4 m farq bilan
	# turgan nuqtada 0,4 m balandlik farq qiladi (12% yon egilish) va
	# mashina yo'lda "maylaydi".
	#
	# Uch marta o'tkazish profilli haqiqatan ham yassilaydi.
	var smoothed := raw
	var window := 200.0
	for _pass in 3:
		var out := PackedFloat32Array()
		out.resize(smoothed.size())
		for i in smoothed.size():
			var sum := 0.0
			var count := 0
			for j in smoothed.size():
				if absf(distances[j] - distances[i]) <= window:
					sum += smoothed[j]
					count += 1
			out[i] = sum / float(maxi(count, 1))
		smoothed = out

	# 3) GRADIENT CHEKLOVI.
	#
	# Bu eng muhim qadam. Yuqoridagi yumshtash oyna mayinlarni olib
	# tashlaydi, lekin profilning MAHALLIY tik qismlari qoladi. Ularning
	# natijasi: yo'lning markazi va 4 m yonidagi nuqta boshqa-boshqa
	# segmentga proyeksiyalanadi, profil qiymati farq qiladi va yer
	# kesishma ustida 0,5 m sakraydi (12% yon egilish).
	#
	# Haqiqiy yo'lda bunday gradient bo'lmaydi. Xorazm — dunyodagi
	# eng tekis viloyatlardan biri, shuning uchun 1:40 (2,5%) chegarasi
	# real bo'ylarga to'g'ri keladi. Bu chegaradan oshsa, yo'l kerak
	# bo'lganda yerni KESIB (cut) yoki KO'TARIB (fill) qiladi — xuddi
	# haqiqiy quruvchilar qilgani kabi.
	const MAX_GRADE := 0.025
	var passes := 32
	for _p in passes:
		for i in range(1, distances.size()):
			var spacing: float = maxf(distances[i] - distances[i - 1], 0.5)
			var limit: float = MAX_GRADE * spacing
			var difference: float = smoothed[i] - smoothed[i - 1]
			if absf(difference) > limit:
				smoothed[i] = smoothed[i - 1] + signf(difference) * limit
		# Orqadan ham — aks holda bosh qismida tiklik qoladi
		for i in range(smoothed.size() - 2, -1, -1):
			var spacing2: float = maxf(distances[i + 1] - distances[i], 0.5)
			var limit2: float = MAX_GRADE * spacing2
			var difference2: float = smoothed[i] - smoothed[i + 1]
			if absf(difference2) > limit2:
				smoothed[i] = smoothed[i + 1] + signf(difference2) * limit2

	# Masofalar bilan birga saqlaymiz.
	_profiles[index] = {"d": distances, "h": smoothed}


## Profil bo'yicha interpolatsiya (ikki tomonlama qidiruv).
##
## DIQQAT: masofa bo'yicha indeks HISOBLASH mumkin emas. Namunalar
## 12 m qadam bilan emas, `floor(length / 12)` bo'yicha qo'yiladi —
## qisqa segmentlarda qadam 1 m, uzun segmentlarda 20+ m bo'ladi.
## Indeks hisoblash butun boshqa nuqtani qaytarib, yo'l notekis
## ko'tarilib ketardi (69 m / 100 m).
static func _sample_profile(profile: Dictionary, distance: float) -> float:
	var d: PackedFloat32Array = profile["d"]
	var h: PackedFloat32Array = profile["h"]
	if d.is_empty():
		return 0.0
	if distance <= d[0]:
		return h[0]
	if distance >= d[d.size() - 1]:
		return h[h.size() - 1]

	var lo := 0
	var hi := d.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if d[mid] <= distance:
			lo = mid
		else:
			hi = mid
	var span: float = d[hi] - d[lo]
	if span <= 0.0:
		return h[lo]
	return lerpf(h[lo], h[hi], (distance - d[lo]) / span)


# ================================================================== YORDAM

## Nuqta suv ustida yoki uning qirg'og'idami? (Ko'prik kerakmi?)
static func is_over_water(x: float, z: float) -> bool:
	return TerrainGen.is_submerged(x, z)


## Yo'lda, boshlang'ich nuqtadan `along` masofa yurib, qayerda
## turganini topadi.
##
## NIMA UCHUN BU KERAK
## `nearest_road_point` "shu nuqtaga yaqin yo'l qayerda" savoliga
## javob beradi — u kameraga yoki AI ga YO'L TOPISH uchun. Lekin
## mashina yurish uchun boshqa narsa kerak: "shu yo'lda 340 m
## yurib, qayerda bo'laman". Qo'lda har kadrda eng yaqin nuqtani
## qayta qidirish (va har safar 34 ta yo'lni tekshirish) sekin va
## noto'g'ri — mashina yo'lning qarama-qarshi tomoniga "ko'chib"
## ketishi mumkin.
##
## [param along] — yo'l boshidan o'tgan masofa, m. Chiqib ketsa
## yo'lning boshiga qaytadi (tomas halqasi).
##
## Qaytaradi: {"nuqta": Vector2, "yo'nalish": Vector2, "orasidagi":
## float, "chegara": bool, "yo'l": String, "tur": int, "y": float}
## Har bir yo'lning KUMULATIV uzunlik jadvali va umumiy uzunligi.
##
## NIMA UCHUN (o'lchov bilan aniqlangan)
## `point_along()` va `road_length()` har chaqiruvda nuqtalar qatorini
## BOSHDAN yurib o'tardi — O(n). Trafik bitta kadrda har bir yo'l uchun
## `gap` marta (62…130) urinish qiladi, ya'ni 34 yo'l × 130 × 2 = 8840
## to'liq yurish. Natijada bitta kadr 591 ms egalladi va o'yin
## 60 FPS dan 1 FPS ga tushadi.
##
## Endi jadval bir marta `_ensure()` da quriladi: `point_along` faqat
## kerakli bo'lakni topadi, `road_length` esa bir qarash.
static var _cumulative: Array[PackedFloat32Array] = []
static var _lengths: PackedFloat32Array = PackedFloat32Array()
## Har bir yo'lning eng kichik va eng katta nuqtasi (2D).
## Trafik uzoqdagi yo'llarni umuman tekshirmasligi uchun kerak:
## 34 yo'l × 130 urinish = 4420 keraksiz `point_along` chaqiruvi.
static var _boxes_lo: PackedVector2Array = PackedVector2Array()
static var _boxes_hi: PackedVector2Array = PackedVector2Array()


static func _build_tables() -> void:
	_cumulative.clear()
	_lengths = PackedFloat32Array()
	_lengths.resize(_roads.size())
	_boxes_lo = PackedVector2Array()
	_boxes_hi = PackedVector2Array()
	for i in _roads.size():
		var points: PackedVector2Array = _roads[i]["nuqta"]
		if points.size() > 0:
			var lo: Vector2 = points[0]
			var hi: Vector2 = points[0]
			for k in points.size():
				lo.x = minf(lo.x, points[k].x)
				lo.y = minf(lo.y, points[k].y)
				hi.x = maxf(hi.x, points[k].x)
				hi.y = maxf(hi.y, points[k].y)
			_boxes_lo.append(lo)
			_boxes_hi.append(hi)
		var table := PackedFloat32Array()
		var total := 0.0
		if points.size() >= 2:
			table.append(0.0)
			for k in range(points.size() - 1):
				total += points[k].distance_to(points[k + 1])
				table.append(total)
		_lengths[i] = total
		_cumulative.append(table)


## [param with_height] — qo'lda `TerrainGen.height_at` ni ham
## hisoblasinmi?
##
## DIQQAT: O'LCHOV BILAN ANIQLANGAN ASOSIY SABAB. Balandlik
## protsedural (shovin + tekislash + yo'l profili) — bitta chaqiruv
## qimmat. Trafik bitta kadrda bu funksiyani 8840 marta chaqiradi
## (34 yo'l × 130 urinish × 2), natijada bitta kadr 631 ms.
## Balandlik faqat MASHINA qo'yilganda kerak — bitta kadrda 35 marta.
static func point_along(index: int, along: float,
		with_height: bool = false) -> Dictionary:
	_ensure()
	var fallback := {
		"nuqta": Vector2.ZERO, "yo'nalish": Vector2.RIGHT,
		"orasidagi": 0.0, "chegara": false, "yo'l": "", "tur": 0,
		"y": 0.0, "uzunlik": 0.0,
	}
	if index < 0 or index >= _roads.size():
		return fallback
	var road: Dictionary = _roads[index]
	var points: PackedVector2Array = road["nuqta"]
	if points.size() < 2:
		return fallback

	var total: float = _lengths[index]
	if total < 0.001:
		return fallback
	# Chekishdan tashqariga chiqsa — boshiga qaytadi
	var wrapped: float = fposmod(along, total)
	var table: PackedFloat32Array = _cumulative[index]
	for i in range(points.size() - 1):
		if table[i + 1] >= wrapped:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var span: float = table[i + 1] - table[i]
			var t: float = (wrapped - table[i]) / maxf(span, 0.0001)
			var spot: Vector2 = a.lerp(b, t)
			var along_dir: Vector2 = (b - a) / maxf(span, 0.0001)
			return {
				"nuqta": spot,
				"yo'nalish": along_dir,
				"orasidagi": wrapped,
				"chegara": i > 0 and i < points.size() - 2,
				"yo'l": road["nom"],
				"tur": int(road["tur"]),
				"y": TerrainGen.height_at(spot.x, spot.y) if with_height else 0.0,
				"uzunlik": total,
			}
	return fallback


## Nuqtaga yaqinligi (gacha bo'lgan minimal masofa) yo'l chegarasi
## ichida yoki yo'q.
static func road_is_near(index: int, point: Vector2, reach: float) -> bool:
	if index < 0 or index >= _boxes_lo.size():
		return false
	var lo: Vector2 = _boxes_lo[index]
	var hi: Vector2 = _boxes_hi[index]
	var closest := Vector2(
		clampf(point.x, lo.x, hi.x), clampf(point.y, lo.y, hi.y))
	return closest.distance_to(point) <= reach


## Yo'ldagi nuqtalar (kinematik mashina uchun).
static func road_length(index: int) -> float:
	_ensure()
	if index < 0 or index >= _lengths.size():
		return 0.0
	return _lengths[index]


## Nuqtaga eng yaqin yo'l nuqtasi. AI mashinalari shundan foydalanadi
## (yo'lni topish, chetga chiqmaslik), surat vositasi ham.
##
## Qaytaradi: {"nuqta": Vector2, "masofa": float, "normal": Vector2,
##            "yo'nalish": Vector2, "yo'l": String, "orasidagi": float}
static func nearest_road_point(p: Vector2) -> Dictionary:
	_ensure()
	var best := INF
	var best_point := p
	var best_normal := Vector2(1, 0)
	var best_direction := Vector2(1, 0)
	var best_road := ""
	var best_along := 0.0

	for index in _roads.size():
		var road: Dictionary = _roads[index]
		var points: PackedVector2Array = road["nuqta"]
		var half: float = HALF_WIDTH[road["tur"]]
		var reach: float = half + LEVELING_WIDTH
		var walked := 0.0
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var ab: Vector2 = b - a
			var length_sq: float = ab.length_squared()
			var length := sqrt(length_sq)
			var t: float = 0.0
			if length_sq > 0.0001:
				t = clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
			var projected: Vector2 = a + ab * t
			var distance: float = projected.distance_to(p)
			if distance < best and distance <= reach + 40.0:
				best = distance
				best_point = projected
				best_along = walked + length * t
				var direction: Vector2 = ab / maxf(length, 0.0001)
				best_normal = direction.orthogonal()
				best_direction = direction
				best_road = road["nom"]
			walked += length

	return {
		"nuqta": best_point,
		"masofa": best,
		"normal": best_normal,
		"yo'nalish": best_direction,
		"yo'l": best_road,
		"orasidagi": best_along,
	}


## Nuqta Amudaryo YOKI sho'r ko'lda yotdimi? Bular keng — ulardan
## ko'prik qurish mumkin emas, yo'l qayta yo'naltirilishi kerak.
static func is_major_water(x: float, z: float) -> bool:
	var river_z: float = TerrainGen.RIVER_CENTER_Z \
		+ sin(x / TerrainGen.RIVER_WAVE_PERIOD) * TerrainGen.RIVER_WAVE
	if absf(z - river_z) < TerrainGen.RIVER_HALF_WIDTH:
		return true
	for lake: Dictionary in TerrainGen.SALT_LAKES:
		if Vector2(x, z).distance_to(lake["pos"]) < float(lake["r"]) * 0.7:
			return true
	return false


## Yo'lning to'liq kengligi (m).
static func road_width(road: Dictionary) -> float:
	return HALF_WIDTH[road["tur"]] * 2.0


## Barcha yo'llar uzunligi (m) — diagnostika uchun.
static func total_length() -> float:
	var total := 0.0
	for i in _roads.size():
		var points: PackedVector2Array = _roads[i]["nuqta"]
		for j in range(points.size() - 1):
			total += points[j].distance_to(points[j + 1])
	return total


static func _ensure() -> void:
	if _ready:
		return
	_coast_noise = FastNoiseLite.new()
	_coast_noise.seed = Settings.WORLD_SEED + 717
	_coast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast_noise.frequency = 0.02

	_build_ring()
	_build_radials()
	_build_urganch_grid()
	_build_khiva_streets()
	_build_dirt_roads()
	_index()
	# Uzunlik jadvali — `point_along` va `road_length` shundan foydalanadi
	_build_tables()
	_ready = true


## DIAGNOSTIKA: nuqta qanday tekishlanayotganini ochiq ko'rsatadi —
## qaysi kesimlar topildi, masofa qancha, profil qancha.
##
## Bu yerda boshidan ikki marta ishlatildi va ikkalasi ham ko'rinmas
## xatoni ko'rsatdi: yo'l markazi to'g'ri tekislangan, lekin yonidagi
## nuqta faqat xom yer bo'lib qolgan (fazolaviy to'r xatosi). Shuning
## uchun bu vosita kodda qoldiriladi — keyingi xatolarni izohlashda
## bir necha daqiqe vaqt tejlaydi.
static func debug_flatten(x: float, z: float) -> String:
	_ensure()
	var p := Vector2(x, z)
	var key := _cell_of(p)
	var segments: PackedInt32Array = _grid.get(key, PackedInt32Array())
	var lines := PackedStringArray()
	lines.append("(%0.1f, %0.1f) KATAK=%s segmentlar=%d" % [x, z, str(key), segments.size()])
	for i in segments:
		var seg: Dictionary = _segments[i]
		var a: Vector2 = seg["a"]
		var ab: Vector2 = seg["b"] - a
		var ls: float = seg["kvadrat"]
		var t: float = 0.0 if ls <= 0.0 else clampf((p - a).dot(ab) / ls, 0.0, 1.0)
		var d: float = (a + ab * t).distance_to(p)
		var half: float = seg["yarim"]
		var w: float = smoothstep(half + LEVELING_WIDTH, half + FLAT_MARGIN, d)
		lines.append("  yo'l=%2d masofa=%6.2f yarim=%4.1f w=%.3f profil=%.3f" % [
			seg["yo'l"], d, half, w,
			_profile_at(seg, seg["boshlanish"] + seg["uzunlik"] * t)])
	lines.append("  xom balandlik = %.3f" % TerrainGen._base_height(x, z))
	return "\n".join(lines)


## TO'R BUTUNLIGI: har bir yo'l nuqtasi o'z katagida o'z yo'li kesimini
## topishi kerak. Aks holda yer shu nuqtada tekishlanmaydi.
static func verify_index() -> PackedStringArray:
	_ensure()
	var problems := PackedStringArray()
	for road_index in _roads.size():
		var road: Dictionary = _roads[road_index]
		var points: PackedVector2Array = road["nuqta"]
		for i in points.size():
			var p: Vector2 = points[i]
			var key := _cell_of(p)
			var list: PackedInt32Array = _grid.get(key, PackedInt32Array())
			var found := false
			for si in list:
				var seg: Dictionary = _segments[si]
				if seg["yo'l"] != road_index:
					continue
				var a: Vector2 = seg["a"]
				var ab: Vector2 = seg["b"] - a
				var ls: float = seg["kvadrat"]
				var t: float = 0.0 if ls <= 0.0 else clampf((p - a).dot(ab) / ls, 0.0, 1.0)
				if (a + ab * t).distance_to(p) < 0.5:
					found = true
					break
			if not found:
				if problems.size() < 5:
					problems.append("%s nuqta %d (%.1f, %.1f) KATAK=%s da %d kesim bor, lekin o'z yo'li yo'q" % [
						road["nom"], i, p.x, p.y, str(key), list.size()])
	return problems
