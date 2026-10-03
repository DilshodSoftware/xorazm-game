class_name WaterSurface
extends Node3D
## Xorazmning suvi — bitta tekislik.
##
## Nima uchun shunday oddiy:
##   Xorazm — Amudaryo deltasi. Barcha suv (daryo, kanallar, G'ovuk ko'l,
##   sho'r ko'llar) bir xil darajada: 0 metr. Tekislikning balandligi
##   1:200 dan ham kam, shuning uchun ufq chizig'i ham deyarli ko'rinmaydi.
##   Bu Yevropaning yassi relyefi kabi — suvning « chegarasi » yo'q.
##
## Ko'rinish:
##   Amudaryo loyqa ko'k-yashil (daryo oqadigan holda xarakterik).
##   Kanallar aniqroq. Bitta material yetarli.

const EXTENT := 12000.0

@export var wave_speed := Vector2(0.006, 0.0035)

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	name = "Suv"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(EXTENT, EXTENT)
	mesh.subdivide_width = 1
	mesh.subdivide_depth = 1

	# --- Amudaryo rangi ---
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.WATER_AMU
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.86
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # pastdan ham ko'rinishi kerak
	mat.roughness = 0.18
	mat.metallic = 0.0
	mat.metallic_specular = 0.55                 # quyosh ko'zguzi
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	# --- Yuzasi juda sekin qimirlashi ---
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.06
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 128
	texture.height = 128
	texture.as_normal_map = true
	mat.normal_enabled = true
	mat.normal_scale = 0.35
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.position.y = Settings.SEA_LEVEL
	add_child(_mesh_instance)

	_material = mat
	# Noto'g'rilgan material tekshiruvni qiyinlashtiradi
	mat.resource_local_to_scene = true


func _process(delta: float) -> void:
	# Suv tekislangani uchun hech qanday geometriya o'zgarishi shart emas —
	# faqat tekstura siljitiladi. Bu arzon va effektli.
	_time += delta
	if _mesh_instance:
		var mat := _mesh_instance.material_override as StandardMaterial3D
		if mat:
			mat.uv1_offset += Vector3(wave_speed.x, wave_speed.y, 0.0) * delta
