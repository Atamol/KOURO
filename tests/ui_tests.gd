extends Node
## Scene level tests, for what needs autoloads and a running SceneTree. Run:
##   godot --headless --path . res://tests/ui_tests.tscn
## The headless suite in run_tests.gd cannot reach these, -s scripts get no autoloads


var fails := 0
var count := 0


func _ready() -> void:
	GameState.testing = true
	# what the dev file happens to hold must not decide what the tests can reach
	for i in GameState.cleared.size():
		GameState.cleared[i] = true
	await _test_skip_during_reveal()
	await _test_normal_reveal()
	_test_dev_progress()
	await _test_main_progress()
	await _test_multi_answer()
	await _test_retry_and_replay()
	await _test_memo()
	await _test_menu_hints()
	await _test_play_shared_stage()
	await _test_editor_selection()
	await _test_source_handles()
	await _test_drag_offset()
	await _test_manual_shows_truth()
	await _test_shape_handles()
	await _test_drag_through()
	print("---")
	print("%d/%d passed" % [count - fails, count])
	get_tree().quit(1 if fails > 0 else 0)


func check(name: String, cond: bool) -> void:
	count += 1
	if cond:
		print("[PASS] " + name)
	else:
		fails += 1
		print("[FAIL] " + name)


func _start(level: int) -> Node:
	GameState.start(level)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	return game


# skipping ahead used to leave the old tween running, which then scored and
# revealed the answer of the problem that replaced it
func _test_main_progress() -> void:
	GameState.cleared[3] = false
	var game := await _start(3)
	for i in game.problem.correct:
		game._on_pick(i)
	await get_tree().create_timer(6.5).timeout
	check("a correct answer opens the next level", GameState.cleared[3] and GameState.is_open(4))
	check("the button offers the next level", game.next_btn.text.begins_with("次のレベル"))
	game.queue_free()
	await get_tree().process_frame
	GameState.cleared[3] = false
	var game2 := await _start(3)
	var wrong := 0
	for i in game2.problem.choices.size():
		if not (game2.problem.correct as Array).has(i):
			wrong = i
	game2._on_pick(wrong)
	await get_tree().create_timer(6.5).timeout
	check("a wrong answer opens nothing", not GameState.cleared[3])
	check("a wrong answer only offers another try", game2.next_btn.text.begins_with("別の問題"))
	game2.queue_free()
	await get_tree().process_frame


func _test_skip_during_reveal() -> void:
	var game := await _start(5)
	game._on_pick(0)
	game._advance()
	var fresh: Dictionary = game.problem
	await get_tree().create_timer(6.5).timeout
	check("skipping does not score the next problem", GameState.asked == 0 and GameState.streak == 0)
	check("skipping leaves the next problem unrevealed", not game.result_bar.visible and not game.revealed)
	check("skipping keeps the markers live", not game.markers[0].disabled)
	var untouched := true
	for m in game.markers:
		if not m.modulate.is_equal_approx(Color.WHITE):
			untouched = false
	check("skipping does not colour the answer", untouched and game.problem == fresh)
	game.queue_free()
	await get_tree().process_frame


func _test_normal_reveal() -> void:
	var game := await _start(5)
	for i in game.problem.correct:
		game._on_pick(i)
	await get_tree().create_timer(6.5).timeout
	check("answering scores once", GameState.asked == 1 and GameState.correct == 1)
	check("answering shows the result", game.result_bar.visible)
	game.queue_free()
	await get_tree().process_frame


## the hard level that parts a beam in two, which is where two answers come from
func _split_level() -> int:
	for i in range(Difficulty.HARD_START, Difficulty.LEVELS.size()):
		if Difficulty.LEVELS[i].get("require_split", false):
			return i
	return Difficulty.HARD_START


func _test_multi_answer() -> void:
	var at := _split_level()
	GameState.cleared[at] = false
	var game := await _start(at)
	var right: Array = game.problem.correct
	check("a splitting level asks for two points", right.size() == 2)
	# both answers must be the two halves of one split, not any two bright exits
	var pols := {}
	for i in right.size():
		pols[game.problem.trace.exits[i].pol] = true
	check("the answers are the ordinary and extraordinary beams", pols.has("s") and pols.has("p"))
	if right.size() == 2:
		game._on_pick(right[0])
		check("one pick is not enough", not game.revealed and game.picked.size() == 1)
		check("the first pick is marked on the board", game.markers[right[0]].get_theme_stylebox("normal").border_width_top == 3)
		game._on_pick(right[0])
		check("picking the same marker takes it back", game.picked.is_empty() and not game.revealed)
		check("and its mark comes off", game.markers[right[0]].get_theme_stylebox("normal").border_width_top == 2)
		game._on_pick(right[0])
		game._on_pick(right[1])
		check("the last pick commits the answer", game.revealed)
		await get_tree().create_timer(6.5).timeout
		check("getting both right scores", GameState.correct == 1 and GameState.asked == 1)
		check("a correct answer opens the next hard level", GameState.cleared[at] and GameState.is_open(at + 1))
	game.queue_free()
	await get_tree().process_frame
	GameState.cleared[at] = false
	# and getting only one of them right is wrong
	var game2 := await _start(at)
	var right2: Array = game2.problem.correct
	var wrong := 0
	for i in game2.problem.choices.size():
		if not right2.has(i):
			wrong = i
	game2._on_pick(right2[0])
	game2._on_pick(wrong)
	await get_tree().create_timer(6.5).timeout
	check("half right is wrong", GameState.correct == 0 and GameState.asked == 1)
	check("a wrong answer opens nothing", not GameState.cleared[at])
	check("the button offers another try", game2.next_btn.text.begins_with("別の問題"))
	game2.queue_free()
	await get_tree().process_frame


# a fresh problem at the same level, and watching the answer again, must
# neither score nor move the ladder along
func _test_retry_and_replay() -> void:
	var game := await _start(6)
	var before: Dictionary = game.problem
	var seed_before: String = game.current_code
	game._retry()
	await get_tree().process_frame
	check("another problem replaces this one", game.problem != before and game.current_code != seed_before)
	check("staying on the same level", GameState.level_index == 6)
	check("and it is not an answer", GameState.asked == 0 and not game.revealed)
	for i in game.problem.correct:
		game._on_pick(i)
	await get_tree().create_timer(6.5).timeout
	var scored: int = GameState.asked
	game._replay()
	check("replaying restarts the beam", game.beams.reveal_t < 0.001)
	await get_tree().create_timer(6.5).timeout
	check("replaying does not answer again", GameState.asked == scored)
	check("the result stays up", game.result_bar.visible)
	game.queue_free()
	await get_tree().process_frame


func _test_memo() -> void:
	var game := await _start(2)
	var mid: Vector2 = ProblemGen.FIELD.get_center()
	game.memo.begin(mid, false)
	game.memo.extend(mid + Vector2(60, 0))
	game.memo.extend(mid + Vector2(120, 30))
	game.memo.finish()
	check("a drag leaves a stroke", game.memo.strokes.size() == 1)
	game.memo.begin(mid + Vector2(0, 80), false)
	game.memo.extend(mid + Vector2(80, 80))
	game.memo.finish()
	check("a second drag leaves a second", game.memo.strokes.size() == 2)
	game.memo.begin(mid + Vector2(60, 0), true)
	game.memo.finish()
	check("the right button rubs out the stroke it touches", game.memo.strokes.size() == 1)
	game.memo.undo()
	check("undo puts a rubbed out stroke back", game.memo.strokes.size() == 2)
	game.memo.undo()
	check("undo takes a stroke off again", game.memo.strokes.size() == 1)
	game.memo.clear_all()
	check("all of it goes at once", game.memo.strokes.is_empty())
	game.memo.undo()
	check("and comes back at once", game.memo.strokes.size() == 1)
	# notes belong to the problem they were made on
	game._retry()
	await get_tree().process_frame
	check("a fresh problem starts on a clean board", game.memo.strokes.is_empty() and game.memo.history.is_empty())
	game.queue_free()
	await get_tree().process_frame


# a hint wider than the column used to stretch it, so the whole menu jumped
# every time the pointer crossed a button
func _test_menu_hints() -> void:
	var menu: Node = load("res://scenes/main.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check("nothing is explained before the pointer arrives", menu.detail.text.is_empty())
	var anchor: Vector2 = menu.buttons[0].global_position
	var still := true
	for m: String in Difficulty.MODES:
		menu._show_hint(m)
		await get_tree().process_frame
		await get_tree().process_frame
		if not (menu.buttons[0].global_position as Vector2).is_equal_approx(anchor):
			still = false
		if menu.detail.text.is_empty():
			still = false
	check("showing a hint leaves the buttons where they were", still)
	menu._hide_hint(Difficulty.MODES[Difficulty.MODES.size() - 1])
	check("leaving a button takes its hint away", menu.detail.text.is_empty())
	# the two signals can arrive in either order, and the stale one must not win
	menu._show_hint("hard")
	menu._hide_hint("main")
	check("a late leave from the button before does not", not menu.detail.text.is_empty())
	menu.queue_free()
	await get_tree().process_frame

	GameState.menu_mode = "main"
	var ladder: Node = load("res://scenes/ladder.tscn").instantiate()
	add_child(ladder)
	await get_tree().process_frame
	check("the ladder screen starts quiet too", ladder.detail.text.is_empty())
	var seat: Vector2 = ladder.buttons[0].global_position
	ladder._show_detail(Difficulty.MAIN_COUNT - 1)
	await get_tree().process_frame
	await get_tree().process_frame
	check("and stays put when a level is explained",
			(ladder.buttons[0].global_position as Vector2).is_equal_approx(seat) and not ladder.detail.text.is_empty())
	ladder._hide_detail(Difficulty.MAIN_COUNT - 1)
	check("and clears on the way out", ladder.detail.text.is_empty())
	ladder.queue_free()
	await get_tree().process_frame


func _test_play_shared_stage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4600
	var built := ProblemGen.generate(Difficulty.LEVELS[6], rng)
	var code := StageCode.from_seed(6, 4600)
	GameState.play_stage(code, false)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var same: bool = not game.problem.is_empty() and str(game.problem.correct) == str(built.correct) \
			and game.problem.choices.size() == built.choices.size()
	for i in game.problem.choices.size():
		if not (game.problem.choices[i] as Vector2).is_equal_approx(built.choices[i]):
			same = false
	check("a seed code replays its exact problem", same)
	check("a seed code shows in the HUD", game.seed_label.text == "Seed: " + code)
	game.queue_free()
	await get_tree().process_frame
	# the editor must preview a loaded seed the way the game will play it
	GameState.play_stage(code, false)
	var ed: Node = load("res://scenes/creative.tscn").instantiate()
	add_child(ed)
	await get_tree().process_frame
	check("the editor previews a seed with the same answer count",
			not ed.preview.is_empty() and (ed.preview.correct as Array).size() == built.correct.size())
	check("an untouched seed is still shared as a seed", ed._share_code() == code)
	ed.queue_free()
	GameState.clear_stage()
	await get_tree().process_frame


# turning the generator off must not hide where the light goes

func _test_manual_shows_truth() -> void:
	var ed := await _editor()
	ed._place_shape(2)
	ed.draft.manual = true
	ed.draft.decoys.clear()
	ed._touch()
	check("the real exits show before any decoy is placed", not ed.truth.is_empty())
	check("nothing is playable until a decoy exists", ed.preview.is_empty())
	var s: float = ProblemGen._border_s(ed.truth[0])
	ed._add_decoy(ProblemGen.s_to_point(fposmod(s + 700.0, 2.0 * (ProblemGen.FIELD.size.x + ProblemGen.FIELD.size.y))))
	check("a hand placed decoy makes it playable", not ed.preview.is_empty() and ed.preview.choices.size() == 1 + ed.truth.size())
	check("the answer is still shown", not ed.truth.is_empty())
	ed._select(0, "decoy")
	ed._delete_selected()
	check("the decoy can be deleted again", ed.draft.decoys.is_empty() and ed.preview.is_empty() and not ed.truth.is_empty())
	# both source handles sit on the border, which is where decoys go too, so a
	# click meant for the source must not drop a marker instead
	var root: Vector2 = ed._source_root()
	var tip: Vector2 = ed._source_tip()
	ed._press_at(root)
	check("the root still grabs in manual mode", ed.drag == "root" and ed.draft.decoys.is_empty())
	ed.drag = ""
	ed._press_at(tip)
	check("the aim handle still grabs in manual mode", ed.drag == "tip" and ed.draft.decoys.is_empty())
	ed.drag = ""
	var beside: Vector2 = tip + (tip - root).normalized().rotated(PI * 0.5) * 26.0
	ed._press_at(beside)
	check("a click just off a handle does not drop a decoy", ed.draft.decoys.is_empty())
	ed.queue_free()
	await get_tree().process_frame


func _test_dev_progress() -> void:
	var kept: Array[bool] = GameState.cleared.duplicate()
	var cfg := ConfigFile.new()
	cfg.set_value("dev", "main", 5)
	cfg.set_value("dev", "hard", 2)
	GameState.apply_dev(cfg)
	var opened: bool = true
	for i in Difficulty.MAIN_COUNT:
		if GameState.cleared[i] != (i < 5):
			opened = false
	check("the dev file sets how far each ladder is open", opened)
	check("the level after the last one is playable", GameState.is_open(5) and not GameState.is_open(6))
	check("a ladder of its own for hard", GameState.cleared_in("hard") == 2 and GameState.cleared_in("extra") == 0)
	# hard is gated on main, so a count alone must not open it
	check("hard stays shut until main allows it", not GameState.mode_open("hard") and not GameState.is_open(Difficulty.HARD_START))
	var far := ConfigFile.new()
	far.set_value("dev", "main", Difficulty.MAIN_COUNT)
	far.set_value("dev", "hard", Difficulty.HARD_COUNT)
	GameState.apply_dev(far)
	check("finishing main opens hard", GameState.mode_open("hard") and GameState.is_open(Difficulty.HARD_START))
	check("finishing hard opens extra", GameState.mode_open("extra") and GameState.is_open(Difficulty.EXTRA_START))
	# an out of range count must not spill into the next ladder
	var over := ConfigFile.new()
	over.set_value("dev", "main", 9999)
	GameState.apply_dev(over)
	check("an oversized count clamps", GameState.cleared[Difficulty.MAIN_COUNT - 1] and not GameState.cleared[Difficulty.HARD_START])
	var blank := ConfigFile.new()
	GameState.apply_dev(blank)
	check("an empty file locks everything", not GameState.cleared[0] and not GameState.mode_open("hard"))
	GameState.cleared = kept


func _editor() -> Node:
	GameState.clear_stage()
	var ed: Node = load("res://scenes/creative.tscn").instantiate()
	add_child(ed)
	await get_tree().process_frame
	return ed


func _test_editor_selection() -> void:
	var ed := await _editor()
	check("nothing selected at first", ed.selected == -1 and ed.delete_btn.disabled and ed.mat_picker.disabled)
	ed._place_shape(2)
	var placed: bool = ed.draft.objects.size() == 1 and ed.selected == 0
	check("placing selects the new body", placed and not ed.delete_btn.disabled and not ed.mat_picker.disabled)
	if placed:
		var rec: Dictionary = ed.draft.objects[0]
		var at := Vector2(rec.x, rec.y)
		ed._select(-1)
		ed._press_at(at)
		check("clicking a body selects it", ed.selected == 0 and ed.drag == "object")
		# a corner of the field is inside the board but well clear of the circle
		ed._press_at(ProblemGen.FIELD.position + Vector2(40, 460))
		check("clicking the background clears the selection", ed.selected == -1 and ed.drag.is_empty())
		check("commands switch off with no selection", ed.delete_btn.disabled and ed.mat_picker.disabled)
		ed._press_at(at)
		ed._delete_selected()
		check("delete removes the selected body", ed.draft.objects.is_empty() and ed.delete_btn.disabled)
	ed.queue_free()
	await get_tree().process_frame


func _test_source_handles() -> void:
	var ed := await _editor()
	var root: Vector2 = ed._source_root()
	var tip: Vector2 = ed._source_tip()
	ed._press_at(root.lerp(tip, 0.5))
	check("the shaft between the handles is not grabbable", ed.drag.is_empty())
	var s0: float = ed.draft.source_s
	var tilt0: float = ed.draft.source_tilt
	ed._press_at(root)
	check("the root handle grabs", ed.drag == "root")
	ed._on_drag(ProblemGen.FIELD.position + Vector2(0, 200))
	check("dragging the root moves the source", not is_equal_approx(ed.draft.source_s, s0))
	check("dragging the root leaves the angle alone", is_equal_approx(ed.draft.source_tilt, tilt0))
	ed.drag = ""
	var s1: float = ed.draft.source_s
	ed._press_at(ed._source_tip())
	check("the tip handle grabs", ed.drag == "tip")
	var aim: Vector2 = ed._source_root() + ProblemGen.border_inward(s1).rotated(0.4) * 200.0
	ed._on_drag(aim)
	check("dragging the tip turns the source", not is_equal_approx(ed.draft.source_tilt, tilt0))
	check("dragging the tip leaves the position alone", is_equal_approx(ed.draft.source_s, s1))
	var f := ProblemGen.FIELD
	var tip2: Vector2 = ed._source_tip()
	var on_frame: bool = absf(tip2.x - f.position.x) < 0.5 or absf(tip2.x - f.end.x) < 0.5 \
			or absf(tip2.y - f.position.y) < 0.5 or absf(tip2.y - f.end.y) < 0.5
	check("the aim handle sits on the frame", on_frame)
	ed.queue_free()
	await get_tree().process_frame


func _test_drag_offset() -> void:
	var ed := await _editor()
	ed._place_shape(1)
	var rec: Dictionary = ed.draft.objects[0]
	var before := Vector2(rec.x, rec.y)
	# grab it off centre, the body must not snap its middle onto the cursor
	var press := before + Vector2(60, 0)
	ed._press_at(press)
	var grabbed: bool = ed.drag == "object"
	check("pressing away from the middle still grabs the body", grabbed)
	if grabbed:
		ed._on_drag(press + Vector2(40, 30))
		var after := Vector2(ed.draft.objects[0].x, ed.draft.objects[0].y)
		check("dragging keeps the grab offset", after.distance_to(before + Vector2(40, 30)) < 1.5)
	ed.queue_free()
	await get_tree().process_frame


func _test_shape_handles() -> void:
	var ed := await _editor()
	ed._place_shape(1)
	var rec: Dictionary = ed.draft.objects[0]
	var centre := Vector2(rec.x, rec.y)
	var rim := centre + Vector2(rec.s1 * 0.5, 0.0)
	ed._press_at(rim)
	check("the rim starts a resize", ed.drag == "resize")
	ed._on_drag(rim + Vector2(30, 0))
	check("dragging the rim resizes", ed.draft.objects[0].s1 > rec.s1)
	ed.drag = ""
	var corner: Vector2 = ed._object(0).vertices()[0]
	ed._press_at(corner)
	check("a corner starts a rotation", ed.drag == "rotate")
	var was: float = ed.draft.objects[0].rot
	var mid := Vector2(ed.draft.objects[0].x, ed.draft.objects[0].y)
	ed._on_drag(mid + (corner - mid).rotated(0.6))
	check("dragging a corner turns the body", absf(ed.draft.objects[0].rot - was) > 0.4)
	ed.drag = ""
	ed._delete_selected()
	ed._place_shape(0)
	var ends: PackedVector2Array = ed._object(0).vertices()
	ed._press_at(ends[0])
	check("a mirror end starts an endpoint drag", ed.drag == "endpoint")
	var other := ends[1]
	ed._on_drag(ends[0] + Vector2(0, 40))
	var moved: PackedVector2Array = ed._object(0).vertices()
	var anchored: bool = moved[0].distance_to(other) < 2.0 or moved[1].distance_to(other) < 2.0
	check("the far end of a mirror stays put", anchored)
	ed.queue_free()
	await get_tree().process_frame


func _test_drag_through() -> void:
	var ed := await _editor()
	ed._place_shape(2)
	ed._place_shape(2)
	var two: bool = ed.draft.objects.size() == 2
	check("two bodies placed", two)
	if two:
		var home := Vector2(ed.draft.objects[0].x, ed.draft.objects[0].y)
		var mover := Vector2(ed.draft.objects[1].x, ed.draft.objects[1].y)
		ed._press_at(mover)
		ed._on_drag(home)
		var landed := Vector2(ed.draft.objects[1].x, ed.draft.objects[1].y)
		check("a body can be carried over another", landed.distance_to(home) < 2.0)
		check("the overlap is flagged", ed.faults.size() == 2)
		check("nothing is playable while flagged", ed.preview.is_empty())
		ed._on_drag(home + Vector2(300, 0))
		check("carrying it clear clears the flag", ed.faults.is_empty())
	ed.queue_free()
	await get_tree().process_frame
