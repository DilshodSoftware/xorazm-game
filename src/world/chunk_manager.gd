class_name ChunkManager
extends Node3D
## Xorazm yerini to'g'ri atrofga yuklab oladi va tashlab ketadi.
##
## Qanday ishlaydi
##   Har kadrda o'yinchi koordinatasi aniqlanadi, kerakli chunklar
##   ro'yxati tuziladi. Yetishmaydiganlar BIR KADRDA bir nechta
##   generatsiya qilinadi (Settings.CHUNK_BUDGET_PER_FRAME) — shunda
##   o'yin to'silmaydi. Kerak bo'lmagan chunklar darhol bo'shatiladi.
##
## Nima uchun radius 2 yetarli
##   Tuman 450 m da tugaydi. Radius 2 chunklarining chegarasi o'yinchidan
##   800–1200 m masofada boshlanadi, ya'ni tuman allaqachin yopib
##   qo'ygan. Shuning uchun pop-in ko'rinmaydi.

signal chunk_loaded(coord: Vector2i)

## Yuklangan chunklar: coord -> WorldChunk
var _chunks: Dictionary = {}
## O'yinchi turgan chunk (tezlik uchun kesh)
var _last_centre := Vector2i(99999, 99999)
var _pending: Array[Vector2i] = []
## Statistika
var _generated_total := 0


func _ready() -> void:
	# Boshlang'ich yuklash chog'ini ochiq ko'rsatamiz
	EventBus.world_loading.emit(0.0, Lang.txt("xabar.yuklanmoqda"))


func _process(delta: float) -> void:
	var focus: Vector3 = _focus_point()

	# --- O'yinchi boshqa chunkga o'tdimi? ---
	var centre := _coord_of(focus)
	if centre != _last_centre:
		_last_centre = centre
		_rebuild_pending(focus)

	# --- Byudjet: faqat bir nechta ---
	var budget: int = Settings.CHUNK_BUDGET_PER_FRAME
	while budget > 0 and not _pending.is_empty():
		var coord: Vector2i = _pending.pop_front()
		_upgrade_or_create(coord)
		budget -= 1

	# --- Yuklash tugaganda xabar beramiz ---
	if _pending.is_empty() and not _loading_reported and _chunks.size() > 0:
		_loading_reported = true
		EventBus.world_ready.emit()


var _loading_reported := false


## Kameraga (o'yinchiga) qarab yuklanadigan nuqta.
##
## DIQQAT: bu qiymatni TIT qilib olib turish kerak edi. Dastlab
## `Game.current_world()` orqali olinardi, lekin asosiy sahna `Game`
## orqali ro'yxatga olinmagandi — shuning uchun funksiya DOIM
## Vector3.ZERO qaytarar, chunklar har doim dunyo markazida qolardi va
## relyum umuman chizilmasdi. Endi bog'lanish aniq va tekshiriladigan.
var target: Node3D

func _focus_point() -> Vector3:
	if target != null and is_instance_valid(target):
		return target.global_position
	return global_position


static func _coord_of(point: Vector3) -> Vector2i:
	var size: float = Settings.CHUNK_SIZE
	return Vector2i(floori(point.x / size), floori(point.z / size))


## Kerakli chunklarni ro'yxatga oladi va ortiqchalarni bo'shatadi.
func _rebuild_pending(focus: Vector3) -> void:
	_rebuild_around(focus)


## Kerakli chunklarni ro'yxatga oladi va ortiqchalarni bo'shatadi.
func _rebuild_around(focus: Vector3) -> void:
	var radius: int = Settings.load_radius()
	var centre := _coord_of(focus)

	# --- Kerakli ro'yxat ---
	var wanted: Dictionary = {}
	var order: Array[Vector2i] = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			# kvadrat emas — doira: chetdagi ortiqcha chunklarni yuklamaslik
			# uchun. 30% kamroq ish.
			if dx * dx + dz * dz > radius * radius + radius:
				continue
			var coord := Vector2i(centre.x + dx, centre.y + dz)
			wanted[coord] = true
			order.append(coord)

	# --- Navbat: yaqinlar avval ---
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - centre).length_squared() < (b - centre).length_squared())

	# --- Ortiqchalarni bo'shat ---
	for coord: Vector2i in _chunks.keys():
		if not wanted.has(coord):
			var chunk: WorldChunk = _chunks[coord]
			_chunks.erase(coord)
			if is_instance_valid(chunk):
				chunk.queue_free()

	# --- Yetishmaganlarni navbatga ---
	_pending.clear()
	for coord: Vector2i in order:
		if _chunks.get(coord) == null:
			_pending.append(coord)
		elif _chunks[coord].detail != _is_near(coord, centre):
			# Radius 1 ga kirgan (yoki undan chiqgan) chunk — batafsilligi
			# o'zgarishi kerak.
			#
			# DIQQAT: bu yerda HECH NARSA bo'shatmaymiz! Avvalgi versiya
			# `existing.queue_free()` qilib, chunkni ro'yxatdan chiqarib,
			# navbatga tashlar edi. Keyin ular 1 kadr/kadr qayta
			# qurilardi — va o'yinchi ostidagi yer bir necha kadrga
			# YO'QOLARDI: u havoga tushib ketardi. Endi eski chunk
			# o'z o'rnida turadi, yangisi avval yaratilib, keyin eskisi
			# bo'shatiladi (qarang `_upgrade_or_create`).
			_pending.append(coord)


func _is_near(coord: Vector2i, centre: Vector2i) -> bool:
	var d: Vector2i = coord - centre
	return absi(d.x) <= 1 and absi(d.y) <= 1


## Chunkni yaratadi YOKI batafsilligini yangilaydi.
##
## MUHIM TARTIB: yangi chunk avval sahnaga qo'shiladi, ESKI chunk keyin
## bo'shatiladi. Aks holda o'yinchi ostida bir necha kadrga yer
## bo'lmay qoladi va u havoga tushib ketadi.
func _upgrade_or_create(coord: Vector2i) -> void:
	var wants_detail: bool = _is_near(coord, _last_centre)
	var existing: WorldChunk = _chunks.get(coord)

	if existing != null:
		if existing.detail == wants_detail:
			return          # allaqachon kerakli darajada
		var replacement := WorldChunk.create(coord, wants_detail)
		add_child(replacement)          # 1. yangisi sahnada
		_chunks[coord] = replacement   # 2. ro'yxatga o'tdi
		existing.queue_free()           # 3. eskisi keyin o'chadi
		_generated_total += 1
		chunk_loaded.emit(coord)
		EventBus.chunk_generated.emit(coord)
		return

	var chunk := WorldChunk.create(coord, wants_detail)
	add_child(chunk)
	_chunks[coord] = chunk
	_generated_total += 1

	chunk_loaded.emit(coord)
	EventBus.chunk_generated.emit(coord)

	EventBus.world_loading.emit(
		float(_chunks.size()) / float(maxi(1, _wanted_count())),
		Lang.txt("xabar.yuklanmoqda")
	)


func _wanted_count() -> int:
	var radius: int = Settings.load_radius()
	var count := 0
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz <= radius * radius + radius:
				count += 1
	return count


## Barcha kerakli chunklarni darhol yuklaydi (boshlang'ich va teleportdan
## keyin kerak — o'yinchi hech nara tushib qolmasin).
##
## DIQQAT: `_last_centre` OLDINDAN to'g'rilanadi. Avvalgi versiya uni
## sentinel qiymatga (99999) qo'yib, so'ng chunklarni yaratardi —
## shuning uchun hammasi `detail=false` bo'lib chiqardi va keyingi
## kadrda 9 ta yaqin chunk "LOD uchun" bo'shatilib, 1 kadr/kadr
## qaytadan qurilardi. O'yinchi aynan shu teshikdan havoga tushardi.
func force_load_all(focus: Vector3) -> void:
	_last_centre = _coord_of(focus)      # <- avval to'g'rilaymiz
	_rebuild_around(focus)
	while not _pending.is_empty():
		_upgrade_or_create(_pending.pop_front())
	_loading_reported = true
	EventBus.world_ready.emit()


# ------------------------------------------------------------------ So'rovlar

func chunk_at(coord: Vector2i) -> WorldChunk:
	return _chunks.get(coord)


func is_loaded(coord: Vector2i) -> bool:
	return _chunks.has(coord)


func loaded_count() -> int:
	return _chunks.size()


## Navbatda kutayotgan chunklar soni. Diagnostika va testlar uchun:
## bu qiymat 0 bo'lmasa, keyingi kadrda teshik paydo bo'lishi mumkin.
func pending_count() -> int:
	return _pending.size()


func generated_total() -> int:
	return _generated_total


## O'quvchilar uchun qulay: berilgan nuqtadagi yer balandligi.
## Chunk yuklanmagan bo'lsa ham, TerrainGen dan to'g'ri o'qiydi
## (boshlang'ich qadamda).
func ground_height(x: float, z: float) -> float:
	return TerrainGen.height_at(x, z)
