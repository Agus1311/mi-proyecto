class_name DeskUI
extends Control
## Escritorio de TI: Zoho Desk (tickets), Active Directory, correo, monitor de red,
## visor de eventos (SOC), tablet MFA, empleos, tienda, habilidades y BIOS (en sitio).

signal closed

const TABS := [["t", "Tickets"], ["sk", "Habilidades"], ["ev", "Eventos"], ["ad", "Active Directory"],
	["mail", "Correo"], ["mon", "Monitor"], ["mfa", "Tablet"], ["jobs", "Empleos"], ["shop", "Tienda"], ["bios", "BIOS"]]
const SKILL_XP := 120

var tab := "t"
var sel := -1
var fb_ticket := -1
var fb: Dictionary = {}

var tab_btns: Dictionary = {}
var end_btn: Button
var body: MarginContainer
var tk_split: HSplitContainer
var list_box: VBoxContainer
var det_box: VBoxContainer
var app_box: VBoxContainer
var app_scroll: ScrollContainer
var mfa_code_lbl: Label
var mfa_sub_lbl: Label
var mfa_input: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.11, 0.08, 0.13, 0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 20)
	add_child(mc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIU.style(UIU.PAPER, 10, Color(0, 0, 0, 0), 0, 0))
	mc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	panel.add_child(vb)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIU.style(UIU.TEAL, 8, Color(0, 0, 0, 0), 0, 10))
	vb.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	bar.add_child(hb)
	var title := UIU.label("CAA Corp · Escritorio de TI", 17, Color.WHITE)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hb.add_child(title)
	var tabs_box := HFlowContainer.new()
	tabs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_box.add_theme_constant_override("h_separation", 6)
	tabs_box.add_theme_constant_override("v_separation", 4)
	hb.add_child(tabs_box)
	for t in TABS:
		var k: String = t[0]
		var b := UIU.button(t[1], func(): show_tab(k), Color.WHITE, Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.0), 14, false)
		tabs_box.add_child(b)
		tab_btns[k] = b
	end_btn = UIU.button("Terminar jornada", func(): Game.finish(), Color.WHITE, Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.0), 14, false)
	hb.add_child(end_btn)
	hb.add_child(UIU.button("Apagar pantalla (Esc)", close, Color.WHITE, Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.0), 14, false))

	body = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + s, 12)
	vb.add_child(body)

	tk_split = HSplitContainer.new()
	body.add_child(tk_split)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tk_split.add_child(left)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	left.add_child(list_box)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tk_split.add_child(right)
	det_box = VBoxContainer.new()
	det_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det_box.add_theme_constant_override("separation", 8)
	right.add_child(det_box)

	app_scroll = ScrollContainer.new()
	app_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(app_scroll)
	app_box = VBoxContainer.new()
	app_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_box.add_theme_constant_override("separation", 8)
	app_scroll.add_child(app_box)

	var tm := Timer.new()
	tm.wait_time = 1.0
	tm.autostart = true
	tm.timeout.connect(_mfa_tick)
	add_child(tm)


# ----------------------------------------------------------------- apertura ----
func open(onsite: int, ticket: int) -> void:
	visible = true
	end_btn.visible = onsite == 0
	for t in TABS:
		var k: String = t[0]
		tab_btns[k].visible = (k == "t" or k == "bios") if onsite != 0 else k != "bios"
	fb_ticket = -1
	sel = ticket if ticket >= 0 else Game.first_open()
	if ticket < 0 and onsite != 0 and int(Game.bios.get("loc", -1)) == onsite and not Game.bios["done"] and Game.first_open(onsite) < 0:
		show_tab("bios")
	else:
		show_tab("t")


func close() -> void:
	visible = false
	closed.emit()


func show_tab(k: String) -> void:
	tab = k
	for key in tab_btns:
		var b: Button = tab_btns[key]
		var on: bool = key == k
		b.add_theme_stylebox_override("normal", UIU.style(Color.WHITE if on else Color(1, 1, 1, 0.15), 8, Color(0, 0, 0, 0), 0, 10))
		b.add_theme_color_override("font_color", UIU.TEAL if on else Color.WHITE)
	tk_split.visible = k == "t"
	app_scroll.visible = k != "t"
	if k == "t":
		_draw_list()
		_draw_detail()
		return
	UIU.clear(app_box)
	match k:
		"sk": _draw_skills()
		"ev": _draw_events()
		"ad": _draw_ad()
		"mail": _draw_mail()
		"mon": _draw_mon()
		"mfa": _draw_mfa()
		"jobs": _draw_jobs()
		"shop": _draw_shop()
		"bios": _draw_bios()


func _act(tab_k: String, f: Callable) -> void:
	f.call()
	show_tab(tab_k)


func _head(t: String) -> void:
	app_box.add_child(UIU.label(t, 22))


# ----------------------------------------------------------------- tickets ----
func _draw_list() -> void:
	UIU.clear(list_box)
	for i in Game.tickets.size():
		var k: Dictionary = Game.tickets[i]
		var closed_t: bool = Game.tstate[i] != -1
		var loc := int(k["loc"])
		var suffix := " · Te buscará" if loc == 4 else (" · En sitio" if loc != 0 else "")
		var b := UIU.button("%s\n%s%s%s" % [k["t"], k["from"], suffix, Game.sla_text(i)], func(): _select(i), UIU.INK, Color(0.93, 0.83, 0.74) if sel == i else Color(1, 1, 1, 0.55), Color(0, 0, 0, 0), 15)
		var col := Color(String(Data.PRI[int(k["p"]) - 1]))
		var sbx := UIU.style(Color(0.93, 0.83, 0.74) if sel == i else Color(1, 1, 1, 0.55), 6, col, 0, 10)
		sbx.border_width_left = 7
		b.add_theme_stylebox_override("normal", sbx)
		var sbh := UIU.style(Color(0.92, 0.8, 0.7), 6, col, 0, 10)
		sbh.border_width_left = 7
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_color_override("font_hover_color", UIU.INK)
		b.add_theme_color_override("font_pressed_color", UIU.INK)
		if closed_t:
			b.modulate = Color(1, 1, 1, 0.45)
		list_box.add_child(b)


func _select(i: int) -> void:
	sel = i
	_draw_list()
	_draw_detail()


func _draw_detail() -> void:
	UIU.clear(det_box)
	if sel < 0:
		det_box.add_child(UIU.label("Selecciona un ticket", 22))
		det_box.add_child(UIU.label("Atiende cada caso eligiendo la mejor acción. Cada decisión consume tiempo y afecta la satisfacción de los usuarios y la seguridad de la empresa."))
		return
	var k: Dictionary = Game.tickets[sel]
	var open_t: bool = Game.tstate[sel] == -1
	det_box.add_child(UIU.label(k["t"], 22))
	if open_t or fb_ticket == sel:
		det_box.add_child(UIU.label("De: " + k["from"], 13, Color(UIU.INK, 0.7)))
		det_box.add_child(UIU.label(k["b"]))
	var loc := int(k["loc"])
	if open_t and loc != Game.onsite:
		var m := "Este caso se atiende desde tu escritorio."
		if loc == 4:
			m = "Este usuario vendrá a buscarte en persona. Recorre CAA Corp y atiéndelo cuando te encuentre."
		elif loc != 0:
			m = "Este caso requiere visita en sitio: ve al puesto de %s." % Game.STN[loc]["name"]
		det_box.add_child(UIU.label(m, 16))
		return
	if not open_t:
		if fb_ticket == sel:
			_draw_feedback()
		else:
			det_box.add_child(UIU.label("Ticket cerrado."))
		return
	for j in k["o"].size():
		det_box.add_child(UIU.button(k["o"][j][0], func(): _resolve(sel, j), UIU.INK, Color.WHITE, UIU.TEAL, 16))


func _resolve(i: int, j: int) -> void:
	fb = Game.resolve(i, j)
	fb_ticket = i
	_draw_list()
	_draw_detail()


func _draw_feedback() -> void:
	var c := UIU.card(det_box, Color(UIU.OKC, 0.25) if fb["good"] else Color(UIU.BADC, 0.25))
	c.add_child(UIU.label(fb["text"], 16))
	c.add_child(UIU.label("★".repeat(fb["stars"]) + "☆".repeat(5 - fb["stars"]) + "   Satisfacción %+d · Seguridad %+d" % [fb["sat"], fb["sec"]], 14))
	det_box.add_child(UIU.button("Siguiente ticket", _next, UIU.INK, UIU.WARM, UIU.WARM, 16, false))


func _next() -> void:
	_draw_list()
	var n := Game.first_open()
	if Game.time >= Game.END:
		Game.finish()
	elif n < 0:
		Game.toast("Tickets cerrados. Revisa AD, Correo y Monitor o termina la jornada.")
		if Game.onsite != 0:
			close()
		else:
			show_tab("ad")
	elif Game.onsite != 0:
		close()
	else:
		fb_ticket = -1
		_select(n)


# -------------------------------------------------------------- habilidades ----
func _draw_skills() -> void:
	var L := Game.lvl()
	var cur := (L - 1) * SKILL_XP
	_head("Habilidades")
	var c := UIU.card(app_box)
	c.add_child(UIU.label("Nivel %d · XP %d/%d · Puntos disponibles: %d" % [L, Game.G["xp"], L * SKILL_XP, Game.G["sp"]]))
	var pb := ProgressBar.new()
	pb.max_value = SKILL_XP
	pb.value = Game.G["xp"] - cur
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 14)
	c.add_child(pb)
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_box.add_child(g)
	for s in Data.SK:
		var key: String = s[0]
		var v := Game.sk(key)
		var cc := UIU.card(g)
		cc.add_child(UIU.label("%s %s" % [s[2], s[1]], 17))
		cc.add_child(UIU.label("●".repeat(v) + "○".repeat(int(s[3]) - v), 16))
		cc.add_child(UIU.label(s[4], 13, Color(UIU.INK, 0.7)))
		if v < int(s[3]):
			cc.add_child(UIU.button("Mejorar (%d pt)" % (v + 1), _act.bind("sk", Game.skill_up.bind(key)), UIU.INK, Color.WHITE, UIU.TEAL, 14, false))
		else:
			cc.add_child(UIU.label("Máximo", 14, UIU.OKC))


# ------------------------------------------------------------------ eventos ----
func _draw_events() -> void:
	_head("Visor de eventos — Registro de seguridad")
	var done_i: bool = Game.inv["done"]
	var c := UIU.card(app_box, Color(1, 1, 1, 0.6))
	c.add_child(UIU.label("✔ Ataque contenido: IP bloqueada en el firewall." if done_i else "⚠ Alerta del SIEM: intentos de inicio de sesión fallidos fuera de horario. Identifica la IP responsable y bloquéala."))
	if Game.sk("logs") == 1 and not done_i:
		c.add_child(UIU.label("🔎 Pista: busca fallos seguidos de un acceso correcto desde una misma IP externa."))
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 14)
	app_box.add_child(g)
	for h in ["Hora", "Nivel", "Id", "Usuario", "IP origen", ""]:
		g.add_child(UIU.label(h, 14, Color(UIU.INK, 0.6)))
	for i in Game.evl.size():
		var e: Dictionary = Game.evl[i]
		var hot: bool = Game.sk("logs") > 1 and e["ip"] == Game.inv["ip"]
		var col := Color("a8641a") if hot else UIU.INK
		for v in [e["t"], e["lv"], str(e["id"]), e["u"], e["ip"]]:
			var l := UIU.label(v, 14, col)
			l.size_flags_horizontal = Control.SIZE_FILL
			g.add_child(l)
		if done_i:
			g.add_child(Control.new())
		else:
			g.add_child(UIU.button("Bloquear IP", _act.bind("ev", Game.ev_block.bind(i)), UIU.INK, Color.WHITE, UIU.TEAL, 13, false))


# ------------------------------------------------------------ Active Directory ----
func _draw_ad() -> void:
	_head("Active Directory — Usuarios y equipos")
	var c := UIU.card(app_box, Color(1, 1, 1, 0.6))
	for t in Game.adt:
		c.add_child(UIU.label(("✔ " if t["done"] else "○ ") + t["txt"], 15))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 8)
	app_box.add_child(g)
	for h in ["Usuario", "Departamento", "Estado", ""]:
		g.add_child(UIU.label(h, 14, Color(UIU.INK, 0.6)))
	for i in Data.USERS.size():
		var u: Array = Data.USERS[i]
		var s: Dictionary = Game.ad[i]
		g.add_child(UIU.label("%s  (%s)" % [u[1], u[0]], 14))
		g.add_child(UIU.label(u[2], 14))
		var st_t := "Deshabilitada" if s["off"] else ("🔒 Bloqueada" if s["lock"] else "Activa")
		if s["ex"]:
			st_t += "\nBaja reportada por RRHH"
		g.add_child(UIU.label(st_t, 14))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		g.add_child(hb)
		var toggle: String = "on" if s["off"] else "off"
		hb.add_child(UIU.button("Desbloquear", _act.bind("ad", Game.ad_act.bind(i, "unlock")), UIU.INK, Color.WHITE, UIU.TEAL, 13, false))
		hb.add_child(UIU.button("Restablecer clave", _act.bind("ad", Game.ad_act.bind(i, "reset")), UIU.INK, Color.WHITE, UIU.TEAL, 13, false))
		hb.add_child(UIU.button("Habilitar" if s["off"] else "Deshabilitar", _act.bind("ad", Game.ad_act.bind(i, toggle)), UIU.INK, Color.WHITE, UIU.TEAL, 13, false))


# -------------------------------------------------------------------- correo ----
func _draw_mail() -> void:
	_head("Bandeja de entrada")
	for i in Game.mails.size():
		var x: Dictionary = Game.mails[i]
		var m: Array = x["m"]
		var c := UIU.card(app_box)
		c.add_child(UIU.label(m[1], 17))
		c.add_child(UIU.label("De: " + m[0], 13, Color(UIU.INK, 0.7)))
		if Game.sk("phish") > 0 and m[3] and x["a"] == null:
			c.add_child(UIU.label("🔎 " + ("Señales de phishing detectadas" if Game.sk("phish") > 1 else "Algo no cuadra con este remitente"), 13, Color(UIU.INK, 0.7)))
		c.add_child(UIU.label(m[2]))
		if x["a"] == null:
			var hb := HBoxContainer.new()
			c.add_child(hb)
			hb.add_child(UIU.button("Es legítimo", _act.bind("mail", Game.mail_act.bind(i, false)), UIU.INK, Color.WHITE, UIU.TEAL, 14, false))
			hb.add_child(UIU.button("Es phishing", _act.bind("mail", Game.mail_act.bind(i, true)), UIU.INK, Color.WHITE, UIU.TEAL, 14, false))
		else:
			c.add_child(UIU.label("%s: %s %s" % ["Phishing" if m[3] else "Legítimo", m[4], "✔" if x["a"] == m[3] else "✘"], 14, UIU.OKC if x["a"] == m[3] else UIU.BADC))


# ------------------------------------------------------------------- monitor ----
func _draw_mon() -> void:
	_head("Monitor de red")
	var g := GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_box.add_child(g)
	for i in Data.DEV.size():
		var d: Array = Data.DEV[i]
		var down: bool = Game.dev[i] == "down"
		var c := UIU.card(g, Color("f7d6d0") if down else Color.WHITE)
		c.add_child(UIU.label(d[0], 17))
		c.add_child(UIU.label("● CAÍDO" if down else "● En línea", 15, UIU.BADC if down else UIU.OKC))
		if down:
			c.add_child(UIU.label(d[1], 13, Color(UIU.INK, 0.7)))
			for k in Data.MA.size():
				c.add_child(UIU.button(Data.MA[k], _act.bind("mon", Game.mon_act.bind(i, k)), UIU.INK, Color.WHITE, UIU.TEAL, 14, false))


# ----------------------------------------------------------------------- MFA ----
func _draw_mfa() -> void:
	_head("Tablet · Authenticator")
	var c := UIU.card(app_box, Color("3a3f9a"))
	c.add_child(UIU.label("Administrador VPN · caacorp.com", 13, Color.WHITE))
	mfa_code_lbl = UIU.label(Game.mfa_code(0), 38, Color.WHITE)
	c.add_child(mfa_code_lbl)
	mfa_sub_lbl = UIU.label("", 13, Color.WHITE)
	c.add_child(mfa_sub_lbl)
	_head("Portal VPN — acceso de administrador")
	app_box.add_child(UIU.label("Inicios pendientes: %d. Ingresa el código de 6 dígitos de la tablet." % (3 - Game.mfa)))
	var hb := HBoxContainer.new()
	app_box.add_child(hb)
	mfa_input = LineEdit.new()
	mfa_input.max_length = 6
	mfa_input.placeholder_text = "123456"
	mfa_input.custom_minimum_size = Vector2(160, 0)
	mfa_input.text_submitted.connect(func(_t): _mfa_submit())
	hb.add_child(mfa_input)
	hb.add_child(UIU.button("Verificar", _mfa_submit, UIU.INK, Color.WHITE, UIU.TEAL, 15, false))
	_mfa_tick()


func _mfa_submit() -> void:
	Game.mfa_try(mfa_input.text.strip_edges())
	show_tab("mfa")


func _mfa_tick() -> void:
	if not visible or tab != "mfa" or mfa_code_lbl == null or not is_instance_valid(mfa_code_lbl):
		return
	mfa_code_lbl.text = Game.mfa_code(0)
	mfa_sub_lbl.text = "Caduca en %d s" % (15 - int(Time.get_unix_time_from_system()) % 15)


# -------------------------------------------------------------- empleos / tienda ----
func _draw_jobs() -> void:
	_head("Bolsa de empleo")
	app_box.add_child(UIU.label("Rango actual: %s · Puesto: %s (sueldo x%s)" % [Game.rank(), Data.JB[Game.G["job"]][0], Data.JB[Game.G["job"]][3]]))
	for i in Data.JB.size():
		var j: Array = Data.JB[i]
		var c := UIU.card(app_box)
		c.add_child(UIU.label("%s — %s" % [j[0], j[1]], 17))
		c.add_child(UIU.label("Requiere rango: %s · Sueldo x%s" % [Data.RANKS[int(j[2])], j[3]], 13, Color(UIU.INK, 0.7)))
		if int(Game.G["job"]) == i:
			c.add_child(UIU.label("Puesto actual ✔", 14, UIU.OKC))
		elif Game.ri() >= int(j[2]):
			c.add_child(UIU.button("Aplicar", _act.bind("jobs", Game.apply_job.bind(i)), UIU.INK, Color.WHITE, UIU.TEAL, 14, false))
		else:
			c.add_child(UIU.label("Rango insuficiente", 14, UIU.BADC))


func _draw_shop() -> void:
	_head("Tienda de TI")
	app_box.add_child(UIU.label("Saldo: $%d · cobras al terminar cada jornada." % Game.G["money"]))
	for s in Data.SHOP:
		var key: String = s[0]
		var c := UIU.card(app_box)
		c.add_child(UIU.label("%s — $%d" % [s[1], s[3]], 17))
		c.add_child(UIU.label(s[2], 14))
		if Game.ups().has(key):
			c.add_child(UIU.label("Comprado ✔", 14, UIU.OKC))
		else:
			c.add_child(UIU.button("Comprar", _act.bind("shop", Game.buy.bind(key)), UIU.INK, Color.WHITE, UIU.TEAL, 14, false))


# ---------------------------------------------------------------------- BIOS ----
func _draw_bios() -> void:
	var b: Dictionary = Game.bios
	if b.is_empty() or int(b["loc"]) != Game.onsite:
		_head("BIOS")
		app_box.add_child(UIU.label("Esta estación no reporta problemas de arranque."))
		return
	if b["done"]:
		_head("BIOS")
		app_box.add_child(UIU.label("La PC arrancó correctamente. ✔"))
		return
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", UIU.style(Color("0a1a8f"), 0, Color("c0c0c0"), 2, 0))
	pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_box.add_child(pan)
	var v := VBoxContainer.new()
	pan.add_child(v)
	var menu := HBoxContainer.new()
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UIU.style(Color("0a7ab0"), 0, Color(0, 0, 0, 0), 0, 0))
	mp.add_child(menu)
	v.add_child(mp)
	var white := Color("e8e8e8")
	for p in ["Main", "Advanced", "Security", "Boot", "Exit"]:
		var pg: String = p
		var on: bool = b["page"] == pg
		menu.add_child(UIU.button(pg, _act.bind("bios", Game.bios_act.bind("p", pg)), Color.BLACK if on else Color.WHITE, Color("c0c0c0") if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 15, false))
	var inner := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + s, 14)
	v.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	inner.add_child(col)
	var c: Dictionary = b["cfg"]
	match b["page"]:
		"Main":
			col.add_child(UIU.label("Sistema: equipo de usuario\nBIOS: v1.4.2\nEstado: no arranca el sistema operativo", 16, white))
			col.add_child(UIU.label("Objetivo: Secure Boot y TPM habilitados y SSD como primer dispositivo de arranque. Guarda y sal (Exit).", 16, white))
		"Advanced":
			col.add_child(UIU.label("CPU Configuration\nSATA Configuration\nUSB Configuration\nNetwork Stack Configuration", 16, white))
		"Security":
			_bios_row(col, "Secure Boot", c["sb"], "sb")
			_bios_row(col, "TPM Device", c["tpm"], "tpm")
		"Boot":
			_bios_row(col, "Boot Option #1", c["boot"], "boot")
		_:
			col.add_child(UIU.button("Save Changes and Exit", _act.bind("bios", Game.bios_act.bind("s", "1")), Color.WHITE, Color(0, 0, 0, 0), Color("c0c0c0"), 15, false))
			col.add_child(UIU.button("Discard Changes and Exit", _act.bind("bios", Game.bios_act.bind("s", "0")), Color.WHITE, Color(0, 0, 0, 0), Color("c0c0c0"), 15, false))


func _bios_row(parent: Node, label_t: String, value: String, key: String) -> void:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	hb.add_child(UIU.label(label_t, 16, Color("e8e8e8")))
	hb.add_child(UIU.button(value, _act.bind("bios", Game.bios_act.bind("t", key)), Color.WHITE, Color(0, 0, 0, 0), Color("c0c0c0"), 15, false))
