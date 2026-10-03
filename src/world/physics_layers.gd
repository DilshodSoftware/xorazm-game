class_name PhysicsLayers
extends RefCounted
## Fizika qatlamlari. Boshqa fayllar faqat shu nomlarni ishlatadi —
## raqamlarni hech qayerda qo'lda yozmaymiz.
##
## project.godot ichidagi [layer_names] bilan bir xil tartibda.

const WORLD := 1 << 0        ## Yer, binolar, devorlar — statik
const PLAYER := 1 << 1       ## O'yinchi
const VEHICLE := 1 << 2      ## Mashinalar
const PROP := 1 << 3         ## Daraxt, ustun, to'shak — yashiriladigan
const TRIGGER := 1 << 4      ## Ta'sir zonalari (eshik, bekatchi)
const WATER := 1 << 5        ## Suv
const PROJECTILE := 1 << 6   ## O'q, tash
const HITBOX := 1 << 7       ## Zarar maydonlari

# --- Tayyor filtrlar ---

## Qat'iy narsalar: yerga va binolarga urilamiz.
const SOLID := WORLD | PROP

## Harakatlanuvchi narsalar: ularga tegamiz va ularni uramiz.
const CHARACTERS := PLAYER | VEHICLE

## O'yinchi o'z qatlami + uni ko'radigan qatlamlar.
const PLAYER_MASK := WORLD | PROP | VEHICLE | TRIGGER


## Maskani inson o'qiladigan satrga aylantirish (diagnostika uchun).
static func describe(mask: int) -> String:
	var names: Array[String] = []
	if mask & WORLD: names.append("World")
	if mask & PLAYER: names.append("Player")
	if mask & VEHICLE: names.append("Vehicle")
	if mask & PROP: names.append("Prop")
	if mask & TRIGGER: names.append("Trigger")
	if mask & WATER: names.append("Water")
	if mask & PROJECTILE: names.append("Projectile")
	if mask & HITBOX: names.append("Hitbox")
	return " ".join(names) if not names.is_empty() else "—"
