extends Node3D
## O'yin ildizi. Dunyo, yorug'lik va o'yinchi shu yerda yig'iladi.
##
## HOVOQ: bu sahna 0-bosqich uchun ishga tayyor. Quyidagilar vaqtinchalik:
##   _DebugFlyCamera  — 1-bosqichda haqiqiy o'yinchi bilan almashtiriladi
##   _TemporaryGround — 2-bosqichda protsedural Xorazm relyefi bilan
## Undan keyin bu ikkalasi ham o'chiriladi.

const BAND_NORD := 900.0      ## qizil
const BAND_NORMAL := 700.0     ## sariq
const BAND_SOUTH := -700.0     ## ko'k

var _debug_fly: Node3D
var _hud: Label
var _hud_visible := false
var _help_visible := true


func _ready() -> void:
	# --- Xorazmning ertalabki yorug'ligi ---
	# Butun o'yin shu vaqtda — quyosh qimirlamaydi, GPU yuki kam qoladi.
	KhorezmMorning.install(self, Settings.draw_distance(), Settings.shadow_distance())

	# Vaqtinchalik tekis yer (2-bosqichda haqiqiy relyef bilan almashtiriladi)
	_add_temporary_ground()

	# Vaqtinchalik ko'rish kamerasi (1-bosqichda haqiqiy o'yinchi bilan)
	_debug_fly = DebugFlyCamera.new()
	_debug_fly.name = "Kamera"
	add_child(_debug_fly)

	_build_hud()
	_build_help()

	print_rich("[color=#d9a441]XORAZM[/color] — muhit tayyor. F1: yordam, F3: diagnostika")

	_parse_cli()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().quit()
	elif event.is_action_pressed("debug_overlay"):
		_hud_visible = not _hud_visible
		if _hud:
			_hud.visible = _hud_visible
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F1:
		_toggle_help()
	elif event.is_action_pressed("interact"):
		# Hovuq: xabar tizimini tekshirish
		EventBus.notify(Lang.txt("tarix.0"))


# ------------------------------------------------------------ Ishlab chiqarish

## Ekran suratini olish (dizayn va sifatlashni tekshirish uchun):
##     godot --path . -- --shot /tmp/shot.png
func _parse_cli() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot" and i + 1 < args.size():
			_capture(args[i + 1])
			return
		if args[i] == "--bench":
			_benchmark()
			return


## Ko'rsatkichlarni o'lchash — har bosqichdan keyin ishlatiladi.
##     godot --path . -- --bench
## Maqsad: 60 FPS (Intel UHD Graphics ICL GT1 da).
const BENCH_FRAMES := 400


func _benchmark() -> void:
	_debug_fly.global_position = Vector3(-1200, 9, -520)
	_debug_fly.rotation = Vector3(deg_to_rad(-4), deg_to_rad(-90), 0.0)

	# Ishga tushishi uchun 60 kadr kutamiz
	for _i in 60:
		await get_tree().process_frame

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
	print("Kadr:          %.1f FPS  (%.0f ms)" % [fps, elapsed * 1000.0 / BENCH_FRAMES])
	print("Chizqichlar:   %d / kadr" % (sum_draw / BENCH_FRAMES))
	print("Primitivlar:   %d / kadr" % (sum_tris / BENCH_FRAMES))
	print("Sifat:         %s (%.0f m, soya %.0f m)" % [
		Settings.quality_name(), Settings.draw_distance(), Settings.shadow_distance()
	])
	print("Oyna:          %d x %d" % [
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y
	])
	print("GPU:           %s" % RenderingServer.get_video_adapter_name())
	var verdict := "YAXSHI" if fps >= 55.0 else ("QONIQLI" if fps >= 35.0 else "SEKIN")
	print_rich("Xulosa:        [color=#%s]%s[/color] (maqsad 60)" % [
		"7fbf6a" if fps >= 55.0 else ("d9a441" if fps >= 35.0 else "c8452f"), verdict
	])
	print("")

	get_tree().quit()


func _capture(path: String) -> void:
	# Chiroyli ko'rinish uchun Tandirchi mahallasidan sharqqa qaraymiz
	# (quyosh ham aynan sharqda).
	_debug_fly.global_position = Vector3(-1200, 9, -520)
	_debug_fly.rotation = Vector3(deg_to_rad(-4), deg_to_rad(-90), 0.0)
	_hud.visible = false
	_help.visible = false

	# Bir necha kadr kutamiz — shaderlar va soya joylashishi maslahatgacha.
	for _i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print_rich("[color=#7fbf6a]Skrinshot[/color] %s — %d×%d (xato: %d)" % [
		path, image.get_width(), image.get_height(), err
	])
	get_tree().quit()


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

	# Rangi va qurilishi maksimal sodda — barcha vizual qarorlar
	# kelgusi bosqichlarga qoldiriladi.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.SAND
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var ground := MeshInstance3D.new()
	ground.name = "Yer"
	ground.mesh = mesh
	ground.material_override = mat
	ground.position = Vector3(0, 0, 0)
	add_child(ground)

	# Materiallar, soya va tuman masofasini tekshirish uchun obyektlar
	# (vaqtinchalik — 1-bosqichda o'chadi)
	var props := DebugProps.new()
	props.name = "SinovObyektlari"
	props.position = Vector3(-1170, 0, -520)
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
	var cam := _debug_fly.global_position
	var lines := PackedStringArray()
	lines.append("=== XORAZM · diagnostika ===")
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	lines.append("GPU: %s" % RenderingServer.get_video_adapter_name())
	lines.append("Renderer: %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	lines.append("Chizilgan primitiv: %d" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	lines.append("Chizqichlar soni: %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	lines.append("Video xotira: %.0f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	lines.append("Sifat: %s (ko'rish %.0f m)" % [Settings.quality_name(), Settings.draw_distance()])
	lines.append("Oyna: %d × %d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y])
	lines.append("----")
	lines.append("X: %.1f   Y: %.1f   Z: %.1f" % [cam.x, cam.y, cam.z])
	lines.append("Node'lar: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
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
	_help.text = """XORAZM — 0-bosqich (muhit)

WASD / Sichqoncha — ko'rish
Shift — tez, Ctrl — past
E — xabar sinovi
F3 — diagnostika
F1 — bu yordam
Esc — chiqish"""
	_help.visible = _help_visible
	layer.add_child(_help)


func _toggle_help() -> void:
	_help.visible = not _help.visible
