extends Node
## O'yin boshqaruvchisi — barcha sahifalar orasidagi markaz.
##
## GameState ma'lumotlari shu yerda, GameState.class esa — sof ma'lumot.

var state := GameState.new()

## Sahna almashuvi (keyin: tandiqqa, savdo do'koni, Xiva va h.k.)
var _scene_stack: Array[Node] = []
var _paused_by_us: bool = false


func _ready() -> void:
	# Autoload'lar to'xtatilganda ham ishlashi kerak — Esc bosilsa ham
	# o'yinni to'xtatish va qayta boshlash shu yerda boshqariladi.
	process_mode = Node.PROCESS_MODE_ALWAYS


# ---------------------------------------------------------------- Sichqoncha

func capture_mouse() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		EventBus.input_mouse_captured.emit(true)


func release_mouse() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		EventBus.input_mouse_captured.emit(false)


func toggle_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		release_mouse()
	else:
		capture_mouse()


# --------------------------------------------------------------------- Turgunlik

func is_paused() -> bool:
	return get_tree().paused


func toggle_pause() -> void:
	if is_paused():
		resume()
	else:
		pause()


func pause() -> void:
	if is_paused():
		return
	get_tree().paused = true
	_paused_by_us = true
	release_mouse()


func resume() -> void:
	if not _paused_by_us:
		return
	get_tree().paused = false
	_paused_by_us = false
	capture_mouse()


# ----------------------------------------------------------------------- Dunyo

## Sahna almashuv. Avvalgisini avtomatik tozalaydi.
func goto_scene(scene: Node) -> void:
	_clear_scenes()
	_scene_stack.append(scene)
	get_tree().current_scene.add_child(scene)


func _clear_scenes() -> void:
	for scene in _scene_stack:
		if is_instance_valid(scene):
			scene.queue_free()
	_scene_stack.clear()


func current_world() -> Node:
	return _scene_stack.back() if not _scene_stack.is_empty() else null


# ---------------------------------------------------------------------- Tezkor

## "F5" — saqlash. Endi faqat o'yinchi holati; keyin dunyo qo'shiladi.
func quick_save() -> void:
	SaveSystem.save(state, 1)
	EventBus.notify(Lang.txt("xabar.saqlandi"))


func quick_load() -> void:
	if SaveSystem.load_into(state, 1):
		EventBus.notify(Lang.txt("xabar.yuklandi"))
	else:
		EventBus.notify(Lang.txt("xabar.xotira_toliq"))


## Dunyoni qayta o'rnatish (o'yinni boshlash / tugatish).
func restart_world() -> void:
	var world := current_world()
	if world and world.has_method("reset"):
		world.reset()
		state.reset()
