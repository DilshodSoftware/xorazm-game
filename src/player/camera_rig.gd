class_name PlayerCameraRig
extends Node3D
## Kamera "ichki hayoti": ko'z balandligi, bosh tebranishi, yerga
## urilgandagi cho'zilish, burilgandagi egilish, tezlikda FOV.
##
## Nima uchun masofa emas, vaqt bo'yicha tebranish:
##   Agar bosh tebranish vaqtga bog'lansa, tez yurganingizda
##   qadamlar orasida oraliq qoladi va yurish sun'iy ko'rinadi.
##   Masofaga bog'langan tebranish har qadamda bir xil chiqadi.

@export_group("Ko'z")
## Ko'z balandligi yerga qarab. Urganchdagi o'rtacha erkak balandligi ~1,72 m.
@export var eye_stand := 1.66
@export var eye_crouch := 1.05
## Ko'z balandligi almashganda tezligi (m/s).
@export var eye_lerp_speed := 9.0

@export_group("Bosh tebranishi")
## Bir qadam uzunligi (m) — tebranish buni belgilaydi.
@export var stride_length := 2.15
@export var bob_vertical := 0.055
@export var bob_lateral := 0.038
@export var bob_speed_smooth := 10.0

@export_group("Yerga urilish")
@export var landing_spring := 150.0
@export var landing_damping := 16.0

@export_group("Ko'rish")
@export var fov_base := 76.0
@export var fov_sprint := 83.0
@export var fov_vehicle := 88.0
@export var fov_lerp_speed := 5.0

var camera: Camera3D

# --- Ichki holat ---
var _bob_phase := 0.0        ## yig'ilgan masofa, radian
var _bob_blend := 0.0        ## tebranish kuchi 0..1
var _eye_current := 1.66
var _landing_offset := 0.0
var _landing_velocity := 0.0
var _tilt := 0.0
var _recoil_offset := 0.0
var _recoil_velocity := 0.0
var _vehicle := false


func _ready() -> void:
	camera = get_node_or_null("Camera") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera"
		add_child(camera)
	camera.fov = fov_base
	# Uzoqlik tuman chegarasidan biroz oshsin — chindan ham uzoqni
	# chizishga hojat yo'q, chuqurlik buferi tejaladi.
	camera.near = 0.05
	camera.far = Settings.draw_distance() * 1.3
	_eye_current = eye_stand


## O'yinchi har kadrda chaqiradi — tebranish masofa bo'yicha to'plansin.
func track_motion(horizontal_speed: float, delta: float) -> void:
	var target: float = horizontal_speed
	if target > 0.05:
		_bob_phase += target * delta * TAU / stride_length

	var ratio: float = clampf(target / 6.0, 0.0, 1.0)
	_bob_blend = lerpf(_bob_blend, ratio, clampf(delta * bob_speed_smooth, 0.0, 1.0))


## Yerga qattiq urilganda kamera pastga cho'zilsin.
## [param amount] — urish qat'iyigiga bog'liq (0,1 .. 1).
func kick(amount: float) -> void:
	_landing_velocity -= amount * 4.2


## Otishdan keyin kamera orqaga silkasin.
func recoil(amount: float) -> void:
	_recoil_velocity += amount


## Yengil burilganda kamera yon tomonga egilsin.
func set_strafe(input_x: float, delta: float) -> void:
	var target: float = -input_x * deg_to_rad(1.6)
	_tilt = lerpf(_tilt, target, clampf(delta * 7.0, 0.0, 1.0))


func set_crouching(crouching: bool) -> void:
	pass  # ko'z balandligi _process da yumshoq almashadi


func set_in_vehicle(value: bool) -> void:
	_vehicle = value


## Ko'rishni tiklash (mashina kamerasi va h.k.).
func set_fov_base(value: float) -> void:
	fov_base = value


func _process(delta: float) -> void:
	# --- Ko'z balandligi ---
	var target_eye: float = eye_crouch if is_crouching() else eye_stand
	_eye_current = lerpf(_eye_current, target_eye, clampf(delta * eye_lerp_speed, 0.0, 1.0))

	# --- Yerga urilish prujinasi (barchqanday tebranish o'chguncha qaytadi) ---
	_landing_velocity += (-_landing_offset * landing_spring - _landing_velocity * landing_damping) * delta
	_landing_offset += _landing_velocity * delta

	# --- Otish ---
	_recoil_velocity -= _recoil_offset * 90.0 * delta
	_recoil_offset += _recoil_velocity * delta
	_recoil_offset = lerpf(_recoil_offset, 0.0, clampf(delta * 6.0, 0.0, 1.0))

	# --- Bosh tebranish ---
	var bob_y: float = sin(_bob_phase * 2.0) * bob_vertical * _bob_blend
	var bob_x: float = sin(_bob_phase) * bob_lateral * _bob_blend

	position.y = _eye_current + bob_y + _landing_offset

	if camera:
		camera.position = Vector3(bob_x, 0, 0)
		camera.rotation.z = deg_to_rad(_tilt)
		camera.position.z = _recoil_offset

		# --- FOV: tez yurishda ko'rish kengayadi (tezlik hissi) ---
		var target_fov: float = fov_base
		if _vehicle:
			target_fov = fov_vehicle
		elif _bob_blend > 0.55:
			target_fov = lerpf(fov_base, fov_sprint, (_bob_blend - 0.55) / 0.45)
		camera.fov = lerpf(camera.fov, target_fov, clampf(delta * fov_lerp_speed, 0.0, 1.0))


func is_crouching() -> bool:
	var player := get_parent()
	return player != null and player.get("crouching") == true
