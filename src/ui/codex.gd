extends Control
## Every material the game can put on a board, with what light does when it
## meets one. The pictures run the same `RayTracer` the levels do, so nothing
## here can claim behaviour the game would not produce.
##
## Open from the start: knowing that diamond bends harder than water is not a
## spoiler, it is the table a player is meant to reason from


## the frame the pictures are drawn in, to the right of the list
const BOARD := Rect2(430, 90, 700, 270)
const BEAM := Color(0.45, 1.00, 0.55)
const AXLE := Color(1.0, 0.86, 0.52)
const DIM := Color(0.62, 0.72, 0.88)
const LIST_W := 250
## a line of body text with the theme's spacing on it, and how many lines each
## row under the picture has to hold. The facts run to four on a crystal or a
## rotary liquid, and no trivia entry wraps past two
const LINE_H := 28
const FACTS_H := 4 * LINE_H
const TRIVIA_H := 2 * LINE_H
const ROW_GAP := 14
## a ball rather than a slab: light meets a curved face at every angle from head
## on to grazing, and no corner ever gets in the way
const BALL_R := 96.0
## the two handles the beam is moved by, and how near a click has to land
const HANDLE_R := 11.0
const GRAB := 18.0
## the shortest the beam may be made, so the two handles never sit on top of
## each other and leave no direction to read
const MIN_AIM := 90.0
## what ← → turn the beam by, and how far a rotary body may be grown
const TURN_STEP := deg_to_rad(2.0)
const ROTARY := {"lo": 40.0, "hi": 92.0, "from": 62.0, "step": 2.0}
## a held arrow key waits this long, then steps this often
const HOLD_DELAY := 0.32
const HOLD_STEP := 0.045

var keys: Array = []
var at := 0
var list: ScrollContainer
var buttons: Array = []
var facts: Label
var trivia: Label
var live_label: Label
var hint: Label
## both ends of the beam sit on the frame, so neither ever fights a body for a
## click. The same arrangement the editor uses
var root := Vector2.ZERO
var tip := Vector2.ZERO
## how long the rotary body is across, which is the one thing ← → change there
var span := ROTARY.from
var drag := ""
var held_for := 0.0


func _ready() -> void:
	theme = UiTheme.make()
	# a Control that stops the pointer would eat the drag before it arrives
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# nothing new crosses a page while it is being read
	SkyState.allow_beams(false)
	for key: String in OpticsMaterials.BY_INDEX:
		keys.append(key)
	for key: String in OpticsMaterials.REFLECTIVE_ORDER:
		keys.append(key)
	_build()
	_select(0)


func _build() -> void:
	var title := Label.new()
	title.text = Lang.t("codex.title")
	title.position = Vector2(150, 24)
	title.custom_minimum_size = Vector2(980, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)
	list = ScrollContainer.new()
	list.position = Vector2(150, 90)
	list.custom_minimum_size = Vector2(LIST_W, 476)
	list.size = Vector2(LIST_W, 476)
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(list)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	list.add_child(col)
	for i in keys.size():
		var b := Button.new()
		b.text = _label(keys[i])
		b.custom_minimum_size = Vector2(LIST_W - 14, 32)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select.bind(i))
		col.add_child(b)
		buttons.append(b)
	var facts_y := BOARD.end.y + 18.0
	facts = _line(Vector2(BOARD.position.x, facts_y), FACTS_H, DIM)
	# the real world half, kept a different colour so it does not read as more
	# numbers to work with
	var trivia_y := facts_y + FACTS_H + ROW_GAP
	trivia = _line(Vector2(BOARD.position.x, trivia_y), TRIVIA_H, Color(0.86, 0.78, 0.62))
	trivia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live_label = _line(Vector2(BOARD.position.x, trivia_y + TRIVIA_H + ROW_GAP), LINE_H, Color(0.9, 0.93, 0.97))
	# lined up under the picture with the rest of the right hand column, a notch
	# smaller than the facts so it reads as an aside
	hint = _line(Vector2(BOARD.position.x, 626), 22, DIM)
	hint.add_theme_font_size_override("font_size", 15)
	var back := Button.new()
	back.text = Lang.t("back_menu")
	back.position = Vector2(150, 580)
	back.custom_minimum_size = Vector2(LIST_W, 38)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_to_menu)
	add_child(back)


func _line(at_p: Vector2, height: int, col: Color) -> Label:
	var l := Label.new()
	l.position = at_p
	l.custom_minimum_size = Vector2(BOARD.size.x, height)
	l.size = Vector2(BOARD.size.x, height)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _label(key: String) -> String:
	return OpticsMaterials.label_of(key)


func _select(i: int) -> void:
	at = clampi(i, 0, keys.size() - 1)
	span = ROTARY.from
	held_for = 0.0
	drag = ""
	_reset_beam()
	for k in buttons.size():
		(buttons[k] as Button).add_theme_color_override("font_color", BEAM if k == at else Color(0.9, 0.93, 0.97))
	# stepping with the arrow keys walks off the bottom of the list otherwise
	list.ensure_control_visible(buttons[at])
	facts.text = _facts()
	trivia.text = str((TRIVIA_EN if Lang.en() else TRIVIA).get(_key(), ""))
	hint.text = Lang.t("codex.hint_rotary") if _turns() else Lang.t("codex.hint_beam")
	queue_redraw()


## Aimed to show the material off: across the ball off centre, or down onto the
## mirror at an angle worth reading
func _reset_beam() -> void:
	var c := BOARD.get_center()
	if _turns():
		root = Vector2(BOARD.position.x, c.y)
		tip = Vector2(BOARD.end.x, c.y)
		return
	if _metal():
		var d := Vector2(sin(deg_to_rad(38.0)), cos(deg_to_rad(38.0)))
		var ends := _frame_ends(c, d)
		root = ends[0]
		tip = ends[1]
		return
	var y := c.y - BALL_R * sin(deg_to_rad(38.0))
	root = Vector2(BOARD.position.x, y)
	tip = Vector2(BOARD.end.x, y)


## Where a line through `through` running along `d` meets the frame, entry first
func _frame_ends(through: Vector2, d: Vector2) -> Array:
	var back := Isect.ray_rect_exit(through, -d, BOARD)
	var fore := Isect.ray_rect_exit(through, d, BOARD)
	var a: Vector2 = back.point if not back.is_empty() else through - d * MIN_AIM
	var b: Vector2 = fore.point if not fore.is_empty() else through + d * MIN_AIM
	return [a, b]


func _dir() -> Vector2:
	var away := tip - root
	return away.normalized() if away.length() > 1e-6 else Vector2.RIGHT


func _key() -> String:
	return keys[at]


func _metal() -> bool:
	return OpticsMaterials.REFLECTIVE.has(_key())


func _turns() -> bool:
	return OpticsMaterials.is_rotary(_key())


func _facts() -> String:
	var key := _key()
	if _metal():
		var back: float = OpticsMaterials.REFLECTIVE[key].reflectance
		return "\n".join([Lang.t("codex.reflectance") % (back * 100.0),
				Lang.t("codex.absorbs") % (back * 100.0), Lang.t("codex.no_refract")])
	var mat: Dictionary = OpticsMaterials.TRANSPARENT[key]
	var n: float = mat.n
	var lines: Array = [Lang.t("codex.n") % n,
			Lang.t("codex.speed") % (100.0 / n),
			Lang.t("codex.critical") % rad_to_deg(Optics.critical_angle(n, OpticsMaterials.AIR))]
	if mat.has("ne"):
		# no subscript letters in the UI font, so the two indices are named out
		var sign_of := Lang.t("codex.positive") if mat.ne > n else Lang.t("codex.negative")
		lines.append(Lang.t("codex.birefringent") % [n, mat.ne, sign_of])
	if mat.has("rotation"):
		var hand := Lang.t("codex.dextro") if mat.rotation > 0.0 else Lang.t("codex.levo")
		lines.append(Lang.t("codex.rotary") % [mat.rotation, hand])
	return "\n".join(lines)


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if not key_ev.pressed or key_ev.echo:
			return
		match key_ev.keycode:
			KEY_ESCAPE:
				_to_menu()
			KEY_LEFT:
				_turn(-1)
			KEY_RIGHT:
				_turn(1)
			KEY_UP:
				_select(at - 1)
			KEY_DOWN:
				_select(at + 1)
		return
	# a rotary body is sized rather than aimed at, so its beam stays put
	if _turns():
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if not click.pressed:
			drag = ""
			return
		drag = _grabbed(click.global_position)
		if not drag.is_empty():
			_on_drag(click.global_position)
		return
	if event is InputEventMouseMotion and not drag.is_empty():
		if ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			drag = ""
			return
		_on_drag((event as InputEventMouseMotion).global_position)


func _grabbed(pos: Vector2) -> String:
	if pos.distance_to(root) <= GRAB:
		return "root"
	if pos.distance_to(tip) <= GRAB:
		return "tip"
	return ""


## Both ends stay on the frame, and the beam is never allowed to get so short
## that there is no direction left to read off it
func _on_drag(pos: Vector2) -> void:
	var want := _on_frame(pos)
	var other: Vector2 = tip if drag == "root" else root
	if want.distance_to(other) < MIN_AIM:
		return
	if drag == "root":
		root = want
	else:
		tip = want
	queue_redraw()


func _on_frame(pos: Vector2) -> Vector2:
	var x := clampf(pos.x, BOARD.position.x, BOARD.end.x)
	var y := clampf(pos.y, BOARD.position.y, BOARD.end.y)
	var gaps := [y - BOARD.position.y, BOARD.end.y - y, x - BOARD.position.x, BOARD.end.x - x]
	var near: float = (gaps as Array).min()
	if near == gaps[0]:
		return Vector2(x, BOARD.position.y)
	if near == gaps[1]:
		return Vector2(x, BOARD.end.y)
	return Vector2(BOARD.position.x if near == gaps[2] else BOARD.end.x, y)


## Read off the keyboard rather than off key events, so letting go while the
## window is not focused cannot leave the beam turning by itself
func _process(delta: float) -> void:
	# the sky drifts underneath, so this cannot wait for something to change
	queue_redraw()
	var step := (1 if Input.is_key_pressed(KEY_RIGHT) else 0) - (1 if Input.is_key_pressed(KEY_LEFT) else 0)
	if step == 0:
		held_for = 0.0
		return
	held_for += delta
	while held_for >= HOLD_DELAY:
		_turn(step)
		held_for -= HOLD_STEP


func _turn(step: int) -> void:
	if _turns():
		span = clampf(span + ROTARY.step * step, ROTARY.lo, ROTARY.hi)
		queue_redraw()
		return
	# ← → swing the beam about its root, which is the same thing the tip handle
	# does by hand
	var turned := _dir().rotated(TURN_STEP * step)
	var far := Isect.ray_rect_exit(root + turned * 0.5, turned, BOARD)
	if far.is_empty() or (far.point as Vector2).distance_to(root) < MIN_AIM:
		return
	tip = far.point
	queue_redraw()


## Labels and buttons are children, so they land on top of everything drawn here
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.07, 0.10), true)
	SkyState.paint(self)
	draw_rect(BOARD.grow(8.0), Color(0.085, 0.105, 0.15), true)
	draw_rect(BOARD, Color(0.045, 0.055, 0.085), true)
	draw_rect(BOARD, Color(0.45, 0.55, 0.75, 0.8), false, 2.0)
	if _metal():
		_draw_metal()
	elif _turns():
		_draw_rotary()
	else:
		_draw_ball()
	if not _turns():
		_handle(root)
		_handle(tip)


func _handle(at_p: Vector2) -> void:
	draw_circle(at_p, HANDLE_R, Color(0.10, 0.13, 0.18, 0.9))
	draw_arc(at_p, HANDLE_R, 0.0, TAU, 24, Color(AXLE, 0.9), 2.0, true)


func _draw_ball() -> void:
	var c := BOARD.get_center()
	var key := _key()
	var mat: Dictionary = OpticsMaterials.TRANSPARENT[key]
	var axis := deg_to_rad(35.0) if OpticsMaterials.is_crystal(key) else 0.0
	var ball := ProblemGen.make_object("circle", key, c, BALL_R, 0.0, axis)
	var d := _dir()
	_traced([ball], root, d)
	var hit := Isect.ray_circle(root, d, c, BALL_R)
	if hit.is_empty():
		live_label.text = Lang.t("codex.miss_ball")
		return
	var face: Vector2 = hit.normal
	_normal(hit.point, face)
	var cos_i := clampf(-d.dot(face), 0.0, 1.0)
	var share := Optics.reflectance(d, face, OpticsMaterials.AIR, mat.n)
	var bent := asin(clampf(sqrt(maxf(1.0 - cos_i * cos_i, 0.0)) * OpticsMaterials.AIR / mat.n, 0.0, 1.0))
	var text := Lang.t("codex.ball_live") % [rad_to_deg(acos(cos_i)), rad_to_deg(bent), share * 100.0]
	if OpticsMaterials.is_crystal(key):
		text += Lang.t("codex.splits")
	live_label.text = text


func _draw_metal() -> void:
	var c := BOARD.get_center()
	var key := _key()
	var mir := ProblemGen.make_object("mirror", key, c, BOARD.size.x * 0.30, 0.0, 0.0)
	var d := _dir()
	_traced([mir], root, d)
	var hit := Isect.ray_segment(root, d, mir.a, mir.b)
	var back: float = OpticsMaterials.REFLECTIVE[key].reflectance
	if hit.is_empty():
		live_label.text = Lang.t("codex.miss_mirror")
		return
	_normal(hit.point, hit.normal)
	live_label.text = Lang.t("codex.metal_live") % [
			rad_to_deg(acos(clampf(-d.dot(hit.normal), 0.0, 1.0))), back * 100.0]


## The one kind that shows nothing by itself: between crossed sheets, how much
## gets through is the turn the body put on the plane
func _draw_rotary() -> void:
	var c := BOARD.get_center()
	var key := _key()
	var body := ProblemGen.make_object("circle", key, c, span, 0.0, 0.0)
	var turn := rad_to_deg(OpticsMaterials.rotary(key) * span * 2.0)
	var res := _traced([_sheet_at(c.x - 250.0, c.y, 0.0), body, _sheet_at(c.x + 250.0, c.y, PI * 0.5)],
			Vector2(BOARD.position.x + 4.0, c.y), Vector2.RIGHT)
	for i in 3:
		_dial(Vector2(c.x - 220.0 + i * 34.0, c.y), 0.0)
	if not res.exits.is_empty():
		for i in 3:
			_dial(Vector2(c.x + span + 30.0 + i * 34.0, c.y), deg_to_rad(turn))
	var through: float = 0.0 if res.exits.is_empty() else res.exits[0].intensity
	live_label.text = Lang.t("codex.rotary_live") % [
			span * 2.0, span * 2.0 * OpticsMaterials.PX_MM, turn, through * 100.0]


func _sheet_at(x: float, y: float, phi: float) -> SceneObj:
	return ProblemGen.make_object("polarizer", "polarizer", Vector2(x, y), 92.0, 0.0,
			PI * 0.5, PolarizerObj.byte_from_phi(phi))


func _dial(at_p: Vector2, phi: float) -> void:
	var arm := Vector2.from_angle(PI * 0.5 - phi) * 13.0
	draw_line(at_p - arm, at_p + arm, Color(AXLE, 0.9), 2.0, true)


func _normal(at_p: Vector2, face: Vector2) -> void:
	var reach := 64.0
	draw_dashed_line(at_p - face * reach, at_p + face * reach, Color(0.85, 0.88, 0.95, 0.45), 1.5, 7.0, true, true)


## The same tracer the levels run, so a picture here cannot drift from the game
func _traced(objects: Array, from: Vector2, dir: Vector2) -> Dictionary:
	var res := RayTracer.trace(objects, BOARD, from, dir, {"fresnel": true, "min_intensity": 0.01, "max_events": 48})
	for obj: SceneObj in objects:
		FieldDraw.shape(self, obj)
	for seg: Dictionary in res.segments:
		var i: float = seg.intensity
		draw_line(seg.a, seg.b, Color(0.30, 0.90, 0.45, 0.10 + 0.20 * i), 7.0 + 6.0 * sqrt(i), true)
		draw_line(seg.a, seg.b, Color(BEAM, clampf(0.3 + 0.7 * i, 0.0, 1.0)), 1.2 + 1.8 * sqrt(i), true)
	FieldDraw.source(self, from, dir, 0.0)
	return res


## What the material is away from the board. The indices above decide the puzzle,
## these decide whether the name means anything to the person reading it
const TRIVIA := {
	"aerogel": "SiO₂ の骨格に 99 % 以上の空気を抱えた固体です．断熱材のほか，探査機が宇宙塵を壊さずに捕まえるのにも使われました．",
	"water": "H₂O．屈折率の基準としてよく引かれます．水中の物が浅い位置に見えるのも，底からの光が水面で曲がるためです．",
	"ethanol": "C₂H₅OH．消毒用アルコールの主成分で，水よりわずかに強く光を曲げます．",
	"fructose": "C₆H₁₂O₆．果物や蜂蜜に含まれる糖で，偏光面を左へ回すので左旋糖とも呼ばれます．",
	"fluorite": "CaF₂．分散が小さく色のにじみが出にくいため，望遠鏡やカメラの高性能レンズに使われます．蛍光 (fluorescence) はこの鉱物の名から来ています．",
	"sucrose": "C₁₂H₂₂O₁₁．いわゆる砂糖です．偏光面を右へ回す量から濃度を測る旋光計があり，製糖の現場で使われています．",
	"silica": "SiO₂．紫外線をよく通すので殺菌ランプに使われ，不純物を抑えたものは光ファイバになります．",
	"limonene": "C₁₀H₁₆．柑橘の皮に含まれる油で，オレンジの香りの正体です．鏡像の関係にある分子は別の匂いに感じられます．",
	"turpentine": "マツの樹脂から採る油で，主成分はピネン C₁₀H₁₆．塗料の希釈や松脂の原料に使われます．",
	"acrylic": "PMMA．ガラスより軽く割れにくいので，水族館の大型水槽の壁に使われます．",
	"bk7": "ホウケイ酸クラウンガラス．レンズやプリズムの標準的な材料で，光学系の性能を比べるときの基準にもなります．",
	"soda_glass": "窓ガラスや瓶の材料で，世の中で作られるガラスの大半がこれです．",
	"quartz": "SiO₂ の結晶．押すと電気が出る圧電性があり，切り出した薄片の振動が腕時計の精度を支えています．",
	"polycarb": "PC．強い衝撃でも割れにくいので，眼鏡のレンズや防護板に使われます．",
	"carbon_disulfide": "CS₂．屈折率も分散も大きく，かつては液体プリズムに詰められました．引火しやすく毒性があります．",
	"calcite": "CaCO₃．透明なものはアイスランドスパーと呼ばれ，複屈折の発見とニコルプリズムの材料になりました．",
	"sapphire": "Al₂O₃ (コランダム)．モース硬度9で傷が付きにくく，腕時計の風防や耐傷窓に使われます．",
	"sf11": "重フリントガラス．屈折率も分散も大きく，色消しレンズではクラウンガラスと組にして使われます．",
	"zirconia": "ZrO₂ を安定化した結晶．屈折率と分散がダイヤモンドに近いので，模造石として広く出回っています．",
	"diamond": "炭素の結晶．屈折率が高く臨界角が 24 度しかないため，内部で反射を繰り返してから出てきます．ブリリアントカットはこれを狙った形です．",
	"rutile": "TiO₂．身近な結晶では複屈折が最大級で，白色顔料チタンホワイトの原料でもあります．",
	"gallium_phosphide": "GaP．半導体で，緑や赤の LED に使われます．550 nm より短い波長を吸うので橙色に見えます．",
	"mirror": "実在しない理想の鏡です．当たった光を1つも失わずに返します．",
	"silver": "Ag．可視光の反射率は金属で最も高く，古くから鏡や望遠鏡に使われました．硫化して曇るのが弱点です．",
	"aluminum": "Al．曇りにくいので，いまの望遠鏡の鏡はこれを蒸着します．紫外線もよく反射します．",
}


const TRIVIA_EN := {
	"aerogel": "A solid that is over 99 % air held in a skeleton of SiO₂. It insulates, and it caught cosmic dust intact on a space probe.",
	"water": "H₂O. The usual reference for refractive index. Things underwater look shallower than they are because light from the bottom bends at the surface.",
	"ethanol": "C₂H₅OH. The alcohol in disinfectant, and it bends light a little harder than water does.",
	"fructose": "C₆H₁₂O₆. The sugar in fruit and honey. It turns the plane of polarization left, which is why it is also called levulose.",
	"fluorite": "CaF₂. Low dispersion means little colour fringing, so it goes into high end lenses. Fluorescence is named after this mineral.",
	"sucrose": "C₁₂H₂₂O₁₁. Table sugar. Polarimeters read concentration off how far it turns the plane to the right, and sugar refineries use them.",
	"silica": "SiO₂. It passes ultraviolet well enough for germicidal lamps, and the purest of it becomes optical fibre.",
	"limonene": "C₁₀H₁₆. The oil in citrus peel and the source of the orange smell. Its mirror image molecule smells like something else.",
	"turpentine": "Oil distilled from pine resin, mostly pinene C₁₀H₁₆. Used to thin paint and as a source of rosin.",
	"acrylic": "PMMA. Lighter than glass and harder to break, which is why the big aquarium tanks are made of it.",
	"bk7": "Borosilicate crown glass. The standard material for lenses and prisms, and the baseline other optics get compared against.",
	"soda_glass": "What windows and bottles are made of, and most of the glass in the world.",
	"quartz": "Crystalline SiO₂. It is piezoelectric, and a thin slice of it vibrating keeps a wristwatch accurate.",
	"polycarb": "PC. It survives hard impacts, so it goes into eyeglass lenses and safety shields.",
	"carbon_disulfide": "CS₂. High index and high dispersion, once poured into liquid prisms. It catches fire easily and is toxic.",
	"calcite": "CaCO₃. Clear pieces are called Iceland spar, and they gave us both the discovery of birefringence and the Nicol prism.",
	"sapphire": "Al₂O₃ (corundum). Mohs hardness 9 and hard to scratch, so watch crystals and scratch resistant windows are made of it.",
	"sf11": "Dense flint glass. High index and high dispersion, paired with crown glass to make an achromatic lens.",
	"zirconia": "Stabilized ZrO₂. Its index and dispersion are close to diamond, so it turns up everywhere as an imitation stone.",
	"diamond": "Crystalline carbon. Its critical angle is only 24 degrees, so light bounces around inside before it escapes. The brilliant cut is shaped for that.",
	"rutile": "TiO₂. About the largest birefringence among everyday crystals, and the raw material for titanium white.",
	"gallium_phosphide": "GaP. A semiconductor used in green and red LEDs. It absorbs wavelengths shorter than 550 nm, hence the orange.",
	"mirror": "An ideal mirror, which does not exist. It sends back every bit of the light it is given.",
	"silver": "Ag. The highest visible reflectance of any metal, used for mirrors and telescopes for centuries. Tarnishing to sulfide is its weakness.",
	"aluminum": "Al. It does not tarnish, so telescope mirrors are coated with it now. It reflects ultraviolet well too.",
}
