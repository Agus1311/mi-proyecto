extends Node
## Datos del juego (tickets, usuarios, correos, habilidades...).
## Se cargan desde data/game_data.json, extraído tal cual del prototipo HTML.

var POOL: Array = []
var USERS: Array = []
var MT: Array = []
var DEV: Array = []
var MA: Array = []
var SHOP: Array = []
var JB: Array = []
var SK: Array = []
var ACH: Dictionary = {}
var CALLS: Array = []
var RANKS: Array = []
var TH: Array = []
var FAULTS: Array = []
var PARTS: Dictionary = {}
var COMP: Array = []
var TOOLS: Array = []
var TAP: Dictionary = {}
var NORM: Dictionary = {}
var PRI: Array = []

# Carteles de las pantallas de publicidad: [título, subtítulo, color fondo]
const ADS := [
	["CAA CORP", "Tecnología que conecta", "0b2a4a"],
	["SOPORTE IT 24/7", "Rápido, humano y seguro", "2a1b4a"],
	["CIBERSEGURIDAD", "Protegemos tu información", "0b3a2a"],
	["REDES CISCO", "Conectividad de alto rendimiento", "3a1f0b"],
	["ÚNETE A CAA CORP", "Vacantes en RRHH · Piso 1", "0b2a4a"],
]

func _init() -> void:
	var f := FileAccess.open("res://data/game_data.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	POOL = d["POOL"]
	USERS = d["USERS"]
	MT = d["MT"]
	DEV = d["DEV"]
	MA = d["MA"]
	SHOP = d["SHOP"]
	JB = d["JB"]
	SK = d["SK"]
	ACH = d["ACH"]
	CALLS = d["CALLS"]
	RANKS = d["RANKS"]
	TH = d["TH"]
	FAULTS = d["FAULTS"]
	PARTS = d["PARTS"]
	COMP = d["COMP"]
	TOOLS = d["TOOLS"]
	TAP = d["TAP"]
	NORM = d["NORM"]
	PRI = d["PRI"]
