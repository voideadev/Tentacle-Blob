extends RefCounted

const PATH := "user://meta.cfg"
const DATA := {
	"hp": {"name": "Vitalidad", "desc": "+10 vida máxima", "max": 10, "cost": 20},
	"xp": {"name": "Voracidad", "desc": "+8% de XP", "max": 5, "cost": 30},
	"tent": {"name": "Tentáculo inicial", "desc": "+1 tentáculo al empezar", "max": 4, "cost": 40},
	"mut": {"name": "Mutación inicial", "desc": "Empiezas con una mutación al azar", "max": 3, "cost": 60},
	"armor": {"name": "Piel inicial", "desc": "-5% de daño recibido", "max": 5, "cost": 30},
	"dna": {"name": "Hambre de ADN", "desc": "+20% de ADN por partida", "max": 5, "cost": 40},
	"reroll": {"name": "Mutación mutable", "desc": "+1 relanzamiento de opciones", "max": 3, "cost": 50},
	"dash": {"name": "Embestida inicial", "desc": "+1 carga de lunge", "max": 2, "cost": 80},
	"egg": {"name": "Huevo ancestral", "desc": "Empiezas con Huevo parásito", "max": 1, "cost": 150},
}

static var dna := 0
static var best_depth := 0
static var levels := {}
static var loaded := false

static func load_data() -> void:
	if loaded:
		return
	loaded = true
	var cf := ConfigFile.new()
	var ok := cf.load(PATH) == OK
	if ok:
		dna = int(cf.get_value("meta", "dna", 0))
		best_depth = int(cf.get_value("meta", "best_depth", 0))
	for id in DATA:
		levels[id] = int(cf.get_value("levels", id, 0)) if ok else 0

static func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "dna", dna)
	cf.set_value("meta", "best_depth", best_depth)
	for id in DATA:
		cf.set_value("levels", id, levels.get(id, 0))
	cf.save(PATH)

static func level(id: String) -> int:
	return int(levels.get(id, 0))

static func cost(id: String) -> int:
	return int(DATA[id]["cost"]) * (level(id) + 1)

static func can_buy(id: String) -> bool:
	return level(id) < int(DATA[id]["max"]) and dna >= cost(id)

static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	dna -= cost(id)
	levels[id] = level(id) + 1
	save_data()
	return true
