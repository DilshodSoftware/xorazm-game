class_name PlayerHouse
extends RefCounted
## O'yinchi uyi — Tandirchi, Kosiblar ko'chasi.
##
## Bu oddiy generator emas: bu SHU OYNING UCHI. U ichkariga kiriladi,
## yuriladi, o'tiriladi. Shuning uchun bu yerda:
##   * eshiklar ochiladi (E tugmasi)
##   * xona yorug'lik oladi (chiroq)
##   * mebeller haqiqiy o'lchamda va joylashuvi mantiqiy
##
## XONA TUZILISHI
##   1. Peshenta (taborxona) — ko'chadan hovliga o'tadigan yopiq
##      o'ttizish. Eshik shu yerda.
##   2. Hovli — osmon ochiq, anor, tandir, idish to'plash.
##   3. Katta xona (mehr) — oila yig'iladigan asosiy xona:
##      to'ragan, samovar, g'ilam, mayda, televizor, kitob javoni.
##   4. Oshxona — o'choq, muzlatgich, non taxtasi, laganda.
##   5. Yotqona — karavot, shkaf.
##
## Ikki qavat: pastki xona va ustki xona (ayvon orqali). Ustki
## qavatga tashqi zinapoya orqali chiqiladi — Xorazmda ham ichki
## zinapoya kamdan-kam uchraydi.

## Uyni quradi va `root` ga joylaydi (tugun, chiroq, eshiklar).
static func build(root: Node3D, inspect: bool = false) -> Dictionary:
	var plot := Tandirchi.player_plot()
	if plot.is_empty():
		return {}

	var builder := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = Settings.WORLD_SEED + 991
	var info := build_geometry(builder, plot, rng, inspect)

	var centre: Vector2 = plot["markaz"]
	var yaw: float = plot["yaw"]
	var front: float = plot["front"]
	var depth: float = plot["chuqur"]
	var ground: float = TerrainGen.height_at(centre.x, centre.y)
	var basis := Basis(Vector3.UP, yaw)
	var origin: Vector3 = Vector3(centre.x, ground, centre.y) \
		+ basis * Vector3(0.0, 0.0, -depth * 0.5)
	var room_v0: float = depth - CourtyardHouse.ROOM_DEPTH

	var house := Node3D.new()
	house.name = "O'yinchiUyi"
	root.add_child(house)
	builder.commit(house, "Mesh")
	builder.commit_collision(house, "Kolpasi")

	var lights := _build_lights(root, origin, basis, front, room_v0, depth, ground)
	var doors := _build_doors(house, info["shell"], origin, basis)

	info["tugun"] = house
	info["yorug'lik"] = lights
	info["eshiklar"] = doors
	return info


## Faqat GEOMETRIYA quradi (sahna tuguni qo'shmaydi). Testlar ham,
## `build` ham shundan foydalanadi.
static func build_geometry(builder: MeshBuilder, plot: Dictionary,
		rng: RandomNumberGenerator, inspect: bool = false) -> Dictionary:
	var centre: Vector2 = plot["markaz"]
	var yaw: float = plot["yaw"]
	var front: float = plot["front"]
	var depth: float = plot["chuqur"]

	builder.want_collision = true

	var ground: float = TerrainGen.height_at(centre.x, centre.y)
	var basis := Basis(Vector3.UP, yaw)
	var origin: Vector3 = Vector3(centre.x, ground, centre.y) \
		+ basis * Vector3(0.0, 0.0, -depth * 0.5)

	# Bino qobiqasi — xuddi boshqa uylar kabi (shunda ko'chadan
	# ko'rinishi barcha uyga o'xshash bo'ladi). Statik eshiklar
	# chizilmaydi: pastda haqiqiy, ochiladigan eshiklar qo'yiladi.
	var shell := CourtyardHouse.build(builder, centre, yaw, front, depth, 2,
		rng, CourtyardHouse.Style.MODERN, false, inspect)

	# Xonalar bloki ichidagi joylar (mahalliy koordinatalar)
	var room_v0: float = depth - CourtyardHouse.ROOM_DEPTH
	var ceiling: float = BuildingKit.CEILING

	# --- Ichki devor: katta xona va oshxona ajratiladi ---
	# Xona 5,2 m chuqurlikda; uni ikki qismga bo'lamiz
	var split: float = -front * 0.18
	_split_wall(builder, origin, basis, split, room_v0, room_v0 + 2.4, ground,
		ceiling)

	# --- Xona poli ---
	# DIQQAT: pol shart. Terrassi (sho'r qum) xona ichida to'g'ri
	# ko'rinmaydi va pol chang bo'lib choyqadi. Xorazmda pol g'isht
	# yoki suvaloq bilan qoplanadi.
	var pf0: Vector2 = _p2(origin, basis, -front, room_v0)
	var pf1: Vector2 = _p2(origin, basis, front, depth)
	builder.add_plate(pf0, pf1, ground + 0.06, 0.10, Color("bfa882"), true)

	# --- Birinchi qavat shifti (ikkinchi qavat ostida) ---
	var f0: Vector2 = _p2(origin, basis, -front, room_v0)
	var f1: Vector2 = _p2(origin, basis, front, depth)
	builder.add_plate(f0, f1, ground + ceiling, 0.20, Palette.ROOF_DECK, false)

	# ================================================================= KATTA XONA
	# To'ragan — hovliga qaragan devor yonida (derazaning ostida)
	FurnitureKit.toragan(builder,
		_at(origin, basis, front * 0.34, room_v0 + 0.36, ground),
		rad_to_deg(yaw) + PI)
	FurnitureKit.stol(builder,
		_at(origin, basis, front * 0.30, room_v0 + 2.6, ground), yaw)
	FurnitureKit.stools(builder,
		_at(origin, basis, front * 0.30, room_v0 + 1.9, ground), yaw, 3)
	FurnitureKit.khalta(builder,
		_at(origin, basis, front * 0.28, room_v0 + 2.5, ground), yaw, false)
	FurnitureKit.khalta(builder,
		_at(origin, basis, -front * 0.32, room_v0 + 0.2, ground + 1.15),
		rad_to_deg(yaw) + PI, true)
	FurnitureKit.mayda(builder,
		_at(origin, basis, -front * 0.44, room_v0 + 0.55, ground), yaw)
	FurnitureKit.javon(builder,
		_at(origin, basis, -front * 0.46, room_v0 + 1.35, ground), yaw, true)
	FurnitureKit.televizor(builder,
		_at(origin, basis, -front * 0.42, room_v0 + 0.30, ground),
		rad_to_deg(yaw) + PI)
	FurnitureKit.laganda(builder,
		_at(origin, basis, front * 0.10, room_v0 + 0.14, ground),
		rad_to_deg(yaw) + PI)

	# ================================================================= OSHXONA
	var kitchen := _at(origin, basis, -front * 0.30, room_v0 + 1.4, ground)
	FurnitureKit.ochoq(builder,
		_at(origin, basis, -front * 0.36, room_v0 + 0.44, ground), yaw)
	FurnitureKit.muzlatgich(builder,
		_at(origin, basis, -front * 0.04, room_v0 + 0.42, ground),
		rad_to_deg(yaw) + PI)
	FurnitureKit.non_taxtasi(builder,
		_at(origin, basis, -front * 0.34, room_v0 + 1.5, ground), yaw)

	# ================================================================= YOTQONA
	FurnitureKit.karavot(builder,
		_at(origin, basis, -front * 0.34, room_v0 + 1.5, ground),
		rad_to_deg(yaw) + PI)
	FurnitureKit.shkaf(builder,
		_at(origin, basis, -front * 0.44, room_v0 + 3.1, ground), yaw)

	# ================================================================= ICHKI ZINAPOYA
	_stairs(builder, origin, basis, front, room_v0, ground, ceiling)

	# ================================================================= TAVAN
	if not inspect:
		_tavan(builder, origin, basis, front, room_v0, depth, ground, ceiling)

	return {
	 "shell": shell,
	 "markaz": centre,
	 "farq": yaw,
	 "chegaralar": Rect2(
		Vector2(centre.x - front, centre.y - depth),
		Vector2(front * 2.0, depth * 2.0)),
	 "ichki": Vector3(centre.x, ground, centre.y),
	}


# ------------------------------------------------------------------ Eshiklar

## Ikkita haqiqiy eshik: ko'chadan peshentaga va peshentadan katta
## xonaga. Ikkalasi ham E tugmasi bilan ochiladi.
static func _build_doors(house: Node3D, shell: Dictionary, origin: Vector3,
		basis: Basis) -> Array[HouseDoor]:
	var doors: Array[HouseDoor] = []
	var inside: Vector3 = basis * Vector3(0, 0, 1)     # uy ichiga qaragan
	var across: Vector3 = basis * Vector3(1, 0, 0)

	# 1) Peshtenadagi eshik — uy ichiga ochiladi
	var gate: Vector3 = shell["peshenta_eshigi"]
	doors.append(HouseDoor.create(
		house, gate + Vector3(-1.05, 0, 0),
		atan2(inside.x, inside.z), 2.1, BuildingKit.DOOR_HEIGHT))

	# 2) Katta xona eshigi — hovliga qaragan
	var room: Vector3 = shell["xona_eshigi"]
	doors.append(HouseDoor.create(
		house, room + Vector3(-0.58, 0, 0),
		atan2(-inside.x, -inside.z), 1.16, BuildingKit.DOOR_HEIGHT))

	return doors


# ------------------------------------------------------------------ Bo'laklar

## Katta xona va oshxona orasidagi ichki devor.
static func _split_wall(builder: MeshBuilder, origin: Vector3, basis: Basis,
		u: float, v0: float, v1: float, ground: float, height: float) -> void:
	var a: Vector2 = _p2(origin, basis, u, v0)
	var b: Vector2 = _p2(origin, basis, u, v1)
	builder.add_wall(a, b, ground, height, 0.14, Palette.PLASTER_NEW)


## Shift — ikkinchi qavat ostidagi to'sh. Yorug'lik uchun muhim:
## shift bo'lmasa, xona quyosh tegmaydi va qorong'i bo'lib qoladi.
static func _tavan(builder: MeshBuilder, origin: Vector3, basis: Basis,
		front: float, v0: float, v1: float, ground: float,
		height: float) -> void:
	var a: Vector2 = _p2(origin, basis, -front, v0)
	var b: Vector2 = _p2(origin, basis, front, v1)
	builder.add_plate(a, b, ground + height - 0.06, 0.14,
		Color("e6dcc6"), false)


## Ichki zinapoya — ikkinchi qavatga.
static func _stairs(builder: MeshBuilder, origin: Vector3, basis: Basis,
		front: float, v0: float, ground: float, height: float) -> void:
	var steps: int = 9
	for i in steps:
		var t: float = float(i) / float(steps)
		var at: Vector3 = _at(origin, basis, front * 0.74, v0 + 0.9 - t * 1.8, ground + height * t)
		_box(builder, basis, at + Vector3(0, 0.06, 0),
			Vector3(0.80, 0.12, 0.22), FurnitureKit.WOOD_ASH)
	# Qo'lda tutish uchun ustun
	builder.add_cylinder(
		_at(origin, basis, front * 0.74, v0 + 0.9, ground),
		_at(origin, basis, front * 0.74, v0 - 0.6, ground + height * 0.75),
		0.035, 6, FurnitureKit.WOOD_RED, false)


## Xona ichidagi chiroqlar.
##
## NIMA UCHUN alohida: shift bor — quyosh ichkariga tushmaydi.
## Real uyda elektr chiroq bor, demak bizda ham bo'lishi kerak.
## Yorug'lik issiq (2700 K atigi) — ertalab soat 7 da uy ichida
## chiroq yoniq bo'lishi tabiiy.
static func _build_lights(root: Node3D, origin: Vector3, basis: Basis,
		front: float, v0: float, v1: float, ground: float) -> Array[Light3D]:
	var lights: Array[Light3D] = []
	var spots: Array[Vector2] = [
		Vector2(front * 0.28, v0 + 1.6),      # katta xona
		Vector2(-front * 0.30, v0 + 1.6),     # oshxona / yotqona
		Vector2(0.0, (CourtyardHouse.PORCH_DEPTH + v0) * 0.5),   # hovli
	]

	for i in spots.size():
		var at: Vector3 = _at(origin, basis, spots[i].x, spots[i].y, ground + 2.72)
		var light := OmniLight3D.new()
		light.name = "Chiroq_%d" % i
		light.position = at
		light.light_color = Color("ffdcae")
		light.light_energy = 1.35
		light.omni_range = 5.2
		light.shadow_enabled = false          # soya zayif GPU uchun qimmat
		root.add_child(light)
		lights.append(light)
	return lights


# ------------------------------------------------------------------ Yordam

## Mahalliy koordinotadan dunyoga — `y` MUTLAQ balandlik.
##
## DIQQAT: `origin.y` allaqachon yer balandligi. Agar unga yana
## `ground` qo'shilsa, natija 2 × balandlik bo'ladi va barcha mebel
## hamda chiroq shift ustida qoladi. Shuning uchun offset `y - origin.y`.
static func _at(origin: Vector3, basis: Basis, u: float, v: float,
		y: float) -> Vector3:
	return origin + basis * Vector3(u, y - origin.y, v)


static func _p2(origin: Vector3, basis: Basis, u: float, v: float) -> Vector2:
	var world: Vector3 = origin + basis * Vector3(u, 0.0, v)
	return Vector2(world.x, world.z)


static func _box(builder: MeshBuilder, basis: Basis, centre: Vector3,
		size: Vector3, colour: Color) -> void:
	FurnitureKit._box(builder, basis, centre, size, colour, true)