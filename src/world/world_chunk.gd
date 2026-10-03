class_name WorldChunk
extends Node3D
## Bitta 400 × 400 m yer bo'lagi.
##
## Ikki narsa qiladi:
##   1. Ko'rinadigan mesh (radius 1 = batafsil, radius 2 = sodda)
##   2. Collision (HeightMapShape3D — juda arzon, maxsus tipdagi shakl)
##
## Chegara choklar: qo'shni chunklar o'z chegaralarida BIR XIL
## balandlik hisoblaydi (chunk ichki emas, global funksiyadan olinadi),
## shuning uchun darq yo'q.

## Yer usti materiali — barcha chunklar bitta materialni bo'lishadi.
static var _material: StandardMaterial3D
## Yerning donadorligi uchun kichik protsedural tekstura
static var _grain: ImageTexture
static var _assets_ready := false


static func _ensure_assets() -> void:
	if _assets_ready:
		return

	# --- 128 × 128 donadorlik. Bitta kichik tekstura — Intel UHD uchun
	# deyarli arzon, lekin tekis yerga "haqiqiy" ko'rinish beradi. ---
	const SIZE := 128
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = Settings.WORLD_SEED + 999
	for y in SIZE:
		for x in SIZE:
			# Ikkita chastota aralashtirilgan, o'rtasi 1.0 ga yaqin bulutli.
			# Kuchli kontrast: Xorazm yuzasi bir tekis rang emas, quritilgan
			# qum dog'lari va tuz izlari bilan "dog'langan".
			var a := rng.randf_range(-0.17, 0.17)
			var b := sin(float(x) * 0.9) * 0.055 + cos(float(y) * 0.7) * 0.055
			var value := clampf(1.0 + a + b, 0.0, 1.5)
			image.set_pixel(x, y, Color(value, value, value))
	_grain = ImageTexture.create_from_image(image)

	_material = StandardMaterial3D.new()
	# DIAGNOSTIKA: --flat-colour bayrog'i bilan yerga yagona rang beriladi.
	# Bu biz ko'rayotgan narsa haqiqatan yer ekanini isbotlaydi.
	if OS.get_cmdline_user_args().has("--flat-colour"):
		_material.vertex_color_use_as_albedo = false
		_material.albedo_texture = null
		_material.albedo_color = Color("d200ff")
		_assets_ready = true
		return
	_material.vertex_color_use_as_albedo = true   # rang mesh'dan
	_material.albedo_texture = _grain             # donadorlik teksturadan
	_material.uv1_scale = Vector3(26.0, 26.0, 1.0)
	_material.roughness = 1.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	_assets_ready = true


## Bitta chunk quradi va darhol tayyor bo'ladi.
## [param coord] — chunk koordinatalari (dunyo birliklarida)
## [param detail] — true = yaqin (batafsil), false = uzoq (sodda)
static func create(coord: Vector2i, detail: bool) -> WorldChunk:
	_ensure_assets()

	var chunk := WorldChunk.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.coord = coord
	chunk.position = Vector3(
		coord.x * Settings.CHUNK_SIZE, 0.0, coord.y * Settings.CHUNK_SIZE
	)
	chunk.detail = detail

	chunk._build_mesh(Settings.RES_NEAR if detail else Settings.RES_FAR)
	chunk._build_collision()

	return chunk


var coord: Vector2i
var detail := false


func _build_mesh(res: int) -> void:
	var step: float = Settings.CHUNK_SIZE / float(res)
	var columns: int = res + 1
	# Diqqat: chunk sahnaga qo'shilmagan holda quriladi, shuning uchun
	# global_position emas, position ishlatiladi (ChunkManager o'qda turadi).
	var origin := position

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	vertices.resize(columns * columns)
	normals.resize(columns * columns)
	colors.resize(columns * columns)
	uvs.resize(columns * columns)

	# --- Balandlik bir vaqtda collision uchun ham yig'iladi ---
	var heights := PackedFloat32Array()
	heights.resize(columns * columns)

	# Normal va qiyalik uchun qadam kattaligi
	var probe: float = step

	for row in columns:
		for col in columns:
			var i := row * columns + col
			var wx: float = origin.x + col * step
			var wz: float = origin.z + row * step
			var h: float = TerrainGen.height_at(wx, wz)
			heights[i] = h

			vertices[i] = Vector3(col * step, h, row * step)
			uvs[i] = Vector2(wx, wz) / 40.0

			# --- Markaziy farq bilan normal ---
			# Yuzaning normali aniq bo'ladi va bo'lak sonidan qat'i nazar
			# to'g'ri chiqadi (uchburchaklar tekis bo'lmasa ham).
			var h_left := TerrainGen.height_at(wx - probe, wz)
			var h_right := TerrainGen.height_at(wx + probe, wz)
			var h_down := TerrainGen.height_at(wx, wz - probe)
			var h_up := TerrainGen.height_at(wx, wz + probe)
			normals[i] = Vector3(h_left - h_right, 2.0 * probe, h_down - h_up).normalized()

			var slope: float = 1.0 - normals[i].y
			colors[i] = TerrainGen.color_at(wx, wz, h, slope)

	# --- Uchburchaklar ---
	# DIQQAT: YO'NALISH. Godot'da old (ko'rinadigan) yuzalar AYNAN
	# shu tartibda. Noto'g'ri yo'nalishda mesh "shaffof" bo'lib qoladi:
	# backface culling uni ikki tomondan ham yashiradi va o'yinchi
	# osmonning yerga qaragan yarimini ko'radi (belgisi — relyef
	# rangi butunlay ko'rinmaydi, lekin renderlash statistikasi
	# o'zgarmaydi, chunklar esa "yuklangan" bo'lib turadi).
	var indices := PackedInt32Array()
	indices.resize(res * res * 6)
	var w := 0
	for row in res:
		for col in res:
			var i := row * columns + col
			indices[w] = i
			indices[w + 1] = i + 1
			indices[w + 2] = i + columns
			indices[w + 3] = i + 1
			indices[w + 4] = i + columns + 1
			indices[w + 5] = i + columns
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var node := MeshInstance3D.new()
	node.name = "Yer"
	node.mesh = mesh
	node.material_override = _material
	# Yer soyani QABUL qiladi, lekin O'ZI soya tashlamaydi:
	# 400 m li chunkdan soya chiqarish ikki barobar ishlashni talab qiladi
	# va hech narsa yaxshilamaydi (relief yassilanadi).
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

	_collider_heights = heights


var _collider_heights := PackedFloat32Array()


func _build_collision() -> void:
	# Collision balandligi boshqacha to'rda (RES_COLLISION) — visual
	# bo'laklardan farqli bo'lishi mumkin.
	var res: int = Settings.RES_COLLISION
	var columns: int = res + 1
	var step: float = Settings.CHUNK_SIZE / float(res)
	# Diqqat: chunk sahnaga qo'shilmagan holda quriladi, shuning uchun
	# global_position emas, position ishlatiladi (ChunkManager o'qda turadi).
	var origin := position

	# Masshtab: bir katak = CHUNK_SIZE / res metr.
	var scale: float = Settings.CHUNK_SIZE / float(res)

	var data := PackedFloat32Array()
	data.resize(columns * columns)
	for row in columns:
		for col in columns:
			# Balandlikni masshtabga bo'lamiz: node.scale Y o'qiga ham
			# ta'sir qiladi va shakldagi qiymat yana ko'payadi.
			data[row * columns + col] = TerrainGen.height_at(
				origin.x + col * step, origin.z + row * step
			) / scale

	# HeightMapShape3D ichki kataklari 1 birlikli. Bizda bitta katak
	# CHUNK_SIZE / res metr bo'lishi kerak, shuning uchun shaklni
	# masshtablaymiz.
	#
	# DIQQAT (4.7 da tekshirilgan):
	#   * up_direction xossasi olib tashlangan — xarita har doim Y bo'ylab
	#   * map_data hajmi = map_width * map_depth, (w+1)*(d+1) EMAS
	#     ya'ni map_width = nuqtalar soni = res + 1
	#   * shakl (map_width - 1) birlikni qamrab oladi
	var shape := HeightMapShape3D.new()
	shape.map_width = columns
	shape.map_depth = columns
	shape.map_data = data

	var node := CollisionShape3D.new()
	node.shape = shape
	# Masshtab Y o'qiga ham ta'sir qiladi, shuning uchun balandlikni
	# oldindan bo'lib qo'yamiz (pastda).
	node.scale = Vector3(scale, scale, scale)

	var body := StaticBody3D.new()
	body.name = "Kolpasi"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.add_child(node)
	add_child(body)


## Boshqa tarafdan kelgan balandlikni o'zgartirish (yo'llar, 3-bosqich).
## Bu qimmat: butun chunk qaytadan quriladi.
func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_collider_heights = PackedFloat32Array()
	_build_mesh(Settings.RES_NEAR if detail else Settings.RES_FAR)
	_build_collision()
