class_name BuildingKit
extends RefCounted
## Xorazm uyining qismlari — har biri alohida funksiya.
##
## XORAZM UYI NIMA UCHUN SHUNDAY
##
## 1. KO'CHAGA QARAGAN DEVOR DA ZARASIZ bo'ladi. Sabab ikki xil:
##    shahar ichida begona uyni ko'rishdan himoya qilinadi, yozda
##    uy ichini salqin saqlanadi. Xorazmda shuning uchun uylarning
##    ko'chaga qaragan qismi — TEKIS, baland (2,2–2,5 m), derazasiz.
## 2. Eshik ko'chada emas, chuqurroqda — ko'pincha devorning chap
##    yoki o'ng tomonida, ufqdan uzoqda. Bu Xorazmning an'anaviy
##    qurilishi (chekdor / xilona).
## 3. Ikkinchi qavat hovliga (ichki hovli) qaraydi — ko'chaga emas.
##    Shuning uchun tashqi tomon yalang'och devor, ichki tomon
##    derazali.
## 4. Tom TEKIS. Yassi tekislikning issiq yozi yaxshi boshqariladi.
##    Tom ostida yog'och taronalar ko'rinib turadi, ustida — devor
##    (parpet).
## 5. Hovlida anor o'sadi. U meva, soya va go'zallik.

const WALL_THICKNESS := 0.34            ## Tashqi devor — qalin (sovuqdan himoya)
const INNER_THICKNESS := 0.26            ## Ichki devor
const PARAPET_HEIGHT := 0.55            ## Tom ustidagi devor
const STREET_WALL_HEIGHT := 2.45        ## Ko'cha bo'yi devor
const GATE_HEIGHT := 2.05
const DOOR_HEIGHT := 2.15
const CEILING := 3.05                   ## Birinchi qavat balandligi
const SECOND_FLOOR := 2.85              ## Ikkinchi qavat (bir oz past)


# ================================================================== DEVORLAR

## Devor + tepasiga ko'rov (chep). Ko'cha bo'yi devorlarda shu usul:
## yuqoriga yugurilgan qora chet — uy qanchalik baland ekanini
## uzoqdan ko'rsatadi va chang yig'ilmaydi.
## PLINTH_HIGHT devorning pastki qismi — boshqa rangda bo'yaladi.
## Xorazmda devorning pastki 40–60 smi yotgandan keyin ranglanadi:
## loydan yalang'och suvaloq namdan tez yemiriladi, uni och-ko'k yoki
## to'q qilib bo'yab himoya qilinadi. Bu mahallaning ko'chalariga
## eng ko'p "inson ko'rish" beradigan narsa — devor bir xil oq
## devorda uzun oq lenta kabi bo'lib qolmasligi uchun.
const PLINTH_HEIGHT := 0.55

static func wall_with_coping(builder: MeshBuilder, from: Vector2, to: Vector2,
		base_y: float, height: float, thickness: float, colour: Color,
		coping: Color = Palette.CONCRETE) -> void:
	builder.add_wall(from, to, base_y, height, thickness, colour)
	# Sokva — devor poydevori
	var plinth: Color = _plinth_colour(colour)
	if height > PLINTH_HEIGHT + 0.1:
		builder.add_wall(from, to, base_y, PLINTH_HEIGHT,
			thickness + 0.035, plinth)
	# Ko'rov — devordan 3 sm chetga chiqib turadi
	var direction: Vector2 = (to - from)
	if direction.length_squared() < 0.0001:
		return
	var side: Vector2 = direction.orthogonal().normalized() * (thickness * 0.5 + 0.03)
	builder.add_plate(from - side, to + side, base_y + height, 0.10, coping)


## An'anaviy Xorazm ravoqi — devorda kichik tokcha.
##
## DIQQAT: bu yopiq kvadrat bo'lib, atrofga chiqib turadi, haqiqiy
## chuqur ravoq EMAS. Chuqur ravoq qilish uchun devor mesh'ini
## teshish kerak edi — bitta birlashtirilgan mesh'da bu mumkin
## emas (teshik qirqish butun devorni bo'lishini talab qiladi).
## Qorong'i kvadrat uzoqdan bir xil ko'rinadi, arzon va xato xavfi yo'q.
static func niche(builder: MeshBuilder, at: Vector3, width: float,
		height: float, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	# DIQQAT: to'rt burchak — to'g'ri TO'RTBURCHAK bo'lishi shart.
	# Avval `at ± half` ga yana `Vector3(0, height, 0)` qo'shilardi,
	# shuning uchun shakl "galtaq bow" bo'lib chiqardi va devorda
	# QORA KREST ko'rinardi (barcha mahalla uylarida).
	var q: Array[Vector3] = [
		at + basis * Vector3(-width * 0.5, -height * 0.5, 0.0),
		at + basis * Vector3(width * 0.5, -height * 0.5, 0.0),
		at + basis * Vector3(width * 0.5, height * 0.5, 0.0),
		at + basis * Vector3(-width * 0.5, height * 0.5, 0.0),
	]
	builder.add_quad(q[0], q[1], q[2], q[3], Color("3b3128"),
		basis * Vector3(0, 0, 1), false)


# ================================================================== TESHIKLAR

## To'rt-pangali to'sh oyna ("to'rt ko'z"). Xorazmda oddiy shisha
## oyna deyarli yo'q — yog'och to'sh ishlatiladi: havo o'tadi,
## ko'rmaydi, issiqni kamaytiradi.
static func lattice_window(builder: MeshBuilder, at: Vector3,
		width: float, height: float, yaw: float) -> void:
	var frame := Palette.WOOD_DARK
	var basis := Basis(Vector3.UP, yaw)
	var normal := basis * Vector3(0, 0, 1)

	# To'sh orqasi — qorong'i, chuqurroq
	builder.add_quad(
		at + basis * Vector3(-width * 0.5, -height * 0.5, -0.10),
		at + basis * Vector3(width * 0.5, -height * 0.5, -0.10),
		at + basis * Vector3(width * 0.5, height * 0.5, -0.10),
		at + basis * Vector3(-width * 0.5, height * 0.5, -0.10),
		Color("241c15"), normal, false)

	# Ramka
	_frame(builder, at, width, height, yaw, 0.07, frame)
	# To'rt panga bo'luvchi gorizontal va vertikal tayoqchalar
	_bar(builder, at, width - 0.06, 0.028, yaw, frame)
	_bar(builder, at + basis * Vector3(0, height * 0.16, 0),
		width - 0.06, 0.028, yaw, frame)
	_bar(builder, at + basis * Vector3(width * 0.22, 0, 0),
		height - 0.06, 0.028, yaw + PI * 0.5, frame)
	_bar(builder, at + basis * Vector3(-width * 0.22, 0, 0),
		height - 0.06, 0.028, yaw + PI * 0.5, frame)


## Eshik — Xorazm eshigi ("rangli eshik"): pastki qismi yalang'och
## taxtadan, yuqori qismi to'shli. Do'konlarga yopiq, qishloq
## xonadonlarida ochiladigan.
static func plank_door(builder: MeshBuilder, at: Vector3, width: float,
		height: float, yaw: float, colour: Color = Palette.WOOD_DARK) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var normal := basis * Vector3(0, 0, 1)
	var panel_height: float = height * 0.42

	# To'shli yuqori qism
	builder.add_quad(
		at + basis * Vector3(-width * 0.5, panel_height, 0.02),
		at + basis * Vector3(width * 0.5, panel_height, 0.02),
		at + basis * Vector3(width * 0.5, height * 0.5 - 0.03, 0.02),
		at + basis * Vector3(-width * 0.5, height * 0.5 - 0.03, 0.02),
		Color("2b2019"), normal, false)

	# Taxta yuzasi — ketma-ket bo'laklar
	var boards: int = 4
	for i in boards:
		var x0: float = -width * 0.5 + width * float(i) / float(boards)
		var x1: float = -width * 0.5 + width * float(i + 1) / float(boards)
		var tone: Color = colour.lightened(rng_seed(i) * 0.12)
		builder.add_quad(
			at + basis * Vector3(x0 + 0.008, 0, 0.03),
			at + basis * Vector3(x1 - 0.008, 0, 0.03),
			at + basis * Vector3(x1 - 0.008, panel_height, 0.03),
			at + basis * Vector3(x0 + 0.008, panel_height, 0.03),
			tone, normal, false)

	# Ramka va to'sh tayoqlari
	_frame(builder, at, width, height, yaw, 0.09, colour.darkened(0.2))
	# Yuqori to'sh qismida uchta vertikal tayoq
	for i in 3:
		_bar(builder,
			at + basis * Vector3(-width * 0.24 + width * 0.24 * float(i),
				(panel_height + height * 0.5) * 0.5 + 0.02, 0.0),
			height * 0.5 - panel_height - 0.08, 0.024, yaw + PI * 0.5, colour)


## Yuk mashinasi eshigi (keng, temir, ikki bo'lakli).
static func metal_gate(builder: MeshBuilder, from: Vector2, to: Vector2,
		base_y: float, height: float) -> void:
	var direction: Vector2 = to - from
	var length: float = direction.length()
	if length < 0.4:
		return
	var normal := direction.orthogonal().normalized()
	var colour := Palette.GATE_METAL

	builder.add_wall(from, to, base_y, 0.28, 0.16, Palette.CONCRETE)
	builder.add_wall(from, to, base_y + height - 0.14, 0.14, 0.18, colour)

	# Vertikal pichqlar
	var bars: int = maxi(4, int(length / 0.22))
	for i in range(1, bars):
		var t: float = float(i) / float(bars)
		var p: Vector2 = from.lerp(to, t)
		var a := Vector3(p.x, base_y + 0.22, p.y)
		var b := Vector3(p.x, base_y + height - 0.14, p.y)
		builder.add_box((a + b) * 0.5, Vector3(0.035, height - 0.36, 0.035),
			colour.lightened(0.10), 0.0, false)

	# Gorizontal chiziqlar
	for level in 2:
		var y: float = base_y + 0.35 + (height - 0.9) * float(level)
		var a := Vector3(from.x, y, from.y)
		var b := Vector3(to.x, y, to.y)
		builder.add_box((a + b) * 0.5, Vector3((b - a).length(), 0.03, 0.03),
			colour.lightened(0.10),
			rad_to_deg(direction.angle()) * -1.0 + 90.0, false)


# ================================================================== TAYAMAK

## Tarona — yog'och ustun. Xorazmda uy shifti va ayvonini ko'taradi.
## Pastda to'g'ri, yuqorida yengil kengaygan (kapitel).
static func tarona(builder: MeshBuilder, at: Vector3, height: float,
		radius: float = 0.15) -> void:
	var basis_height: float = height * 0.86
	builder.add_cylinder(at, at + Vector3(0, basis_height, 0), radius, 8,
		Palette.WOOD, false)
	# Kapitel — kichik va yengil. DIQQAT: katta qilsak, pastdan
	# qaraganda uning ostki yuzasi quyoshdan uzoq bo'lgani uchun
	# QORA bo'lib ko'rinadi va ustun ustida "qora krest" paydo bo'ladi.
	builder.add_box(at + Vector3(0, basis_height + height * 0.045, 0),
		Vector3(radius * 2.2, height * 0.075, radius * 2.2), Palette.WOOD_LIGHT,
		0.0, false)
	# Poy ostidagi tosh to'shak
	builder.add_box(at + Vector3(0, 0.08, 0),
		Vector3(radius * 2.1, 0.16, radius * 2.1), Palette.CONCRETE, 0.0, false)


## Tom ostidagi ko'rinib turadigan yog'och taronalar.
## DIQQAT: nopiya (tomon) uchun chiqib turadi — bu Xorazm uyining
## eng ko'rinadigan belgisi. Uzunligi 40–60 sm.
static func eave_beams(builder: MeshBuilder, from: Vector2, to: Vector2,
		y: float, count: int, length: float = 0.5,
		colour: Color = Palette.WOOD) -> void:
	var direction: Vector2 = to - from
	if direction.length_squared() < 0.0001:
		return
	var normal: Vector2 = direction.orthogonal().normalized()
	for i in count:
		var t: float = (float(i) + 0.5) / float(count)
		var p: Vector2 = from + direction * t
		# DIQQAT: burilish DEVOR yo'nalishi bo'yicha emas, NORMAL
		# bo'yicha bo'lishi shart. Aks holda nopiya devor ustida yotib
		# qoladi va uyning chetida uzun "kalta" paydo bo'ladi.
		var yaw: float = rad_to_deg(normal.angle())
		# DIQQAT: faqat BITTA tomonga chiziladi. Ikki tomonga
		# chizilsak, nopiya devor o'qida to'xtab, yuqoridan qaraganda
		# "+" shaklida ko'rinadi va uyning chetida "tarqoq taxtalar"
		# paydo bo'ladi. Haqiqiy nopiya devordan BIR tomonga chiqadi.
		var tip: Vector2 = p + normal * length
		var a := Vector3(p.x, y, p.y)
		var b := Vector3(tip.x, y, tip.y)
		# Nopiqa 7×9 sm, uzunligi 45 sm. Katta qilsak, uy ustida
		# "narasimon taxta" qatori paydo bo'ladi.
		builder.add_box((a + b) * 0.5, Vector3(0.07, 0.09, length), colour,
			yaw, false)


# ================================================================== TOM

## Yassi tom. Ustiga yopilgan shift (chanoq), chetida devor.
## [param y] — shift YUZASINING balandligi.
static func flat_roof(builder: MeshBuilder, from: Vector2, to: Vector2,
		y: float, colour: Color = Palette.ROOF_DECK) -> void:
	builder.add_plate(from, to, y, 0.24, colour)
	parapet(builder, from, to, y, colour)


## Tom ustidagi devor.
static func parapet(builder: MeshBuilder, from: Vector2, to: Vector2,
		y: float, colour: Color) -> void:
	var direction: Vector2 = to - from
	if direction.length_squared() < 0.0001:
		return
	var side: Vector2 = direction.orthogonal().normalized() * 0.13
	builder.add_wall(from, to, y, PARAPET_HEIGHT, 0.20, colour)
	# Yuqori qatlam
	builder.add_plate(from - side, to + side, y + PARAPET_HEIGHT, 0.06, colour)


# ================================================================== YORDAM

## Ramka — to'rtta yong'oqdan.
static func _frame(builder: MeshBuilder, at: Vector3, width: float,
		height: float, yaw: float, bar: float, colour: Color) -> void:
	_frame_edge(builder, at + Basis(Vector3.UP, yaw) * Vector3(0, -height * 0.5, 0),
		width, bar, yaw, colour)
	_frame_edge(builder, at + Basis(Vector3.UP, yaw) * Vector3(0, height * 0.5, 0),
		width, bar, yaw, colour)
	_frame_edge(builder, at + Basis(Vector3.UP, yaw) * Vector3(-width * 0.5, 0, 0),
		height, bar, yaw + PI * 0.5, colour)
	_frame_edge(builder, at + Basis(Vector3.UP, yaw) * Vector3(width * 0.5, 0, 0),
		height, bar, yaw + PI * 0.5, colour)


static func _frame_edge(builder: MeshBuilder, at: Vector3, length: float,
		bar: float, yaw: float, colour: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	builder.add_box(at, basis * Vector3(length, bar, bar * 0.8), colour, 0.0, false)


## Yagona yong'oq — gorizontal yoki vertikal.
static func _bar(builder: MeshBuilder, at: Vector3, length: float,
		bar: float, yaw: float, colour: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	builder.add_box(at, basis * Vector3(length, bar, bar * 0.8), colour, 0.0, false)


## Takrorlanuvchan taxtalar uchun qat'iy kichik o'zgarish.
## Devor poydevorining rangi — asosiy devordan sezilarli farq qiladi.
static func _plinth_colour(colour: Color) -> Color:
	if colour.is_equal_approx(Palette.PLASTER_NEW):
		return Color("8fa3a0")          # ko'k-yashil — eng ko'p uchraydigan
	if colour.is_equal_approx(Palette.SAMAN):
		return Color("7d6240")
	if colour.is_equal_approx(Palette.BRICK_NEW):
		return Color("7f5b42")
	return colour.darkened(0.30)


static func rng_seed(index: int) -> float:
	return float((index * 37) % 17) / 17.0