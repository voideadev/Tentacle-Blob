extends RefCounted

const DATA := {
	"tentacles": {"name": "Tentáculos extra", "desc": "+2 tentáculos: más agarre, más velocidad y más presas a la vez.", "max": 3, "w": 10},
	"reach": {"name": "Zarpa larga", "desc": "+20% de alcance. Agarras paredes y presas desde más lejos.", "max": 4, "w": 10},
	"muscle": {"name": "Músculo reptante", "desc": "+12% de velocidad y más empuje al agarrarte.", "max": 4, "w": 10},
	"claws": {"name": "Garras", "desc": "Las puntas de tus tentáculos desgarran a quien toquen.", "max": 3, "w": 8},
	"acid": {"name": "Aura ácida", "desc": "Disuelve poco a poco a los enemigos que se acercan.", "max": 3, "w": 7},
	"regen": {"name": "Metabolismo", "desc": "Regeneras +2 de vida por segundo.", "max": 3, "w": 8},
	"armor": {"name": "Piel gruesa", "desc": "Recibes un 15% menos de daño.", "max": 4, "w": 8},
	"dash": {"name": "Embestida doble", "desc": "+1 carga de lunge y recarga más rápida.", "max": 3, "w": 8},
	"shock": {"name": "Onda de choque", "desc": "Al terminar un lunge, una onda mata a los cercanos.", "max": 3, "w": 6},
	"vamp": {"name": "Vampirismo", "desc": "+3 de vida extra por cada presa devorada.", "max": 4, "w": 7},
	"magnet": {"name": "Hambre voraz", "desc": "Cazas presas desde más lejos y las arrastras más rápido.", "max": 3, "w": 8},
	"rush": {"name": "Adrenalina", "desc": "Tras cada muerte, ganas velocidad durante 3 segundos.", "max": 2, "w": 7},
	"hyper": {"name": "Hipertrofia", "desc": "+25 de vida máxima, curación total y más tamaño.", "max": 3, "w": 6},
	"sense": {"name": "Olfato", "desc": "Ves a todos los enemigos en el minimapa.", "max": 1, "w": 6},
	"shield": {"name": "Escudo de carne", "desc": "Tus tentáculos bloquean balas y te curan al hacerlo.", "max": 1, "w": 4},
	"egg": {"name": "Huevo parásito", "desc": "Si mueres, renaces con 50% de vida y una explosión.", "max": 2, "w": 3},
}

static func roll(stacks: Dictionary, count: int) -> Array:
	var pool: Array = []
	for id in DATA:
		if stacks.get(id, 0) < DATA[id]["max"]:
			pool.append(id)
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += float(DATA[id]["w"])
		var r := randf() * total
		var chosen = pool[0]
		for id in pool:
			r -= float(DATA[id]["w"])
			if r <= 0.0:
				chosen = id
				break
		out.append(chosen)
		pool.erase(chosen)
	return out
