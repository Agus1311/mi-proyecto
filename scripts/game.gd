extends Node
## Estado y reglas del juego (autoload "Game").
## Port de la lógica del prototipo HTML: tickets, jornada, economía, habilidades,
## eventos de red, Active Directory, correo, BIOS, taller y llamadas.

signal changed
signal toast_msg(text: String, secs: float)
signal day_finished(summary: Dictionary)
signal call_started(idx: int)
signal ticket_resolved(i: int)

const END := 17 * 60
const COST := 60
const SAVE_PATH := "user://itg1.json"
const STN := [
	null,
	{"name": "Marta", "dept": "Contabilidad"},
	{"name": "Luis", "dept": "Operaciones"},
	{"name": "Carlos", "dept": "Ventas"},
	{"name": "Un usuario", "dept": ""},
	{"name": "la copiadora", "dept": ""},
]
const MODELS := ["OptiPlex 7090", "ThinkCentre M70", "ProDesk 400 G7", "Vostro 3910"]

# --- progreso persistente ---
var G: Dictionary = {}

# --- estado de la jornada ---
var sat := 50
var sec := 50
var done := 0
var net := 0
var time := 480
var earn := 0
var over := false
var tickets: Array = []
var tstate: Array = []        # -1 = abierto; si no, índice de la opción elegida
var ad: Array = []
var adt: Array = []
var mails: Array = []
var slaB := 0
var slaK := 0
var cs: Array = []
var rep := 0
var rma: Dictionary = {}
var bn: Dictionary = {"tab": "ord", "o": 0}
var rq: Array = []
var calls: Array = []
var call_open := false
var mfa := 0
var bios: Dictionary = {}
var evl: Array = []
var inv: Dictionary = {}
var dev: Array = []
var ev: Array = []
var sw: IOSSim

# --- estado de interfaz / mundo ---
var sitting := false
var onsite := 0
var at_home := false


func _ready() -> void:
	randomize()
	_load()
	sw = IOSSim.new()
	new_day()


# ============================================================ utilidades ====
func rn(n: int) -> int:
	return randi() % n


func shuffled(a: Array) -> Array:
	var b := a.duplicate()
	b.shuffle()
	return b


func ups() -> Dictionary:
	return G["ups"]


func sk(k: String) -> int:
	return int(G["sk"].get(k, 0))


func lvl() -> int:
	return int(G["xp"] / 120) + 1


func ri() -> int:
	var r := 0
	for i in Data.TH.size():
		if G["xp"] >= int(Data.TH[i]):
			r = i
	return r


func rank() -> String:
	return Data.RANKS[ri()]


func time_str() -> String:
	return "%02d:%02d" % [time / 60, time % 60]


func date_str() -> String:
	return "21/01/2025"


func clock_str() -> String:
	return date_str() + "  " + time_str()


func hhmm(n: int) -> String:
	return "%02d:%02d" % [n / 60, n % 60]


func alerts() -> int:
	var c := 0
	for e in ev:
		if e["fired"] and not e["done"]:
			c += 1
	return c


func slaDl(k: Dictionary) -> int:
	return [960, 780, 660][int(k["p"]) - 1]


func sla_text(i: int) -> String:
	if tstate[i] != -1:
		return ""
	var dl := slaDl(tickets[i])
	if time > dl:
		return " · SLA vencido"
	return " · SLA " + hhmm(dl)


func pending_at(loc: int) -> bool:
	for i in tickets.size():
		if int(tickets[i]["loc"]) == loc and tstate[i] == -1:
			return true
	return bool(bios.get("loc", -1) == loc and not bios.get("done", true))


func open_tickets() -> int:
	var c := 0
	for s in tstate:
		if s == -1:
			c += 1
	return c


func first_open(loc: int = -1) -> int:
	for i in tickets.size():
		if tstate[i] == -1 and (loc < 0 or int(tickets[i]["loc"]) == loc):
			return i
	return -1


# =============================================================== guardado ====
func _default_g() -> Dictionary:
	return {"day": 1, "money": 100, "xp": 0, "ups": {}, "ach": {}, "job": 0, "eve": 0, "sk": {}, "sp": 0, "lv": 1,
		"parts": {"ram": 1, "psu": 1, "ssd": 1, "fan": 1, "cmos": 2, "paste": 3}, "note": "", "nt": {}}


func _load() -> void:
	G = _default_g()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				G[k] = d[k]
	for k in ["day", "money", "xp", "job", "eve", "sp", "lv"]:
		G[k] = int(G[k])
	for k in G["sk"]:
		G["sk"][k] = int(G["sk"][k])
	for k in G["parts"]:
		G["parts"][k] = int(G["parts"][k])


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(G))


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_load()
	new_day()


# =============================================================== feedback ====
func toast(t: String, secs: float = 3.2) -> void:
	toast_msg.emit(t, secs)


func ach(k: String) -> void:
	if G["ach"].has(k):
		return
	G["ach"][k] = 1
	save()
	toast("🏆 Logro: " + Data.ACH[k][0])


func hud() -> void:
	ev_check()
	lv_check()
	changed.emit()


func bump(a: int, b: int, m: String) -> void:
	sat = clampi(sat + a, 0, 100)
	sec = clampi(sec + b, 0, 100)
	hud()
	toast(m)


func adv(m: int) -> void:
	time += m
	hud()
	if time >= END:
		finish()


func lv_check() -> void:
	var L := lvl()
	if L > int(G["lv"]):
		G["sp"] = int(G["sp"]) + L - int(G["lv"])
		G["lv"] = L
		save()
		toast("⭐ ¡Nivel %d! +1 punto de habilidad" % L)
		if L >= 5:
			ach("lv5")


func ev_check() -> void:
	for e in ev:
		if not e["fired"] and time >= e["t"]:
			e["fired"] = true
			dev[e["d"]] = "down"
			toast("⚠ ALERTA: " + Data.DEV[e["d"]][0] + " sin respuesta")
	if call_open:
		return
	for i in calls.size():
		var c: Dictionary = calls[i]
		if not c["fired"] and time >= c["t"]:
			c["fired"] = true
			call_open = true
			call_started.emit(int(c["i"]))
			return


func answer_call(call_i: int, opt: int) -> void:
	var o: Array = Data.CALLS[call_i][2][opt]
	call_open = false
	G["xp"] = int(G["xp"]) + int(o[3])
	bump(int(o[1]), int(o[2]), o[4])
	adv(3)
	if int(o[3]) != 0:
		ach("call")


# ================================================================ nuevo día ====
func new_day() -> void:
	over = false
	done = 0
	net = 0
	time = 480
	var nt: Dictionary = G["nt"]
	sat = 50 + (10 if ups().has("coffee") else 0) + int(nt.get("cook", 0)) * 5 + int(nt.get("tv", 0)) * 5
	sec = 50
	earn = 0
	G["eve"] = 0
	_build_tickets()
	_build_ad_mail()
	slaB = 0
	slaK = 0
	cs = []
	rep = 0
	rma = {}
	bn = {"tab": "ord", "o": 0}
	_build_workshop_calls()
	mfa = 0
	bios = {"loc": 1 + rn(3), "done": false, "page": "Main", "cfg": {"boot": "USB Drive", "sb": "Disabled", "tpm": "Disabled"}}
	_build_event_log()
	var dv := range(Data.DEV.size())
	dv = shuffled(dv)
	dev = []
	for _d in Data.DEV:
		dev.append("ok")
	ev = []
	for i in 3:
		ev.append({"t": 540 + i * 120 + rn(60), "d": dv[i], "fired": false, "done": false})
	sw.reset(int(G["day"]))
	call_open = false
	hud()
	toast("Bienvenido a CAA Corp. Los usuarios te buscarán para pedir ayuda; también puedes visitar RRHH, Copiado, Contabilidad, Ventas, Operaciones y Gerencia." if G["day"] == 1 else "Día %d en una nueva sucursal. ¡Suerte!" % G["day"], 5.0)


func _build_tickets() -> void:
	tickets = []
	var all: Array = []
	for k in Data.POOL:
		var c: Dictionary = k.duplicate(true)
		c["from0"] = c["from"]
		c["loc"] = 0
		all.append(c)
	all = shuffled(all)
	var cp = null
	for k in all:
		if k.get("copy", 0) != 0:
			cp = k
			break
	var picked: Array = []
	if cp != null:
		picked.append(cp)
	for k in all:
		if k.get("copy", 0) == 0:
			picked.append(k)
	picked = picked.slice(0, 8)
	picked = shuffled(picked)
	tickets = picked
	for k in tickets:
		k["loc"] = 5 if k.get("copy", 0) != 0 else 0
	# candidatos a atenderse en sitio (excluye alertas automáticas, TI, teletrabajo...)
	var re := RegEx.create_from_string("Seguridad|\\bTI\\b|Teletrabajo|Soporte|Mesa")
	var cand: Array = []
	for k in tickets:
		if k.get("copy", 0) == 0 and re.search(k["from0"]) == null:
			cand.append(k)
	var pool: Array = shuffled(cand if cand.size() >= 3 else tickets)
	for n in 3:
		var k: Dictionary = pool[n]
		var l := n + 1
		k["loc"] = l
		k["from"] = STN[l]["name"] + " · " + STN[l]["dept"]
	var wn := shuffled(["Sofía", "Andrea", "Jorge", "Patricia", "Daniel"])
	var cols := [0xd05a7a, 0x4c7ad0, 0x6a9a4c, 0xe8a03a, 0x8a5ac0, 0x3aa7a7]
	var paren := RegEx.create_from_string("^.*\\((.*)\\)$")
	for n in range(3, mini(5, pool.size())):
		var k: Dictionary = pool[n]
		if int(k["loc"]) != 0:
			continue
		k["loc"] = 4
		k["who"] = wn[n - 3]
		k["col"] = cols[rn(6)]
		var m := paren.search(k["from0"])
		k["from"] = k["who"] + " · " + (m.get_string(1) if m else k["from0"])
	tstate = []
	for _k in tickets:
		tstate.append(-1)
	cur = -1


var cur := -1


func _build_ad_mail() -> void:
	var ids := shuffled(range(Data.USERS.size()))
	ad = []
	for _u in Data.USERS:
		ad.append({"lock": false, "off": false, "ex": false})
	ad[ids[0]]["lock"] = true
	ad[ids[1]]["lock"] = true
	ad[ids[2]]["ex"] = true
	adt = []
	for pr in [[ids[0], "unlock"], [ids[1], "unlock"], [ids[2], "disable"]]:
		var u: int = pr[0]
		var k: String = pr[1]
		adt.append({"u": u, "k": k, "done": false,
			"txt": ("Desbloquear la cuenta de " if k == "unlock" else "Deshabilitar la cuenta del ex empleado ") + Data.USERS[u][1]})
	mails = []
	for m in shuffled(Data.MT).slice(0, 5):
		mails.append({"m": m, "a": null})


func _build_workshop_calls() -> void:
	var fi: Array = []
	for i in Data.FAULTS.size():
		if int(G["day"]) >= 2 or Data.FAULTS[i]["c"] != "gpu":
			fi.append(i)
	fi = shuffled(fi)
	var ux := shuffled(range(Data.USERS.size()))
	var ci := shuffled(range(Data.CALLS.size()))
	rq = []
	for k in (3 if int(G["day"]) >= 3 else 2):
		rq.append({"f": fi[k], "own": Data.USERS[ux[k]][1], "mod": MODELS[rn(4)], "fixed": false, "sel": null, "log": []})
	calls = []
	for k in 3:
		calls.append({"t": 570 + k * 170 + rn(40), "fired": false, "i": ci[k]})


func _build_event_log() -> void:
	var atk := "185.220.101.%d" % (10 + rn(80))
	var au: String = Data.USERS[rn(8)][0]
	var L: Array = []
	var BN := [[4624, "Auditoría correcta"], [4672, "Información"], [7036, "Información"], [4625, "Auditoría de errores"]]
	for i in 5:
		L.append({"t": "03:12:%02d" % (i * 2 + 1), "lv": "Auditoría de errores", "id": 4625, "u": au, "ip": atk})
	L.append({"t": "03:12:14", "lv": "Auditoría correcta", "id": 4624, "u": au, "ip": atk})
	for i in 9:
		var b: Array = BN[rn(3 if i < 2 else 4)]
		L.append({"t": "%02d:%02d:%02d" % [7 + rn(9), rn(60), rn(60)], "lv": b[1], "id": b[0], "u": Data.USERS[rn(8)][0], "ip": "10.0.0.%d" % (10 + rn(40))})
	L.sort_custom(func(a, b): return a["t"] < b["t"])
	evl = L
	inv = {"ip": atk, "done": false}


# ================================================================== tickets ====
## Aplica la opción j al ticket i. Devuelve los datos para mostrar el feedback.
func resolve(i: int, j: int) -> Dictionary:
	var o: Array = tickets[i]["o"][j]
	var a := int(o[1])
	var b := int(o[2])
	tstate[i] = j
	done += 1
	ticket_resolved.emit(i)
	sat = clampi(sat + a + (sk("comm") if a > 0 else 0), 0, 100)
	sec = clampi(sec + b + (((2 if ups().has("sec") else 0) + sk("hard")) if b > 0 else 0), 0, 100)
	if time > slaDl(tickets[i]):
		slaB += 1
		sat = maxi(0, sat - 4)
		toast("⏰ SLA incumplido: −4 de satisfacción")
	else:
		slaK += 1
	time += maxi(10, (20 if ups().has("chair") else 25) - sk("time") * 2)
	var sc := a + b
	earn += 30 if sc >= 8 else (15 if sc >= 0 else 0)
	ach("first")
	hud()
	var stars := 5 if sc >= 12 else (4 if sc >= 6 else (3 if sc >= 0 else (2 if sc >= -8 else 1)))
	cs.append(stars)
	return {"text": o[3], "stars": stars, "good": sc >= 8, "sat": a, "sec": b}


func finish() -> void:
	if over:
		return
	over = true
	var pnd := open_tickets()
	var down := alerts()
	sat = maxi(0, sat - pnd * 5)
	sec = maxi(0, sec - down * 5 - (8 if not inv.get("done", true) else 0))
	var t := (sat + sec) / 2.0
	var bonus := 100 if t >= 80 else (40 if t >= 60 else 0)
	var pay := int(round(maxf(0.0, 100 + earn + bonus - down * 30 - pnd * 20) * float(Data.JB[G["job"]][3])))
	var xp := int(round(t + done * 5 + net * 10))
	var r0 := rank()
	G["money"] = maxi(0, int(G["money"]) + pay - COST)
	G["xp"] = int(G["xp"]) + xp
	if done > 0:
		ach("first")
	if t >= 85:
		ach("perfect")
	if int(G["day"]) >= 5:
		ach("week")
	save()
	var r1 := rank()
	hud()
	var head := "Día para el olvido"
	if t >= 80:
		head = "Analista estrella"
	elif t >= 60:
		head = "Buen desempeño"
	elif t >= 40:
		head = "Necesitas práctica"
	var p := "Día %d: %d/%d tickets, %d/3 trabajos de red. Satisfacción %d · Seguridad %d. Cobras $%d (+%d XP). Saldo: $%d." % [G["day"], done, tickets.size(), net, sat, sec, pay, xp, G["money"]]
	p += (" ¡Ascenso a %s!" % r1) if r1 != r0 else (" Rango: %s." % r1)
	if pnd > 0:
		p += " Tickets sin atender: %d." % pnd
	if down > 0:
		p += " Alertas sin resolver: %d." % down
	if not inv.get("done", true):
		p += " Ataque sin investigar."
	p += " Gastos de vida: $%d. SLA cumplidos: %d/%d." % [COST, slaK, slaK + slaB]
	if not cs.is_empty():
		var s := 0
		for x in cs:
			s += x
		p += " Valoración media: %.1f★." % (float(s) / cs.size())
	if rep > 0:
		p += " Reparaciones: %d." % rep
	var al: Array = []
	for k in Data.ACH:
		al.append(("🏆 " if G["ach"].has(k) else "🔒 ") + Data.ACH[k][0])
	day_finished.emit({"title": head, "text": p, "ach": "  ·  ".join(PackedStringArray(al))})


func go_home() -> void:
	at_home = true
	G["nt"] = {"study": 0, "cook": 0, "tv": 0}
	toast("Llegaste a casa. Estudia, cocina, mira TV y duerme para empezar un nuevo día.", 5.0)


func home_action(k: String) -> bool:
	## Devuelve true si se durmió (nuevo día).
	var nt: Dictionary = G["nt"]
	if k == "study":
		nt["study"] = 1
		G["xp"] = int(G["xp"]) + 25
		toast("Estudiaste para tu certificación: +25 XP")
	elif k == "cook":
		nt["cook"] = 1
		G["money"] = maxi(0, int(G["money"]) - 5)
		toast("Cocinaste una buena cena: +5 de satisfacción mañana (−$5)")
	elif k == "tv":
		nt["tv"] = 1
		toast("Un rato de TV para despejarte: +5 de satisfacción mañana")
	else:
		at_home = false
		G["day"] = int(G["day"]) + 1
		save()
		new_day()
		return true
	hud()
	return false


# ====================================================== Active Directory ====
func ad_act(i: int, a: String) -> void:
	var u: Dictionary = ad[i]
	var n: String = Data.USERS[i][1]
	if a == "unlock":
		if not u["lock"]:
			toast(n + " no estaba bloqueada")
			return
		u["lock"] = false
		bump(1, 1, "Cuenta de " + n + " desbloqueada")
		adv(10)
	elif a == "reset":
		if u["ex"]:
			bump(0, -6, "Restableciste la clave de un ex empleado: riesgo de acceso indebido")
		else:
			toast("Clave temporal enviada a " + n + " por canal verificado")
		adv(5)
	elif a == "off":
		u["off"] = true
		if u["ex"]:
			bump(0, 6, n + " deshabilitado")
		else:
			bump(-10, 0, "¡Deshabilitaste a un empleado activo!")
		adv(10)
	elif a == "on":
		u["off"] = false
		toast("Cuenta habilitada de nuevo")
		adv(5)
	for t in adt:
		if t["u"] == i and not t["done"] and ((t["k"] == "unlock" and not u["lock"]) or (t["k"] == "disable" and u["off"])):
			t["done"] = true
			earn += 20
			var all := true
			for x in adt:
				if not x["done"]:
					all = false
			if all:
				ach("ad")


# ====================================================================== correo ====
func mail_act(i: int, phish: bool) -> void:
	var x: Dictionary = mails[i]
	if x["a"] != null:
		return
	x["a"] = phish
	var real: bool = x["m"][3]
	if phish == real:
		bump(0, 3, "✔ Correcto")
		earn += 5
	elif real:
		bump(0, -8, "✘ Era phishing: un usuario podría hacer clic")
	else:
		bump(-3, 0, "✘ Era legítimo: bloqueaste un correo válido")
	adv(5)
	var all := true
	for y in mails:
		if y["a"] != y["m"][3]:
			all = false
	if all:
		ach("mail")


# ====================================================================== monitor ====
func mon_act(i: int, a: int) -> void:
	var e = null
	for x in ev:
		if x["d"] == i and x["fired"] and not x["done"]:
			e = x
	if e == null:
		return
	if a == int(Data.DEV[i][2]):
		e["done"] = true
		dev[i] = "ok"
		earn += 25
		bump(0, 5, "✔ " + Data.DEV[i][0] + " restablecido")
	else:
		bump(-3, 0, "Esa acción no resolvió el problema")
	adv(15)


func ev_block(i: int) -> void:
	var e: Dictionary = evl[i]
	if inv["done"]:
		return
	if e["ip"] == inv["ip"]:
		inv["done"] = true
		earn += 40
		bump(2, 10, "✔ IP atacante " + e["ip"] + " bloqueada; fuerza bruta detenida")
		ach("soc")
	else:
		bump(-10, -2, "Bloqueaste una IP interna legítima: " + e["ip"])
	adv(10)


func mfa_code(o: int) -> String:
	var w := int(Time.get_unix_time_from_system() / 15.0) - o
	return str(100000 + int(((w * 2654435761) & 0xFFFFFFFF) % 900000))


func mfa_try(v: String) -> void:
	if mfa >= 3:
		toast("No hay más inicios pendientes")
		return
	if v == mfa_code(0) or v == mfa_code(1):
		mfa += 1
		earn += 10
		bump(1, 3, "✔ Acceso verificado con MFA")
		adv(5)
	else:
		bump(0, -3, "✘ Código incorrecto o caducado")


# ======================================================================= BIOS ====
func bios_act(x: String, y: String) -> void:
	if bios.is_empty() or bios["done"]:
		return
	if x == "p":
		bios["page"] = y
	elif x == "t":
		var opts: Dictionary = {"boot": ["USB Drive", "Network", "SSD"], "sb": ["Disabled", "Enabled"], "tpm": ["Disabled", "Enabled"]}
		var o: Array = opts[y]
		bios["cfg"][y] = o[(o.find(bios["cfg"][y]) + 1) % o.size()]
	elif x == "s":
		if y == "1":
			var c: Dictionary = bios["cfg"]
			if c["boot"] == "SSD" and c["sb"] == "Enabled" and c["tpm"] == "Enabled":
				bios["done"] = true
				earn += 40
				bump(8, 8, "✔ La PC arrancó con Secure Boot y TPM activos")
				adv(20)
			else:
				bump(-3, 0, "La PC sigue sin arrancar: revisa Boot, Secure Boot y TPM")
				adv(10)
		else:
			bios["cfg"] = {"boot": "USB Drive", "sb": "Disabled", "tpm": "Disabled"}
			toast("Cambios descartados")


# ================================================================== progreso ====
func skill_up(k: String) -> void:
	var s: Array = []
	for x in Data.SK:
		if x[0] == k:
			s = x
	var v := sk(k)
	if s.is_empty() or v >= int(s[3]):
		return
	if int(G["sp"]) < v + 1:
		toast("Puntos insuficientes")
		return
	G["sp"] = int(G["sp"]) - (v + 1)
	G["sk"][k] = v + 1
	save()
	toast("⭐ %s nivel %d" % [s[1], v + 1])


func buy(k: String) -> void:
	var s: Array = []
	for x in Data.SHOP:
		if x[0] == k:
			s = x
	if s.is_empty() or ups().has(k):
		return
	if int(G["money"]) < int(s[3]):
		toast("Saldo insuficiente")
		return
	G["money"] = int(G["money"]) - int(s[3])
	ups()[k] = 1
	save()
	ach("shop")
	hud()
	toast("Compraste: " + s[1])


func apply_job(i: int) -> void:
	G["job"] = i
	save()
	hud()
	toast("¡Nuevo puesto: %s!" % Data.JB[i][0])


# ====================================================================== taller ====
func part_price(k: String) -> int:
	return int(round(float(Data.PARTS[k][1]) * (1.0 - 0.1 * sk("inv"))))


func comp_name(k: String) -> String:
	for c in Data.COMP:
		if c[0] == k:
			return c[1]
	return k


func tool_name(k: String) -> String:
	for t in Data.TOOLS:
		if t[0] == k:
			return t[1]
	return k


func bn_test(x: String) -> void:
	var o: Dictionary = rq[bn["o"]]
	if o["sel"] == null or o["fixed"]:
		return
	var f: Dictionary = Data.FAULTS[o["f"]]
	var ap = Data.TAP.get(x, null)
	var txt := ""
	var ok := true
	var r: Dictionary = f["r"]
	if x == "post" and o["sel"] == "mb":
		txt = ("⚠ " + r["post"]) if r.has("post") else Data.NORM["post"]
	elif ap != null and not ap.has(o["sel"]):
		txt = "Esta prueba no aplica a este componente."
		ok = false
	elif o["sel"] == f["c"] and r.has(x):
		txt = "⚠ " + r[x]
	else:
		txt = Data.NORM[x]
	o["log"].append(comp_name(o["sel"]) + " · " + tool_name(x) + ": " + txt)
	if ok:
		adv(0 if sk("diag") >= 2 else 2)


func bn_replace(x: String) -> void:
	var o: Dictionary = rq[bn["o"]]
	if o["sel"] == null or o["fixed"]:
		toast("Selecciona el componente a reemplazar")
		return
	if int(G["parts"].get(x, 0)) < 1:
		toast("No tienes esa pieza en stock")
		return
	G["parts"][x] = int(G["parts"][x]) - 1
	save()
	var f: Dictionary = Data.FAULTS[o["f"]]
	if o["sel"] == f["c"] and x == f["p"]:
		o["fixed"] = true
		rep += 1
		earn += 40 + sk("diag") * 5
		G["xp"] = int(G["xp"]) + 10
		bump(6, 2, "✔ Reparación completada: la PC de %s arrancó correctamente" % o["own"])
		ach("rep")
		adv(20)
	else:
		bump(-3, 0, "Esa pieza no resolvió el problema (se desperdició)")
		adv(10)


func bn_buy(x: String) -> void:
	if int(G["money"]) < part_price(x):
		toast("Saldo insuficiente")
		return
	G["money"] = int(G["money"]) - part_price(x)
	G["parts"][x] = int(G["parts"].get(x, 0)) + 1
	save()
	hud()
	toast("Compraste: " + Data.PARTS[x][0])


func bn_rma(x: String) -> void:
	if rma.has(x):
		toast("Ya pediste esa pieza hoy por garantía")
		return
	rma[x] = 1
	G["parts"][x] = int(G["parts"].get(x, 0)) + 1
	save()
	adv(40)
	toast("📦 Pieza por garantía recibida: " + Data.PARTS[x][0])
