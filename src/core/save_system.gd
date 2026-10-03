class_name SaveSystem
extends RefCounted
## O'yinni saqlash va yuklash.
##
## Format: user://save_N.json — oddiy, inson o'qiy oladigan, tarmoqqa
## yuborish oson (GIT kabi).
## O'yin holati GameState.dict() shaklida yoziladi.

const SAVE_DIR := "user://saves"
const FORMAT_VERSION := 1


static func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Yozish. true = muvaffaqiyatli.
static func save(state: GameState, slot: int) -> bool:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var payload := {
		"version": FORMAT_VERSION,
		"world_seed": Settings.WORLD_SEED,
		"saved_at": Time.get_datetime_string_from_system(true),
		"state": state.to_dict(),
	}

	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Saqlab bo'lmadi: %s" % slot_path(slot))
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


## Yuklash. false = bo'sh yoki buzilgan slot.
static func load_into(state: GameState, slot: int) -> bool:
	if not slot_exists(slot):
		return false

	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Saqlash fayli buzilgan: slot %d" % slot)
		return false

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != FORMAT_VERSION:
		push_warning("Saqlash versiyasi mos emas: slot %d" % slot)
		return false

	state.from_dict(data.get("state", {}))
	return true


static func delete(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(slot_path(slot))
