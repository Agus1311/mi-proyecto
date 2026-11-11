class_name UIU
extends RefCounted
## Utilidades para construir la interfaz por código.

const INK := Color("2a2230")
const PAPER := Color("f6e7d8")
const TEAL := Color("2f6f8f")
const WARM := Color("e8a77c")
const OKC := Color("4c9a6a")
const BADC := Color("c4503f")


static func style(bg: Color, radius: int = 8, border: Color = Color(0, 0, 0, 0), bw: int = 0, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, size: int = 16, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, cb: Callable, fg: Color = INK, bg: Color = Color.WHITE, border: Color = TEAL, size: int = 15, wrap: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.4))
	b.add_theme_stylebox_override("normal", style(bg, 8, border, 2, 10))
	b.add_theme_stylebox_override("hover", style(border, 8, border, 2, 10))
	b.add_theme_stylebox_override("pressed", style(border.darkened(0.2), 8, border, 2, 10))
	b.add_theme_stylebox_override("disabled", style(Color(bg, 0.5), 8, Color(border, 0.4), 2, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func card(parent: Node, bg: Color = Color.WHITE) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, 8, Color(0, 0, 0, 0), 0, 10))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v


static func scroll(parent: Node) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


static func mono_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Courier New", "DejaVu Sans Mono", "Consolas", "monospace"])
	return f
