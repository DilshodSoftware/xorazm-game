extends Node3D
## O'yin ildizi. Dunyo, yorug'lik va o'yinchi shu yerda yig'iladi.
##
## HOVOQ: 0- va 1-bosqich uchun ishga tayyor. Quyidagilar vaqtinchalik:
##   _add_temporary_ground() — 2-bosqichda protsedural Xorazm relyefi bilan
##   DebugProps              — 1-bosqichda tandirchi haqiqiy uyi bilan
## Ularning ikkalasi ham keyingi bosqichda o'chiriladi.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## Sinov skriptlari uchun qarash nuqtasi: Tandirchi mahallasi,
## sharqqa qarab (quyosh ham aynan sharqda).
const SHOT_POSITION := Vector3(-1196.0, 1.2, -452.0)
const SHOT_YAW := -90.0
const SHOT_PITCH := -4.0

var _player: Player
var _hud: Label
var _hud_visible := false


func _ready() -> void:
	# --- Xorazmning ertalabki yorug'ligi ---
	# Butun o'yin shu vaqtda — quyosh qimirlamaydi, GPU yuki kam qoladi.
	KhorezmMorning.install(self, Settings.draw_distance(), Settings.shadow_distance())

	# Vaqtinchalik tekis yer (2-bosqichda haqiqiy relyef bilan)
	_add_temporary_ground()

	_spawn_player()

	_build_hud()
	_build_help()

	print_rich("[color=#d9a441]XORAZM[/color] — %s" % Lang.txt("tarix.0"))
	print_rich("[color=#7fbf6a]Boshqaruv:[/color] F1 yordam · F3 diagnostika")

	_parse_cli()


## O'yinchini Tandirchi mahallasida, uy oldida o'rnatadi.
func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	_player.teleport(WorldMap.PLAYER_SPAWN, SHOT_YAW, SHOT_PITCH)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_hud_visible = not _hud_visible
		if _hud:
			_hud.visible = _hud_visible
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F1:
		_toggle_help()


func _process(_delta: float) -> void:
	if _hud_visible and _hud:
		_hud.text = _diagnostics()


# ----------------------------------------------------------------- Vaqtinchalik

func _add_temporary_ground() -> void:
	# 30 km — tuman chegarasidan juda uzoq. Shuning uchun yerning chekkasi
	# ko'rinmaydi va osmon bilan tabiiy birikadi. Ikki uchburchak, arzon.
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(30_000, 30_000)
	mesh.subdivide_width = 1
	mesh.subdivide_depth = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.SAND
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var ground := MeshInstance3D.new()
	ground.name = "Yer"
	ground.mesh = mesh
	ground.material_override = mat
	add_child(ground)

	# Yer ostida tekis collision — o'yinchi va mashina yerga tushsin.
	var shape := BoxShape3D.new()
	shape.size = Vector3(30_000, 20, 30_000)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, -10, 0)

	var body := StaticBody3D.new()
	body.name = "YerKolpasi"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.add_child(col)
	add_child(body)

	# Materiallar, soya va tuman masofasini tekshirish uchun obyektlar
	# (vaqtinchalik — 1-bosqich oxirida o'chadi)
	var props := DebugProps.new()
	props.name = "SinovObyektlari"
	props.position = Vector3(-1161, 0, -457)
	add_child(props)


# ------------------------------------------------------------------------ HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 14)
	_hud.add_theme_color_override("font_color", Palette.UI_TEXT)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	_hud.visible = false
	layer.add_child(_hud)


func _diagnostics() -> String:
	var lines := PackedStringArray()
	lines.append("=== XORAZM · diagnostika ===")
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	lines.append("GPU: %s" % RenderingServer.get_video_adapter_name())
	lines.append("Primitiv: %d   Chizqich: %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	])
	lines.append("Video RAM: %.0f MB" % (
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	lines.append("Sifat: %s (ko'rish %.0f m, soya %.0f m)" % [
		Settings.quality_name(), Settings.draw_distance(), Settings.shadow_distance()
	])
	lines.append("Oyna: %d x %d" % [
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y
	])
	lines.append("----")
	if _player:
		var p := _player.global_position
		lines.append("X: %.1f  Y: %.2f  Z: %.1f" % [p.x, p.y, p.z])
		lines.append("Tezlik: %.2f m/s   Yerga teggan: %s" % [
			_player.horizontal_speed(), "ha" if _player.is_on_floor() else "yo'q"
		])
		lines.append("Egilgan: %s   Yugurish: %s   Kuch: %.0f" % [
			_player.crouching, _player.sprinting, Game.state.stamina
		])
		lines.append("Qatlam: %d (mask: %s)" % [
			_player.collision_layer, PhysicsLayers.describe(_player.collision_mask)
		])
		lines.append("Taxminiy shahar: %s" % WorldMap.nearest_city(p))
	return "\n".join(lines)


var _help: Label

func _build_help() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	_help = Label.new()
	_help.position = Vector2(24, 24)
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_color", Palette.UI_TEXT)
	_help.add_theme_color_override("font_outline_color", Color.BLACK)
	_help.add_theme_constant_override("outline_size", 5)
	_help.text = "XORAZM — 1-bosqich (o'yinchi)

WASD          — yurish
Shift         — yugurish (kuch sarflanadi)
Ctrl / C      — egilish
Space         — sakrash
Sichqoncha    — ko'rish
E             — (2-bosqich: eshik / mashina)
F             — (5-bosqich: mashinaga minish)

F1 — bu yordam      F3 — diagnostika
Esc — chiqish"
	layer.add_child(_help)


func _toggle_help() -> void:
	_help.visible = not _help.visible


# ------------------------------------------------------------ Ishlab chiqarish

## Ekran surati olish:
##     godot --path . -- --shot /tmp/shot.png
## Ko'rsatkichlarni o'lchash:
##     godot --path . -- --bench
func _parse_cli() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot" and i + 1 < args.size():
			_capture(args[i + 1])
			return
		if args[i] == "--bench":
			_benchmark()
			return
		if args[i] == "--test":
			var test := PlayerSelfTest.new()
			test.host = self
			add_child(test)
			return


const CAPTURE_FRAMES := 40
const BENCH_FRAMES := 400


func _capture(path: String) -> void:
	_player.teleport(SHOT_POSITION, SHOT_YAW, SHOT_PITCH)
	_hud.visible = false
	_help.visible = false
	await _settle(CAPTURE_FRAMES)

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print_rich("[color=#7fbf6a]Skrinshot[/color] %s — %d×%d (xato: %d)" % [
		path, image.get_width(), image.get_height(), err
	])
	get_tree().quit()


func _benchmark() -> void:
	_player.teleport(SHOT_POSITION, SHOT_YAW, SHOT_PITCH)
	await _settle(60)

	var start := Time.get_ticks_usec()
	var sum_draw := 0
	var sum_tris := 0
	for _i in BENCH_FRAMES:
		await get_tree().process_frame
		sum_draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sum_tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var elapsed := (Time.get_ticks_usec() - start) / 1_000_000.0

	var fps := BENCH_FRAMES / maxf(elapsed, 0.001)
	print_rich("\n[b]=== O'LCHOV ===[/b]")
	print("Kadr:        %.1f FPS  (%.1f ms)" % [fps, elapsed * 1000.0 / BENCH_FRAMES])
	print("Chizqichlar: %d / kadr" % (sum_draw / BENCH_FRAMES))
	print("Primitivlar: %d / kadr" % (sum_tris / BENCH_FRAMES))
	print("Sifat:       %s (%.0f m, soya %.0f m)" % [
		Settings.quality_name(), Settings.draw_distance(), Settings.shadow_distance()
	])
	print("Oyna:        %d x %d" % [
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y
	])
	print("GPU:         %s" % RenderingServer.get_video_adapter_name())
	var color: String = "7fbf6a" if fps >= 55.0 else ("d9a441" if fps >= 35.0 else "c8452f")
	print_rich("Xulosa:      [color=#%s]%s[/color] (maqsad 60)" % [
		color, "YAXSHI" if fps >= 55.0 else ("QONIQLI" if fps >= 35.0 else "SEKIN")
	])
	print("")
	get_tree().quit()


## Kadr o'tishi uchun kutish — renderlash va soya joylashishi maslahatgacha.
func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
