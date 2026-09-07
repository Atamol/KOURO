extends Node
## Scene level tests, for what needs autoloads and a running SceneTree. The
## headless suite in run_tests.gd cannot reach these, -s scripts get no autoloads


var fails := 0
var count := 0


func _ready() -> void:
	GameState.testing = true
	# the checks read wording off the screen. English is covered by tools/lang_shot.tscn
	Lang.locale = "ja"
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
	await _test_reveal_one_path()
	await _test_menu_hints()
	_test_score_carries()
	_test_score_posting()
	await _test_reset_asks()
	_test_unlock_notice()
	await _test_tutorial()
	await _test_rules_topic()
	await _test_tutorial_menu()
	await _test_tutorial_badge()
	await _test_codex()
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
	await _board_ready(game)
	return game


## The board is searched for on a worker, so it is not there on the first frame
func _board_ready(game: Node) -> void:
	for _i in 100000:
		if not (game.problem as Dictionary).is_empty():
			return
		await get_tree().process_frame


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
	await _board_ready(game)
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
	# the counters ride across stages, so what is checked is the change
	var asked0: int = GameState.asked
	var correct0: int = GameState.correct
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
		check("getting both right scores", GameState.correct == correct0 + 1 and GameState.asked == asked0 + 1)
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
	var asked1: int = GameState.asked
	var correct1: int = GameState.correct
	var score1: int = GameState.score
	game2._on_pick(right2[0])
	game2._on_pick(wrong)
	await get_tree().create_timer(6.5).timeout
	check("half right is wrong", GameState.correct == correct1 and GameState.asked == asked1 + 1)
	# guessing has to be worth nothing on average, so a miss costs what one mark
	# out of the set is worth
	check("and it costs points", GameState.score == maxi(score1 - GameState.miss_cost(game2.problem.choices.size()), 0))
	check("a wrong answer opens nothing", not GameState.cleared[at])
	check("the button offers another try", game2.next_btn.text.begins_with("別の問題"))
	game2.queue_free()
	await get_tree().process_frame


# a fresh problem at the same level, and watching the answer again, must
# neither score nor move the ladder along
func _test_retry_and_replay() -> void:
	var game := await _start(6)
	var asked0: int = GameState.asked
	var before: Dictionary = game.problem
	var seed_before: String = game.current_code
	game._retry()
	await _board_ready(game)
	check("another problem replaces this one", game.problem != before and game.current_code != seed_before)
	check("staying on the same level", GameState.level_index == 6)
	check("and it is not an answer", GameState.asked == asked0 and not game.revealed)
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
	# a straight stroke keeps only its two ends, however far the pointer wandered
	game.memo.begin(mid + Vector2(-100, -60), false, true)
	game.memo.extend(mid + Vector2(-40, 20))
	game.memo.extend(mid + Vector2(20, -40))
	game.memo.finish()
	var line: PackedVector2Array = game.memo.strokes[game.memo.strokes.size() - 1]
	check("Shift draws a straight line", line.size() == 2 and line[1].is_equal_approx(mid + Vector2(20, -40)))
	game.memo.undo()
	check("and undoes as one stroke", game.memo.strokes.size() == 1)
	# notes belong to the problem they were made on
	game._retry()
	await _board_ready(game)
	check("a fresh problem starts on a clean board", game.memo.strokes.is_empty() and game.memo.history.is_empty())
	game.queue_free()
	await get_tree().process_frame


# drawing every branch answers a question nobody was asked, so the reveal shows
# the beam that reached the answer and stops there
func _test_reveal_one_path() -> void:
	# a hard board, since normal mode no longer lets a face part the beam at all
	var game := await _start(Difficulty.start_of("hard") + 4)
	check("the trace really did branch", game.problem.trace.exits.size() > 1)
	game._play_reveal(false)
	check("but only one path is drawn", game.beams.segments.size() < game.problem.trace.segments.size())
	check("and only the answer glows", game.beams.exits.size() == (game.problem.correct as Array).size())
	game.queue_free()
	await get_tree().process_frame
	# a crystal is the one thing that makes a second beam an answer of its own
	var split := await _start(Difficulty.start_of("hard") + 2)
	split._play_reveal(false)
	check("a crystal keeps every branch on screen", split.beams.segments.size() == split.problem.trace.segments.size())
	split.queue_free()
	await get_tree().process_frame


# the last page runs the same Snell the game does, so it has to agree with it
func _test_tutorial() -> void:
	GameState.tutorial_topic = "refract"
	var tut: Node = load("res://scenes/tutorial.tscn").instantiate()
	add_child(tut)
	await get_tree().process_frame
	check("it opens on the first page", tut.page == 0 and not tut.media_row.visible)
	# the first page steps out of the topic rather than being a dead end
	check("and its back button leaves the topic", tut.back_btn.text == "一覧へ" and not tut.back_btn.disabled)
	tut._show_page(1)
	check("and reads as a back button after that", tut.back_btn.text == "戻る")
	for i in GameState.tutorial_read.size():
		GameState.tutorial_read[i] = false
	tut._show_page((tut.pages as Array).size() - 1)
	check("reading a topic through marks it", GameState.topic_read("refract"))
	check("the controls only come out on the last page", tut.media_row.visible and tut.live_label.visible)
	tut.knob = 40.0
	tut.from_air = true
	tut.medium = "soda_glass"
	tut._refresh()
	await get_tree().process_frame
	var bent := asin(sin(deg_to_rad(40.0)) * OpticsMaterials.AIR / OpticsMaterials.TRANSPARENT.soda_glass.n)
	check("air into glass bends toward the normal", tut.live_label.text.contains("%.1f" % rad_to_deg(bent)))
	# 40 degrees is inside the glass to air critical angle, 55 is past it
	tut.from_air = false
	tut._refresh()
	await get_tree().process_frame
	check("the same angle still gets out the other way", not tut.live_label.text.contains("全反射"))
	tut.knob = 55.0
	tut._refresh()
	await get_tree().process_frame
	check("and past the critical angle nothing gets through", tut.live_label.text.contains("全反射"))
	tut._turn(-1)
	check("the arrow keys turn the beam", not is_equal_approx(tut.knob, 55.0))
	# the page said it could be dragged, but a Control that stops the pointer ate
	# the click before _unhandled_input ever saw it. The headless display server
	# runs no input pipeline, so the two halves are checked apart
	check("the screen lets a click through to the board", tut.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	tut.knob = 0.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(tut.BOARD.position.x + 120.0, tut.BOARD.position.y + 60.0)
	press.global_position = press.position
	tut._unhandled_input(press)
	check("and dragging the screen turns it too", not is_equal_approx(tut.knob, 0.0))
	# holding one down carries on by itself, rather than waiting on the keyboard
	tut.knob = 0.0
	var hold := InputEventKey.new()
	hold.keycode = KEY_RIGHT
	hold.physical_keycode = KEY_RIGHT
	hold.pressed = true
	Input.parse_input_event(hold)
	Input.flush_buffered_events()
	tut._process(tut.HOLD_DELAY + tut.HOLD_STEP * 4.0)
	check("a held key keeps going", tut.knob >= tut.KNOB[tut.topic].step * 4.0)
	hold.pressed = false
	Input.parse_input_event(hold)
	Input.flush_buffered_events()
	tut._process(0.5)
	var settled: float = tut.knob
	tut._process(0.5)
	check("and stops when it is let go", is_equal_approx(tut.knob, settled))
	tut.queue_free()
	await get_tree().process_frame


# the score is a run total now: it survives picking another stage, and only the
# button on the menu clears it
func _test_score_carries() -> void:
	GameState.reset_score()
	GameState.record(true, 5)
	GameState.record(true, 5)
	# the second in a row is worth the board plus one step of the chain
	var expect := 2 * GameState.SOLVED + GameState.CHAIN
	check("a run pays more than the boards alone", GameState.score == expect)
	GameState.start(3)
	check("and choosing another stage leaves it alone", GameState.score == expect)
	GameState.record(false, 5)
	check("a miss costs one mark's worth", GameState.score == expect - GameState.miss_cost(5))
	check("and takes the run away", GameState.streak == 0)
	for _i in 20:
		GameState.record(true, 5)
	check("the chain stops climbing at its cap", GameState.chain_bonus(50) == GameState.CHAIN * GameState.CHAIN_CAP)
	GameState.reset_score()
	GameState.record(false, 3)
	check("and it never falls below nothing", GameState.score == 0)
	# a blind pick wins 100/C of the time and loses the rest, and those have to
	# cancel or pressing marks at random becomes the way to play
	var fair := true
	for c in range(3, 9):
		var win := float(GameState.SOLVED) / float(c)
		var lose := float(c - 1) / float(c) * float(GameState.miss_cost(c))
		if absf(win - lose) > 1.0:
			fair = false
	check("guessing is worth nothing whatever the board offers", fair)
	GameState.reset_score()
	# a coded board must leave every counter where it was
	GameState.record(true, 5)
	var held := [GameState.score, GameState.streak, GameState.best_streak, GameState.asked, GameState.correct]
	GameState.play_stage("L1-16c0a2fc", true)
	for _i in 5:
		GameState.record(true, 5)
		GameState.record(false, 5)
	check("a coded board never moves the score", held == [GameState.score, GameState.streak, GameState.best_streak, GameState.asked, GameState.correct])
	GameState.clear_stage()
	GameState.record(true, 5)
	check("and the ladder scores again after one", GameState.score > held[0])
	GameState.reset_score()


# a total counted as sent when the request failed is one nobody ever sees, so
# only an answer from the board may move the mark. The client itself is only
# built in a release run, so what is tested is what its answer does here
func _test_score_posting() -> void:
	GameState.posted = 0
	GameState.sending = 500
	GameState._on_board_answered(true, UnityroomClient.ScoreUploadResponse.new(true))
	check("an accepted total is the new mark", GameState.posted == 500 and GameState.sending == 0)
	GameState.sending = 700
	GameState._on_board_answered(false, UnityroomClient.ErrorResponse.new(500, "server", "down"))
	check("a refused total leaves the mark alone", GameState.posted == 500)
	check("and is not left counted as in flight", GameState.sending == 0)
	GameState.sending = 700
	GameState._on_board_answered(false, UnityroomClient.ErrorResponse.new(0, "throttled", "queued"))
	check("a throttled total is left to the client", GameState.posted == 500 and GameState.sending == 0)
	GameState.posted = 0
	GameState.sending = 0


# opening a mode happens while the player is on a stage screen, so it has to be
# handed to whoever can say so
func _test_unlock_notice() -> void:
	for i in GameState.cleared.size():
		GameState.cleared[i] = false
	GameState.just_opened.clear()
	GameState.clear_stage()
	GameState.start(Difficulty.TEACHING.size() - 1)
	check("hard is shut until the teaching levels are done", not GameState.mode_open("hard"))
	GameState.mark_beaten()
	check("clearing the last of them opens hard", GameState.mode_open("hard"))
	check("and it is queued to be announced", GameState.take_opened() == "hard")
	check("but only the once", GameState.take_opened().is_empty())
	for i in GameState.cleared.size():
		GameState.cleared[i] = true


# nothing else in the tutorial says what the game is for, so this one has to be
# first and has to be readable from the start
func _test_rules_topic() -> void:
	check("the rules come first in the list", TutorialTopics.LIST[0].key == "rules")
	check("and are open from the beginning", not TutorialTopics.LIST[0].hard)
	GameState.tutorial_topic = "rules"
	var tut: Node = load("res://scenes/tutorial.tscn").instantiate()
	add_child(tut)
	await get_tree().process_frame
	tut._show_page((tut.pages as Array).size() - 1)
	await get_tree().process_frame
	var marks: Array = tut._rules_marks()
	var right: int = (tut.rules.correct as Array)[0]
	check("the rules stand on a board the ladder itself made",
			not (tut.rules as Dictionary).is_empty() and marks.size() >= 3)
	# mirrors only: nothing on it needs a topic the reader has not opened yet
	var plain := true
	for o: SceneObj in (tut.rules.objects as Array):
		if not o.is_reflector():
			plain = false
	check("and it asks for nothing but reflection", plain)
	check("with no total reflection on the way", tut.rules.trace.exits[0].tir == 0)
	var spread := true
	for i in marks.size():
		for k in range(i + 1, marks.size()):
			if (marks[i] as Vector2).distance_to(marks[k]) < 60.0:
				spread = false
	check("and its marks do not sit on top of each other", spread)
	check("the page does not open already answered", int(tut.knob) != right)
	# clicking one is the very thing the page is teaching
	tut._aim(marks[right])
	check("clicking a mark picks it", int(tut.knob) == right)
	tut.knob = float((right + 1) % marks.size())
	tut._refresh()
	await get_tree().process_frame
	check("a wrong pick keeps the path to itself", (tut.live_label.text as String).contains("選んでいます"))
	tut.knob = float(right)
	tut._refresh()
	await get_tree().process_frame
	check("and the right one gives it away", (tut.live_label.text as String).contains("正解"))
	tut.queue_free()
	await get_tree().process_frame


# a locked topic must not name the gimmick it covers: the levels that introduce
# it are the ones asking the question
func _test_tutorial_menu() -> void:
	for i in GameState.cleared.size():
		GameState.cleared[i] = false
	var menu: Node = load("res://scenes/tutorial_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var locked := 0
	var open := 0
	var named := 0
	for i in TutorialTopics.LIST.size():
		var topic: Dictionary = TutorialTopics.LIST[i]
		var b: Button = menu.buttons[i]
		if topic.hard:
			locked += 1
			if b.disabled and (b.text as String).contains(menu.HIDDEN):
				named += 1
		else:
			open += 1
			if not b.disabled and (b.text as String).contains(topic.title):
				named += 1
	check("every topic reads either as itself or as unknown", named == locked + open)
	check("and hard mode really does hold some back", locked > 0 and open > 0)
	menu.queue_free()
	for i in GameState.cleared.size():
		GameState.cleared[i] = true
	await get_tree().process_frame


# the mark says a topic turned up while the player was elsewhere, so it must not
# be standing there from the start nor stay after the topics have been read
func _test_tutorial_badge() -> void:
	for i in GameState.cleared.size():
		GameState.cleared[i] = false
	for i in GameState.tutorial_read.size():
		GameState.tutorial_read[i] = false
	check("nothing is new before anything has opened", not GameState.tutorial_news())
	for i in Difficulty.TEACHING.size():
		GameState.cleared[i] = true
	check("finishing the teaching levels brings the hard topics in", GameState.tutorial_news())
	var menu: Node = load("res://scenes/main.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check("and the menu marks the tutorial button", menu.badge.visible)
	for i in GameState.tutorial_read.size():
		GameState.tutorial_read[i] = true
	menu._refresh()
	check("reading them takes the mark away", not menu.badge.visible)
	menu.queue_free()
	for i in GameState.cleared.size():
		GameState.cleared[i] = true
	await get_tree().process_frame


# the pictures run the real tracer, so every material has to come out drawable.
# One that throws or leaves the readout blank would only show up when clicked
func _test_codex() -> void:
	var codex: Node = load("res://scenes/codex.tscn").instantiate()
	add_child(codex)
	await get_tree().process_frame
	check("the codex lists every material there is", (codex.keys as Array).size()
			== OpticsMaterials.BY_INDEX.size() + OpticsMaterials.REFLECTIVE_ORDER.size())
	var blank := ""
	for i in (codex.keys as Array).size():
		codex._select(i)
		await get_tree().process_frame
		if (codex.live_label.text as String).is_empty() or (codex.facts.text as String).is_empty():
			blank = codex.keys[i]
	check("and each one draws with something to read off it", blank.is_empty())
	# what makes a kind different has to reach the screen
	for pair: Array in [["calcite", "2本"], ["sucrose", "回り"], ["silver", "96"], ["diamond", "屈折角"]]:
		codex._select((codex.keys as Array).find(pair[0]))
		await get_tree().process_frame
		check("%s says what it does" % pair[0], (codex.live_label.text as String).contains(pair[1]))
	var missing := ""
	for table: Dictionary in [codex.TRIVIA, codex.TRIVIA_EN]:
		for key: String in codex.keys:
			if not table.has(key) or (table[key] as String).is_empty():
				missing = key
	check("and says what it is away from the board, in both languages", missing.is_empty())
	codex._select((codex.keys as Array).find("soda_glass"))
	var before: Vector2 = codex._dir()
	codex._turn(1)
	check("the arrow keys swing the beam", codex._dir().dot(before) < 0.9999)
	# the beam is moved by two handles on the frame, the way the editor's source is
	check("the tip is one handle", codex._grabbed(codex.tip) == "tip")
	check("and the root is the other", codex._grabbed(codex.root) == "root")
	check("but the middle of the picture is neither", (codex._grabbed(codex.BOARD.get_center()) as String).is_empty())
	var was: Vector2 = codex.tip
	codex.drag = "tip"
	codex._on_drag(Vector2(codex.BOARD.end.x - 40.0, codex.BOARD.position.y - 30.0))
	check("dragging a handle moves the beam", not codex.tip.is_equal_approx(was))
	check("and leaves it on the frame", absf(codex.tip.y - codex.BOARD.position.y) < 0.5)
	codex.queue_free()
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
	check("showing a hint leaves the buttons where they were", still)
	# an open ladder says how hard it is, a shut one says the way in instead
	for i in GameState.cleared.size():
		GameState.cleared[i] = false
	menu._show_hint("hard")
	check("a shut mode explains how to open it", menu.detail.text.contains("解放"))
	for i in GameState.cleared.size():
		GameState.cleared[i] = true
	var said := true
	for m: String in Difficulty.MODES:
		menu._show_hint(m)
		if menu.detail.text.is_empty() or menu.detail.text.contains("解放"):
			said = false
	check("and once open each one says how hard it is", said)
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
	await _board_ready(game)
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


# clearing a whole run sits one click away from opening a ladder, so it asks
# first and does nothing until the answer comes back
func _test_reset_asks() -> void:
	var menu: Node = load("res://scenes/main.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	GameState.reset_score()
	GameState.record(true, 5)
	var before: int = GameState.score
	menu._ask_reset()
	await get_tree().process_frame
	check("the reset button asks rather than acting", menu.confirm.visible and GameState.score == before)
	menu.confirm.hide()
	await get_tree().process_frame
	check("and backing out leaves the score alone", GameState.score == before)
	menu._ask_reset()
	await get_tree().process_frame
	menu.confirm.confirmed.emit()
	await get_tree().process_frame
	check("saying yes clears it", GameState.score == 0)
	menu.queue_free()
	await get_tree().process_frame
