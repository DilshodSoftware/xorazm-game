class_name CarShapes
extends RefCounted
## Mashina kuzovini kod bilan chizadi — bitta fayl, bitta geometriya
## yig'uvchi, hech qanday tashqi model fayli yo'q.
##
## USUL
## Kuzov "staqichalar" (stations) deb ataladigan qator bilan chiziladi.
## Har bir staqicha mashinaning uzunligi bo'ylab bitta kesim:
## qayerda pol, qayerda beltinga chiziq, qayerda shift, qancha keng.
## Kesimlar orasidagi yuzalar `add_face` bilan chiziladi, shuning uchun
## burilish hech qachon xato bo'lmaydi.
##
## YO'NALISH QOIDASI (majburiy)
## Oldingi tomon −Z da. Bu Godot ning o'z qoidasi: kamera −Z ga
## qaraydi, `Node3D.forward()` shunga teng, ko'pchilik namunasi shu
## yo'nalishda chiziladi.
##
## DIQQAT: avval modeller +X da chizilgan edi. Natijada mashina
## "oldinga" qaraganda orqaga burilib, ko'chaga PERPENDIKULAR
## yotib qolardi — ko'chadagi uyning ichiga botib, zarba qutisi
## uni shift ustiga chiqarib yuborardi (sinovda: yerdan 0,82 m
## ko'tarilib, gaz berilganda ham qo'zg'almagan). Yo'nalish
## -Z ga ko'chirildi.
##
## Kesim 8 burchakli (X, Y, toraytirish) da:
##
##       4 ───── 5            ← shift
##      ╱          ╲
##     3            6        ← beltinga chizig'i (yon oyna shu yerda
##     │            │            boshlanadi)
##     2            7
##      ╲          ╱
##       0 ───── 1            ← pastki qirqliq
##
## Yon oyna 3→4 va 5→6 yuzalarida turadi. Oldingi oyna (shisha)
## stansiyalar turishi o'zgarganda — yani yondan xatchopga o'tganda —
## avtomatik paydo bo'ladi. Shuning uchun oldingi oyna uchun alohida
## chizilgan to'rtburchak yo'q: u shu yuzaning o'zi.
##
## Nima uchun shu usul
## Kublardan yig'ish mumkin edi, lekin mashina kubdan ko'rinardi:
## qat'iy burchaklar, tekis yuzalar. Staqicha usuli yon profile
## silliq chiqadi — bu 1.5 m masofada seziladi va oddiy o'yinchi
## shunchaki "mashina" deb taniydi.
##
## DIQQAT: halqaning birinchi komponenti endi X (kenglik), oldin
## Z edi — chunki uzunlik o'qi endi −Z.
##
## Uchinchi komponent — toraytirish og'irligi: 1 bo'lsa, stansiyaning
## `tor` qiymati qo'llaniladi. Faqat shift burchaklarida 1 — ya'ni
## shift balandingiz kuzovdan tor, lekin yon devor balandligi o'sishda
## (bu haqiqiy mashinada ham shunday: yon oyna yuqoriga qarab
## ichkariga egiladi).
const RING := [
	Vector3(-1.00, 0.00, 0.0),   # 0 past-chap
	Vector3(1.00, 0.00, 0.0),    # 1 past-o'ng
	Vector3(1.00, 0.56, 0.0),    # 2 yon (pastki qism)
	Vector3(1.00, 0.80, 0.0),    # 3 beltinga chizig'i
	Vector3(0.86, 1.00, 1.0),    # 4 shift-o'ng
	Vector3(-0.86, 1.00, 1.0),   # 5 shift-chap
	Vector3(-1.00, 0.80, 0.0),   # 6 beltinga chizig'i
	Vector3(-1.00, 0.56, 0.0),   # 7 yon (pastki qism)
]
const RING_EDGES := 8   ## RING uzunligi (const ifoda `size()`ni qabul qilmaydi)

## Yon oyna joyi: 3→4 (o'ng) va 5→6 (chap).
const GLASS_SIDE := [3, 5]
## Oldingi/oringi oyna: stansiya turi o'zgargandagi yuzalarning
## hammasi shisha bo'ladi (A-tillar ham, oynaning o'zi ham).
const GLASS_FRONT := [2, 3, 4, 5, 6]

## Ranglar
const UNDER := Color("35322e")       ## Pastki qirqliq (qorong'i)
const TYRE := Color("22201f")
const RIM := Color("9aa0a4")
const GLASS := Color("3a4b54")       ## Shisha — ko'k-greys, yorqin emas
const LAMP := Color("e8e4d6")        ## Oldingi fara
const LAMP_RED := Color("a5231c")    ## Qizil signal
const LAMP_AMBER := Color("d9922c")  ## Ko'rsatkich
const TRIM := Color("6a6f72")        ## Bufer, halqa
const GRILLE := Color("2c2e30")      ## Radish tori
const PLATE := Color("d8d5c8")       ## Davlat raqami
const LAMP_DIM := Color("6d6a60")    ## Ishlatilmagan chiroq


## Bitta mashinaning to'liq kuzovi + g'ildoraklari.
##
## [param builder] — geometriya yig'uvchi (bir necha mashina uchun
## umumiy ishlatilishi mumkin).
## [param spec] — CarSpecs dan birinchi model.
## [param origin] — mashinaning markazi, yerga tegadigan nuqta.
## [param colour] — kuzov rangi.
## [param want_collision] — urish geometriyasi kerakmi (AI mashinalari
## uchun kerak, dekorativ ko'rinish uchun kerak emas).
static func build(builder: MeshBuilder, spec: Dictionary, origin: Vector3,
		colour: Color, want_collision: bool = true) -> void:
	var stations: Array[Dictionary] = _stations(spec)
	var width: float = float(spec["kenglik"])
	var half := width * 0.5

	_shell(builder, stations, origin, half, colour, want_collision)
	_bumpers(builder, spec, stations, origin, half, want_collision)
	_lights(builder, spec, stations, origin, half)
	_details(builder, spec, stations, origin, half, want_collision)
	if bool(spec.get("marshrutka", false)):
		_route_sign(builder, spec, stations, origin, half, want_collision)
	wheels(builder, spec, origin, want_collision)


## Faqat kuzov qobig'i — chiroq, bufer, ko'zgu va g'ildoraklarsiz.
##
## Nima uchun alohida funksiya: o'lchamni tekshirishda aynan shu
## qism model o'lchamiga MUTLAQ mos kelishi SHART (ko'zgu kuzovdan
## 25 sm kengroq — bu normal), lekin to'liq modelda kenglik
## o'lchashga to'g'ri kelmaydi. Test shu funksiyani ishlatadi.
static func build_shell(builder: MeshBuilder, spec: Dictionary,
		colour: Color) -> void:
	_shell(builder, _stations(spec), Vector3.ZERO,
		float(spec["kenglik"]) * 0.5, colour, false)


## Yolg'iz g'ildorak (Vehicle butun model emas, bitta g'ildorak
## chizishini so'raydi). Ekseni Z bo'ylab yotgan silindr + nippel +
## yoy ichi.
static func build_wheel(builder: MeshBuilder, radius: float,
		width: float) -> void:
	_wheel(builder, Vector3.ZERO, radius, width, false)


## G'ildorakni ANIQLANGAN joyda, umumiy mesh ichida chizadi.
##
## NIMA UCHUN: AI mashinalarida g'ildoraklar aylanmaydi
## (`physics_driven = false`), shuning uchun ularni alohida tugun
## qilib saqlashning hojimi yo'q. Har bir alohida `MeshInstance3D`
## bitta chizqich (draw call) — 76 ta mashina × 4 g'ildorak = 304
## chizqich. Ularni kuzov mesh'iga birlashtirish 5 chizqichni 1 ga
## tushiradi va o'lchovda 194 chizqichdan ~90 ga tushdi.
static func build_wheel_at(builder: MeshBuilder, centre: Vector3,
		radius: float, width: float) -> void:
	_wheel(builder, centre, radius, width, false)


# ================================================================ SILUET

## Shaklga qarab staqichalarni qaytaradi.
##
## Har bir staqicha:
##   x     — mashina markaziga nisbatan, metr (−old…+orqa)
##   past  — pastki qirqliq balandligi, m
##   beltiq — yon oynaning pastki chizig'i, m
##   shift — shiftning balandligi, m
##   keng  — kuzovning yarim eni (meters)
##   tor   — shiftning yarim eni (kengdan kichikroq)
##   qism  — CarSpecs.Part
static func _stations(spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary]
	match int(spec["shakl"]):
		CarSpecs.Shape.SEDAN:
			out = _sedan(spec)
		CarSpecs.Shape.MINIBUS:
			out = _minibus(spec)
		_:
			out = _hatch(spec)
	return _with_openings(out, spec)


## Shaklga qarab staqichalarni qaytaradi (ochiq versiya — sinov uchun).
static func stations(spec: Dictionary) -> Array[Dictionary]:
	return _stations(spec)


## Barcha o'lchamlarni model o'lchamiga masshtablovchi yordamchi.
##
## DIQQAT: balandlik FRANSIYA (0…1) beriladi, `past` esa metrda.
## Shunda shift har bir modelda aniq `balandlik` da bo'ladi:
## `f = 1.0` → shift = balandlik (yerdan shiftgacha). Aks holda
## bitta profil ikki balandlikdagi modelga ishlatilardi va Spark
## (1,48 m) 1,12 m baland chiqardi — mashina yerga cho'kib turardi.
##
## Nima uchun shu tarzda: CarSpecs da balandlik YERDAN o'lchanadi
## (1483 mm — Spark uchun rasmiy raqam). Profil esa qirqliqdan
## boshlanadi. Ikkalasi boshlang'ich nuqtadan farq qiladi, shuning
## uchun fraksiya aynan shu muammoni hal qiladi.
static func _scaled(stations: Array[Array], length: float,
		height: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Array in stations:
		# row = [u, past (m), beltiq (fraksiya), shift (fraksiya), tor, qism]
		var floor_y: float = float(row[1])
		var headroom: float = height - floor_y
		out.append({
			"u": float(row[0]),
			# u=0 → orqa (+Z), u=1 → oldingi (−Z)
			"x": (0.5 - float(row[0])) * length,
			"past": floor_y,
			"beltiq": floor_y + float(row[2]) * headroom,
			"shift": floor_y + float(row[3]) * headroom,
			"tor": float(row[4]),
			"qism": int(row[5]),
		})
	return out


## G'ildorak o'yini — kuzovning pastki chizig'i g'ildorak ustida
## ko'tariladi.
##
## NIMA UCHUN BU ZARUR
## Aks holda mashina "quti ustida to'rtta doira" bo'lib chiqadi:
## qirqliq pastda, g'ildoraklar esa uning OSTIDA ko'rinadi. Haqiqiy
## mashinada esa yon devorda aylana shaklidagi OYNA bor va butun
## g'ildorak shu oynadan ko'rinadi. Bu bitta o'ynasiz farq
## "mashina" va "uzilgan quti" o'rtasidagi farq.
##
## Oyna yarim doirasi shaklida: balandligi markazda eng katta,
## chetlarida nol (uzluksiz chiziqqa qo'shiladi).
static func _add_wheel_openings(stations: Array[Dictionary], axle_u: float,
		sill: float, peak: float, radius: float, length: float) -> Array[Dictionary]:
	var half: float = (radius + 0.17) / length
	var out: Array[Dictionary] = []
	var done := false
	for i in stations.size():
		var station: Dictionary = stations[i]
		# DIQQAT: stansiya AVVAL qo'shiladi, arx nuqtalari undan
		# KEYIN. Teskari tartib yuzani "qaytarib" yuboradi
		# (stansiya i → i+1 → yana i) va hajm manfiy chiqadi.
		out.append(station)
		if done or i + 1 >= stations.size():
			continue
		var here: float = float(station["u"])
		var next_u: float = float(stations[i + 1]["u"])
		if axle_u <= here or axle_u >= next_u:
			continue
		var next_station: Dictionary = stations[i + 1]
		# Faqat ICHKI nuqtalar (u=0 va u=1 allaqon mavjud)
		for k in range(1, 4):
			var t: float = float(k) / 4.0
			var u: float = lerpf(here, next_u, t)
			var d: float = absf(u - axle_u) / half
			# Yarim doira: markazda eng baland, chetlarida nol
			var arch: float = sqrt(maxf(1.0 - d * d, 0.0))
			out.append({
				"u": u,
				"x": (0.5 - u) * length,
				"past": lerpf(sill, peak, arch),
				"beltiq": lerpf(float(station["beltiq"]),
					float(next_station["beltiq"]), t),
				"shift": lerpf(float(station["shift"]),
					float(next_station["shift"]), t),
				"tor": lerpf(float(station["tor"]),
					float(next_station["tor"]), t),
				"qism": int(station["qism"]),
			})
		done = true
	return out if done else stations


## Ikkala g'ildorak o'yni bilan bezangan stansiyalar ro'yxati.
static func _with_openings(stations: Array[Dictionary],
		spec: Dictionary) -> Array[Dictionary]:
	var axle := CarSpecs.axles(spec)
	var length: float = float(spec["uzunlik"])
	var radius: float = float(spec["radius"])
	var sill: float = INF
	for station: Dictionary in stations:
		sill = minf(sill, float(station["past"]))
	# Oyna tepasi g'ildorak radiusidan biroz baland — butun g'ildorak
	# oynadan ko'rinishi SHART
	var peak: float = sill + radius * 1.06
	return _add_wheel_openings(
		_add_wheel_openings(stations, axle.x, sill, peak, radius, length),
		axle.y, sill, peak, radius, length)


## Xatchop — Chevrolet Spark, Aptiya.
##
## Siluet: pastga tushirilgan orqa qiya (og'irlik ~50°), baland shift,
## qisqa yoldorish. Xorazmda eng ko'p uchraydigan mashina.
static func _hatch(spec: Dictionary) -> Array[Dictionary]:
	const T := CarSpecs.Part.TAIL
	const B := CarSpecs.Part.BOOT
	const C := CarSpecs.Part.CABIN
	const N := CarSpecs.Part.NOSE
	var axle := CarSpecs.axles(spec)
	var front: float = axle.x
	var rear: float = axle.y
	return _scaled([
		# u                   past  beltiq shift tor   qism
		[0.000,               0.44, 0.62,  0.62,  0.90, T],  # orqa buffer
		[maxf(rear - 0.14, 0.02), 0.36, 0.64, 0.64, 0.95, T],
		[maxf(rear - 0.04, 0.03), 0.31, 0.66, 0.93, 0.92, B],
		[rear + 0.01,         0.30, 0.67,  0.96,  0.90, C],  # ← orqa oyna
		[rear + 0.11,         0.29, 0.68,  0.99,  0.87, C],
		[rear + 0.16,         0.28, 0.68,  1.00,  0.86, C],  # shift orqa
		[front - 0.24,        0.28, 0.68,  1.00,  0.86, C],  # shift oldingi
		[front - 0.16,        0.29, 0.67,  0.94,  0.88, C],  # ← oldingi oyna
		[front - 0.05,        0.30, 0.65,  0.64,  0.94, N],  # ← kapot boshi
		[front + 0.07,        0.31, 0.59,  0.57,  0.95, N],  # kapot
		[minf(front + 0.13, 0.96), 0.33, 0.53, 0.50, 0.93, N],
		[1.000,               0.38, 0.46,  0.43,  0.86, N],  # oldingi buffer
	], float(spec["uzunlik"]), float(spec["balandlik"]))


## Sedan — Daewoo Nexia (1,38 m), Chevrolet Cobalt (1,45 m).
##
## Siluet: orqada alohida bagaj (taxminan 1,1 m), undan keyin keskin
## ko'tariladigan orqa oyna. Nexia balandligi Cobalt'dan 7 sm past —
## shuning uchun profil balandlik fransiyasi orqali moslashadi.
static func _sedan(spec: Dictionary) -> Array[Dictionary]:
	const T := CarSpecs.Part.TAIL
	const B := CarSpecs.Part.BOOT
	const C := CarSpecs.Part.CABIN
	const N := CarSpecs.Part.NOSE
	var axle := CarSpecs.axles(spec)
	var front: float = axle.x
	var rear: float = axle.y
	return _scaled([
		[0.000,               0.44, 0.62,  0.62,  0.88, T],  # orqa buffer
		[maxf(rear - 0.16, 0.02), 0.35, 0.65, 0.65, 0.94, T],
		[maxf(rear - 0.07, 0.04), 0.31, 0.67, 0.68, 0.96, B],
		[maxf(rear - 0.01, 0.06), 0.29, 0.68, 0.69, 0.97, B],  # bagaj oxiri
		[rear + 0.03,         0.29, 0.68,  0.86,  0.92, C],  # ← orqa oyna
		[rear + 0.13,         0.28, 0.69,  0.96,  0.88, C],
		[rear + 0.19,         0.28, 0.70,  1.00,  0.87, C],  # shift orqa
		[front - 0.26,        0.28, 0.70,  1.00,  0.87, C],  # shift oldingi
		[front - 0.18,        0.29, 0.69,  0.94,  0.88, C],  # ← oldingi oyna
		[front - 0.12,        0.30, 0.68,  0.66,  0.95, N],  # ← kapot boshi
		[front + 0.06,        0.31, 0.64,  0.61,  0.95, N],  # kapot
		[minf(front + 0.16, 0.96), 0.34, 0.57, 0.53, 0.92, N],
		[1.000,               0.40, 0.50,  0.46,  0.86, N],  # oldingi buffer
	], float(spec["uzunlik"]), float(spec["balandlik"]))


## Miktobus — marshrutka.
##
## Siluet: deyarli to'rtburchak, katta oynalar, orqada umuman
## bagaj yo'q. Bu Xorazm ko'chasining tanilgan belgisi — boshqa
## mashina bilan aralashtirilmaydi.
static func _minibus(spec: Dictionary) -> Array[Dictionary]:
	const T := CarSpecs.Part.TAIL
	const C := CarSpecs.Part.CABIN
	const N := CarSpecs.Part.NOSE
	var axle := CarSpecs.axles(spec)
	var front: float = axle.x
	return _scaled([
		[0.000,               0.46, 0.62,  0.62,  0.96, T],  # orqa devor
		[0.020,               0.38, 0.66,  0.84,  0.95, T],
		[0.060,               0.34, 0.68,  0.95,  0.92, C],
		[0.110,               0.32, 0.68,  1.00,  0.91, C],  # shift orqa
		[front - 0.19,        0.31, 0.69,  1.00,  0.90, C],  # shift oldingi
		[front - 0.10,        0.32, 0.68,  0.95,  0.91, C],  # ← oldingi oyna
		[front - 0.02,        0.33, 0.64,  0.65,  0.94, N],  # ← kapot boshi
		[front + 0.08,        0.34, 0.60,  0.60,  0.95, N],
		[minf(front + 0.17, 0.96), 0.36, 0.53, 0.53, 0.94, N],
		[1.000,               0.42, 0.46,  0.46,  0.88, N],  # oldingi buffer
	], float(spec["uzunlik"]), float(spec["balandlik"]))


# ================================================================ KUZOV

## Kesim burchagining 3D nuqtasi.
static func _point(station: Dictionary, ring: Vector3, half_width: float,
		origin: Vector3) -> Vector3:
	var width: float = half_width * lerpf(1.0, float(station["tor"]), ring.z)
	return origin + Vector3(width * ring.x,
		lerpf(float(station["past"]), float(station["shift"]), ring.y),
		float(station["x"]))


## Kuzov qobig'i: stansiyalarni bog'lab yuzalarni chizadi.
static func _shell(builder: MeshBuilder, stations: Array[Dictionary],
		origin: Vector3, half: float, colour: Color,
		collision: bool) -> void:
	for i in range(stations.size() - 1):
		var a: Dictionary = stations[i]
		var b: Dictionary = stations[i + 1]
		var a_cabin: bool = int(a["qism"]) == CarSpecs.Part.CABIN
		var b_cabin: bool = int(b["qism"]) == CarSpecs.Part.CABIN

		for k in RING_EDGES:
			var k2: int = (k + 1) % RING_EDGES
			var p0 := _point(a, RING[k], half, origin)
			var p1 := _point(a, RING[k2], half, origin)
			var p2 := _point(b, RING[k2], half, origin)
			var p3 := _point(b, RING[k], half, origin)
			# Yuzaning tashqi yo'nalishi: kesimning (z, y) da
			# qarama-qarshi burilgan. Pastki yuzada pastga, yon
			# yuzalarda yon ga qaragan.
			# Yuzaning tashqi yo'nalishi.
			#
			# DIQQAT: oddiy holatda yetarli `Vector3(0, -edge.x, edge.y)`
			# edi, lekin shunda oldingi oyna noto'g'ri burilardi:
			# u deyarli tik bo'lganda geometrik normal vertikal
			# yo'nalish bilan 90° ga yaqinlashadi va `add_face` ning
			# belgi tekshiruvi ikkala tomonni ham qabul qiladi —
			# natijada oyna yoki teskari chiziladi yoki butunlay
			# ko'rinmaydi. Shuning uchun stansiyalar orasidagi
			# balandlik farqi ham hisobga olinadi: yuzaning tikligi
			# uning oldinga-orqaga qarab qaysarishini belgilaydi.
			var edge: Vector2 = Vector2(RING[k2].x - RING[k].x,
				RING[k2].y - RING[k].y)
			# Uzunlik o'qi −Z bo'lgani uchun tiklik belgisi ham
			# o'zgaradi: stansiya Z bo'ylab kamayib boradi
			var slope: float = (float(b["shift"]) - float(a["shift"])) \
				* (RING[k].y + RING[k2].y) * 0.5
			# Kesim (X, Y) da → tashqi yo'nalish (X, Y) da
			# = (dy, −dx), uzunlik bo'yicha tiklik Z ga qo'shiladi
			var outward := Vector3(edge.y, -edge.x, slope)
			var shade: Color = colour
			if k == 0:
				shade = UNDER                      # pastki qirqliq
			elif a_cabin and b_cabin:
				if k in GLASS_SIDE:
					shade = GLASS
			elif a_cabin != b_cabin:
				# Stansiya turi o'zgarganda — bu oldingi yoki orqa
				# oyna. Hech qanday alohida shisha chizilmaydi:
				# yuzaning o'zi shisha.
				if k in GLASS_FRONT:
					shade = GLASS
			builder.add_face(p0, p1, p2, p3, outward, shade, collision)

	# Oldingi va orqa yopishlar
	for end_index: int in [0, stations.size() - 1]:
		var station: Dictionary = stations[end_index]
		var points: Array[Vector3] = []
		for k in RING_EDGES:
			points.append(_point(station, RING[k], half, origin))
		_cap(builder, points, origin, station, colour)


## Uchlarning yopish yuzasi — mashinaning oldingi va orqa devori.
##
## DIQQAT: rang har doim kuzov rangida. Shisha emas: oldingi va orqa
## oyna stansiya O'ZGARGANDA paydo bo'ladi (yuqoriga qarang), ya'ni
## oldingi stansiya bilan keyingi stansiya orasidagi yuzada. Bu yopish
## esa faqat oldingi buffer devori.
static func _cap(builder: MeshBuilder, points: Array[Vector3],
		origin: Vector3, station: Dictionary, colour: Color) -> void:
	# DIQQAT: uzunlik o'qi Z (−Z oldingi). Bu yerda eskirgan X
	# qolsa, yopish nuqtasi ko'chada turadi va butun kuzov
	# "kengligi" mashina uzunligiga teng bo'lib chiqadi.
	var centre := Vector3(
		0.0,
		(float(station["past"]) + float(station["shift"])) * 0.5,
		float(station["x"]))
	var tip := origin + centre
	# Oldingi tomon −Z
	var outward := Vector3(
		0.0, 0.0, -1.0 if float(station["x"]) < 0.0 else 1.0)
	for i in points.size():
		var j: int = (i + 1) % points.size()
		var normal := (points[j] - tip).cross(points[i] - tip)
		if normal.dot(outward) < 0.0:
			builder.add_triangle(tip, points[j], points[i], colour, outward)
		else:
			builder.add_triangle(tip, points[i], points[j], colour, outward)


# ================================================================ QISMLAR

## Oldingi va orqa buferlar. Mashinaning eng qalin, eng to'gri qismi.
static func _bumpers(builder: MeshBuilder, spec: Dictionary,
		stations: Array[Dictionary], origin: Vector3, half: float,
		collision: bool) -> void:
	for tail: bool in [false, true]:
		var station: Dictionary = stations[0] if tail else stations[stations.size() - 1]
		# `z` — oldingi tomon (−Z) qarab qaraganda manfiy
		var z: float = float(station["x"])
		var sign_z: float = 1.0 if tail else -1.0
		var low: float = float(station["past"])
		var high: float = float(station["past"]) + 0.30
		var depth: float = 0.16
		var width: float = half * 1.9
		var centre := origin + Vector3(0.0, (low + high) * 0.5,
			z + sign_z * depth * 0.4)
		builder.add_box(centre,
			Vector3(width, high - low, depth), TRIM, 0.0, collision)


## Chiroqlar: oldinda fara, orqada qizil signal, yonlarda ko'rsatkich.
static func _lights(builder: MeshBuilder, spec: Dictionary,
		stations: Array[Dictionary], origin: Vector3, half: float) -> void:
	var nose: Dictionary = stations[stations.size() - 1]
	var tail: Dictionary = stations[0]
	var nose_x: float = float(nose["x"])
	var tail_x: float = float(tail["x"])
	var lamp_y: float = float(nose["beltiq"]) - 0.10
	var tail_y: float = float(tail["beltiq"]) - 0.08

	# --- Oldingi faralar ---
	for side: float in [-1.0, 1.0]:
		var lamp := origin + Vector3(side * half * 0.62, lamp_y,
			nose_x - 0.055)
		builder.add_box(lamp, Vector3(0.34, 0.17, 0.10), LAMP, 0.0, false)
	# Radish tori — markazda, kundalik kuzovda eng ko'p ko'rinadigan
	# qora dog'ular
	var grille_centre := origin + Vector3(0.0, lamp_y - 0.02, nose_x - 0.04)
	builder.add_box(grille_centre, Vector3(half * 0.95, 0.15, 0.06),
		GRILLE, 0.0, false)

	# --- Davlat raqami ---
	var plate := origin + Vector3(0.0, lamp_y - 0.30, nose_x - 0.075)
	builder.add_box(plate, Vector3(0.44, 0.12, 0.03), PLATE, 0.0, false)

	# --- Orqa signallar ---
	for side: float in [-1.0, 1.0]:
		var lamp := origin + Vector3(side * half * 0.66, tail_y, tail_x + 0.05)
		builder.add_box(lamp, Vector3(0.26, 0.20, 0.09), LAMP_RED, 0.0, false)
		# Yuqorida kichik qizil — marshrutkalar va Spark'lar shunday
		var high := origin + Vector3(side * half * 0.52,
			float(tail["shift"]) - 0.14, tail_x + 0.10)
		builder.add_box(high, Vector3(0.13, 0.09, 0.05), LAMP_DIM, 0.0, false)

	# --- Yon ko'rsatkichlar (kompilyatsiya ustida yon devorda) ---
	var mid: Dictionary = stations[stations.size() / 2]
	for side: float in [-1.0, 1.0]:
		var lamp := origin + Vector3(side * half * 0.99,
			float(mid["beltiq"]) - 0.14, float(mid["x"]) - 0.10)
		builder.add_box(lamp, Vector3(0.05, 0.08, 0.13), LAMP_AMBER, 0.0, false)


## Ko'zgu, ichki detail'lar, oldingi va orqa raqam taxtasi.
static func _details(builder: MeshBuilder, spec: Dictionary,
		stations: Array[Dictionary], origin: Vector3, half: float,
		collision: bool) -> void:
	# --- Ko'zgu: A-tillar oldida, yon tomonda ---
	# Oldingi stansiya joylashuvini ishlatamiz — ko'zgu faqat
	# shunda to'g'ri chiqadi.
	for i in stations.size():
		if int(stations[i]["qism"]) != CarSpecs.Part.NOSE:
			continue
		var station: Dictionary = stations[i]
		var z: float = float(station["x"])
		var y: float = float(station["shift"]) - 0.02
		for side: float in [-1.0, 1.0]:
			# Poy (tayoqcha)
			builder.add_box(origin + Vector3(side * half * 0.94, y - 0.06,
				z + 0.02), Vector3(0.10, 0.05, 0.06), TRIM, 0.0, false)
			# Ko'zgu tanasi
			builder.add_box(origin + Vector3(side * half * 1.12, y + 0.02,
				z + 0.06), Vector3(0.05, 0.11, 0.16), TRIM, 0.0, false)
			# Ko'zgu yuzasi (qora)
			builder.add_box(origin + Vector3(side * half * 1.14, y + 0.02,
				z + 0.10), Vector3(0.02, 0.085, 0.12), GLASS, 0.0, false)
		break

	# --- Pastki himoya (yarpaq to'siq) ---
	# Xorazmda har doim bor: qumli, past tekislikda aylanib chiqish
	# mumkin, lekin kichkinagina balandlik ko'pni saqlaydi.
	var nose: Dictionary = stations[stations.size() - 1]
	builder.add_box(
		origin + Vector3(0.0, float(nose["past"]) - 0.04,
			float(nose["x"]) + 0.12),
		Vector3(half * 1.7, 0.06, 0.18), UNDER, 0.0, collision)


## Marshrutka peshona belgisi — Xorazm ko'chasining eng tanilgan
## belgisi. Yo'l raqami yozilgan to'rtburchak, shift oldida.
##
## DIQQAT: balandlik KABINANING shiftidan olinadi, oldingi
## stansiyadan emas. Oldingi stansiya pastda (kapot 1,3 m da) —
## belgi shunda oldingi kapot ustida suzib yurardi, peshona
## ustida emas.
static func _route_sign(builder: MeshBuilder, spec: Dictionary,
		stations: Array[Dictionary], origin: Vector3, half: float,
		collision: bool) -> void:
	var roof: Dictionary = stations[0]
	var found := false
	for station: Dictionary in stations:
		if int(station["qism"]) == CarSpecs.Part.CABIN:
			roof = station          # oxirgi kabina stansiyasi saqlanadi
			found = true
	if not found:
		return
	var z: float = float(roof["x"]) + 0.26
	var top: float = float(roof["shift"]) + 0.015
	var width: float = 0.66
	var height: float = 0.26
	# Ikki tomonlama: oldi va orqa devorda bir xil belgi
	for side: float in [1.0, -1.0]:
		var panel := origin + Vector3(side * 0.013, top + height * 0.5, z)
		builder.add_box(panel, Vector3(0.026, height, width), LAMP, 0.0,
			collision and side > 0.0)
		# Belgi matni — qara to'rtburchaklar (harflar kodda emas)
		for i in 3:
			var letter := origin + Vector3(
				side * 0.030, top + height * 0.5,
				z + width * 0.27 - float(i) * width * 0.27)
			builder.add_box(letter,
				Vector3(0.01, height * 0.52, width * 0.15), UNDER, 0.0, false)


# ================================================================ G'ILDORAK

## To'rt g'ildorak. Balandlik yerga tegadi, shuning uchun mashinaning
## markazi yerga tegadigan nuqtada turadi.
static func wheels(builder: MeshBuilder, spec: Dictionary, origin: Vector3,
		collision: bool) -> void:
	var radius: float = float(spec["radius"])
	var width: float = float(spec["en_kenglik"])
	var base: float = float(spec["gildorak"]) * 0.5
	var track: float = float(spec["iz"]) * 0.5
	for front: bool in [false, true]:
		var z: float = -base if front else base
		for side: float in [-1.0, 1.0]:
			_wheel(builder, origin + Vector3(side * track, radius, z),
				radius, width, collision)


static func _wheel(builder: MeshBuilder, centre: Vector3, radius: float,
		width: float, collision: bool) -> void:
	# G'ildorak yassi aylanma — ekseni X bo'ylab
	var axis := Vector3(width * 0.5, 0, 0)
	builder.add_cylinder(centre - axis, centre + axis, radius, 12, TYRE,
		collision)
	# Nippel — kichkina, lekin kuzovga yaqin tursa siluetni buzadi
	builder.add_cylinder(centre + Vector3(width * 0.44, 0, 0),
		centre + Vector3(width * 0.52, 0, 0), radius * 0.56, 10, RIM, false)
