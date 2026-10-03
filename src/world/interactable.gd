class_name Interactable
extends Area3D
## O'yinchi bilan muloqot qiladigan narsa: eshik, sandiq, televizor.
##
## O'yinchi yoniga kelganda ushbu hududga kirsa, oyna yuqorida
## paydo bo'ladi: "[E] Eshikni ochish". E bosilsa — `signal fired`
## chiqadi.
##
## Nima uchun Area3D, kinematik zona emas: kinematik zona yerga
## tegib turadi va devor ichida ham ishlaydi (o'yinchi eshikning
## ikki tomonida ham eshikni ko'radi). Area3D esa haqiqiy fazoda
## bitta aniq nuqtada turadi.

## E bosilganda chiqadigan signal.
signal fired(player: Node3D)

## Oynada chiqadigan matn (kalit, masalan "hud.eshik").
@export var label_key := "hud.interact"

## Qo'shimcha ma'lumot — har bir narsa uchun boshqacha.
@export var prompt := ""

## Ishlatilgandan keyin o'z-o'zidan o'chadimi? (bir martalik)
@export var once := false

## Nima qilish kerak — `open_door`, `read`, va h.k.
@export var action := ""

var _used := false
var _player_inside := false


func _ready() -> void:
	# Hudud — qisqa, o'yinchi yoniga kelganda ishga tushadi
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.2, 2.4)
	shape.shape = box
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if body.has_method("register_interactable"):
		body.register_interactable(self)
	EventBus.interact_shown.emit(_text())


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	if body.has_method("unregister_interactable"):
		body.unregister_interactable(self)
	EventBus.interact_hidden.emit()


func _text() -> String:
	var verb: String = Lang.txt(label_key)
	if prompt != "":
		return "[E] %s — %s" % [prompt, verb]
	return "[E] %s" % verb


## O'yinchi E bosdimi?
func try_use(player: Node3D) -> bool:
	if not _player_inside or (once and _used):
		return false
	_used = once
	fired.emit(player)
	EventBus.interact_hidden.emit()
	return true


## Oyna ko'rsatilgan holatda.
func is_offered() -> bool:
	return _player_inside and not (once and _used)