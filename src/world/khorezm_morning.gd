class_name KhorezmMorning
extends RefCounted
## Xorazmning ertalabki yorug'ligi — o'yin butun davomida shu qoladi.
##
## Nima uchun doim 7:00 da:
##   Xorazm yozi erta tongda issiq, changli va g'atir bo'ladi.
##   Bu bizning texnik chegaraimizni yashiradi — Intel UHD GPU faqat ~450 m
##   ko'rish masofasini ko'taradi. Ishiq chang tumani shu chegarani
##   Xorazmning haqiqiy ko'rinishiga aylantiradi.
##
## Quyosh balandligi va rangi o'zbek shehri kelib chiqqan:
##   7:00 da quyosh ~22° da, sharqdan, issiq-sariq.

## Quyosh balandligi (daraja). Past = uzun soya.
const SUN_ELEVATION := 22.0
## Quyosh azimuti (daraja): 0 = shimol, 90 = sharq, 180 = janub.
const SUN_AZIMUT := 90.0

## Soxta yumshoq soya — 0.5 = yumshoq chegara.
const SOFTNESS := 0.6


## Butun sahnaga qo'yiladigan atrof-muhit (Environment).
static func make_environment(draw_distance: float = 450.0) -> Environment:
	var env := Environment.new()

	# --- Osmondagi gradient ---
	env.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Palette.SKY_TOP
	sky_material.sky_horizon_color = Palette.SKY_HORIZON
	sky_material.sky_curve = 0.15
	sky_material.sky_energy_multiplier = 1.0

	# Osmon ostidagi yerga yaqin rang — tuman bilan bir qilib ketadi,
	# shuning uchun chegarada "kesilgan" chiziq ko'rinmaydi.
	sky_material.ground_horizon_color = Palette.GROUND_HORIZON
	sky_material.ground_bottom_color = Palette.SAND_DARK
	sky_material.ground_curve = 0.08

	# Quyosh kichakayin va oq emas — Xorazm ertalabida u yumshoq,
	# changli, deyarli ko'rinmaydi.
	sky_material.sun_angle_max = 20.0
	sky_material.sun_curve = 0.25
	sky_material.use_debanding = true

	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky

	# --- Atrof-muhit yorug'ligi osmondan ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.35

	# --- Iliq, changli tuman ---
	# Bu bir vaqtda nafaqat san'at, balki qurilma chegarasi ham:
	# ~150 m da yengil, ~450 m da yarim yo'qoladi, uzoqda butunlay eriydi.
	#
	# DIQQAT: bu qiymatlar faqat FOG_MODE_EXPONENTIAL da ishlaydi
	# (fog_density + fog_aerial_perspective). Rejimni FOG_MODE_DEPTH ga
	# o'tkazsak, bu ikkalasi ham e'tiborsiz qoladi.
	env.fog_enabled = true
	env.fog_light_color = Palette.FOG_DUST
	env.fog_light_energy = 0.62
	env.fog_sun_scatter = 0.25       # quyosh atrofidagi issiq dog'
	env.fog_density = _density_for(draw_distance)
	env.fog_aerial_perspective = 0.4  # ufqda osmon rangini oladi
	env.fog_sky_affect = 0.15         # osmon ham biroz namlanadi

	# --- Rangni to'g'rilash ---
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.0
	env.tonemap_exposure = 1.0

	# Xorazm quyosligi: biroz rangli, pastga surilgan kontrast.
	# Diqqat: brightness ni ko'tarish ranglarni oqaga yuvadi —
	# kerak bo'lsa faqat saturation va contrast o'ynatiladi.
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15

	return env


## Ko'rish masofasiga mos tuman zichligi.
##
## exp(-zichlik * masofa) = 0.5  ->  zichlik = ln(2) / masofa.
## Ya'ni ko'rish chegarasida ko'rinish 50% ga tushadi — na juda
## oq (chegara ko'rinib turadi), na juda shaffof (chegara sezilmaydi).
static func _density_for(draw_distance: float) -> float:
	var target_depth: float = max(150.0, draw_distance)
	return log(2.0) / target_depth * 1.45


## Quyosh nuri.
static func make_sun(shadow_distance: float = 120.0) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Quyosh"
	sun.light_color = Palette.SUN_MORNING
	sun.light_energy = 0.9
	sun.light_angular_distance = SOFTNESS
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# Faqat o'yinchi atrofida soya — qolgani uzoq soya kadrni yeydi
	# va Intel UHD da foyda keltirmaydi.
	sun.directional_shadow_max_distance = shadow_distance
	sun.directional_shadow_fade_start = 0.85
	sun.position = Vector3(0, 100, 0)
	sun.look_at_from_position(Vector3.ZERO, _sun_direction(), Vector3.UP)
	return sun


## Quyoshning yerga qarab yo'nalishi (quyoshdan yerga tomon).
static func _sun_direction() -> Vector3:
	var e := deg_to_rad(SUN_ELEVATION)
	var a := deg_to_rad(SUN_AZIMUT)
	var to_sun := Vector3(
		sin(a) * cos(e),
		sin(e),
		-cos(a) * cos(e)
	)
	return -to_sun.normalized()


## Qarshi tomondan to'ldiruvchi nur — qum yuzasidan qaytgan nur
## (bounce light). Compatibility rendererda GI yo'q, shuning uchun
## soyadagi qorong'i joylar aks holda yashil-kulrang bo'lib qolardi —
## bu nur ularni Xorazm qumiga yaqinroq qiladi.
static func make_fill_light() -> DirectionalLight3D:
	var fill := DirectionalLight3D.new()
	fill.name = "To'ldiruvchi"
	fill.light_color = Palette.SAND.lerp(Palette.SKY_TOP, 0.30)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.4, -0.8, 0.45), Vector3.UP)
	return fill


## Tayyor uchta node — sahnaga qo'shish uchun.
static func install(root: Node3D, draw_distance: float, shadow_distance: float) -> void:
	var we := WorldEnvironment.new()
	we.name = "AtrofMuhit"
	we.environment = make_environment(draw_distance)
	root.add_child(we)

	root.add_child(make_sun(shadow_distance))
	root.add_child(make_fill_light())
