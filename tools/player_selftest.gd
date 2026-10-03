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

const SETTLE_FRAMES := 30
const WALK_FRAMES := 45
const JUMP_FRAMES := 90
## To'liq sakrash uchun tugmani cho'qqa qadar ushlab turish kerak
## (JUMP_CUT ishi sabab). ~0,5 s yetarli.
const JUMP_HOLD_FRAMES := 32

## Bu sahnaga qo'shiladigan NODE bo'lishi SHART: RefCounted bo'lsa,
## `await` qilingandan keyin obyekt bo'shilib ketadi va tekshiruv
## jimgina to'xtab qoladi (RefCounted signalga obyektni ushlab turmaydi).

var host: Node

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run()


func _run() -> void:
	print_rich("\n[b]=== O'YINCHI O'Z-IJNI TEKSHIRUVI ===[/b]")

	await _test_gravity_and_rest()
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
	# Chiqish kodi: 0 = hammasi o'tdi (terminal/CI uchun)
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
	# 6 m dan tushirish — 1,3 sekund yetarli. 40 m dan tushirsak,
	# chegara oshib ketadi va test hamma narsa "hali tushmagan" bo'lib chiqadi.
	var player := _fresh_player(host, Vector3(0, 6, 0))
	await _wait(SETTLE_FRAMES * 4)

	# O'yinchi ILDIZI oyoqda turadi (shakl markazi 0,90 da), shuning uchun
	# yerga qo'naygan holatda y = 0 bo'lishi kerak.
	_ok("Yerga qo'naydi", player.global_position.y, 0.0, 0.12)
	_check("Yerda turibdi", player.is_on_floor(),
		"(is_on_floor = %s)" % player.is_on_floor())

	# X, Z silinishi bo'lmasligi kerak
	_check("X silinmadi", absf(player.velocity.x) < 0.01)
	_check("Z silinmadi", absf(player.velocity.z) < 0.01)

	player.queue_free()
	await host.get_tree().process_frame


## Yurish yo'nalishi: W bosilganda kamera qaragan tomonga.
func _test_walk_direction() -> void:
	var player := _fresh_player(host, Vector3(0, 0, 0))
	# Sharqqa qarayapti (yaw -90)
	player.teleport(Vector3(0, 1.0, 0), -90.0, 0.0)
	await _wait(SETTLE_FRAMES)

	var start := player.global_position
	Input.action_press("move_forward")
	await _wait(WALK_FRAMES)
	Input.action_release("move_forward")
	await _wait(5)

	var moved := player.global_position - start
	_check("Oldinga yurdi (sharqqa)", moved.x > 3.0,
		"(Δx = %.2f, Δz = %.2f)" % [moved.x, moved.z])
	_check("Z o'qi bo'yicha chetlash kam", absf(moved.z) < moved.x * 0.25,
		"(Δz = %.2f)" % moved.z)

	player.queue_free()
	await host.get_tree().process_frame


## Shift bilan yugurish tezroq va kuch sarflaydi.
func _test_sprint_speed() -> void:
	var player := _fresh_player(host, Vector3(0, 0, 0))
	player.teleport(Vector3(0, 1.0, 0), -90.0, 0.0)
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
	var player := _fresh_player(host, Vector3(0, 0, 0))
	await _wait(SETTLE_FRAMES)

	# --- To'liq sakrash ---
	var ground_y := player.global_position.y
	var peak := ground_y

	Input.action_press("jump")
	# MUHIM: tepa nuqtasi ~19-kadrda. Agar biz tugmаni ushlab turganimizda
	# o'lchmay qo'yib, keyin o'lchashni boshlagan bo'lsak, tepa nuqtasi
	# allaqachon o'tib ketadi va sakrash "past" ko'rinadi.
	# Shuning uchun har BIR kadrda balandlikni yozib boramiz.
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
	_ok("Yerda turgan y", player.global_position.y, ground_y, 0.15)

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
	var player := _fresh_player(host, Vector3(0, 0, 0))
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

	_check("Egilgan holatda", player.crouching)

	# --- Tepada shift bilan ---
	var ceiling := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 0.4, 4)
	var col := CollisionShape3D.new()
	col.shape = shape
	ceiling.add_child(col)
	ceiling.collision_layer = PhysicsLayers.WORLD
	ceiling.position = Vector3(0, 1.45, 0)   # egilgan bosh (~1,05) ustida,
	host.add_child(ceiling)                   # tik bosh (~1,66) ostida
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
	var player := _fresh_player(host, Vector3(0, 0, 0))
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
	player.set_mouse_sensitivity(0.0)   # sichqoncha javobini yoq qilamiz
	Game.release_mouse()
	return player


func _wait(frames: int) -> void:
	for _i in frames:
		await Engine.get_main_loop().physics_frame
