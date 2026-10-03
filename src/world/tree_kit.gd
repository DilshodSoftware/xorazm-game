class_name TreeKit
extends RefCounted
## Xorazm daraxtlari — kodda, tashqi model faylisiz.
##
## NIMA UCHUN SHU DARAxtLAR
## Xorazmda daraxt — uyning bir qismi. Anor ( Granada ) har bir
## hovlining burchagida o'sadi: mevasi ham, ko'kasi ham, sovuqdan
## himoya ham. Ko'chalar bo'ylab qarag'ay (topliq) va terak turadi.
## Shuning uchun Tandirchi mahallasida daraxtsiz ko'cha bo'lmaydi.
##
## QANDAY QURILADI
## Barglar — SHAFFOF EMAS, kichik kvadratchalar. Sababi:
##   * alpha-test shaffoflik arzon GPU'da qimmat (blending, sıralama)
##   * shaffoflik yuzalari bir-birining ichida qaralashda noto'g'ri
##     tasvirlanadi
##   * 40–70 ta kichik kvadratcha pastga qaragan siluet beradi —
##     aynan daraxt siluetini ko'rish uchun kerak bo'lgan narsa
## 1 ta daraxt ≈ 60 uchburchak — 200 ta daraxt 12 000 uchburchak.

const CANOPY_VERTEX_COLOUR := true


enum Kind { ANOR, NONAK, QARAGAY, SHARAK, TERAK }


## Daraxtni berilgan nuqtaga quradi. `rng` — takrorlanuvchanlik uchun.
static func build(builder: MeshBuilder, at: Vector3, kind: int,
		rng: RandomNumberGenerator, scale: float = 1.0) -> void:
	match kind:
		Kind.ANOR:
			_anor(builder, at, rng, scale)
		Kind.QARAGAY:
			_qaragay(builder, at, rng, scale)
		Kind.TERAK:
			_terak(builder, at, rng, scale)
		_:
			_round_tree(builder, at, rng, scale, kind)


# ------------------------------------------------------------------ Turlar

## Anor — Xorazmning belgisi daraxti. Bir nechta yon poydan chiqadi,
## shuning uchun manzarada "daraxt" emas, "buta" ko'rinadi. 2,5–4 m.
static func _anor(builder: MeshBuilder, at: Vector3,
		rng: RandomNumberGenerator, scale: float) -> void:
	var stems: int = rng.randi_range(3, 5)
	var height: float = rng.randf_range(2.3, 3.4) * scale
	var spread: float = rng.randf_range(1.5, 2.2) * scale

	for i in stems:
		var angle: float = TAU * float(i) / float(stems) + rng.randf() * 0.6
		var lean: Vector3 = Vector3(cos(angle), 0, sin(angle)) * spread * 0.35
		var top: Vector3 = at + Vector3(0, height * rng.randf_range(0.75, 1.0), 0) + lean
		builder.add_cylinder(at, top, 0.09 * scale, 5, Palette.TRUNK, false)

	# Keng, past va zich somon
	var centre: Vector3 = at + Vector3(0, height * 0.82, 0)
	_canopy(builder, centre, Vector3(spread, height * 0.42, spread),
		rng, 52, scale, Palette.LEAF_DARK, Palette.LEAF_LIGHT)


## Nonak (o'rik) — keng, yassi va shoxli. 5–7 m.
static func _round_tree(builder: MeshBuilder, at: Vector3,
		rng: RandomNumberGenerator, scale: float, kind: int) -> void:
	var height: float = rng.randf_range(4.6, 6.4) * scale
	var radius: float = rng.randf_range(2.2, 3.1) * scale

	# Pastga egilgan poy — nonakda shakil tabiiy
	var lean: Vector3 = Vector3(rng.randf_range(-0.4, 0.4), 0,
		rng.randf_range(-0.4, 0.4))
	builder.add_cylinder(at, at + Vector3(0, height * 0.45, 0) + lean,
		0.19 * scale, 6, Palette.TRUNK, false)

	# Asosiy shoxlar
	var crown: Vector3 = at + Vector3(0, height * 0.45, 0) + lean
	var branches: int = rng.randi_range(3, 5)
	for i in branches:
		var angle: float = TAU * float(i) / float(branches) + rng.randf()
		var tip: Vector3 = crown + Vector3(cos(angle), 0, sin(angle)) * radius * 0.55 \
			+ Vector3(0, height * 0.2, 0)
		builder.add_cylinder(crown, tip, 0.09 * scale, 4, Palette.TRUNK, false)

	var tone: Color = Color("6f8a3c") if kind == Kind.SHARAK else Color("557a33")
	_canopy(builder, crown + Vector3(0, height * 0.3, 0),
		Vector3(radius, radius * 0.66, radius), rng, 62, scale,
		tone.darkened(0.22), tone.lightened(0.10))


## Qarag'ay (topliq / turang') — uzun, ingichka, ko'chaning belgisi.
## 11–15 m. Yo'l bo'ylab qator qilib ekiladi.
static func _qaragay(builder: MeshBuilder, at: Vector3,
		rng: RandomNumberGenerator, scale: float) -> void:
	var height: float = rng.randf_range(11.0, 14.5) * scale
	var radius: float = rng.randf_range(1.25, 1.7) * scale

	builder.add_cylinder(at, at + Vector3(0, height, 0), 0.24 * scale, 6,
		Color("6e5b46"), false)
	# Tor, uchiqayroqchoq korona — tepada ingichka
	_canopy_tapered(builder, at + Vector3(0, height * 0.18, 0),
		height * 0.82, radius, radius * 0.28, rng, 58, scale,
		Color("4a6a35"), Color("6d8c46"))


## Terak — kanal bo'ylab, osiluvchi shoxlari bilan.
static func _terak(builder: MeshBuilder, at: Vector3,
		rng: RandomNumberGenerator, scale: float) -> void:
	var height: float = rng.randf_range(7.5, 10.0) * scale
	builder.add_cylinder(at, at + Vector3(0, height * 0.55, 0), 0.32 * scale, 6,
		Color("7a6b52"), false)
	var crown: Vector3 = at + Vector3(0, height * 0.6, 0)
	var branches: int = rng.randi_range(4, 6)
	for i in branches:
		var angle: float = TAU * float(i) / float(branches) + rng.randf()
		var tip: Vector3 = crown + Vector3(cos(angle), 0, sin(angle)) * 2.4 * scale \
			+ Vector3(0, height * 0.22, 0)
		builder.add_cylinder(crown, tip, 0.11 * scale, 4, Color("7a6b52"), false)
		# Osiluvchi shox — terakning o'ziga xos ko'rinishi
		var droop: Vector3 = tip + Vector3(cos(angle) * 0.7, -1.9 * scale,
			sin(angle) * 0.7)
		builder.add_cylinder(tip, droop, 0.05 * scale, 4, Color("7a6b52"), false)
	_canopy(builder, crown + Vector3(0, height * 0.26, 0),
		Vector3(2.7 * scale, height * 0.3, 2.7 * scale), rng, 58, scale,
		Color("6f8455"), Color("93a26c"))


# ------------------------------------------------------------------ Somon

## Keng ellipsoid ichida tarqatilgan kvadratchalar.
static func _canopy(builder: MeshBuilder, centre: Vector3,
		radii: Vector3, rng: RandomNumberGenerator, count: int,
		scale: float, dark: Color, light: Color) -> void:
	for i in count:
		# Kub ichida bir tekis nuqta — yaxshiroq taqsimot uchun
		var p := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0))
		if p.length_squared() > 1.0:
			p = p.normalized()
		var at: Vector3 = centre + Vector3(p.x * radii.x, p.y * radii.y, p.z * radii.z)

		# Barg kvadratchasi — har safar boshqa yo'nalishda
		var yaw: float = rng.randf() * TAU
		var tilt: float = rng.randf_range(-0.9, 0.9)
		# Barg 30–45 sm. Katta qilsak, daraxt "keng varakli kalitak"
		# bo'lib ko'rinadi va 2 m gacha siluet chiqadi.
		var size: float = rng.randf_range(0.30, 0.48) * scale
		_leaf(builder, at, yaw, tilt, size, dark, light, rng)


## Pastdan kengroq, tepadan ingichka korona (qarag'ay).
static func _canopy_tapered(builder: MeshBuilder, base: Vector3,
		height: float, radius_low: float, radius_top: float,
		rng: RandomNumberGenerator, count: int, scale: float,
		dark: Color, light: Color) -> void:
	for i in count:
		var t: float = pow(rng.randf(), 0.7)
		var y: float = t * height
		var radius: float = lerpf(radius_low, radius_top, t) * scale
		var angle: float = rng.randf() * TAU
		var at: Vector3 = base + Vector3(
			cos(angle) * radius * sqrt(rng.randf()),
			y,
			sin(angle) * radius * sqrt(rng.randf()))
		_leaf(builder, at, rng.randf() * TAU, rng.randf_range(-0.7, 0.7),
			rng.randf_range(0.55, 0.95) * scale, dark, light, rng)


## Bitta barg kvadratchasi. Ikkala tomi ham ko'rinadi.
static func _leaf(builder: MeshBuilder, at: Vector3, yaw: float, tilt: float,
		size: float, dark: Color, light: Color, rng: RandomNumberGenerator) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	var normal := (basis * Vector3(0, 0, 1)).normalized()
	var colour: Color = dark.lerp(light, rng.randf())
	# DIQQAT: to'rt burchak — haqiqiy TO'RTBURCHAK. `at ± half` ga
	# yana vertikal ofset qo'shilsa, shakl "galtaq bow" bo'ladi va
	# daraxt "kaltak bargli nishonlar" ko'rinishida chiqadi.
	var h := size * 0.5
	var w := size * 0.34
	builder.add_quad(
		at + basis * Vector3(-w, -h, 0.0),
		at + basis * Vector3(w, -h, 0.0),
		at + basis * Vector3(w, h, 0.0),
		at + basis * Vector3(-w, h, 0.0),
		colour, normal, false)


## Kuzgi (sariq-cho'k) rang. Bahorda emas, kuzda kerak.
static func autumn_canopy(builder: MeshBuilder, at: Vector3, kind: int,
		rng: RandomNumberGenerator, scale: float) -> void:
	var height: float = rng.randf_range(5.0, 6.8) * scale
	builder.add_cylinder(at, at + Vector3(0, height * 0.45, 0), 0.2 * scale, 6,
		Color("6b5340"), false)
	_canopy(builder, at + Vector3(0, height * 0.72, 0),
		Vector3(2.6 * scale, 1.9 * scale, 2.6 * scale), rng, 56, scale,
		Color("8a6a24"), Color("c39a3a"))