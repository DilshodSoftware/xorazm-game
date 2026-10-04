extends SceneTree
## VAQTINCHALIK DIAGNOSTIKA (ish yakunida o'chiriladi).

func _init() -> void:
	var stats := {}
	for p: Dictionary in Khiva.plots():
		var nom := String(p["nom"])
		stats[nom] = int(stats.get(nom, 0)) + 1
	for k: String in stats:
		print("JOY  %-36s %d" % [k, stats[k]])
	print("--- RAD ETILGANLAR ---")
	for k: String in Khiva._radetildi:
		print("RAD  %-52s %d" % [k, Khiva._radetildi[k]])
	print("jami joy: %d" % Khiva.plots().size())
	quit(0)
