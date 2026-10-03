class_name RoadBuilder
extends RefCounted
## Yo'llarni ko'rinadigan geometriyaga aylantiradi.
##
## Collision alohida qurilmaydi — chunki RoadNetwork yer ostini ALMASH
## tekislashtiradi, shuning uchun o'yinchi va mashina kengaytirilgan
## tekis yer ustida haydaydi. Bu arzon va uzluksiz: ko'priklarsiz
## qismlarda yerning o'zi yo'l.
##
## Ko'priklar alohida: ular suv ustida quriladi, u yerda tekislangan
## yer yo'l darajasida emas.

## Yo'l bo'ylab namuna oralig'i (m). Katta qiymat = kamroq uchburchak,
## lekin burilgan yo'llar notekis bo'ladi.
const STEP := 12.0

## Chiziqlar uchun yurish qadami (m). Chiziqlar asosiy lentadan alohida
## yuriladi, chunki punktli chiziq 12 m qadamda ifoda bo'lmaydi.
## 3,0 m — punktli chiziqning uzunligiga teng, shuning uchun chiziq
## aniq 3 m bo'lib chiqadi.
const WALK := 3.0
## Chiziq kalinligi (m). Haqiqiy yo'l chizig'i 12–15 sm.
const LINE_WIDTH := 0.15
## Markaziy chiziq: uzoqligi va teshigi. Nisbati haqiqiy standartga
## yaqin (3 m chiziq, 6 m teshik).
const DASH_LENGTH := 3.0
const DASH_GAP := 6.0
## Magistraldagi JUFT sariq chiziq orasidagi bo'shliq (m).
const DOUBLE_GAP := 0.2

## Yo'l yuzasi TERRITRIYA bilan bir tekislikda quriladi (ikkalasi ham
## TerrainGen.height_at dan o'qiydi). Bu Z-URISH (z-fighting) keltiradi:
## uzoqda yo'l, yaqinda esa yer ustun keladi — yaqindan yo'lni ko'rish
## mumkin bo'lmaydi. Shuning uchun lenta 6 sm ko'tariladi.
##
## 6 sm sezilmaydi: mashina ham, yalang'och oyoq ham yerni sezadi
## (collision yer ostida qoladi), ko'z esa shuncha farqni ushlaydi.
const ROAD_LIFT := 0.06
## Chiziqlar asosiy yuzadan biroz balandda — z-urish va chotkalashdan.
const LINE_LIFT := 0.12

## Ko'prik: suv ustidan o'tish uchun
const BRIDGE_MIN_SPAN := 12.0
const BRIDGE_THICKNESS := 0.55
const BRIDGE_PARAPET := 0.85


## Barcha yo'llarni quradi va ildiz tugun qaytaradi.
static func build(root: Node3D) -> Node3D:
	var group := Node3D.new()
	group.name = "Yo'llar"
	root.add_child(group)

	var asphalt := MeshBuilder.new()
	var lines := MeshBuilder.new()

	for road: Dictionary in RoadNetwork.roads():
		var kind: int = road["tur"]
		if kind == RoadNetwork.DIRT:
			# Qishloq yo'llari — qum rangli, chiziqsiz
			_add_dirt(asphalt, road)
		else:
			_add_paved(asphalt, road, kind)
			_add_markings(lines, road, kind)

	# --- Ko'priklar (alohida, chunki collision ham bor) ---
	_build_bridges(group)

	asphalt.commit(group, "Asfalt")
	lines.commit(group, "Chiziqlar")
	return group


# ------------------------------------------------------------------ YUPOQ
## Asfalt lenta + yon chetlar.
##
## DIQQAT: barcha nuqtalar Vector3 (baldik bilan) saqlanadi. Avval Vector2
## saqlaganimizda balandlik umuman ishlatilmasdi va butun yo'l y = 0 da
## yotib qolardi — yer ostida.
static func _add_paved(asphalt: MeshBuilder, road: Dictionary, kind: int) -> void:
	var points: PackedVector2Array = road["nuqta"]
	var half: float = RoadNetwork.HALF_WIDTH[kind]
	var edge_colour: Color = (
		Palette.CONCRETE_ROAD if kind == RoadNetwork.HIGHWAY else Palette.CONCRETE
	)

	var previous: Dictionary = {}

	for at in range(points.size() - 1):
		var a: Vector2 = points[at]
		var b: Vector2 = points[at + 1]
		var length: float = a.distance_to(b)
		if length < 0.01:
			continue
		var direction := (b - a).normalized()
		var normal := direction.orthogonal()

		var steps := maxi(1, int(ceil(length / STEP)))
		for s in steps:
			var t: float = s / float(steps)
			var p: Vector2 = a.lerp(b, t)
			var y: float = TerrainGen.height_at(p.x, p.y)

			var sample := {
				"chap_ich": Vector3(p.x - normal.x * half, y, p.y - normal.y * half),
				"chap": Vector3(p.x - normal.x * (half + 0.55), y, p.y - normal.y * (half + 0.55)),
				"markaz": Vector3(p.x, y, p.y),
				"o'ng": Vector3(p.x + normal.x * (half + 0.55), y, p.y + normal.y * (half + 0.55)),
				"o'ng_ich": Vector3(p.x + normal.x * half, y, p.y + normal.y * half),
				"normal": normal,
			}

			if not previous.is_empty():
				_pave_strip(asphalt, previous, sample, edge_colour)
			previous = sample


## Bitta qadamdagi asfalt yuzasi.
static func _pave_strip(buffer: MeshBuilder, prev: Dictionary, cur: Dictionary,
		edge_colour: Color) -> void:
	# Asfalt yuzasi: markazdan ikki yonga
	_quad(buffer, prev["chap_ich"], prev["markaz"], cur["markaz"], cur["chap_ich"],
		Palette.ASPHALT, ROAD_LIFT)
	_quad(buffer, prev["markaz"], prev["o'ng_ich"], cur["o'ng_ich"], cur["markaz"],
		Palette.ASPHALT, ROAD_LIFT)
	# Yon chetlar (trotuar / ko'pik ostidagi asfalt) — asfaltdan biroz past,
	# shunda chiziq va chet bir-birining ustiga tushmaydi
	_quad(buffer, prev["chap"], prev["chap_ich"], cur["chap_ich"], cur["chap"],
		edge_colour, ROAD_LIFT - 0.02)
	_quad(buffer, prev["o'ng_ich"], prev["o'ng"], cur["o'ng"], cur["o'ng_ich"],
		edge_colour, ROAD_LIFT - 0.02)


## Yo'l chiziqlari: chet chiziqlari va markaziy punktli chiziq.
##
## DIQQAT: chiziqlar asosiy lentadan ALOHIDA, mayin qadam (1,5 m) bilan
## yuriladi. Ikki sabab bor:
##   * Lenta 12 m qadam bilan quriladi — 3 m li punktli chiziq undan
##     chiqmaydi.
##   * GDScriptda funksiyaga ARGUMAN qiymat bo'yicha o'tadi. Avval
##     `clock` funksiya ichida nolga qaytarilardi — `_add_paved` dagi
##     `dash_clock` esa o'smayverardi va chiziq bir marta chizilib,
##     butun yo'lda yo'q bo'lib qolardi.
static func _add_markings(lines: MeshBuilder, road: Dictionary, kind: int) -> void:
	var points: PackedVector2Array = road["nuqta"]
	var half: float = RoadNetwork.HALF_WIDTH[kind]
	var centre_colour: Color = (
		Palette.ROAD_LINE_YELLOW if kind == RoadNetwork.HIGHWAY
		else Palette.ROAD_LINE_WHITE
	)

	var previous: Dictionary = {}
	var along := 0.0

	for at in range(points.size() - 1):
		var a: Vector2 = points[at]
		var b: Vector2 = points[at + 1]
		var length: float = a.distance_to(b)
		if length < 0.01:
			continue
		var normal := (b - a).normalized().orthogonal()
		var steps := maxi(1, int(ceil(length / WALK)))
		var step_length: float = length / float(steps)

		for s in steps:
			var p: Vector2 = a.lerp(b, s / float(steps))
			var y: float = TerrainGen.height_at(p.x, p.y)
			var sample := {
				"markaz": Vector3(p.x, y, p.y),
				"normal": normal,
			}

			if not previous.is_empty():
				# Chet chiziqlari — uzluksiz, faqat magistralda
				if kind == RoadNetwork.HIGHWAY:
					var edge: float = half - LINE_WIDTH * 2.0
					_ribbon(lines, _shift(previous, -edge), _shift(sample, -edge),
						Palette.ROAD_LINE_WHITE, LINE_WIDTH)
					_ribbon(lines, _shift(previous, edge), _shift(sample, edge),
						Palette.ROAD_LINE_WHITE, LINE_WIDTH)

				# Markaziy chiziq — punktli.
				#
				# DIQQAT: faza QADAMNING O'RTASIGA hisoblanadi. Qadam
				# uzunligi butun son bo'lishi shart emas (halqa
				# qadamlari 2,94 m bo'lib chiqadi), shuning uchun
				# `fmod(along, ...)` hech qachon 0 ga yaqin kelmaydi va
				# chiziq butun yo'l bo'ylab umuman chizilmay qoladi.
				var phase: float = fmod(
					along + step_length * 0.5, DASH_LENGTH + DASH_GAP)
				if phase < DASH_LENGTH:
					# Magistralda 4 ta tasma bo'lgani uchun markazda JUFT
					# chiziq turadi (qarshi yo'nalishni ajratadi).
					# Ko'chada bitta oddiy chiziq yetarli.
					if kind == RoadNetwork.HIGHWAY:
						var offset: float = LINE_WIDTH * 0.5 + DOUBLE_GAP * 0.5
						_ribbon(lines, _shift(previous, -offset),
							_shift(sample, -offset), centre_colour, LINE_WIDTH)
						_ribbon(lines, _shift(previous, offset),
							_shift(sample, offset), centre_colour, LINE_WIDTH)
					else:
						_ribbon(lines, previous["markaz"], sample["markaz"],
							centre_colour, LINE_WIDTH)

			previous = sample
			along += length / float(steps)


## Namunaviy nuqtani yo'l markazidan yon tomonga surish.
static func _shift(sample: Dictionary, offset: float) -> Vector3:
	var n: Vector2 = sample["normal"]
	var c: Vector3 = sample["markaz"]
	return c + Vector3(n.x * offset, 0.0, n.y * offset)


## Qishloq yo'li — qum, chiziqsiz, yonlarisiz.
static func _add_dirt(buffer: MeshBuilder, road: Dictionary) -> void:
	var points: PackedVector2Array = road["nuqta"]
	var half: float = RoadNetwork.HALF_WIDTH[road["tur"]]

	var previous: Dictionary = {}
	for at in range(points.size() - 1):
		var a: Vector2 = points[at]
		var b: Vector2 = points[at + 1]
		var length: float = a.distance_to(b)
		if length < 0.01:
			continue
		var normal := (b - a).normalized().orthogonal()
		var steps := maxi(1, int(ceil(length / STEP)))
		for s in steps:
			var t: float = s / float(steps)
			var p: Vector2 = a.lerp(b, t)
			var y: float = TerrainGen.height_at(p.x, p.y)
			var sample := {
				"chap": Vector3(p.x - normal.x * half, y, p.y - normal.y * half),
				"o'ng": Vector3(p.x + normal.x * half, y, p.y + normal.y * half),
			}
			if not previous.is_empty():
				_quad(buffer, previous["chap"], previous["o'ng"],
					sample["o'ng"], sample["chap"], Palette.SOIL_ROAD, ROAD_LIFT * 0.7)
			previous = sample


# ---------------------------------------------------------------- KO'PRIK

## Yo'l suv bilan kesishgan joylarda avtomatik ko'prik qo'yadi.
##
## Nima uchun avtomatik: Xorazmda kanallar minglab. Har birini qo'lda
## belgilab bo'lmaydi. Yo'l qurilishda o'zi topadi — xuddi shu tarzda
## quruvchilar ham qiladi (dasturaviy "to'qnashuv" tekshiruvi).
static func _build_bridges(root: Node3D) -> void:
	var bridge_index := 0
	for road: Dictionary in RoadNetwork.roads():
		if road["tur"] == RoadNetwork.DIRT:
			continue
		var points: PackedVector2Array = road["nuqta"]
		var half_width: float = RoadNetwork.HALF_WIDTH[road["tur"]] + RoadNetwork.SHOULDER

		var walked := 0.0
		var run_start := -1.0
		for at in range(points.size() - 1):
			var a: Vector2 = points[at]
			var b: Vector2 = points[at + 1]
			var length: float = a.distance_to(b)
			if length < 0.01:
				continue
			var steps := maxi(1, int(ceil(length / 6.0)))
			for s in range(steps + 1):
				var p: Vector2 = a.lerp(b, s / float(steps))
				var wet: bool = RoadNetwork.is_over_water(p.x, p.y)
				if wet and run_start < 0.0:
					run_start = walked
				elif not wet and run_start >= 0.0:
					if walked - run_start >= BRIDGE_MIN_SPAN:
						_build_one_bridge(root, points, maxf(0.0, run_start - 5.0),
							walked + 5.0, half_width, bridge_index)
						bridge_index += 1
					run_start = -1.0
				walked += length / float(steps)

	# Joylarni chiqaramiz — ko'prik kamda ko'rinadi, lekin xato qilsa
	# ("yo'l suv ustida qoldi") shu ro'yxatdan darhol topiladi.
	var where := PackedStringArray()
	for node: Node in root.get_children():
		var p := (node as Node3D).position
		where.append("(%.0f, %.0f)" % [p.x, p.z])
	print_rich("[color=#d9a441]Ko'priklar:[/color] %d ta qurildi (kanallar ustida)"
		% bridge_index + ("  " + " · ".join(where) if where.size() > 0 else ""))


## Bitta ko'prik: to'siq ko'prik ushugi + ikki yon devor.
##
## BARCHA vertexlar MAHSULIY koordinatalarda (Vector3) — chunki ko'prik
## balandligi o'zgaradi va uni alohida tugunga qo'yamiz.
static func _build_one_bridge(root: Node3D, points: PackedVector2Array,
		start: float, finish: float, half_width: float, index: int) -> void:
	var edge := _point_at(points, start)
	var deck_y: float = TerrainGen.height_at(edge.x, edge.y) + 0.05

	# Ko'prik o'z O'RTA markaziga qo'yiladi, vertexlar esa shu markazga
	# nisbatan yoziladi. Aks holda tugun (0,0) da turib, butun dunyo
	# koordinatasidagi vertexlarni saqlardi — bu ko'rinmaydigan xarajat,
	# va ko'prik joyini bilib bo'lmaydi.
	var origin := _point_at(points, (start + finish) * 0.5)
	var offset := Vector3(origin.x, 0.0, origin.y)

	var surface := MeshBuilder.new()
	var steps := maxi(2, int(ceil((finish - start) / 6.0)))

	var previous: Dictionary = {}
	var first_left := Vector3.ZERO
	var first_right := Vector3.ZERO
	for i in range(steps + 1):
		var distance: float = lerpf(start, finish, i / float(steps))
		var p: Vector2 = _point_at(points, distance)
		var n: Vector2 = _normal_at(points, distance)
		var left: Vector3 = Vector3(p.x - n.x * half_width, 0.0, p.y - n.y * half_width) - offset
		var right: Vector3 = Vector3(p.x + n.x * half_width, 0.0, p.y + n.y * half_width) - offset
		if i == 0:
			first_left = left
			first_right = right
		var current := {"chap": left, "o'ng": right, "normal": n}

		if not previous.is_empty():
			var pl: Vector3 = previous["chap"]
			var pr: Vector3 = previous["o'ng"]
			var cl: Vector3 = current["chap"]
			var cr: Vector3 = current["o'ng"]
			# Ustiq yuzasi
			_quad(surface, pl, pr, cr, cl, Palette.CONCRETE_ROAD, 0.0)
			# Pastki yuzasi — pastga qaraydi
			var drop := Vector3(0, -BRIDGE_THICKNESS, 0)
			_quad(surface, pl + drop, pr + drop, cr + drop, cl + drop,
				Palette.CONCRETE, 0.0)
			# YON devorlar — ko'prikning IKKI YON bo'ylab, uzunasiga.
			# DIQQAT: avval har qadamda butun kenglik bo'ylab tik plastina
			# qurilgan edi (pl→pr→pr+drop→pl+drop) — bu ko'prikni har
			# 6 m da kesib tishsimon qilib chiqargan. Yon devor uzunasiga
			# borishi kerak: pl → cl.
			_quad(surface, pl, pl + drop, cl + drop, cl, Palette.CONCRETE, 0.0)
			_quad(surface, pr, cr, cr + drop, pr + drop, Palette.CONCRETE, 0.0)
			# To'siq (parapet) — ikki yon
			_parapet(surface, pl, pr, cl, cr,
				previous["normal"], current["normal"], BRIDGE_PARAPET)
		previous = current

	# Bosh va oxir yopishlari — faqat ikki uchda (har qadamda emas)
	if previous.size() > 0:
		var first: Array = [first_left, first_right]
		_quad(surface, first_left, first_right,
			first_right + Vector3(0, -BRIDGE_THICKNESS, 0),
			first_left + Vector3(0, -BRIDGE_THICKNESS, 0),
			Palette.CONCRETE, 0.0)
		var el: Vector3 = previous["chap"]
		var er: Vector3 = previous["o'ng"]
		_quad(surface, el + Vector3(0, -BRIDGE_THICKNESS, 0),
			er + Vector3(0, -BRIDGE_THICKNESS, 0), er, el,
			Palette.CONCRETE, 0.0)

	var node := Node3D.new()
	node.name = "Ko'prik_%d" % index
	node.position = Vector3(origin.x, deck_y, origin.y)
	root.add_child(node)

	var built: Node3D = surface.commit(node, "Ustiq")
	if built == null:
		node.queue_free()
		return

	# Collision. Ko'prik ushigining YUQORI yuzasi va yon devorlari yetarli —
	# ichki va pastki yuzalarni yig'masligimiz mumkin (ular ko'rinmaydi,
	# o'yinchi orasidan o'tmaydi). Lekin bitta muhim nuqta bor: pastki
	# yuzani HAM qo'shish kerak, aks holda suv ostidan qaragan dastur
	# devordan o'tib keta oladi.
	surface.want_collision = true
	surface.commit_collision(node, "Kolpasi")


## Ko'prik to'sig'i — ikki yonda beton devor.
##
## DIQQAT: devor yo'l yo'nalishiga QARAB quriladi. Avval yo'nalishni
## doimiy Vector3(-1,0,0) deb olganmiz — natijada ko'prik yo'lda
## diagonal turgan bo'lsa, to'siqlar yon tomonga uchib chiqib, tish
##simon shakl hosil qilardi.
static func _parapet(buffer: MeshBuilder,
		pl: Vector3, pr: Vector3, cl: Vector3, cr: Vector3,
		prev_normal: Vector2, cur_normal: Vector2, height: float) -> void:
	var thickness := 0.24
	var up := Vector3(0, height, 0)

	for side in 2:
		var base_a: Vector3 = pl if side == 0 else pr
		var base_b: Vector3 = cl if side == 0 else cr
		var na: Vector2 = prev_normal
		var nb: Vector2 = cur_normal
		# Yo'ldan tashqariga qaragan yo'nalish
		var outward: float = -1.0 if side == 0 else 1.0
		var offset_a := Vector3(na.x, 0.0, na.y) * (thickness * outward)
		var offset_b := Vector3(nb.x, 0.0, nb.y) * (thickness * outward)

		# DIQQAT: har bir yuzaning TO'RT burchagi bir tekislikda
		# bo'lishi shart. Avval "tashqi" yuzaga ichki va tashqi
		# nuqtalar aralashgan edi — kvadrat cho'zilib, ko'prik
		# yonidan uzun oq qanotlar chiqardi.
		var outer_a: Vector3 = base_a + offset_a
		var outer_b: Vector3 = base_b + offset_b
		# Tashqi yuzasi (devorning tashqi tomoni)
		_quad(buffer, outer_a, outer_b, outer_b + up, outer_a + up,
			Palette.CONCRETE, 0.0)
		# Ichki yuzasi (yo'l tomoni)
		_quad(buffer, base_a, base_a + up, base_b + up, base_b,
			Palette.CONCRETE, 0.0)
		# Ustasi
		_quad(buffer, base_a + up, outer_a + up, outer_b + up, base_b + up,
			Palette.CONCRETE, 0.0)


static func _point_at(points: PackedVector2Array, distance: float) -> Vector2:
	var walked := 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length: float = a.distance_to(b)
		if walked + length >= distance:
			var t: float = 0.0 if length < 0.01 else (distance - walked) / length
			return a.lerp(b, t)
		walked += length
	return points[points.size() - 1]


static func _normal_at(points: PackedVector2Array, distance: float) -> Vector2:
	var walked := 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length: float = a.distance_to(b)
		if walked + length >= distance or i == points.size() - 2:
			var direction: Vector2 = b - a
			if direction.length_squared() < 0.0001:
				return Vector2(1, 0)
			return direction.normalized().orthogonal()
		walked += length
	return Vector2(1, 0)


# --------------------------------------------------------------- GEOMETRIYA

## Bitta kvadrat (ikki uchburchak), har uchi rangli.
static func _quad(buffer: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		colour: Color, lift: float) -> void:
	buffer.add_quad(a + Vector3.UP * lift, b + Vector3.UP * lift,
		c + Vector3.UP * lift, d + Vector3.UP * lift, colour, Vector3.UP, false)


## Tor chiziq: ikki nuqta orasida. Nuqtalar Vector3 (balandlik bilan).
static func _ribbon(buffer: MeshBuilder, a: Vector3, b: Vector3,
		colour: Color, width: float) -> void:
	var direction := b - a
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()
	# Kenglik normal bo'ylab — chiziq balandlikni o'zgartirmaydi.
	# Vector3 da orthogonal() yo'q — qo'lda hisoblaymiz.
	var perpendicular := Vector3(-direction.z, 0.0, direction.x)
	var offset := perpendicular * (width * 0.5)
	# Chiziq asfalt ustida bo'lishi SHART. Bu ko'tarishni tushirib
	# qoldirsak, chiziq asfaltdan 6 sm pastda qoladi va butun yo'l
	# bo'ylab ko'rinmay qoladi.
	#
	# DIQQAT: vertex tartibi asfaltnikika TESKARI bo'lishi SHART.
	# Aks holda chiziq orqa yuzaga qaraydi va ko'rinishdan chiqadi
	# (asfalt esa ko'rinadi) — chalkashlik chiqadi.
	_quad(buffer, a + offset, a - offset, b - offset, b + offset,
		colour, LINE_LIFT)
