class_name WorldMap
extends RefCounted
## Xorazmning haqiqiy geografiyasidan olingan xarita.
##
## SHKALLASH
##   Shaharlar *orasidagi* masofa haqiqiy koordinatalardan 1:20 hisoblanib
##   kichiklashtirilgan. Lekin binolar va minoralar 1:1 HAQIQIY
##   o'lchamda qoladi (Kalta Minor 29 m, Islam Xo'ja 57 m).
##   Shu sababli minoralar tekis Xorazm tekisligida 1 km dan ko'rinadi.
##
## KOORDINATALAR
##   X = sharq (+), Z = janub (+). Demak -Z = shimol, +X = sharq.
##   Bu Godot 3D ning standart yo'nalishi (-Z = oldinga/qarama-qarshi).
##
##     game_x = (lon − 60.638) × 4170 − 720
##     game_z = −(lat − 41.52) × 5565 + 93
##
##     (1° kenglik = 111,3 km → 4 452 m;  1° uzunlik 41° da = 83,4 km → 3 336 m)
##     Keyin o'q markazga siljitilgan: x + 30,5.

const SEED := 20260715

## Orol o'lchamlari (quruq qism chegarasi, metr).
const ISLAND_WIDTH := 4300.0
const ISLAND_DEPTH := 3600.0

## Dengiz sathidan pastda bo'ladigan chegaralar.
const SHORE_MARGIN := 210.0

## --- Shaharlar: nom -> o'yin koordinatasi ---
## O'rganish manbalari: Wikipedia/Wikidata koordinatalari va
## Xorazm viloyati rasmiy ma'lumotlari.
const CITIES := {
	"gurlan": {
		"nom": "Gurlan", "x": -1682.0, "z": -1743.0,
		"radius": 260.0, "rol": "shimoliy shaharcha, sohil",
	},
	"yangibozor": {
		"nom": "Yangibozor", "x": -1102.0, "z": -969.0,
		"radius": 220.0, "rol": "shimoliy fermerlik",
	},
	"shovot": {
		"nom": "Shovot", "x": -2099.0, "z": -630.0,
		"radius": 200.0, "rol": "garbiy, kanal boyida",
	},
	"urganch": {
		"nom": "Urganch", "x": -745.0, "z": 13.0,
		"radius": 620.0, "rol": "VILOYAT MARKAZI",
	},
	"qoshkopir": {
		"nom": "Qo'shko'pir", "x": -1891.0, "z": 167.0,
		"radius": 190.0, "rol": "garbiy",
	},
	"xonqa": {
		"nom": "Xonqa", "x": -84.0, "z": 390.0,
		"radius": 230.0, "rol": "urganch janobida",
	},
	"khiva": {
		"nom": "Xiva", "x": -1845.0, "z": 864.0,
		"radius": 420.0, "rol": "TARIXIY MARKAZ — Ichan Qal'a",
	},
	"xazorasp": {
		"nom": "Xazorasp", "x": 1099.0, "z": 1224.0,
		"radius": 250.0, "rol": "sharqiy savdo markazi",
	},
	"pitnak": {
		"nom": "Pitnak", "x": 2099.0, "z": 1750.0,
		"radius": 240.0, "rol": "janubi-sharqiy sanoat markazi",
	},
}

## Sizning uyingiz — Urganch tumani, Tandirchi mahallasi,
## Kosiblar ko'chasi. Urganch markazidan ~630 m shimoli-g'arbda.
const TANDIRCHI := Vector2(-1200.0, -457.0)

## O'yinchi shu nuqtada uyg'onadi.
##
## DIQQAT: nuqta atrofidagi obyektlardan (devor, mashina, daraxt) kamida
## 25 m masofada bo'lishi SHART. Aks holda o'yinchi ularning ichida
## tug'iladi va `move_and_slide` uni ichkaridan pastga suradi — u yer
## oriqali tushib ketadi. Bu xato albatta chalkash: chunk collision
## to'g'ri ishlayotgani ko'rinadi, chunklar "yuklangan" bo'ladi,
## renderlash statistikasi normal qoladi — o'yinchi esa havoda ketadi.
## (Shu sabab tools/player_selftest.gd da alohida test bor.)
##
## Balandlik RUNDA hisoblanadi (shahar tepasligi ~6 m), chunki statik
## raqam relyefni o'zgartirganda noto'g'ri bo'lib qoladi.
const PLAYER_SPAWN := Vector2(-1251.0, -492.0)


static func city_position(id: String) -> Vector2:
	return Vector2(CITIES[id]["x"], CITIES[id]["z"])


static func city_name(id: String) -> String:
	return CITIES[id]["nom"]


## O'yinchi tug'iladigan nuqta — balandlik TerrainGen dan.
static func spawn_position() -> Vector3:
	var y: float = TerrainGen.height_at(PLAYER_SPAWN.x, PLAYER_SPAWN.y)
	return Vector3(PLAYER_SPAWN.x, y + 0.3, PLAYER_SPAWN.y)


## Orolning eng yaqin shahri (HUD/minimap uchun).
static func nearest_city(point: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for id: String in CITIES:
		var city: Vector2 = city_position(id)
		var d := city.distance_squared_to(Vector2(point.x, point.z))
		if d < best_distance:
			best_distance = d
			best = id
	return best
