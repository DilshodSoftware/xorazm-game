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
	Quality.LOW:    {"render_scale": 0.75, "draw_distance": 320.0, "shadow_distance": 60.0,  "msaa": 0, "load_radius": 1},
	Quality.MEDIUM: {"render_scale": 1.0,  "draw_distance": 450.0, "shadow_distance": 120.0, "msaa": 1, "load_radius": 2},
	Quality.HIGH:   {"render_scale": 1.0,  "draw_distance": 700.0, "shadow_distance": 250.0, "msaa": 2, "load_radius": 3},
}

var quality: Quality = Quality.MEDIUM

## O'yin vaqti — doim ertalab. Sahna har doim shu soatda boshlanadi.
const GAME_HOUR := 7
const GAME_MINUTE := 0

## Dunyo o'lchamlari (metr). Boshqa fayllar shundan foydalanadi.
const WORLD_SEED := 20260715          ## Xorazm oroli — bitta raqam, bitta o'yin

## Chunk kengligi. 400 m tanlandi: Xorazm tekis bo'lgani uchun kichik
## chunklar kerak emas, katik chunklar esa chegara bo'ylab yerga
## tekislash (yo'llar) uchun joy qoldiradi.
const CHUNK_SIZE := 400.0

## Har bir o'lchamdagi bo'laklar soni (1 + N*N tipidagi to'r).
const RES_NEAR := 48                 ## radius 1 — yaqin, 8,3 m bo'lak
const RES_FAR := 16                  ## radius 2 — uzoq, 25 m bo'lak
const RES_COLLISION := 48            ## collision to'ri (8,3 m)

## Radius 1 = batafsil mesh, radius 2 = sodda mesh.
## Tuman 450 m da tugaydi, 2-chunk chegarasi 800–1200 m da — hech qachon
## ko'rinmaydi, shuning uchun pop-in ko'rinmaydi.
const LOAD_RADIUS := 2

## Bitta kadrda nechta chunk generatsiya qilinadi (tiqilmaslik uchun).
const CHUNK_BUDGET_PER_FRAME := 1

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
	_load_radius = int(p["load_radius"])

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
var _load_radius: int = 2


func draw_distance() -> float:
	return _draw_distance


func shadow_distance() -> float:
	return _shadow_distance


## Chunk yuklash radiusi (chunk birlikida).
func load_radius() -> int:
	return _load_radius


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
