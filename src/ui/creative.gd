extends Node2D
## Stage editor. There is no tool mode: the shape buttons place, clicking picks,
## clicking the background drops the selection. The draft is kept as plain
## records and every preview goes through encode then decode, so what is shown
## is exactly what the code carries


const SHAPES := [
	{"kind": "mirror", "label": "鏡", "mat": "mirror", "s1": 80.0, "s2": 0.0},
	{"kind": "slab", "label": "板", "mat": "soda_glass", "s1": 200.0, "s2": 70.0},
	{"kind": "circle", "label": "円", "mat": "soda_glass", "s1": 60.0, "s2": 0.0},
	{"kind": "prism", "label": "プリズム", "mat": "soda_glass", "s1": 80.0, "s2": 0.0},
	{"kind": "polarizer", "label": "偏光板", "mat": "polarizer", "s1": 80.0, "s2": 0.0},
	{"kind": "gradient", "label": "勾配", "mat": "bk7", "s1": 200.0, "s2": 90.0},
]
## transmission axes offered for a sheet, in degrees from out of plane
const AXES := [0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165]
## index slopes offered for a graded block, as a share of what it can carry
const SLOPES := [-1.0, -0.75, -0.5, -0.25, 0.25, 0.5, 0.75, 1.0]
const HANDLE_R := 11.0
## how close to a source handle a click has to be to grab it, and how much room
## around one is kept clear of hand placed decoys. Both handles sit on the
## border, which is exactly where decoys go, so without this the click that was
## meant for the source drops a marker instead
const HANDLE_GRAB := 18.0
const SOURCE_KEEPOUT := 40.0
const PICK_SLACK := 6.0
## grab radius for a corner, and how near the boundary counts as the rim
const VERTEX_R := 12.0
const RIM_R := 8.0
## keeps the aim handle grabbable when a steep tilt near a corner would otherwise
## land it on top of the root
const MIN_AIM := 60.0

var draft := {
	"fresnel": false,
	"choices": 4,
	"source_s": 400.0,
	"source_tilt": 0.0,
	"objects": [],
	"manual": false,
	"decoys": [],
}
## what the selection refers to, "" / "object" / "decoy"
var sel_kind := ""
var selected := -1
var drag := ""
## what the pointer was holding when the drag started, so a resize or a rotation
## stays anchored to the spot that was grabbed
var grab := {}
## index -> why it cannot be used, filled on every refresh
var faults := {}
var code := ""
## a seed code replays its problem exactly, so keep it until the draft is edited
var seed_code := ""
var seed_level := -1
var stage: Dictionary = {}
var preview: Dictionary = {}
## where the light really lands, drawn whether or not the stage is playable yet
var truth: Array = []
var status := ""

var beams: Node2D
var ui: Control
var font: Font
var status_label: Label
var code_edit: LineEdit
var mat_picker: OptionButton
## transmission axis for a sheet, index slope for a graded block
var extra_picker: OptionButton
var delete_btn: Button
var fresnel_box: CheckBox
var auto_box: CheckBox
var choices_spin: SpinBox


func _ready() -> void:
	beams = BeamLayer.new()
	add_child(beams)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.theme = UiTheme.make()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	font = ui.theme.default_font
	_build_ui()
	if not GameState.stage_code.is_empty():
		_load_code(GameState.stage_code)
	_sync_controls()
	_refresh()


func _build_ui() -> void:
	var title := Label.new()
	title.position = Vector2(150, 22)
	title.text = "クリエイティブ"
	ui.add_child(title)
	var help := Label.new()
	help.position = Vector2(300, 10)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.62, 0.72, 0.88))
	help.text = "物体: クリックで選択  中をドラッグで移動  外周で大きさ  頂点で回転  ホイールでも回転\n光源: 枠上の2点をドラッグ (根元=位置，先端=向き)    手動時は枠付近クリックで誤答を追加\n偏光板の透過軸と勾配の傾きは，選んでから下のリストで変えます"
	ui.add_child(help)
	var back := Button.new()
	back.text = "メニュー"
	back.position = Vector2(1030, 16)
	back.custom_minimum_size = Vector2(100, 34)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_to_menu)
	ui.add_child(back)

	var row1 := HBoxContainer.new()
	row1.position = Vector2(150, 588)
	row1.add_theme_constant_override("separation", 6)
	ui.add_child(row1)
	var add_label := Label.new()
	add_label.text = "置く"
	add_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row1.add_child(add_label)
	row1.add_child(_gap(2))
	for i in SHAPES.size():
		var b := Button.new()
		b.text = SHAPES[i].label
		b.custom_minimum_size = Vector2(66, 36)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_place_shape.bind(i))
		row1.add_child(b)
	row1.add_child(_gap(14))
	mat_picker = OptionButton.new()
	mat_picker.custom_minimum_size = Vector2(172, 36)
	# without this the button widens to its longest material name
	mat_picker.clip_text = true
	mat_picker.focus_mode = Control.FOCUS_NONE
	mat_picker.item_selected.connect(_on_material)
	row1.add_child(mat_picker)
	extra_picker = OptionButton.new()
	extra_picker.custom_minimum_size = Vector2(148, 36)
	extra_picker.clip_text = true
	extra_picker.focus_mode = Control.FOCUS_NONE
	extra_picker.item_selected.connect(_on_extra)
	row1.add_child(extra_picker)
	delete_btn = Button.new()
	delete_btn.text = "削除"
	delete_btn.custom_minimum_size = Vector2(72, 36)
	delete_btn.focus_mode = Control.FOCUS_NONE
	delete_btn.pressed.connect(_delete_selected)
	row1.add_child(delete_btn)

	var row2 := HBoxContainer.new()
	row2.position = Vector2(150, 632)
	row2.add_theme_constant_override("separation", 8)
	ui.add_child(row2)
	fresnel_box = CheckBox.new()
	fresnel_box.text = "分岐 (Fresnel)"
	fresnel_box.focus_mode = Control.FOCUS_NONE
	fresnel_box.toggled.connect(func(on: bool) -> void:
		draft.fresnel = on
		_touch())
	row2.add_child(fresnel_box)
	row2.add_child(_gap(6))
	auto_box = CheckBox.new()
	auto_box.text = "誤答は自動"
	auto_box.button_pressed = true
	auto_box.focus_mode = Control.FOCUS_NONE
	auto_box.toggled.connect(func(on: bool) -> void:
		draft.manual = not on
		if on:
			draft.decoys.clear()
		_select(-1)
		choices_spin.editable = on
		_touch())
	row2.add_child(auto_box)
	row2.add_child(_gap(6))
	var ch_label := Label.new()
	ch_label.text = "選択肢"
	ch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row2.add_child(ch_label)
	choices_spin = SpinBox.new()
	choices_spin.min_value = StageCode.MIN_CHOICES
	choices_spin.max_value = StageCode.MAX_CHOICES
	choices_spin.value = draft.choices
	choices_spin.custom_minimum_size = Vector2(70, 36)
	choices_spin.value_changed.connect(func(v: float) -> void:
		draft.choices = int(v)
		_touch())
	row2.add_child(choices_spin)
	row2.add_child(_gap(10))
	code_edit = LineEdit.new()
	code_edit.custom_minimum_size = Vector2(196, 36)
	code_edit.placeholder_text = "コードを貼り付け"
	row2.add_child(code_edit)
	var load_b := Button.new()
	load_b.text = "読み込み"
	load_b.custom_minimum_size = Vector2(88, 36)
	load_b.focus_mode = Control.FOCUS_NONE
	load_b.pressed.connect(func() -> void: _load_code(code_edit.text))
	row2.add_child(load_b)
	var copy_b := Button.new()
	copy_b.text = "コードをコピー"
	copy_b.custom_minimum_size = Vector2(124, 36)
	copy_b.focus_mode = Control.FOCUS_NONE
	copy_b.pressed.connect(_copy_code)
	row2.add_child(copy_b)
	var clear_b := Button.new()
	clear_b.text = "全消去"
	clear_b.custom_minimum_size = Vector2(76, 36)
	clear_b.focus_mode = Control.FOCUS_NONE
	clear_b.pressed.connect(func() -> void:
		draft.objects.clear()
		_select(-1)
		_touch())
	row2.add_child(clear_b)
	var play_b := Button.new()
	play_b.text = "遊ぶ"
	play_b.custom_minimum_size = Vector2(88, 36)
	play_b.focus_mode = Control.FOCUS_NONE
	play_b.pressed.connect(_play)
	row2.add_child(play_b)

	status_label = Label.new()
	status_label.position = Vector2(150, 678)
	status_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(status_label)


func _gap(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c


func _to_menu() -> void:
	GameState.clear_stage()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## any edit invalidates a loaded seed, the stage is a hand made one from here on
func _touch() -> void:
	seed_code = ""
	seed_level = -1
	_refresh()


func _select(index: int, kind := "object") -> void:
	sel_kind = kind if index >= 0 else ""
	selected = index
	_rebuild_materials()
	delete_btn.disabled = index < 0


func _sync_controls() -> void:
	fresnel_box.set_pressed_no_signal(draft.fresnel)
	auto_box.set_pressed_no_signal(not draft.manual)
	choices_spin.set_value_no_signal(draft.choices)
	choices_spin.editable = not draft.manual
	_select(-1)


func _rebuild_materials() -> void:
	mat_picker.clear()
	extra_picker.clear()
	if sel_kind != "object" or selected < 0:
		mat_picker.disabled = true
		extra_picker.disabled = true
		mat_picker.add_item("物質 (物体を選ぶ)")
		extra_picker.add_item("―")
		return
	var rec: Dictionary = draft.objects[selected]
	var table := _material_table(rec.kind)
	mat_picker.disabled = table.is_empty()
	if table.is_empty():
		mat_picker.add_item("物質なし")
	for key: String in table:
		var info: Dictionary = OpticsMaterials.REFLECTIVE[key] if rec.kind == "mirror" else OpticsMaterials.TRANSPARENT[key]
		mat_picker.add_item(info.label if rec.kind == "mirror" else "%s  n=%.3f" % [info.label, info.n])
	mat_picker.select(maxi(table.find(rec.mat), 0))
	_rebuild_extra(rec)


## The spare byte means an axis on a sheet and a slope on a graded block, so the
## same control offers different things
func _rebuild_extra(rec: Dictionary) -> void:
	extra_picker.disabled = not ProblemGen.EXTRA_KINDS.has(rec.kind)
	if rec.kind == "polarizer":
		for deg: int in AXES:
			extra_picker.add_item("透過軸 %d°" % deg)
		extra_picker.select(maxi(AXES.find(int(rec.extra) % 180), 0))
		return
	if rec.kind == "gradient":
		var cap := GradientBody.slope_cap(rec.mat, rec.s2)
		var now := GradientBody.slope_from_byte(int(rec.extra))
		var near := 0
		for i in SLOPES.size():
			extra_picker.add_item("勾配 %+d%%" % roundi(SLOPES[i] * 100.0))
			if absf(SLOPES[i] * cap - now) < absf(SLOPES[near] * cap - now):
				near = i
		extra_picker.select(near)
		return
	extra_picker.add_item("―")


func _material_table(kind: String) -> Array:
	if kind == "polarizer":
		return []
	return OpticsMaterials.REFLECTIVE_ORDER if kind == "mirror" else OpticsMaterials.BY_INDEX


func _on_material(index: int) -> void:
	if selected < 0:
		return
	var table := _material_table(draft.objects[selected].kind)
	if index < 0 or index >= table.size():
		return
	var rec: Dictionary = draft.objects[selected].duplicate()
	rec.mat = table[index]
	_apply(rec, selected)


func _on_extra(index: int) -> void:
	if selected < 0:
		return
	var rec: Dictionary = draft.objects[selected].duplicate()
	if rec.kind == "polarizer" and index < AXES.size():
		rec.extra = AXES[index]
	elif rec.kind == "gradient" and index < SLOPES.size():
		rec.extra = GradientBody.byte_from_slope(SLOPES[index] * GradientBody.slope_cap(rec.mat, rec.s2))
	_apply(rec, selected)


func _delete_selected() -> void:
	if selected < 0:
		return
	if sel_kind == "decoy":
		draft.decoys.remove_at(selected)
	else:
		draft.objects.remove_at(selected)
	_select(-1)
	_touch()


func _place_shape(index: int) -> void:
	if draft.objects.size() >= StageCode.MAX_OBJECTS:
		_note("物体は %d 個までです" % StageCode.MAX_OBJECTS)
		return
	var shape: Dictionary = SHAPES[index]
	var spot := _free_spot(shape)
	if spot == Vector2.INF:
		_note("空いている場所がありません")
		return
	draft.objects.append(_shape_record(shape, spot))
	_select(draft.objects.size() - 1)
	_touch()


## a fresh graded block is given most of the slope its material can carry, so
## that placing one shows what it does without any fiddling
func _shape_record(shape: Dictionary, spot: Vector2) -> Dictionary:
	var extra := 0
	if shape.kind == "gradient":
		extra = GradientBody.byte_from_slope(0.6 * GradientBody.slope_cap(shape.mat, shape.s2))
	return StageCode.snap({
		"kind": shape.kind, "mat": shape.mat,
		"x": spot.x, "y": spot.y, "s1": shape.s1, "s2": shape.s2, "rot": 0.0, "extra": extra,
	})


## Nearest free grid point to the middle, so a new body lands somewhere visible
func _free_spot(shape: Dictionary) -> Vector2:
	var f := ProblemGen.FIELD
	var mid := f.get_center()
	var spots: Array[Vector2] = []
	for gy in range(1, 6):
		for gx in range(1, 10):
			spots.append(Vector2(f.position.x + f.size.x * gx / 10.0, f.position.y + f.size.y * gy / 6.0))
	spots.sort_custom(func(a: Vector2, b: Vector2): return a.distance_to(mid) < b.distance_to(mid))
	for spot in spots:
		var rec := _shape_record(shape, spot)
		if _record_ok(rec, -1):
			return Vector2(rec.x, rec.y)
	return Vector2.INF


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).keycode
		if key == KEY_DELETE or key == KEY_BACKSPACE:
			_delete_selected()
		elif key == KEY_ESCAPE:
			_to_menu()
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		if drag.is_empty():
			Input.set_default_cursor_shape(_cursor_at(get_global_mouse_position()))
		else:
			_on_drag(get_global_mouse_position())


func _on_mouse_button(event: InputEventMouseButton) -> void:
	var pos := get_global_mouse_position()
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if event.pressed and selected >= 0:
			_nudge(selected, 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1, event.shift_pressed, event.ctrl_pressed)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		drag = ""
		return
	_press_at(pos)


func _press_at(pos: Vector2) -> void:
	# the source is grabbable only at its two ends, never along the shaft
	if pos.distance_to(_source_root()) <= HANDLE_GRAB:
		drag = "root"
		return
	if pos.distance_to(_source_tip()) <= HANDLE_GRAB:
		drag = "tip"
		return
	if draft.manual:
		var near := _decoy_at(pos)
		if near >= 0:
			_select(near, "decoy")
			_refresh()
			return
		if _near_border(pos):
			if _crowds_source(pos):
				_note("光源のハンドルに近すぎます．少し離してから置いてください")
				return
			_add_decoy(pos)
			return
	if not ProblemGen.FIELD.has_point(pos):
		return
	# handles belong to the selected body only, otherwise a click near two bodies
	# would be ambiguous
	if sel_kind == "object" and selected >= 0:
		var mode := _handle_at(selected, pos)
		if not mode.is_empty():
			drag = mode
			grab = _grab_ref(selected, pos)
			return
	var picked := _pick_object(pos)
	_select(picked)
	drag = "object" if picked >= 0 else ""
	if picked >= 0:
		grab = _grab_ref(picked, pos)
	_refresh()


## Hand placed decoys live on the border, so clicking near the frame drops the
## next one there
func _near_border(pos: Vector2) -> bool:
	var f := ProblemGen.FIELD
	return f.grow(26.0).has_point(pos) and not f.grow(-26.0).has_point(pos)


func _crowds_source(pos: Vector2) -> bool:
	return pos.distance_to(_source_root()) < SOURCE_KEEPOUT or pos.distance_to(_source_tip()) < SOURCE_KEEPOUT


func _decoy_at(pos: Vector2) -> int:
	for i in draft.decoys.size():
		if pos.distance_to(ProblemGen.s_to_point(draft.decoys[i])) <= 22.0:
			return i
	return -1


func _add_decoy(pos: Vector2) -> void:
	if draft.decoys.size() >= StageCode.MAX_DECOYS:
		_note("選択肢は %d 個までです" % (StageCode.MAX_DECOYS + 1))
		return
	draft.decoys.append(StageCode.snap_source_s(_nearest_border_s(pos)))
	_select(draft.decoys.size() - 1, "decoy")
	_touch()


## What the pointer is over on body i: a corner turns it, the rim resizes it,
## anything else moves it
func _handle_at(i: int, pos: Vector2) -> String:
	var obj := _object(i)
	if obj == null:
		return ""
	var bar: bool = obj is MirrorObj or obj is PolarizerObj
	for v in obj.vertices():
		if pos.distance_to(v) <= VERTEX_R:
			return "endpoint" if bar else "rotate"
	if bar:
		return ""
	if _rim_distance(obj, pos) <= RIM_R:
		return "resize"
	return ""


static func _rim_distance(obj: SceneObj, pos: Vector2) -> float:
	var line := obj.outline(0.0)
	var best := INF
	for i in line.size():
		var a := line[i]
		var b := line[(i + 1) % line.size()]
		best = minf(best, Geometry2D.get_closest_point_to_segment(pos, a, b).distance_to(pos))
	return best


func _grab_ref(i: int, pos: Vector2) -> Dictionary:
	var rec: Dictionary = draft.objects[i]
	var centre := Vector2(rec.x, rec.y)
	var ref := {
		"offset": centre - pos, "rot": rec.rot, "s1": rec.s1, "s2": rec.s2,
		"angle": (pos - centre).angle(), "dist": maxf(pos.distance_to(centre), 1.0),
		"axis": "s1", "anchor": Vector2.ZERO,
	}
	if rec.kind == "slab" or rec.kind == "gradient":
		# whichever edge is nearer decides which side the drag stretches
		var local := (pos - centre).rotated(-rec.rot)
		ref.axis = "s1" if absf(local.x) / maxf(rec.s1, 1.0) >= absf(local.y) / maxf(rec.s2, 1.0) else "s2"
	if rec.kind == "mirror" or rec.kind == "polarizer":
		var obj := _object(i)
		var ends := obj.vertices()
		ref.anchor = ends[1] if pos.distance_to(ends[0]) < pos.distance_to(ends[1]) else ends[0]
	return ref


func _on_drag(pos: Vector2) -> void:
	match drag:
		"root":
			draft.source_s = StageCode.snap_source_s(_nearest_border_s(pos))
			_touch()
		"tip":
			var want := pos - _source_root()
			if want.length() > 6.0:
				var tilt := ProblemGen.border_inward(draft.source_s).angle_to(want.normalized())
				draft.source_tilt = StageCode.snap_tilt(clampf(tilt, -StageCode.MAX_TILT, StageCode.MAX_TILT))
				_touch()
		"object":
			_move_to(pos)
		"rotate":
			_rotate_to(pos)
		"resize":
			_resize_to(pos)
		"endpoint":
			_endpoint_to(pos)


## Dragging is never blocked, so a body can be carried across another one. What
## it lands on is judged afterwards, in _refresh
func _move_to(pos: Vector2) -> void:
	if selected < 0:
		return
	var rec: Dictionary = draft.objects[selected].duplicate()
	var want: Vector2 = pos + grab.offset
	rec.x = clampf(want.x, ProblemGen.FIELD.position.x, ProblemGen.FIELD.end.x)
	rec.y = clampf(want.y, ProblemGen.FIELD.position.y, ProblemGen.FIELD.end.y)
	_apply(rec, selected)


func _rotate_to(pos: Vector2) -> void:
	if selected < 0:
		return
	var rec: Dictionary = draft.objects[selected].duplicate()
	var centre := Vector2(rec.x, rec.y)
	rec.rot = fposmod(grab.rot + (pos - centre).angle() - grab.angle, TAU)
	_apply(rec, selected)


func _resize_to(pos: Vector2) -> void:
	if selected < 0:
		return
	var rec: Dictionary = draft.objects[selected].duplicate()
	var centre := Vector2(rec.x, rec.y)
	var span: Dictionary = ProblemGen.SIZE_RANGE[rec.kind]
	if rec.kind == "slab" or rec.kind == "gradient":
		var local := (pos - centre).rotated(-rec.rot)
		if grab.axis == "s1":
			rec.s1 = clampf(absf(local.x) * 2.0, span.s1[0], span.s1[1])
		else:
			rec.s2 = clampf(absf(local.y) * 2.0, span.s2[0], span.s2[1])
	else:
		var scale: float = pos.distance_to(centre) / grab.dist
		rec.s1 = clampf(grab.s1 * scale, span.s1[0], span.s1[1])
	_apply(rec, selected)


## A mirror is a line, so its ends set the length and the angle together
func _endpoint_to(pos: Vector2) -> void:
	if selected < 0:
		return
	var rec: Dictionary = draft.objects[selected].duplicate()
	var anchor: Vector2 = grab.anchor
	var span: Dictionary = ProblemGen.SIZE_RANGE[rec.kind]
	var half := clampf(pos.distance_to(anchor) * 0.5, span.s1[0], span.s1[1])
	var dir := (pos - anchor).normalized() if pos.distance_to(anchor) > 1.0 else Vector2.RIGHT
	var far := anchor + dir * half * 2.0
	rec.x = (anchor.x + far.x) * 0.5
	rec.y = (anchor.y + far.y) * 0.5
	rec.s1 = half
	rec.rot = dir.angle()
	_apply(rec, selected)


func _cursor_at(pos: Vector2) -> int:
	if pos.distance_to(_source_root()) <= HANDLE_GRAB or pos.distance_to(_source_tip()) <= HANDLE_GRAB:
		return Input.CURSOR_POINTING_HAND
	if selected >= 0:
		match _handle_at(selected, pos):
			"rotate", "endpoint":
				return Input.CURSOR_CROSS
			"resize":
				return _size_cursor(pos)
	return Input.CURSOR_POINTING_HAND if _pick_object(pos) >= 0 else Input.CURSOR_ARROW


## picks the arrow that points along the direction the rim would move
func _size_cursor(pos: Vector2) -> int:
	var rec: Dictionary = draft.objects[selected]
	var out := (pos - Vector2(rec.x, rec.y)).normalized()
	var deg := rad_to_deg(fposmod(out.angle(), PI))
	if deg < 22.5 or deg >= 157.5:
		return Input.CURSOR_HSIZE
	if deg < 67.5:
		return Input.CURSOR_FDIAGSIZE
	if deg < 112.5:
		return Input.CURSOR_VSIZE
	return Input.CURSOR_BDIAGSIZE


func _nudge(index: int, dir: int, resize: bool, thickness: bool) -> void:
	var rec: Dictionary = draft.objects[index].duplicate()
	var range_of: Dictionary = ProblemGen.SIZE_RANGE[rec.kind]
	if thickness and range_of.s2[1] > 0.0:
		rec.s2 = clampf(rec.s2 + dir * 6.0, range_of.s2[0], range_of.s2[1])
	elif resize:
		rec.s1 = clampf(rec.s1 + dir * 8.0, range_of.s1[0], range_of.s1[1])
	else:
		rec.rot = fposmod(rec.rot + dir * deg_to_rad(5.0), TAU)
	_apply(rec, index)


## Snap before storing, so the draft only ever holds values the code can carry.
## Nothing is rejected here, a bad placement is reported by _faults instead
func _apply(rec: Dictionary, index: int) -> void:
	var fitted := _fit_gradient(rec)
	draft.objects[index] = StageCode.snap(fitted)
	if fitted.kind == "gradient" and index == selected:
		extra_picker.clear()
		_rebuild_extra(draft.objects[index])
	_touch()


## Resizing a block or giving it a rarer material changes how steep it may be,
## so the slope is pulled back into range instead of turning the block red
func _fit_gradient(rec: Dictionary) -> Dictionary:
	if rec.kind != "gradient":
		return rec
	var cap := GradientBody.slope_cap(rec.mat, rec.s2)
	rec.extra = GradientBody.byte_from_slope(clampf(GradientBody.slope_from_byte(int(rec.get("extra", 0))), -cap, cap))
	return rec


func _build(rec: Dictionary) -> SceneObj:
	return ProblemGen.make_object(rec.kind, rec.mat, Vector2(rec.x, rec.y), rec.s1, rec.s2, rec.rot, int(rec.get("extra", 0)))


func _object(i: int) -> SceneObj:
	return _build(draft.objects[i])


func _record_ok(rec: Dictionary, skip: int) -> bool:
	if not StageCode.size_ok(rec):
		return false
	var obj := _build(rec)
	if obj == null or not StageCode.in_field(obj):
		return false
	var others: Array = []
	for i in draft.objects.size():
		if i == skip:
			continue
		others.append(_object(i))
	return ProblemGen.no_overlap(obj, others)


## Which bodies are unusable and why, so the board can say so where it happened
func _find_faults() -> Dictionary:
	var objects: Array = []
	for i in draft.objects.size():
		objects.append(_object(i))
	var out := {}
	for i in objects.size():
		var obj: SceneObj = objects[i]
		if obj == null or not StageCode.size_ok(draft.objects[i]):
			out[i] = "大きさが範囲外"
			continue
		if not StageCode.in_field(obj):
			out[i] = "枠からはみ出している"
			continue
		var others: Array = []
		for j in objects.size():
			if j != i:
				others.append(objects[j])
		if not ProblemGen.no_overlap(obj, others):
			out[i] = "他の物体と重なっている"
	return out


## last drawn wins, so the body sitting on top is the one that gets picked
func _pick_object(pos: Vector2) -> int:
	for i in range(draft.objects.size() - 1, -1, -1):
		var obj := _object(i)
		if obj != null and obj.hit(pos, PICK_SLACK):
			return i
	return -1


func _source_root() -> Vector2:
	return ProblemGen.s_to_point(draft.source_s)


func _source_dir() -> Vector2:
	return ProblemGen.border_inward(draft.source_s).rotated(draft.source_tilt)


## where the light first reaches the border if nothing were in the way, so both
## handles sit on the frame and never contend with a body for a click
func _source_tip() -> Vector2:
	var root := _source_root()
	var d := _source_dir()
	var far := Isect.ray_rect_exit(root + d * 0.5, d, ProblemGen.FIELD)
	var tip: Vector2 = far.point if not far.is_empty() else root + d * MIN_AIM
	if tip.distance_to(root) < MIN_AIM:
		tip = root + d * MIN_AIM
	return tip


func _nearest_border_s(pos: Vector2) -> float:
	var r := ProblemGen.FIELD
	var x := clampf(pos.x, r.position.x, r.end.x)
	var y := clampf(pos.y, r.position.y, r.end.y)
	var dt := y - r.position.y
	var db := r.end.y - y
	var dl := x - r.position.x
	var dr := r.end.x - x
	var m := minf(minf(dt, db), minf(dl, dr))
	if m == dt:
		return x - r.position.x
	if m == dr:
		return r.size.x + (y - r.position.y)
	if m == db:
		return r.size.x + r.size.y + (r.end.x - x)
	return 2.0 * r.size.x + r.size.y + (r.end.y - y)


func _load_code(text: String) -> void:
	var parsed := StageCode.read(text)
	if parsed.has("error"):
		_note("読み込めません: " + str(parsed.error))
		return
	if parsed.mode == "seed":
		var rng := RandomNumberGenerator.new()
		rng.seed = parsed.seed
		var problem := ProblemGen.generate(Difficulty.LEVELS[parsed.level], rng)
		if problem.is_empty():
			_note("この seed からは再現できませんでした")
			return
		var lv: Dictionary = Difficulty.LEVELS[parsed.level]
		draft.fresnel = lv.fresnel
		draft.choices = lv.choices
		var snapped: Array = []
		for rec: Dictionary in StageCode.records_from(problem.objects):
			snapped.append(StageCode.snap(rec))
		draft.objects = snapped
		draft.source_s = StageCode.snap_source_s(_nearest_border_s(problem.source.p))
		var inward := ProblemGen.border_inward(draft.source_s)
		draft.source_tilt = StageCode.snap_tilt(clampf(inward.angle_to(problem.source.d), -StageCode.MAX_TILT, StageCode.MAX_TILT))
		# the seed replays exactly, so share that until the draft is edited
		seed_code = StageCode.from_seed(parsed.level, parsed.seed)
		seed_level = parsed.level
		_note("Lv. %d の seed を読み込みました．編集するとこのステージは共有コードになります" % (parsed.level + 1))
	else:
		draft.fresnel = parsed.fresnel
		draft.choices = parsed.choices
		draft.source_s = parsed.source_s
		draft.source_tilt = parsed.source_tilt
		draft.objects = parsed.objects
		seed_code = ""
		seed_level = -1
		_note("共有コードを読み込みました")
	_sync_controls()
	_refresh()


## Traces the stage as it stands and shows the beam plus the points that count
## as answers, independently of whether a playable set of choices exists yet
func _show_truth() -> void:
	var traced := RayTracer.trace(StageCode.objects_of(stage), ProblemGen.FIELD, StageCode.source_of(stage).p,
			StageCode.source_of(stage).d, {"fresnel": stage.fresnel, "min_intensity": 0.02, "max_events": 96})
	if not traced.ok:
		return
	beams.show_path(traced.segments, traced.exits)
	beams.set_reveal(INF)
	for i in ProblemGen.answers_in(traced.exits):
		truth.append(traced.exits[i].point)


func _refresh() -> void:
	faults = _find_faults()
	code = StageCode.from_stage(draft)
	stage = StageCode.read(code)
	preview = {}
	truth.clear()
	beams.clear_path()
	var msg := ""
	var col := Color(0.7, 0.82, 0.95)
	if not faults.is_empty():
		msg = "赤い物体を直してください (%d 個)" % faults.size()
		col = Color(1.0, 0.6, 0.6)
	elif stage.has("error"):
		msg = "コードにできません: " + str(stage.error)
		col = Color(1.0, 0.6, 0.6)
	else:
		# the real path is drawn whatever else is going on. Placing decoys by
		# hand is guesswork without seeing where the light lands
		_show_truth()
		var rng := RandomNumberGenerator.new()
		if seed_level >= 0:
			# an untouched seed is shared as a seed, so preview it the way the
			# game will build it or the answer count could differ
			rng.seed = StageCode.read(seed_code).seed
			preview = ProblemGen.generate(Difficulty.LEVELS[seed_level], rng)
		else:
			rng.seed = code.hash()
			preview = ProblemGen.build_custom(StageCode.objects_of(stage), StageCode.source_of(stage), stage.fresnel, stage.choices, rng, stage.get("decoys", []), stage.get("manual", false))
		if truth.is_empty():
			msg = "この配置では光が抜けません (光源の向きか物体の位置を変えてください)"
			col = Color(1.0, 0.75, 0.5)
		elif draft.manual and draft.decoys.is_empty():
			msg = "緑が正解の出口．枠のあたりをクリックして誤答の選択肢を置いてください"
			col = Color(1.0, 0.75, 0.5)
		elif preview.is_empty():
			msg = "この配置では出題できません (選択肢が置けていないか，正解に近すぎます)"
			col = Color(1.0, 0.75, 0.5)
		else:
			msg = "物体 %d 個   相互作用 %d回   答える箇所 %d   コード %d文字" % [
				draft.objects.size(), preview.trace.exits[0].events, (preview.correct as Array).size(), _share_code().length()]
	status_label.text = msg if status.is_empty() else msg + "    " + status
	status_label.add_theme_color_override("font_color", col)
	queue_redraw()


func _note(text: String) -> void:
	status = text
	_refresh()
	status = ""


func _copy_code() -> void:
	if not faults.is_empty() or stage.has("error"):
		_note("赤い物体があるうちは共有できません")
		return
	DisplayServer.clipboard_set(_share_code())
	_note("コードをクリップボードにコピーしました")


func _share_code() -> String:
	return seed_code if not seed_code.is_empty() else code


func _play() -> void:
	if not faults.is_empty():
		_note("赤い物体があるうちは遊べません")
		return
	if preview.is_empty():
		_note("出題できる配置になっていません")
		return
	GameState.play_stage(_share_code(), true)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _draw() -> void:
	FieldDraw.field(self)
	var objects: Array = []
	for rec: Dictionary in draft.objects:
		objects.append(_build(rec))
	FieldDraw.bodies(self, objects, font, selected if sel_kind == "object" else -1, faults)
	if sel_kind == "object" and selected >= 0 and selected < objects.size():
		_draw_handles(objects[selected])
	_draw_source_handles()
	for i in draft.decoys.size():
		var at := ProblemGen.s_to_point(draft.decoys[i])
		var chosen: bool = sel_kind == "decoy" and i == selected
		draw_circle(at, 15.0, Color(0.08, 0.10, 0.14, 0.85))
		draw_circle(at, 15.0, Color(1, 1, 1, 0.95) if chosen else Color(0.72, 0.82, 1.0, 0.7), false, 2.0, true)
	for p: Vector2 in truth:
		draw_circle(p, 17.0, Color(0.5, 1.0, 0.6, 0.9), false, 3.0, true)
	if preview.is_empty():
		return
	for i in preview.choices.size():
		var c: Vector2 = preview.choices[i]
		var col := Color(0.5, 1.0, 0.6, 0.9) if (preview.correct as Array).has(i) else Color(0.72, 0.82, 1.0, 0.55)
		draw_arc(c, 16.0, 0.0, TAU, 32, col, 2.0, true)
		draw_string(font, c + Vector2(-8, 6), StageCode.LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, 16, 15, col)


## corner grips on the selected body, so it is obvious where turning starts
func _draw_handles(obj: SceneObj) -> void:
	for v in obj.vertices():
		draw_circle(v, 5.0, Color(0.06, 0.08, 0.12, 0.9))
		draw_circle(v, 5.0, Color(1, 1, 1, 0.9), false, 1.5, true)


func _draw_source_handles() -> void:
	var root := _source_root()
	var tip := _source_tip()
	var green := Color(0.55, 1.0, 0.65)
	# dashed, so the aim line never reads as part of the traced beam
	draw_dashed_line(root, tip, Color(green, 0.3), 1.5, 9.0, true, true)
	FieldDraw.source(self, root, _source_dir(), 0.0)
	for h in [{"p": root, "on": drag == "root"}, {"p": tip, "on": drag == "tip"}]:
		var fill := Color(green, 0.9 if h.on else 0.35)
		draw_circle(h.p, HANDLE_R, fill)
		draw_circle(h.p, HANDLE_R, Color(1, 1, 1, 0.9), false, 2.0, true)
