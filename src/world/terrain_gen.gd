class_name TerrainGen
extends RefCounted
## Xorazm vohasining protsedural balandlik xaritasi.
##
## Bu butun o'yining yuragi: har bir nuqta uchun bitta raqam —
## balandlik. Dunyo, jamoa, paxta maydonlari, daraxtlar va keyinchalik
## yo'llar hammasidan bu funksiya orqali o'tadi.
##
## ILMIY ASOS
##   Xorazm — O'zbekistondagi eng tekis viloyat. Rasmiy ta'rif: "pasttekislik,
##   daryo yotqiziqlaridan iborat", o'rtacha balandlik ~100 m (dengizdan).
##   Demak TOG'LAR YO'Q. Barcha relyef — mayin, qum tepaligi va sho'r ko'llar.
##
## SHAKILLANTIRISH TARTIBI (pastdan yuqoriga)
##   1. Orol maski      — elliptik + shovqinli qirg'oq
##   2. Mayin           — keng, past relyef
##   3. Qum tepaliklari — faqat g'arb va janubi-g'arbda
##   4. Mayda notekislik
##   5. Suv izlarini kesish — Amudaryo, sho'r ko'llar, G'ovuk ko'l, kanallar
##   6. Chekadan cho'kish
##   7. Shahar tekisliklari — shaharlar quruq va tekis bo'lishi uchun
##
## O'LCHOVLAR (dunyo birligi = 1 metr)

# --- Asosiy ---
const BASE_HEIGHT := 5.2          ## Tekislikning o'rtacha balandligi
const SWELL_AMPLITUDE := 1.6      ## Keng mayin (to'lqin uzunligi ~520 m)
const SWELL_WAVELENGTH := 520.0
const FINE_AMPLITUDE := 0.35     ## Mayda notekislik (~55 m)
const FINE_WAVELENGTH := 55.0

# --- Orol maski ---
const ISLAND_HALF_X := 2900.0     ## Yarim kengligi (sharq-g'arb)
const ISLAND_HALF_Z := 2600.0     ## Yarim chuqurligi (shimol-janub)
## Eksponent 3 = "kvadratga yaqin doira". Oddiy doiraga tegishli emas:
## Pitnak janubi-sharqiy burchakda joylashgan, doira esa uni suvga
## tushirib qoldirardi.
const FALLOFF_POWER := 3.0
const FALLOFF_OUTER := 1.15       ## Bu yerda quruq yer tugaydi
const FALLOFF_INNER := 0.70       ## Bu yerda to'liq quruq
const COAST_WAVELENGTH := 1100.0  ## Qirg'oq notekisligi
const COAST_AMPLITUDE := 0.08

# --- Qum tepaliklari (g'arb, janub-g'arb — Qizilqum tomon) ---
const DUNE_AMPLITUDE := 7.5
const DUNE_WAVELENGTH := 240.0
const DUNE_WAVELENGTH_2 := 95.0

# --- Suv ---
const RIVER_FLOOR := -9.0         ## Amudaryo tubi
const RIVER_CENTER_Z := 2140.0    ## Daryo o'rtasi (janubda)
const RIVER_WAVE := 150.0         ## Qirg'oq to'lqini
const RIVER_WAVE_PERIOD := 1000.0
const RIVER_HALF_WIDTH := 240.0

const SALT_FLOOR := -1.3          ## Sho'r ko'l tubi (dengizdan oz past)
const CANAL_DEPTH := 1.7          ## Kanal chuqurligi
const CANAL_HALF_WIDTH := 7.0     ## Kanal yarim kengligi
const GOVUK_POOL_FLOOR := -0.9    ## Xivadagi G'ovuk ko'l

# --- Shaharlar ---
## Shaharlar tepalik bo'lishi tarixiy dalil bilan ham mos keladi:
## Xorazmda qadimiy "tilla tepa" — sun'iy ko'tarilgan qishloq tepalari.
const CITY_HEIGHT := 6.0
const CITY_MARGIN := 340.0        ## Tekislikka o'tish uzunligi

# --- Sho'r ko'llar (janub — tadqiqot bo'yicha shu yerda eng ko'p) ---
const SALT_LAKES := [
	{"pos": Vector2(-600.0, 1500.0), "r": 240.0},
	{"pos": Vector2(500.0, 1350.0), "r": 180.0},
	{"pos": Vector2(1750.0, 500.0), "r": 150.0},
	{"pos": Vector2(-1250.0, 1250.0), "r": 200.0},
]

## G'ovuk ko'l — Xiva shahridagi kichik turizm ko'li.
## DIQQAT: Xiva markaziga QO'YILMAYDI — u shahar markazini suv ostida
## qoldiradi. Shaharning sharqiy chekkasida (radius ichida) turibdi.
const GOVUK_POOL := {"pos": Vector2(-1585.0, 864.0), "r": 75.0}

## Sug'orish kanallari. Amudaryodan shimolga tarqaladi — Xorazmning
## asosiy suv tarmog'i ("kanalizatsiya" butun viloyatni qamrab olgan).
## Yo'llar keyingi bosqichda shu kanallar ustidan ko'prik quradi.
const CANALS := [
	{"nom": "Shavat",         "a": Vector2(-100.0, 2050.0),  "b": Vector2(-1000.0, -450.0)},
	{"nom": "Yermish",        "a": Vector2(-900.0, 2050.0),  "b": Vector2(-1900.0, 200.0)},
	{"nom": "Polvon",         "a": Vector2(700.0, 2100.0),   "b": Vector2(600.0, -300.0)},
	{"nom": "Qilichniyozboy", "a": Vector2(-1600.0, 1900.0), "b": Vector2(-350.0, 300.0)},
]


# --- Shovqin qatlamlari. Bir marta yaratiladi, qayta ishlatiladi. ---
static var _coast: FastNoiseLite
static var _swells: FastNoiseLite
static var _fine: FastNoiseLite
static var _dunes: FastNoiseLite
static var _dunes2: FastNoiseLite
static var _fields: FastNoiseLite
static var _ready := false


static func _ensure() -> void:
	if _ready:
		return
	_coast  = _noise(COAST_WAVELENGTH, 2, 0.45, 101)
	_swells = _noise(SWELL_WAVELENGTH, 3, 0.50, 202)
	_fine   = _noise(FINE_WAVELENGTH, 2, 0.40, 303)
	_dunes  = _noise(DUNE_WAVELENGTH, 3, 0.50, 404)
	_dunes2 = _noise(DUNE_WAVELENGTH_2, 2, 0.45, 505)
	_fields = _noise(700.0, 2, 0.50, 606)
	_ready = true


static func _noise(wavelength: float, octaves: int, gain: float, seed_offset: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = Settings.WORLD_SEED + seed_offset
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0 / wavelength
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_gain = gain
	n.fractal_lacunarity = 2.0
	return n


# =============================================================== BALANDLIK

## Dunyoning istalgan nuqtasidagi balandlik (metr, dengiz sathiga nisbatan).
##
## Bu — bitta manba: mesh, collision, obyektlar va yo'llar shundan o'qiydi.
static func height_at(x: float, z: float) -> float:
	# Yo'llar yer ostida tekis koridor bo'lishi kerak, shuning uchun
	# avval tabiiy balandlik, keyin yo'l tekislash qo'llaniladi.
	# RoadNetwork faqat _base_height ni chaqiradi — chekinish (recursion)
	# bo'lmaydi.
	return RoadNetwork.flatten(x, z, _base_height(x, z))


## Tabiiy balandlik — YO'LLARSIZ. RoadNetwork shuni ishlatadi.
static func _base_height(x: float, z: float) -> float:
	_ensure()

	# --- 1. Orol maski ---
	var fall := _island_falloff(x, z)

	# Suv osti: faqat mayin qoldiramiz, bas
	if fall <= 0.001:
		return RIVER_FLOOR + _fine.get_noise_2d(x, z) * FINE_AMPLITUDE

	# --- 2. Asosiy tekislik ---
	var h := BASE_HEIGHT
	h += _swells.get_noise_2d(x, z) * SWELL_AMPLITUDE

	# --- 3. Qum tepaliklari ---
	var dune_mask := dune_mask_at(x, z)
	if dune_mask > 0.0:
		h += (_dunes.get_noise_2d(x, z) * 0.75
			+ _dunes2.get_noise_2d(x, z) * 0.25) * DUNE_AMPLITUDE * dune_mask

	# --- 4. Mayda notekislik ---
	h += _fine.get_noise_2d(x, z) * FINE_AMPLITUDE

	# --- 5. Chegaradan cho'kish ---
	h = lerpf(RIVER_FLOOR, h, fall)

	# --- 6. Shahar tekisliklari ---
	# Tepalik qirg'oq cho'kishidan KEYIN, lekin suv o'yilishidan OLDIN
	# qo'llanadi. Shu tartib uchta kafolat beradi:
	#   * chekkadagi shaharlar (Gurlan, Pitnak) cho'kib ketmaydi
	#   * shahar ichidagi ko'l/kanal tepalik bilan to'lmaydi
	#   * shaharlar doim tekis va quruq bo'ladi
	h = _city_plateaus(x, z, h)

	# --- 7. Suv izlarini kesish (oxirida — suv har doim ustun) ---
	h = _carve_water(x, z, h)

	return h


## 0 = suv (chet), 1 = to'liq quruq quruq (markaz).
static func _island_falloff(x: float, z: float) -> float:
	var ax: float = absf(x) / ISLAND_HALF_X
	var az: float = absf(z) / ISLAND_HALF_Z
	var d: float = pow(pow(ax, FALLOFF_POWER) + pow(az, FALLOFF_POWER), 1.0 / FALLOFF_POWER)
	d += _coast.get_noise_2d(x, z) * COAST_AMPLITUDE
	return smoothstep(FALLOFF_OUTER, FALLOFF_INNER, d)


## Qum tepaliklari faqat g'arb va janubi-g'arbda — Qizilqum tomon.
## Boshqa joyda 0.
static func dune_mask_at(x: float, z: float) -> float:
	# G'arbiy va janubi-g'arbiy chorak
	var west := smoothstep(200.0, 1600.0, -x)
	var southwest := smoothstep(200.0, 1200.0, z)
	return clampf(west * 0.75 + southwest * 0.55, 0.0, 1.0)


## Amudaryo, sho'r ko'llar, G'ovuk ko'l va kanallarni balandlikka o'yadi.
static func _carve_water(x: float, z: float, h: float) -> float:
	# --- Amudaryo (janubiy qirg'oq) ---
	var river_z: float = RIVER_CENTER_Z + sin(x / RIVER_WAVE_PERIOD) * RIVER_WAVE
	var river_d: float = absf(z - river_z)
	if river_d < RIVER_HALF_WIDTH:
		# Chekkada yumshoq, markazda to'liq chuqur
		var t: float = 1.0 - smoothstep(0.0, RIVER_HALF_WIDTH, river_d)
		h = lerpf(h, RIVER_FLOOR, t * t)

	# --- Sho'r ko'llar ---
	for lake: Dictionary in SALT_LAKES:
		var d: float = Vector2(x, z).distance_to(lake["pos"])
		var r: float = lake["r"]
		if d < r:
			var t: float = 1.0 - smoothstep(r * 0.35, r, d)
			h = minf(h, lerpf(h, SALT_FLOOR, t))

	# --- G'ovuk ko'l (Xiva) ---
	var g: Dictionary = GOVUK_POOL
	var gd: float = Vector2(x, z).distance_to(g["pos"])
	var gr: float = g["r"]
	if gd < gr:
		h = minf(h, lerpf(h, GOVUK_POOL_FLOOR, 1.0 - smoothstep(0.0, gr, gd)))

	# --- Kanallar ---
	for canal: Dictionary in CANALS:
		var d2: float = _distance_to_segment(
			Vector2(x, z), canal["a"], canal["b"])
		if d2 < CANAL_HALF_WIDTH:
			# Kanal tubi tekis bo'lishi kerak — ayniqsa ko'prik uchun
			h = minf(h, lerpf(h, BASE_HEIGHT - CANAL_DEPTH,
				1.0 - smoothstep(0.0, CANAL_HALF_WIDTH, d2)))

	return h


## Sug'orish kanalining suv sathi.
##
## DIQQAT: kanal suv sathi DENGIZ sathida EMAS. Xorazm kanallari
## Amudaryodan suv oladi va tepalik bo'ylab oqadi — ya'ni ular yer
## yuzasidan yuqorida (≈ 4,6 m) turadi. Agar ularni dengiz sathiga
## tushirsak, kanallar butunlay QURUQ ko'rinadi (terrassi 3,5 m da
## qoladi, suv esa 0 m da) va ko'prik kerak joylar aniqlanmaydi.
const CANAL_WATER_LEVEL := 4.6

## Nuqtaning suv sathi (m). Kanal va ko'llarda — yuqorida, Amudaryo
## va sho'r ko'llarda — dengiz sathida.
static func water_level_at(x: float, z: float) -> float:
	var point := Vector2(x, z)

	# Kanallar — suv eng balandda
	for canal: Dictionary in CANALS:
		if _distance_to_segment(point, canal["a"], canal["b"]) < CANAL_HALF_WIDTH * 1.2:
			return CANAL_WATER_LEVEL

	# G'ovuk ko'l
	if point.distance_to(GOVUK_POOL["pos"]) < float(GOVUK_POOL["r"]) * 1.1:
		return CANAL_WATER_LEVEL

	# Sho'r ko'llar va Amudaryo — dengiz sathida
	return Settings.SEA_LEVEL


## Nuqta suv ostidami? Kanal, ko'l yoki daryo — hamma uchun.
static func is_submerged(x: float, z: float) -> bool:
	return _base_height(x, z) < water_level_at(x, z) - 0.02


## Noldan birgacha: 0 = shahar chegarasidan tashqarida, 1 = markazda.
static func _city_plateaus(x: float, z: float, h: float) -> float:
	var point := Vector2(x, z)
	for id: String in WorldMap.CITIES:
		var data: Dictionary = WorldMap.CITIES[id]
		var centre: Vector2 = WorldMap.city_position(id)
		var radius: float = data["radius"]
		var d: float = point.distance_to(centre)
		var outer: float = radius + CITY_MARGIN
		if d < outer:
			# Markazda to'liq tekislanadi, chekkada yumshoq o'tadi
			var t: float = 1.0 - smoothstep(radius * 0.75, outer, d)
			h = lerpf(h, CITY_HEIGHT, t)
	return h


static func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq < 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# =============================================================== RANG

## Nuqtaning rangi — relyef, balandlik, qiyalik va atrof-muhitga qarab.
##
## Rangning o'zi alohida "textura" emas: mesh vertex rangiga yoziladi.
## Shuning uchun umuman bitta tekstura yuklanmaydi — Intel UHD uchun
## muhim yanada tejash.
##
## MUHIM: barcha qatlamlar UZLUKSIZ aralashtiriladi. Agar biror qatlam
## `if shart: return boshqa_rang` qilib yozilsa, chegara chetlarida
## keskin chiziq paydo bo'ladi (xaritada shimoli-sharqdagi to'rtburchak
## aynan shundan kelib chiqqan edi).
static func color_at(x: float, z: float, h: float, slope: float) -> Color:
	_ensure()

	# --- 1. Asosiy: sho'rlangan bo'z tuproq va dasht ---
	var patch: float = _fields.get_noise_2d(x, z)
	var colour := Palette.SOIL.lerp(Palette.STEPPE, smoothstep(-0.4, 0.5, patch))

	# --- 2. Paxta dalalari ---
	# Xorazmning eng taniqli manzarasi: yirik to'g'ri kvadrat yamoqlar.
	colour = colour.lerp(Palette.COTTON, smoothstep(0.28, 0.75, patch) * 0.7)

	# --- 3. Qum tepaliklari (g'arb, janub-g'arb) ---
	var dune: float = dune_mask_at(x, z)
	colour = colour.lerp(Palette.SAND, dune * 0.6)

	# --- 4. Plyaj: suv yaqinida qum ---
	colour = colour.lerp(Palette.SAND, (1.0 - smoothstep(0.4, 3.2, h)) * 0.85)

	# --- 5. Qiyalik: yerga yuvilgan, qum ochilgan ---
	colour = colour.lerp(Palette.SAND_DARK, smoothstep(0.30, 0.75, slope) * 0.8)

	# --- 6. Sho'r ko'llar: oq tuz qatlami ---
	for lake: Dictionary in SALT_LAKES:
		var d: float = Vector2(x, z).distance_to(lake["pos"])
		var radius: float = lake["r"]
		colour = colour.lerp(
			Palette.SALINE, 1.0 - smoothstep(radius * 0.35, radius * 1.3, d)
		)

	# --- 7. G'ovuk ko'l (Xiva) ---
	var g: Dictionary = GOVUK_POOL
	var gd: float = Vector2(x, z).distance_to(g["pos"])
	colour = colour.lerp(
		Palette.WATER_CANAL, 1.0 - smoothstep(0.0, float(g["r"]) * 1.25, gd)
	)

	# --- 8. Suv osti: tubi qumli, chuqurligi bo'yicha ko'k ---
	if h < Settings.SEA_LEVEL:
		var depth: float = clampf(-h / 9.0, 0.0, 1.0)
		var bed := Palette.RIVERBED.lerp(Palette.WATER_AMU.darkened(0.30), depth)
		# Qirg'oqda uzluksiz o'tish
		colour = colour.lerp(bed, smoothstep(0.6, -0.6, h))

	# --- 9. YER YUZASINING MAYDA NOTEKISHLIGI ---
	# Yuqoridagi barcha ranglar 700 m to'lqin uzunligida — ya'ni yaqinda
	# butun ko'rinish maydoni bir xil rangda bo'lib chiqadi. Xorazmning
	# yuzasi esa mayda notekis: quritilgan qum dog'lari, tuz izlari,
	# ekin qoldig'i. Bu ~55 m li shovqin yerga "dono" beradi va yerga
	# tekis bo'yalgan karton emas, deshta ko'rinishiga olib keladi.
	var fine := _fine.get_noise_2d(x, z)
	colour = colour.lerp(Palette.SAND_DARK, clampf(-fine, 0.0, 1.0) * 0.30)
	colour = colour.lerp(Palette.SAND, clampf(fine, 0.0, 1.0) * 0.16)

	return colour


# =============================================================== YORDAM

## Nuqta suv ostidami (ko'llar, kanallar, daryo).
static func is_water(x: float, z: float) -> bool:
	return height_at(x, z) < water_level_at(x, z) - 0.02


## Yer ustidagi eng yaqin nuqta (obyekt qo'yish, kameralar uchun).
static func surface_y(x: float, z: float) -> float:
	return maxf(height_at(x, z), water_level_at(x, z))


## HAQIQIY yer balandligi — nishat orqali o'lchanadi.
##
## NIMA UCHUN BU KERAK (va `height_at` nega yetarli emas)
## `height_at()` ANALITIK natija: u shovin, kanallar va tekislashni
## to'g'ridan-to'g'ri hisoblaydi. Lekin ko'rish uchun chiziladigan
## chunk mesh'i 400 m kataklarda tuziladi va tugunlar ORASIDA chiziqli
## interpolatsiya qiladi. Shu sababli mesh yuzasi analitik
## balandlikdan farq qiladi: Kosiblar ko'chasi bo'ylab o'lchaganda
## 0,42 m gacha.
##
## Bu mashina uchun halokatli: mashina 0,42 m botib ketsa yoki
## havoda osilib qolsa, to'rtta g'ildorak ham noto'g'ri ishlaydi —
## g'ildorak nishati yerga tegmaydi, yetakchi kuch ishlamaydi,
## mashina qo'zg'almaydi. Shuning uchun mashinalar joylashtirilganda
## MUTLAQ shu funksiya ishlatiladi.
static func ground_height(space: PhysicsDirectSpaceState3D, x: float,
		z: float, from: float = 90.0,
		mask: int = PhysicsLayers.SOLID) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, from, z), Vector3(x, from - 260.0, z))
	query.collision_mask = mask
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return height_at(x, z)
	return (hit["position"] as Vector3).y
