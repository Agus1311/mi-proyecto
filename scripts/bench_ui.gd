class_name BenchUI
extends Control
## Taller de reparación (piso 2): órdenes, banco de diagnóstico y almacén de piezas.

signal closed

var content: VBoxContainer
var tabs_box: HBoxContainer
var money_lbl: Label

const BG := Color("1b2735")
const LIGHT := Color("e8eaf0")
const BLUE := Color("2f6f8f")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color("0d141c", 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 24)
	add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mc.add_child(v)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIU.style(Color("16202b"), 8, Color(0, 0, 0, 0), 0, 10))
	v.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	bar.add_child(hb)
	var t := UIU.label("🔧 Taller de reparación · CAA Corp", 17, LIGHT)
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(t)
	tabs_box = HBoxContainer.new()
	tabs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(tabs_box)
	money_lbl = UIU.label("", 16, LIGHT)
	money_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
	money_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(money_lbl)
	hb.add_child(UIU.button("Salir (Esc)", close, Color.WHITE, Color("a63b2f"), Color("a63b2f"), 14, false))
	content = UIU.scroll(v)


func open(tab_k: String) -> void:
	visible = true
	if tab_k == "store":
		Game.bn["tab"] = "store"
	elif tab_k == "bench":
		Game.bn["tab"] = "ord"
	_draw()


func close() -> void:
	visible = false
	closed.emit()


func _go(tab_k: String) -> void:
	Game.bn["tab"] = tab_k
	_draw()


func _act(f: Callable) -> void:
	f.call()
	if visible:
		_draw()


func _open_order(i: int) -> void:
	Game.bn["o"] = i
	Game.bn["tab"] = "bench"
	_draw()


func _sel(c: String) -> void:
	var o: Dictionary = Game.rq[Game.bn["o"]]
	if not o["fixed"]:
		o["sel"] = c


func _b(t: String, cb: Callable, on: bool = false, disabled: bool = false) -> Button:
	var b := UIU.button(t, cb, LIGHT, BLUE if on else Color("14202c"), BLUE, 14, false)
	b.disabled = disabled
	return b


func _draw() -> void:
	var g: Dictionary = Game.bn
	UIU.clear(tabs_box)
	for t in [["ord", "Órdenes"], ["bench", "Banco"], ["store", "Almacén"]]:
		var k: String = t[0]
		tabs_box.add_child(UIU.button(t[1], _go.bind(k), Color("2a2230") if g["tab"] == k else Color.WHITE, Color("e8a77c") if g["tab"] == k else BLUE, BLUE, 14, false))
	money_lbl.text = "💰 $%d" % Game.G["money"]
	UIU.clear(content)
	if g["tab"] == "ord":
		content.add_child(UIU.label("Órdenes de reparación de hoy", 22, LIGHT))
		for i in Game.rq.size():
			var q: Dictionary = Game.rq[i]
			var c := UIU.card(content, BG)
			c.add_child(UIU.label("#%d · %s — %s" % [101 + i, q["mod"], q["own"]], 17, LIGHT))
			c.add_child(UIU.label(Data.FAULTS[q["f"]]["sym"], 14, Color(LIGHT, 0.7)))
			if q["fixed"]:
				c.add_child(UIU.label("✔ Reparado", 15, Color("7ddc9a")))
			else:
				c.add_child(_b("Abrir en el banco", _open_order.bind(i)))
		return
	if g["tab"] == "store":
		content.add_child(UIU.label("Almacén de piezas", 22, LIGHT))
		content.add_child(UIU.label("Saldo: $%d · Cobras al terminar cada jornada." % Game.G["money"], 15, LIGHT))
		for k in Data.PARTS:
			var key: String = k
			var c := UIU.card(content, BG)
			c.add_child(UIU.label("%s — $%d · En stock: %d" % [Data.PARTS[k][0], Game.part_price(k), int(Game.G["parts"].get(k, 0))], 16, LIGHT))
			var hb := HBoxContainer.new()
			c.add_child(hb)
			hb.add_child(_b("Comprar", _act.bind(Game.bn_buy.bind(key))))
			hb.add_child(_b("Pedir por garantía (40 min)", _act.bind(Game.bn_rma.bind(key))))
		return
	# banco
	if Game.rq.is_empty():
		content.add_child(UIU.label("No hay órdenes.", 16, LIGHT))
		return
	var o: Dictionary = Game.rq[g["o"]]
	var f: Dictionary = Data.FAULTS[o["f"]]
	var dg := Game.sk("diag")
	if o["fixed"]:
		content.add_child(UIU.label("#%d · %s" % [101 + g["o"], o["mod"]], 22, LIGHT))
		content.add_child(UIU.label("✔ Reparado: la PC de %s arrancó correctamente." % o["own"], 16, Color("7ddc9a")))
		return
	content.add_child(UIU.label("#%d · %s de %s" % [101 + g["o"], o["mod"], o["own"]], 22, LIGHT))
	content.add_child(UIU.label("🔧 Síntoma: " + f["sym"], 16, LIGHT))
	if dg >= 1:
		content.add_child(UIU.label("Pista del síntoma: revisa %s." % f["cat"], 13, Color(LIGHT, 0.7)))
	var grid := GridContainer.new()
	grid.columns = 4
	content.add_child(grid)
	for c in Data.COMP:
		var ck: String = c[0]
		var txt: String = "%s %s%s" % [c[2], c[1], "  ⚠" if dg >= 3 and ck == f["c"] else ""]
		grid.add_child(_b(txt, _act.bind(_sel.bind(ck)), o["sel"] == ck))
	if o["sel"] != null:
		content.add_child(UIU.label("%s — herramientas %s:" % [Game.comp_name(o["sel"]), "(pruebas gratis)" if dg >= 2 else "(2 min cada una)"], 15, LIGHT))
		var th := HFlowContainer.new()
		content.add_child(th)
		for t in Data.TOOLS:
			th.add_child(_b(t[1], _act.bind(Game.bn_test.bind(t[0]))))
	else:
		content.add_child(UIU.label("Selecciona un componente para probarlo.", 15, LIGHT))
	var lg := UIU.card(content, Color("05080c"))
	if o["log"].is_empty():
		lg.add_child(UIU.label("Sin pruebas todavía.", 13, Color(LIGHT, 0.6)))
	for l in o["log"]:
		var ll := UIU.label(l, 13, Color("cfe8d5"))
		ll.add_theme_font_override("font", UIU.mono_font())
		lg.add_child(ll)
	if o["sel"] != null:
		content.add_child(UIU.label("Reemplazar el componente con una pieza del inventario:", 15, LIGHT))
		var rh := HFlowContainer.new()
		content.add_child(rh)
		for k in Data.PARTS:
			var key: String = k
			var n := int(Game.G["parts"].get(k, 0))
			rh.add_child(_b("%s (%d)" % [Data.PARTS[k][0], n], _act.bind(Game.bn_replace.bind(key)), false, n < 1))
