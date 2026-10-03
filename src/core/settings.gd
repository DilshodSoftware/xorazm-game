extends Node
## Grafika va umumiy sozlamalar.
##
## Bu loyiha Intel UHD Graphics (ICL GT1) uchun yozilgan — bu GPU'da
## VRAM yo'q (RAM'dan oladi), shuning uchun har bir sozlashma
## maksimal qiymatdan pastga qo'yilgan.

## Sifat darajalari. Standart (1) — Intel UHD uchun moslashtirilgan.
enum Quality { LOW = 0, MEDIUM = 1, HIGH = 2 }

const SETTINGS_PATH := "user://settings.cfg"

const PRESETS := {
	#  render_scale, ko'rish masofasi, soya masofasi, MSAA
	Quality.LOW:    {"render_scale": 0.75, "draw_distance": 320.0, "shadow_distance": 60.0,  "msaa": 0},
	Quality.MEDIUM: {"render_scale": 1.0,  "draw_distance": 450.0, "shadow_distance": 120.0, "msaa": 1},
	Quality.HIGH:   {"render_scale": 1.0,  "draw_distance": 700.0, "shadow_distance": 250.0, "msaa": 2},
}

var quality: Quality = Quality.MEDIUM

## O'yin vaqti — doim ertalab. Sahna har doim shu soatda boshlanadi.
const GAME_HOUR := 7
const GAME_MINUTE := 0

## Dunyo o'lchamlari (metr). Boshqa fayllar shundan foydalanadi.
const WORLD_SEED := 20260715          ## Xorazm oroli — bitta raqam, bitta o'yin
const CHUNK_SIZE := 200.0             ## Chunk kengligi
const CHUNK_RESOLUTION := 33          ## Vertikal bo'laklar soni (1 + 2*16)
const CHUNK_LOAD_RADIUS := 4          ## Necha chunk radiusda yuklanadi
const SEA_LEVEL := 0.0

## Ism. "Xorazm — Urganch"
var last_save_slot := 0


func _ready() -> void:
	_load()
	apply_quality(quality)


func apply_quality(level: Quality) -> void:
	quality = level
	var p: Dictionary = PRESETS[level]

	# Ekran o'lchami — eng arzon usul poligon sonini kamaytirish.
	get_viewport().scaling_3d_scale = float(p["render_scale"])

	# MSAA
	var msaa: int = int(p["msaa"])
	match msaa:
		0: get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1: get_viewport().msaa_3d = Viewport.MSAA_2X
		2: get_viewport().msaa_3d = Viewport.MSAA_4X

	_draw_distance = float(p["draw_distance"])
	_shadow_distance = float(p["shadow_distance"])

	EventBus.notice_posted.emit("Sifat: %s" % quality_name(), 2.0)
	_save()


func cycle_quality() -> void:
	apply_quality(((quality + 1) % 3) as Quality)


func quality_name() -> String:
	match quality:
		Quality.LOW: return "Past"
		Quality.HIGH: return "Yuqori"
		_: return "O'rta"


## Tuman masofasi — ko'rish chegarasi shu bilan belgilanadi.
## Xorazm ertalabi changli, shuning uchun bu chegara tabiiy ko'rinadi.
var _draw_distance: float = 450.0
var _shadow_distance: float = 120.0


func draw_distance() -> float:
	return _draw_distance


func shadow_distance() -> float:
	return _shadow_distance


## Erta tong qorong'iligini sezarli qilish uchun (tez-tez) qiymat.
func morning_factor() -> float:
	return 1.0


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", int(quality))
	cfg.set_value("game", "last_save_slot", last_save_slot)
	cfg.save(SETTINGS_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	quality = cfg.get_value("video", "quality", Quality.MEDIUM) as Quality
	last_save_slot = cfg.get_value("game", "last_save_slot", 0)
