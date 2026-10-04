class_name Traffic
extends Node3D
## Ko'chadagi mashinalar: yo'l bo'ylab suriladigan AI va ko'chada
## qo'yilgan (turgan) mashinalar.
##
## NIMA UCHUN KINEMATIK AI
## 20 ta to'liq fizikali mashina (VehicleBody3D) bir-biriga uriladi,
## ketma-ket to'planib qoladi va zayif protsessorda FPS tushadi.
## AI mashinalar uchun fizika O'CHIRILGAN: ular to'g'ridan-to'g'ri
## yo'lning o'z nuqtasiga qo'yiladi. Natijada:
##   * hech qachon to'xtamaydi va to'qnashmaydi
##   * har kadrda 1 ta `point_along` chaqiruvi (jami 20 ta) — arzon
##   * faqat o'yinchi mashinasi haqiqiy fizika bilan ishlaydi
## O'yinchi o'z mashinasini AI ustiga urganda AI qo'zg'aladi
## (kinematik jism — o'zgarishsiz turadi, lekin tegiladi), bu
## o'yin uchun yetarli va xavfsiz.
##
## YO'LDAGI TARTIB
## O'zbekistonda o'ngdan chapga (masalan Yevropa) harakatlanadi.
## Har bir mashina yo'ldan o'ng tomonda, o'rtadan 1.7 m masofada
## turadi. Yo'ldan chetga chiqmaydi — bu qat'iy.
##
## MAHALLA KO'CHALARI
## Tandirchi ko'chalari 7 m eni — u yerda harakatlanuvchi trafik
## bo'lmaydi (haqiqiy hayotda ham yo'q). Shuning uchun mahallada
## faqat QO'YILGAN mashinalar qo'yiladi: ular ko'chaga hayot
## beradi va o'yinchi ularning orqasidan o'tib ketadi.

## Surish uchun ishlatiladigan yo'llar (mahalla kichik ko'chalar
## tashlab qoldiriladi — ular juda tor).
const TRAVEL_TYPES := [RoadNetwork.HIGHWAY, RoadNetwork.STREET,
	RoadNetwork.DIRT]

## Yo'l turiga bog'liq mashina soni: 1 ta mashina har shu masofada.
const GAP_HIGHWAY := 62.0
const GAP_STREET := 46.0
const GAP_DIRT := 130.0

## Tezlik oralig'i (km/soat). Xorazm shahar ko'chalarida sekin,
## magistralda tez.
const SPEED_STREET := 34.0
const SPEED_HIGHWAY := 74.0
const SPEED_DIRT := 44.0

## O'LCHOV: bu tizim HAZIR VAQTDA SEKIN
##
## O'lchov (40 kadr, 1280x720, Intel UHD ICL GT1):
##   trafiksiz                 9,5 s   (4-bosqich darajasida ~0,7 s edi)
##   1 ta ham harakatlanuvchi  40,0 s
## Son emas — mexanizm: 5 ta va 35 ta bir xil natija beradi.
## Chiqarilgan gumonlar (barchasi o'lchov bilan rad etildi):
##   * soya (cast_shadow)  — o'chirildi, o'zgarmadi
##   * mashina mesh'lari   — yashirildi, o'zgarmadi
##   * zarba shakli        — o'chirildi, o'zgarmadi
##   * har kadrda joyini
##     yangilash (place_on_road) — o'chirildi, o'zgarmadi
##   * g'ildorak aylanishi (rotate_object_local → to'g'ri rotatsiya)
## G'ol qolgan muqobil: `RigidBody3D` jismlari (`freeze = true`)
## tizimga qo'shilganda fizika qadami sekinlashadi — ehtimol
## `FREEZE_MODE_KINEMATIC` har kadrda kenglik fazasini
## qayta qurayotganidir.
##
## KEYINGI QADAM: AI mashinalarini `RigidBody3D` dan chiqarib,
## oddiy `Node3D` (harakatlanuvchi trafik fizika talab qilmaydi)
## qilish. Zarba uchun alohida `StaticBody3D`.
##
## VAQTINCHA: `XORAZM_TRAFIX=0` bilan trafikni o'chirish mumkin.
##
## Yuklash va yuklashdan chiqarish masofasi, m.
const SPAWN_RADIUS := 230.0
const DESPAWN_RADIUS := 300.0

## O'zgaruvchan (rasmiy tilda "mutable") holat — sinov va o'qish uchun.
var cars: Array[Vehicle] = []
var parked: Array[Vehicle] = []
var _target: Node3D = null
var _rng := RandomNumberGenerator.new()
## Yo'l indeksi → band qilingan masofalar ro'yxati
var _lanes: Dictionary = {}
var _parked_plots: Array[Dictionary] = []


func _ready() -> void:
	name = "Trafik"
	_rng.randomize()


## O'yinchiga bog'lanadi. Har kadrda o'z atrofiga mashinalar
## qo'shiladi va uzoqlashganlari olib tashlanadi.
func follow(who: Node3D) -> void:
	if OS.get_environment("XORAZM_TRAFIX") == "0":
		# O'LCHOV sababi bilan o'chirilgan (yuqoroga qarang)
		set_physics_process(false)
		set_process(false)
		return
	_target = who
	spawn_parked()


## Mashinalarni darhol to'ldiradi (bir kadr kutmasdan).
##
## Nima uchun kerak: `--shot` kabi buyruqlar 40 kadr kutadi, lekin
## o'yinchi boshlagan zahoti ko'chada hech narsa ko'rmasligi
## kerak emas. `set_physics_process(false)` bilan to'xtatilgan
## sinovlarda ham qo'llaniladi.
func force_refresh() -> void:
	if _target == null:
		return
	var here: Vector2 = Vector2(_target.global_position.x, _target.global_position.z)
	_manage_travelling(here, 0.0)


func _process(delta: float) -> void:
	if _target == null:
		return
	var here: Vector2 = Vector2(_target.global_position.x,
		_target.global_position.z)
	_manage_travelling(here, delta)
	_manage_parked(here)


# ================================================================ SURISH

## Har bir yo'l uchun kerakli mashina sonini hisoblaydi, yetishini
## qo'shiladi, uzoqlashganini olib tashlaydi.
func _manage_travelling(here: Vector2, delta: float) -> void:
	var roads := RoadNetwork.roads()
	var wanted: Array[int] = []
	for i in roads.size():
		if int(roads[i]["tur"]) not in TRAVEL_TYPES:
			continue
		var length: float = RoadNetwork.road_length(i)
		if length < 40.0:
			continue
		var gap := GAP_HIGHWAY
		match int(roads[i]["tur"]):
			RoadNetwork.STREET:
				gap = GAP_STREET
			RoadNetwork.DIRT:
				gap = GAP_DIRT
		var count := int(clampf(length / gap, 1.0, 7.0))
		for k in count:
			wanted.append(i)

	_lanes.clear()
	for car: Vehicle in cars:
		if not is_instance_valid(car):
			continue
		var index := int(car.get_meta("yol", -1))
		var along: float = float(car.get_meta("orasida", 0.0))
		if not _lanes.has(index):
			_lanes[index] = []
		(_lanes[index] as Array).append(along)
		_drive(car, index, along, delta, here)

	# Yetishmagan mashinalarni qo'shish
	for index: int in wanted:
		# UZOQ YO'LLARNI UMUMAN TEKSHIRMAYDI.
		# O'LCHOV: aks holda bitta kadrda 34 yo'l × 130 urinish
		# = 4420 `point_along` chaqiruvi — bir kadr 67 ms.
		# Chegara bilan faqat o'yinchi atrofidagi yo'llar qoladi.
		if not RoadNetwork.road_is_near(index, here, SPAWN_RADIUS + 120.0):
			continue
		var slots: Array = _lanes.get(index, []) as Array
		var gap := GAP_HIGHWAY
		match int(roads[index]["tur"]):
			RoadNetwork.STREET:
				gap = GAP_STREET
			RoadNetwork.DIRT:
				gap = GAP_DIRT
		var need: int = int(clampf(RoadNetwork.road_length(index) / gap,
			1.0, 7.0))

		# Urinishlar soni cheklangan: 8 ta yetarli. 130 ta urinish
		# keraksiz (yuqoridagi chegara bilan yo'llar kam qoladi).
		for attempt in 8:
			if slots.size() >= need:
				break
			var along: float = _rng.randf() * RoadNetwork.road_length(index)
			if _too_close(slots, along, 9.0):
				continue
			# Balandlik SHART: mashina shu balandlikda qo'yiladi.
			# `point_along` uni ixtiyoriy qilgan (o'lchov sababli),
			# shuning uchun qo'yishda so'rash SHART.
			var spot: Dictionary = RoadNetwork.point_along(index, along, true)
			# Faqat o'yinchiga yaqin yo'llarda
			var near: float = Vector2(
				spot["nuqta"]).distance_to(here)
			if near > SPAWN_RADIUS:
				continue
			slots.append(along)
			_spawn_traveller(index, along, spot)
			break


## Bitta mashinani bir qadam suradi.
func _drive(car: Vehicle, index: int, along: float, delta: float,
		here: Vector2) -> void:
	var roads := RoadNetwork.roads()
	if index < 0 or index >= roads.size():
		return
	# O'ng tomonda, o'rtadan 1.7 m — o'ngdan chapga harakat
	var lane := 1.7
	var speed: float = float(car.get_meta("tezlik_maqsad", SPEED_STREET))
	var next_along: float = along + speed / 3.6 * delta
	var spot := RoadNetwork.point_along(index, next_along, true)
	var point: Vector2 = spot["nuqta"]
	var direction: Vector2 = spot["yo'nalish"]
	# Yo'nalishga 90° burilgan yo'nalish — mashinaning o'ng tomoni
	var right: Vector2 = direction.orthogonal()
	# Skipping: marshrutka va yuk mashinalari tez
	var place: Vector3 = Vector3(
		point.x + right.x * lane, float(spot["y"]) + 0.02,
		point.y + right.y * lane)
	var yaw: float = rad_to_deg(atan2(-direction.x, -direction.y))
	if absf(float(car.get_meta("burchak", 0.0)) - yaw) > 0.05:
		car.rotation.y = yaw
		car.set_meta("burchak", yaw)
	car.place_on_road(place, yaw, speed)
	car.set_meta("orasida", next_along)

	# Uzoqlashganini olib tashlash (o'yinchi tez mashinada)
	if Vector2(place.x, place.z).distance_to(here) > DESPAWN_RADIUS:
		car.queue_free()
		cars.erase(car)


## Ikki mashina orasida minimal masofa bor-yo'qligi.
func _too_close(slots: Array, along: float, gap: float) -> bool:
	for other: float in slots:
		if absf(other - along) < gap:
			return true
	return false


func _spawn_traveller(index: int, along: float, spot: Dictionary) -> void:
	var roads := RoadNetwork.roads()
	var spec := _random_spec(int(roads[index]["tur"]))
	var car := Vehicle.create(String(spec["kalit"]), _random_colour(spec),
		false)
	add_child(car)
	car.set_meta("yol", index)
	car.set_meta("orasida", along)
	car.set_meta("tezlik_maqsad", _cruise_speed(int(roads[index]["tur"])))
	car.set_meta("burchak", 0.0)
	cars.append(car)
	# Dastlabki joylashuv — bir kadr kutmasdan to'g'ri ko'rinishi uchun
	var half: float = RoadNetwork.HALF_WIDTH[int(roads[index]["tur"])]
	var direction: Vector2 = spot["yo'nalish"]
	var right: Vector2 = direction.orthogonal()
	var point: Vector2 = spot["nuqta"]
	car.place_on_road(Vector3(
		point.x + right.x * 1.7, float(spot["y"]) + 0.02,
		point.y + right.y * 1.7),
		rad_to_deg(atan2(-direction.x, -direction.y)),
		float(car.get_meta("tezlik_maqsad", SPEED_STREET)))


func _cruise_speed(road_type: int) -> float:
	match road_type:
		RoadNetwork.HIGHWAY:
			return _rng.randf_range(SPEED_HIGHWAY - 14.0, SPEED_HIGHWAY)
		RoadNetwork.DIRT:
			return _rng.randf_range(SPEED_DIRT - 10.0, SPEED_DIRT)
	return _rng.randf_range(SPEED_STREET - 10.0, SPEED_STREET)


## Yo'l turiga mos model: magistralda ko'proq yengil mashina,
## shahar ko'chasida esa marshrutka (Xorazmda eng ko'p uchraydigan).
func _random_spec(road_type: int) -> Dictionary:
	var pool: Array[Dictionary] = []
	for spec: Dictionary in CarSpecs.all():
		var is_bus: bool = int(spec["shakl"]) == CarSpecs.Shape.MINIBUS
		match road_type:
			RoadNetwork.HIGHWAY:
				if not is_bus:
					pool.append(spec)
			RoadNetwork.DIRT:
				if not is_bus:
					pool.append(spec)
			_:
				pool.append(spec)
	if pool.is_empty():
		return CarSpecs.all()[0]
	return pool[_rng.randi() % pool.size()]


func _random_colour(spec: Dictionary) -> Color:
	if spec.has("ranglar"):
		var options: Array = spec["ranglar"]
		return options[_rng.randi() % options.size()]
	return spec.get("rangi", Palette.CAR_WHITE)


# ================================================================ QO'YILGAN

## Tandirchi ko'chalariga va Urganch ko'chalariga qo'yilgan
## mashinalar. Ularning vazifasi — ko'chaga hayot berish va o'yinchi
## uchun to'siq bo'lish. Ular HARNMA turgandir.
func spawn_parked() -> void:
	for place: Dictionary in _parked_places():
		if _parked_plots.size() > 40:
			break
		_parked_plots.append(place)
		var car := Vehicle.create(String(place["model"]),
			_random_colour(place["spec"]), false, false)
		# Qo'yilgan mashina TURGAN — uning g'ildoraklari aylanmaydi,
		# demak statik g'ildorak to'g'ri va kuzov mesh'iga
		# birlashtirilishi mumkin (4 ta chizqich tejiladi).
		# 41 ta qo'yilgan mashina = 164 ta chizqich.
		# Harakatlanuvchi mashinalarda esa g'ildorak Aylanadi —
		# aks holda uzoqdan qaraganda "qotib qolgan" bo'lib ko'rinadi.
		add_child(car)
		car.rotation.y = float(place["yaw"])
		car.global_position = Vector3(
			float(place["pos"].x), float(place["y"]) + 0.02,
			float(place["pos"].y))
		parked.append(car)


## Ko'chalar bo'ylab qo'yish joylari.
func _parked_places() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# 1) Tandirchi ko'chalari — uylar orasidagi kichik ko'chalar
	for street: Dictionary in Tandirchi.streets():
		var points: PackedVector2Array = street["nuqta"]
		var width: float = float(street.get("kenglik", 7.0))
		if points.size() < 2:
			continue
		# Har bir ko'chada bitta mashina — kosiblar ko'chasida esa ikki
		var cars_here: int = 2 if String(street.get("nom", "")) \
			.to_lower().contains("kosiblar") else 1
		for k in cars_here:
			var index: int = int(round(float(_rng.randf())
				* float(points.size() - 1)))
			index = clampi(index, 0, points.size() - 2)
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			var along: float = _rng.randf() * minf(a.distance_to(b), 40.0)
			var direction: Vector2 = (b - a).normalized()
			var right: Vector2 = direction.orthogonal()
			var point: Vector2 = a + direction * along
			# Ko'cha chetiga, devorga yaqin turish
			var offset: float = (width * 0.5 - 1.05) * (1.0 if _rng.randf() > 0.5 else -1.0)
			var spot: Vector2 = point + right * offset
			var spec := _random_spec(RoadNetwork.STREET)
			out.append({
				"model": String(spec["kalit"]), "spec": spec,
				"pos": spot,
				"yaw": rad_to_deg(atan2(-direction.x, -direction.y))
					+ (0.0 if _rng.randf() > 0.5 else 180.0),
				"y": TerrainGen.height_at(spot.x, spot.y),
			})
	# 2) Urganch shahar ko'chalari — yon chetida, har 90 m da
	for i in RoadNetwork.roads().size():
		var road: Dictionary = RoadNetwork.roads()[i]
		if int(road["tur"]) != RoadNetwork.STREET:
			continue
		var length: float = RoadNetwork.road_length(i)
		if length < 60.0:
			continue
		var count: int = int(minf(length / 95.0, 3.0))
		for k in count:
			var along: float = _rng.randf() * length
			var spot2 := RoadNetwork.point_along(i, along, true)
			var point2: Vector2 = spot2["nuqta"]
			var right2: Vector2 = (spot2["yo'nalish"] as Vector2).orthogonal()
			var edge: float = RoadNetwork.HALF_WIDTH[int(road["tur"])] - 1.15
			var side: float = 1.0 if _rng.randf() > 0.4 else -1.0
			var where: Vector2 = point2 + right2 * edge * side
			var spec2 := _random_spec(RoadNetwork.STREET)
			out.append({
				"model": String(spec2["kalit"]), "spec": spec2,
				"pos": where,
				"yaw": rad_to_deg(atan2(
					-(spot2["yo'nalish"] as Vector2).x,
					-(spot2["yo'nalish"] as Vector2).y)),
				"y": float(spot2["y"]),
			})
	return out


func _manage_parked(here: Vector2) -> void:
	for car: Vehicle in parked:
		if not is_instance_valid(car):
			continue
		if Vector2(car.global_position.x, car.global_position.z) \
				.distance_to(here) > 420.0:
			car.visible = false
		else:
			car.visible = true


# ================================================================ JOY TOPISH

## Nuqtaga eng yaqin ko'cha chetidagi bo'sh joy — mashina qo'yish uchun.
##
## DIQQAT: avval Tandirchi ko'chalariga, keyin umumiy yo'l tarmog'iga
## qaraydi. Sababi: o'yinchi Tandirchi mahallasida yashaydi va uning
## mashinasi ko'chada shu yerga qo'yilishi kerak. Umumiy yo'l
## tarmog'idagi kosiblar ko'chasi YO'Q (u 7 m eni — tarmoq uchun
## juda tor).
##
## [param lane] — ko'cha markazidan qancha chetga. 0 = o'rtada
## (sinov uchun), 2,3 = chetda (parklash uchun).
##
## Qaytaradi: {"pos": Vector2, "yaw": float, "nom": String}
static func kerbside_near(point: Vector2, lane: float = 2.3) -> Dictionary:
	var best := INF
	var best_pos := point
	var best_dir := Vector2.RIGHT
	var best_name := ""

	# --- 1) Tandirchi ko'chalari ---
	for street: Dictionary in Tandirchi.streets():
		var points: PackedVector2Array = street["nuqta"]
		var half: float = float(street.get("kenglik", 6.0)) * 0.5
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var ab: Vector2 = b - a
			var length: float = ab.length()
			if length < 0.001:
				continue
			var t: float = clampf((point - a).dot(ab) / length, 0.0, 1.0)
			var projected: Vector2 = a + ab * t
			var distance: float = projected.distance_to(point)
			if distance < best:
				best = distance
				best_pos = projected
				best_dir = ab / length
				best_name = String(street["nom"])

	# --- 2) Umumiy yo'llar (agar mahallada yaqin bo'lmasa) ---
	if best > 45.0:
		var nearest := RoadNetwork.nearest_road_point(point)
		best_pos = nearest["nuqta"]
		best_dir = nearest["yo'nalish"]
		best_name = String(nearest["yo'l"])
		var half_road: float = RoadNetwork.HALF_WIDTH[
			RoadNetwork.STREET] if String(nearest["yo'l"]) != "" else 3.0

	# Ko'cha chetiga (mashina kengligi 1,7 m + oz bo'shliq)
	var right: Vector2 = best_dir.orthogonal()
	var spot: Vector2 = best_pos + right * lane
	return {
		"pos": spot,
		"yaw": rad_to_deg(atan2(-best_dir.x, -best_dir.y)),
		"nom": best_name,
	}


# ================================================================ DIAGNOSTIKA

func moving_count() -> int:
	return cars.size()


func parked_count() -> int:
	return parked.size()


## Sinov uchun: yo'l bo'ylab yurish to'g'rimi.
static func along_check() -> Array[String]:
	var problems: Array[String] = []
	for i in RoadNetwork.roads().size():
		var length: float = RoadNetwork.road_length(i)
		if length < 1.0:
			problems.append("yo'l %d: uzunligi %.1f" % [i, length])
			continue
		for step in [0.0, length * 0.25, length * 0.5, length * 0.75,
				length * 0.999]:
			var spot := RoadNetwork.point_along(i, step)
			var point: Vector2 = spot["nuqta"]
			var direction: Vector2 = spot["yo'nalish"]
			if direction.length() < 0.5:
				problems.append("yo'l %d: yo'nalish yo'q" % i)
			# Nuqta haqiqan yo'lda bo'lishi SHART
			var nearest := RoadNetwork.nearest_road_point(point)
			if float(nearest["masofa"]) > 2.0:
				problems.append("yo'l %d: nuqta yo'ldan %.1f m uzoqda" % [
					i, float(nearest["masofa"])])
			if float(spot["y"]) < -2.0 or float(spot["y"]) > 40.0:
				problems.append("yo'l %d: balandlik %.1f" % [i, float(spot["y"])])
	return problems
