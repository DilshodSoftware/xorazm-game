extends Node
## Xorazm vizual palitrasi — barcha ranglar bu yerdan.
##
## Ranglar haqiqiy Xorazm manzarasidan olingan:
##   qum tepaliklari, socho'lda kuydirilgan g'isht, ko'k-sho'k daryo,
##   to'qog'oy yashiligi, paxta maydonlari.
##
## Bitta son ishlatish o'rniga shu nomlarni ishlating:
##   var c := Palette.SAND

# --- Yerlarning uslublari ---
## Qum ranglari ataylab biroz quyuq: quyosh + osmon yorug'ligi
## ularni yoritganda qiymat 1.0 dan oshadi va rang oqaga yuviladi.
const SAND := Color("a89164")           ## Qum tepaligi
const SAND_DARK := Color("8e7449")      ## Qumning soyasi
const STEPPE := Color("a9a062")          ## Quruq o't / dasht
const STEPPE_DRY := Color("8f8a52")      ## Parcha o't
const COTTON := Color("e3ddcc")          ## Paxta maydoni (oq)
const SOIL := Color("8d7350")            #  Sho'rlangan bo'z tuproq
const SALINE := Color("dcd8cc")          ## Sho'r ko'l quritilgan yuzasi
const RIVERBED := Color("9a8b62")        ## Amudaryo tubi

# --- Suv ---
const WATER_AMU := Color("5c8a86")       ## Amudaryo (loyqa ko'k-yashil)
const WATER_CANAL := Color("6f9b95")     ## Shavat, Polvon kanallari
const WATER_DEEP := Color("3d6b6b")      ## Chuqur suv

# --- Qurilish ---
const SAMAN := Color("bd9766")           ## Xiva devorlari: loydan yasalgan g'isht
const SAMAN_DARK := Color("9d7a4f")
const BRICK := Color("a87550")           ## Pishgan g'isht (pishgan g'isht)
const PLASTER := Color("d8cbb0")         ## G'isht ustiga surilgan suvaloq
const TILE_TURQUOISE := Color("2f9ba8")  ## Xiva ko'k kafel
const TILE_BLUE := Color("1f5f8c")
const TILE_CREAM := Color("e2d5b8")
const CONCRETE := Color("b3ada0")
const ROOF_GRAY := Color("8d8478")

# --- Tabiat ---
const TUGAY := Color("5e7a3c")          ## To'qog'oy: terak, tol
const TUGAY_LIGHT := Color("7a8b4e")     ## Yulg'un (tamarix)
const REED := Color("a8a066")            ## Qamish
const TRUNK := Color("6b5340")

# --- Yo'llar ---
const ASPHALT := Color("4a4a4c")
const ASPHALT_WORN := Color("5a5652")
const ROAD_LINE_WHITE := Color("e6e2d8")
const ROAD_LINE_YELLOW := Color("d4a93c")
const CONCRETE_ROAD := Color("7d786f")
const SOIL_ROAD := Color("9c8256")       ## Xorazmning qumloy yo'llari

# --- Ranglar (mashinalar) ---
## Real hayotdagidek: O'zbekistonda asosan oq va kuvа mashinalar.
const CAR_WHITE := Color("eceae4")
const CAR_SILVER := Color("b9bcc0")
const CAR_BLACK := Color("2a2a2c")
const CAR_GRAY := Color("8a8c8e")
const CAR_BLUE := Color("2f5f96")
const CAR_RED := Color("a33430")
const CAR_GREEN := Color("3d6b4a")
const CAR_BEIGE := Color("c2b291")
const CAR_TANTA_MARSHRUTKA := Color("f2f0ea")  ## Marshrutka — har doim oq

# --- Eshitish va yorug'lik ---
const SUN_MORNING := Color("ffeed2")
const FOG_DUST := Color("c6b090")       ## Changli tuman — oq emas, qumli
const SKY_TOP := Color("6f9cc4")
const SKY_HORIZON := Color("e3c79b")
const GROUND_HORIZON := Color("bda478")

# --- UI ---
const UI_BG := Color("1a1712")
const UI_PANEL := Color(0.10, 0.09, 0.07, 0.88)
const UI_TEXT := Color("efe7d8")
const UI_TEXT_DIM := Color("a89d8a")
const UI_ACCENT := Color("d9a441")
const UI_HP := Color("c8452f")
const UI_STAMINA := Color("5e8f5a")
const UI_MONEY := Color("7fbf6a")


## Rangni (0..1) yoki rang kodini (#rrggbb) qabul qiladi,
## ikalasini ham qaytaradi — kodda qulay bo'lishi uchun.
static func c(value: String) -> Color:
	return Color(value)
