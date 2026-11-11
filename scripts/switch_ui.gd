class_name SwitchUI
extends Control
## Consola del switch core Cisco Catalyst 2960 (data center).

signal closed

var out: RichTextLabel
var input: LineEdit
var prompt_lbl: Label
var goals_lbl: Label
var port_grid: GridContainer
var hist: Array = []
var hi := 0
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color("0b1118", 0.95)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 24)
	add_child(mc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIU.style(Color("16202b"), 10, UIU.TEAL, 2, 16))
	mc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var hb := HBoxContainer.new()
	v.add_child(hb)
	hb.add_child(UIU.label("Consola del switch core — Cisco Catalyst 2960", 22, Color.WHITE))
	hb.add_child(UIU.button("Salir (Esc)", close, Color.WHITE, Color("a63b2f"), Color("a63b2f"), 14, false))

	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", UIU.style(Color("101923"), 8, Color(0, 0, 0, 0), 0, 10))
	v.add_child(gp)
	goals_lbl = UIU.label("", 15, Color("dfe8f0"))
	gp.add_child(goals_lbl)

	port_grid = GridContainer.new()
	port_grid.columns = 13
	port_grid.add_theme_constant_override("h_separation", 4)
	port_grid.add_theme_constant_override("v_separation", 4)
	v.add_child(port_grid)

	out = RichTextLabel.new()
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.scroll_following = true
	out.selection_enabled = true
	out.add_theme_font_override("normal_font", UIU.mono_font())
	out.add_theme_font_size_override("normal_font_size", 14)
	out.add_theme_color_override("default_color", Color("cfe8d5"))
	out.add_theme_stylebox_override("normal", UIU.style(Color("05080c"), 6, Color(0, 0, 0, 0), 0, 10))
	v.add_child(out)

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIU.style(Color("05080c"), 6, Color(0, 0, 0, 0), 0, 8))
	v.add_child(row)
	var rh := HBoxContainer.new()
	row.add_child(rh)
	prompt_lbl = Label.new()
	prompt_lbl.add_theme_font_override("font", UIU.mono_font())
	prompt_lbl.add_theme_color_override("font_color", Color("cfe8d5"))
	rh.add_child(prompt_lbl)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.flat = true
	input.add_theme_font_override("font", UIU.mono_font())
	input.add_theme_color_override("font_color", Color.WHITE)
	input.caret_blink = true
	input.text_submitted.connect(_submit)
	input.gui_input.connect(_input_keys)
	rh.add_child(input)
	v.add_child(UIU.label("Rojo = puerto apagado · Azul = access en VLAN distinta de 1 · Verde = troncal. Toca un puerto para escribir «interface …». Flechas ↑/↓ = historial.", 12, Color(1, 1, 1, 0.55)))


func open() -> void:
	visible = true
	_closing = false
	var sw: IOSSim = Game.sw
	if sw.term == "":
		sw.say("Cisco IOS Software, C2960 Software (C2960-LANBASEK9-M), Version 15.0(2)SE4\nCatalyst 2960-24TT · Switch core del data center\nEscribe ? para ver los comandos disponibles.\n")
	_refresh()
	input.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _submit(v: String) -> void:
	var sw: IOSSim = Game.sw
	input.text = ""
	if not sw.pend and v.strip_edges() != "":
		hist.append(v)
	hi = hist.size()
	sw.exec(v)
	var r := sw.chk()
	_refresh()
	input.grab_focus()
	if r["close"] and not _closing:
		_closing = true
		get_tree().create_timer(1.8).timeout.connect(_auto_close)


func _auto_close() -> void:
	if not visible:
		return
	close()
	if Game.time >= Game.END:
		Game.finish()


func _input_keys(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_UP:
			hi = maxi(0, hi - 1)
			input.text = hist[hi] if hi < hist.size() else ""
			input.caret_column = input.text.length()
			input.accept_event()
		elif e.keycode == KEY_DOWN:
			hi = mini(hist.size(), hi + 1)
			input.text = hist[hi] if hi < hist.size() else ""
			input.caret_column = input.text.length()
			input.accept_event()


func _fill(key: String) -> void:
	input.text = "interface " + key.to_lower()
	input.grab_focus()
	input.caret_column = input.text.length()


func _refresh() -> void:
	var sw: IOSSim = Game.sw
	out.text = sw.term
	prompt_lbl.text = sw.prompt() + " "
	input.secret = sw.pend
	# objetivos
	if sw.ji >= sw.jobs.size():
		goals_lbl.text = "Mantenimiento completado."
	else:
		var J: Dictionary = sw.jobs[sw.ji]
		var ok := sw.goals_ok()
		var t := "Trabajo %d de 3: %s\n" % [sw.ji + 1, J["t"]]
		for i in J["g"].size():
			t += ("✔ " if ok[i] else "○ ") + J["g"][i]["text"] + "\n"
		t += "Pista: " + J["h"]
		goals_lbl.text = t
	# puertos
	UIU.clear(port_grid)
	for k in sw.pn:
		var p: Dictionary = sw.ports[k]
		var bg := Color("0a0f14")
		var bd := Color("3a4b5a")
		if p["shut"]:
			bg = Color("a63b2f")
			bd = Color("e8786a")
		elif p["mode"] == "trunk":
			bg = Color("4c9a6a")
			bd = Color("9fe0b4")
		elif p["vlan"] != 1:
			bg = Color("2a4fd0")
			bd = Color("7da0ff")
		var key: String = k
		var b := UIU.button(("G" + key.substr(key.length() - 1)) if key[0] == "G" else key.substr(3), _fill.bind(key), Color("9fb3c4") if bg == Color("0a0f14") else Color.WHITE, bg, bd, 12, false)
		b.custom_minimum_size = Vector2(40, 32)
		b.tooltip_text = sw.full_name(k)
		port_grid.add_child(b)
