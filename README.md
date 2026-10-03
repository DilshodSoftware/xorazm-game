# XORAZM

Xorazm viloyati hududidagi ochiq dunyo o'yini — Urganch, Xiva, Amudaryo.
Godot 4 + GDScript. Barcha model, tekstura va shovqin **kodda** yaratiladi:
loyiha bitta fayl bilan ishga tushadi.

---

## Talablar

| | |
|---|---|
| **Dvigatel** | Godot **4.7.2-stable** (`~/Applications/godot`) |
| **Renderer** | `gl_compatibility` (OpenGL 3.3) |
| **GPU** | Intel UHD Graphics ICL GT1 dan kattaroq (sinovdan o'tgan: **Intel UHD ICL GT1**) |
| **Til** | GDScript (C# ishlatilmaydi) |

## Ishga tushirish

```bash
# O'yinni o'yingiz
~/Applications/godot --path .

# Tezkor diagnostika (F3 ham shuni ko'rsatadi)
~/Applications/godot --path . -- --bench

# O'yinchi fizikasining avtomatik tekshiruvi (27 ta test)
~/Applications/godot --headless --path . -- --test

# Xorazm relyefining tekshiruvi (45 ta test)
~/Applications/godot --headless --path . -- --test-terrain

# Yo'l tarmog'ining tekshiruvi (15 ta test)
~/Applications/godot --headless --path . -- --test-roads

# Tandirchi binolarining tekshiruvi (14 ta test)
~/Applications/godot --headless --path . -- --test-buildings

# Butun orolning tekis rasm xaritasi (GPU'siz)
~/Applications/godot --headless --path . -- --terrainmap /tmp/map.png

# Ekran surati
~/Applications/godot --path . -- --shot /tmp/shot.png      # o'yin ichidan
~/Applications/godot --path . -- --aerial /tmp/a.png      # ko'tarilgan
~/Applications/godot --path . -- --nofog /tmp/f.png       # tumanisiz
~/Applications/godot --path . -- --shot /tmp/s.png --hud # diagnostika bilan

# Istalgan nuqtadan, istalgan balandlikdan (burchak ham beriladi).
# Kamera YO'L BO'YLAB qaraydi — yo'lni tekshirish uchun qulay.
~/Applications/godot --path . -- --at /tmp/yo'l.png -745,180
~/Applications/godot --path . -- --at /tmp/yuqori.png -745,13 260 -42

# Nuqtaning relyefi, suv holati va eng yaqin yo'li
~/Applications/godot --headless --path . -- --probe "-745,180;-745,812"

# Bitta uyni qurib, ko'chadan ko'rish (uyni tuzatish uchun)
~/Applications/godot --path . -- --testhouse /tmp/uy.png
```

Godot muharririda: **Import** → loyihani tanlang → **Play (F5)**.

## Boshqaruv

| Tugma | Vazifasi |
|---|---|
| WASD | Yurish |
| Shift | Yugurish (kuch sarflanadi, charchaganda to'xtaydi) |
| Ctrl / C | Egilish |
| Space | Sakrash (tugma tez bo'shatilsa — pastki sakrash) |
| Sichqoncha | Ko'rish |
| F | (5-bosqich: mashinaga minish) |
| E | (2-bosqich: eshik / NPC) |
| F1 | Yordam · **F3** diagnostika · **Esc** chiqish |

---

## Dizayn asoslari

### Nima uchun ertalab 7:00?

Xorazm yozi erta tongda issiq, changli va g'atir. Bu bizning texnik
chegaramizni yashiradi: **Intel UHD GPU faqat ~450 m** ko'rish masofasini
ko'taradi. Iliq chang tumani shu chegarani Xorazmning haqiqiy
ko'rinishiga aylantiradi.

Quyosh 22° balandlikda, sharqdan. Qaror fayli: `src/world/khorezm_morning.gd`

### Nima uchun siqilgan xarita?

Shaharlar *orasidagi* masofa haqiqiy Xorazm koordinatalaridan **1:20**
hisoblanib olingan (Urganch ↔ Xiva 1,18 km). Lekin binolar va minoralar
**1:1 haqiqiy o'lchamda** — Kalta Minor 29 m, Islam Xo'ja 57 m, Ichan
Qal'a devorlari 10 m. Bu shuni beradi ki, minoralar tekis Xorazm
tekisligida 1 km dan ko'rinib turadi.

### Nima uchun barchasi kodda?

Tashqi fayl yo'q: mashinalar, binolar, daraxtlar, paxta maydonlari —
hammasi `ArrayMesh` va `MultiMesh` orqali generatsiya qilinadi, ranglar
`Palette` dan olinadi. Natija: bitta `git clone` — va o'yin shay.

### GPU chegaralari

| | |
|---|---|
| Ko'rish masofasi (tuman) | 450 m (Past sifatda 320 m) |
| Soya | 1 ta nur, faqat 120 m atrofida |
| Dynamic light | ≤ 8 |
| MultiMesh | 15 000 misol/kadr |
| Glow / SSAO | O'chirilgan (Compatibility'da yo'q) |

---

## Reja

| # | Bosqich | Holat |
|---|---|---|
| 0 | Muhit, ertalab yorug'ligi, til tizimi, Git | ✅ |
| 1 | O'yinchi, FPS kamera, harakat, egilish, sakrash | ✅ |
| 2 | Xorazm relyefi, chunk streaming, Amudaryo, sho'r ko'llar | ✅ |
| 3 | Yo'llar: halqa, radial, shahar to'ri, ko'pik, ko'prik | ✅ |
| 4 | Tandirchi mahallasi va o'yinchi uyining ichi | 🚧 |
| 5 | O'zbek mashinalari + haydash fizikasi | ⬜ |
| 6 | AI yo'l harakati, marshrutka, piyodalar | ⬜ |
| 7 | Urganch: baza, Al-Xorazmiy, Avesto bog'i, stansiya | ⬜ |
| 8 | Tabiat: to'qog'ay, paxta, qamish | ⬜ |
| 9 | Xiva: Ichan Qal'a, Kalta Minor, Islam Xo'ja | ⬜ |
| 10 | Kurashish, qurol, dushman AI | ⬜ |
| 11 | Dunyo jonli bo'lishi, saqlash, minimap, vazifa | ⬜ |
| 12+ | Tank va kema | ⬜ |

### Xorazm relyefi

Bitta manba bor: `TerrainGen.height_at(x, z)`. Dunyo, jamoa, paxta
maydonlari, daraxtlar va keyinchalik yo'llar hammasidan shu funksiya
o'qiydi — shuning uchun hech qayerda "ikkita xil balandlik" bo'lmaydi.

| | |
|---|---|
| Orol | 5,8 × 5,2 km (kvadratga yaqin, shaharlar to'g'ri sig'sin) |
| Chunk | 400 m · radius 2 (doira) = 21 ta · 1 kadr/kadr |
| Balandlik diapazoni | **−9 … +10 m** — Xorazm hech qachon tog'li emas |
| Shahar tepaligi | +6,00 m, radius 340 m bilan yumshoq o'tadi |
| Amudaryo | janubda, ~2140 m da, tubi −9 m |
| Sho'r ko'llar | 4 ta (janub), tubi −1,3 m |
| Kanallar | 4 ta (Shavat, Yermish, Polvon, Qilichniyozboy), 14 m keng |
| G'ovuk ko'l | Xivada, Ø 150 m |
| Qum tepaliklari | g'arb va janub-g'arb, 7,5 m |

**Tartib muhim:** mayin → chekadan cho'kish → shahar tepaligi → suv o'yilishi.
Oxirgi ikkitasi almashsa, shahar suv ostida qoladi yoki ko'l tepalik bilan
to'ladi (ikkalasi ham bo'lgan edi).

### O'yinchi parametrli

| | |
|---|---|
| Ko'z balandligi | 1,66 m (egilganda 1,05 m) |
| Tezliklar | yurish 5,1 · yugurish 7,6 · egilgan 1,45 m/s |
| Sakrash | 1,0 m (tugma tez bo'shatilsa 0,58 m) |
| Og'irlik | 19,6 m/s² (haqiqiy 9,8 — o'yin hissi uchun ikki barobar) |
| Kuch | yugurishda 13/s, 0,9 s kutgandan keyin tiklanadi |

### Yo'l tarmog'i

Xorazmda halqa yo'l **yo'q**. Lekin Amudaryo qirg'og'ida sel-suv
himoya dambalari aynan orol atrofida qurilgan va yo'llar shu damlar
ustida yuradi. Shu sababli bizning "halqa" — qirg'oqga moslangan
damlar yo'li.

| | |
|---|---|
| Tashqi halqa | ~48 km, **quruq yer tugagacha** har burchakda o'lchanadi |
| Radial | 6 ta, Urganchdan, haqiqiy shaharlar yo'nalishiga qarab |
| Shahar to'ri | Urganch — 150 × 130 m kvartal, doiraga sig'dirilgan |
| Qishloq yo'llari | 8 ta, g'ishtli (qum rangli, chiziqsiz) |
| Magistr | 14 m (4 tasma) · ko'cha 8 m (2 tasma) · qishloq 5 m |
| Ko'prik | kanal kesishgan **har** joyda avtomatik (hozir 5 ta) |

**Nima uchun halqa sun'iy ellipsa emas:** doimiy radiusli halqa janubda
Amudaryoning ichiga tushib, ko'priksiz qismda suv ustida qolardi.
Radiuslar endi har 2,5° da quruq yerni tekshirib, undan 220 m ichkarida
o'tadi — xuddi haqiqiy damba qilgandek.

**Nima uchun yer tekislanadi:** `TerrainGen.height_at` yo'llar ostidagi
yeri tekislaydi, shuning uchun mashina kengaytirilgan yerning o'zi
ustida haydaydi — alohida collision kerak emas va uzluksiz ishlaydi.

Profil uch qadam bilan barqarorlashtiriladi: oyna bilan yumshtash
(±200 m, 3 marta), **gradient cheklovi 1:40** va kesishmalarda
profillarni o'rtalash. Cheklov muhim: Xorazm — dunyodagi eng tekis
viloyatlardan biri, 2,5% dan tik yo'l bu yerda tabiiy emas.

```
project.godot      # loyiha sozlamalari, autoload'lar, fizika qatlamlari
data/locale/uz.json # barcha o'yin matnlari

src/core/          # game, event_bus, locale, palette, settings,
                   # save_system, game_state, input_setup
src/world/         # terrain_gen.gd     — BALANDLIKNING YAGONA MANBA
                   # world_map.gd       — Xorazmning haqiqiy koordinatalari
                   # world_chunk.gd     — 400 m bo'lak: mesh + collision
                   # chunk_manager.gd   — streaming
                   # water_surface.gd   — Amudaryo, kanallar, ko'llar
                   # khorezm_morning.gd — ertalab yorug'ligi
                   # physics_layers.gd  — qatlamlar
                   # debug_props.gd     (vaqtinchalik, 4-bosqichda o'chadi)
src/world/roads/   # road_network.gd   — YO'L TARMOG'I: geometriya, tekislash
                   # road_builder.gd    — ko'rinadigan yo'l, chiziq, ko'prik
src/buildings/     # building_kit.gd   — Xorazm uyining qismlari (eshik, to'sh,
                   #                      tarona, shift, ravoq, darvoza)
                   # courtyard_house.gd — bitta hovli uy
                   # tandirchi.gd       — KO'CHALAR VA UY JOYLARI (ma'lumot)
                   # building_manager.gd— binolarni chunk'lar bo'yicha yuklash
src/world/tree_kit.gd  — anor, nonak, qarag'ay, sharak, terak
src/player/        # player.gd, camera_rig.gd
src/main.gd        # o'yin ildizi
scenes/            # main.tscn, player/player.tscn
tools/             # player_selftest.gd — 27 ta test
                   # terrain_selftest.gd — 45 ta test
                   # road_selftest.gd   — 15 ta test
                   # building_selftest.gd — 14 ta test
                   # terrain_map.gd     — rasm xaritasi chizuvchisi
```

## Tekshiruv

Har bir bosqichda avtomatik tekshiruv ishlaydi:

```bash
~/Applications/godot --headless --path . -- --test           # o'yinchi (27)
~/Applications/godot --headless --path . -- --test-terrain   # relyef (45)
~/Applications/godot --headless --path . -- --test-roads     # yo'llar (15)
~/Applications/godot --headless --path . -- --test-buildings # Tandirchi (14)
~/Applications/godot --path . -- --bench                    # FPS (maqsad 60)
```

Har uchasi ham chiqish kodi bilan tugaydi: `0` = hammasi o'tdi, `1` = xato bor.

**Bu nima uchun muhim.** 2-bosqichda tekshiruvlar bitta ko'rinmas xatoni
topdi: chunk ostida bir necha kadrga teshik qolardi va o'yinchi havoga
tushib ketardi. Chunklar soni va renderlash statistikasi **normal**
ko'rinardi — faqat skrinshotga qarab sezildi.

3-bosqichda esa **fazolaviy to'r** xatosi shunday yashiringan edi:
diagonal yo'l kesimi katak chegarasini "sakrab" o'tib, o'sha katak
belgilanmagan qolardi. Natija: yo'lning markazi tekislangan, 4 m
yonidagi nuqta esa qo'lda qolgan — mashina yo'lda mayraydi, ko'prik
kerak joylar topilmadi. Hech qanday vizual belgi yo'q edi. Shu bois
`verify_index()` — har bir yo'l nuqtasi o'z katagida o'z yo'lini
topishi tekshiriladi. Kelgisi bosqichlarda ham shu poydevor kerak.

## O'zbek tilida o'zgartirish

Barcha matnlar `data/locale/uz.json` da. Masalan HP yorlig'ining matnini
o'zgartirmoq uchun `hud.samar` kalitini tahrirlang. Kodga tegilmaydi.

`Lang.txt("hud.samar")` · `Lang.group("mashinalar")` · `Lang.missing()`

> **Muhim:** tarjima metodi `tr` emas, `txt` — `Object.tr()` allaqachon
> mavjud (Godot'ning o'z funksiyasi) va override qilinishi butun
> loyihani buzadi.
