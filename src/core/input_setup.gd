extends Node
## Barcha o'yin boshqaruvlari shu yerda, oddiy GDScript da.
##
## Nima uchun .godot faylidagi InputMap emas:
##   1) O'qiladi — qaysi tugma nima qilishi bitta ekranda ko'rinadi.
##   2) Xarakterni o'zgartirmasdan yangi tugma qo'shish mumkin.
##   3) Bir xil tugma bir necha kontekstda ishlatilishi mumkin
##      (masalan Space: sakrash / mashinada qo'lda tormoz).


## Klaviatura tugmalari -> InputMap harakati
const KEY_ACTIONS := {
	# --- Harakat ---
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],

	# --- Yurish holatlari ---
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"roll": [KEY_ALT],

	# --- O'zaro ta'sir ---
	"interact": [KEY_E],          # eshik / mashina / NPC
	"vehicle_enter_exit": [KEY_F], # mashinaga minish- chiqish
	"horn": [KEY_H],               # Marshrutka! Marshrutka!!
	"reload": [KEY_R],

	# --- Qurol ---
	"slot_1": [KEY_1],
	"slot_2": [KEY_2],
	"slot_3": [KEY_3],
	"slot_4": [KEY_4],
	"weapon_next": [KEY_Q],
	"weapon_prev": [KEY_TAB],

	# --- Interfeys ---
	"inventory": [KEY_I],
	"map": [KEY_M],
	"pause": [KEY_ESCAPE],
	"debug_overlay": [KEY_F3],
}


## Sichqoncha tugmalari -> InputMap harakati
const MOUSE_ACTIONS := {
	"fire": [MOUSE_BUTTON_LEFT],
	"aim": [MOUSE_BUTTON_RIGHT],
}


func _ready() -> void:
	_register()


## Barqaror natija uchun barcha harakatlarni qayta qayd etamiz.
## Godot'ni qayta ishga tushirsak ham bir xil bo'ladi.
func _register() -> void:
	for action: String in KEY_ACTIONS:
		_add_key_action(action, KEY_ACTIONS[action])

	for action: String in MOUSE_ACTIONS:
		_add_mouse_action(action, MOUSE_ACTIONS[action])


func _add_key_action(action: String, keys: Array) -> void:
	_ensure_action(action)
	for keycode: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _add_mouse_action(action: String, buttons: Array) -> void:
	_ensure_action(action)
	for button: MouseButton in buttons:
		var event := InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)


func _ensure_action(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)
