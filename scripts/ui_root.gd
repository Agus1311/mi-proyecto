extends CanvasLayer
## Interfaz 2D: HUD, avisos, llamadas, fin de jornada y ventanas (escritorio, consola, taller).

signal home_requested

var desk: DeskUI
var switch_ui: SwitchUI
var bench: BenchUI

var clock_l: Label
var s1: Label
var s2: Label
var s3: Label
var s4: Label
var place_l: Label
var prompt_p: PanelContainer
var prompt_l: Label
var toast_p: PanelContainer
var toast_l: Label
var toast_timer: Timer
var call_p: Control
var call_name: Label
var call_text: Label
var call_box: VBoxContainer
var call_idx := -1
var end_p: Control
var end_title: Label
var end_text: Label
var end_ach: Label
var reset_btn: Button
var hud_root: Control


func _ready() -> void:
	layer = 10
	var th := Theme.new()
	th.default_font_size = 16
	hud_root = Control.new()
	hud_root.theme = th
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	_build_hud()
	desk = DeskUI.new()
	desk.closed.connect(_modal_closed)
	hud_root.add_child(desk)
	switch_ui = SwitchUI.new()
	switch_ui.closed.connect(_modal_closed)
	hud_root.add_child(switch_ui)
	bench = BenchUI.new()
	bench.closed.connect(_modal_closed)
	hud_root.add_child(bench)
	_build_call()
	_build_end()
	Game.changed.connect(_refresh)
	Game.toast_msg.connect(_toast)
	Game.call_started.connect(_on_call)
	Game.day_finished.connect(_on_day_finished)
	_refresh()


# ------------------------------------------------------------------- HUD ----
func _pill(parent: Node, bg: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIU.style(bg, 999, Color(0, 0, 0, 0), 0, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return l


func _build_hud() -> void:
	var top := HFlowContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_top = 12
	top.offset_right = -14
	top.add_theme_constant_override("h_separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(top)
	clock_l = _pill(top, Color("2f6f8f", 0.8))
	s1 = _pill(top, Color(0, 0, 0, 0.4))
	s2 = _pill(top, Color(0, 0, 0, 0.4))
	s3 = _pill(top, Color(0, 0, 0, 0.4))
	s4 = _pill(top, Color(0, 0, 0, 0.4))

	toast_p = PanelContainer.new()
	toast_p.add_theme_stylebox_override("panel", UIU.style(Color(0.06, 0.08, 0.12, 0.88), 10, Color(0, 0, 0, 0), 0, 12))
	toast_p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_p.offset_top = 64
	toast_p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_p.visible = false
	hud_root.add_child(toast_p)
	toast_l = Label.new()
	toast_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_l.custom_minimum_size = Vector2(420, 0)
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_p.add_child(toast_l)
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(func(): toast_p.visible = false)
	add_child(toast_timer)

	prompt_p = PanelContainer.new()
	prompt_p.add_theme_stylebox_override("panel", UIU.style(UIU.WARM, 12, Color(0, 0, 0, 0), 0, 12))
	prompt_p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_p.offset_bottom = -64
	prompt_p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_p.visible = false
	hud_root.add_child(prompt_p)
	prompt_l = Label.new()
	prompt_l.add_theme_color_override("font_color", UIU.INK)
	prompt_l.add_theme_font_size_override("font_size", 17)
	prompt_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_p.add_child(prompt_l)

	var hint := Label.new()
	hint.text = "Clic = mirar con el mouse (Esc lo libera) · WASD mover · Shift correr · ←/→ girar · E interactuar"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.85)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_bottom = -14
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hint)

	place_l = Label.new()
	place_l.add_theme_font_size_override("font_size", 12)
	place_l.modulate = Color(1, 1, 1, 0.6)
	place_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	place_l.offset_left = -240
	place_l.offset_right = -12
	place_l.offset_top = -30
	place_l.offset_bottom = -8
	place_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(place_l)

	var xh := Label.new()
	xh.text = "+"
	xh.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	xh.modulate = Color(1, 1, 1, 0.55)
	xh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(xh)


func _refresh() -> void:
	clock_l.text = Game.clock_str()
	s1.text = "Satisfacción %d" % Game.sat
	s2.text = "Seguridad %d" % Game.sec
	var al := Game.alerts()
	s3.text = "Tickets %d/%d · Red %d/3 · BIOS %d/1 · Taller %d/%d%s" % [Game.done, Game.tickets.size(), Game.net, 1 if Game.bios.get("done", false) else 0, Game.rep, Game.rq.size(), (" · ⚠ %d" % al) if al > 0 else ""]
	s4.text = "Día %d · Nv %d · $%d · %s" % [Game.G["day"], Game.lvl(), Game.G["money"], Game.rank()]


func set_place(t: String) -> void:
	place_l.text = t


func set_prompt(t: String) -> void:
	prompt_p.visible = t != "" and not Game.sitting and not end_p.visible
	prompt_l.text = "E · " + t.trim_suffix(" (E)")


func _toast(t: String, secs: float) -> void:
	toast_l.text = t
	toast_p.visible = true
	toast_timer.start(secs)


# ------------------------------------------------------------- ventanas ----
func modal_open() -> bool:
	return desk.visible or switch_ui.visible or bench.visible


func open_desk(onsite: int, ticket: int) -> void:
	Game.sitting = true
	Game.onsite = onsite
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	desk.open(onsite, ticket)


func open_switch() -> void:
	Game.sitting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	switch_ui.open()


func open_bench(tab_k: String) -> void:
	Game.sitting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	bench.open(tab_k)


func close_all() -> void:
	desk.visible = false
	switch_ui.visible = false
	bench.visible = false
	Game.sitting = false


func _modal_closed() -> void:
	Game.sitting = modal_open()


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and modal_open():
		if bench.visible:
			bench.close()
		elif switch_ui.visible:
			switch_ui.close()
		elif desk.visible:
			desk.close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------- llamadas ----
func _build_call() -> void:
	call_p = Control.new()
	call_p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_p.visible = false
	hud_root.add_child(call_p)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_p.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_p.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(480, 0)
	p.add_theme_stylebox_override("panel", UIU.style(Color("1b2230"), 14, UIU.WARM, 2, 18))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UIU.label("📞 Llamada entrante", 14, Color(1, 1, 1, 0.6)))
	call_name = UIU.label("", 22, Color.WHITE)
	v.add_child(call_name)
	call_text = UIU.label("", 16, Color.WHITE)
	v.add_child(call_text)
	call_box = VBoxContainer.new()
	call_box.add_theme_constant_override("separation", 6)
	v.add_child(call_box)


func _on_call(i: int) -> void:
	call_idx = i
	var d: Array = Data.CALLS[i]
	call_name.text = d[0]
	call_text.text = d[1]
	UIU.clear(call_box)
	for k in d[2].size():
		call_box.add_child(UIU.button(d[2][k][0], _answer.bind(k), UIU.INK, Color.WHITE, UIU.TEAL, 15))
	call_p.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.sitting = true


func _answer(k: int) -> void:
	call_p.visible = false
	Game.sitting = modal_open()
	Game.answer_call(call_idx, k)


# ---------------------------------------------------------- fin de jornada ----
func _build_end() -> void:
	end_p = Control.new()
	end_p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_p.visible = false
	hud_root.add_child(end_p)
	var dim := ColorRect.new()
	dim.color = Color("1d1520", 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_p.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_p.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 10)
	cc.add_child(v)
	end_title = UIU.label("", 34, Color.WHITE)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_title)
	end_text = UIU.label("", 17, Color.WHITE)
	end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_text)
	end_ach = UIU.label("", 13, Color(1, 1, 1, 0.7))
	end_ach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_ach)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	hb.add_child(UIU.button("Ir a casa", _go_home, UIU.INK, UIU.WARM, UIU.WARM, 17, false))
	reset_btn = UIU.button("Reiniciar progreso", _reset, Color.WHITE, Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.2), 14, false)
	hb.add_child(reset_btn)


func _on_day_finished(s: Dictionary) -> void:
	close_all()
	call_p.visible = false
	Game.call_open = false
	end_title.text = s["title"]
	end_text.text = s["text"]
	end_ach.text = s["ach"]
	reset_btn.text = "Reiniciar progreso"
	reset_btn.set_meta("armed", false)
	end_p.visible = true
	prompt_p.visible = false
	Game.sitting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _go_home() -> void:
	end_p.visible = false
	Game.sitting = false
	Game.go_home()
	home_requested.emit()


func _reset() -> void:
	if not reset_btn.get_meta("armed", false):
		reset_btn.set_meta("armed", true)
		reset_btn.text = "¿Seguro? Pulsa otra vez"
		return
	end_p.visible = false
	Game.sitting = false
	Game.reset_save()
	home_requested.emit()
