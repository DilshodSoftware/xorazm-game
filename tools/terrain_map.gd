class_name TerrainMap
extends RefCounted
## Xorazmning tekis rasm xaritasi — to'g'ridan TerrainGen dan.
##
##     godot --headless --path . -- --terrainmap /tmp/map.png
##
## Nima uchun bu kerak:
##   O'yin GPU'da faqat radius 2 (800–1200 m) atrofini ko'radi, shuning
##   uchun butun orolni ko'rsatib bo'lmaydi. Ammo Xorazm — tekis o'lkaz:
##   5,8 × 5,2 km maydonda balandlik farqi atigi 19 m. 3 km balandlikdan
##   qaraganda 6 m farq umuman ko'rinmaydi va hamma suv ostida qoladi.
##
##   Bu voscha esa balandlik funksiyasini to'g'ridan-to'g'ri chizadi:
##   orol shakli, kanallar, Amudaryo, sho'r ko'llar, qum tepaliklari va
##   paxta dalalari — hammasi bir rasmda. Boshqaruv qarorlari uchun.

const DEFAULT_WIDTH := 1000

## Yorug'lik yo'nalishi — relyefni bo'lish uchun (chap yuqoridan)
const HILL_LIGHT := Vector3(-0.55, 0.72, -0.42)


## Xarita chizadi, PNG saqlaydi. Qaytaradi: muvaffaqiyat (0 = xato).
static func render(path: String, width: int = DEFAULT_WIDTH) -> int:
	var half_x: float = TerrainGen.ISLAND_HALF_X * 1.18
	var half_z: float = TerrainGen.ISLAND_HALF_Z * 1.18
	var height: int = int(round(float(width) * half_z / half_x))

	print_rich("[color=#7fbf6a]Xarita chizilmoqda[/color] %d × %d ... (%d balandlik hisobi)" % [
		width, height, width * height
	])

	# Balandliklar bir marta hisoblanadi — ikki marta sarflanmasin
	var grid := PackedFloat32Array()
	grid.resize(width * height)
	for j in height:
		for i in width:
			grid[j * width + i] = TerrainGen.height_at(
				_map_x(i, width, half_x), _map_z(j, height, half_z)
			)

	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var cell_x: float = 2.0 * half_x / float(width)
	var cell_z: float = 2.0 * half_z / float(height)

	for j in height:
		for i in width:
			var x: float = _map_x(i, width, half_x)
			var z: float = _map_z(j, height, half_z)
			var h: float = grid[j * width + i]

			# --- Relefni bo'lish ---
			var h_left: float = grid[j * width + maxi(i - 1, 0)]
			var h_right: float = grid[j * width + mini(i + 1, width - 1)]
			var h_down: float = grid[maxi(j - 1, 0) * width + i]
			var h_up: float = grid[mini(j + 1, height - 1) * width + i]
			var normal := Vector3(
				(h_left - h_right) / (2.0 * cell_x),
				1.0,
				(h_down - h_up) / (2.0 * cell_z)
			).normalized()
			var shade: float = clampf(normal.dot(HILL_LIGHT.normalized()), 0.0, 1.0)
			# Kontrastni oshiramiz — past relyefda boshqa ko'rinmaydi
			shade = pow(shade, 1.6) * 0.75 + 0.25

			# --- Balandlik bo'yicha rang ---
			var colour: Color = _colour_at(x, z, h, 1.0 - normal.y)
			image.set_pixel(i, j, Color(
				colour.r * shade, colour.g * shade, colour.b * shade
			))

	_draw_cities(image, width, height, half_x, half_z)
	_draw_home(image, width, height, half_x, half_z)
	_draw_canals(image, width, height, half_x, half_z)

	var err := image.save_png(path)
	print_rich("[color=#7fbf6a]Xarita saqlandi[/color] %s (xato: %d)" % [path, err])
	return err


# ------------------------------------------------------------------ Yordamchi

static func _map_x(i: int, width: int, half: float) -> float:
	return -half + (float(i) + 0.5) / float(width) * 2.0 * half


static func _map_z(j: int, height: int, half: float) -> float:
	# qator 0 = shimol (-Z) — tepadan pastga qaraganda tabiiy
	return -half + (float(j) + 0.5) / float(height) * 2.0 * half


static func _colour_at(x: float, z: float, h: float, slope: float) -> Color:
	# Suv chuqurligi bo'yicha qumli-kesk ko'k
	if h < Settings.SEA_LEVEL:
		var depth: float = clampf(-h / 9.0, 0.0, 1.0)
		return Palette.RIVERBED.lerp(Palette.WATER_AMU.darkened(0.35), depth)
	return TerrainGen.color_at(x, z, h, slope)


static func _draw_cities(image: Image, width: int, height: int,
		half_x: float, half_z: float) -> void:
	for id: String in WorldMap.CITIES:
		var p: Vector2 = WorldMap.city_position(id)
		var radius: float = WorldMap.CITIES[id]["radius"]
		var c := Vector2(_to_px(p.x, half_x, width), _to_pz(p.y, half_z, height))
		var r: float = radius / (2.0 * half_x) * float(width)
		_draw_ring(image, c, r, Palette.UI_TEXT, false)
		_draw_dot(image, c, 3, Palette.UI_TEXT)
		print_rich("  [color=#a89d8a]%s — %.0f, %.0f (r=%.0f m)[/color]" % [
			WorldMap.city_name(id), p.x, p.y, radius
		])


static func _draw_home(image: Image, width: int, height: int,
		half_x: float, half_z: float) -> void:
	var p: Vector2 = WorldMap.TANDIRCHI
	var c := Vector2(_to_px(p.x, half_x, width), _to_pz(p.y, half_z, height))
	_draw_cross(image, c, 8, Palette.UI_ACCENT)
	print_rich("  [color=#d9a441]Tandirchi (uyingiz) — %.0f, %.0f[/color]" % [p.x, p.y])


static func _draw_canals(image: Image, width: int, height: int,
		half_x: float, half_z: float) -> void:
	for canal: Dictionary in TerrainGen.CANALS:
		_draw_line(image,
			Vector2(_to_px(canal["a"].x, half_x, width), _to_pz(canal["a"].y, half_z, height)),
			Vector2(_to_px(canal["b"].x, half_x, width), _to_pz(canal["b"].y, half_z, height)),
			Palette.WATER_CANAL)


static func _to_px(x: float, half_x: float, width: int) -> float:
	return (x + half_x) / (2.0 * half_x) * float(width)


static func _to_pz(z: float, half_z: float, height: int) -> float:
	return (z + half_z) / (2.0 * half_z) * float(height)


static func _draw_dot(image: Image, centre: Vector2, radius: int, colour: Color) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				_plot(image, centre.x + dx, centre.y + dy, colour)


static func _draw_ring(image: Image, centre: Vector2, radius: float,
		colour: Color, filled: bool = true) -> void:
	var steps: int = int(radius * 8.0)
	for a in steps:
		var angle: float = a / float(steps) * TAU
		_plot(image, centre.x + cos(angle) * radius, centre.y + sin(angle) * radius, colour)


static func _draw_cross(image: Image, centre: Vector2, size: int, colour: Color) -> void:
	for d in range(-size, size + 1):
		_plot(image, centre.x + d, centre.y, colour)
		_plot(image, centre.x, centre.y + d, colour)


static func _draw_line(image: Image, a: Vector2, b: Vector2, colour: Color) -> void:
	var steps: int = int(maxf(a.distance_to(b), 1.0)) * 2
	for s in steps + 1:
		var t: float = s / float(maxi(steps, 1))
		_plot(image, lerpf(a.x, b.x, t), lerpf(a.y, b.y, t), colour)


## Nomi "_set" bo'lishi SHART emas: Object._set(StringName, Variant) —
## bu allaqachon mavjud virtual metod, biz override qilishga urinib
## xato qilamiz. Shuning uchun "_plot".
static func _plot(image: Image, x: float, y: float, colour: Color) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var xi := int(round(x))
	var yi := int(round(y))
	if xi >= 0 and xi < w and yi >= 0 and yi < h:
		image.set_pixel(xi, yi, colour)
