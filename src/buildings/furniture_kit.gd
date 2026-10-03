class_name FurnitureKit
extends RefCounted
## Xorazm xonasining mebellari — an'anaviy, o'lchamlari haqiqiy.
##
## NIMA UCHUN AN'ANAVIY
## Bu xona Xorazm oilasining oilasining xonasidir — katta, yagona.
## U yotqona emas: oila shu yerda yig'iladi, qahva ichadi, kun
## bo'ladi. Shuning uchun markazda — to'ragan (tandir yonidagi
## idish saqlovchi komoda) va uning ustida samovar. Yerga — g'ilam
## va mayda (ko'rpa yoki yostiqlar saqlanadigan sandiq).
##
## O'LCHAMLAR HAQIQIY
## To'ragan 1,80 × 0,55 m · samovar Ø 0,30 m, balandligi 0,62 m
## g'ilam 2,5 × 1,7 m · karavot 2,0 × 1,40 m · shkaf 1,50 × 0,60 m
## Stol 1,40 × 0,75 m

const WOOD_RED := Color("6b3f28")       ## Yong'oq — to'ragan, karavot
const WOOD_ASH := Color("8a6a45")       ## O'tin — shkaf, stol
const BRASS := Color("b08a3e")          ## Samovar, laganda
const CLOTH_RED := Color("8e2f2a")      ## G'ilam, yostiq
const CLOTH_GREEN := Color("4a6b52")
const CLOTH_BLUE := Color("2f4560")
const CLOTH_CREAM := Color("c9b58e")
const ENAMEL := Color("e2e6e4")         ## Oq boyalgan lozinka, kosacha
const LEATHER := Color("5a3d28")


# ================================================================== XONA

## To'ragan — idish saqlovchi komoda. Xorazm xonasining markazida
## shu turadi, chunki u tandir bilan birga ishlatiladi.
static func toragan(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var width: float = 1.80
	var depth: float = 0.55
	var height: float = 0.88

	# Korpus
	_box(builder, basis, at + Vector3(0, height * 0.5, 0),
		Vector3(width, height, depth), WOOD_RED)
	# Ustki tosh
	_box(builder, basis, at + Vector3(0, height + 0.025, 0),
		Vector3(width + 0.06, 0.05, depth + 0.05), WOOD_ASH)
	# Eshik va tortilgan dastak
	for side in 2:
		var x: float = (width * 0.5) * 0.5 if side == 0 else -(width * 0.5) * 0.5
		_box(builder, basis, at + Vector3(x, height * 0.55, depth * 0.5 + 0.01),
			Vector3(width * 0.46, height * 0.62, 0.03), WOOD_RED.darkened(0.25))
		_box(builder, basis, at + Vector3(x + width * 0.17, height * 0.55,
			depth * 0.5 + 0.04), Vector3(0.05, 0.16, 0.05), BRASS)

	# Ustida: samovar va kosachalar
	samovar(builder, basis * Vector3(0, 0, 0) + at + Vector3(0, height + 0.05, 0))
	for i in 3:
		var x: float = -0.62 + float(i) * 0.16
		_box(builder, basis, at + Vector3(x, height + 0.09, -0.08),
			Vector3(0.13, 0.08, 0.13), ENAMEL)


## Samovar — choynak. Latta yoki misdan. Yonida choy tovoqlari.
static func samovar(builder: MeshBuilder, at: Vector3) -> void:
	builder.add_cylinder(at, at + Vector3(0, 0.44, 0), 0.13, 10, BRASS, false)
	builder.add_cylinder(at + Vector3(0, 0.44, 0), at + Vector3(0, 0.52, 0),
		0.10, 10, BRASS.darkened(0.15), false)
	builder.add_box(at + Vector3(0, 0.56, 0), Vector3(0.05, 0.08, 0.05), BRASS,
		0.0, false)
	# Xurba (uchoq)
	_box(builder, Basis(), at + Vector3(0, 0.12, 0.13), Vector3(0.03, 0.20, 0.03),
		BRASS.darkened(0.3), false)
	# Qo'llab turadigan tayoqchalar
	for side in 2:
		_box(builder, Basis(), at + Vector3(0.13 if side == 0 else -0.13, 0.26, 0),
			Vector3(0.03, 0.22, 0.03), BRASS, false)


## G'ilam — to'ldiriladi va devorga tikiladi yoki yerga yoyiladi.
static func khalta(builder: MeshBuilder, at: Vector3, yaw: float,
		rolled: bool = false) -> void:
	var basis := Basis(Vector3.UP, yaw)
	if rolled:
		# Devorga tikilgan, tepasiga tayoq bilan bog'langan
		builder.add_cylinder(
			at + basis * Vector3(-1.1, 0.10, 0.0),
			at + basis * Vector3(1.1, 0.10, 0.0), 0.10, 8, CLOTH_RED, false)
		_box(builder, basis, at + Vector3(0, 0.11, 0),
			Vector3(2.3, 0.04, 0.04), WOOD_ASH)
		return
	# Yerga yoyilgan
	_box(builder, basis, at + Vector3(0, 0.012, 0),
		Vector3(2.5, 0.024, 1.7), CLOTH_RED)
	# Chekka guli
	_box(builder, basis, at + Vector3(0, 0.026, 0.68),
		Vector3(2.5, 0.004, 0.12), CLOTH_GREEN)
	_box(builder, basis, at + Vector3(0, 0.026, -0.68),
		Vector3(2.5, 0.004, 0.12), CLOTH_GREEN)
	_box(builder, basis, at + Vector3(1.12, 0.026, 0),
		Vector3(0.12, 0.004, 1.7), CLOTH_GREEN)


## Mayda — yostiq va ko'rpa saqlanadigan sandiq.
static func mayda(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(builder, basis, at + Vector3(0, 0.21, 0), Vector3(1.20, 0.42, 0.60),
		WOOD_ASH)
	_box(builder, basis, at + Vector3(0, 0.43, 0), Vector3(1.24, 0.04, 0.64),
		WOOD_RED)
	# Ustidagi yostiqlar
	for i in 2:
		_box(builder, basis, at + Vector3(-0.28 + float(i) * 0.56, 0.50, 0),
			Vector3(0.48, 0.10, 0.44), CLOTH_CREAM if i == 0 else CLOTH_BLUE)


## Karavot — to'shak. Uzunligi 2 m, eni 1,4 m.
static func karavot(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(builder, basis, at + Vector3(0, 0.22, 0), Vector3(2.00, 0.30, 1.40),
		WOOD_RED)
	_box(builder, basis, at + Vector3(0, 0.44, 0), Vector3(1.94, 0.16, 1.34),
		CLOTH_CREAM)                                    # to'shak
	# Yastiq va "bolus" (uzun yostiq)
	_box(builder, basis, at + Vector3(-0.72, 0.56, 0), Vector3(0.36, 0.12, 0.70),
		CLOTH_CREAM)
	_box(builder, basis, at + Vector3(0, 0.56, 0.45), Vector3(1.40, 0.12, 0.26),
		CLOTH_GREEN)
	# Boshi — baland boshkoya tayorlangan kichik devorcha
	_box(builder, basis, at + Vector3(-1.02, 0.55, 0), Vector3(0.08, 0.50, 1.40),
		WOOD_RED)


## Shkaf — kiyim va ro'zg'oh uchun.
static func shkaf(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(builder, basis, at + Vector3(0, 1.00, 0), Vector3(1.50, 2.00, 0.60),
		WOOD_ASH)
	# Eshiklar
	for side in 2:
		_box(builder, basis,
			at + Vector3((0.36 if side == 0 else -0.36), 1.05, 0.31),
			Vector3(0.70, 1.70, 0.03), WOOD_ASH.darkened(0.18))
		_box(builder, basis,
			at + Vector3((0.08 if side == 0 else -0.08), 1.05, 0.34),
			Vector3(0.04, 0.18, 0.04), BRASS)


## Kitob javoni — o'qish uchun, derazaning yonida.
static func javon(builder: MeshBuilder, at: Vector3, yaw: float,
		filled: bool = true) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var width: float = 1.10
	var height: float = 1.80
	_box(builder, basis, at + Vector3(0, height * 0.5, 0),
		Vector3(width, height, 0.32), WOOD_ASH)
	var shelves: int = 4
	for i in shelves:
		var y: float = 0.32 + (height - 0.5) * float(i) / float(shelves)
		_box(builder, basis, at + Vector3(0, y, 0), Vector3(width - 0.06, 0.035, 0.30),
			WOOD_ASH.lightened(0.1))
		if not filled or i == 0:
			continue
		# Kitoblar — turlarga qarab balandligi turlicha
		var x: float = -width * 0.5 + 0.06
		while x < width * 0.5 - 0.08:
			var thickness: float = 0.022 + float((int(abs(x) * 97.0)) % 5) * 0.006
			var book_height: float = 0.20 + float((int(abs(x) * 53.0)) % 7) * 0.022
			var tone: Color = [Color("6b3f28"), Color("2f4560"), Color("4a6b52"),
				Color("8e2f2a")][int(abs(x) * 31.0) % 4]
			_box(builder, basis, at + Vector3(x + thickness * 0.5,
				y + book_height * 0.5, 0.0),
				Vector3(thickness, book_height, 0.22), tone)
			x += thickness + 0.004


## Stol + stools — choy va ovqat yeyish.
static func stol(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(builder, basis, at + Vector3(0, 0.72, 0), Vector3(1.40, 0.06, 0.75),
		WOOD_ASH)
	# Oyoqlar
	for sx in [-0.62, 0.62]:
		for sz in [-0.30, 0.30]:
			_box(builder, basis, at + Vector3(sx, 0.35, sz),
				Vector3(0.07, 0.70, 0.07), WOOD_RED)
	# Ustidagi laganda va kosacha
	_box(builder, basis, at + Vector3(0.32, 0.78, 0), Vector3(0.36, 0.06, 0.36),
		ENAMEL)
	_box(builder, basis, at + Vector3(-0.38, 0.765, 0.05), Vector3(0.17, 0.03, 0.17),
		ENAMEL, false)


static func stools(builder: MeshBuilder, at: Vector3, yaw: float,
		count: int = 3) -> void:
	var basis := Basis(Vector3.UP, yaw)
	for i in count:
		var x: float = -0.45 + 0.45 * float(i)
		var p: Vector3 = at + basis * Vector3(x, 0, 0.72)
		_box(builder, basis, p + Vector3(0, 0.22, 0), Vector3(0.32, 0.05, 0.30),
			WOOD_RED)
		for sx in [-0.12, 0.12]:
			for sz in [-0.11, 0.11]:
				_box(builder, basis, p + Vector3(sx, 0.11, sz),
					Vector3(0.05, 0.22, 0.05), WOOD_RED)


## Televizor — hozirgi davr uylarida, devorda o'rnatilgan.
static func televizor(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	# Taglik
	_box(builder, basis, at + Vector3(0, 0.28, 0), Vector3(0.90, 0.56, 0.45),
		WOOD_ASH)
	# Ekran — qora, biroz yaltiroq
	_box(builder, basis, at + Vector3(0, 0.86, -0.02),
		Vector3(0.86, 0.52, 0.06), Color("22262b"))
	_box(builder, basis, at + Vector3(0, 0.86, -0.055),
		Vector3(0.78, 0.45, 0.02), Color("2c3238"))
	# Antenna
	_box(builder, basis, at + Vector3(0, 1.22, 0.02), Vector3(0.03, 0.22, 0.03),
		Color("4a4a4a"), false)


# ================================================================== OSHXONA

## O'choq — o'choq va tandir birga. Ustida kazan va non yopiladi.
static func ochoq(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(builder, basis, at + Vector3(0, 0.42, 0), Vector3(1.30, 0.84, 0.72),
		Color("b6ada0"))                                # oq kaolin g'isht
	_box(builder, basis, at + Vector3(0, 0.87, 0), Vector3(1.36, 0.06, 0.78),
		Color("8e867a"))
	# O'yik (kuygan og'iz)
	_box(builder, basis, at + Vector3(-0.28, 0.26, 0.37),
		Vector3(0.56, 0.40, 0.04), Color("2a211a"))
	# Mozdok (truba)
	_box(builder, basis, at + Vector3(0.45, 1.50, -0.16),
		Vector3(0.22, 1.24, 0.22), Color("9c948a"))
	# Kazan
	_box(builder, basis, at + Vector3(-0.30, 1.00, 0.0), Vector3(0.52, 0.22, 0.52),
		Color("4a4a4e"), false)
	_box(builder, basis, at + Vector3(-0.30, 1.12, 0.0), Vector3(0.54, 0.03, 0.54),
		Color("5c5c60"), false)


## Muzlatgich.
static func muzlatgich(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(builder, basis, at + Vector3(0, 0.42, 0), Vector3(0.58, 0.84, 0.60),
		ENAMEL)
	_box(builder, basis, at + Vector3(0, 0.62, 0.305), Vector3(0.56, 0.02, 0.02),
		Color("c0c4c2"))
	_box(builder, basis, at + Vector3(-0.20, 0.62, 0.32), Vector3(0.03, 0.30, 0.03),
		Color("8a8e8c"))


## Non taxtasi va non.
static func non_taxtasi(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(builder, basis, at + Vector3(0, 0.40, 0), Vector3(0.60, 0.80, 0.40),
		WOOD_ASH)
	_box(builder, basis, at + Vector3(0, 0.83, 0), Vector3(0.66, 0.06, 0.46),
		WOOD_ASH.lightened(0.12))
	# Non — tandirda pishgan, yassilangan
	_box(builder, Basis(), at + Vector3(0, 0.90, 0), Vector3(0.40, 0.09, 0.30),
		Color("c99a5c"), false)
	_box(builder, Basis(), at + Vector3(0.12, 0.97, 0.04),
		Vector3(0.22, 0.06, 0.18), Color("d4a869"), false)


## Devordagi laganda (cho'ntaka) va kosachalar.
static func laganda(builder: MeshBuilder, at: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(builder, basis, at + Vector3(0, 0.02, 0), Vector3(1.60, 0.04, 0.30),
		WOOD_ASH)
	for sx in [-0.74, 0.74]:
		_box(builder, basis, at + Vector3(sx, -0.04, 0), Vector3(0.05, 0.12, 0.05),
			Color("8a6a45"))
	# Idishlar
	for i in 4:
		_box(builder, basis, at + Vector3(-0.45 + float(i) * 0.30, 0.07, 0),
			Vector3(0.20, 0.06, 0.20), ENAMEL, false)


# ================================================================== YORDAM

## Rotatsiya bilan bitta kub.
static func _box(builder: MeshBuilder, basis: Basis, centre: Vector3,
		size: Vector3, colour: Color, collision: bool = true) -> void:
	var half := size * 0.5
	var c: Array[Vector3] = [
		centre + basis * Vector3(-half.x, -half.y, -half.z),
		centre + basis * Vector3(half.x, -half.y, -half.z),
		centre + basis * Vector3(half.x, half.y, -half.z),
		centre + basis * Vector3(-half.x, half.y, -half.z),
		centre + basis * Vector3(-half.x, -half.y, half.z),
		centre + basis * Vector3(half.x, -half.y, half.z),
		centre + basis * Vector3(half.x, half.y, half.z),
		centre + basis * Vector3(-half.x, half.y, half.z),
	]
	_quad(builder, c[0], c[1], c[2], c[3], colour, -basis.z, collision)
	_quad(builder, c[7], c[6], c[5], c[4], colour, basis.z, collision)
	_quad(builder, c[4], c[5], c[1], c[0], colour, basis.y, collision)
	_quad(builder, c[6], c[7], c[3], c[2], colour, -basis.y, collision)
	_quad(builder, c[5], c[6], c[2], c[1], colour, basis.x, collision)
	_quad(builder, c[7], c[4], c[0], c[3], colour, -basis.x, collision)


static func _quad(builder: MeshBuilder, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, colour: Color, normal: Vector3, collision: bool) -> void:
	builder.add_quad(a, b, c, d, colour, normal, collision)