extends Control
## One gimmick at a time, picked on the screen before this one. Every topic ends
## on a page you can move, and those run the real optics rather than a drawing of
## it, so the tutorial and the game never drift apart


## the frame the diagrams are drawn in, lined up with the play screen's
const BOARD := Rect2(150, 96, 980, 364)
const AIR := Color(0.55, 0.70, 0.95)
const GLASS := Color(0.55, 0.85, 0.62)
const BEAM := Color(0.45, 1.00, 0.55)
const AXLE := Color(1.0, 0.86, 0.52)
const DIM := Color(0.62, 0.72, 0.88)
## the glass the fixed diagrams are drawn with
const SLOW := "soda_glass"
## how far a beam runs either side of the surface
const REACH := 168.0
## a held arrow key waits this long, then steps this often
const HOLD_DELAY := 0.32
const HOLD_STEP := 0.045
## what ← → changes on the last page of each topic, and how far it may go. The
## angle topics count degrees off the normal, the others count what they name
const KNOB := {
	# not an angle: which of the four marks is being pointed at
	"rules": {"lo": 0.0, "hi": 3.0, "step": 1.0, "from": 0.0, "drag": "pick"},
	"mirror": {"lo": -88.0, "hi": 88.0, "step": 2.0, "from": 38.0, "drag": "aim"},
	"refract": {"lo": -88.0, "hi": 88.0, "step": 2.0, "from": 38.0, "drag": "aim"},
	"critical": {"lo": -88.0, "hi": 88.0, "step": 1.0, "from": 30.0, "drag": "aim"},
	"split": {"lo": -88.0, "hi": 88.0, "step": 2.0, "from": 38.0, "drag": "aim"},
	"sheet": {"lo": 0.0, "hi": 180.0, "step": 5.0, "from": 90.0, "drag": "turn"},
	"crystal": {"lo": 0.0, "hi": 180.0, "step": 5.0, "from": 25.0, "drag": "turn"},
	"spin": {"lo": 42.0, "hi": 104.0, "step": 2.0, "from": 70.0, "drag": ""},
	"grin": {"lo": -100.0, "hi": 100.0, "step": 5.0, "from": 70.0, "drag": ""},
}
const MEDIA := {
	"refract": ["water", "soda_glass", "diamond"],
	"critical": ["soda_glass", "diamond", "gallium_phosphide"],
	"split": ["soda_glass", "diamond", "gallium_phosphide"],
	"spin": ["sucrose", "fructose", "limonene"],
}


var topic := "refract"
var pages: Array = []
var media: Array = []
var page := 0
var title_label: Label
var body_label: Label
var count_label: Label
var back_btn: Button
var next_btn: Button
var media_row: HBoxContainer
var media_btns: Array = []
var flip_btn: Button
var live_label: Label
## how long an arrow key has been down, so a hold carries on where tapping left
## off rather than waiting on the keyboard's own repeat
var held_for := 0.0
## the one thing the last page lets you move, in whatever unit the topic counts
var knob := 38.0
var from_air := true
var medium := "soda_glass"
## the board the rules pages are explained on, traced once at startup
var rules: Dictionary = {}


func _ready() -> void:
	topic = GameState.tutorial_topic if KNOB.has(GameState.tutorial_topic) else "refract"
	pages = TutorialPages.of(topic)
	media = MEDIA.get(topic, [])
	if not media.is_empty():
		medium = media[0]
	knob = KNOB[topic].from
	if topic == "rules":
		_build_rules()
	theme = UiTheme.make()
	# a Control that stops the pointer swallows the click before _unhandled_input
	# ever sees it, which left the last page draggable only by keyboard
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# nothing new crosses a page while it is being read. The rules are the
	# exception: they are what a beam is, so one going past belongs there
	SkyState.allow_beams(topic == "rules")
	title_label = Label.new()
	title_label.position = Vector2(150, 36)
	title_label.custom_minimum_size = Vector2(980, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	add_child(title_label)
	body_label = Label.new()
	# three lines of room: the longer entries run that far and the row below has
	# to stay clear of them
	body_label.position = Vector2(190, 470)
	body_label.custom_minimum_size = Vector2(900, 78)
	body_label.size = Vector2(900, 78)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("font_color", DIM)
	add_child(body_label)
	_build_controls()
	_show_page(0)


func _build_controls() -> void:
	live_label = Label.new()
	live_label.position = Vector2(150, 556)
	live_label.custom_minimum_size = Vector2(980, 0)
	live_label.size = Vector2(980, 26)
	live_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(live_label)
	media_row = HBoxContainer.new()
	media_row.position = Vector2(150, 590)
	media_row.custom_minimum_size = Vector2(980, 0)
	media_row.alignment = BoxContainer.ALIGNMENT_CENTER
	media_row.add_theme_constant_override("separation", 8)
	add_child(media_row)
	for key: String in media:
		var b := Button.new()
		b.text = "%s n=%.3f" % [OpticsMaterials.label_of(key), OpticsMaterials.TRANSPARENT[key].n]
		b.custom_minimum_size = Vector2(220, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			medium = key
			_refresh())
		media_row.add_child(b)
		media_btns.append(b)
	flip_btn = Button.new()
	flip_btn.custom_minimum_size = Vector2(180, 34)
	flip_btn.focus_mode = Control.FOCUS_NONE
	# only refraction reads the same either way round. Everywhere else the side
	# the light starts on is the point of the topic
	flip_btn.visible = topic == "refract"
	flip_btn.pressed.connect(func() -> void:
		from_air = not from_air
		_refresh())
	media_row.add_child(flip_btn)

	var bar := HBoxContainer.new()
	bar.position = Vector2(150, 640)
	bar.custom_minimum_size = Vector2(980, 0)
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	back_btn = Button.new()
	back_btn.custom_minimum_size = Vector2(140, 38)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_on_back)
	bar.add_child(back_btn)
	count_label = Label.new()
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", DIM)
	bar.add_child(count_label)
	next_btn = Button.new()
	next_btn.custom_minimum_size = Vector2(140, 38)
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(_on_next)
	bar.add_child(next_btn)


func _show_page(at: int) -> void:
	page = clampi(at, 0, pages.size() - 1)
	title_label.text = pages[page].title
	body_label.text = pages[page].body
	count_label.text = "%d / %d" % [page + 1, pages.size()]
	# the first page steps back out of the topic rather than being a dead end
	back_btn.text = Lang.t("tut.list") if page == 0 else Lang.t("tut.back")
	next_btn.text = Lang.t("tut.done") if page == pages.size() - 1 else Lang.t("tut.next")
	if _live():
		GameState.mark_read(topic)
	media_row.visible = _live() and not media.is_empty()
	live_label.visible = _live()
	_refresh()


func _refresh() -> void:
	if _live():
		flip_btn.text = Lang.t("tut.from_air") if from_air else Lang.t("tut.from_glass")
		for i in media_btns.size():
			var on: bool = media[i] == medium
			(media_btns[i] as Button).add_theme_color_override("font_color", BEAM if on else Color(0.9, 0.93, 0.97))
	queue_redraw()


func _live() -> bool:
	return page == pages.size() - 1


func _on_next() -> void:
	if _live():
		_to_menu()
	else:
		_show_page(page + 1)


func _on_back() -> void:
	if page == 0:
		_to_menu()
	else:
		_show_page(page - 1)


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			_to_menu()
		elif key == KEY_LEFT:
			# the last page has something of its own to move, the rest turn pages
			if _live():
				_turn(-1)
			else:
				_on_back()
		elif key == KEY_RIGHT:
			if _live():
				_turn(1)
			else:
				_show_page(page + 1)
		return
	if not _live() or KNOB[topic].drag.is_empty():
		return
	# dragging reads as pointing the beam, or as turning the thing on the board
	var held: bool = event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if held or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		# the position the event carries, not wherever the pointer is by the time
		# this runs
		var at: Vector2 = (event as InputEventMouse).global_position
		if BOARD.has_point(at):
			_aim(at)


## Read off the keyboard rather than off key events, so letting go while the
## window is not focused cannot leave the knob turning by itself
func _process(delta: float) -> void:
	# the sky drifts underneath, so this cannot wait for something to change
	queue_redraw()
	var dir := (1 if Input.is_key_pressed(KEY_RIGHT) else 0) - (1 if Input.is_key_pressed(KEY_LEFT) else 0)
	if dir == 0 or not _live():
		held_for = 0.0
		return
	held_for += delta
	while held_for >= HOLD_DELAY:
		_turn(dir)
		held_for -= HOLD_STEP


func _turn(step: int) -> void:
	if not _live():
		return
	var top: float = KNOB[topic].hi
	# the rules page steps between marks, and only the decoys that landed far
	# enough apart are there to step between
	if topic == "rules" and not rules.is_empty():
		top = float((rules.choices as Array).size() - 1)
	knob = clampf(knob + KNOB[topic].step * step, KNOB[topic].lo, top)
	queue_redraw()


func _aim(at: Vector2) -> void:
	if KNOB[topic].drag == "pick":
		var marks := _rules_marks()
		var best := 0
		for i in marks.size():
			if (marks[i] as Vector2).distance_to(at) < (marks[best] as Vector2).distance_to(at):
				best = i
		knob = float(best)
		queue_redraw()
		return
	if KNOB[topic].drag == "turn":
		knob = fposmod(rad_to_deg((at - _pivot()).angle()), 180.0)
		queue_redraw()
		return
	# the pointer is taken as a point on the incoming beam. Which side of the
	# surface that is depends on the direction, so only its distance counts
	var back := _pivot() - at
	knob = clampf(rad_to_deg(atan2(back.x, absf(back.y))), KNOB[topic].lo, KNOB[topic].hi)
	queue_redraw()


func _pivot() -> Vector2:
	return Vector2(BOARD.position.x + BOARD.size.x * 0.5, BOARD.position.y + BOARD.size.y * 0.5)


## Labels and buttons are children, so they land on top of everything drawn here
func _draw() -> void:
	var frame := _frame_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.07, 0.10), true)
	SkyState.paint(self)
	draw_rect(frame.grow(8.0), Color(0.085, 0.105, 0.15), true)
	draw_rect(frame, Color(0.045, 0.055, 0.085), true)
	draw_rect(frame, Color(0.45, 0.55, 0.75, 0.8), false, 2.0)
	match topic:
		"rules":
			_draw_rules()
		"mirror":
			_draw_mirror()
		"critical":
			_draw_critical()
		"split":
			_draw_split()
		"sheet":
			_draw_sheet()
		"crystal":
			_draw_crystal()
		"spin":
			_draw_spin()
		"grin":
			_draw_grin()
		_:
			_draw_refract()


## Two mirrors at the same angle, so the light draws an N. Placed by hand rather
## than generated: the first board anybody sees should be readable at a glance,
## and a shape the eye knows beats a fair but arbitrary one. Drawn shrunk at the
## same scale both ways, so no angle is a lie
const RULES_TILT := 0.4783
const RULES_LEFT := Vector2(400, 496)
const RULES_RIGHT := Vector2(880, 156)


## The rules pages stand a shrunk play field inside the tutorial's frame, so the
## frame drawn round them is that one and not the tutorial's own
func _frame_rect() -> Rect2:
	if topic != "rules":
		return BOARD
	var wide := ProblemGen.FIELD.size.x * _rules_scale()
	return Rect2(BOARD.position.x + (BOARD.size.x - wide) * 0.5, BOARD.position.y, wide, BOARD.size.y)


func _rules_scale() -> float:
	return BOARD.size.y / ProblemGen.FIELD.size.y


## A mark sits on the frame, and the body text starts right under it. The play
## screen has room below for one to hang over, this does not
func _inset_mark(p: Vector2) -> Vector2:
	var frame := _frame_rect()
	var out := p
	if absf(p.y - frame.position.y) < 1.0:
		out.y += 16.0
	elif absf(p.y - frame.end.y) < 1.0:
		out.y -= 16.0
	if absf(p.x - frame.position.x) < 1.0:
		out.x += 16.0
	elif absf(p.x - frame.end.x) < 1.0:
		out.x -= 16.0
	return out


func _to_board(p: Vector2) -> Vector2:
	var s := _rules_scale()
	var wide := ProblemGen.FIELD.size.x * s
	var corner := Vector2(BOARD.position.x + (BOARD.size.x - wide) * 0.5, BOARD.position.y)
	return corner + (p - ProblemGen.FIELD.position) * s


## Traced once, so the shape and its wrong answers are settled before any page
## is drawn. The decoys come from misreading the mirrors, which is where the
## game gets its own from
func _build_rules() -> void:
	var f := ProblemGen.FIELD
	var objects := [
		ProblemGen.make_object("mirror", "mirror", RULES_LEFT, 78.0, 0.0, RULES_TILT),
		ProblemGen.make_object("mirror", "mirror", RULES_RIGHT, 78.0, 0.0, RULES_TILT),
	]
	var from := Vector2(RULES_LEFT.x, f.position.y)
	var opts := {"fresnel": false, "min_intensity": 0.02, "max_events": 16}
	var res := RayTracer.trace(objects, f, from, Vector2.DOWN, opts)
	if not res.ok:
		return
	var picks: Array = [res.exits[0].point]
	for slip: String in ["reflect_axis", "normal_bounce"]:
		var wrong := RayTracer.trace(objects, f, from, Vector2.DOWN, {
				"fresnel": false, "min_intensity": 0.02, "max_events": 16, "mistake": slip})
		if not wrong.ok:
			continue
		var p: Vector2 = wrong.exits[0].point
		var clear := true
		for kept: Vector2 in picks:
			if kept.distance_to(p) < 140.0:
				clear = false
		if clear:
			picks.append(p)
	var right: Vector2 = picks[0]
	picks.sort_custom(func(a: Vector2, b: Vector2): return _frame_order(a) < _frame_order(b))
	rules = {"objects": objects, "source": {"p": from, "d": Vector2.DOWN}, "trace": res,
			"choices": picks, "correct": [picks.find(right)]}
	# start on anything but the answer, or the last page opens already solved
	knob = float((picks.find(right) + 1) % picks.size())


## Round the frame, only so the marks get their letters in a sensible order
func _frame_order(p: Vector2) -> float:
	return (p - ProblemGen.FIELD.get_center()).angle()


func _rules_marks() -> Array:
	var out: Array = []
	for p: Vector2 in (rules.choices as Array):
		out.append(_inset_mark(_to_board(p)))
	return out


## Drawn the way the play screen draws its answer markers, since that is what
## the page is teaching the reader to click
func _marker(at: Vector2, letter: String, state: int) -> void:
	var edge := Color(0.55, 0.70, 0.95)
	if state == 2:
		edge = BEAM
	elif state == 1:
		edge = AXLE
	draw_circle(at, 18.0, Color(0.10, 0.14, 0.20, 0.95))
	draw_arc(at, 18.0, 0.0, TAU, 28, edge, 2.5, true)
	var f := theme.default_font
	var dim := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	draw_string(f, at + Vector2(-dim.x * 0.5, f.get_ascent(17) * 0.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, edge)


## Beams and bodies are drawn through the shrinking transform, the marks after it
## so they keep the size a marker really has
func _rules_scene(objects: Array, from: Vector2, dir: Vector2, legs: Array) -> void:
	var s := _rules_scale()
	# in field coordinates from here, since that is what the board was built in
	draw_set_transform(_to_board(Vector2.ZERO), 0.0, Vector2(s, s))
	# shapes only: two mirrors need no naming, and the labels landed on the beam
	for obj: SceneObj in objects:
		FieldDraw.shape(self, obj)
	for seg: Dictionary in legs:
		FieldDraw.beam(self, seg.a, seg.b, seg.intensity, s)
	FieldDraw.source(self, from, dir, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rules() -> void:
	var frame := _frame_rect()
	if rules.is_empty():
		return
	var res: Dictionary = rules.trace
	var right: int = (rules.correct as Array)[0]
	var chosen := clampi(int(knob), 0, (rules.choices as Array).size() - 1)
	# the middle pages hold the path back, which is the whole point of the game
	var told: bool = page == 0 or (_live() and chosen == right)
	_rules_scene(rules.objects, rules.source.p, rules.source.d, res.segments if told else [res.segments[0]])
	var marks := _rules_marks()
	for i in marks.size():
		var state := 0
		if _live():
			state = 2 if chosen == right and i == right else (1 if i == chosen else 0)
		elif i == right and page != 1:
			state = 2
		_marker(marks[i], StageCode.LABELS[i], state)
	if page == 1:
		# above the frame: the marks sit on it, and there is nothing else up there
		_note(Vector2(frame.get_center().x, frame.position.y - 14.0), Lang.t("tut.follow"), DIM)
	if _live():
		var letter: String = StageCode.LABELS[chosen]
		live_label.text = (Lang.t("tut.rules_right") % letter) if chosen == right else (Lang.t("tut.rules_picked") % letter)


func _draw_refract() -> void:
	match page:
		0:
			_draw_bend()
		1:
			_draw_band()
		2:
			_draw_crossing(true)
		3:
			_draw_crossing(false)
		4:
			_draw_laws()
		_:
			_draw_live()


func _draw_bend() -> void:
	var c := _pivot()
	var slow: float = OpticsMaterials.TRANSPARENT[SLOW].n
	_surface(c, OpticsMaterials.AIR, slow)
	var angle := deg_to_rad(38.0)
	var d := _incoming(angle, true)
	var t: Variant = Optics.refract(d, Vector2(0, -1), OpticsMaterials.AIR, slow)
	_ray(c - d * REACH, c)
	_ray(c, c + (t as Vector2) * REACH)
	_normal(c, 0.5, _free_corner(angle, true))
	_angle_mark(c, -d, 46.0, "θ₁")
	_angle_mark(c, t as Vector2, 66.0, "θ₂")
	_note(Vector2(c.x, BOARD.end.y - 26.0), Lang.t("tut.bend"), DIM)


func _draw_band() -> void:
	var c := _pivot()
	var d := Vector2(0.94, 0.34).normalized()
	var a := c - d * 300.0
	var b := c + d * 300.0
	_beam(a, b, 30.0)
	for i in 7:
		_axle(a.lerp(b, (i + 0.5) / 7.0), d, 30.0, i == 3)
	var perp := Vector2(-d.y, d.x)
	_note(a.lerp(b, 0.5) + perp * 62.0, Lang.t("tut.axle"), AXLE)
	_note(a.lerp(b, 0.86) + perp * 34.0, Lang.t("tut.wheel"), AXLE)
	_note(a.lerp(b, 0.14) - perp * 52.0, Lang.t("tut.band"), BEAM)


## The slow side stays at the bottom on both pages, so the only thing that
## changes between them is the way the beam runs
func _draw_crossing(entering: bool) -> void:
	var c := _pivot()
	var slow: float = OpticsMaterials.TRANSPARENT[SLOW].n
	_surface(c, OpticsMaterials.AIR, slow)
	var angle := deg_to_rad(34.0 if entering else 22.0)
	var d := _incoming(angle, entering)
	var face := Vector2(0, -1) if entering else Vector2(0, 1)
	var n1: float = OpticsMaterials.AIR if entering else slow
	var n2: float = slow if entering else OpticsMaterials.AIR
	var t: Variant = Optics.refract(d, face, n1, n2)
	var out: Vector2 = t if t != null else Optics.reflect(d, face)
	_beam(c - d * REACH, c, 26.0)
	_beam(c, c + out * REACH, 26.0)
	# spread along both beams, so the tilt reads as the whole band turning rather
	# than as one axle being drawn crooked
	for i in 3:
		var away := REACH * (0.35 + 0.28 * i)
		_axle(c - d * away, d, 26.0, false)
		_axle(c + out * away, out, 26.0, false)
	# the axle caught mid crossing: one wheel is already in the slow side and has
	# fallen behind, which is the tilt the beam keeps
	_axle(c, (d + out).normalized(), 26.0, true)
	_normal(c, 0.5, _free_corner(angle, entering))
	_angle_mark(c, -d, 46.0, "θ₁")
	_angle_mark(c, out, 66.0, "θ₂")
	var side := 1.0 if entering else -1.0
	_note(c + Vector2(150, -46.0 * side), Lang.t("tut.wheel_in") if entering else Lang.t("tut.wheel_out"), AXLE)


## Toward the surface, from above when entering the lower medium and from below
## when leaving it. `angle` is measured off the normal either way
func _incoming(angle: float, entering: bool) -> Vector2:
	return Vector2(sin(angle), cos(angle) if entering else -cos(angle))


func _draw_laws() -> void:
	var left := Vector2(BOARD.position.x + BOARD.size.x * 0.27, _pivot().y)
	var right := Vector2(BOARD.position.x + BOARD.size.x * 0.73, _pivot().y)
	var d := _incoming(deg_to_rad(40.0), true)
	var slow: float = OpticsMaterials.TRANSPARENT[SLOW].n
	_surface(left, OpticsMaterials.AIR, slow, 0.44)
	var t: Variant = Optics.refract(d, Vector2(0, -1), OpticsMaterials.AIR, slow)
	_ray(left - d * 150.0, left)
	_ray(left, left + (t as Vector2) * 150.0)
	_normal(left, 0.44)
	_angle_mark(left, -d, 44.0, "θ₁")
	_angle_mark(left, t as Vector2, 62.0, "θ₂")
	_note(left + Vector2(0, 150), "n₁ sin θ₁ = n₂ sin θ₂", DIM)

	var mirror := 150.0
	draw_line(right + Vector2(-mirror, 0), right + Vector2(mirror, 0), Color(0.85, 0.90, 0.95), 5.0, true)
	draw_line(right + Vector2(-mirror, 0), right + Vector2(mirror, 0), Color(1, 1, 1, 0.6), 1.5, true)
	_ray(right - d * 150.0, right)
	_ray(right, right + Vector2(d.x, -d.y) * 150.0)
	# both sides above a mirror are taken by beams, so the label goes below it
	_normal(right, 0.44, Vector2(1, 1))
	_angle_mark(right, -d, 44.0, "θ")
	_angle_mark(right, Vector2(d.x, -d.y), 62.0, "θ")
	_note(right + Vector2(0, 150), Lang.t("tut.mirror_law"), DIM)


func _draw_live() -> void:
	var c := _pivot()
	var slow: float = OpticsMaterials.TRANSPARENT[medium].n
	_surface(c, OpticsMaterials.AIR, slow)
	var n1: float = OpticsMaterials.AIR if from_air else slow
	var n2: float = slow if from_air else OpticsMaterials.AIR
	var d := _incoming(deg_to_rad(knob), from_air)
	var face := Vector2(0, -1) if from_air else Vector2(0, 1)
	var t: Variant = Optics.refract(d, face, n1, n2)
	var out: Vector2 = t if t != null else Optics.reflect(d, face)
	_beam(c - d * REACH, c, 22.0)
	_beam(c, c + out * REACH, 22.0)
	for i in 3:
		var away := REACH * (0.35 + 0.28 * i)
		_axle(c - d * away, d, 22.0, false)
		_axle(c + out * away, out, 22.0, false)
	# on the surface, where the wheel that crossed first is the one that fell
	# behind. Nothing crosses on a total reflection, so nothing is drawn there
	if t != null:
		_axle(c, (d + out).normalized(), 22.0, true)
	_normal(c, 0.5, _free_corner(deg_to_rad(knob), from_air))
	_angle_mark(c, -d, 46.0, "θ₁")
	var text := "θ₁ = %.1f°" % absf(knob)
	if t == null:
		text += Lang.t("tut.tir_critical") % rad_to_deg(Optics.critical_angle(n1, n2))
	else:
		_angle_mark(c, out, 66.0, "θ₂")
		text += "    θ₂ = %.1f°" % rad_to_deg(absf(atan2(out.x, absf(out.y))))
	live_label.text = text


## Puts a board through the same tracer the game uses and draws what comes back.
## A page built this way cannot claim something the game would not do
func _traced(objects: Array, from: Vector2, dir: Vector2) -> Dictionary:
	var res := RayTracer.trace(objects, BOARD, from, dir, {"fresnel": false, "min_intensity": 0.01, "max_events": 48})
	FieldDraw.bodies(self, objects, theme.default_font)
	for seg: Dictionary in res.segments:
		FieldDraw.beam(self, seg.a, seg.b, seg.intensity)
	FieldDraw.source(self, from, dir, 0.0)
	return res


## The plane of vibration, read the way the dial on a sheet is read: upright is
## out of the board, flat is in the plane of it
func _dial(at: Vector2, phi: float, col: Color) -> void:
	var arm := Vector2.from_angle(PI * 0.5 - phi) * 14.0
	draw_line(at - arm, at + arm, col, 2.0, true)


func _sheet_at(x: float, y: float, phi: float) -> SceneObj:
	return ProblemGen.make_object("polarizer", "polarizer", Vector2(x, y), 92.0, 0.0,
			PI * 0.5, PolarizerObj.byte_from_phi(phi))


func _draw_sheet() -> void:
	var c := _pivot()
	if page == 0:
		var a := Vector2(BOARD.position.x + 90.0, c.y)
		var b := Vector2(BOARD.end.x - 90.0, c.y)
		_ray(a, b)
		for i in 5:
			var at := a.lerp(b, (i + 0.5) / 5.0)
			for k in 4:
				_dial(at, PI * k / 4.0, Color(AXLE, 0.85))
		_note(Vector2(c.x, c.y - 72.0), Lang.t("tut.natural"), AXLE)
		_note(Vector2(c.x, c.y + 84.0), Lang.t("tut.bars"), DIM)
		return
	var sheets: Array = [_sheet_at(c.x - 150.0, c.y, 0.0)]
	var second := deg_to_rad(knob) if _live() else PI * 0.5
	if page >= 2:
		sheets.append(_sheet_at(c.x + 150.0, c.y, second))
	var res := _traced(sheets, Vector2(BOARD.position.x + 4.0, c.y), Vector2.RIGHT)
	for i in 3:
		_dial(Vector2(c.x - 110.0 + i * 40.0, c.y), 0.0, Color(AXLE, 0.9))
	if page == 1:
		_note(Vector2(c.x + 150.0, c.y - 72.0), Lang.t("tut.aligned"), AXLE)
		return
	var through: float = 0.0 if res.exits.is_empty() else res.exits[0].intensity
	if through > 0.02:
		for i in 3:
			_dial(Vector2(c.x + 190.0 + i * 40.0, c.y), second, Color(AXLE, 0.9))
	var text := Lang.t("tut.sheet_live") % [knob, through * 100.0]
	if _live():
		live_label.text = text
	else:
		_note(Vector2(c.x, BOARD.end.y - 26.0), Lang.t("tut.crossed"), DIM)


func _draw_crystal() -> void:
	var c := _pivot()
	var axis := deg_to_rad(knob) if _live() else deg_to_rad(25.0)
	var ball := ProblemGen.make_object("circle", "calcite", c, 96.0, 0.0, axis)
	if page == 0:
		FieldDraw.bodies(self, [ball], theme.default_font)
		_note(Vector2(c.x, c.y - 130.0), Lang.t("tut.optic_axis"), AXLE)
		_note(Vector2(c.x, BOARD.end.y - 26.0), Lang.t("tut.crystal_note"), DIM)
		return
	var res := _traced([ball], Vector2(BOARD.position.x + 4.0, c.y - 30.0), Vector2(1, 0.10).normalized())
	for k in res.exits.size():
		var e: Dictionary = res.exits[k]
		_note((e.point as Vector2) + Vector2(-64.0, -16.0 + 30.0 * k), Lang.t("tut.ordinary") if e.pol == "s" else Lang.t("tut.extraordinary"), BEAM)
	if _live():
		live_label.text = Lang.t("tut.crystal_live") % [knob, res.exits.size()]
	else:
		_note(Vector2(c.x, BOARD.end.y - 26.0), Lang.t("tut.crystal_two"), DIM)


## Path length decides the turn, which is why the knob here is a size and not
## an angle
func _draw_spin() -> void:
	var c := _pivot()
	var radius: float = knob if _live() else [70.0, 46.0][page] if page < 2 else 70.0
	var body := ProblemGen.make_object("circle", medium, c, radius, 0.0, 0.0)
	var turn := rad_to_deg(OpticsMaterials.rotary(medium) * radius * 2.0)
	if page < 2:
		var res := _traced([_sheet_at(c.x - 260.0, c.y, 0.0), body], Vector2(BOARD.position.x + 4.0, c.y), Vector2.RIGHT)
		for i in 3:
			_dial(Vector2(c.x - 230.0 + i * 40.0, c.y), 0.0, Color(AXLE, 0.9))
		if not res.exits.is_empty():
			for i in 3:
				_dial(Vector2(c.x + radius + 40.0 + i * 40.0, c.y), deg_to_rad(turn), Color(AXLE, 0.9))
		_note(Vector2(c.x, BOARD.end.y - 26.0), Lang.t("tut.spin_note") % [radius * 2.0, turn], DIM)
		return
	var sheets: Array = [_sheet_at(c.x - 260.0, c.y, 0.0), body, _sheet_at(c.x + 260.0, c.y, PI * 0.5)]
	var res := _traced(sheets, Vector2(BOARD.position.x + 4.0, c.y), Vector2.RIGHT)
	var through: float = 0.0 if res.exits.is_empty() else res.exits[0].intensity
	live_label.text = Lang.t("tut.spin_live") % [radius * 2.0, turn, through * 100.0]


func _draw_grin() -> void:
	var c := _pivot()
	var slope := knob / 100.0 * 0.009
	if page == 1:
		for i in 2:
			var at := Vector2(BOARD.position.x + BOARD.size.x * (0.28 + 0.44 * i), c.y)
			var one := ProblemGen.make_object("gradient", "bk7", at, 220.0, 150.0, 0.0,
					GradientBody.byte_from_slope(0.006 * (1.0 if i == 0 else -1.0)))
			_traced([one], Vector2(at.x - 210.0, c.y - 40.0), Vector2(1, 0.12).normalized())
		_note(Vector2(c.x, BOARD.end.y - 26.0), Lang.t("tut.grin_note"), DIM)
		return
	var block := ProblemGen.make_object("gradient", "bk7", c, 520.0, 190.0, 0.0,
			GradientBody.byte_from_slope(slope if _live() else 0.006))
	_traced([block], Vector2(BOARD.position.x + 4.0, c.y - 50.0), Vector2(1, 0.10).normalized())
	if _live():
		live_label.text = Lang.t("tut.grin_live") % [slope, Lang.t("tut.below") if slope > 0.0 else Lang.t("tut.above")]
	else:
		_note(Vector2(c.x, BOARD.end.y - 26.0), Lang.t("tut.grin_curve"), DIM)


func _draw_mirror() -> void:
	var c := _pivot()
	var half := BOARD.size.x * 0.42
	draw_line(c - Vector2(half, 0), c + Vector2(half, 0), Color(0.85, 0.90, 0.95), 5.0, true)
	draw_line(c - Vector2(half, 0), c + Vector2(half, 0), Color(1, 1, 1, 0.6), 1.5, true)
	var angle: float = deg_to_rad(knob) if _live() else deg_to_rad(38.0)
	var d := _incoming(angle, true)
	# no band here: nothing about a mirror depends on the beam having two edges
	_ray(c - d * REACH, c)
	# the beams take both upper quadrants, so the label goes under the mirror
	_normal(c, 0.5, Vector2(1, 1))
	_angle_mark(c, -d, 46.0, Lang.t("tut.incidence") if page == 0 else "θ")
	if page == 0:
		_note(c + Vector2(-232, 84), Lang.t("tut.from_normal"), DIM)
		return
	var back := Vector2(d.x, -d.y)
	_ray(c, c + back * REACH)
	_angle_mark(c, back, 66.0, Lang.t("tut.reflection") if page == 1 else "θ")
	if _live():
		live_label.text = Lang.t("tut.mirror_live") % absf(knob)


## Always from inside the slow medium, since that is the only side the topic is
## about. The three fixed pages walk the angle up past the critical one
func _draw_critical() -> void:
	var c := _pivot()
	var slow: float = OpticsMaterials.TRANSPARENT[medium if _live() else SLOW].n
	_surface(c, OpticsMaterials.AIR, slow)
	var crit := Optics.critical_angle(slow, OpticsMaterials.AIR)
	var angle: float = deg_to_rad(knob)
	if not _live():
		# just under the critical angle the outgoing one swings by degrees for
		# hundredths of a degree in, so the middle page is set from where it lands
		var grazing := asin(clampf(sin(deg_to_rad(87.0)) * OpticsMaterials.AIR / slow, 0.0, 1.0))
		angle = [crit * 0.5, grazing, crit + deg_to_rad(14.0)][page]
	var d := _incoming(angle, false)
	var face := Vector2(0, 1)
	var t: Variant = Optics.refract(d, face, slow, OpticsMaterials.AIR)
	var out: Vector2 = t if t != null else Optics.reflect(d, face)
	_beam(c - d * REACH, c, 22.0)
	_beam(c, c + out * REACH, 22.0)
	_normal(c, 0.5, _free_corner(angle, false))
	_angle_mark(c, -d, 46.0, "θ₁")
	var text := Lang.t("tut.critical_live") % [rad_to_deg(absf(angle)), rad_to_deg(crit)]
	if t == null:
		text += Lang.t("tut.tir")
	else:
		_angle_mark(c, out, 66.0, "θ₂")
		text += "    θ₂ = %.1f°" % rad_to_deg(absf(atan2(out.x, absf(out.y))))
	if _live():
		live_label.text = text
	else:
		_note(Vector2(c.x, BOARD.end.y - 26.0), text, DIM)


func _draw_split() -> void:
	var slow: float = OpticsMaterials.TRANSPARENT[medium if _live() else SLOW].n
	if page == 1:
		_split_at(Vector2(BOARD.position.x + BOARD.size.x * 0.27, _pivot().y), deg_to_rad(18.0), slow, 0.44, 112.0)
		_split_at(Vector2(BOARD.position.x + BOARD.size.x * 0.73, _pivot().y), deg_to_rad(84.0), slow, 0.44, 112.0)
		return
	var angle: float = deg_to_rad(knob) if _live() else deg_to_rad(35.0)
	var r := _split_at(_pivot(), angle, slow, 1.0, REACH)
	if _live():
		live_label.text = Lang.t("tut.split_live") % [rad_to_deg(absf(angle)), r * 100.0, (1.0 - r) * 100.0]


## Returns the share that came back, which the caller puts on screen
func _split_at(c: Vector2, angle: float, slow: float, span: float, reach: float) -> float:
	_surface(c, OpticsMaterials.AIR, slow, span)
	var d := _incoming(angle, true)
	var face := Vector2(0, -1)
	var share := Optics.reflectance(d, face, OpticsMaterials.AIR, slow)
	var t: Variant = Optics.refract(d, face, OpticsMaterials.AIR, slow)
	_ray(c - d * reach, c)
	_ray(c, c + Vector2(d.x, -d.y) * reach, share)
	if t != null:
		_ray(c, c + (t as Vector2) * reach, 1.0 - share)
	# three beams here, so the only free quadrant is the one behind the incoming
	_normal(c, 0.5 if span > 0.9 else 0.44, Vector2(-1, 1))
	if span < 0.9:
		_note(Vector2(c.x, c.y + 150.0), Lang.t("tut.split_note") % [rad_to_deg(angle), share * 100.0], DIM)
		return share
	# beside each beam rather than at its end, which would land off the board
	var side := Vector2(-d.y, d.x) * 36.0
	_note(c + Vector2(d.x, -d.y) * reach * 0.62 + Vector2(side.x, -side.y), Lang.t("tut.reflects") % (share * 100.0), DIM)
	if t != null:
		_note(c + (t as Vector2) * reach * 0.62 - side, Lang.t("tut.passes") % ((1.0 - share) * 100.0), DIM)
	return share


## The surface, with the medium on each side named by its index. The slow side is
## drawn at the bottom on every page, so a reader can hold one picture in mind
## and only follow the beam
func _surface(c: Vector2, top_n: float, bottom_n: float, span := 1.0) -> void:
	var half := BOARD.size.x * 0.5 * span
	var top_col := AIR if top_n < bottom_n else GLASS
	var bottom_col := GLASS if top_n < bottom_n else AIR
	draw_rect(Rect2(c.x - half, BOARD.position.y + 2.0, half * 2.0, c.y - BOARD.position.y - 2.0),
			Color(top_col, 0.09), true)
	draw_rect(Rect2(c.x - half, c.y, half * 2.0, BOARD.end.y - c.y - 2.0), Color(bottom_col, 0.09), true)
	draw_line(c - Vector2(half, 0), c + Vector2(half, 0), Color(0.75, 0.82, 0.95, 0.9), 2.0, true)
	_note(Vector2(c.x - half + 62.0, c.y - 24.0), "n = %.3f" % top_n, top_col)
	_note(Vector2(c.x - half + 62.0, c.y + 24.0), "n = %.3f" % bottom_n, bottom_col)


## `corner` picks which way from the crossing the label sits. The beams take two
## opposite quadrants and which two depends on the page
func _normal(c: Vector2, span := 0.5, corner := Vector2(1, -1)) -> void:
	var reach := BOARD.size.y * 0.5 * span
	draw_dashed_line(c - Vector2(0, reach), c + Vector2(0, reach), Color(0.85, 0.88, 0.95, 0.45), 1.5, 7.0, true, true)
	_note(c + Vector2(36.0 * corner.x, (reach - 16.0) * corner.y), Lang.t("tut.normal"), Color(0.85, 0.88, 0.95, 0.7))


func _free_corner(angle: float, entering: bool) -> Vector2:
	return Vector2(1.0 if (angle >= 0.0) == entering else -1.0, -1.0)


func _beam(a: Vector2, b: Vector2, half_w: float) -> void:
	var perp := (b - a).normalized().rotated(PI * 0.5) * half_w
	draw_colored_polygon(PackedVector2Array([a + perp, b + perp, b - perp, a - perp]), Color(BEAM, 0.12))
	draw_line(a + perp, b + perp, Color(BEAM, 0.55), 1.5, true)
	draw_line(a - perp, b - perp, Color(BEAM, 0.55), 1.5, true)
	_ray(a, b)


## `power` is the share of the light this beam carries, drawn the way the play
## screen draws a dim branch
func _ray(a: Vector2, b: Vector2, power := 1.0) -> void:
	var d := (b - a).normalized()
	FieldDraw.beam(self, a, b, power)
	for turn in [PI * 0.82, -PI * 0.82]:
		FieldDraw.beam(self, b, b + d.rotated(turn) * 15.0, power)


## A wheel at each end of the axle, drawn across the beam
func _axle(at: Vector2, d: Vector2, half_w: float, strong: bool) -> void:
	var perp := d.rotated(PI * 0.5) * half_w
	var col := Color(AXLE, 1.0 if strong else 0.5)
	draw_line(at - perp, at + perp, col, 2.5 if strong else 1.5, true)
	for e in [at - perp, at + perp]:
		draw_circle(e, 6.0 if strong else 4.5, col)


func _angle_mark(c: Vector2, d: Vector2, radius: float, text: String) -> void:
	var from: float = -PI * 0.5 if d.y < 0.0 else PI * 0.5
	var to := d.angle()
	draw_arc(c, radius, minf(from, to), maxf(from, to), 24, Color(0.9, 0.93, 0.97, 0.6), 1.5, true)
	var mid := (Vector2.from_angle(from) + d).normalized()
	_note(c + mid * (radius + 18.0), text, Color(0.9, 0.93, 0.97, 0.85))


func _note(at: Vector2, text: String, col: Color) -> void:
	var font: Font = theme.default_font
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	draw_string(font, at - Vector2(size.x * 0.5, -5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
