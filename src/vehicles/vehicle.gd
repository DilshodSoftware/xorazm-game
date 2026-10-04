class_name Vehicle
extends RigidBody3D
## Bitta mashina: kuzov geometriyasi, osilish, haydash fizikasi
## va o'yinchi uchun joy.
##
## NIMA UCHUN O'ZIMNING FIZIKAM
## Godot'ning `VehicleBody3D` (4.7 da `RaycastVehicle3D` ning o'rniga
## kelgani) sinovlarda ishladi: g'ildorak tugunining balandligi,
## osilish sayohati, qattiqlik — hech qanday o'zgarish mashinaning
## turish balandligini ham, gaz berilgandagi harakatini ham
## o'zgartirmadi. Sinovda 0,80 m da "osilib" qolgan, gaz berilganda
## ham qo'zg'almagan. Ilgari buning sababi boshqa nuqsonlar bo'lishi
## mumkin edi (yo'nalish teskari, zarba qutisi noto'g'ri o'qda) —
## ular tuzatildi, lekin motor baribir sekin va to'g'ridan-to'g'ri
## boshqarilmaydi.
##
## Qo'lda yozilgan modelning afzalligi SHU: har bir kuch aniq
## raqam, sinov o'lchaydi, va o'yinchi shu hisni o'zgartira oladi.
## Kamchilik: qisqa (200 qator), aylanish va g'ildorak aylanishini
## o'zim boshqaraman.
##
## OSILISH MODELI
## Har bir g'ildorak uchun pastga nishat:
##   1) Bakal r=4,5 sm bosilishi (qisilish)ni topamiz
##   2) `kuch = qisilish × qattiqlik − tezlik × damping`
##   3) Kuchni tegish nuqtasida, kontakt normali bo'ylab qo'llaymiz
## G'ildorak yerga tegmasa (havoda) — kuch yo'q, faqat havo
## qarshiligi.
##
## REZLINAV ISHQALANISH
## G'ildorak markazi tezligini yerga nisbatan hisoblab, yon
## yo'nalishdagi tezlikni NOLGA keltiruvchi kuch qo'llaymiz
## (mashina burilmaydi), uzunlik yo'nalishida esa gaz va tormoz
## kuchini. Ikkalasi ham `muk` (ishqalanish koeffitsienti) va
## kontakt kuchi bilan cheklangan — shuning uchun g'ildorak
## havoda aylanadi (spinning) va tormozda mashina silinadi.
##
## YO'NALISH QOIDASI: oldingi tomon −Z (Godot qoidasi).
##
## AI MASHINALARI
## Uchun fizika butunlay o'chiriladi (`freeze = KINEMATIC`) va ular
## to'g'ridan-to'g'ri yo'l bo'ylab suriladi. Sababi: 20 ta fizikali
## mashina bir-biriga uriladi, ketma-ket to'planib qoladi va zayif
## protsessorda FPS tushadi.

## Ichkariga kirganda va chiqganda.
signal entered(who: Node3D)
signal exited(who: Node3D)

## Qo'ng'iroq bosildi.
signal horn_pressed(who: Node3D)

# ================================================================ KONSTANTALAR

## Bir g'ildorakka tushadigan og'irlik ulushi. 4 ta teng.
const WHEEL_MASS := 0.25

## Erkin prujina uzunligi, m — g'ildorak markazi osilish nuqtasidan
## shuncha pastda osilib turadi (yuki yo'q holatda).
const SUSPENSION_FREE := 0.20

## NISHAT NIMAGA URILMASLIGI KERAK (asosiy xato)
## Nishat pastga qaradi. Agar u korpusning zarba qutisi ICHIDA
## boshlanса, avval mashinaning o'ziga tegadi: kontakt nuqtasi
## korpusning pastki yuzasi, normal pastga qaragan bo'ladi, va
## prujina kuchi mashinani YERGA bosadi. Sinovda shunday bo'ldi:
## korpus yer ostida 24 sm, g'ildoraklar "kontaktda" deb
## hisoblangan, gaz berilsa ham tezlik 0.
##
## Ikki qatlamli himoya:
##   1) nishat boshi `RAY_ORIGIN_Y` (0,06 m) da — korpus pastidan
##      pastda, ya'ni uning ichida emas
##   2) korpusning pastki qirrasi radius + 6 sm da — osilish
##      nuqtasidan baland, ya'ni korpus hech qachon yerga tegmaydi
##      va mashinani faqat osilish ushlab turadi
## Nishat boshining korpusga nisbatan balandligi, m.
##
## DIQQAT: bu qiymat KORPUS ZARBA QUTISINING PASTIDAN kichik
## bo'lishi SHART — aks holda nishat qutining ichidan o'tib, avval
## mashinaning o'ziga tegadi (yuqoraga qarang). Pastda turishi
## yordamchi: nishat bosh korpus pastida qoladi.
const RAY_ORIGIN_Y := 0.06

## Nishat uzunligi — to'liq cho'zilgan holatda ham yerni topishi
## uchun erkin prujina uzunligi + sayohat + zaxira.
const RAY_REACH := 0.62

## Natija: nuqta `radius` balandlikda (g'ildorak o'qida — fizikada
## to'g'ri shunday), ko'rinadigan g'ildorak markazi esa statik
## cho'zilish hisobga olingan holda nuqtadan pastda.

## Osilish (suspenziya). `qattiqlik` — N/m. 1000 kg li mashinada
## statik bosilish = m·g / 4 / qattiqlik ≈ 0,11 m — bu real.
const SUSPENSION_TRAVEL := 0.22      ## m — osilishning yurish chegarasi
const SUSPENSION_STIFFNESS := 24000.0  ## N/m
const SUSPENSION_DAMPING := 3000.0   ## N/(m/s)

## Ishqalanish. `MUK` — chek: kontakt kuchiga ko'ra qancha kush
## uzatish mumkinligi.
const MUK := 2.4                     ## asfalt (uzunlik — yetakchi kuch)
## Yon ishqalanish chegarasi.
##
## DIQQAT: bu MUK dan KICHIK bo'lishi SHART. Yon kuch g'ildorak
## burilgan yo'nalishiga PERPENDIKULAR, shuning uchun uning
## mashinaning oldingi yo'nalishiga ham komponenti bor. Agar chegara
## 2,4 g bo'lsa, to'liq burishda bu komponent 6 kN ga chiqadi va
## mashina gaz berilgan holda ham TORMOZLANADI (sinovda: 11,8 →
## 2,2 km/soat, burchak o'zgarmadi). Haqiqiy mashina maksimal
## 0,8–1,0 g bilan buriladi.
const MUK_LATERAL := 1.0

## Maksimal YON TEZLANISH, m/s². To'liq burish burchagida shu
## tezlanishga intiladi.
##
## DIQQAT: avval burchak kuchiga proportsional kuch ishlatilardi
## (`TURN_GAIN = 0,75`), ya'ni tik yon tezlanish DOIMIY ~2,1 m/s²
## edi. Shundan burish radiusi `R = v²/a` bo'lib chiqadi va
## tezlik KVADRATI bilan o'sadi: 72 km/h da 188 m — ko'chada qator
## almashib bo'lmasdi. Endi aylanish radiusi beriladi va tezlanish
## undan hisoblanadi.
##
## `8,0` m/s² ≈ 0,82 g — bu yengil mashina (Nexia, Spark) uchun
## real chegara. Kalka qishloq sharoitida 0,9 g gʻilish mumkin,
## ammo u holda mashina "qayiq" bo'lib ketadi va tormozlashni
## yo'qotadi (sinovda 11,8 → 2,2 km/soat holati).
const TURN_ACCEL := 8.0

## Tezlikda burish kuchining yumshalishi, m/s. Yuqoridagi
## formuladagi bo'luvchi: shu tezlikdan boshlab kuch
## `v / 18,0` ga bo'linadi. Bu qamishli burishni beradi — 18 m/s
## (65 km/h) da kuch 1,0 bo'ladi, 36 m/s da 0,5.
const TURN_SOFTEN_SPEED := 18.0

const MUK_HANDBRAKE := 0.9           ## qo'lda tormoz — orqa g'ildorak
const AERO_DRAG := 0.9              ## havo qarshiligi (tezlik² ga)
## G'ildorak aylanish qarshiligi. Haqiqiy qiymat vaznning 1–2% —
## bu yerda 0,4% (yangi rezin, tekis asfalt). Katta qiymat sekin
## tezlanishga olib keladi: 0,012 da Nexia 2 soniyada 9 km/soat
## ga chiqardi (haqiqiyda ~14).
const ROLL_RESISTANCE := 0.004

## Burish tezligi (rad/s).
const STEER_SPEED := 2.6

# --- O'zi haqida ---
var spec: Dictionary = {}
var model_key := "spark"
var colour: Color = Color.WHITE
var occupied := false

## Soat millimetridagi tezlik — HUD uchun.
var speed_kmh := 0.0

## Kim haydayapti (null = bo'sh).
var driver: Node3D = null

## Fizika yoqilganmi? true = o'yinchi, false = AI.
var physics_driven := false

## Beshlang'ich sozlama — sinov va sozlash uchun.
## G'ildoraklar qo'llanadimi (alohida tugun) yoki kuzov mesh'iga
## birlashtirilganmi (statik) — qarang `_build_wheels`.
##
## QO'YILGAN (parkovlangan) mashinalarda aylanish KERAK EMAS:
## ular turgan, demak statik g'ildorak fizikaga to'g'ri va
## 0 ta qo'shimcha chizqich. HARAKATLANUVCHI AI mashinalarida
## aylanish kerak — uzoqdan qaraganda "qotib qolgan" g'ildorak
## o'yinchi darajasini pasayiradi.
var wheels_animate := false

var max_steer := 0.0
var steer_now := 0.0
var engine_now := 0.0
var brake_now := 0.0
var handbrake_now := 0.0

var _wheel_attach: Array[Vector3] = []
var _wheel_visual: Array[MeshInstance3D] = []
var _wheel_spin := 0.0
var _wheel_mesh: Mesh = null
var _on_floor := false
var _steps := 0


## Nechta fizika kadrida osilish hisoblangan (sinov uchun).
func integration_steps() -> int:
	return _steps


func _ready() -> void:
	add_to_group("vehicles")


## Mashinani quradi: geometriya, urish shakli, osilish nuqtalari.
## [param driveable] — o'yinchi haydaydimi yoki kinematik AI?
## [param animate_wheels] — g'ildoraklar aylanadimi? Qo'yilgan
## mashinalar uchun `false`: ular turgan, statik g'ildorak to'g'ri
## va kuzov mesh'iga birlashtirilishi bilan 4 ta chizqich
## tejlanadi (41 ta mashina = 164 ta chizqich).
static func create(model: String, body_colour: Color,
		driveable: bool, animate_wheels: bool = true) -> Vehicle:
	var vehicle := Vehicle.new()
	vehicle.model_key = model
	vehicle.spec = CarSpecs.find(model)
	vehicle.physics_driven = driveable
	# O'yinchi va HARAKATLANUVCHI AI mashinalarida g'ildoraklar
	# aylanadi. Qo'yilgan mashinalarda esa statik qoladi.
	vehicle.wheels_animate = animate_wheels
	vehicle.name = "Mashina_%s" % model
	vehicle.collision_layer = PhysicsLayers.VEHICLE
	vehicle.mass = float(vehicle.spec["massa"])
	vehicle.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# Og'irlik markazi pastda — shunda mashina egilmaydi va
	# to'qnashganda aylanib ketmaydi
	vehicle.center_of_mass = Vector3(0.0, -0.05, 0.0)
	vehicle.linear_damp = 0.0
	vehicle.angular_damp = 0.35
	# DIQQAT: uxlab turish MUTLAQ o'chiriladi. Godot jism
	# sekinlashganda uni "uxlatadi" va gravitatsiya ham to'xtaydi.
	# Qo'lda joylashtirilgan mashina darhol uxlaydi, keyin gaz
	# berilsa ham `_integrate_forces` chaqirilmaydi — mashina
	# qo'zg'almaydi. Sinovda shunday chiqdi: 0,80 m da "osilib"
	# turgan, tezligi 0,11 m/s (gravitatsiya emas).
	vehicle.can_sleep = false
	vehicle.max_steer = float(vehicle.spec["burish"])
	vehicle.set_meta("tezlik", 0.0)
	if driveable:
		vehicle.collision_mask = PhysicsLayers.SOLID | PhysicsLayers.VEHICLE
	else:
		# Kinematik AI mashinasi: og'irmaydi, aylanmaydi
		vehicle.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		vehicle.freeze = true
		vehicle.collision_mask = 0
		vehicle.can_sleep = false
	vehicle.colour = body_colour if body_colour.a > 0.0 \
		else vehicle.spec.get("rangi", Palette.CAR_WHITE)
	vehicle._build()
	return vehicle


# ================================================================ QURILISH

func _build() -> void:
	_build_body()
	_build_collision()
	_build_wheels()


## Kuzov geometriyasi.
##
## DIQQAT: material `MeshBuilder.commit` orqali qo'yiladi, qo'lda
## emas — aks holda vertex ranglari (kuzov rangi, shisha, chiroq)
## ishlamaydi va orqa yuzalar cull qilinadi.
## Barcha mashinalar uchun umumiy material (bir marta yaratiladi).
static var _shared_body_material: StandardMaterial3D = null


## Yuk ostida prujinaning statik siqilishi, m.
##
## Ko'rinadigan g'ildorak shu miqdorda chizilishi SHART, aks holda
## mashina yerga tegmaydi yoki botib qoladi: `m·g/4 / qattiqlik`.
static func _wheel_sag(spec: Dictionary) -> float:
	return float(spec["massa"]) * 9.8 / 4.0 / SUSPENSION_STIFFNESS


## Kuzov geometriyasini umumiy material bilan yig'adi.
##
## DIQQAT: bu alohida funksiya, chunki `MeshBuilder.commit()` har
## chaqiruvda YANGI material yaratadi. 76 ta mashina uchun 76 ta
## alohida material — `gl_compatibility` renderer har biriga shayder
## variantini qayta kompilyatsiya qiladi.
##
## O'lchov: 0 ta mashina 9,5 s, 1 ta mashina 40 s (40 kadr).
## Bo'lish mumkin, chunki rang mesh VERTEX ranglarida saqlanadi —
## material barchasi uchun bir xil.
## Kuzov MESH'i model + rang bo'yicha keshlanadi.
static var _body_cache: Dictionary = {}


## [param animate] — g'ildoraklar aylanadimi? Agar `false` bo'lsa,
## ular kuzov mesh'i ichiga chiziladi va alohida chizqich kerak
## bo'lmaydi. Qo'yilgan mashinalar uchun shunday (ular turgan —
## statik g'ildorak to'g'ri).
static func _build_shared_body(parent: Node3D, spec: Dictionary,
		colour: Color, animate: bool = true) -> void:
	if _shared_body_material == null:
		_shared_body_material = StandardMaterial3D.new()
		_shared_body_material.vertex_color_use_as_albedo = true
		_shared_body_material.roughness = 0.38
		_shared_body_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		_shared_body_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# DIQQAT: geometriya GDScript sikllari bilan chiziladi (~4000
	# uchburchak, har biri uchta `add_vertex` chaqiruvi). Bir
	# mashinani qurish sekin — ko'chada 76 ta mashina bo'lsa, har
	# birini alohida qurish 30 s yig'iladi (o'lchov: 0 ta mashina
	# 9,5 s, 1 ta mashina 40 s).
	#
	# Yechim: bir xil model + bir xil rang bitta mesh bo'ladi.
	# 76 ta mashina 5 model × 5 rang = ~25 ta qurish.
	# G'ildorak joylari — statik kuzov ichida chiziladi.
	# Boshlang'ich nuqta g'ildorak O'QIDA (fizikada to'g'ri),
	# ko'rinadigan g'ildorak esa statik osilish hisobiga
	# (`sag - SUSPENSION_FREE`) pastroqda chiziladi.
	var wr: float = float(spec["radius"])
	var ww: float = float(spec["en_kenglik"])
	var wb: float = float(spec["gildorak"]) * 0.5
	var wt: float = float(spec["iz"]) * 0.5
	var wdy: float = wr + _wheel_sag(spec) - SUSPENSION_FREE
	var i := Vector3(-wt, wdy, -wb)
	var j := Vector3(wt, wdy, -wb)
	var k := Vector3(-wt, wdy, wb)
	var l := Vector3(wt, wdy, wb)
	var radius := wr
	var width := ww

	var key := "%s|%s|%s" % [spec["kalit"], colour.to_html(false),
		"1" if animate else "0"]
	var mesh: Mesh = null
	if _body_cache.has(key):
		mesh = _body_cache[key]
	else:
		var builder := MeshBuilder.new()
		builder.want_collision = false
		CarShapes.build(builder, spec, Vector3.ZERO, colour, false)
		# AI mashinasining g'ildoraklari KUZOV MESH'I ichiga
			# chiziladi (ko'rish uchun o'zgartirish mumkin emas —
			# ular kinematik, `place_on_road` faqat butun mashinani
		# ko'chiradi). Bu 5 ta chizqichni 1 ga tushiradi.
		if not animate:
			# Statik g'ildorak kuzov ichida — alohida chizqich kerak
			# emas (parkovlangan mashina uchun to'g'ri: u turadi).
			CarShapes.build_wheel_at(builder, i, radius, width)
			CarShapes.build_wheel_at(builder, j, radius, width)
			CarShapes.build_wheel_at(builder, k, radius, width)
			CarShapes.build_wheel_at(builder, l, radius, width)
		if builder.is_empty():
			push_error("Mashina kuzovi bo'sh qoldi: %s" % spec["kalit"])
			return
		mesh = builder.build_mesh()
		_body_cache[key] = mesh

	var node := MeshInstance3D.new()
	node.name = "Kuzov"
	node.mesh = mesh
	node.material_override = _shared_body_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)



## Kuzovni quradi.
##
## DIQQAT: avval shu funksiya `CarShapes.build` ni CHAQRIDI, uni
## tekshirdi va TASHLAB KETDI — keyin `_build_shared_body` xuddi
## shu geometriyani yana qurardi (yoki keshdan olardi). Ya'ni har
## bir mashina uchun ~4000 uchburchak ikki marta chizilardi.
##
## Bu keshni foydasiz qilgan edi: kesh ishlagan holatda ham
## `_build_body` ning chiqindi qismi har doim to'liq chizilardi.
## O'lchov: ko'chadagi 76 ta mashina boshlang'ich yuklanishni
## 30 s oshirardi.
func _build_body() -> void:
	# DIQQAT: soya faqat O'YINCHI mashinasida. AI va qo'yilgan
	# mashinalar soyasiz: ularning hammasi soya xaritasiga tushsa,
	# har biriga ~4000 uchburchak qo'shilardi. Past quyosh soyasi
	# uzoqda ham deyarli ko'rinmaydi.
	_build_shared_body(self, spec, colour, wheels_animate)


## Zarba shakli.
##
## DIQQAT: X = kenglik, Z = uzunlik (−Z oldingi tomon). Pastki qirra
## osilish nuqtasidan BALAND bo'lishi SHART — aks holda nishat
## korpusning o'ziga tegadi.
func _build_collision() -> void:
	var length: float = float(spec["uzunlik"])
	var width: float = float(spec["kenglik"])
	# DIQQAT: pastki qirra osilish nuqtasidan BALAND bo'lishi SHART.
	# Aks holda korpus yerga tegib, mashinani o'zi ko'tarib turadi va
	# osilish umuman ishlamaydi (sinovda shunday: korpus yer ostida
	# 24 sm, prujina kuchi 0).
	var floor_y: float = float(spec["radius"]) + 0.06
	var top_y: float = float(spec["balandlik"]) - 0.08
	var shape := CollisionShape3D.new()
	shape.name = "Zarba"
	var box := BoxShape3D.new()
	box.size = Vector3(width * 0.88, maxf(top_y - floor_y, 0.2), length * 0.84)
	shape.shape = box
	shape.position = Vector3(0.0, (floor_y + top_y) * 0.5, 0.0)
	add_child(shape)


## To'rtta g'ildorak: osilish nuqtasi + ko'rinadigan mesh.
##
## DIQQAT: osilish nuqtasi `radius + 0.10` balandlikda — ya'ni to'xtagan
## holatda g'ildorak markazi yerga tegadi. Sinovda 0,10 … 0,70 m
## oralig'i o'lchandi; bu qiymatda to'rtta g'ildorak ham yerga
## tegadi va mashina 0,5 s ichida to'liq qo'zg'aladi.
func _build_wheels() -> void:
	var radius: float = float(spec["radius"])
	var width: float = float(spec["en_kenglik"])
	var base: float = float(spec["gildorak"]) * 0.5
	var track: float = float(spec["iz"]) * 0.5
	# Osilish nuqtasi g'ildorak O'QIDA turadi — fizikada to'g'ri
	# shunday. Shu bilan birga prujina erkin uzunligi
	# `SUSPENSION_FREE` (0,20 m) g'ildorakni pastga osiltiradi.
	var attach_y: float = radius
	# Yuk ostida prujina `m·g/4 / qattiqlik` ga siqiladi — shu
	# miqdorda g'ildorak markazi ko'tariladi. Ko'rinadigan
	# g'ildorak shu statik holatda chizilishi SHART, aks holda
	# mashina yerga tegmaydi yoki botib qoladi.
	var sag: float = _wheel_sag(spec)

	# Osilish nuqtalari har doim to'ldiriladi — ular FIZIKA uchun
	# kerak (nishat, moment). AI mashinalarida ham kerak, chunki
	# `place_on_road` shularni ishlatadi.
	for front: bool in [true, false]:
		for side: float in [-1.0, 1.0]:
			# X = yon tomon, Z = oldingi (−Z)
			_wheel_attach.append(Vector3(side * track, attach_y,
				-base if front else base))

	# DIQQAT: ko'rinadigan g'ildorak tugunlari faqat O'YINCHI
	# mashinasida qilinadi. AI mashinalarida ular kuzov mesh'i ichida
	# chizilgan (`_build_shared_body`) va aylanmaydi — ular
	# kinematik. Sabab: har bir tugun bitta chizqich; 76 ta AI
	# mashinasida 4 tadan = 304 chizqich, o'rniga 76 ta.
	if not wheels_animate:
		return

	var mesh := _wheel_visual_mesh()
	for slot in _wheel_attach.size():
		var node := MeshInstance3D.new()
		node.name = "Gildorak_%d" % slot
		node.mesh = mesh
		# Silindrning ekseni X — mesh allaqon shunday chizilgan
		node.position = _wheel_attach[slot] \
			+ Vector3(0.0, sag - SUSPENSION_FREE, 0.0)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_wheel_visual.append(node)


## Bitta g'ildorak mesh'i — to'rt g'ildorak ham, hamma mashinalar ham
## bitta nusxani ishlatadi.
static var _wheel_cache: Dictionary = {}
static var _shared_wheel_material: StandardMaterial3D = null


## G'ildorak mesh'i — O'LCHAM BO'YICHA KESHLANADI.
##
## DIQQAT: avval har bir mashina o'z g'ildorak mesh'ini qurardi
## (76 ta alohida mesh + material). Endi bir xil radius/En kombinatsiya
## uchun bitta nusxa ishlatiladi.
func _wheel_visual_mesh() -> Mesh:
	if _wheel_mesh != null:
		return _wheel_mesh
	var key := "%0.3f_%0.3f" % [float(spec["radius"]),
		float(spec["en_kenglik"])]
	if _wheel_cache.has(key):
		_wheel_mesh = _wheel_cache[key]
		return _wheel_mesh
	var builder := MeshBuilder.new()
	builder.want_collision = false
	CarShapes.build_wheel(builder, float(spec["radius"]),
		float(spec["en_kenglik"]))
	if _shared_wheel_material == null:
		_shared_wheel_material = StandardMaterial3D.new()
		_shared_wheel_material.vertex_color_use_as_albedo = true
		_shared_wheel_material.roughness = 0.86
		_shared_wheel_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_shared_wheel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wheel_mesh = builder.build_mesh()
	_wheel_mesh.surface_set_material(0, _shared_wheel_material)
	_wheel_cache[key] = _wheel_mesh
	return _wheel_mesh


# ================================================================ OSILISH

## Har bir fizika kadrida chaqiriladi.
##
## DIQQAT: nishatlar `_physics_process` da qilinadi, `_integrate_forces`
## ICHIDA EMAS.
##
## Sababi sinovda topildi: fizika vaqti davomida (`_integrate_forces`)
## chaqirilgan nishat jismning O'Z korpusiga uriladi — jismning
## `exclude` ro'yxati ishlamaydi. Natijada har bir g'ildorak
## "kontaktda" bo'lib, 5280 N bosim qilardi (0,22 m maksimal
## siqilish), korpus esa yerga botib, o'z zarba qutisi bilan turib
## qolardi: gaz berilsa ham tezlik 0.
##
## `_physics_process` da nishat to'g'ri ishlaydi va kuch `apply_force`
## orqali keyingi kadrga qo'llaniladi. Bu bir kadr kechikish
## (16 ms) — sezilmaydi.
func _physics_process(delta: float) -> void:
	_delta = delta
	if not physics_driven or freeze:
		update_speed()
		return
	_steps += 1
	var basis := global_transform.basis
	var up: Vector3 = basis.y
	var body_velocity: Vector3 = linear_velocity
	var omega: Vector3 = angular_velocity
	var origin: Vector3 = global_position
	var contacts := 0
	var normal_forces: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var hits: Array[Vector3] = []
	_last_torque = Vector3.ZERO

	for i in _wheel_attach.size():
		var radius: float = float(spec["radius"])
		# Nishat korpus qutisining OSTIDAN boshlanadi (yuqoraga qarang)

		# DIQQAT: avval BARCHA to'rtta nishat MASHINANING MARKAZIDAN
		# chiqardi (`origin + up * balandlik`) — `_wheel_attach` ning
		# X/Z qismi ishlatilmagan edi. Natijada to'rt g'ildorak bir
		# xil nuqtada yerga urildi, `lever` deyarli nol bo'ldi va
		# momentlar bir-birini bekor qildi: jamlangan moment
		# (−7, 0, −3) N·m. Sinovda shunday ko'rindi — to'liq burishda
		# burchak 0° qoldi.
		#
		# Endi nishat har bir g'ildorakning o'z nuqtasidan
		# chiqadi, lekin korpus qutisining OSTIDA qoladi.
		var ray_origin: Vector3 = global_transform * Vector3(
			_wheel_attach[i].x, RAY_ORIGIN_Y, _wheel_attach[i].z)
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin, ray_origin - up * RAY_REACH)
		query.collision_mask = PhysicsLayers.SOLID
		query.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state \
			.intersect_ray(query)
		if hit.is_empty():
			hits.append(Vector3.ZERO)
			continue
		contacts += 1
		var point: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		hits.append(point)
		# Bakal bosilishi.
		#
		# Nishat boshi yerga `d` masofada. Nishat boshi korpusning
		# `RAY_ORIGIN_Y` balandligida, prujina esa erkin holda
		# `SUSPENSION_FREE` uzunlikda osilib turadi. Shuning uchun
		#     siqilish = (erkin uzunlik + RAY_ORIGIN_Y) − d
		# Chassi pastga tushganda `d` kamayadi — prujina siqiladi.
		var compression: float = clampf(
			SUSPENSION_FREE + RAY_ORIGIN_Y - ray_origin.distance_to(point),
			0.0, SUSPENSION_TRAVEL)
		# Nuqtadagi tezlik (qat'iy nuqta + burchak tezligi)
		var point_velocity: Vector3 = body_velocity \
			+ omega.cross(point - origin)
		var sinking: float = point_velocity.dot(normal)
		var force: float = compression * SUSPENSION_STIFFNESS \
			- sinking * SUSPENSION_DAMPING
		force = clampf(force, 0.0, 60000.0)
		normal_forces[i] = force
		# Kuch markazda qo'llanadi, moment alohida hisoblanadi.
		#
		# DIQQAT: `apply_force(kuch, nuqta)` ning nuqta argumenti
		# shu jismda moment hosil qilmadi — sinovda aniqlandi:
		# `apply_torque(5000 N·m)` → 49° aylanish, lekin bir xil
		# miqdordagi kuch `apply_force` orqali aylantirmadi.
		# Shuning uchun endi kuch va moment AJRATILADI:
		#   * kuch — markazda (tormoq kuchi yo'q)
		#   * moment — `lever × kuch` orqali, ochiq formula bilan
		# Bu shaklda natija nazorat ostida va o'qilishi mumkin.
		var lever: Vector3 = point - origin
		apply_force(normal * force)
		apply_torque(lever.cross(normal * force))
	_on_floor = contacts > 0
	_last_forces = normal_forces
	_last_hits = hits
	if contacts == 0:
		return

	# --- Rezvin ishqalanish ---
	_apply_tyres(basis, up, hits, normal_forces, delta)

	# --- Havo qarshiligi ---
	var speed := body_velocity.length()
	if speed > 0.2:
		apply_central_force(
			-body_velocity.normalized() * speed * speed * AERO_DRAG * mass / 1000.0)


## G'ildoraklarning yon va uzunlik kuchlari.
##
## DIQQAT: `apply_force(kuch, nuqta)` — KUCH birinchi argument.
func _apply_tyres(basis: Basis, up: Vector3, hits: Array[Vector3],
		normal_forces: Array[float], delta: float) -> void:
	var origin: Vector3 = global_position
	var body_velocity: Vector3 = linear_velocity
	var omega: Vector3 = angular_velocity
	var share: float = mass * WHEEL_MASS

	for i in _wheel_attach.size():
		if normal_forces[i] <= 0.0:
			continue
		var front: bool = i < 2
		# G'ildorakning yo'nalishlari
		# Uzunlik yo'nalishi — burilgan holda (bu to'g'ri: shina
		# aylanish o'qi bo'ylab yuguradi).
		var forward: Vector3 = -basis.z
		if front:
			forward = forward.rotated(up, steer_now)
		forward = (forward - up * forward.dot(up)).normalized()
		# Yon yo'nalishi — MASHINANING o'z yoniga qaragan.
		#
		# DIQQAT: bu burilgan g'ildorak yo'nalishiga PERPENDIKULAR
		# emas. Shunday qilib yon kuch mashinaning oldinga
		# yo'nalishida katta TORMOQ kuchi hosil qilardi: to'liq
		# burishda (0,58 rad) yon kuch μ·N ga tegadi va uning
		# oldinga komponenti 2 × 2700 N bo'ladi — dvigatel kuchi
		# (1950 N) ustidan ham ko'p. Natija: mashina gaz berilgan
		# holda ham 1 km/soatdan oshmaydi va burilmaydi.
		# Sinovda shunday ko'rindi: 0,75 soniyada 1,1 km/soat,
		# burchak 0°.
		#
		# Ko'p arcade o'yin ham shuni qiladi: yon kuch doim
		# mashinaning o'z yon tomoniga qarab yo'naltiriladi.
		var car_forward: Vector3 = -basis.z
		car_forward = (car_forward - up * car_forward.dot(up)).normalized()
		var side: Vector3 = car_forward.cross(up).normalized()

		var lever: Vector3 = hits[i] - origin
		var point_velocity: Vector3 = body_velocity + omega.cross(lever)
		var v_forward: float = point_velocity.dot(forward)
		var v_side: float = point_velocity.dot(side)

		# --- Yon ishqalanish ---
		#
		# DIQQAT: bu qism ikki marta qayta yozildi, sababi ham
		# o'zgarildi. Maqomi — arxiv:
		#
		# 1) Birinchi urinish: tezlikni to'liq nolga keltirish
		#    (`−v_side × ulush / delta`). Har doim chegaraga
		#    tegib, aylanish momentini butunlay yo'q qiladi —
		#    mashina qo'lda ham to'g'ri ham yurardi (3° / 2 s).
		#
		# 2) Ikkinchi urinish: sirish burchagi modeli
		#    (`slip × qattiqlik`), o'lchash BURILGAN g'ildorak
		#    yo'nalishiga nisbatan. To'g'ri fizika, lekin yon kuch
		#    mashinaning oldingi yo'nalishida 2 × 2700 N tormoq
		#    kuchi yaratdi — dvigatel kuchidan (1950 N) ko'p.
		#    Mashina gaz berilgan holda 1,1 km/soatdan oshmadi.
		#
		# 3) Uchinchi urinish: yon kuch mashina yo'nalishiga
		#    bog'langanda tormoq yo'qoldi, lekin burish burchagi
		#    kuchga umuman ta'sir qilmadi (0°, 4,8 km/soat).
		#
		# YECHIM (hozirgi): ARCADE MODEL
		#   * oldingi g'ildorak — yon kuch burish burchagiga
		#     PROPORSIONAL. Bu aylanish momentini yaratadi
		#     (`steer × N × TURN_GAIN`), shuning uchun mashina
		#     tezligidan qat'i nazar buriladi (kinematik
		#     boshqaruv — ko'plab arcade o'yinlar shunday).
		#   * orqa g'ildorak — yon silinishga qarsiliq: yon
		#     tezlikni NOLGA keltiradi, ya'ni mashina yonmaydi,
		#     faqat buriladi.
		#   * ikkalasi ham mashinaning o'z yon tomoniga
		#     qo'llaniladi → oldinga yo'nalishda tormoq yo'q.
		#
		# YAQINROQ VAQT: barcha g'ildorak uchun to'liq sinish
		# modeli (shina egilishi, yuklash transferi, ABS).
		# Hozirgi model atayin va ishonchli, lekin yuqori
		# tezlikda real emas.
		var limit: float = normal_forces[i] * MUK_LATERAL
		if not front:
			# Qo'lda tormozda orqa ishqalanish susadi — mashina
			# yonma-yon silinadi (odatdagidek)
			limit *= lerpf(MUK_LATERAL, MUK_LATERAL * 0.4, handbrake_now)
		var side_force := 0.0
		if front:
			# DIQQAT: bu avval `-steer × N × TURN_GAIN` edi —
			# tezlikka bog'liq EMAS. Natijada tinch burishda
			# tik yon tezlanish doimiy qolardi (~2,1 m/s²) va
			# burish radiusi `R = v²/a` bo'lib TEZLIK KVADRATI bilan
			# o'sardi: 72 km/h da 188 m! Ko'chada qator almashib
			# bo'lmasdi. Endi burchak kuchiga emas, KERAKLI yon
			# tezlanishga o'tiladi: `a = vaqt / R`, ya'ni sekin
			# tezlikda kuchli, tez tezlikda yumshoq (kamera).
			var steer_ratio: float = steer_now / maxf(max_steer, 0.01)
			var wanted_lat: float = steer_ratio * TURN_ACCEL \
				/ maxf(1.0, absf(linear_velocity.dot(Vector3.FORWARD))
					/ TURN_SOFTEN_SPEED)
			side_force = clampf(-wanted_lat * mass * 0.5, -limit, limit)
		else:
			side_force = clampf(-v_side * share / delta, -limit, limit)

		# --- Uzunlik kuchi: gaz, tormoz, aylanish qarshiligi ---
		#
		# DIQQAT: `dvigatel` va `tormoz` JAMI kuch (N). Ikki orqa
		# g'ildorak bo'lgani uchun ularning hissasi yarim. Bu
		# noto'g'ri bo'lsa (masalda butun kuch har bir
		# g'ildorakka berilsa), mashina to'rt barobar tez
		# tezlashadi.
		var drive := 0.0
		if not front:
			drive = engine_now * 0.5
		# Tormoz: oddiy tormoz to'rtala g'ildorakka, qo'lda tormoz
		# faqat orqaga
		# DIQQAT: `car_specs.gd` da `tormoz` — JAMI kuch (N). To'rt
		# g'ildorakka teng taqsimlanishi uchun 0,25 kerak. 0,5
		# bilan har biriga ikki barobar ko'p berilardi, qo'lda
		# tormozda esa uch barobar.
		var brake := brake_now * 0.25
		if not front:
			# Qo'lda tormoz orqa g'ildoraklarga qo'shimcha
			brake += brake_now * handbrake_now * 0.5
		# G'ildorak aylanish qarshiligi — tezlikka proporsional,
		# kontakt kuchiga bog'liq (haqiqiy shunday)
		var roll := -v_forward * normal_forces[i] * ROLL_RESISTANCE

		# Tormoz ham, gaz ham ishqalanish chegarasidan o'tmaydi —
		# aks holda mashina tormozlaganda ham sirg'alib ketardi
		# DIQQAT: `signf(0.0)` nol qaytaradi — tik yo'lda to'xtagan
		# mashinani tormoz USHLAMASDI (tezlik nolga tushgach kuch
		# yo'qolardi). Tezlik juda kichik bo'lsa yo'nalish +1
		# olinadi: tormoz kuchi nol bo'lmaydi.
		var dir := signf(v_forward)
		if absf(v_forward) < 0.05:
			dir = 1.0
		var total: float = drive + roll - brake * dir
		# DIQQAT: avval chegara `limit` (LATERAL chegarasi) edi, ya'ni
		# gaz va tormoz kuchi ham yon ishqalanish koeffitsientiga
		# bog'langan. Noto'g'ri: asfaltda ham, g'ishtda ham
		# uzunlik ishqalanishi bor. Endi o'z koeffitsienti.
		var long_limit: float = normal_forces[i] * MUK \
			* (0.6 if (not front and handbrake_now > 0.5) else 1.0)
		var long_force: float = clampf(total, -long_limit, long_limit)

		_last_side[i] = side_force
		# Xuddi shuningdek: kuch markazda, moment alohida.
		var tyre: Vector3 = forward * long_force + side * side_force
		apply_force(tyre)
		_last_torque += lever.cross(tyre)
		apply_torque(lever.cross(tyre))


# ================================================================ KIRISH

## Kamera uchun o'tirish nuqtasi (balandlik past — ichki ko'rinish).
func seat_position() -> Vector3:
	var base: float = float(spec["gildorak"]) * 0.5
	var eye: float = float(spec["balandlik"]) * 0.60
	return global_position + global_transform.basis * Vector3(
		-base * 0.10, maxf(eye, 1.05), 0.0)


## Chiqish nuqtasi — eshik tomoni, yurish yo'li tomonida.
##
## DIQQAT: qaysi tomon ekani YER ostidagi yo'nalishdan topiladi
## (`forward.cross(UP)`), o'z o'zidan emas. Aks holda mashina
## ko'chaga to'g'ri qaragan bo'lsa, o'yinchi yo'lning ichiga tushib
## qoladi va orada qisilib qoladi.
func exit_position() -> Vector3:
	var half: float = float(spec["kenglik"]) * 0.5
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var door := Vector3(
		global_position.x + right.x * (half + 0.85)
			+ forward.x * float(spec["gildorak"]) * 0.30,
		0.0,
		global_position.z + right.z * (half + 0.85)
			+ forward.z * float(spec["gildorak"]) * 0.30)
	door.y = TerrainGen.height_at(door.x, door.z) + 0.15
	return door


func wheels() -> Array[MeshInstance3D]:
	return _wheel_visual


func forward_vector() -> Vector3:
	return -global_transform.basis.z


func speed() -> float:
	return speed_kmh


## Yerga teggan g'ildoraklar soni (sinov uchun).
func wheels_on_floor() -> int:
	var n := 0
	for i in _wheel_attach.size():
		var attachment: Vector3 = global_transform * _wheel_attach[i]
		var reach: float = float(spec["radius"]) + SUSPENSION_TRAVEL
		var query := PhysicsRayQueryParameters3D.create(
			attachment, attachment - global_transform.basis.y * (reach + 0.05))
		query.collision_mask = PhysicsLayers.SOLID
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			n += 1
	return n


## Oxirgi kadrda hisoblangan kontakt kuchlari (sinov uchun).
func suspension_forces() -> Array[float]:
	return _last_forces


var _last_forces: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _last_hits: Array[Vector3] = []


## Oxirgi kadrda kontakt nuqtalari (sinov uchun).
func contact_points() -> Array[Vector3]:
	return _last_hits


## Oxirgi kadrda hisoblangan yon kuch (sinov uchun).
func side_forces_now() -> Array[float]:
	return _last_side


## Jamlangan moment (sinov uchun).
func torque_now() -> Vector3:
	return _last_torque


var _last_torque := Vector3.ZERO


var _last_side: Array[float] = [0.0, 0.0, 0.0, 0.0]


## Barcha g'ildorak yerdan ko'tarilganmi (havoda).
func is_airborne() -> bool:
	return not _on_floor


## Ko'rinadigan g'ildoraklarni buradi va aylantiradi.
##
## DIQQAT: aylanish `rotate_object_local` bilan JAMLANIB emas,
## to'g'ridan-to'g'ri rotatsiya bilan qo'yiladi.
##
## Sababi o'lchovda topildi: `rotate_object_local` har chaqiruvda
## matritsani ko'paytiradi va tugunga "transform o'zgardi" deb
## xabar beradi — bu esa meshning chegarasini (AABB) bekor qiladi.
## 35 ta mashina × 4 g'ildorak = 140 ta tugun, har kadrda →
## FPS 60 dan ~1 ga tushdi (40 kadr 0,7 s dan 40 s ga).
##
## Bundan tashqari burchak `TAU` ga qisqartiriladi — aks holda
## sonlar son bo'lib, aniqlikni yo'qotadi va meshning chegarasi
## yana kengayadi.
func _update_visuals(delta: float) -> void:
	var radius: float = maxf(float(spec["radius"]), 0.1)
	# DIQQAT: `linear_velocity` AI mashinalarida DOIM nol (ular
	# `freeze` bilan qo'yilgan, `set_reported_speed` esa tezlikni
	# faqat meta/`speed_kmh` ga yozadi). Shu bois g'ildoraklar
	# hech qachon aylanmasdi. Endi kerak bo'lsa meta'dan olinadi.
	# Yana: vertikal tezlik (sakrash) g'ildorakni aylantirmasligi
	# kerak — faqat YERGA BO'YLAN yo'nalish aylantiradi.
	var v: float = Vector2(
		linear_velocity.x, linear_velocity.z).length()
	if not physics_driven:
		v = speed_kmh / 3.6
	_wheel_spin += (v / radius) * delta
	var spin: float = fposmod(-_wheel_spin, TAU)
	for i in _wheel_visual.size():
		var node: MeshInstance3D = _wheel_visual[i]
		# Oldingi g'ildorak buriladi; rotatsiya tartibi YXZ, ya'ni
		# avval burish, keyin aylanish — to'g'ri tartib
		node.rotation = Vector3(spin, steer_now if i < 2 else 0.0, 0.0)


func _process(delta: float) -> void:
	# DIQQAT: avval `physics_driven` bo'lmasa butunlay chiqardi —
	# ya'ni AI mashinalarining g'ildoraklari BIR KADHAM ham
	# aylanmasdi (o'zgartirilgan g'ildorakni ham qaytarish
	# `_process` siz qolardi). Endi faqat `wheels_animate` bo'lsa
	# ishlatiladi: qo'yilgan mashinalarda statik g'ildorak to'g'ri
	# (ular turgan) va chizqich ham tejiladi.
	if not wheels_animate:
		return
	_update_visuals(delta)


# ================================================================ HAYDASH

## O'yinchi kiritgan kuchlarni qo'llaydi.
##
## [param throttle] −1 … 1 (orqaga)
## [param steer] −1 … 1
## [param braking] 0 … 1
## [param handbrake] qo'lda tormoz
func drive(throttle: float, steer: float, braking: float,
		handbrake: float) -> void:
	if not physics_driven:
		return
	# --- Burish: sekinlashishi kerak, aks holda mashina "judder" beradi
	var target: float = -steer * max_steer
	steer_now = move_toward(steer_now, target, STEER_SPEED * delta_of())

	# --- Gaz ---
	var power: float = float(spec["dvigatel"]) * throttle
	if throttle < 0.0:
		power *= 0.35
	# Tepa tezlik
	var limit: float = float(spec["tepa_tezlik"]) / 3.6
	if throttle > 0.0 and speed_kmh >= limit:
		power *= 0.12
	engine_now = power

	# --- Tormoz ---
	brake_now = float(spec["tormoz"]) * clampf(braking, 0.0, 1.0)
	if throttle < 0.0 and speed_kmh < 2.0:
		brake_now = maxf(brake_now, float(spec["tormoz"]) * 0.4)
	handbrake_now = clampf(handbrake, 0.0, 1.0)


## `move_toward` uchun qadam — har kadrda chaqiriladi.
var _delta := 0.016


func delta_of() -> float:
	return _delta


## Tezlikni yangilaydi (ichki chaqiriladi).
func update_speed() -> void:
	if physics_driven:
		speed_kmh = linear_velocity.length() * 3.6
	else:
		speed_kmh = float(get_meta("tezlik", 0.0))


## AI uchun: tezlikni e'lon qilish va tugunni yo'lga qo'yish.
##
## [param position] — g'ildorak tovonining tegishi kerak bo'lgan
## nuqta (odatda yer yuzasi). Korpus shu nuqtadan
## `radius − WHEEL_DROP` balandda turadi — aks holda mashina yerga
## botib qoladi yoki havoda suzib yuradi.
func place_on_road(position: Vector3, yaw: float, speed: float) -> void:
	# Korpus o'zining statik holatida `sag − erkin uzunlik` tepada
	# turadi: shunda g'ildorak markazi yerga tegadi
	# DIQQAT: korpusning tinch holatdagi balandligi `erkin uzunlik −
	# siqilish` = `SUSPENSION_FREE − sag`. AVVAL bu yerga
	# `radius − (SUSPENSION_FREE − sag)` yozilgan edi — ya'ni
	# G'ILDORAKNING mahalliy siljishi. Bu ikki marta qo'shilgan:
	# marshrutka 29 sm, Nexia 8 sm havoda turardi (ko'z bilan
	# aniq ko'rinadi, o'lchash esa 0,9 m chegara bilan yashirdi).
	var lift: float = SUSPENSION_FREE \
		- float(spec["massa"]) * 9.8 / 4.0 / SUSPENSION_STIFFNESS
	global_position = Vector3(position.x, position.y + lift, position.z)
	rotation.y = yaw
	_update_visuals(_delta)
	set_reported_speed(speed)


func set_reported_speed(value: float) -> void:
	set_meta("tezlik", value)
	speed_kmh = value
