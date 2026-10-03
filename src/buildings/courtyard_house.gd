class_name CourtyardHouse
extends RefCounted
## Xorazm xalq uyi — ichki hovli (bog') bilan.
##
## XARITASI (mahalliy koordinatalar: u = ko'cha bo'ylab, v = uy ichiga)
##
##      ko'cha  ═══════════════════════════════════════════════
##   v=0  │ devor (ko'chaga qaragan, derazasiz, baland)       │
##        │        ╔═══╗                                     │
##        │        ║ eshik║  peshenta (taborxona), 2,6 m      │
##   v=2,6│  ──────╚═══╝─────────────────────                 │
##        │   HOVLI: anor, tandir (non o'chog'i)             │
##        │                                                    │
##   v=D−5│  ┌──────────────┬──────────────┐  ← xonalar       │
##        │  │ xona         │ xona         │    (hovliga      │
##        │  │ eshik+oyna   │ eshik+oyna   │     derazali)    │
##   v=D  │  └──────────────┴──────────────┘                  │
##        └───────────────────────────────────────────────────
##            u=−W/2                                  u=+W/2
##
## O'LCHAMLAR — haqiqiy, 1:1 (hech narsa kichiklashtirilmagan)
##   Ko'cha devori 2,45 m · Birinchi qavat 3,05 m
##   Ikkinchi qavat 2,85 m · Darvoza 2,15 m · Tarona Ø 0,30 m
##
## NIMA UCHUN BU SHAKL
## Xorazm — issiq cho'lli. Devor qalin (0,34 m) va shift TEKIS —
## yozda ham, qishda ham yaxshi. Derazalar HOVLIGA qaraydi, ko'chaga
## emas: shaharda begona uyni ko'rishdan himoya qilinadi va ichkarida
## salqin saqlanadi. Shu sababli tashqi devor butunlay TEKIS — bu
## Xorazm ko'chalarining eng ko'zga tashlanadigan belgisi.

enum Style { MODERN, OLD_SAMAN, HALF }

## Eshiklarni chizish kerakmi? O'yinchi uyida haqiqiy, ochiladigan
## eshiklar qo'yiladi (`HouseDoor`) — ular ko'p geometriya talab qiladi,
## shuning uchun statik chizilgan eshik kerak emas.
static var _doors := true

## Shimbani va uning ustidagi devorni chizmaslik. Faqat `--inspect`
## (shimola qaraganda) uchun — mebel joylashuvini bir qarashda
## ko'rish kerak.
static var _skip_roof := false

const MIN_FRONT := 9.5
const MAX_FRONT := 15.5
const MIN_DEPTH := 12.5
const MAX_DEPTH := 17.5
const PORCH_DEPTH := 2.6
const ROOM_DEPTH := 5.2


## Bir uyni quradi.
##
## [param builder]   — umumiy mesh yig'uvchi (barcha uylar bitta mesh)
## [param centre]    — uy markazi, XZ
## [param yaw]       — uy qaysi tomonga qarashi (radian)
## [param front]     — ko'cha bo'ylab kengligi (m)
## [param depth]     — ko'chadan uy orqasigacha (m)
## [param storeys]   — 1 yoki 2
## [param rng]       — tasodifiy manba
static func build(builder: MeshBuilder, centre: Vector2, yaw: float,
		front: float, depth: float, storeys: int,
		rng: RandomNumberGenerator, style: int = Style.MODERN,
		decorative_doors: bool = true, skip_roof: bool = false) -> Dictionary:
	var ground: float = TerrainGen.height_at(centre.x, centre.y)
	var basis := Basis(Vector3.UP, yaw)
	_doors = decorative_doors
	_skip_roof = skip_roof
	# DIQQAT: bu funksiya ichida `v = 0` — KO'CHA CHEGARASI (uyning
	# old devori). `centre` esa — BIR MAYDONNING O'RTASI. Shu sababli
	# boshlang'ich nuqtani yarim chuqurlikka orqaga suramiz. Aks holda
	# uy ko'chadan `depth` metr uzoqlashib, ko'chada bo'sh joy qolardi.
	var origin := Vector3(centre.x, ground, centre.y) \
		+ basis * Vector3(0.0, 0.0, -depth * 0.5)

	var wall := _wall_colour(style)
	var coping: Color = Palette.SAMAN_DARK if style == Style.OLD_SAMAN \
		else Palette.CONCRETE
	var roof: Color = Palette.SAMAN_DARK if style == Style.OLD_SAMAN \
		else Palette.ROOF_DECK

	var half: float = front * 0.5
	var t: float = BuildingKit.WALL_THICKNESS
	var ceiling: float = BuildingKit.CEILING
	var top: float = ground + ceiling + (BuildingKit.SECOND_FLOOR if storeys >= 2 else 0.0)

	# Darvoza ko'chada emas, chetga surilgan — Xorazmning an'anasi.
	# Bu xona ichini ko'chadan ko'rishni ham berkitadi.
	var gate_u: float = half * rng.randf_range(-0.62, -0.30)
	var gate_w: float = 2.15

	# ================================================= 1. KO'CHA BO'YI DEVORI
	var gate_left: float = gate_u - gate_w * 0.5
	var gate_right: float = gate_u + gate_w * 0.5
	_street_wall(builder, origin, basis, -half, gate_left, ground, wall, coping)
	_street_wall(builder, origin, basis, gate_right, half, ground, wall, coping)

	# ================================================= 2. YON DEVOLAR
	# Ko'chadan uy orqasigacha — ko'zga to'sqinlik qiladi.
	for side in 2:
		var u: float = -half if side == 0 else half
		var a: Vector2 = _p(origin, basis, u, 0.0)
		var b: Vector2 = _p(origin, basis, u, depth)
		BuildingKit.wall_with_coping(builder, a, b, ground, top - ground,
			BuildingKit.WALL_THICKNESS, wall, coping)

	# ================================================= 3. PESHTENTA (TABORXONA)
	_porch(builder, origin, basis, gate_u, gate_w, ground, wall, coping)

	# ================================================= 4. XONALAR BLOKI
	var room_v0: float = depth - ROOM_DEPTH
	_rooms(builder, origin, basis, -half, half, room_v0, depth,
		ground, top, storeys, rng)

	# ================================================= 5. HOVLI
	var courtyard_mid: float = (PORCH_DEPTH + room_v0) * 0.5
	var anor_at: Vector3 = _w(origin, basis,
		rng.randf_range(-half * 0.45, half * 0.45), courtyard_mid, ground)
	TreeKit.build(builder, anor_at, TreeKit.Kind.ANOR, rng,
		rng.randf_range(0.9, 1.2))

	# Tandir — non yopish o'chog'i, Xorazm hovlisining belgisi
	var tandir_at: Vector3 = _w(origin, basis,
		half - 1.7, courtyard_mid - 1.1, ground)
	_tandyr(builder, tandir_at)

	# DIQQAT: bu nuqtalarni qaytaramiz. Uchinchidan tashqari bino
	# yig'iladi va keyin kerak bo'lmaydi — lekin o'yinchi uyi uchun
	# JUCHTA JOY muhim: eshiklar shu yerda turadi. Ular qaytarilmasa,
	# eshikni aniq joyga qo'yib bo'lmaydi (ko'chadan ichkariga
	# qaragan tomon boshqacha chiqadi).
	return {
		"darvoza": _w(origin, basis, gate_u, 0.0, ground),
		"peshenta_eshigi": _w(origin, basis, gate_u, PORCH_DEPTH, ground),
		"xona_eshigi": _w(origin, basis, 0.0, room_v0, ground),
		"hovli": _w(origin, basis, 0.0, courtyard_mid, ground),
		"burchak": yaw,
		"old": basis * Vector3(0, 0, 1),
		"yon": basis * Vector3(1, 0, 0),
		"kenglik": front,
		"chuqur": depth,
	}


# ------------------------------------------------------------------ Bo'laklar

## Ko'cha bo'yidagi baland devor — derazasiz.
static func _street_wall(builder: MeshBuilder, origin: Vector3, basis: Basis,
		u0: float, u1: float, ground: float, wall: Color,
		coping: Color) -> void:
	if u1 - u0 < 0.3:
		return
	var a: Vector2 = _p(origin, basis, u0, 0.0)
	var b: Vector2 = _p(origin, basis, u1, 0.0)
	BuildingKit.wall_with_coping(builder, a, b, ground,
		BuildingKit.STREET_WALL_HEIGHT, BuildingKit.WALL_THICKNESS,
		wall, coping)


## Peshenta: yon devorlar, yopiq shift va chuqurdagi og'ir eshik.
static func _porch(builder: MeshBuilder, origin: Vector3, basis: Basis,
		gate_u: float, gate_w: float, ground: float, wall: Color,
		coping: Color) -> void:
	var height: float = BuildingKit.GATE_HEIGHT + 0.45
	var half_gate: float = gate_w * 0.5

	# Ikki yon devor — peshenta ichiga parallel
	for side in 2:
		var u: float = gate_u - half_gate - 0.16 if side == 0 \
			else gate_u + half_gate + 0.16
		var a: Vector2 = _p(origin, basis, u, BuildingKit.WALL_THICKNESS * 0.5)
		var b: Vector2 = _p(origin, basis, u, PORCH_DEPTH)
		builder.add_wall(a, b, ground, height, 0.22, wall)

	# Peshenta shifti
	var r0: Vector2 = _p(origin, basis,
		gate_u - half_gate - 0.32, 0.0)
	var r1: Vector2 = _p(origin, basis,
		gate_u + half_gate + 0.32, PORCH_DEPTH)
	builder.add_plate(r0, r1, ground + height, 0.20, Palette.ROOF_DECK, false)
	# Shift ustida peshenta devori (kirishni yopmaydi, balandlik uchun)
	_paint_line(builder, origin, basis, r0, r1, ground + height + 0.20,
		0.30, coping)

	# Eshik — peshenta oxirida, hovliga qaragan
	if _doors:
		var door_at: Vector3 = _w(origin, basis, gate_u, PORCH_DEPTH - 0.14,
			ground + BuildingKit.DOOR_HEIGHT * 0.5)
		BuildingKit.plank_door(builder, door_at, gate_w * 0.86,
			BuildingKit.DOOR_HEIGHT, rad_to_deg(basis.get_euler().y) + PI)

	# Peshenta yon devorlariga ravoq
	for side in 2:
		var u: float = gate_u - half_gate - 0.16 if side == 0 \
			else gate_u + half_gate + 0.16
		var at: Vector3 = _w(origin, basis, u - 0.13 if side == 1 else u + 0.13,
			PORCH_DEPTH * 0.55, ground + 1.35)
		BuildingKit.niche(builder, at, 0.44, 0.56,
			rad_to_deg(basis.get_euler().y) + (0.0 if side == 1 else PI))


## Xonalar bloki: hovliga qaragan devorda eshik + derazalar.
static func _rooms(builder: MeshBuilder, origin: Vector3, basis: Basis,
		u0: float, u1: float, v0: float, v1: float, ground: float,
		top: float, storeys: int, rng: RandomNumberGenerator) -> void:
	# DIQQAT: uslubni BIR marta aniqlaymiz. `_style_of` rng ni
	# surishtiradi — ikki marta chaqirsak, devor va shift boshqa
	# uslubni olib, uy chalkash ko'rinadi.
	var wall := _wall_colour(_style_of(rng))
	var roof: Color = Palette.SAMAN_DARK if _style_of(rng) == Style.OLD_SAMAN \
		else Palette.ROOF_DECK
	var length: float = u1 - u0
	var t := BuildingKit.WALL_THICKNESS
	var centre_u: float = (u0 + u1) * 0.5

	# Orqa devor (panjarasiz, ko'chadan ko'rinmaydi)
	var back_a: Vector2 = _p(origin, basis, u0, v1)
	var back_b: Vector2 = _p(origin, basis, u1, v1)
	builder.add_wall(back_a, back_b, ground, top - ground, t, wall)

	# Hovliga qaragan devor — ikki qismga bo'lib, orasida eshik bo'ladi
	var door_w: float = 1.15
	var left_a: Vector2 = _p(origin, basis, u0, v0)
	var left_b: Vector2 = _p(origin, basis, centre_u - door_w * 0.5, v0)
	var right_a: Vector2 = _p(origin, basis, centre_u + door_w * 0.5, v0)
	var right_b: Vector2 = _p(origin, basis, u1, v0)
	builder.add_wall(left_a, left_b, ground, top - ground, t, wall)
	builder.add_wall(right_a, right_b, ground, top - ground, t, wall)
	# Eshik ustidagi pereklad
	var lintel_a: Vector2 = _p(origin, basis, centre_u - door_w * 0.5, v0)
	var lintel_b: Vector2 = _p(origin, basis, centre_u + door_w * 0.5, v0)
	builder.add_wall(lintel_a, lintel_b, ground + BuildingKit.DOOR_HEIGHT,
		top - ground - BuildingKit.DOOR_HEIGHT, t, wall)

	# Yon devorlar
	for side in 2:
		var u: float = u0 + t * 0.5 if side == 0 else u1 - t * 0.5
		var a: Vector2 = _p(origin, basis, u, v0)
		var b: Vector2 = _p(origin, basis, u, v1)
		builder.add_wall(a, b, ground, top - ground, t, wall, false)

	# Eshik
	if _doors:
		var door_at: Vector3 = _w(origin, basis, centre_u, v0 - t * 0.5,
			ground + BuildingKit.DOOR_HEIGHT * 0.5)
		BuildingKit.plank_door(builder, door_at, door_w * 0.95,
			BuildingKit.DOOR_HEIGHT, rad_to_deg(basis.get_euler().y))

	# Birinchi qavat derazalari
	var facade_yaw: float = rad_to_deg(basis.get_euler().y) + PI
	var windows: int = clampi(int((length - door_w) / 3.6), 1, 4)
	for i in windows:
		var u: float = lerpf(u0 + 1.3, u1 - 1.3,
			(float(i) + 0.5) / float(windows))
		if absf(u - centre_u) < 1.4:
			continue                      # eshik oldidan o'tkazib yubormaymiz
		BuildingKit.lattice_window(builder,
			_w(origin, basis, u, v0 - t * 0.5 - 0.02,
				ground + BuildingKit.CEILING * 0.62),
			1.05, 1.15, facade_yaw)

	# Ikkinchi qayat: ayvon + derazalar
	if storeys >= 2:
		var ayvon_y: float = ground + BuildingKit.CEILING
		var columns: int = clampi(int(length / 2.8), 2, 6)
		for i in columns:
			var u: float = lerpf(u0 + 0.9, u1 - 0.9,
				(float(i) + 0.5) / float(columns))
			# DIQQAT: ustun YERDAN boshlanadi. `ayvon_y` dan
			# boshlansa, ustun havoda "turib" qoladi — chunki u
			# ayvon shiftining OSTIDA bo'lishi kerak.
			BuildingKit.tarona(builder,
				_w(origin, basis, u, v0 - 1.25, ground),
				BuildingKit.CEILING - 0.25, 0.14)
		# Ayvon shifti
		var g0: Vector2 = _p(origin, basis, u0, v0 - 1.55)
		var g1: Vector2 = _p(origin, basis, u1, v0)
		builder.add_plate(g0, g1, ayvon_y - 0.05, 0.22, Palette.ROOF_DECK,
			false)
		# Nopiya — AQVON shiftining chetida. Xorazmda aynan shu yerga
		# taronalar chiqadi: ular ko'chadan ko'rinadi va uyga o'z
		# uslubini beradi. Boshqa joyga (masalan asosiy shift ostiga)
		# qo'yilsa, devor ustida "parvoz qilayotgan taxtalar" paydo
		# bo'ladi — ko'chadan havoda suzib qoladi.
		# DIQQAT: nopiyalar AQVONNING TASHQI chehrasi bo'ylab teriladi,
		# ya'ni (u0, v0−1,55) → (u1, v0−1,55). Agar (u1, v0) ishlatilsa,
		# chiziq diagonal bo'lib, taronalar chetga yotib qoladi va ko'chadan
		# "tarqoq taxtalar" ko'rinadi.
		var e0: Vector2 = _p(origin, basis, u0, v0 - 1.55)
		var e1: Vector2 = _p(origin, basis, u1, v0 - 1.55)
		BuildingKit.eave_beams(builder, e0, e1, ayvon_y - 0.34,
			maxi(4, int((u1 - u0) / 0.62)))

		var upper: int = clampi(int(length / 3.4), 1, 4)
		for i in upper:
			var u: float = lerpf(u0 + 1.4, u1 - 1.4,
				(float(i) + 0.5) / float(upper))
			BuildingKit.lattice_window(builder,
				_w(origin, basis, u, v0 - t * 0.5 - 0.02,
					ayvon_y + BuildingKit.SECOND_FLOOR * 0.56),
				1.05, 1.05, facade_yaw)

	# Shift
	var r0: Vector2 = _p(origin, basis, u0, v0)
	var r1: Vector2 = _p(origin, basis, u1, v1)
	if not _skip_roof:
		BuildingKit.flat_roof(builder, r0, r1, top + 0.12, roof)
	# Nopiya — shift PLITASINING ostida, 20 sm pastda. Ustida bo'lsa,
	# taronalar shifit ustidan chiqib, uyga "qalin taxta halqa" beradi.
	BuildingKit.eave_beams(builder, r0, r1, top - 0.32,
		maxi(3, int((u1 - u0) / 0.95)))


## Non yopish o'chog'i. Xorazm hovlisida doim bor.
static func _tandyr(builder: MeshBuilder, at: Vector3) -> void:
	builder.add_cylinder(at, at + Vector3(0, 0.82, 0), 0.58, 10,
		Palette.SAMAN_DARK, false)
	builder.add_cylinder(at + Vector3(0, 0.80, 0), at + Vector3(0, 0.88, 0),
		0.48, 10, Color("2e251c"), false)


# ------------------------------------------------------------------ Yordam

## Mahalliy koordinata (u = ko'cha bo'ylab, v = uy ichiga) → dunyo.
##
## DIQQAT: `y` — MUTLAQ balandlik (yer ustidagi), nisbiy emas.
## `origin.y` allaqachon yer balandligi teng bo'lgani uchun, agar yana
## `ground` qo'shilsa, natija 2 × balandlik bo'lib qolardi — barcha
## mebel, daraxt va eshik havoda suzib yotgan bo'lardi. Shuning uchun
## offset `y - origin.y` qilinadi.
static func _w(origin: Vector3, basis: Basis, u: float, v: float,
		y: float) -> Vector3:
	return origin + basis * Vector3(u, y - origin.y, v)


## XZ nuqtasi (mahalliy koordinatalardan).
static func _p(origin: Vector3, basis: Basis, u: float, v: float) -> Vector2:
	var world: Vector3 = origin + basis * Vector3(u, 0.0, v)
	return Vector2(world.x, world.z)


## Ikki nuqta orasiga yupqa devor (shift ustidagi kichik to'siq).
static func _paint_line(builder: MeshBuilder, origin: Vector3, basis: Basis,
		a: Vector2, b: Vector2, y: float, height: float, colour: Color) -> void:
	builder.add_wall(a, b, y, height, 0.16, colour)


static func _wall_colour(style: int) -> Color:
	match style:
		Style.OLD_SAMAN:
			return Palette.SAMAN
		Style.HALF:
			return Palette.BRICK_NEW
		_:
			return Palette.PLASTER_NEW


## Uslubni qayta aniqlash — har chaqirganda bir xil chiqishi uchun
## rng holatiga bog'liq emas, faqat uyning o'z qo'yidan.
static func _style_of(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if roll < 0.62:
		return Style.MODERN
	elif roll < 0.88:
		return Style.HALF
	return Style.OLD_SAMAN