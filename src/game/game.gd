extends Node2D


const LABELS := StageCode.LABELS
## width reserved either side of the prompt, so it stays centred on the frame
const SIDE := 200

var level: Dictionary
var problem: Dictionary = {}
var rng := RandomNumberGenerator.new()
var current_seed := 0
var current_code := ""
var picked: Array[int] = []
var revealed := false
var last_ok := false
var reveal_tween: Tween

var beams: Node2D
var memo: MemoLayer
var ui: Control
var hud: Label
var seed_label: Label
var copy_btn: Button
var retry_btn: Button
var markers: Array = []
var result_bar: PanelContainer
var result_label: Label
## the prompt and the memo hint, which belong on screen at the same times
var memo_row: HBoxContainer
var prompt_label: Label
var next_btn: Button
var replay_btn: Button


func _ready() -> void:
	level = Difficulty.LEVELS[GameState.current_level()]
	beams = BeamLayer.new()
	add_child(beams)
	memo = MemoLayer.new()
	add_child(memo)
	# a CanvasLayer gives the UI a real viewport rect to anchor against
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.theme = UiTheme.make()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_build_hud()
	_build_memo_controls()
	_build_result_bar()
	_next_problem()


func _build_hud() -> void:
	hud = Label.new()
	hud.position = Vector2(150, 22)
	ui.add_child(hud)
	# right aligned against the field's edge, so the seed and the buttons stay
	# together however long the code is
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.offset_left = 150
	box.offset_right = -150
	box.offset_top = 16
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 8)
	ui.add_child(box)
	seed_label = Label.new()
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(seed_label)
	copy_btn = Button.new()
	copy_btn.text = "コピー"
	copy_btn.custom_minimum_size = Vector2(90, 34)
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.pressed.connect(_copy_code)
	box.add_child(copy_btn)
	retry_btn = Button.new()
	retry_btn.text = "別の問題"
	retry_btn.custom_minimum_size = Vector2(104, 34)
	retry_btn.focus_mode = Control.FOCUS_NONE
	retry_btn.pressed.connect(_retry)
	# a shared stage is the one stage there is, so there is nothing to reroll to
	retry_btn.visible = GameState.stage_code.is_empty()
	box.add_child(retry_btn)
	var menu_btn := Button.new()
	menu_btn.text = "メニュー"
	menu_btn.custom_minimum_size = Vector2(100, 34)
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.pressed.connect(_to_menu)
	box.add_child(menu_btn)


## Below the frame, beside the prompt: the memo is only worth explaining while
## there is still something to work out, so it comes and goes with the prompt
func _build_memo_controls() -> void:
	memo_row = HBoxContainer.new()
	# clear of the markers, whose bottom halves hang below the frame
	memo_row.position = Vector2(150, 600)
	memo_row.custom_minimum_size = Vector2(980, 0)
	memo_row.add_theme_constant_override("separation", 0)
	ui.add_child(memo_row)
	var help := Label.new()
	# both ends are the same width, so the prompt between them stays centred on
	# the frame rather than on what is left over
	help.custom_minimum_size = Vector2(SIDE, 68)
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help.text = "左ドラッグ  書く\n右ドラッグ  一筆消す\nZ キー  ひとつ戻す"
	help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52, 0.85))
	memo_row.add_child(help)
	prompt_label = Label.new()
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.9))
	memo_row.add_child(prompt_label)
	var right := HBoxContainer.new()
	right.custom_minimum_size = Vector2(SIDE, 68)
	right.alignment = BoxContainer.ALIGNMENT_END
	memo_row.add_child(right)
	var wipe := Button.new()
	wipe.text = "メモを全消去"
	wipe.custom_minimum_size = Vector2(128, 34)
	wipe.focus_mode = Control.FOCUS_NONE
	wipe.pressed.connect(func() -> void: memo.clear_all())
	right.add_child(wipe)


func _copy_code() -> void:
	DisplayServer.clipboard_set(current_code)
	copy_btn.text = "コピー済"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(copy_btn):
		copy_btn.text = "コピー"


func _build_result_bar() -> void:
	result_bar = PanelContainer.new()
	result_bar.visible = false
	result_bar.position = Vector2(150, 600)
	result_bar.custom_minimum_size = Vector2(980, 76)
	ui.add_child(result_bar)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	result_bar.add_child(margin)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	margin.add_child(hb)
	result_label = Label.new()
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# a long verdict must not widen the bar past the frame, so it wraps into the
	# room it is given
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(300, 0)
	hb.add_child(result_label)
	replay_btn = Button.new()
	replay_btn.text = "もう一度再生  (R)"
	replay_btn.custom_minimum_size = Vector2(176, 44)
	replay_btn.focus_mode = Control.FOCUS_NONE
	replay_btn.pressed.connect(_replay)
	hb.add_child(replay_btn)
	next_btn = Button.new()
	next_btn.custom_minimum_size = Vector2(216, 44)
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(_advance)
	hb.add_child(next_btn)
	next_btn.text = "エディタへ  (Space)" if GameState.from_creative else "次の問題  (Space)"
	var menu_b := Button.new()
	menu_b.text = "メニュー"
	menu_b.custom_minimum_size = Vector2(104, 44)
	menu_b.focus_mode = Control.FOCUS_NONE
	menu_b.pressed.connect(_to_menu)
	hb.add_child(menu_b)


## Getting it wrong never moves you on. The only way forward is a fresh problem
## answered correctly, so the button names what it will do
func _advance() -> void:
	if GameState.from_creative:
		get_tree().change_scene_to_file("res://scenes/creative.tscn")
		return
	if last_ok:
		var nxt := GameState.next_level()
		if nxt < 0:
			_to_menu()
			return
		if GameState.is_open(nxt):
			GameState.start(nxt)
	_next_problem()


func _retry() -> void:
	if GameState.from_creative:
		return
	_next_problem()


func _to_menu() -> void:
	var back := "res://scenes/main.tscn"
	# a stage played from a code has no ladder of its own to go back to
	if GameState.stage_code.is_empty():
		GameState.menu_mode = GameState.mode
		back = "res://scenes/ladder.tscn"
	GameState.clear_stage()
	get_tree().change_scene_to_file(back)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion and memo.busy():
		# a release over a marker never reaches here, so a stroke that finds the
		# button already let go ends itself
		var held: int = (event as InputEventMouseMotion).button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)
		if held == 0:
			memo.finish()
		else:
			memo.extend(_pen(get_global_mouse_position()))
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		_to_menu()
	elif key == KEY_Z:
		memo.undo()
	elif key == KEY_R:
		_replay()
	elif revealed:
		if key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
			_advance()
	else:
		var idx := -1
		if key >= KEY_A and key <= KEY_H:
			idx = key - KEY_A
		elif key >= KEY_1 and key <= KEY_8:
			idx = key - KEY_1
		if idx >= 0 and idx < markers.size():
			_on_pick(idx)


## A press the markers did not take is a note. They are Buttons, so anything
## that reaches here missed them
func _on_mouse_button(event: InputEventMouseButton) -> void:
	var at := get_global_mouse_position()
	var writing: bool = event.button_index == MOUSE_BUTTON_LEFT
	var rubbing: bool = event.button_index == MOUSE_BUTTON_RIGHT
	if not (writing or rubbing):
		return
	if not event.pressed:
		memo.finish()
		return
	if ProblemGen.FIELD.has_point(at):
		memo.begin(at, rubbing)


## a drag that wanders off the board keeps writing, but only inside the frame
func _pen(at: Vector2) -> Vector2:
	var f := ProblemGen.FIELD
	return Vector2(clampf(at.x, f.position.x, f.end.x), clampf(at.y, f.position.y, f.end.y))


func _next_problem() -> void:
	_stop_reveal()
	result_bar.visible = false
	memo_row.visible = true
	picked.clear()
	revealed = false
	beams.clear_path()
	memo.wipe()
	problem = {}
	level = Difficulty.LEVELS[GameState.current_level()]
	if GameState.stage_code.is_empty():
		for _i in 20:
			rng.randomize()
			current_seed = rng.randi()
			rng.seed = current_seed
			problem = ProblemGen.generate(level, rng)
			if not problem.is_empty():
				break
		current_code = StageCode.from_seed(GameState.current_level(), current_seed)
	else:
		current_code = GameState.stage_code
		problem = _load_stage(current_code)
	if problem.is_empty():
		push_error("could not build a problem")
		return
	_update_prompt()
	_rebuild_markers()
	_update_hud()
	queue_redraw()


func _load_stage(code: String) -> Dictionary:
	var stage := StageCode.read(code)
	if stage.has("error"):
		push_error("bad stage code: " + str(stage.error))
		return {}
	if stage.mode == "seed":
		level = Difficulty.LEVELS[stage.level]
		current_seed = stage.seed
		rng.seed = current_seed
		return ProblemGen.generate(level, rng)
	# everyone holding the code must see the same options, so the decoys are
	# drawn from the code itself rather than from a fresh random stream
	rng.seed = code.hash()
	return ProblemGen.build_custom(StageCode.objects_of(stage), StageCode.source_of(stage), stage.fresnel, stage.choices, rng, stage.get("decoys", []), stage.get("manual", false))


func _rebuild_markers() -> void:
	for m in markers:
		m.queue_free()
	markers.clear()
	for i in problem.choices.size():
		var b := Button.new()
		b.text = LABELS[i]
		b.custom_minimum_size = Vector2(42, 42)
		b.position = (problem.choices[i] as Vector2) - Vector2(21, 21)
		b.focus_mode = Control.FOCUS_NONE
		_style_marker(b, false)
		b.pressed.connect(_on_pick.bind(i))
		ui.add_child(b)
		markers.append(b)


## A marker already picked is filled in and outlined, so a half finished set of
## answers can be read off the board at a glance
func _style_marker(b: Button, chosen: bool) -> void:
	var base := Color(0.42, 0.33, 0.12) if chosen else Color(0.15, 0.21, 0.32)
	var edge := Color(1.0, 0.86, 0.52, 0.95) if chosen else Color(0.72, 0.82, 1.0, 0.55)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = base.lightened(0.12) if state == "hover" else base
		sb.set_corner_radius_all(21)
		sb.set_border_width_all(3 if chosen else 2)
		sb.border_color = edge
		# the theme's own margins are not symmetric, which leaves the letter
		# sitting high in the circle
		sb.content_margin_left = 0.0
		sb.content_margin_right = 0.0
		sb.content_margin_top = 0.0
		sb.content_margin_bottom = 0.0
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72) if chosen else Color(0.9, 0.93, 0.97))


func _wanted() -> int:
	return problem.correct.size() if not problem.is_empty() else 1


func _update_prompt() -> void:
	var want := _wanted()
	var keys: String = LABELS.substr(0, problem.choices.size())
	if want == 1:
		prompt_label.text = "光が抜ける地点を選ぶ  (キー %s でも選択可)" % keys
	else:
		prompt_label.text = "光が抜ける地点を %d 箇所選ぶ  (%d / %d)   キー %s でも選択可" % [want, picked.size(), want, keys]


## With more than one answer a click toggles, and the reveal waits until the
## player has committed the whole set
func _on_pick(i: int) -> void:
	if revealed:
		return
	if picked.has(i):
		picked.erase(i)
		_style_marker(markers[i], false)
		_update_prompt()
		return
	picked.append(i)
	_style_marker(markers[i], true)
	if picked.size() < _wanted():
		_update_prompt()
		return
	revealed = true
	memo_row.visible = false
	for m in markers:
		m.disabled = true
	_play_reveal(true)


func _play_reveal(score_it: bool) -> void:
	beams.show_path(problem.trace.segments, problem.trace.exits)
	var t_max := 0.0
	for seg in problem.trace.segments:
		t_max = maxf(t_max, seg.t1)
	_stop_reveal()
	reveal_tween = create_tween()
	reveal_tween.tween_method(beams.set_reveal, 0.0, t_max, clampf(t_max, 0.8, 5.0))
	if score_it:
		reveal_tween.finished.connect(_show_result)


## Watching it again must not answer the problem a second time
func _replay() -> void:
	if not revealed or problem.is_empty():
		return
	_play_reveal(false)


## Space skips ahead while the beam is still drawing, and a tween left running
## would then reveal the next problem's answer
func _stop_reveal() -> void:
	if reveal_tween != null and reveal_tween.is_valid():
		reveal_tween.kill()
	reveal_tween = null


func _show_result() -> void:
	var right: Array = problem.correct
	var ok := true
	for i in picked:
		if not right.has(i):
			ok = false
	if picked.size() != right.size():
		ok = false
	GameState.record(ok)
	for i in markers.size():
		_style_marker(markers[i], false)
		if right.has(i):
			markers[i].modulate = Color(0.5, 1.4, 0.6)
		elif picked.has(i):
			markers[i].modulate = Color(1.5, 0.45, 0.45)
		else:
			markers[i].modulate = Color.WHITE
	var names := ""
	for i in right:
		names += LABELS[i]
	last_ok = ok
	if ok:
		GameState.mark_beaten()
	var txt := "○ 正解" if ok else "× 不正解    正解は %s" % names
	txt += "    相互作用 %d回" % problem.trace.exits[0].events
	if problem.trace.exits.size() > 1:
		txt += "    最も明るい出口に全体の %d%% が到達" % roundi(problem.trace.exits[0].intensity * 100.0)
	result_label.text = txt
	result_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65) if ok else Color(1.0, 0.6, 0.6))
	next_btn.text = _next_label(ok)
	_update_hud()
	result_bar.visible = true


func _next_label(ok: bool) -> String:
	if GameState.from_creative:
		return "エディタへ  (Space)"
	if not ok:
		return "別の問題で再挑戦  (Space)"
	return "次のレベルへ  (Space)" if GameState.next_level() >= 0 else "メニューへ  (Space)"


func _update_hud() -> void:
	if GameState.stage_code.is_empty():
		var where := Difficulty.label(GameState.current_level())
		if GameState.cleared[GameState.level_index]:
			where = "✓ " + where
		hud.text = "%s    スコア %d    連続正解 %d" % [where, GameState.score, GameState.streak]
		seed_label.text = "Seed: %s" % current_code
	else:
		hud.text = "共有ステージ"
		# a hand built layout packs into a code far too long to show
		seed_label.text = "Seed: %s" % current_code if current_code.begins_with("L") else "Seed: (作成ステージ)"


func _draw() -> void:
	FieldDraw.field(self)
	if problem.is_empty():
		return
	FieldDraw.bodies(self, problem.objects, ui.theme.default_font)
	# the hint stops short of the first surface, so it never draws light
	# carrying straight on through something
	var first_leg: float = problem.trace.segments[0].a.distance_to(problem.trace.segments[0].b)
	FieldDraw.source(self, problem.source.p, problem.source.d, minf(46.0, first_leg - 6.0))
