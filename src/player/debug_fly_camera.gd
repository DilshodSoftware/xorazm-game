class_name DebugFlyCamera
extends Camera3D
## VAQTINCHALIK kamera — 0-bosqich muhitni tekshirish uchun.
##
## 1-bosqichda haqiqiy o'yinchi (CharacterBody3D) qo'yiladi va bu
## fayl o'chiriladi. O'sha paytda kamera o'yinchi ichida bo'ladi.

@export var speed := 8.0
@export var sprint_multiplier := 4.0
@export var mouse_sensitivity := 0.0022

var _yaw := 0.0
var _pitch := -0.15
var _velocity := Vector3.ZERO


func _ready() -> void:
	# O'yin boshlanishida o'ng tomondan qaraydi (shimolga qarab).
	rotation = Vector3(_pitch, _yaw, 0.0)
	Game.capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	# Sichqoncha qo'yib yuborilgan bo'lsa, qayta ushlab olamiz.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Game.capture_mouse()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * mouse_sensitivity
		_pitch = clampf(
			_pitch - motion.relative.y * mouse_sensitivity,
			deg_to_rad(-89.0), deg_to_rad(89.0)
		)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	if direction.length_squared() > 0.0:
		direction *= 1.0

	# Vertikal harakat: Space — yuqoriga, Ctrl — pastga
	var vertical := Input.get_axis("crouch", "jump")

	var target := direction * speed
	target.y += vertical * speed

	if Input.is_action_pressed("sprint"):
		target *= sprint_multiplier

	# Harakat yumshoq, tez to'xtaydi
	_velocity = _velocity.lerp(target, clampf(delta * 9.0, 0.0, 1.0))
	global_position += _velocity * delta
