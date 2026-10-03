class_name Tandirchi
extends RefCounted
## Tandirchi mahallasi — ko'chalar va uy joylari (ma'lumot, sizsiz).
##
## Bu sinf hech narsa qurmadi — faqat MA'LUMOT beradi. Qurilish
## BuildingManager orqali, chunk'lar bo'yicha amalga oshiriladi.
##
## NIMA UCHUN PANJARA EMAS
## Xorazmning eski mahallalari (Tandirchi aynan shunday) an'anaviy
## tarzda qurilgan: tor, EGILGAN, o'zaro bog'lanmagan ko'chalar.
## Panjara faqat 1920–1950 yillarda sho'llik shaharlarda qo'llandi.
## Tandirchi — boshqa davrning mahallasi, shuning uchun ko'chalar
## to'g'ri chiziq emas, buriladi va bir-biriga to'g'ri kelmaydi.
##
## MAHALLA O'LCHAMI
## 210 × 160 m. Bu ataylab kichik: o'yinchi biror kun o'tmaydi,
## lekin har bir kvadrat metr haqiqiy o'lchamda. Uylar hech qachon
## kichiklashtirilmaydi — Xorazm xalq uyi 10 × 15 m haqiqiy.

const EXTENT_X := 120.0
const EXTENT_Z := 100.0

## Ko'chalar orasidagi minimal masofa.
##
## NIMA UCHUN: har bir ko'chaning ikki tomonida uylar turadi, ular
## 12–16 m chuqurlikda. Demak bitta ko'cha bandi uchun
##   7 m (ko'cha) + 2 × 14 m (uylar) = 35 m
## kerak. Agar parallel ko'chalar 30 m da tursa, uylar bir-birining
## ustiga tushadi va bo'sh joy qolmaydi (test 111 dan 35 taga
## tushgandek).
const LANE_PITCH := 44.0

## Ko'chalar: {"nuqta": PackedVector2Array, "kenglik": float, "nom": String}
static var _streets: Array[Dictionary] = []
## Uy joylari: {"markaz": Vector2, "yaw": float, "front": float,
##             "chuqur": float, "qavat": int, "uslub": int, "urish": int}
static var _plots: Array[Dictionary] = []
static var _ready := false


static func _ensure() -> void:
	if _ready:
		return
	_build_streets()
	_build_plots()
	_ready = true


static func streets() -> Array[Dictionary]:
	_ensure()
	return _streets


static func plots() -> Array[Dictionary]:
	_ensure()
	return _plots


# ================================================================= KO'CHALAR

## Kosiblar ko'chasi va uning tarmoqlari.
##
## Tuzilishi — "to'r" emas, balki tartibli, lekin egilgan:
##
##      Ustki mavze ─────────────────────  z ≈ −58
##              │            │
##      Yuqori mavze ──────────────────  z ≈ −16
##              │            │
##      Kosiblar ko'chasi ══════════════  z ≈ +24   ← o'yinchi shu yerda
##              │            │
##      Pastki mavze ───────────────────  z ≈ +62
##
##   Qisman o'zaro bog'li (to'liq panjara emas), mavzelar Kosiblar
##   ko'chasiga TUSHIQ holda ulanadi — Xorazmning eski mahallalari
##   shunday quriladi.
##
## O'yinchi shu ko'chada tug'iladi (WorldMap.PLAYER_SPAWN), shuning
## uchun Kosiblar ko'chasining AYNAN shu nuqtadan o'tishi shart —
## qo'lda yozilgan, koordinataning o'zi bilan solishtirilgan.
static func _build_streets() -> void:
	var c: Vector2 = WorldMap.TANDIRCHI
	var spawn: Vector2 = WorldMap.PLAYER_SPAWN

	# Kosiblar o'qi — mahallaning "qon tomiri". Barcha mavzalar unga
	# tushadi. Slight diagonal: Xorazmda ham ko'chalar to'g'ri emas.
	var spine: Array[Vector2] = [
		c + Vector2(-112.0, -40.0),
		spawn,
		c + Vector2(16.0, 18.0),
		c + Vector2(72.0, 40.0),
		c + Vector2(116.0, 52.0),
	]

	_streets = [
		{
			"nom": "Kosiblar ko'chasi",
			"kenglik": 7.0,
			"nuqta": PackedVector2Array(spine),
		},
	]

	# --- Kosiblar GAARDAN parallel mavzelar (ikki tomonda) ---
	# Asosiy o'qning istiqboli (world XZ): taxminan (0,7) → (1,0,18°)
	var along := Vector2(0.94, 0.34)
	var across := along.orthogonal()

	# Shimol tomonda (across ning manfi yo'nalishi)
	for i in 2:
		var offset: float = LANE_PITCH * float(i + 1)
		_streets.append({
			"nom": "Yuqori mavze" if i == 0 else "Ustki mavze",
			"kenglik": 4.6 if i == 0 else 4.2,
			"nuqta": _parallel(spine, -offset, 24.0, 88.0),
		})
	# Janub tomonda
	for i in 1:
		var offset: float = LANE_PITCH * float(i + 1)
		_streets.append({
			"nom": "Pastki mavze",
			"kenglik": 4.6,
			"nuqta": _parallel(spine, offset, 20.0, 92.0),
		})

	# --- Ko'chadan ko'chaga (kesma) mavzalar, ~50 m oraliqda ---
	var crossings: Array[Vector2] = [
		c + Vector2(-72.0, 0.0),
		c + Vector2(-22.0, 0.0),
		c + Vector2(28.0, 0.0),
		c + Vector2(78.0, 0.0),
	]
	for i in crossings.size():
		var at: Vector2 = crossings[i]
		_streets.append({
			"nom": "%d-mavze" % (i + 1),
			"kenglik": 4.4,
			"nuqta": PackedVector2Array([
				at + across * 96.0,
				at - across * 96.0,
			]),
		})


## Asosiy o'qqa parallel, berilgan masofada qisqa ko'cha.
static func _parallel(spine: Array[Vector2], offset: float,
		from_along: float, to_along: float) -> PackedVector2Array:
	var along := Vector2(0.94, 0.34)
	var across := along.orthogonal()
	var a: Vector2 = spine[0] + along * from_along + across * offset
	var b: Vector2 = spine[0] + along * to_along + across * offset
	return PackedVector2Array([a, a.lerp(b, 0.5), b])


# ================================================================= JOYLASH

## Ko'chalar bo'ylab uy joylari joylashtiradi.
##
## Har bir joy: ko'cha bo'ylab `front` (8–15 m), ichkariga `chuqur`
## (12–17 m). Odatda Xorazmda uylar ko'chaga devor bilan tegadi va
## 2 qavatli bo'ladi.
static func _build_plots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Settings.WORLD_SEED + 4211

	# DIQQAT tartibi: avval O'YINCHI uyi joyi band qilinadi, keyin
	# qo'shnilar. Aks holda tasodifiy uy o'yinchi uyining ustiga
	# tushib qolishi mumkin.
	_player_plot()

	for street: Dictionary in _streets:
		var points: PackedVector2Array = street["nuqta"]
		var width: float = street["kenglik"]

		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var direction: Vector2 = b - a
			var length: float = direction.length()
			if length < 6.0:
				continue
			var normal: Vector2 = direction.orthogonal().normalized()

			for side in 2:
				var sign_f: float = -1.0 if side == 0 else 1.0
				var offset: float = width * 0.5
				var walked := rng.randf_range(0.0, 3.0)

				while walked < length - 9.0:
					var front: float = rng.randf_range(9.5, 14.5)
					var depth: float = rng.randf_range(11.5, 15.5)
					var mid: Vector2 = a + direction.normalized() * (walked + front * 0.5)
					# Uy markazi ko'chadan `offset + depth/2` masofada
					var centre: Vector2 = mid + normal * sign_f * (offset + depth * 0.5)

					# Uy ko'chaga shu tomon bilan qaraydi
					var facing: Vector2 = -normal * sign_f
					var facing_yaw: float = atan2(facing.x, facing.y)
					if _is_free(centre, facing_yaw, front, depth):
						_plots.append({
							"markaz": centre,
							"yaw": facing_yaw,
							"front": front,
							"chuqur": depth,
							"qavat": 2 if rng.randf() < 0.72 else 1,
							"uslub": _pick_style(rng),
							"urish": int((walked + front * 0.5) * 10.0) + i * 1000
								+ side * 100000,
						})

					walked += front + rng.randf_range(0.0, 1.2)


## Ikki joy ustma-ust tushmasligini tekshiradi (2D SAT).
##
## DIQQAT: oldin radius bo'yicha tekshirilgan edi. Bu XATO: qo'shni
## joylar ko'chaning IKKALA tomonida turadi va markazlari 20+ m
## masofada bo'lsa ham, radius 13 m chiqib ketardi va bir qator uy
## yo'qolib qolardi. To'g'ri usul — to'g'ri to'rtburchaklarning
## kesishishini aniq tekshirish.
static func _is_free(centre: Vector2, yaw: float, front: float,
		depth: float) -> bool:
	# 30 sm qisqartiriladi: Xorazmda uylar ko'pincha devor bo'lib
	# tutashadi, ya'ni ular orasida kichik bo'shliq bo'ladi.
	const GAP := 0.3
	var half_w: float = front * 0.5 - GAP
	var half_d: float = depth * 0.5 - GAP
	var mine_u: Vector2 = Vector2(sin(yaw), cos(yaw))
	var mine_v: Vector2 = mine_u.orthogonal()

	for plot: Dictionary in _plots:
		var other: Vector2 = plot["markaz"]
		var other_yaw: float = plot["yaw"]
		var their_u: Vector2 = Vector2(sin(other_yaw), cos(other_yaw))
		var their_v: Vector2 = their_u.orthogonal()
		var other_half_w: float = float(plot["front"]) * 0.5
		var other_half_d: float = float(plot["chuqur"]) * 0.5

		# To'rtta o'q: ikkala to'rtburchakning o'q bo'ylab yo'nalishlari.
		#
		# DIQQAT: `break` SHART. Avval sikl ichida `return` yozilgan edi —
		# u faqat BIRINCHI o'qni tekshirib, butun funksiyani chiqarib
		# ketardi. Natijada 111 joydan 275 juftlik ustma-ust tushib
		# qolgan edi (turli ko'chalardagi uylar ko'cha burchagida
		# to'qnashadi).
		var separated := false
		for axis: Vector2 in [mine_u, mine_v, their_u, their_v]:
			var delta: Vector2 = other - centre
			var gap: float = absf(delta.dot(axis))
			var reach: float = half_w * absf(mine_u.dot(axis)) \
				+ half_d * absf(mine_v.dot(axis)) \
				+ other_half_w * absf(their_u.dot(axis)) \
				+ other_half_d * absf(their_v.dot(axis))
			if gap >= reach:
				separated = true
				break
		if not separated:
			return false            # shu joy bilan kesishadi
	return true


static func _pick_style(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if roll < 0.58:
		return CourtyardHouse.Style.MODERN      # g'isht + suvaloq
	elif roll < 0.85:
		return CourtyardHouse.Style.HALF        # g'isht, suvaloq yo'q
	return CourtyardHouse.Style.OLD_SAMAN     # eski, saman


## O'yinchi uyining joyi.
##
## DIQQAT: bu qo'lda yozilgan emas — Kosiblar ko'chasidan chiqarib
## olinadi. Aks holda ko'cha ko'chirilsa, uy ko'chadan ajralib qoladi
## (3-bosqichda shunday xato yo'l hollari yo'lni chetlab o'tish
## tufayli bo'lgan edi).
static func _player_plot() -> void:
	var spawn: Vector2 = WorldMap.PLAYER_SPAWN
	var front: float = 12.0
	var depth: float = 15.0

	# Kosiblar ko'chasida eng yaqin nuqtani topamiz
	var street: Dictionary = _streets[0]
	var points: PackedVector2Array = street["nuqta"]
	var best := points[0]
	var best_direction := Vector2(1, 0)
	var best_distance := INF

	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var ab: Vector2 = b - a
		var length_sq: float = ab.length_squared()
		if length_sq < 0.0001:
			continue
		var t: float = clampf((spawn - a).dot(ab) / length_sq, 0.0, 1.0)
		var projected: Vector2 = a + ab * t
		var d: float = projected.distance_squared_to(spawn)
		if d < best_distance:
			best_distance = d
			best = projected
			best_direction = ab.normalized()

	# Uy ko'chadan keyinga qaragan tomonda turadi
	var side: Vector2 = best_direction.orthogonal()
	var centre: Vector2 = best + side * (float(street["kenglik"]) * 0.5 + depth * 0.5)
	var facing: Vector2 = -side

	_plots.append({
		"markaz": centre,
		"yaw": atan2(facing.x, facing.y),
		"front": front,
		"chuqur": depth,
		"qavat": 2,
		"uslub": CourtyardHouse.Style.MODERN,
		"urish": 999999,
		"o'yinchi": true,
	})


# ================================================================= So'rovlar

## O'yinchi uyining joyi (yoki null).
static func player_plot() -> Dictionary:
	_ensure()
	for plot: Dictionary in _plots:
		if plot.get("o'yinchi", false):
			return plot
	return {}


## Berilgan nuqtaga eng yaqin joy.
static func plot_near(point: Vector2) -> Dictionary:
	_ensure()
	var best: Dictionary = {}
	var best_distance := INF
	for plot: Dictionary in _plots:
		var d: float = point.distance_squared_to(plot["markaz"])
		if d < best_distance:
			best_distance = d
			best = plot
	return best


## Mahallaning chegarasi (chunk bo'ylab saralash uchun).
static func bounds() -> Rect2:
	_ensure()
	var centre: Vector2 = WorldMap.TANDIRCHI
	return Rect2(
		centre - Vector2(EXTENT_X + 24.0, EXTENT_Z + 24.0),
		Vector2((EXTENT_X + 24.0) * 2.0, (EXTENT_Z + 24.0) * 2.0))