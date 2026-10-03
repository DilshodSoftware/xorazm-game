class_name PlayerSelfTest
extends Node
## O'yinchi fizikasining avtomatik tekshiruvi.
##
##     godot --headless --path . -- --test
##
## Nima uchun bu kerak: yurish, sakrash, egilish, ko'rinadigan qatlamlar —
## keyingi barcha bosqichlar shularga tayanadi (mashinaga minish, suzish,
## kurashish). Agar bu yerda xato bo'lsa, u 10-bosqichda chiqadi va
## tuzatish juda qiyin bo'ladi.
##
## SINOV YERI: Urganch markazi. Bu Xorazmdagi eng tekis nuqta — shahar
## tepaligi markazda aniq 6,00 m. O'lchovlar nisbiy (erga nisbatan),
## shuning uchun relyefni o'zgartirsak ham test o'zgarmaydi.
##
## Bu sahnaga qo'shiladigan NODE bo'lishi SHART: RefCounted bo'lsa,
## `await` qilingandan keyin obyekt bo'shilib ketadi va tekshiruv
## jimgina to'xtab qoladi (RefCounted signalga obyektni ushlab turmaydi).

## Sinov maydoni — Urganch markazi, tepalik markazi (aniq 6,00 m)
const GROUND := Vector2(-745.0, 13.0)

const SETTLE_FRAMES := 30
const WALK_FRAMES := 45
const JUMP_FRAMES := 90
## To'liq sakrash uchun tugmani cho'qqa qadar ushlab turish kerak
## (JUMP_CUT ishi sabab). ~0,5 s yetarli.
const JUMP_HOLD_FRAMES := 32

var host: Node

var _passed := 0
var _failed := 0


var _dummy_target: Node3D


func _ready() -> void:
	# ChunkManager BITTAGINA nishoni kuzatadi. Sinov maydoni boshqa
	# nuqtada bo'lgani uchun, aks holda manager haqiqiy o'yinchini kuzatib
	# davom etar va SINOV chunklarini bo'shatib yuborardi — o'yinchi
	# havoga tushardi. Shuning uchun vaqtincha nishonni almashtiramiz.
	_dummy_target = Node3D.new()
	_dummy_target.name = "SinovNishoni"
	_dummy_target.position = Vector3(GROUND.x, 0.0, GROUND.y)
	add_child(_dummy_target)
	host.chunks.target = _dummy_target
	host.chunks.force_load_all(_dummy_target.global_position)
	_run()


func _run() -> void:
	print_rich("\n[b]=== O'YINCHI O'Z-IJNI TEKSHIRUVI ===[/b]")

	await _test_gravity_and_rest()
	await _test_spawn_is_clear()
	await _test_walk_direction()
	await _test_sprint_speed()
	await _test_jump_and_land()
	await _test_crouch_and_ceiling()
	await _test_collision_layers()

	print("----------------------------------------")
	print_rich("O'tdi: [color=#7fbf6a]%d[/color]   Xato: [color=#%s]%d[/color]" % [
		_passed, "c8452f" if _failed > 0 else "7fbf6a", _failed
	])
	print("")
	get_tree().quit(0 if _failed == 0 else 1)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print_rich("  [color=#7fbf6a]OK[/color]   %s [color=#a89d8a]%s[/color]" % [label, detail])
	else:
		_failed += 1
		print_rich("  [color=#c8452f]FAIL[/color] %s %s" % [label, detail])


func _ok(label: String, actual: float, expected: float, tolerance: float) -> void:
	_check(label, absf(actual - expected) <= tolerance,
		"(kutilgan %.2f, olindi %.2f, ±%.2f)" % [expected, actual, tolerance])


# ------------------------------------------------------------------- Testlar

## Yer ushlab turishi: og'irlik ishlaydi, qo'lda qolmaydi.
func _test_gravity_and_rest() -> void:
	var ground: float = TerrainGen.height_at(GROUND.x, GROUND.y)
	var player := _fresh_player(host, Vector3(GROUND.x, ground + 6.0, GROUND.y))
	await _wait(SETTLE_FRAMES * 4)

	_ok("Erga qo'naydi", player.global_position.y, ground, 0.25)
	_check("Yerda turibdi", player.is_on_floor(),
		"(is_on_floor = %s)" % player.is_on_floor())
	_check("X silinmadi", absf(player.velocity.x) < 0.01)
	_check("Z silinmadi", absf(player.velocity.z) < 0.01)

	player.queue_free()
	await host.get_tree().process_frame


## Tug'ilish nuqtasi toza bo'lishi SHART.
##
## Bu test bir haqiqiy xatoni ushlaydi: o'yinchi birinchi bo'lib
## ishga tushganda, agar nuqta qo'yilgan obyektning (devor, mashina,
## daraxt) ICHIDA bo'lsa, `move_and_slide` uni ichkaridan pastga suradi
## va u yer oriqali tushib ketadi. Chunklar to'g'ri ishlayotganini
## ko'rib, chunk collision muammosi deb o'ylash mumkin — lekin muammo
## boshqada. Shu sabab bu test alohida qo'yilgan.
func _test_spawn_is_clear() -> void:
	var spawn := WorldMap.spawn_position()
	_check("Tug'ilish nuqtasi yer ustidagi to'g'ri yerda",
		TerrainGen.height_at(spawn.x, spawn.z) > 1.0,
		"(yer %.2f m, spawn %.2f m)" % [TerrainGen.height_at(spawn.x, spawn.z), spawn.y])

	# Tug'ilish nuqtasida bosh to'plami (ko'z balandligi) bo'sh bo'lishi kerak.
	# DIQQAT: yerning O'ZINI tekshiruvdan chiqarish kerak — collision to'ri
	# 8,3 m, shuning uchun nuqtadagi haqiqiy yuzasi TerrainGen dan 0,2–0,4 m
	# farq qilishi mumkin va probs ustiga tushib qoladi. Shuning uchun
	# avval yuzani raycast bilan topamiz, keyin undan yuqorini tekshiramiz.
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(
		spawn + Vector3(0, 40.0, 0), spawn + Vector3(0, -40.0, 0))
	down.collision_mask = PhysicsLayers.WORLD
	var hit: Dictionary = space.intersect_ray(down)
	var surface_y: float = (hit["position"] as Vector3).y if not hit.is_empty() else spawn.y

	var probe := BoxShape3D.new()
	probe.size = Vector3(0.7, 1.7, 0.7)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = probe
	params.transform = Transform3D(
		Basis.IDENTITY, Vector3(spawn.x, surface_y + 0.05 + 0.85, spawn.z))
	params.collision_mask = PhysicsLayers.SOLID
	var hits: Array[Dictionary] = space.intersect_shape(params, 4)
	_check("Tug'ilish nuqtasida to'sqinlik yo'q", hits.is_empty(),
		"(%d ta to'sqinlik, yuzasi %.2f m)" % [hits.size(), surface_y])

	# O'yinchi shu nuqtada qo'yilsa va YERGA TUSHMASIN
	var player := _fresh_player(host, spawn)
	await _wait(SETTLE_FRAMES * 3)
	var ground: float = TerrainGen.height_at(spawn.x, spawn.z)
	_check("Tug'ilishda yerga tushmaydi",
		player.global_position.y > ground - 0.5,
		"(y = %.2f, yer %.2f)" % [player.global_position.y, ground])
	_check("Tug'ilishda yerga o'tiradi", player.is_on_floor())

	player.queue_free()
	await host.get_tree().process_frame


## Yurish yo'nalishi: W bosilganda kamera qaragan tomonga.
func _test_walk_direction() -> void:
	var ground: float = TerrainGen.height_at(GROUND.x, GROUND.y)
	var player := _fresh_player(host, Vector3(GROUND.x, ground, GROUND.y))
	# yaw = 0 da oldinga = -Z = shimol
	player.teleport(player.global_position, 0.0, 0.0)
	await _wait(SETTLE_FRAMES)

	var start := player.global_position
	Input.action_press("move_forward")
	await _wait(WALK_FRAMES)
	Input.action_release("move_forward")
	await _wait(5)

	var moved := player.global_position - start
	_check("Oldinga yurdi (shimolga, -Z)", moved.z < -3.0,
		"(Δx = %.2f, Δz = %.2f)" % [moved.x, moved.z])
	_check("X o'qi bo'yicha chetlash kam", absf(moved.x) < maxf(moved.z * 0.25, 0.5),
		"(Δx = %.2f)" % moved.x)

	player.queue_free()
	await host.get_tree().process_frame


## Shift bilan yugurish tezroq va kuch sarflaydi.
func _test_sprint_speed() -> void:
	var ground: float = TerrainGen.height_at(GROUND.x, GROUND.y)
	var player := _fresh_player(host, Vector3(GROUND.x, ground, GROUND.y))
	player.teleport(player.global_position, 0.0, 0.0)
	await _wait(SETTLE_FRAMES)

	# Oddiy yugurish (Shift'siz)
	Input.action_press("move_forward")
	await _wait(30)
	var run_speed := player.horizontal_speed()

	Game.state.stamina = 100.0
	Input.action_press("sprint")
	await _wait(30)
	var sprint_speed := player.horizontal_speed()

	_check("Shift yugurishni tezlaptiradi", sprint_speed > run_speed + 0.8,
		"(yugurish %.2f -> yugurish %.2f m/s)" % [run_speed, sprint_speed])
	_ok("Yugurish tezligi", sprint_speed, Player.SPEED_SPRINT, 0.35)
	_check("Kuch sarflanmoqda", Game.state.stamina < 100.0,
		"(kuch = %.0f)" % Game.state.stamina)

	Input.action_release("sprint")
	Input.action_release("move_forward")
	Game.state.stamina = 100.0

	player.queue_free()
	await host.get_tree().process_frame


## Sakrash: ko'tariladi, keyin yerga qaytadi. Pastki sakrash ham ishlaydi.
func _test_jump_and_land() -> void:
	var ground: float = TerrainGen.height_at(GROUND.x, GROUND.y)
	var player := _fresh_player(host, Vector3(GROUND.x, ground, GROUND.y))
	await _wait(SETTLE_FRAMES)

	# --- To'liq sakrash ---
	var ground_y := player.global_position.y
	var peak := ground_y

	Input.action_press("jump")
	# MUHIM: tepa nuqtasi ~19-kadrda. Agar biz tugmаni ushlab turganimizda
	# o'lchmay qo'yib, keyin o'lchashni boshlagan bo'lsak, tepa nuqtasi
	# allaqachon o'tib ketadi va sakrash "past" ko'rinadi.
	for _i in JUMP_HOLD_FRAMES:
		await host.get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	Input.action_release("jump")

	for _i in JUMP_FRAMES:
		await host.get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)

	_ok("To'liq sakrash balandligi", peak - ground_y, 0.95, 0.25)
	_check("Yerga qaytdi", player.is_on_floor(),
		"(is_on_floor = %s)" % player.is_on_floor())
	_ok("Yerda turgan y", player.global_position.y, ground_y, 0.25)

	# --- Pastki sakrash (tugma tez bo'shatilsa) ---
	await _wait(25)
	var low_start := player.global_position.y
	var low_peak := low_start
	Input.action_press("jump")
	for _i in 5:
		await host.get_tree().physics_frame
		low_peak = maxf(low_peak, player.global_position.y)
	Input.action_release("jump")
	for _i in 45:
		await host.get_tree().physics_frame
		low_peak = maxf(low_peak, player.global_position.y)

	var full_height := peak - ground_y
	var low_height := low_peak - low_start
	_check("Pastki sakrash to'liqidan past", low_height < full_height * 0.75,
		"(pastki %.2f m < to'liq %.2f m)" % [low_height, full_height])
	_check("Pastki sakrash ham baland", low_height > 0.15, "(%.2f m)" % low_height)
	await _wait(30)

	player.queue_free()
	await host.get_tree().process_frame


## Egilish: kamayadi, pastga sakramaydi, tepada to'sqinlik bo'lsa turmaydi.
func _test_crouch_and_ceiling() -> void:
	var ground: float = TerrainGen.height_at(GROUND.x, GROUND.y)
	var player := _fresh_player(host, Vector3(GROUND.x, ground, GROUND.y))
	await _wait(SETTLE_FRAMES)

	# --- Pastga sakramasligi kerak ---
	var y_before := player.global_position.y
	Input.action_press("crouch")
	await _wait(SETTLE_FRAMES)
	Input.action_press("jump")
	await _wait(20)
	Input.action_release("jump")
	await _wait(10)
	_check("Egilganda sakramadi", player.global_position.y <= y_before + 0.05,
		"(y: %.2f -> %.2f)" % [y_before, player.global_position.y])

	# Oyoq yerda qolishi kerak (kapsula markazi ko'tarilmasin)
	_ok("Egilganda oyog' yerda", player.global_position.y, ground, 0.25)
	_check("Egilgan holatda", player.crouching)

	# --- Tepada shift bilan ---
	var base := player.global_position
	var ceiling := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 0.4, 4)
	var col := CollisionShape3D.new()
	col.shape = shape
	ceiling.add_child(col)
	ceiling.collision_layer = PhysicsLayers.WORLD
	ceiling.position = base + Vector3(0, 1.45, 0)   # egilgan bosh (~1,05) ustida,
	host.add_child(ceiling)                           # tik bosh (~1,66) ostida
	await _wait(10)

	Input.action_release("crouch")
	await _wait(SETTLE_FRAMES)
	_check("Tepada to'sqinlik bo'lsa tik turmaydi", player.crouching,
		"(shift = %s)" % player.crouching)

	# Shiftni bo'shatamiz — tik turishi kerak
	ceiling.queue_free()
	Input.action_release("crouch")
	await _wait(SETTLE_FRAMES)
	_check("To'sqinlik yo'qolsa tik turadi", not player.crouching)

	player.queue_free()
	await host.get_tree().process_frame


## Qatlamlar to'g'ri: o'yinchi o'zi bilan to'qnashmaydi, lekin yerga uriladi.
func _test_collision_layers() -> void:
	var ground: float = TerrainGen.height_at(GROUND.x, GROUND.y)
	var player := _fresh_player(host, Vector3(GROUND.x, ground, GROUND.y))
	await _wait(SETTLE_FRAMES)

	_check("Qatlam = O'yinchi", player.collision_layer == PhysicsLayers.PLAYER,
		"(%s)" % PhysicsLayers.describe(player.collision_layer))
	_check("Maskada Yer bor", (player.collision_mask & PhysicsLayers.WORLD) != 0)
	_check("Maskada O'yinchi yo'q (o'zi bilan to'qnashmasin)",
		(player.collision_mask & PhysicsLayers.PLAYER) == 0,
		"(%s)" % PhysicsLayers.describe(player.collision_mask))
	_check("Yerga urildi (maska ishlayapti)", player.is_on_floor())

	player.queue_free()
	await host.get_tree().process_frame


# ------------------------------------------------------------------- Yordamchi

func _fresh_player(host: Node, position: Vector3) -> Player:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	var player := scene.instantiate() as Player
	host.add_child(player)
	player.teleport(position)
	player.set_mouse_sensitivity(0.0)   # sichqoncha javobini yo'q qilamiz
	Game.release_mouse()
	return player


func _wait(frames: int) -> void:
	for _i in frames:
		await Engine.get_main_loop().physics_frame
