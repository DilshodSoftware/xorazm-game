extends Node3D
## O'yin ildizi. Dunyo, yorug'lik va o'yinchi shu yerda yig'iladi.
##
## HOVOQ: 2-bosqich (Xorazm relyefi) ishga tushdi — vaqtinchalik tekis yer
## olib tashlandi, uni ChunkManager va TerrainGen almashtirdi.
## 3-bosqichda vaqtinchalik DebugProps olib tashlandi — endi Tandirchi
## mahallasining haqiqiy uylari bor.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## Sinov skriptlari uchun qarash nuqtasi: Tandirchi mahallasi,
## sharqqa qarab (quyosh ham aynan sharqda).
const SHOT_YAW := -90.0
const SHOT_PITCH := -4.0

var player: Player
var chunks: ChunkManager
var buildings: BuildingManager
var player_house: Dictionary = {}
var traffic: Traffic
var driver: PlayerCar
var player_vehicle: Vehicle = null
var _hud: Label
var _prompt: Label
var _speedo: Label
var _hud_visible := false


func _ready() -> void:
	# --- Xorazmning ertalabki yorug'ligi ---
	# Butun o'yin shu vaqtda — quyosh qimirlamaydi, GPU yuki kam qoladi.
	KhorezmMorning.install(self, Settings.draw_distance(), Settings.shadow_distance())

	_build_world()
	_spawnplayer()

	_build_hud()
	_build_help()

	print_rich("[color=#d9a441]XORAZM[/color] — %s" % Lang.txt("tarix.0"))
	print_rich("[color=#7fbf6a]Yo'llar:[/color] %d ta, jami %.1f km" % [
		RoadNetwork.roads().size(), RoadNetwork.total_length() / 1000.0])
	print_rich("[color=#7fbf6a]Tandirchi:[/color] %d ta ko'cha, %d ta uy joyi" % [
		Tandirchi.streets().size(), Tandirchi.plots().size()])

	print_rich("[color=#7fbf6a]Boshqaruv:[/color] F1 yordam · F3 diagnostika")
	print_rich("[color=#d9a441]Eshik:[/color] uy oldida E bosing — peshenta va xona eshiklari ochiladi")
	if not player_house.is_empty():
		var doors: Array = player_house.get("eshiklar", [])
		for i in doors.size():
			var d := doors[i] as HouseDoor
			print_rich("  [color=#a89d8a]eshik %d: (%.1f, %.1f)[/color]" % [
				i, d.global_position.x, d.global_position.z])
		var inner: Vector3 = player_house.get("ichki", Vector3.ZERO)
		print_rich("  [color=#a89d8a]uy markazi: (%.1f, %.1f)[/color]" % [
			inner.x, inner.z])

	_parse_cli()


## Xorazm vohasi: protsedural yer, suv, yo'llar va sinov obyektlari.
func _build_world() -> void:
	chunks = ChunkManager.new()
	chunks.name = "Yer"
	add_child(chunks)

	add_child(WaterSurface.new())

	# Yo'llar. RoadNetwork avval yer ostini tekislaydi (TerrainGen ichida),
	# shuning uchun bu qator MUTLAQ chunndan keyin kelishi shart: lentalar
	# allaqon tekislangan yerga o'tiradi va hech qachon havoda suzmaydi.
	RoadBuilder.build(self)

	# Tandirchi mahallasi. Binolar ham, xuddi yer kabi, chunk bo'yicha
	# yuklanadi — 190 uyni bir vaqtda qursak, zayif GPU uchun og'ir.
	buildings = BuildingManager.new()
	buildings.name = "Binolar"
	add_child(buildings)

	# O'yinchi uyi alohida quriladi: ichiga kiriladi, ichida yorug'lik
	# va mebeller bor. Oddiy generator undan keyin keladi va o'sha uyni
	# qayta quradi — shuning uchun bu tartib MUTLAQ.
	player_house = PlayerHouse.build(self, OS.get_cmdline_user_args().has("--inspect"))

	# --- Mashinalar ---
	# Avval trafik, keyin o'yinchi mashinasi: aks holda o'yinchi
	# mashinasi AI mashinalari orasida qolib ketishi mumkin.
	traffic = Traffic.new()
	add_child(traffic)

	driver = PlayerCar.new()
	add_child(driver)


## O'yinchini Tandirchi mahallasida, uy oldida o'rnatadi.
func _spawnplayer() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.teleport(WorldMap.spawn_position(), SHOT_YAW, SHOT_PITCH)

	# ChunkManager o'yinchiga bog'lanadi — u har kadrda o'z atrofiga
	# chunklarni yuklab oladi (main.gd ga bog'liq emas).
	chunks.target = player
	chunks.force_load_all(player.global_position)

	# Binolar ham o'yinchiga bog'lanadi va darhol yuklanadi — teleportdan
	# keyin bino ostida bir necha kadr bo'sh qolmasligi uchun.
	buildings.target = player
	buildings.force_load_all(player.global_position)

	# --- Mashinalar ---
	# O'yinchi mashinasi uy oldiga, ko'cha chetiga qo'yiladi:
	# Kosiblar ko'chasi. Odatda Nexia — Xorazmda eng ko'p uchraydigan
	# va arzon mashina.
	player_vehicle = _spawn_player_vehicle()
	traffic.follow(player)
	# Boshida mashinalar darhol ko'rinsin (bir kadr kutmasdan)
	traffic.force_refresh()


## Ko'cha chetida, o'yinchi uyiga yaqin joyda haydana oladigan
## mashina qo'yadi.
func _spawn_player_vehicle() -> Vehicle:
	var car := Vehicle.create("nexia", Palette.CAR_WHITE, true)
	add_child(car)
	var here := Vector2(player.global_position.x, player.global_position.z)
	var spot := Traffic.kerbside_near(here)
	var pos: Vector2 = spot["pos"]
	car.global_position = Vector3(pos.x, TerrainGen.height_at(pos.x, pos.y),
		pos.y)
	car.rotation.y = float(spot["yaw"])
	_attach_vehicle_zone(car)
	return car


## Mashinaga E bilan minish uchun zona.
func _attach_vehicle_zone(car: Vehicle) -> void:
	var zone := Interactable.new()
	zone.name = "Minish"
	zone.label_key = "amal.minish"
	zone.prompt = Lang.txt(String(car.spec["nom"]))
	zone.action = "drive"
	zone.fired.connect(func(_who: Node3D) -> void: _enter_vehicle(car))
	car.add_child(zone)


## Mashinaga o'tadi (F yoki E).
func _enter_vehicle(car: Vehicle) -> void:
	if driver == null or driver.vehicle != null:
		return
	if car == null or car == driver.vehicle:
		return
	if not car.physics_driven:
		return
	driver.take_control(car, player)
	if _speedo:
		_speedo.visible = true


## Mashinadan tushadi (F).
func _exit_vehicle() -> void:
	if driver == null or driver.vehicle == null:
		return
	driver.release()
	if _speedo:
		_speedo.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_hud_visible = not _hud_visible
		if _hud:
			_hud.visible = _hud_visible
	elif event.is_action_pressed("vehicle_enter_exit"):
		if driver != null and driver.vehicle != null:
			_exit_vehicle()
		elif player_vehicle != null:
			_enter_vehicle(player_vehicle)
	elif event.is_action_pressed("horn") and driver != null \
			and driver.vehicle != null:
		driver.vehicle.horn_pressed.emit(player)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F1:
		_toggle_help()


func _process(_delta: float) -> void:
	if _hud_visible and _hud:
		_hud.text = _diagnostics()
	# Oyna o'yni ekran pastki markazida ushlab turadi
	var size := get_viewport().get_visible_rect().size
	if _prompt != null and _prompt.visible:
		_prompt.size = Vector2(size.x, 0)
		_prompt.position = Vector2(0, size.y - 130)
	if _speedo != null and _speedo.visible:
		_speedo.size = Vector2(240, 60)
		_speedo.position = Vector2(size.x - 256, size.y - 92)


func _on_interact_shown(text: String) -> void:
	if _prompt != null:
		_prompt.text = text
		_prompt.visible = true


func _on_interact_hidden() -> void:
	if _prompt != null:
		_prompt.visible = false


## Tezlik o'lchagini yangilaydi va ekranning o'ng pastiga joylaydi.
func _on_speed_changed(kmh: float) -> void:
	if _speedo == null:
		return
	var size := get_viewport().get_visible_rect().size
	_speedo.size = Vector2(240, 60)
	_speedo.position = Vector2(size.x - 256, size.y - 92)
	# Butun son — o'yinchi uchun 0…200 oralig'i kerak, kasr kerak emas
	_speedo.text = "%d\n%s" % [int(round(kmh)), Lang.txt("hud.kmo_soat")]


# ------------------------------------------------------------------------ HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	# --- Muloqot oynasi (E tugmasi) ---
	_prompt = Label.new()
	_prompt.name = "Muloqot"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Palette.UI_TEXT)
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	layer.add_child(_prompt)

	# Hodisa oynani boshqaradi
	EventBus.interact_shown.connect(_on_interact_shown)
	EventBus.interact_hidden.connect(_on_interact_hidden)

	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 14)
	_hud.add_theme_color_override("font_color", Palette.UI_TEXT)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	_hud.visible = false
	layer.add_child(_hud)

	# --- Tezlik o'lchag ---
	# O'ng pastda, katta raqam bilan. Haydash paytida paydo bo'ladi.
	_speedo = Label.new()
	_speedo.name = "Tezlik"
	_speedo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speedo.add_theme_font_size_override("font_size", 44)
	_speedo.add_theme_color_override("font_color", Palette.UI_ACCENT)
	_speedo.add_theme_color_override("font_outline_color", Color.BLACK)
	_speedo.add_theme_constant_override("outline_size", 6)
	_speedo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speedo.visible = false
	layer.add_child(_speedo)
	if driver != null:
		driver.speed_changed.connect(_on_speed_changed)


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
	if player:
		var p := player.global_position
		lines.append("X: %.1f  Y: %.2f  Z: %.1f" % [p.x, p.y, p.z])
		lines.append("Tezlik: %.2f m/s   Yerga teggan: %s" % [
			player.horizontal_speed(), "ha" if player.is_on_floor() else "yo'q"
		])
		lines.append("Egilgan: %s   Yugurish: %s   Kuch: %.0f" % [
			player.crouching, player.sprinting, Game.state.stamina
		])
		lines.append("Taxminiy shahar: %s" % WorldMap.nearest_city(p))
	if chunks:
		lines.append("Chunklar: %d (jami %d)" % [
			chunks.loaded_count(), chunks.generated_total()
		])
		lines.append("---")
		lines.append("Chunk: 400 m · Radius %d" % Settings.load_radius())
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
		if args[i] == "--aerial" and i + 1 < args.size():
			_capture_aerial(args[i + 1])
			return
		if args[i] == "--at" and i + 1 < args.size():
			_capture_at(
				args[i + 1],
				args[i + 2] if i + 2 < args.size() else "",
				args[i + 3] if i + 3 < args.size() else "",
				args[i + 4] if i + 4 < args.size() else "",
				args[i + 5] if i + 5 < args.size() else ""
			)
			return
		if args[i] == "--nofog" and i + 1 < args.size():
			_clear_fog(true)
			_hide_water(true)
			_capture(args[i + 1])
			return
		if args[i] == "--nowater" and i + 1 < args.size():
			_hide_water(true)
			_capture(args[i + 1])
			return
		if args[i] == "--test-roads":
			var road_test := RoadSelfTest.new()
			road_test.host = self
			add_child(road_test)
			return
		if args[i] == "--terrainmap" and i + 1 < args.size():
			TerrainMap.render(args[i + 1])
			get_tree().quit(0)
			return
		if args[i] == "--door" and i + 1 < args.size():
			_capture_door(args[i + 1], args[i + 2] if i + 2 < args.size() else "open")
			return
		if args[i] == "--inspect" and i + 1 < args.size():
			_inspect(args[i + 1])
			return
		if args[i] == "--cars" and i + 1 < args.size():
			_preview_cars(args[i + 1], args[i + 2] if i + 2 < args.size() else "")
			return
		if args[i] == "--car" and i + 2 < args.size():
			_preview_car(args[i + 1], args[i + 2],
				args[i + 3] if i + 3 < args.size() else "")
			return
		if args[i] == "--test-vehicles":
			var vehicle_test := VehicleSelfTest.new()
			vehicle_test.host = self
			add_child(vehicle_test)
			return
		if args[i] == "--test-mesh":
			var mesh_test := MeshSelfTest.new()
			add_child(mesh_test)
			return
		if args[i] == "--test-buildings":
			var building_test := BuildingSelfTest.new()
			building_test.host = self
			add_child(building_test)
			return
		if args[i] == "--testhouse" and i + 1 < args.size():
			_capture_testhouse(args[i + 1])
			return
		if args[i] == "--probe" and i + 1 < args.size():
			_probe(args[i + 1])
			return
		if args[i] == "--bench":
			_benchmark()
			return
		if args[i] == "--test":
			var test := PlayerSelfTest.new()
			test.host = self
			add_child(test)
			return
		if args[i] == "--test-terrain":
			var terrain_test := TerrainSelfTest.new()
			terrain_test.host = self
			add_child(terrain_test)
			return


## Barcha mashina modellari bir qatorga qo'yilib suratga olinadi.
##     godot --path . -- --cars /tmp/mashinalar.png
##     godot --path . -- --cars /tmp/orqa.png orqa
##
## Nima uchun alohida rejim: protsedural kuzov faqat ko'z bilan
## tekshiriladi. O'lchamlar to'g'ri, lekin siluet noto'g'ri bo'lsa
## (masalan shift oynasi baland yoki baland emas) — testlar buni
## ushlaydi, lekin "mashina deb o'ylayotgan" narsani faqat rasmda
## ko'rish mumkin. Shu uchun har bir model yonidan (profil) va
## oldindan (3/4) ko'rsatiladi.
##
## Ikkinchi argument — qaysi tomondan: "yoni" (sukut bo'lgani) yoki
## "oldi".
func _preview_cars(path: String, view: String) -> void:
	var pad := CarPreview.find_pad()
	var row := CarPreview.build_row(self, pad)
	if row.is_empty():
		print_rich("[color=#c8452f]Mashinalar qurilmadi[/color]")
		get_tree().quit(2)
		return

	var front: bool = view == "oldi"
	var cam: Camera3D = player.rig.camera
	if cam:
		cam.far = 300.0
		cam.fov = 66.0
	# Qator markazi — kamera shunga QARAB qarashi SHART. Avval kamera
	# qatorning yonidan o'tkazilib, "nishon" esa o'sha yon edi:
	# natijada mashinalar ko'rish maydonidan tashqarida qoldi.
	var span := 0.0
	for spec: Dictionary in CarSpecs.all():
		span += float(spec["uzunlik"]) + CarPreview.GAP
	var centre := pad + Vector3(span * 0.5 - CarPreview.GAP * 0.5, 0.0, 0.0)
	var eye: Vector3 = centre + (Vector3(15.0, 0.0, -17.0) if front
		else Vector3(0.0, 0.0, -16.0))
	var target: Vector3 = centre
	var direction: Vector3 = target - eye
	var yaw: float = rad_to_deg(atan2(-direction.x, -direction.z))
	var height: float = 1.9 if front else 2.4
	var look := Vector3(eye.x, TerrainGen.height_at(eye.x, eye.z) + height, eye.z)
	player.teleport(look, yaw, -5.0 if not front else -8.0)
	await _settle(CAPTURE_FRAMES)
	player.teleport(look, yaw, -5.0 if not front else -8.0)
	await _settle(2)
	print_rich("[color=#7fbf6a]Modellar:[/color] %d ta, ko'rinish: %s, pad (%.0f, %.0f)" % [
		row.size(), "oldi" if front else "yoni", pad.x, pad.z])
	_save_shot(path)


## Bitta modelni 7 metrdan ko'rish — siluetni tekshirish uchun.
##     godot --path . -- --car spark /tmp/spark.png
##     godot --path . -- --car marshrutka /tmp/m.png orqa
func _preview_car(model: String, path: String, view: String = "") -> void:
	var pad := CarPreview.find_pad()
	var spec := CarSpecs.find(model)
	CarPreview.build_one(self, pad, model, CarPreview.pick_colour(spec))
	var rear: bool = view == "orqa"
	# 3/4 ko'rinish: yon profil va oldingi yuzaning egri chizig'i bir
	# vaqtda ko'rinadi — siluetni tekshirish uchun eng maqul burchak
	var offset := Vector3(4.6, 0.0, -4.2)
	if rear:
		offset = Vector3(-4.6, 0.0, 4.2)
	if view == "yoni":
		offset = Vector3(0.0, 0.0, -5.6)
	var eye: Vector3 = pad + offset
	var target: Vector3 = pad + Vector3(0.0, float(spec["balandlik"]) * 0.45, 0.0)
	var direction: Vector3 = target - eye
	var yaw: float = rad_to_deg(atan2(-direction.x, -direction.z))
	var cam: Camera3D = player.rig.camera
	if cam:
		cam.far = 120.0
		cam.fov = 58.0
	var look := Vector3(eye.x, TerrainGen.height_at(eye.x, eye.z) + 1.05, eye.z)
	player.teleport(look, yaw, -8.0)
	await _settle(CAPTURE_FRAMES)
	player.teleport(look, yaw, -8.0)
	await _settle(2)
	print_rich("[color=#7fbf6a]Model:[/color] %s (%.2f × %.2f × %.2f m)" % [
		Lang.txt(String(spec["nom"])), float(spec["uzunlik"]),
		float(spec["kenglik"]), float(spec["balandlik"])])
	_save_shot(path)


## Eshikning oldidan surat — "open" yoki "yopiq".
##     godot --path . -- --door /tmp/eshik.png open
## DIQQAT: eshikni OCHIB, bir necha kadr kutamiz — shunda rasmda
## burilgan holati ko'rinadi (avvalgi xatoda `is_open()` true bo'lib,
## eshik 0° da turgandi).
func _capture_door(path: String, state: String) -> void:
	var doors: Array = player_house.get("eshiklar", [])
	if doors.is_empty():
		_save_shot(path)
		return
	var door := doors[0] as HouseDoor
	if state == "open":
		door.set_open(true)

	# Eshikning oldida, ichkariga qaragan tomonda
	var into: Vector3 = Vector3(sin(door.rotation.y), 0, cos(door.rotation.y))
	var eye: Vector3 = door.global_position - into * 2.4 + into * 0.6 \
		+ Vector3(0, 1.7, 0)
	var ground: float = TerrainGen.height_at(eye.x, eye.z)
	var look: Vector2 = Vector2(door.global_position.x - eye.x,
		door.global_position.z - eye.z).normalized()
	var spot := Vector3(eye.x, ground + 1.7, eye.z)
	var yaw := rad_to_deg(atan2(-look.x, -look.y))
	player.teleport(spot, yaw, -8.0)
	await _settle(CAPTURE_FRAMES)
	player.teleport(spot, yaw, -8.0)
	await _settle(3)
	_save_shot(path)


## Uyni shimolasiz qurib, ichini yuqoridan ko'rsatadi — mebel
## joylashuvini bir qarashda tekshirish uchun.
##     godot --path . -- --inspect /tmp/ichi.png
func _inspect(path: String) -> void:
	var plot := Tandirchi.player_plot()
	var centre: Vector2 = plot["markaz"]
	var yaw: float = plot["yaw"]
	var basis := Basis(Vector3.UP, yaw)

	# Xona markazi — maydon o'rtasidan uy orqasiga chuqurlik/2 + ROOM_DEPTH/2
	var front: float = plot["front"]
	var depth: float = plot["chuqur"]
	var room_v: float = depth - CourtyardHouse.ROOM_DEPTH * 0.5
	var room := Vector3(centre.x, 0.0, centre.y) + basis * Vector3(0.0, 0.0, room_v)

	# Kamera xona ustida — rejali (flat) ko'rinish
	var eye := room + Vector3(0.0, 25.0, 0.0) + basis * Vector3(0.0, 0.0, 10.0)
	var ground: float = TerrainGen.height_at(eye.x, eye.z)
	var look := Vector2(room.x - eye.x, room.z - eye.z).normalized()
	var spot := Vector3(eye.x, ground + 25.0, eye.z)
	var cam_yaw := rad_to_deg(atan2(-look.x, -look.y))
	player.teleport(spot, cam_yaw, -75.0)
	await _settle(CAPTURE_FRAMES)
	player.teleport(spot, cam_yaw, -75.0)
	await _settle(3)
	_save_shot(path)


## YALG'IZ bitta uyni qurib, uni ma'lum nuqtadan suratga oladi.
## Uyni qayta-qayta tuzatish kerak bo'lganda shu vosita ishlatiladi —
## aks holda har safar mahallada kamera burchagini qidirib topish
## kerak bo'lardi.
##     godot --path . -- --testhouse /tmp/uy.png
func _capture_testhouse(path: String) -> void:
	var centre := WorldMap.TANDIRCHI + Vector2(-150.0, -150.0)
	var builder := MeshBuilder.new()
	builder.want_collision = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	CourtyardHouse.build(builder, centre, deg_to_rad(18.0), 12.5, 15.0, 2,
		rng, CourtyardHouse.Style.MODERN)

	print_rich("[color=#d9a441]SINOV UYI:[/color] %d uchburchak, %d cho'qqa" % [
		builder.triangle_count(), builder.vertices.size()])

	var holder := Node3D.new()
	holder.name = "SinovUyi"
	add_child(holder)
	builder.commit(holder, "Mesh")
	builder.commit_collision(holder, "Kolpasi")

	# Ko'chadan, odam balandligida — Xorazm ko'chasidan ko'rinadigan
	# ko'rinish. Bu eng muhim ko'rinish: o'yinchi har kuni shuni ko'radi.
	var forward := Vector2(sin(deg_to_rad(18.0)), cos(deg_to_rad(18.0)))
	var eye: Vector2 = centre - forward * 9.5
	var ground: float = TerrainGen.height_at(eye.x, eye.y)
	var look: Vector2 = (centre - eye).normalized()
	var yaw: float = rad_to_deg(atan2(-look.x, -look.y))
	# DIQQAT: ikkinchi teleport BIR XIL burchak bilan bo'lishi shart.
	# Avval ikkinchisida qiyofa boshqa qiymatga tushib, kamera gorizontal
	# qaragan va uyning ichi ko'rinmagan.
	var pitch := 4.0
	var spot := Vector3(eye.x, ground + 2.7, eye.y)
	player.teleport(spot, yaw, pitch)
	await _settle(CAPTURE_FRAMES)
	player.teleport(spot, yaw, pitch)
	await _settle(3)
	_save_shot(path)


## Nuqtaning balandligi va suv holatini chiqaradi. Yo'l tekislashining
## natijasini tekshirish uchun qulay.
##     godot --headless --path . -- --probe -745,180
func _probe(where: String) -> void:
	for one: String in where.split(";"):
		var parts := one.split(",")
		if parts.size() < 2:
			continue
		var x := parts[0].to_float()
		var z := parts[1].to_float()
		var raw: float = TerrainGen._base_height(x, z)
		var flat: float = TerrainGen.height_at(x, z)
		var water: float = TerrainGen.water_level_at(x, z)
		var road := RoadNetwork.nearest_road_point(Vector2(x, z))
		print_rich("(%.0f, %.0f)  xom=%.2f m  tekis=%+.2f m  suv=%.2f m  %s  yo'l=%s (%.1f m)" % [
			x, z, raw, flat, water,
			"suv ostida" if flat < water else "quruq",
			road["yo'l"], road["masofa"]])
	get_tree().quit(0)


const CAPTURE_FRAMES := 40
const BENCH_FRAMES := 400


func _capture(path: String) -> void:
	player.teleport(WorldMap.spawn_position(), SHOT_YAW, SHOT_PITCH)
	await _settle(10)
	_save_shot(path)


## Ko'tarilgan ko'rinish: relyef, kanallar, Amudaryo ko'rinadi.
##     godot --path . -- --aerial /tmp/a.png
func _capture_aerial(path: String) -> void:
	var spot := Vector3(-300.0, 300.0, -1500.0)
	player.teleport(spot, -75.0, -38.0)
	_hide_water(true)
	_extend_far(6000.0)
	await _settle(CAPTURE_FRAMES)
	player.teleport(spot, -75.0, -38.0)
	await _settle(3)
	_save_shot(path)


## Ixtiyoriy nuqtadan surat. Yo'l, ko'prik yoki shaharni ko'rish uchun.
##     godot --path . -- --at /tmp/yo'l.png  -1851,-503
##     godot --path . -- --at /tmp/baland.png -1200,-460 900
## Birinchi qiymat — "x,z". Ikkinchisi (ixtiyoriy) — balandlik, metr.
## Balandlik berilmasa, 25 m (odatdagi ko'z balandligi + biroz tepaga).
## `yaw_arg` — ko'rish yo'nalishi, gradus. Berilmasa, yo'l bo'ylab
## qaraydi (yo'lni tekshirish uchun qulay). Berilsa — aniq yo'nalish,
## masalan uyni tashqaridan ko'rish uchun.
func _capture_at(path: String, where: String, height_arg: String,
		pitch_arg: String, yaw_arg: String) -> void:
	var parts := where.split(",")
	if parts.size() < 2:
		print_rich("[color=#c8452f]--at uchun \"x,z\" kerak[/color]")
		get_tree().quit(2)
		return
	var x := parts[0].to_float()
	var z := parts[1].to_float()
	var height: float = 25.0
	if height_arg != "":
		height = height_arg.to_float()
	var pitch: float = SHOT_PITCH
	if pitch_arg != "":
		pitch = pitch_arg.to_float()
	var explicit_yaw := false
	var yaw_override: float = SHOT_YAW
	if yaw_arg != "":
		yaw_override = yaw_arg.to_float()
		explicit_yaw = true

	# Yo'lda bo'lsa, YO'L BO'YLAB qaraymiz — shunda chiziqlar, ko'prik
	# va yo'l yonidagi relyef ko'rinadi.
	# Kamera yo'nalishi: yaw=0 da oldinga qaragan (-Z), shuning uchun
	# yaw = atan2(-dx, -dz).
	var yaw: float = yaw_override
	var nearest := RoadNetwork.nearest_road_point(Vector2(x, z))
	if not explicit_yaw and float(nearest["masofa"]) < 60.0:
		var d: Vector2 = nearest["yo'nalish"]
		yaw = rad_to_deg(atan2(-d.x, -d.y))

	var spot := Vector3(x, TerrainGen.height_at(x, z) + height, z)
	if height > 60.0:
		_hide_water(true)
		_extend_far(4000.0)
	# O'yinchi 120 m balandlikda 40 kadr davomida ERKIN TUSHADI
	# (gravitatsiya ishlaydi) va surat butun boshqa balandlikdan
	# olinadi. Shuning uchun avali kutib, so'ng JOYINI QAYTARIB
	# turamiz — chunklar yuklangan, kamera esa aniq kerakli nuqtada.
	await _settle(CAPTURE_FRAMES)
	player.teleport(spot, yaw, pitch)
	await _settle(3)
	_save_shot(path)


## Ko'tarilgan ko'rinish uchun tayyorgarlik.
##
## Ikki narsani o'zgartiradi:
##   * kamera chegarasi (odatda 585 m — tuman uchun)
##   * TUMAN O'CHIRILADI. U maydon darajasidagi o'yin uchun sozlangan:
##     300 m balandlikda hammasi yopilib ketadi. O'yinchi hech qachon
##     u qadar ko'tarilmaydi, shuning uchun bu faqat dizayn vositasi.
func _extend_far(distance: float) -> void:
	var cam: Camera3D = player.rig.camera
	if cam:
		cam.far = distance
	_clear_fog(true)


## Suv tekisligini yashirish (dizayn ko'rinishi uchun).
##
## Nima uchun bu kerak: Xorazm tekisligida yer faqat 6 m balandlikda,
## suv esa 0 m da. Yuqoridan qaraganda 6 m farq ko'rinmaydi va 12 km li
## suv tekisi relyefni to'liq to'sib qo'yadi.
func _hide_water(off: bool) -> void:
	for node in get_children():
		if node is WaterSurface:
			(node as WaterSurface).visible = not off


func _clear_fog(off: bool) -> void:
	for node in get_children():
		if node is WorldEnvironment:
			var env := (node as WorldEnvironment).environment
			if env:
				env.fog_enabled = not off


func _save_shot(path: String) -> void:
	var want_hud: bool = OS.get_cmdline_user_args().has("--hud")
	_hud.visible = want_hud
	_help.visible = false
	if want_hud:
		_hud_visible = true
		_hud.text = _diagnostics()
	await _settle(CAPTURE_FRAMES)
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print_rich("[color=#7fbf6a]Skrinshot[/color] %s — %d×%d (xato: %d)" % [
		path, image.get_width(), image.get_height(), err
	])
	get_tree().quit()


func _benchmark() -> void:
	player.teleport(WorldMap.spawn_position(), SHOT_YAW, SHOT_PITCH)
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
