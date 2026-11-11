extends Node3D
## Mundo 3D de CAA Corp (construido por código, estilo low-poly), jugador en primera
## persona, zonas de interacción y usuarios que te buscan. Mismas coordenadas que el
## prototipo Three.js.

const OX := 40.0
const WALL := 0xf0c9a0
const CA := Color("e9b58a")
const CB := Color("dcc0a0")
const CC := Color("c2603e")

var DK: Array = []   # obstáculos [x, z, mitad_x, mitad_z]
var WK: Array = []   # zonas caminables [x0, x1, z0, z1]
var ACT: Array = []  # zonas de interacción

var _mats: Dictionary = {}
var _meshes: Dictionary = {}
var env: Environment
var cam: Camera3D
var ui: Node
var yaw := 0.0
var pitch := 0.0
var bob_t := 0.0
var leds: Array = []
const LED_COLS := [0x39ff7a, 0xffb03a, 0x39ff7a, 0x4aa8ff]
var tvs: Array = []
var st_screens: Array = []   # {mat, label}
var desk_label: Label3D
var clock_label: Label3D
var seek: Dictionary = {}
var seek_at := 0.0
var _led_t := 0.0
var _ad_t := 0.0
var _tint_time := -1
var _seek_t := 0.0
var _place := ""
var npcs: Array = []


func _ready() -> void:
	ui = $UI
	_setup_env()
	_build_office()
	_build_hall_home()
	_build_datacenter()
	_build_departments()
	_build_floor2()
	_build_npcs()
	cam = Camera3D.new()
	cam.fov = 70
	cam.near = 0.05
	cam.far = 60
	cam.position = Vector3(-1, 1.6, 2)
	add_child(cam)
	cam.current = true
	seek_at = Time.get_ticks_msec() + 12000.0
	Game.changed.connect(_on_changed)
	Game.ticket_resolved.connect(_on_ticket_resolved)
	Game.day_finished.connect(func(_s): _end_seek(true))
	ui.home_requested.connect(_on_home)
	_on_changed()


# ================================================================ helpers ====
func mat(c: int, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%d_%d" % [c, int(unshaded)]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((c << 8) | 0xFF)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


func _bm(w: float, h: float, d: float) -> BoxMesh:
	var key := "%.3f_%.3f_%.3f" % [w, h, d]
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = Vector3(w, h, d)
		_meshes[key] = b
	return _meshes[key]


func box(w: float, h: float, d: float, c: int, x: float, y: float, z: float, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _bm(w, h, d)
	mi.material_override = mat(c)
	mi.position = Vector3(x, y, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


## Obstáculo con colisión: caja + registro en DK.
func fb(w: float, h: float, d: float, c: int, x: float, y: float, z: float) -> MeshInstance3D:
	DK.append([x, z, w / 2 + .25, d / 2 + .25])
	return box(w, h, d, c, x, y, z)


func quad(w: float, h: float, c: int, pos: Vector3, ry: float = 0.0, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	mi.material_override = mat(c, true)
	mi.position = pos
	mi.rotation.y = ry
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func text3d(t: String, pos: Vector3, ry: float, height: float, color: Color = Color.WHITE, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = 48
	l.pixel_size = height / 48.0
	l.modulate = color
	l.shaded = false
	l.outline_size = 0
	l.position = pos
	l.rotation.y = ry
	(parent if parent else self).add_child(l)
	return l


func flat(x0: float, x1: float, z0: float, z1: float, c: int, y: float = 0.01) -> void:
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(x1 - x0, z1 - z0)
	mi.mesh = p
	mi.material_override = mat(c)
	mi.position = Vector3((x0 + x1) / 2, y, (z0 + z1) / 2)
	add_child(mi)


func omni(x: float, y: float, z: float, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = Vector3(x, y, z)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)


func lamp(x: float, z: float) -> void:
	var m := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(1, .04, .6)
	m.mesh = q
	m.material_override = mat(0xfff2d6, true)
	m.position = Vector3(x, 2.96, z)
	add_child(m)


func poster(x: float, y: float, z: float, l1: String, l2: String, col: String) -> void:
	quad(.5, .62, int(Color(col).to_html(false).hex_to_int()), Vector3(x, y, z))
	text3d(l1, Vector3(x, y + .1, z + .004), 0, .07, Color.WHITE)
	text3d(l2, Vector3(x, y - .03, z + .004), 0, .045, Color.WHITE)


func sgn(x: float, y: float, z: float, ry: float, t: String, col: String) -> void:
	quad(1.1, .28, int(Color(col).to_html(false).hex_to_int()), Vector3(x, y, z), ry)
	var off := Vector3(sin(ry), 0, cos(ry)) * .004
	text3d(t, Vector3(x, y, z) + off, ry, .07, Color.WHITE)


func logo(x: float, y: float, z: float, ry: float, w: float) -> void:
	quad(w, w * .375, 0x0b2a4a, Vector3(x, y, z), ry)
	var off := Vector3(sin(ry), 0, cos(ry)) * .004
	text3d("CAA CORP", Vector3(x, y, z) + off, ry, w * .12, Color("ff9a1f"))


func plant(x: float, z: float, solid: bool = false) -> void:
	box(.4, .4, .4, 0x1c3fc8, x, .2, z)
	box(.05, .7, .05, 0x2a4a2a, x, .7, z)
	if solid:
		DK.append([x, z, .45, .45])


func window(x: float, z: float, ry: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, 1.7, z)
	g.rotation.y = ry
	add_child(g)
	box(3, 1.3, .12, 0x111111, 0, 0, 0, g)
	quad(2.7, 1.05, 0x4fa56a, Vector3(0, 0, .07), 0, g)
	for i in 4:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := .3 + randf() * .2
		sm.radius = r
		sm.height = r * 2
		sm.radial_segments = 6
		sm.rings = 3
		s.mesh = sm
		s.material_override = mat(0x2e8a4f)
		s.position = Vector3(-1 + i * .7, -.2 + randf() * .3, .12)
		g.add_child(s)


func tv(x: float, y: float, z: float, ry: float, w: float) -> void:
	var h := w * .5625
	var g := Node3D.new()
	g.position = Vector3(x, y, z)
	g.rotation.y = ry
	add_child(g)
	box(w + .08, h + .08, .06, 0x0a0a10, 0, 0, 0, g)
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position.z = .035
	g.add_child(mi)
	var l := Label3D.new()
	l.font_size = 48
	l.pixel_size = w * .09 / 48.0
	l.shaded = false
	l.position = Vector3(0, 0, .04)
	g.add_child(l)
	tvs.append({"mat": m, "label": l, "pos": Vector3(x, 0, z)})


func fl_wall_x(x: float, z0: float, z1: float, gs: Array) -> void:
	var a := z0
	for g in gs + [z1 + 1]:
		var e: float = z1 if g > z1 else g - .9
		if e > a:
			box(.2, 3, e - a, 0xeee6d8, x, 1.5, (a + e) / 2)
		if g <= z1:
			box(.2, 1, 1.8, 0xeee6d8, x, 2.5, g)
			a = g + .9


func wall_z(z: float, x0: float, x1: float) -> void:
	box(x1 - x0, 3, .2, 0xeee6d8, (x0 + x1) / 2, 1.5, z)


func d2(x: float, z: float, u: int = -1) -> void:
	box(1.4, .07, .7, 0x8a7a8e, x, .76, z)
	box(.05, .76, .6, 0x1a1620, x - .65, .38, z)
	box(.05, .76, .6, 0x1a1620, x + .65, .38, z)
	box(.5, .35, .04, 0x111111, x, 1.08, z - .2)
	quad(.46, .3, 0x2f6f8f, Vector3(x, 1.08, z - .17))
	box(.4, .02, .14, 0x222222, x, .8, z + .1)
	box(.45, .07, .45, 0x2f5fbf, x, .5, z + .85)
	box(.45, .5, .06, 0x2f5fbf, x, .8, z + 1.1)
	DK.append([x, z, .9, .55])


func person(col: int, name_t: String, sitting: bool = false) -> Node3D:
	var g := Node3D.new()
	var y0 := -.2 if sitting else 0.0
	box(.34, .62, .22, col, 0, .95 + y0, 0, g)
	box(.12, .6 if not sitting else .35, .14, 0x2a2a3a, -.09, .3 + (.15 if sitting else 0.0), 0, g)
	box(.12, .6 if not sitting else .35, .14, 0x2a2a3a, .09, .3 + (.15 if sitting else 0.0), 0, g)
	box(.22, .22, .22, 0xe0a97a, 0, 1.42 + y0, 0, g)
	box(.09, .5, .1, col, -.23, .95 + y0, 0, g)
	box(.09, .5, .1, col, .23, .95 + y0, 0, g)
	var l := Label3D.new()
	l.text = name_t
	l.font_size = 40
	l.pixel_size = .0045
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.no_depth_test = true
	l.modulate = Color.WHITE
	l.outline_size = 8
	l.position.y = 1.9 + y0
	g.add_child(l)
	add_child(g)
	return g


# ================================================================ entorno ====
func _setup_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = CA
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffe2c4")
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = CA
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _tint() -> void:
	var tf := clampf((Game.time - 480) / 540.0, 0.0, 1.0)
	var u := tf * 2.0 if tf < .5 else (tf - .5) * 2.0
	var c: Color = (CA if tf < .5 else CB).lerp(CB if tf < .5 else CC, u)
	env.background_color = c
	env.fog_light_color = c
	env.ambient_light_energy = 0.9 - 0.2 * tf


# ============================================================ oficina TI ====
func _build_office() -> void:
	flat(-4, 4, -3, 3, 0x2f6f8f, 0.0)
	# suelo ajedrezado
	for i in 8:
		for j in 6:
			if (i + j) % 2 == 0:
				flat(-4 + i, -3 + i, -3 + j, -2 + j, 0xf3e7cf, 0.005)
	box(8, 3, .2, WALL, 0, 1.5, -3)
	box(.2, 3, 2.1, WALL, -4, 1.5, -1.95)
	box(.2, 3, 2.1, WALL, -4, 1.5, 1.95)
	box(.2, 1, 1.8, WALL, -4, 2.5, 0)
	box(.2, 3, 2.1, WALL, 4, 1.5, -1.95)
	box(.2, 3, 2.1, WALL, 4, 1.5, 1.95)
	box(.2, 1, 1.8, WALL, 4, 2.5, 0)
	box(8, 3, .2, WALL, 0, 1.5, 3)
	box(8, .2, 6, 0x7a5a48, 0, 3, 0)
	window(0, -2.88, 0)
	window(-1.6, 2.88, PI)
	for p in [[-1.5, 0.0], [1.5, .3]]:
		lamp(p[0], p[1])
		omni(p[0], 2.6, p[1], Color("ffe3b0"), 0.9, 7.0)
	omni(2, 1.3, -1.6, Color("9a6aff"), 0.5, 2.5)
	# reloj de pared
	clock_label = text3d("08:00", Vector3(-2.6, 2.3, -2.88), 0, .18, Color("2a2230"))
	quad(.5, .3, 0xf6e7d8, Vector3(-2.6, 2.3, -2.89))
	box(.45, .22, .35, 0xdad4c8, -1.7, .85, -2.7)
	box(.3, .04, .2, 0xffffff, -1.7, .99, -2.6)
	box(.35, .9, .35, 0xcfe3ee, 3.4, .45, 2.4)
	box(.28, .35, .28, 0x6ec1ff, 3.4, 1.05, 2.4)
	plant(-3.5, 2.4)
	poster(3.2, 1.7, -2.88, "MFA", "siempre", "#2f6f8f")
	poster(-3.45, 1.6, -2.88, "NO HAGAS", "CLIC", "#a63b2f")
	# escritorio del jugador
	var desk := Node3D.new()
	desk.position = Vector3(2, 0, -1.9)
	add_child(desk)
	box(2.2, .07, 1, 0x77687a, 0, .76, 0, desk)
	box(.5, .76, .95, 0x15121a, -.85, .38, 0, desk)
	box(.5, .76, .95, 0x15121a, .85, .38, 0, desk)
	box(.1, .3, .05, 0x222222, 0, .9, -.1, desk)
	box(.4, .02, .15, 0x111111, 0, .8, .2, desk)
	box(.74, .48, .04, 0x111111, 0, 1.18, -.1, desk)
	quad(.7, .44, 0x6a3a8a, Vector3(0, 1.18, -.07), 0, desk)
	desk_label = text3d("", Vector3(0, 1.18, -.065), 0, .04, Color.WHITE, desk)
	box(.12, .1, .1, 0xff4f9a, .55, .82, .2, desk)
	box(.1, .1, .1, 0x2a3a8a, .7, .82, .1, desk)
	box(.24, .015, .16, 0x1a1a2a, -.6, .81, .15, desk)
	box(.07, .07, .01, 0xe8e04a, .4, 1.4, -.07, desk)
	DK.append([2, -1.9, 1.2, .6])
	# silla
	var chair := Node3D.new()
	chair.position = Vector3(2.4, 0, -1)
	chair.rotation.y = -.5
	add_child(chair)
	box(.6, .08, .6, 0x2f5fbf, 0, .5, 0, chair)
	box(.6, .7, .08, 0x2f5fbf, 0, .9, .3, chair)
	box(.08, .5, .08, 0x222222, 0, .25, 0, chair)
	# mueble largo y detalles
	box(2.6, .7, .5, 0xefe6d6, -1.5, .35, -2.7)
	box(2.6, .05, .5, 0xc07a3a, -1.5, .72, -2.7)
	for i in 6:
		box(.5, .04, .35, [0xffffff, 0x4c9a6a, 0x2f6f8f, 0xc4503f, 0xffffff, 0x4c9a6a][i], -2.2, .76 + i * .045, -2.7)
	box(.3, .3, .3, 0x1c3fc8, -1.1, .9, -2.7)
	box(.04, .5, .04, 0x2a4a2a, -1.1, 1.3, -2.7)
	box(.25, .2, .15, 0x2f6fd0, -.4, .85, -2.7)
	box(.5, .4, .45, 0xb8b3a8, .6, 2, -2.8)
	box(.4, .3, .05, 0x222222, .6, 2, -2.55)
	box(.15, 2.4, 2, 0xd8c7b0, 3.9, 1.2, 2)
	for i in 4:
		box(.18, .04, 2, 0x6a6a6a, 3.85, .5 + i * .6, 2)
	box(1.5, .02, .9, 0x3a2a30, 1.5, 2.97, -.5)
	sgn(-1.2, 2.1, 2.88, PI, "TICKETS PENDIENTES", "#2f6f8f")
	logo(1.8, 1.8, 2.88, PI, 1.6)
	tv(3.2, 1.75, 2.86, PI, 1.1)
	# zonas caminables y de interacción
	WK.append_array([[-11.5, -4.2, -1.7, 2.6], [-4.35, -3.6, -.8, .8], [-3.7, 3.65, -2.5, 2.6], [3.5, 4.5, -.8, .8],
		[4.4, 7.7, -2.5, 20.6], [7.6, 8.5, -.8, .8], [8.4, 13.85, -2.5, 2.6], [13.6, 14.5, -.8, .8], [14.4, 17.6, -2.5, 2.6]])
	DK.append_array([[10.5, .4, 1.3, .7], [12.6, .9, .8, .55], [12.4, -2.55, 1.05, .65], [13.4, -2.4, .55, .6],
		[16.9, -1.6, 1.25, 1], [17.6, 1.7, .6, 1.1], [15.6, 2.6, 1.05, .55], [4.7, -1.9, .5, .95], [7.3, -1.9, .5, .95]])
	ACT.append({"x": 2.0, "z": -1.2, "r": 2.2, "loc": 0, "l": "Sentarse en la PC (E)"})
	ACT.append({"x": -5.0, "z": -1.2, "r": 1.8, "dc": 1, "l": "Abrir consola del switch Cisco (E)"})


# =============================================== pasillo y apartamento ====
func _build_hall_home() -> void:
	var HW := 0xcfd3d9
	var AW := 0xe8d9c4
	flat(4, 8, -3, 3, 0x5a6070, 0.0)
	flat(8, 18, -3, 3, 0xa8794a, 0.0)
	box(4, 3, .2, HW, 6, 1.5, -3)
	box(4, .2, 6, 0xb8bcc4, 6, 3, 0)
	box(.2, 3, 2.1, AW, 8, 1.5, -1.95)
	box(.2, 3, 2.1, AW, 8, 1.5, 1.95)
	box(.2, 1, 1.8, AW, 8, 2.5, 0)
	box(10, 3, .2, AW, 13, 1.5, -3)
	box(10, 3, .2, AW, 13, 1.5, 3)
	box(.2, 3, 6, AW, 18, 1.5, 0)
	box(10, .2, 6, 0xf2ece0, 13, 3, 0)
	box(.2, 3, 2.1, AW, 14, 1.5, -1.95)
	box(.2, 3, 2.1, AW, 14, 1.5, 1.95)
	box(.2, 1, 1.8, AW, 14, 2.5, 0)
	window(9.6, -2.88, 0)
	window(16, -2.88, 0)
	omni(6, 2.6, 0, Color("dfe8ff"), .6, 8)
	omni(11, 2.6, 0, Color("ffe6b8"), .8, 8)
	omni(16, 2.6, 0, Color("ffe6b8"), .8, 8)
	# ascensor, bancas
	box(1.8, 2.2, .1, 0x9aa3ad, 6, 1.1, -2.88)
	box(.03, 2.2, .12, 0x333333, 6, 1.1, -2.86)
	box(.3, .12, .05, 0x6ec1ff, 6, 2.45, -2.86)
	box(.5, .4, 1.4, 0x7a5a42, 4.7, .2, -1.9)
	box(.5, .4, 1.4, 0x7a5a42, 7.3, .2, -1.9)
	plant(4.4, -2.5)
	poster(7.2, 1.7, -2.88, "PISO 5", "Aptos", "#2f6f8f")
	tv(7.86, 1.7, 1.9, -PI / 2, 1.3)
	ACT.append({"x": 6.0, "z": -2.2, "r": 1.6, "elev": 1, "to": 1, "l": "⬆ Subir al piso 2 (E)"})
	# sala y cocina
	box(2.2, .4, .9, 0x3a7a5a, 10.5, .2, .6)
	box(2.2, .55, .2, 0x2f6a4a, 10.5, .65, .15)
	box(.25, .3, .9, 0x2f6a4a, 9.35, .55, .6)
	box(.25, .3, .9, 0x2f6a4a, 11.65, .55, .6)
	flat(9, 12, .3, 2.3, 0xb04a3a, .012)
	box(1.6, .9, .08, 0x0a0a10, 10.5, 1.2, 2.85)
	tv(10.5, 1.2, 2.78, PI, 1.5)
	box(1.8, .4, .45, 0x2a2a30, 10.5, .2, 2.65)
	box(1.8, .9, .7, 0xefe6d6, 12.4, .45, -2.6)
	box(1.9, .05, .75, 0x555a62, 12.4, .92, -2.6)
	box(1.8, .6, .35, 0xc9b79c, 12.4, 2.1, -2.8)
	box(.8, 1.9, .8, 0xdad4c8, 13.4, .95, -2.4)
	box(1.4, .06, .9, 0x8a5a2a, 12.6, .75, .9)
	for p in [[-.6, -.35], [.6, -.35], [-.6, .35], [.6, .35]]:
		box(.06, .72, .06, 0x5a3a1a, 12.6 + p[0], .36, .9 + p[1])
	for p in [[12.1, 1.7], [13.1, 1.7], [12.1, .1], [13.1, .1]]:
		box(.4, .05, .4, 0xc07a3a, p[0], .48, p[1])
		box(.4, .45, .05, 0xc07a3a, p[0], .72, p[1] + (.2 if p[1] > .9 else -.2))
	box(.5, .18, .5, 0xf0a020, 12.6, .84, .9)
	box(.05, 1.6, .05, 0x222222, 8.7, .8, 2.4)
	box(.5, .35, .5, 0xffe2a8, 8.7, 1.7, 2.4)
	plant(8.6, -2.4)
	# dormitorio
	box(2, .3, 1.6, 0x5a3a22, 16.9, .15, -1.6)
	box(1.9, .25, 1.5, 0xe8e4f4, 16.9, .42, -1.6)
	box(.5, .12, .9, 0xffffff, 17.5, .6, -1.6)
	box(1.2, .1, 1.5, 0x2f6f8f, 16.5, .58, -1.6)
	box(.7, 2.3, 1.6, 0x7a5a42, 17.6, 1.15, 1.7)
	box(.5, .5, .5, 0x8a6a4a, 15.4, .25, -2.6)
	box(.2, .3, .2, 0xffe2a8, 15.4, .65, -2.6)
	box(1.6, .06, .7, 0x6a6a72, 15.6, .76, 2.6)
	box(.06, .76, .6, 0x222222, 14.85, .38, 2.6)
	box(.06, .76, .6, 0x222222, 16.35, .38, 2.6)
	box(.25, .5, .5, 0x181820, 16.1, .3, 2.4)
	box(.7, .42, .04, 0x111111, 15.6, 1.1, 2.85)
	quad(.64, .36, 0x0e1b2e, Vector3(15.6, 1.1, 2.82), PI)
	box(.5, .05, .5, 0x2f5fbf, 15.6, .5, 1.9)
	box(.5, .5, .07, 0x2f5fbf, 15.6, .8, 1.65)
	ACT.append({"x": 10.5, "z": 1.7, "r": 1.4, "home": "tv", "l": "Ver TV y relajarte (E)"})
	ACT.append({"x": 12.4, "z": -1.4, "r": 1.4, "home": "cook", "l": "Cocinar algo (E)"})
	ACT.append({"x": 15.6, "z": 1.7, "r": 1.4, "home": "study", "l": "Estudiar para certificación (E)"})
	ACT.append({"x": 16.3, "z": -.2, "r": 1.5, "home": "sleep", "l": "Dormir y empezar un nuevo día (E)"})


# ============================================================ data center ====
func _build_datacenter() -> void:
	flat(-12, -4, -3, 3, 0x1b2430, 0.0)
	for z in [-1, 1]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(5, .03, .12)
		m.mesh = b
		m.material_override = mat(0x9fd0ff, true)
		m.position = Vector3(-8, 2.95, z)
		add_child(m)
	var DW := 0x2a3441
	box(8, 3, .2, DW, -8, 1.5, -3)
	box(8, 3, .2, DW, -8, 1.5, 3)
	box(.2, 3, 6, DW, -12, 1.5, 0)
	box(8, .2, 6, 0x141a22, -8, 3, 0)
	box(8, .1, .3, 0x555b66, -8, 2.7, 0)
	omni(-8, 2.6, 0, Color("5aa0ff"), 1.0, 10)
	var names := ["Nexus 9300", "UCS C240", "Nexus 9300", "ASR 1001", "Catalyst 9300", "Catalyst 2960 · CORE"]
	for i in 6:
		var rg := Node3D.new()
		rg.position = Vector3(-11 + i * 1.2, 0, -2.4)
		add_child(rg)
		box(.9, 2.3, .9, 0x14171d, 0, 1.15, 0, rg)
		for u in 9:
			box(.8, .14, .02, 0x2c3440, 0, .3 + u * .22, .46, rg)
			for k in 4:
				var l := MeshInstance3D.new()
				var lb := BoxMesh.new()
				lb.size = Vector3(.03, .03, .02)
				l.mesh = lb
				var lm := StandardMaterial3D.new()
				lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				lm.albedo_color = Color.hex((LED_COLS[k] << 8) | 0xFF)
				l.material_override = lm
				l.position = Vector3(-.3 + k * .08, .3 + u * .22, .48)
				rg.add_child(l)
				leds.append(lm)
		quad(.8, .125, 0x0a5f8f if i == 5 else 0x0b2a3d, Vector3(-11 + i * 1.2, 2.2, -1.93))
		text3d("CISCO " + names[i], Vector3(-11 + i * 1.2, 2.2, -1.925), 0, .035, Color.WHITE)
	quad(.9, .22, 0x1b2430, Vector3(-3.88, 2.3, 0), PI / 2)
	text3d("DATA CENTER", Vector3(-3.875, 2.3, 0), PI / 2, .08, Color("6ec1ff"))


# ============================================================ departamentos ====
func _build_departments() -> void:
	var RM := [[-4, 4, 3, 9, "RECURSOS HUMANOS", 0xb59ac4, "#8a3fa0"], [-4, 4, 9, 15, "CENTRO DE COPIADO", 0x9aa6b0, "#1f7f8f"],
		[-4, 4, 15, 21, "OPERACIONES", 0x8b7d6a, "#8a6a2a"], [8, 16, 3, 9, "CONTABILIDAD", 0x9ab59a, "#2f7a4a"],
		[8, 16, 9, 15, "VENTAS", 0xc4a46a, "#c0502a"], [8, 16, 15, 21, "GERENCIA", 0x6a4a3a, "#0b2a4a"]]
	flat(4, 8, 3, 21, 0x5a6070)
	box(4, .2, 18, 0xb8bcc4, 6, 3, 12)
	for z in [6, 12, 18]:
		lamp(6, z)
	for r in RM:
		var cx: float = (r[0] + r[1]) / 2.0
		var cz: float = (r[2] + r[3]) / 2.0
		var w: bool = r[0] < 0
		flat(r[0], r[1], r[2], r[3], r[5])
		box(8, .2, 6, 0xf2ece0, cx, 3, cz)
		lamp(cx, cz)
		sgn(4.11 if w else 7.89, 2.55, cz, PI / 2 if w else -PI / 2, r[4], r[6])
	fl_wall_x(4, 3, 21, [6, 12, 18])
	fl_wall_x(-4, 3, 21, [])
	fl_wall_x(8, 3, 21, [6, 12, 18])
	fl_wall_x(16, 3, 21, [])
	wall_z(9, -4, 4)
	wall_z(15, -4, 4)
	wall_z(9, 8, 16)
	wall_z(15, 8, 16)
	wall_z(21, -4, 16)
	for g in [6, 12, 18]:
		WK.append([3.5, 4.5, g - .8, g + .8])
		WK.append([7.5, 8.5, g - .8, g + .8])
		WK.append([-3.7, 3.65, g - 2.5, g + 2.5])
		WK.append([8.4, 15.6, g - 2.5, g + 2.5])
	omni(6, 2.6, 12, Color("dfe8ff"), .6, 16)
	for p in [[0, 6], [0, 12], [0, 18], [12, 6], [12, 12], [12, 18]]:
		omni(p[0], 2.6, p[1], Color("fff0dc"), .7, 7)
	logo(6, 1.9, 20.88, PI, 2.8)
	logo(7.88, 1.7, -2.1, -PI / 2, 1.6)
	fb(.35, .9, .35, 0xcfe3ee, 7.6, .45, 3.8)
	box(.28, .35, .28, 0x6ec1ff, 7.6, 1.05, 3.8)
	plant(4.6, 9)
	plant(7.5, 15)
	# Sala de espera (zona de oficina)
	fb(1.8, .08, .9, 0x8a7a8e, -1.2, .75, .3 + 0.0)
	# RRHH
	d2(-2.4, 4.3)
	d2(.4, 4.3)
	fb(.5, 1.5, .9, 0x8a9aa8, -3.6, .75, 5.7)
	fb(.5, 1.5, .9, 0x8a9aa8, -3.6, .75, 6.8)
	fb(1.4, .08, 1.4, 0x8a5a2a, 1.8, .75, 7.6)
	poster(-.9, 1.7, 3.12, "RRHH", "Bienvenid@", "#8a3fa0")
	poster(2.4, 1.7, 3.12, "CAA", "Valores", "#0b2a4a")
	# Copiado
	fb(1.1, 1.1, .7, 0xdad4c8, -2.6, .55, 10.2)
	fb(1.1, 1.1, .7, 0xdad4c8, -1.2, .55, 10.2)
	box(.45, .06, .25, 0x2f6f8f, -2.6, 1.14, 10.15)
	box(.45, .06, .25, 0x2f6f8f, -1.2, 1.14, 10.15)
	fb(1.6, .9, .6, 0xcfd4da, 1.4, .45, 10.2)
	fb(2.2, .8, .8, 0x8a8a92, .2, .4, 13.9)
	fb(.45, .7, .4, 0x333333, -3.4, .35, 13.6)
	poster(2.8, 1.7, 9.12, "COPIAS", "e impresión", "#1f7f8f")
	# Operaciones
	fb(.6, 2, 3, 0x7a6a5a, -3.55, 1, 17.4)
	for i in 3:
		box(.4, .4, .8, 0xb98b5a, -3.45, .5 + i * .7, 16.7 + i * .5)
	fb(.8, .8, .8, 0xb98b5a, 2.8, .4, 19.5)
	# estaciones con usuarios que piden ayuda en sitio
	for s in [[11.5, 4.4, 0xd05a7a, 1], [-1.5, 16.4, 0x4c7ad0, 2], [11.5, 10.4, 0x6a9a4c, 3]]:
		_station(s[0], s[1], s[2])
		DK.append([s[0], s[1], 1, .7])
	ACT.append({"x": 11.5, "z": 5.8, "r": 1.5, "loc": 1})
	ACT.append({"x": -1.5, "z": 17.8, "r": 1.5, "loc": 2})
	ACT.append({"x": 11.5, "z": 11.8, "r": 1.5, "loc": 3})
	ACT.append({"x": -1.9, "z": 11.5, "r": 1.6, "loc": 5, "lc": "Revisar la copiadora (E)"})
	# Contabilidad / Ventas / Gerencia
	d2(14.2, 4.4)
	fb(.9, 1, .9, 0x444444, 15.2, .5, 7.8)
	fb(.5, 1.5, .9, 0x8a9aa8, 15.6, .75, 5.7)
	poster(9.2, 1.7, 3.12, "FINANZAS", "Cierre de mes", "#2f7a4a")
	d2(14.2, 10.4)
	box(2.4, 1.3, .05, 0xf4f4f4, 12.8, 1.7, 9.12)
	fb(.9, .8, .4, 0x8a5a2a, 9, .4, 13.6)
	poster(9.2, 1.7, 9.12, "VENTAS", "Meta x2", "#c0502a")
	fb(2.4, .08, 1.1, 0x3a2a1a, 12.5, .78, 17.2)
	box(.1, .76, 1, 0x2a1a0a, 11.4, .38, 17.2)
	box(.1, .76, 1, 0x2a1a0a, 13.6, .38, 17.2)
	box(.6, .4, .04, 0x111111, 12.5, 1.12, 17)
	box(.6, .1, .6, 0x1a1a1a, 12.5, .5, 18.1)
	box(.6, .8, .1, 0x1a1a1a, 12.5, .95, 18.4)
	fb(.4, 2.2, 3, 0x5a3a22, 15.6, 1.1, 18.2)
	fb(2, .4, .8, 0x3a3a4a, 10, .2, 20.3)


func _station(x: float, z: float, shirt: int) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, 0, z)
	add_child(g)
	box(1.6, .07, .8, 0x8a7a8e, 0, .76, 0, g)
	box(.06, .76, .7, 0x1a1620, -.72, .38, 0, g)
	box(.06, .76, .7, 0x1a1620, .72, .38, 0, g)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("2f6f8f")
	var lbl: Label3D = null
	for dx in [-.38, .38]:
		box(.7, .42, .04, 0x111111, dx, 1.1, -.2, g)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(.64, .36)
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(dx, 1.1, -.17)
		g.add_child(mi)
		var l := Label3D.new()
		l.font_size = 48
		l.pixel_size = .0035
		l.shaded = false
		l.position = Vector3(dx, 1.1, -.165)
		g.add_child(l)
		if lbl == null:
			lbl = l
		box(.06, .3, .06, 0x222222, dx, .92, -.2, g)
	box(.45, .02, .15, 0x222222, 0, .8, .1, g)
	box(.5, .08, .5, 0x2f5fbf, 0, .5, .9, g)
	box(.5, .6, .07, 0x2f5fbf, 0, .85, 1.18, g)
	st_screens.append({"mat": m, "label": lbl})


# ==================================================================== piso 2 ====
func _build_floor2() -> void:
	var W2 := 0xeee6d8
	flat(OX + 4, OX + 8, -3, 21, 0x5a6070)
	box(4, .2, 24, 0xb8bcc4, OX + 6, 3, 9)
	for z in [0, 6, 12, 18]:
		lamp(OX + 6, z)
	box(.2, 3, 6, W2, OX + 4, 1.5, 0)
	box(.2, 3, 6, W2, OX + 8, 1.5, 0)
	box(4, 3, .2, W2, OX + 6, 1.5, -3)
	box(1.8, 2.2, .1, 0x9aa3ad, OX + 6, 1.1, -2.88)
	box(.3, .12, .05, 0x6ec1ff, OX + 6, 2.45, -2.86)
	var R2 := [[OX - 4, OX + 4, 3, 9, "TALLER DE REPARACIÓN", 0x8a96a2, "#1f4f7f"], [OX - 4, OX + 4, 9, 15, "ALMACÉN DE PIEZAS", 0x7a7060, "#8a6a2a"],
		[OX - 4, OX + 4, 15, 21, "SOPORTE N2", 0x9ab5c4, "#2f6f8f"], [OX + 8, OX + 16, 3, 9, "MARKETING", 0xc49ab5, "#c0306a"],
		[OX + 8, OX + 16, 9, 15, "LEGAL", 0xb5ab9a, "#5a4a2a"], [OX + 8, OX + 16, 15, 21, "CAPACITACIÓN", 0x9ac4a8, "#2f7a4a"]]
	for r in R2:
		var cx: float = (r[0] + r[1]) / 2.0
		var cz: float = (r[2] + r[3]) / 2.0
		var w: bool = r[0] < OX
		flat(r[0], r[1], r[2], r[3], r[5])
		box(8, .2, 6, 0xf2ece0, cx, 3, cz)
		lamp(cx, cz)
		sgn(OX + 4.11 if w else OX + 7.89, 2.55, cz, PI / 2 if w else -PI / 2, r[4], r[6])
		omni(cx, 2.6, cz, Color("fff0dc"), .7, 7)
	fl_wall_x(OX + 4, 3, 21, [6, 12, 18])
	fl_wall_x(OX - 4, 3, 21, [])
	fl_wall_x(OX + 8, 3, 21, [6, 12, 18])
	fl_wall_x(OX + 16, 3, 21, [])
	wall_z(3, OX - 4, OX + 4)
	wall_z(3, OX + 8, OX + 16)
	wall_z(9, OX - 4, OX + 4)
	wall_z(15, OX - 4, OX + 4)
	wall_z(9, OX + 8, OX + 16)
	wall_z(15, OX + 8, OX + 16)
	wall_z(21, OX - 4, OX + 16)
	for g in [6, 12, 18]:
		WK.append([OX + 3.5, OX + 4.5, g - .8, g + .8])
		WK.append([OX + 7.5, OX + 8.5, g - .8, g + .8])
		WK.append([OX - 3.7, OX + 3.65, g - 2.5, g + 2.5])
		WK.append([OX + 8.4, OX + 15.6, g - 2.5, g + 2.5])
	WK.append([OX + 4.4, OX + 7.7, -2.5, 20.6])
	omni(OX + 6, 2.6, 12, Color("dfe8ff"), .6, 16)
	logo(OX + 6, 1.9, 20.88, PI, 2.8)
	logo(OX + 6, 2.6, -2.86, 0, 1.2)
	plant(OX + 4.6, -2.4)
	# Taller: bancos
	for bx in [OX - 1.6, OX + 1.6]:
		fb(2.6, .08, 1, 0x6a6a72, bx, .95, 4.4)
		box(.08, .93, .9, 0x3a3a42, bx - 1.2, .47, 4.4)
		box(.08, .93, .9, 0x3a3a42, bx + 1.2, .47, 4.4)
		box(.5, .42, .5, 0x20242c, bx - .5, 1.22, 4.4)
		box(.4, .02, .4, 0x1f7a4a, bx - .5, 1.45, 4.4)
		box(.2, .08, .12, 0xe8a03a, bx + .7, 1, 4.5)
	fb(.6, 1.8, 1.4, 0xb03a2a, OX + 3.5, .9, 7.2)
	fb(1.6, .8, .7, 0x8a8a92, OX - 3.2, .4, 8.4)
	poster(OX - 2.6, 1.7, 3.12, "TALLER", "Cambio de piezas", "#1f4f7f")
	poster(OX + 1.2, 1.7, 3.12, "ESD", "Pulsera antiestática", "#a63b2f")
	# Almacén
	fb(.6, 2.1, 4, 0x6a5a4a, OX - 3.55, 1.05, 12)
	fb(.6, 2.1, 1.6, 0x6a5a4a, OX + 3.55, 1.05, 10)
	for i in 5:
		var c: int = [0xc0502a, 0x2f6f8f, 0x4c9a6a, 0xe8a03a, 0x8a3fa0][i]
		for k in 3:
			box(.4, .3, .5, c, OX - 3.3, .5 + i * .42, 10.6 + k * 1.1)
			box(.4, .3, .5, c, OX + 3.3, .5 + i * .42, 9.5 + k * .5)
	fb(2.4, .9, .7, 0xefe6d6, OX, .45, 10.2)
	poster(OX - 1, 1.7, 9.12, "ALMACÉN", "Piezas y repuestos", "#8a6a2a")
	# Soporte N2, Marketing, Legal, Capacitación
	d2(OX - 2.4, 16.3)
	d2(OX + .4, 16.3)
	fb(.5, 1.6, .9, 0x8a9aa8, OX + 3.5, .8, 17.5)
	poster(OX - 3, 1.7, 15.12, "N2", "Escalamiento", "#2f6f8f")
	d2(OX + 10.4, 4.3)
	d2(OX + 13.6, 4.3)
	poster(OX + 9, 1.7, 3.12, "MARKETING", "Campañas", "#c0306a")
	d2(OX + 10.4, 10.3)
	d2(OX + 13.6, 10.3)
	fb(.5, 1.6, .9, 0x8a9aa8, OX + 15.5, .8, 13)
	poster(OX + 9, 1.7, 9.12, "LEGAL", "Contratos", "#5a4a2a")
	d2(OX + 10.4, 16.4)
	fb(3, .08, 1.2, 0x8a5a2a, OX + 13, .75, 19.3)
	tv(OX + 7.86, 1.8, 1.9, -PI / 2, 1.4)
	ACT.append({"x": OX + 6, "z": -2.2, "r": 1.6, "elev": 1, "to": 0, "l": "⬇ Bajar al piso 1 (E)"})
	ACT.append({"x": OX - 1.6, "z": 5.7, "r": 1.6, "bench": "bench", "l": "🔧 Banco de reparación (E)"})
	ACT.append({"x": OX, "z": 11.4, "r": 1.6, "bench": "store", "l": "📦 Almacén de piezas (E)"})


func _build_npcs() -> void:
	for n in [["Marta", 11.5, 5.3, 0xd05a7a], ["Luis", -1.5, 17.3, 0x4c7ad0], ["Carlos", 11.5, 11.3, 0x6a9a4c],
			["Andrea", -2.4, 5.15, 0xd05a7a], ["Mailer", .4, 5.15, 0x4c7ad0]]:
		var p := person(n[3], n[0], true)
		p.position = Vector3(n[1], 0, n[2])
		p.rotation.y = PI
		npcs.append(p)


# ============================================================ interacción ====
func ok(x: float, z: float) -> bool:
	for d in DK:
		if absf(x - d[0]) < d[2] and absf(z - d[1]) < d[3]:
			return false
	for r in WK:
		if x > r[0] and x < r[1] and z > r[2] and z < r[3]:
			return true
	return false


func clear(x0: float, z0: float, x1: float, z1: float) -> bool:
	var n := int(ceil(Vector2(x1 - x0, z1 - z0).length() / .3))
	for i in n + 1:
		if not ok(x0 + (x1 - x0) * i / maxf(n, 1), z0 + (z1 - z0) * i / maxf(n, 1)):
			return false
	return true


func label_for(a: Dictionary) -> String:
	if a.has("seek"):
		return ("Atender a %s (E)" % seek["name"]) if not seek.is_empty() else ""
	if a.has("home"):
		var nt: Dictionary = Game.G["nt"]
		return a["l"] if Game.at_home and (a["home"] == "sleep" or int(nt.get(a["home"], 0)) == 0) else ""
	if a.has("dc"):
		return a["l"] if Game.net < 3 else ""
	if a.has("lc"):
		return a["lc"] if Game.pending_at(int(a["loc"])) else ""
	if a.has("l"):
		return a["l"]
	if a.has("loc") and Game.pending_at(int(a["loc"])):
		return "Atender a %s en sitio (E)" % Game.STN[int(a["loc"])]["name"]
	return ""


func near() -> Dictionary:
	if Game.sitting:
		return {}
	var best := {}
	var bd := 9.0
	var p := Vector2(cam.position.x, cam.position.z)
	for a in ACT:
		var d := p.distance_to(Vector2(a["x"], a["z"]))
		if d < a["r"] and d < bd:
			best = a
			bd = d
	if not seek.is_empty():
		var d := p.distance_to(Vector2(seek["x"], seek["z"]))
		if d < 2.6 and d < bd:
			best = {"seek": 1, "loc": 4}
	return best


func interact() -> void:
	var a := near()
	if a.is_empty() or label_for(a) == "":
		return
	if a.has("home"):
		if Game.home_action(a["home"]):
			cam.position = Vector3(-1, 1.6, 2)
			yaw = 0
			pitch = 0
		return
	if Game.time >= Game.END:
		return
	if a.has("dc"):
		ui.open_switch()
	elif a.has("elev"):
		var up: bool = int(a["to"]) == 1
		cam.position = Vector3(OX + 6 if up else 6.0, 1.6, -1.2)
		yaw = PI
		pitch = 0
		Game.toast("⬆ Piso 2: Taller, Almacén, Soporte N2, Marketing, Legal y Capacitación" if up else "⬇ Piso 1: Recepción, Gerencia y departamentos", 3.5)
		if up:
			Game.ach("f2")
	elif a.has("bench"):
		ui.open_bench(a["bench"])
	elif a.has("seek"):
		ui.open_desk(4, int(seek["t"]))
	else:
		var loc := int(a["loc"])
		var n := Game.first_open(loc)
		ui.open_desk(loc, n)


func _on_home() -> void:
	if Game.at_home:
		cam.position = Vector3(8.8, 1.6, 0)
		yaw = -PI / 2
	else:
		cam.position = Vector3(-1, 1.6, 2)
		yaw = 0
	pitch = 0
	_end_seek(true)
	seek_at = Time.get_ticks_msec() + 12000.0


# ======================================================== usuarios que buscan ====
func _spawn_seek() -> void:
	var i := -1
	for j in Game.tickets.size():
		if int(Game.tickets[j]["loc"]) == 4 and Game.tstate[j] == -1:
			i = j
			break
	if i < 0:
		return
	var k: Dictionary = Game.tickets[i]
	var px := cam.position.x
	var pz := cam.position.z
	var sp := Vector2.ZERO
	var found := false
	for d in [6.0, 4.5, 3.2]:
		for _a in 14:
			var an := randf() * TAU
			var x: float = px + cos(an) * d
			var z: float = pz + sin(an) * d
			if ok(x, z) and clear(x, z, px, pz):
				sp = Vector2(x, z)
				found = true
				break
		if found:
			break
	if not found:
		return
	var g := person(int(k["col"]), k["who"])
	g.position = Vector3(sp.x, 0, sp.y)
	seek = {"t": i, "g": g, "x": sp.x, "z": sp.y, "name": k["who"], "born": Time.get_ticks_msec() / 1000.0, "lost": 0.0}
	Game.toast("📣 %s te busca para pedirte ayuda" % k["who"], 4.0)


func _end_seek(good: bool) -> void:
	if seek.is_empty():
		return
	seek["g"].queue_free()
	var nm: String = seek["name"]
	seek = {}
	if not good:
		Game.sat = maxi(0, Game.sat - 3)
		Game.hud()
		Game.toast("%s se cansó de esperar (−3 satisfacción)" % nm)
	seek_at = Time.get_ticks_msec() + (15000.0 if good else 20000.0)


func _on_ticket_resolved(i: int) -> void:
	if not seek.is_empty() and seek["t"] == i:
		_end_seek(true)


func _seek_update(dt: float) -> void:
	if seek.is_empty():
		return
	var px := cam.position.x
	var pz := cam.position.z
	var dx: float = px - seek["x"]
	var dz: float = pz - seek["z"]
	var d := maxf(Vector2(dx, dz).length(), .001)
	if d > 1.7:
		var v := minf(1.8 * dt, d - 1.7)
		seek["x"] += dx / d * v
		seek["z"] += dz / d * v
	if not clear(seek["x"], seek["z"], px, pz):
		seek["lost"] += dt
		if seek["lost"] > 1.5:
			var bx := px + sin(yaw) * 2.2
			var bz := pz + cos(yaw) * 2.2
			if ok(bx, bz):
				seek["x"] = bx
				seek["z"] = bz
			seek["lost"] = 0.0
	else:
		seek["lost"] = 0.0
	var g: Node3D = seek["g"]
	g.position = Vector3(seek["x"], absf(sin(Time.get_ticks_msec() / 160.0)) * .04 if d > 1.9 else 0.0, seek["z"])
	g.rotation.y = atan2(dx, dz)
	if not Game.sitting and Time.get_ticks_msec() / 1000.0 - seek["born"] > 70.0 + Game.sk("comm") * 15.0:
		_end_seek(false)


# ================================================================== pantallas ====
func _on_changed() -> void:
	desk_label.text = "Zoho Desk — CAA Corp\n%d tickets pendientes\nAlertas de red: %d" % [Game.open_tickets(), Game.alerts()]
	clock_label.text = Game.time_str()
	for i in st_screens.size():
		var pend: bool = Game.pending_at(i + 1)
		var s: Dictionary = st_screens[i]
		s["mat"].albedo_color = Color("a63b2f") if pend else Color("2f6f8f")
		s["label"].text = ("⚠ %s necesita\nayuda\nEsperando a TI" % Game.STN[i + 1]["name"]) if pend else ""


func _update_ads(t: float) -> void:
	var a: Array = Data.ADS[int(t / 4.0) % Data.ADS.size()]
	for tvd in tvs:
		tvd["mat"].albedo_color = Color(a[2])
		tvd["label"].text = "%s\n%s" % [a[0], a[1]]


func _place_name() -> String:
	var x := cam.position.x
	if x > 30:
		return "Piso 2"
	if x < -4:
		return "Data center"
	if x < 4:
		return "Oficina"
	if x < 8:
		return "Pasillo"
	return "Apartamento" if cam.position.z < 3.0 else "Oficinas"


# ====================================================================== bucle ====
func _unhandled_input(e: InputEvent) -> void:
	if Game.sitting:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * .003
		pitch = clampf(pitch - e.relative.y * .003, -1.2, 1.2)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_E:
			interact()
		elif e.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	dt = minf(dt, .05)
	if Game.sitting:
		ui.set_prompt("")
		return
	if _tint_time != Game.time:
		_tint_time = Game.time
		_tint()
	if t - _ad_t > 1.0:
		_ad_t = t
		_update_ads(t)
	if t - _led_t > .35:
		_led_t = t
		for m in leds:
			if randf() < .25:
				m.albedo_color = Color("111111") if randf() < .4 else Color.hex((LED_COLS[randi() % 4] << 8) | 0xFF)
	# movimiento
	var K := Input
	var f := (1 if K.is_physical_key_pressed(KEY_W) or K.is_physical_key_pressed(KEY_UP) else 0) - (1 if K.is_physical_key_pressed(KEY_S) or K.is_physical_key_pressed(KEY_DOWN) else 0)
	var s := (1 if K.is_physical_key_pressed(KEY_D) else 0) - (1 if K.is_physical_key_pressed(KEY_A) else 0)
	if K.is_physical_key_pressed(KEY_LEFT):
		yaw += dt * 1.8
	if K.is_physical_key_pressed(KEY_RIGHT):
		yaw -= dt * 1.8
	var run := 1.6 if K.is_physical_key_pressed(KEY_SHIFT) else 1.0
	var l := Vector2(s, f).length()
	var sp := 2.6 * dt * run / maxf(l, 1.0)
	var nx := cam.position.x + (-sin(yaw) * f + cos(yaw) * s) * sp
	var nz := cam.position.z + (-cos(yaw) * f - sin(yaw) * s) * sp
	if ok(nx, cam.position.z):
		cam.position.x = nx
	if ok(cam.position.x, nz):
		cam.position.z = nz
	cam.rotation = Vector3(pitch, yaw, 0)
	bob_t += dt * (1.0 if l > 0 else 0.0)
	cam.position.y = 1.6 + (sin(bob_t * 7.0) * .03 if l > 0 else 0.0)
	_seek_update(dt)
	if Time.get_ticks_msec() > seek_at and seek.is_empty() and not Game.at_home and not Game.over:
		_seek_t += dt
		if _seek_t > 1.0:
			_seek_t = 0.0
			_spawn_seek()
	var a := near()
	var lb := label_for(a) if not a.is_empty() else ""
	ui.set_prompt(lb if Game.time < Game.END else "")
	var pl := _place_name()
	if pl != _place:
		_place = pl
		ui.set_place(pl)
