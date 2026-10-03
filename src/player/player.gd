class_name Player
extends CharacterBody3D
## Birinchi shaxs o'yinchisi.
##
## Harakat hissi GTA/Mafia 2 uslubida: tez, aniq, kechiktirmasdan.
## Buning uchun tezlanish juda katta (pastda ACCEL_GROUND) — sekin
## osish emas, darhol to'xtash va burilish kerak.
##
## O'qiydigan qismlar:
##   _read_input()      — nima qilmoqchi
##   _apply_motion()    — qanday tezlanadi
##   _handle_jump()     — sakrash va havo nazorati
##   _update_crouch()   — egilish va tepaga to'sqinlik tekshiruvi

# --- Tezliklar (m/s) ---
const SPEED_CROUCH := 1.45
const SPEED_RUN := 5.10
const SPEED_SPRINT := 7.60

## Tezlanish: qanchalik tez burchak o'zgartirilsa.
## Juda katta qiymat = "juda sezarli" harakat.
const ACCEL_GROUND := 26.0
const ACCEL_AIR := 5.0

## Sakrash. Balandlik = v² / (2g) ≈ 0,95 m
const JUMP_VELOCITY := 6.1
## Bosh urishdan keyin ham sakrash mumkin (chegara nozikligi uchun)
const COYOTE_TIME := 0.13
## Yerga urishdan oldin bosilsa ham sakrashni kutadi
const JUMP_BUFFER_TIME := 0.16
## Tugmа bosib yuborilsa sakrash qisqaradi (pastki sakrash)
const JUMP_CUT := 0.45

# --- Shakl ---
const RADIUS := 0.34
const HEIGHT_STAND := 1.80
const HEIGHT_CROUCH := 1.15

# --- Kuch ---
const STAMINA_SPRINT_DRAIN := 13.0     ## sekundiga
const STAMINA_REGEN := 9.0
const STAMINA_REGEN_DELAY := 0.9        ## yugurishdan keyin kutish
const SPRINT_MIN_STAMINA := 12.0        ## shundan pastda yugurish to'xtaydi

signal crouch_changed(crouching: bool)
signal footstep()

@onready var rig: PlayerCameraRig = $CameraRig
@onready var body_shape: CollisionShape3D = $Tana

var crouching := false
var sprinting := false
var in_vehicle: Node3D = null

var _yaw := 0.0
var _pitch := 0.0
var _input_vector := Vector2.ZERO
var _coyote := 0.0
var _jump_buffer := 0.0
var _regen_delay := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _mouse_sensitivity := 0.0024


func _ready() -> void:
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.PLAYER_MASK

	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT_STAND
	body_shape.shape = shape

	round(_yaw)
	Game.capture_mouse()
	EventBus.player_spawned.emit(self)
	EventBus.player_health_changed.emit(Game.state.health, GameState.MAX_HEALTH)


# --------------------------------------------------------------- Sichqoncha

func _unhandled_input(event: InputEvent) -> void:
	# Sichqoncha qo'yib yuborilgan — qayta ushla
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Game.capture_mouse()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * _mouse_sensitivity
		_pitch = clampf(
			_pitch - motion.relative.y * _mouse_sensitivity,
			deg_to_rad(-89.0), deg_to_rad(89.0)
		)


# ------------------------------------------------------------------ Asosiy

func _physics_process(delta: float) -> void:
	if in_vehicle != null:
		# Mashina ichida — harakat uning zimmasida
		return

	var on_floor := is_on_floor()

	# Yerga urilganini aniqlash (kamera cho'zilishi uchun)
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -velocity.y)
	elif not _was_on_floor:
		_on_landed()
	_was_on_floor = on_floor

	_update_crouch()
	var wish := _read_input()
	_apply_motion(wish, delta)
	_apply_gravity(delta, on_floor)
	_handle_jump(delta, on_floor)

	rotation.y = _yaw
	rig.rotation.x = _pitch

	var before := global_position
	move_and_slide()

	# O'tgan masofa — kamera tebranishi va qadamlar uchun
	var travelled := Vector2(
		global_position.x - before.x, global_position.z - before.z
	).length()
	Game.state.distance_walked += travelled
	rig.track_motion(horizontal_speed(), delta)
	rig.set_strafe(Input.get_axis("move_left", "move_right"), delta)


# ------------------------------------------------------------------ Kiritish

## Qaytaradi: kamera ko'zatmasiga nisbatan xohlagan yo'nalish (uzunligi 0..1).
func _read_input() -> Vector3:
	_input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := rig.global_basis

	var forward := -cam_basis.z
	forward.y = 0.0
	var right := cam_basis.x
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	# _input_vector.y: -1 = oldinga, +1 = orqaga
	return (right * _input_vector.x + forward * -_input_vector.y).limit_length(1.0)


# -------------------------------------------------------------------- Harakat

func _apply_motion(wish: Vector3, delta: float) -> void:
	var speed := _target_speed(wish)
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish * speed
	# move_toward: tezlanish doimiy, lekin tez — sakrab turib to'xtaydi
	horizontal = horizontal.move_toward(target, accel * maxf(speed, 3.0) * delta)

	# Havo drag'i — sakrashdan keyin sekinlash
	if not is_on_floor() and wish == Vector3.ZERO:
		horizontal = horizontal.move_toward(Vector3.ZERO, 2.0 * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _target_speed(wish: Vector3) -> float:
	if crouching:
		sprinting = false
		return SPEED_CROUCH

	# Faqat oldinga yuguriladi (orqaga yugurish tabiiy emas).
	# Yo'nalishni WORLD o'qidan emas, KAMERA o'qidan tekshiramiz:
	# o'yinchi sharqqa qaragan bo'lsa ham, "W" bu har doim oldingi
	# yo'nalish bo'lib qoladi.
	var moving_forward: bool = _input_vector.y < -0.2
	var wants_sprint: bool = (
		Input.is_action_pressed("sprint")
		and moving_forward
		and Game.state.stamina > SPRINT_MIN_STAMINA
	)
	sprinting = wants_sprint

	if sprinting:
		return SPEED_SPRINT
	# Shift bosilmagan — tez yurish (yugurish emas)
	return SPEED_RUN


# ------------------------------------------------------------------- Og'irlik

func _apply_gravity(delta: float, on_floor: bool) -> void:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 19.6)
	if on_floor:
		if velocity.y < 0.0:
			velocity.y = -2.0     # yerga yopishib turish uchun kichik bosim
		_coyote = COYOTE_TIME
	else:
		velocity.y -= g * delta
		_coyote = maxf(0.0, _coyote - delta)


# -------------------------------------------------------------------- Sakrash

func _handle_jump(delta: float, on_floor: bool) -> void:
	if crouching or in_vehicle != null:
		_jump_buffer = 0.0
		return

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	_jump_buffer = maxf(0.0, _jump_buffer - delta)

	if _jump_buffer > 0.0 and (on_floor or _coyote > 0.0):
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_fall_speed = 0.0
		rig.kick(0.10)   # yerga urilishdan keyingi kichik cho'zilish
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		# Tugma yerga urishdan oldin bo'shatilsa — pastki sakrash
		velocity.y *= JUMP_CUT


func _on_landed() -> void:
	var impact: float = clampf(_fall_speed / 14.0, 0.0, 1.0)
	if impact > 0.12:
		rig.kick(impact)
		footstep.emit()
	_fall_speed = 0.0


# ------------------------------------------------------------------- Egilish

func _update_crouch() -> void:
	var want: bool = Input.is_action_pressed("crouch")
	if want == crouching:
		return

	if want:
		_set_crouch(true)
	elif _has_headroom():
		_set_crouch(false)


func _set_crouch(value: bool) -> void:
	crouching = value
	var shape := body_shape.shape as CapsuleShape3D
	shape.height = HEIGHT_CROUCH if value else HEIGHT_STAND
	# MUHIM: shakl markazini ham ko'taramiz. Aks holda kapsula balandligi
	# qisqarishi bilan oyog' havoda qoladi va o'yinchi yer tomon tushadi.
	# O'yinchi ildizi oyoqda turadi, shuning uchun markaz = balandlik / 2.
	body_shape.position.y = shape.height * 0.5
	rig.set_crouching(value)
	crouch_changed.emit(value)


## Tepada chegara bormi? Aks holda turib bo'lmaydi.
##
## Bosh to'plamini tekshiramiz (1,15 … 1,85 m), butun kapsulani emas:
## kapsula yerga tegib turgani uchun tekshiruv har doim "band" bo'lib
## qoladi va o'yinchi hech qachon tik turmay olmaydi.
func _has_headroom() -> bool:
	const HEAD_HEIGHT := 0.70
	const HEAD_CENTER := HEIGHT_CROUCH + HEAD_HEIGHT * 0.5   # 1,50 m

	var probe := BoxShape3D.new()
	probe.size = Vector3(RADIUS * 2.0, HEAD_HEIGHT, RADIUS * 2.0)

	var basis := global_basis.orthonormalized()
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = probe
	# transform — GLOBAL bo'lishi shart. Agar o'yinchi o'z o'rnini
	# qo'ysak, tekshiruv har doim dunyo markazida bo'lib qoladi.
	params.transform = Transform3D(
		basis, global_position + basis * Vector3(0, HEAD_CENTER, 0)
	)
	params.collision_mask = PhysicsLayers.SOLID
	params.exclude = [get_rid()]

	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


# -------------------------------------------------------------------- Kuch

func _process(delta: float) -> void:
	if in_vehicle != null:
		return

	if sprinting and is_on_floor():
		Game.state.spend_stamina(STAMINA_SPRINT_DRAIN * delta)
		_regen_delay = STAMINA_REGEN_DELAY
	else:
		_regen_delay = maxf(0.0, _regen_delay - delta)
		if _regen_delay <= 0.0:
			Game.state.restore_stamina(STAMINA_REGEN * delta)


# ------------------------------------------------------------------ Yordamchi

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func look_direction() -> Vector3:
	return -rig.global_basis.z


func is_running() -> bool:
	return horizontal_speed() > SPEED_RUN - 0.5


## Sichqoncha sezgirlikini o'zgartirish (sozlamalar uchun).
func set_mouse_sensitivity(value: float) -> void:
	_mouse_sensitivity = value


## O'yinchini darhol ko'chirish va qarash yo'nalishini o'rnatish.
## Vazifalar va sinov skriptlari uchun.
func teleport(position: Vector3, yaw_degrees: float = 0.0, pitch_degrees: float = 0.0) -> void:
	global_position = position
	_yaw = deg_to_rad(yaw_degrees)
	_pitch = deg_to_rad(pitch_degrees)
	rotation.y = _yaw
	rig.rotation.x = _pitch
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	_coyote = 0.0


## Boshqaruvni qaytarish (interfeys oynasi yopilganda).
func release_control() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
