extends SceneTree
## VAQTINCHALIK DIAGNOSTIKA (ish yakunida o'chiriladi).

func _init() -> void:
	# Xast Imam ning pastki nuqtalari qayerdan kelmoqda?
	var xp: Dictionary = Khiva.plots()[0]
	for p: Dictionary in Khiva.plots():
		if int(p["uslub"]) == Khiva.Uslub.MADRASA_XAST:
			xp = p
	var bb := MeshBuilder.new()
	KhivaBuildings.build_xast_imam(bb, xp["markaz"], 0.0, float(xp["yaw"]),
		float(xp["en"]), float(xp["chuqur"]))
	print("Xast Imam asos = 6.0 (test uchun 0), markaz ", xp["markaz"],
		" yaw ", xp["yaw"])
	var pastki: Array[Vector3] = []
	for v: Vector3 in bb.vertices:
		if v.y < 0.5:
			pastki.append(v)
	print("pastki nuqta: ", pastki.size())
	for v: Vector3 in pastki.slice(0, 8):
		print("   ", v)

	# Uy uchburchaklari
	var uylar: Array[int] = []
	for p: Dictionary in Khiva.plots():
		if int(p["uslub"]) != Khiva.Uslub.UY:
			continue
		var b2 := MeshBuilder.new()
		KhivaBuildings.build_uy(b2, p["markaz"], 0.0, float(p["yaw"]),
			float(p["en"]), float(p["chuqur"]), int(p["qavat"]),
			int(p["urish"]))
		uylar.append(b2.triangle_count())
	var jami := 0
	for n: int in uylar:
		jami += n
	print("uylar: %d ta, o'rtacha %d, jami %d" % [uylar.size(),
		jami / maxi(1, uylar.size()), jami])

	# Har bir uslub uchun
	var uslublar := {}
	for p: Dictionary in Khiva.plots():
		var u := int(p["uslub"])
		var b3 := MeshBuilder.new()
		KhivaBuildings.build_plot(b3, p)
		uslublar[u] = int(uslublar.get(u, 0)) + b3.triangle_count()
	for k: int in uslublar:
		print("  uslub %d: %d uchburchak" % [k, uslublar[k]])
	quit(0)
