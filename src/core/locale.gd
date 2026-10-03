extends Node
## Matnlar: Lang.tr("hud.samar")  ->  "Samar"
##
## Barcha o'yin matnlari res://data/locale/uz.json faylida.
## Fayl ichki tuzilgan (bo'limlar -> kalitlar), lekin shu yerda
## "bo'lim.kalit" shaklida ochiladi.
##
## Keyinchalik rus/ingliz qo'shish uchun faqat yangi JSON fayl kerak
## va _load() ga bitta qator qo'shiladi — o'yin kodi tegilmaydi.

const PATH_UZ := "res://data/locale/uz.json"

## Ichki (nested) kalitlar nuqta bilan yopilgan holda saqlanadi:
## {"hud": {"samar": "Samar"}}  ->  "hud.samar" = "Samar"
var _uz: Dictionary = {}
var _missing: Array[String] = []


func _ready() -> void:
	_load(PATH_UZ, _uz)
	if _uz.is_empty():
		push_warning("Til fayli topilmadi yoki bo'sh: %s" % PATH_UZ)


## Tarjima. Ixtiyoriy {0}, {1} ... argumentlarini qabul qiladi:
##     Lang.txt("vazifa.yangilandi", ["Kosibning onasiga bor"])
##
## Tarjima topilmasa "«kalit»" qaytaradi va bir marta ogohlantiradi —
## bu topshiqni ko'rib chiqish o'rniga darhol ko'rsatadi.
##
## DIQQAT: metod nomi "tr" emas, "txt" — `Object.tr()` allaqachon
## mavjud (Godot'ning o'z tarjima funksiyasi) va override qilinsa
## butun loyiha parse xatosiga tushadi.
func txt(path: String, args: Array = []) -> String:
	var value: Variant = _uz.get(path)

	if value == null:
		if not _missing.has(path):
			_missing.append(path)
			push_warning("Tarjima topilmadi: %s" % path)
		return "«%s»" % path

	var result: String = str(value)
	if not args.is_empty():
		result %= args
	return result


## Uzunroq o'qilishi uchun alias — Lang.txt(...) va Lang.text(...) bir xil.
func text(path: String, args: Array = []) -> String:
	return txt(path, args)


## Bo'limni butunlay olish: Lang.group("mashinalar") -> Dictionary.
func group(name: String) -> Dictionary:
	var out: Dictionary = {}
	for key: String in _uz.keys():
		if key.begins_with(name + "."):
			out[key.substr(name.length() + 1)] = _uz[key]
	return out


func has(path: String) -> bool:
	return _uz.has(path)


## Barcha kalitlar — tarjimadagi bo'sh joylarni topish uchun.
func keys() -> Array:
	return _uz.keys()


## Topilmagan kalitlar (diagnostika uchun).
func missing() -> Array[String]:
	return _missing.duplicate()


func _load(path: String, into: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Til faylini ochib bo'lmadi: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Til fayli JSON obyekti emas: %s" % path)
		return
	_flatten(parsed, "", into)


## {"a": {"b": "v"}} -> {"a.b": "v"}
func _flatten(node: Dictionary, prefix: String, into: Dictionary) -> void:
	for key: Variant in node:
		var path: String = "%s.%s" % [prefix, str(key)] if prefix != "" else str(key)
		var value: Variant = node[key]
		if typeof(value) == TYPE_DICTIONARY:
			_flatten(value, path, into)
		else:
			into[path] = str(value)
