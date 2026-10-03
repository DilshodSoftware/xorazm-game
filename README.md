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

# O'yinchi fizikasining avtomatik tekshiruvi (22 ta test)
~/Applications/godot --headless --path . -- --test

# Ekran surati olish (dizayn tekshiruvi)
~/Applications/godot --path . -- --shot /tmp/shot.png
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
| 2 | Xorazm relyefi, chunk streaming, Amudaryo, sho'r ko'llar | ⬜ |
| 3 | Yo'llar: halqa, radial, shahar to'ri, ko'pik, ko'prik | ⬜ |
| 4 | Tandirchi mahallasi va o'yinchi uyining ichi | ⬜ |
| 5 | O'zbek mashinalari + haydash fizikasi | ⬜ |
| 6 | AI yo'l harakati, marshrutka, piyodalar | ⬜ |
| 7 | Urganch: baza, Al-Xorazmiy, Avesto bog'i, stansiya | ⬜ |
| 8 | Tabiat: to'qog'ay, paxta, qamish | ⬜ |
| 9 | Xiva: Ichan Qal'a, Kalta Minor, Islam Xo'ja | ⬜ |
| 10 | Kurashish, qurol, dushman AI | ⬜ |
| 11 | Dunyo jonli bo'lishi, saqlash, minimap, vazifa | ⬜ |
| 12+ | Tank va kema | ⬜ |

### O'yinchi parametrli

| | |
|---|---|
| Ko'z balandligi | 1,66 m (egilganda 1,05 m) |
| Tezliklar | yurish 5,1 · yugurish 7,6 · egilgan 1,45 m/s |
| Sakrash | 1,0 m (tugma tez bo'shatilsa 0,58 m) |
| Og'irlik | 19,6 m/s² (haqiqiy 9,8 — o'yin hissi uchun ikki barobar) |
| Kuch | yugurishda 13/s, 0,9 s kutgandan keyin tiklanadi |

---

## Tuzilma

```
project.godot      # loyiha sozlamalari, autoload'lar, fizika qatlamlari
data/locale/uz.json # barcha o'yin matnlari

src/core/          # game, event_bus, locale, palette, settings,
                   # save_system, game_state, input_setup
src/world/         # khorezm_morning.gd (yorug'lik)
                   # world_map.gd — Xorazmning haqiqiy koordinatalari
                   # physics_layers.gd — qatlamlar
                   # debug_props.gd (vaqtinchalik, 4-bosqichda o'chadi)
src/player/        # player.gd, camera_rig.gd
src/main.gd        # o'yin ildizi
scenes/            # main.tscn, player/player.tscn
tools/             # player_selftest.gd — 22 ta avtomatik test
```

## Tekshiruv

Har bir bosqichda avtomatik tekshiruv ishlaydi:

```bash
~/Applications/godot --headless --path . -- --test    # o'yinchi fizikasi
~/Applications/godot --path . -- --bench             # FPS (maqsad 60)
```

`--test` chiqish kodi bilan tugaydi: `0` = hammasi o'tdi, `1` = xato bor.
Bu kelgisi bosqichlarda muhim: yurish, sakrash, egilish va qatlamlar
keyingi bosqichlarning poydevori (mashinaga minish, suzish, kurashish).

## O'zbek tilida o'zgartirish

Barcha matnlar `data/locale/uz.json` da. Masalan HP yorlig'ining matnini
o'zgartirmoq uchun `hud.samar` kalitini tahrirlang. Kodga tegilmaydi.

`Lang.txt("hud.samar")` · `Lang.group("mashinalar")` · `Lang.missing()`

> **Muhim:** tarjima metodi `tr` emas, `txt` — `Object.tr()` allaqachon
> mavjud (Godot'ning o'z funksiyasi) va override qilinishi butun
> loyihani buzadi.
