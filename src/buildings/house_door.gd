class_name HouseDoor
extends Node3D
## O'tadigan eshik — ochiladi va yopiladi.
##
## Xorazm eshigi og'ir yog'ochdan, o'rtadan to'q qilib yopiladi.
## O'yin yuzasida u E tugmasi bilan ochiladi.
##
## NIMA UCHUN Node3D, oddiy MeshInstance emas
## Ochilgan eshik burilishi kerak — buni `rotation` bilan qilamiz.
## Burilish markazi eshik o'qida bo'lishi uchun tugun aynan
## eshikning chap chetiga qo'yiladi va mesh shunga nisbatan
## joylashtiriladi.

signal opened
signal closed

const OPEN_ANGLE := 78.0
const SPEED := 3.4

var _target: float = 0.0
var _interactable: Interactable
var _is_open := false


## Eshikni quradi.
##
## [param root]   — eshik qo'shiladigan tugun
## [param hinge]  — eshikning chap cheti (Dunyo koordinatasida)
## [param facing] — eshik qaysi tomonga ochiladi (radian, XZ)
## [param width]  — eshik eni
## [param height] — balandligi
## [param colour] — eshik rangi
static func create(root: Node3D, hinge: Vector3, facing: float,
		width: float, height: float,
		colour: Color = Palette.WOOD_DARK) -> HouseDoor:
	var door := HouseDoor.new()
	door.name = "Eshik"
	root.add_child(door)

	# Burilish o'qi — chap chet
	door.position = hinge
	door.rotation.y = facing
	door._width = width

	# Eshik taxtasi — o'qdan chetga, o'rtada.
	# DIQQAT: bu mesh ESHIK tuguniga bog'lanadi (global emas), chunki
	# u qirqilganda aylanadi.
	var leaf := MeshBuilder.new()
	leaf.want_collision = false
	FurnitureKit._box(leaf, Basis(), Vector3(width * 0.5, height * 0.5, 0.0),
		Vector3(width, height, 0.07), colour, true)
	# Nishon va tayoq — Xorazm eshigida metall naqsh bo'ladi
	FurnitureKit._box(leaf, Basis(), Vector3(width * 0.5, height * 0.62, 0.045),
		Vector3(width * 0.5, 0.05, 0.02), Palette.GATE_METAL, false)
	FurnitureKit._box(leaf, Basis(), Vector3(width * 0.5, height * 0.38, 0.045),
		Vector3(width * 0.5, 0.05, 0.02), Palette.GATE_METAL, false)
	leaf.commit(door, "Tafta", 0.75)

	door._setup_interactable(width, height)
	return door


var _width := 1.0


func _setup_interactable(width: float, height: float) -> void:
	_interactable = Interactable.new()
	_interactable.label_key = "hud.eshik"
	_interactable.name = "Muloqot"
	add_child(_interactable)
	_interactable.fired.connect(_on_use)


func _on_use(_player: Node3D) -> void:
	toggle()


func toggle() -> void:
	set_open(not _is_open)


func set_open(open: bool) -> void:
	_is_open = open
	_target = deg_to_rad(OPEN_ANGLE) if open else 0.0
	EventBus.interact_performed.emit("door")
	if open:
		opened.emit()
	else:
		closed.emit()


func is_open() -> bool:
	return _is_open


## Eshik tebranishi — sekin, og'ir yog'och kabi.
func _process(delta: float) -> void:
	if absf(rotation.y - _target) < 0.001:
		return
	rotation.y = move_toward(rotation.y, _target, deg_to_rad(SPEED) * delta * 60.0 * delta)


## Eshikning ochiq turgan nuqtasi (o'tish uchun).
func passage_centre() -> Vector3:
	return global_position + Vector3(0, 1.0, 0) \
		+ Vector3(sin(rotation.y), 0, cos(rotation.y)) * (_width * 0.5)