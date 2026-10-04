class_name Vehicle
extends VehicleBody3D
## Bitta mashina: kuzov geometriyasi, g'ildoraklar, haydash fizikasi
## va o'yinchi uchun joy.
##
## NIMA UCHUN VehicleBody3D
## Godot 4.7 da avvalgi `RaycastVehicle3D` `VehicleBody3D` ichiga
## birlashtirilgan: endi mashina tugunining o'zida `engine_force`,
## `brake`, `steering` bor va `VehicleWheel3D` to'g'ridan-to'g'ri
## uning bolasi. Alohida "osilish" tuguni yo'q.
##
## Nima uchun shu tanlov
## O'quv quti (kinematik, har kadrda yo'l nuqtasiga qo'yib qo'yish)
## 20 ta mashina uchun arzon va sodda. Lekin o'yinchi haydayotganda
## shunchaki yo'l bo'ylab sirg'alib o'tmasligi SHART: to'xtash, burish,
## qum ustida ketish, to'siqka urilish. Bularning barchasi haqiqiy
## fizika talab qiladi. VehicleBody3D — aynan shuning uchun: to'rtta
## nishat orqali osilish (suspension), g'ildoraklar orasidagi ishqalanish,
## yetakchi va boshqaruvchi g'ildorak. U CPU da ishlaydi, GPU ga
## bog'liq emas — zayif Intel uchun ham yetarli (4 ta nishat).
##
## AI MASHINALARI
## Uchun fizika o'chiriladi (`freeze = KINEMATIC`) va ular to'g'ridan
## to'g'ri yo'l bo'ylab suriladi. Sababi: 20 ta to'liq fizikali
## mashina bir-biriga urilishi mumkin, ular ketma-ket to'planib
## qolishi mumkin va zayif protsessorda 60 FPS yo'qoladi. Kinematik
## mashina hech qachon to'xtamaydi, to'qnashmaydi va arzon turadi.
##
## O'LCHAM
## Barcha mashinalar 1:1. Kuzov CarSpecs da haqiqiy o'lchamlarda,
## shakli CarShapes da chiziladi.

## Ichkariga kirganda va chiqganda.
signal entered(who: Node3D)
signal exited(who: Node3D)

## Qo'ng'iroq bosildi (faqat marshrutka va boshqa mashinalar uchun).
signal horn_pressed(who: Node3D)

# --- O'zi haqida ---
var spec: Dictionary = {}
var model_key := "spark"
var colour: Color = Color.WHITE
var occupied := false

## Soat millimetridagi tezlik — HUD uchun.
var speed_kmh := 0.0

## Kim haydayapti (null = bo'sh).
var driver: Node3D = null

## Fizika yoqilganmi? true = o'yinchi, false = AI.
var physics_driven := false

var _wheels: Array[VehicleWheel3D] = []
var _wheel_mesh: Mesh = null


func _ready() -> void:
	add_to_group("vehicles")


## Mashinani quradi: geometriya, urish shakli, g'ildoraklar.
##
## [param model] — CarSpecs kaliti.
## [param body_colour] — `Color(0,0,0,0)` (shaffof) bo'lsa, modelning
## o'z rangi (marshrutka doim oq).
## [param driveable] — o'yinchi haydashi uchun mo'ljallanganmi.
static func create(model: String, body_colour: Color,
		driveable: bool) -> Vehicle:
	var vehicle := Vehicle.new()
	vehicle.model_key = model
	vehicle.spec = CarSpecs.find(model)
	vehicle.physics_driven = driveable
	vehicle.name = "Mashina_%s" % model
	vehicle.collision_layer = PhysicsLayers.VEHICLE
	vehicle.mass = float(vehicle.spec["massa"])
	# DIQQAT: Godot 4 da maydon nomi `center_of_mass` (amerikancha),
	# `centre_of_mass` emas — biri bo'lsa xato beradi.
	vehicle.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	vehicle.center_of_mass = Vector3(0.0, -0.12, 0.0)
	vehicle.linear_damp = 0.05
	vehicle.angular_damp = 1.6
	vehicle.set_meta("tezlik", 0.0)
	if driveable:
		vehicle.collision_mask = PhysicsLayers.SOLID | PhysicsLayers.VEHICLE
	else:
		# Kinematik AI mashinasi: og'irmaydi, aylanmaydi, yerga yopishmaydi
		vehicle.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		vehicle.freeze = true
		vehicle.collision_mask = 0
		vehicle.can_sleep = false
	vehicle.colour = body_colour if body_colour.a > 0.0 \
		else vehicle.spec.get("rangi", Palette.CAR_WHITE)
	vehicle._build()
	return vehicle


# ================================================================ QURILISH

func _build() -> void:
	_build_body()
	_build_collision()
	_build_wheels()


## Kuzov geometriyasi va uni ko'rsatadigan tugun.
##
## DIQQAT: material `MeshBuilder.commit` orqali qo'yiladi, qo'lda
## emas — aks holda vertex ranglari (kuzov rangi, shisha, chiroq)
## ishlamaydi va orqa yuzalar cull qilinadi.
func _build_body() -> void:
	var builder := MeshBuilder.new()
	builder.want_collision = false
	CarShapes.build(builder, spec, Vector3.ZERO, colour, false)
	if builder.is_empty():
		push_error("Mashina kuzovi bo'sh qoldi: %s" % model_key)
		return
	# Bo'yalgan metall: biroz yaltiroq (0.38) va soya beradi —
	# mashina yonida yotgan soya uni yerga bog'laydi
	builder.commit(self, "Kuzov", 0.38, true, true)


## Zarba shakli. Pastki qirqliq g'ildorak radiusidan pastga tushmasligi
## SHART — aks holda qo'lda tormozlaganda kuzov yerga tegib qoladi.
func _build_collision() -> void:
	var length: float = float(spec["uzunlik"])
	var width: float = float(spec["kenglik"])
	var radius: float = float(spec["radius"])
	var floor_y: float = radius * 0.92
	var top_y: float = float(spec["balandlik"]) - 0.08

	var shape := CollisionShape3D.new()
	shape.name = "Zarba"
	var box := BoxShape3D.new()
	box.size = Vector3(length * 0.84, maxf(top_y - floor_y, 0.2), width * 0.88)
	shape.shape = box
	shape.position = Vector3(0.0, (floor_y + top_y) * 0.5, 0.0)
	add_child(shape)


## To'rt g'ildorak.
##
## DIQQAT: oldingi g'ildorak boshqariladi (steering), orqa g'ildorak
## yetakchi (traction). Bu Yevropa mashinasida standart va o'yinchi
## uchun tabiiy.
##
## G'ildorak tugunining o'rni — osilish nuqtasi, g'ildorak markazi
## emas. Osilish qanchalik cho'zilsa, shunchalik pastga tushadi; vizual
## g'ildorak shu yerda `−radius` bo'ylab chizilgan.
func _build_wheels() -> void:
	# DIQQAT: osilish sozlamalari (suspension_travel, damping_*)
	# VehicleBody3D da EMAS, har bir VehicleWheel3D da bor. Godot
	# 4.7 da ular tugunga ko'chgan. Umumiy (butun mashina) eng
	# yagona sozlamalar: dvigatel, tormoz, burish.
	engine_force = 0.0
	brake = 0.0
	steering = 0.0

	var radius: float = float(spec["radius"])
	var width: float = float(spec["en_kenglik"])
	var base: float = float(spec["gildorak"]) * 0.5
	var track: float = float(spec["iz"]) * 0.5
	var rest := 0.20

	for front: bool in [true, false]:
		for side: float in [-1.0, 1.0]:
			var wheel := VehicleWheel3D.new()
			wheel.name = "Gildorak_%s_%s" % [
				"old" if front else "orqa", "chap" if side < 0.0 else "ong"]
			wheel.use_as_steering = front
			wheel.use_as_traction = not front
			wheel.wheel_radius = radius
			wheel.wheel_rest_length = rest
			wheel.wheel_roll_influence = 0.06
			wheel.suspension_travel = 0.28
			wheel.suspension_stiffness = 32.0
			wheel.suspension_max_force = 7000.0
			wheel.damping_compression = 0.88
			wheel.damping_relaxation = 0.94
			wheel.wheel_friction_slip = 3.4
			wheel.position = Vector3(
				base if front else -base, radius + rest, side * track)
			var visual := MeshInstance3D.new()
			visual.name = "Korinish"
			visual.mesh = _wheel_visual()
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# G'ildorak markazi osilish nuqtasidan `radius` pastda
			visual.position = Vector3(0.0, -radius, 0.0)
			wheel.add_child(visual)
			add_child(wheel)
			_wheels.append(wheel)


## Bitta g'ildorak mesh'i — to'rt g'ildorak ham, hamma mashinalar ham
## bitta nusxani ishlatadi (GPU va xotira uchun).
func _wheel_visual() -> Mesh:
	if _wheel_mesh != null:
		return _wheel_mesh
	var builder := MeshBuilder.new()
	builder.want_collision = false
	var radius: float = float(spec["radius"])
	var width: float = float(spec["en_kenglik"])
	CarShapes.build_wheel(builder, radius, width)
	# Material har 4 ta g'ildorak uchun bitta nusxa — GPU da bitta
	# material o'zgarishi 4 marta emas, 1 marta
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.86
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wheel_mesh = builder.build_mesh()
	_wheel_mesh.surface_set_material(0, mat)
	return _wheel_mesh


# ================================================================ KIRISH

## Kamera uchun o'tirish nuqtasi (balandlik past — ichki ko'rinish).
func seat_position() -> Vector3:
	var base: float = float(spec["gildorak"]) * 0.5
	var eye: float = float(spec["balandlik"]) * 0.60
	return global_position + global_transform.basis * Vector3(
		base * 0.10, maxf(eye, 1.05), 0.0)


## Chiqish nuqtasi — eshik tomoni, yurish yo'li tomonida.
##
## DIQQAT: qaysi tomon ekani YER ostidagi yo'nalishdan topiladi
## (`forward.cross(UP)`), o'z o'zidan emas. Aks holda mashina
## ko'chaga to'g'ri qaragan bo'lsa, o'yinchi yo'lning ichiga tushib
## qoladi va orada qisilib qoladi.
func exit_position() -> Vector3:
	var half: float = float(spec["kenglik"]) * 0.5
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var door := Vector3(
		global_position.x + right.x * (half + 0.85)
			+ forward.x * float(spec["gildorak"]) * 0.30,
		0.0,
		global_position.z + right.z * (half + 0.85)
			+ forward.z * float(spec["gildorak"]) * 0.30)
	door.y = TerrainGen.height_at(door.x, door.z) + 0.15
	return door


## G'ildorak burchagi — vizual uchun (chaqiruvchi aylantiradi).
func set_wheel_spin(angle: float) -> void:
	for wheel: VehicleWheel3D in _wheels:
		var visual := wheel.get_node_or_null("Korinish") as MeshInstance3D
		if visual:
			visual.rotate_object_local(Vector3.LEFT, angle)


func forward_vector() -> Vector3:
	return -global_transform.basis.z


func speed() -> float:
	return speed_kmh


## Barcha g'ildorak yerdan ko'tarilganmi (havoda).
func is_airborne() -> bool:
	if not physics_driven:
		return false
	for wheel: VehicleWheel3D in _wheels:
		if wheel.is_in_contact():
			return false
	return true


# ================================================================ HAYDASH

## O'yinchi kiritgan kuchlarni qo'llaydi. Har bir fizika kadrida
## chaqiriladi.
##
## [param throttle] −1 … 1 (orqaga)
## [param steer] −1 … 1
## [param braking] 0 … 1
## [param handbrake] qo'lda tormoz (orqa g'ildorakni qisadi)
func drive(throttle: float, steer: float, braking: float,
		handbrake: float) -> void:
	if not physics_driven:
		return
	# --- Gaz ---
	var power: float = float(spec["dvigatel"]) * throttle
	# Orqaga qarab haydash sekin: 30% kuch — aks holda teskari
	# urilib ketadi
	if throttle < 0.0:
		power *= 0.30
	# Tepa tezlikdan oshmaslik. Chegirmasdan bo'lsa mashina
	# cheksiz tezlashadi va HUD raqami yolg'on bo'lib chiqadi.
	var limit: float = float(spec["tepa_tezlik"]) / 3.6
	if throttle > 0.0 and speed_kmh >= limit:
		power *= 0.10
	engine_force = power

	# --- Burish ---
	# Manfiy belgi: A chapga, D o'ngga — teginish kameraga bog'liq
	# bo'lmagan koordinatada shunday qabul qilingan.
	steering = -steer * float(spec["burish"])

	# --- Tormoz ---
	var brake_force: float = float(spec["tormoz"]) * clampf(braking, 0.0, 1.0)
	if throttle < 0.0 and speed_kmh < 2.0:
		# Orqaga "tormoz": to'xtamay qolmasin
		brake_force = maxf(brake_force, float(spec["tormoz"]) * 0.5)
	brake = brake_force

	# --- Qo'lda tormoz: faqat orqa g'ildoraklar ---
	for wheel: VehicleWheel3D in _wheels:
		if wheel.use_as_traction:
			wheel.brake = float(spec["tormoz"]) * handbrake


## Har kadrda chaqiriladi: tezlikni yangilaydi.
func update_speed() -> void:
	if physics_driven:
		speed_kmh = linear_velocity.length() * 3.6
	else:
		# Kinematik mashina — o'z tezligimizni aytib beramiz
		speed_kmh = float(get_meta("tezlik", 0.0))


## AI uchun: tezlikni e'lon qilish va tugunni yo'lga qo'yish.
func place_on_road(position: Vector3, yaw: float, speed: float) -> void:
	global_position = position
	rotation.y = yaw
	set_reported_speed(speed)
	# G'ildoraklar aylanishi ko'rinishi uchun
	if _wheels.size() > 0:
		set_wheel_spin(speed / 3.6 / maxf(float(spec["radius"]), 0.1) * get_physics_process_delta_time())


func set_reported_speed(value: float) -> void:
	set_meta("tezlik", value)
	speed_kmh = value
