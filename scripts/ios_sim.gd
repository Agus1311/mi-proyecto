class_name IOSSim
extends RefCounted
## Simulador del switch Cisco Catalyst 2960 del data center.
## Port 1:1 de la consola IOS del prototipo HTML (modos user/priv/config/vlan/if),
## con los 3 trabajos de mantenimiento diarios.

const BAD := "% Invalid input detected at '^' marker."
const INC := "% Incomplete command."

var host := "Switch"
var secret := ""
var vlans: Dictionary = {1: "default"}
var ports: Dictionary = {}
var svi: Dictionary = {}
var pn: Array = []

var startup_snap: Dictionary = {}
var startup_str := ""
var wrote := false

var cm := "user"
var ctx_vlan := 0
var ctx_if: Array = []
var pend := false

var jobs: Array = []
var ji := 0
var term := ""


func _init() -> void:
	for i in range(1, 25):
		pn.append("Fa0/%d" % i)
	pn.append("Gi0/1")
	pn.append("Gi0/2")
	reset(1)


func _default_ports() -> Dictionary:
	var p := {}
	for k in pn:
		p[k] = {"mode": "access", "vlan": 1, "shut": false, "desc": ""}
	return p


func reset(day: int) -> void:
	host = "Switch"
	secret = ""
	vlans = {1: "default"}
	svi = {}
	ports = _default_ports()
	startup_snap = snapshot()
	startup_str = cfg_str()
	wrote = false
	cm = "user"
	ctx_if = []
	ctx_vlan = 0
	pend = false
	ji = 0
	jobs = mk_jobs(day)
	term = ""


# ---------------------------------------------------------------- estado ----
func snapshot() -> Dictionary:
	return {"h": host, "s": secret, "v": vlans.duplicate(true), "p": ports.duplicate(true), "i": svi.duplicate(true)}


func cfg_str() -> String:
	return JSON.stringify(snapshot(), "", true)


func saved() -> bool:
	return wrote and startup_str == cfg_str()


func restore() -> void:
	var o := startup_snap.duplicate(true)
	host = o["h"]
	secret = o["s"]
	vlans = o["v"]
	ports = o["p"]
	svi = o["i"]


func wr() -> String:
	startup_snap = snapshot()
	startup_str = cfg_str()
	wrote = true
	return "Building configuration...\n[OK]"


func P(k: String) -> Dictionary:
	if k[0] == "V":
		return svi[int(k.substr(1))]
	return ports[k]


func full_name(k: String) -> String:
	return ("FastEthernet" if k[0] == "F" else "GigabitEthernet") + k.substr(2)


func vname(n: int) -> String:
	return "VLAN" + str(n).pad_zeros(4)


func prompt() -> String:
	if pend:
		return "Password:"
	var s := host
	match cm:
		"user": s += ">"
		"priv": s += "#"
		"cfg": s += "(config)#"
		"vlan": s += "(config-vlan)#"
		"if": s += "(config-if-range)#" if ctx_if.size() > 1 else "(config-if)#"
	return s


func say(t: String) -> void:
	term += t + "\n"


func pd(x, n: int) -> String:
	return str(x).rpad(n)


func to_n(s: String) -> int:
	return int(s) if s.is_valid_int() else 0


func ipok(x: String) -> bool:
	var re := RegEx.create_from_string("^(\\d{1,3}\\.){3}\\d{1,3}$")
	if re.search(x) == null:
		return false
	for p in x.split("."):
		if int(p) > 255:
			return false
	return true


## Coincidencia de abreviaturas: devuelve el comando, "?" si es ambiguo, "" si no existe.
func pick(w: String, l: Array) -> String:
	if w == "":
		return ""
	w = w.to_lower()
	if l.has(w):
		return w
	var m: Array = []
	for x in l:
		if String(x).begins_with(w):
			m.append(x)
	if m.size() == 1:
		return m[0]
	if m.size() > 1:
		return "?"
	return ""


func arg(a: Array, i: int) -> String:
	return a[i] if i < a.size() else ""


func hit(a: int, b: int, m: String) -> String:
	Game.sat = maxi(0, Game.sat + a)
	Game.sec = maxi(0, Game.sec + b)
	Game.hud()
	return m


# --------------------------------------------------------- parseo de if ----
## Devuelve la lista de interfaces o [] si la sintaxis es inválida.
func parse_if(a: Array) -> Array:
	var s := "".join(PackedStringArray(a)).to_lower()
	var r: Array = []
	var re := RegEx.create_from_string("^range(?:f|fa|fastethernet)0/(\\d+)-(?:(?:f|fa|fastethernet)0/)?(\\d+)$")
	var m := re.search(s)
	if m:
		for n in range(int(m.get_string(1)), int(m.get_string(2)) + 1):
			if not ports.has("Fa0/%d" % n):
				return []
			r.append("Fa0/%d" % n)
		return r
	re = RegEx.create_from_string("^(?:f|fa|fastethernet)0/(\\d+)$")
	m = re.search(s)
	if m:
		if not ports.has("Fa0/" + m.get_string(1)):
			return []
		return ["Fa0/" + m.get_string(1)]
	re = RegEx.create_from_string("^(?:g|gi|gigabitethernet)0/(\\d+)$")
	m = re.search(s)
	if m:
		if not ports.has("Gi0/" + m.get_string(1)):
			return []
		return ["Gi0/" + m.get_string(1)]
	re = RegEx.create_from_string("^vlan(\\d+)$")
	m = re.search(s)
	if m:
		var n := int(m.get_string(1))
		if n < 1 or n > 4094:
			return []
		if not svi.has(n):
			svi[n] = {"ip": "", "mask": "", "shut": true}
		return ["V%d" % n]
	return []


# ------------------------------------------------------------- show/run ----
func run_cfg() -> String:
	var t := "Building configuration...\n\nCurrent configuration : %d bytes\n!\nversion 15.0\n!\nhostname %s\n!\n" % [cfg_str().length(), host]
	if secret != "":
		t += "enable secret 5 $1$mERr$hx5rVt7rPNoS4wqbXKX7m0\n!\n"
	var vk := vlans.keys()
	vk.sort()
	for n in vk:
		if n != 1:
			t += "vlan %d\n name %s\n!\n" % [n, vlans[n]]
	for k in pn:
		var p: Dictionary = ports[k]
		t += "interface %s\n" % full_name(k)
		if p["desc"] != "":
			t += " description %s\n" % p["desc"]
		if p["mode"] == "trunk":
			t += " switchport mode trunk\n"
		elif p["vlan"] != 1:
			t += " switchport access vlan %d\n switchport mode access\n" % p["vlan"]
		if p["shut"]:
			t += " shutdown\n"
		t += "!\n"
	var sk_ := svi.keys()
	sk_.sort()
	for n in sk_:
		var v: Dictionary = svi[n]
		t += "interface Vlan%d\n %s\n%s!\n" % [n, ("ip address %s %s" % [v["ip"], v["mask"]]) if v["ip"] != "" else "no ip address", " shutdown\n" if v["shut"] else ""]
	return t + "end"


func sh(a: Array, priv: bool) -> String:
	var w := pick(arg(a, 0), ["running-config", "vlan", "ip", "version", "interfaces"])
	if w == "" or w == "?":
		return BAD
	if w == "running-config":
		if not priv:
			return BAD
		return run_cfg()
	elif w == "vlan":
		var t := "VLAN Name                             Status    Ports\n---- -------------------------------- --------- -------------------------------\n"
		var ks := vlans.keys()
		ks.sort()
		for n in ks:
			var pl: Array = []
			for k in pn:
				if ports[k]["mode"] == "access" and ports[k]["vlan"] == n:
					pl.append(k)
			t += pd(n, 5) + pd(vlans[n], 33) + pd("active", 10) + ", ".join(PackedStringArray(pl)) + "\n"
		return t
	elif w == "ip":
		if pick(arg(a, 1), ["interface"]) != "interface":
			return BAD
		var t := "Interface              IP-Address      OK? Method Status                Protocol\n"
		for k in pn:
			var p: Dictionary = ports[k]
			t += pd(full_name(k), 23) + pd("unassigned", 16) + "YES unset  " + ((pd("administratively down", 22) + "down") if p["shut"] else (pd("up", 22) + "up")) + "\n"
		var ks := svi.keys()
		ks.sort()
		for n in ks:
			var v: Dictionary = svi[n]
			t += pd("Vlan%d" % n, 23) + pd(v["ip"] if v["ip"] != "" else "unassigned", 16) + "YES " + ("manual " if v["ip"] != "" else "unset  ") + ((pd("administratively down", 22) + "down") if v["shut"] else (pd("up", 22) + "up")) + "\n"
		return t
	elif w == "interfaces":
		var t := "Port      Name               Status       Vlan       Duplex  Speed Type\n"
		for k in pn:
			var p: Dictionary = ports[k]
			t += pd(k, 10) + pd(String(p["desc"]).substr(0, 18), 19) + pd("disabled" if p["shut"] else "connected", 13) + pd("trunk" if p["mode"] == "trunk" else p["vlan"], 11) + "a-full  a-100 10/100BaseTX\n"
		return t
	return "Cisco IOS Software, C2960 Software (C2960-LANBASEK9-M), Version 15.0(2)SE4\n%s uptime is 2 hours, 14 minutes" % host


# ---------------------------------------------------------- comandos -------
func cmds(mode: String) -> Array:
	var cfg_l := ["hostname", "vlan", "interface", "enable", "no", "do", "exit", "end"]
	match mode:
		"user": return ["enable", "show", "exit"]
		"priv": return ["disable", "exit", "show", "write", "configure", "copy", "erase", "reload"]
		"cfg": return cfg_l
		"vlan": return cfg_l + ["name"]
		"if": return cfg_l + ["shutdown", "description", "switchport", "ip"]
	return []


func _c_user(c: String, a: Array) -> String:
	match c:
		"enable":
			if secret != "":
				pend = true
				return "Password:"
			cm = "priv"
		"show":
			return sh(a, false)
		"exit":
			pass
	return ""


func _c_priv(c: String, a: Array) -> String:
	match c:
		"disable", "exit":
			cm = "user"
		"show":
			return sh(a, true)
		"write":
			return wr()
		"configure":
			if a.size() > 0 and not "terminal".begins_with(a[0]):
				return BAD
			cm = "cfg"
			return "Enter configuration commands, one per line.  End with CNTL/Z."
		"copy":
			if a.size() < 2:
				return INC
			return wr()
		"erase":
			if a.size() == 0:
				return INC
			var d := {"h": "Switch", "s": "", "v": {1: "default"}, "p": _default_ports(), "i": {}}
			startup_snap = d
			startup_str = JSON.stringify(d, "", true)
			wrote = false
			return hit(-15, -8, "[OK] Erase of nvram: complete\n¡Borraste la configuración de arranque! Al reiniciar se perderá todo.")
		"reload":
			var lost := cfg_str() != startup_str
			restore()
			cm = "user"
			say("Reloading...\n")
			if lost:
				return hit(-4, 0, "La configuración sin guardar se perdió. Usa write memory antes de reiniciar.")
	return ""


func _c_cfg(c: String, a: Array) -> String:
	match c:
		"hostname":
			if a.size() == 0:
				return INC
			host = a[0]
		"vlan":
			var n := to_n(arg(a, 0))
			if n < 1 or n > 4094:
				return BAD
			if not vlans.has(n):
				vlans[n] = vname(n)
			cm = "vlan"
			ctx_vlan = n
		"interface":
			var r := parse_if(a)
			if r.is_empty():
				return BAD
			ctx_if = r
			cm = "if"
		"enable":
			if pick(arg(a, 0), ["secret"]) != "secret":
				return BAD
			if a.size() < 2:
				return INC
			secret = " ".join(PackedStringArray(a.slice(1)))
		"no":
			if pick(arg(a, 0), ["vlan"]) != "vlan":
				return BAD
			var n := to_n(arg(a, 1))
			if n == 1:
				return "% Default VLAN 1 may not be deleted."
			vlans.erase(n)
		"do":
			var w := pick(arg(a, 0), ["show", "write", "copy"])
			if w == "" or w == "?":
				return BAD
			return _c_priv(w, a.slice(1))
		"exit", "end":
			cm = "priv"
	return ""


func _c_vlan(c: String, a: Array) -> String:
	match c:
		"name":
			if a.size() == 0:
				return INC
			vlans[ctx_vlan] = "_".join(PackedStringArray(a))
		"exit":
			cm = "cfg"
		"end":
			cm = "priv"
		_:
			return _c_cfg(c, a)
	return ""


func _c_if(c: String, a: Array) -> String:
	match c:
		"shutdown":
			for k in ctx_if:
				P(k)["shut"] = true
		"no":
			var w := pick(arg(a, 0), ["shutdown", "description"])
			if w == "" or w == "?":
				return BAD
			for k in ctx_if:
				if w == "shutdown":
					P(k)["shut"] = false
				else:
					P(k)["desc"] = ""
		"description":
			if a.size() == 0:
				return INC
			for k in ctx_if:
				P(k)["desc"] = " ".join(PackedStringArray(a))
		"switchport":
			for k in ctx_if:
				if k[0] == "V":
					return BAD
			var w := pick(arg(a, 0), ["mode", "access"])
			if w == "mode":
				var m := pick(arg(a, 1), ["access", "trunk"])
				if m == "" or m == "?":
					return BAD
				for k in ctx_if:
					P(k)["mode"] = m
			elif w == "access":
				if pick(arg(a, 1), ["vlan"]) != "vlan":
					return BAD
				var n := to_n(arg(a, 2))
				if n < 1 or n > 4094:
					return BAD
				var msg := ""
				if not vlans.has(n):
					vlans[n] = vname(n)
					msg = "% Access VLAN does not exist. Creating vlan " + str(n)
				for k in ctx_if:
					P(k)["vlan"] = n
					P(k)["mode"] = "access"
				return msg
			else:
				return BAD
		"ip":
			if not String(ctx_if[0]).begins_with("V"):
				return BAD
			if pick(arg(a, 0), ["address"]) != "address":
				return BAD
			if not ipok(arg(a, 1)) or not ipok(arg(a, 2)):
				return BAD
			P(ctx_if[0])["ip"] = a[1]
			P(ctx_if[0])["mask"] = a[2]
		"exit":
			cm = "cfg"
		"end":
			cm = "priv"
		_:
			return _c_cfg(c, a)
	return ""


func dispatch(c: String, a: Array) -> String:
	match cm:
		"user": return _c_user(c, a)
		"priv": return _c_priv(c, a)
		"cfg": return _c_cfg(c, a)
		"vlan": return _c_vlan(c, a)
		"if": return _c_if(c, a)
	return ""


func exec(line: String) -> void:
	if pend:
		pend = false
		say("")
		if line == secret:
			cm = "priv"
		else:
			say("% Bad secrets")
		return
	say(prompt() + " " + line)
	var t: Array = []
	for p in line.replace("\t", " ").strip_edges().split(" ", false):
		t.append(p)
	if t.is_empty():
		return
	var tb := cmds(cm)
	if t[0] == "?" or t[t.size() - 1] == "?":
		say("  ".join(PackedStringArray(tb)))
		return
	var c := pick(t[0], tb)
	if c == "?":
		say('% Ambiguous command:  "%s"' % line.strip_edges())
		return
	if c == "":
		say(BAD)
		return
	var r := dispatch(c, t.slice(1))
	if r != "":
		say(r)


# ---------------------------------------------------------------- trabajos ----
func mk_jobs(d: int) -> Array:
	var V: int = 20 if d < 2 else [30, 40, 50, 60, 70, 80][randi() % 6]
	var N: String = "VENTAS" if d < 2 else ["RRHH", "TI", "VOZ", "CCTV", "INVITADOS", "ALMACEN"][randi() % 6]
	var port: int = 5 if d < 2 else 2 + randi() % 16
	var H: String = "DC-SW1" if d < 2 else "SUC%d-SW1" % d
	var a: int = 20 if d < 2 else 6 + randi() % 10
	var b: int = a + (4 if d < 2 else 3)
	var g: int = 99 if d < 2 else [99, 88, 77][randi() % 3]
	var ip := "192.168.%d.2" % g
	return [
		{"t": "Segmentar la red de %s" % N, "s": 8,
		 "h": "vlan %d → name %s · interface fa0/%d → switchport mode access → switchport access vlan %d · write memory" % [V, N, port, V],
		 "g": [
			{"k": "vlan_name", "v": V, "n": N, "text": "Crear la VLAN %d con el nombre %s" % [V, N]},
			{"k": "port", "port": port, "v": V, "text": "Fa0/%d en modo access dentro de la VLAN %d" % [port, V]},
			{"k": "saved", "text": "Guardar la configuración en NVRAM"}]},
		{"t": "Endurecer el switch", "s": 12,
		 "h": "configure terminal → hostname %s · enable secret <clave> · interface range fa0/%d - %d → shutdown · write memory" % [H, a, b],
		 "g": [
			{"k": "host", "h": H, "text": "Cambiar el hostname a %s" % H},
			{"k": "secret", "text": "Definir una clave con enable secret"},
			{"k": "shut", "a": a, "b": b, "text": "Apagar los puertos sin uso Fa0/%d a Fa0/%d" % [a, b]},
			{"k": "saved", "text": "Guardar la configuración"}]},
		{"t": "Troncal y gestión", "s": 8,
		 "h": "interface gi0/1 → switchport mode trunk · interface vlan %d → ip address %s 255.255.255.0 → no shutdown · write memory" % [g, ip],
		 "g": [
			{"k": "trunk", "text": "Gi0/1 como troncal (trunk)"},
			{"k": "svi", "g": g, "ip": ip, "text": "Interfaz VLAN %d con IP %s/24 activa" % [g, ip]},
			{"k": "saved", "text": "Guardar la configuración"}]},
	]


func goal_ok(g: Dictionary) -> bool:
	match g["k"]:
		"vlan_name":
			return vlans.get(g["v"], null) == g["n"]
		"port":
			var p: Dictionary = ports["Fa0/%d" % g["port"]]
			return p["mode"] == "access" and p["vlan"] == g["v"]
		"saved":
			return saved()
		"host":
			return host == g["h"]
		"secret":
			return secret != ""
		"shut":
			for n in range(g["a"], g["b"] + 1):
				if not ports["Fa0/%d" % n]["shut"]:
					return false
			return true
		"trunk":
			return ports["Gi0/1"]["mode"] == "trunk"
		"svi":
			var v = svi.get(g["g"], null)
			return v != null and v["ip"] == g["ip"] and v["mask"] == "255.255.255.0" and not v["shut"]
	return false


func goals_ok() -> Array:
	var r: Array = []
	if ji < jobs.size():
		for g in jobs[ji]["g"]:
			r.append(goal_ok(g))
	return r


## Comprueba el trabajo actual tras cada comando. Devuelve {"close": bool} si debe cerrarse la consola.
func chk() -> Dictionary:
	if ji >= jobs.size():
		return {"close": false}
	var ok := goals_ok()
	if ok.has(false):
		return {"close": false}
	var J: Dictionary = jobs[ji]
	ji += 1
	Game.net += 1
	Game.earn += 40
	if Game.net >= 3:
		Game.ach("cli")
	Game.time += maxi(8, (15 if Game.ups().has("ccna") else 25) - Game.sk("cli") * 3)
	Game.sat = mini(100, Game.sat + 8)
	Game.sec = mini(100, Game.sec + int(J["s"]))
	wrote = false
	Game.hud()
	say("\n*** Trabajo completado: " + J["t"] + " ***")
	if ji >= 3:
		say("Mantenimiento del data center terminado. Cerrando consola...")
	else:
		say("Siguiente trabajo: " + jobs[ji]["t"])
	return {"close": ji >= 3 or Game.time >= Game.END}
