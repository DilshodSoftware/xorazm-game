class_name BuildingManager
extends Node3D
## Tandirchi binolarini, xuddi yerni kabi, o'yinchi atrofida yuklaydi.
##
## NIMA UCHUN CHUNK BO'YIB
## Mahallada ~190 uy bor. Hammasini bir vaqtda qursak, bu taxminan
## 50 000 uchburchak va 190 ta collision — zayif GPU uchun juda ko'p.
## Chunk'lar bo'yina bo'lib, faqat yaqin 3–4 ta yuklanadi, qolganlari
## tashlanadi. Yer bilan bir xil tamoyil.
##
## NIMA UCHUN BINOLAR YERGA QO'YILMAYDI
## Har bir uy o'z balandligini TerrainGen.height_at dan oladi — xuddi
## yo'llar kabi. Shuning uchun relyef tekislansa ham uylar yer ostida
## qolmaydi va ko'tarilmaydi.

var _chunks: Dictionary = {}          # coord -> Node3D
var _generated_total := 0
var _house_total := 0
var _last_centre := Vector2i(99999, 99999)
var _pending: Array[Vector2i] = []

## O'yinchi. DIQQAT: `Game.current_world()` orqali olish xato edi —
## asosiy sahna `Game` orqali ro'yxatga olinmagandi va funksiya DOIM
## Vector3.ZERO qaytarar, ya'ni binolar doim dunyo markazida qurilardi.
## ChunkManager bilan bir xil yechim: bog'lanish aniq.
var target: Node3D


func _focus_point() -> Vector3:
	if target != null and is_instance_valid(target):
		return target.global_position
	return global_position


func _ready() -> void:
	name = "Binolar"
	_build_streets()


func _process(_delta: float) -> void:
	var centre := _coord_of(_focus_point())

	if centre != _last_centre:
		_last_centre = centre
		_rebuild(centre)

	var budget: int = Settings.CHUNK_BUDGET_PER_FRAME
	while budget > 0 and not _pending.is_empty():
		_build_chunk(_pending.pop_front())
		budget -= 1


# ================================================================= MAHALLA

## Mahalla ko'chalarini yerga chizadi — tor, g'ishtli, chizig'i yo'q.
func _build_streets() -> void:
	var builder := MeshBuilder.new()
	var holder := Node3D.new()
	holder.name = "Ko'chalar"
	add_child(holder)
	for street: Dictionary in Tandirchi.streets():
		var points: PackedVector2Array = street["nuqta"]
		var width: float = street["kenglik"]
		var previous: Dictionary = {}

		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var length: float = a.distance_to(b)
			if length < 0.5:
				continue
			var normal: Vector2 = (b - a).orthogonal().normalized()
			var steps: int = maxi(1, int(ceil(length / 6.0)))

			for s in steps:
				var t: float = float(s) / float(steps)
				var p: Vector2 = a.lerp(b, t)
				var y: float = TerrainGen.height_at(p.x, p.y)
				# Ko'cha yuzasini 10 sm ko'taramiz. 4 sm yetarli
				# emas edi — uzoqdan z-urish (z-fighting) ko'chani
				# yerga yopib qo'yardi va mahalla "haqiqiy ko'chalar
				# yo'q"dek ko'rindi.
				var sample := {
					"chap": Vector3(p.x - normal.x * width * 0.5, y + 0.10,
						p.y - normal.y * width * 0.5),
					"o'ng": Vector3(p.x + normal.x * width * 0.5, y + 0.10,
						p.y + normal.y * width * 0.5),
				}
				if not previous.is_empty():
					# Ko'cha yuzasi — qum/g'isht, rangi yerdan farq qiladi
					builder.add_quad(
						previous["chap"], sample["chap"],
						sample["o'ng"], previous["o'ng"],
						Palette.STREET_EARTH, Vector3.UP, false)
					# Yon chetlar — ko'cha chetidagi ariqcha (kafedraza)
					var l0: Vector3 = previous["chap"]
					var l1: Vector3 = sample["chap"]
					var r0: Vector3 = previous["o'ng"]
					var r1: Vector3 = sample["o'ng"]
					var edge := Vector3(0, -0.18, 0)
					builder.add_quad(l0, l1, l1 + edge, l0 + edge,
						Palette.STREET_EDGE, Vector3.UP, false)
					builder.add_quad(r0 + edge, r1 + edge, r1, r0,
						Palette.STREET_EDGE, Vector3.UP, false)
				previous = sample

	builder.commit(holder, "Mesh")


func _rebuild(centre: Vector2i) -> void:
	var wanted: Dictionary = {}
	var order: Array[Vector2i] = []
	# Bino yuklash radiusi yerga qaraganda kichikroq — binolar 8 m
	# baland, shuning uchun 2 chunk (800 m) allaqachon tuman ichida.
	var radius: int = 2
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz > radius * radius + radius:
				continue
			var coord := Vector2i(centre.x + dx, centre.y + dz)
			if not _has_content(coord):
				continue
			wanted[coord] = true
			order.append(coord)

	for coord: Vector2i in _chunks.keys():
		if not wanted.has(coord):
			var node: Node3D = _chunks[coord]
			_chunks.erase(coord)
			if is_instance_valid(node):
				node.queue_free()

	_pending.clear()
	for coord in order:
		if not _chunks.has(coord):
			_pending.append(coord)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - centre).length_squared() < (b - centre).length_squared())


## Bu chunk'da Tandirchi binosi bormi?
static func _has_content(coord: Vector2i) -> bool:
	var size: float = Settings.CHUNK_SIZE
	var rect := Rect2(
		Vector2(coord.x * size, coord.y * size), Vector2(size, size))
	return rect.intersects(Tandirchi.bounds())


func _build_chunk(coord: Vector2i) -> void:
	if _chunks.has(coord):
		return

	var builder := MeshBuilder.new()
	builder.want_collision = true
	var rng := RandomNumberGenerator.new()
	rng.seed = Settings.WORLD_SEED + coord.x * 7919 + coord.y * 104729

	var size: float = Settings.CHUNK_SIZE
	var area := Rect2(
		Vector2(coord.x * size, coord.y * size), Vector2(size, size))

	var count := 0
	for plot: Dictionary in Tandirchi.plots():
		# O'yinchi uyi alohida quriladi (ichi, mebelleri, chiroqlari
		# bilan). Agar bu yerda yana qursak, ikkita uy ustma-ust
		# tushadi va ichida yurib bo'lmaydi.
		if plot.get("o'yinchi", false):
			continue
		var centre: Vector2 = plot["markaz"]
		if not area.has_point(centre):
			continue
		rng.seed = Settings.WORLD_SEED + int(plot["urish"])
		CourtyardHouse.build(builder, centre, float(plot["yaw"]),
			float(plot["front"]), float(plot["chuqur"]), int(plot["qavat"]),
			rng, int(plot["uslub"]))
		count += 1

	if builder.is_empty():
		return

	var node := Node3D.new()
	node.name = "Bino_%d_%d" % [coord.x, coord.y]
	add_child(node)
	builder.commit(node, "Mesh")
	builder.commit_collision(node, "Kolpasi")
	_chunks[coord] = node
	_generated_total += 1
	_house_total += count


## Barcha kerakli binolarni darhol yuklaydi (teleportdan keyin).
func force_load_all(focus: Vector3) -> void:
	_last_centre = _coord_of(focus)
	_rebuild(_last_centre)
	while not _pending.is_empty():
		_build_chunk(_pending.pop_front())


# ================================================================= So'rovlar

static func _coord_of(point: Vector3) -> Vector2i:
	var size: float = Settings.CHUNK_SIZE
	return Vector2i(floori(point.x / size), floori(point.z / size))


## Diagnostika: hozirda nechta uy qurilgan.
func house_count() -> int:
	return _house_total


func generated_total() -> int:
	return _generated_total


func loaded_chunks() -> int:
	return _chunks.size()


func pending_count() -> int:
	return _pending.size()