extends Node
## Dev tool: boots every screen and shoots it. Run with
## `godot --path . res://tools/capture.tscn`, shots land in user://shots


const DIR := "user://shots/"

## `-- editor` skips the levels, for iterating on the menus and the editor
var only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		only = arg
	# shooting every level answers them all, which would otherwise unlock the
	# whole ladder in the player's save
	GameState.testing = true
	DirAccess.make_dir_recursive_absolute(DIR)
	print("shots -> " + ProjectSettings.globalize_path(DIR))
	for scene in ["main", "creative"]:
		# the editor shot is more useful with a stage in it
		GameState.stage_code = StageCode.from_seed(6, 4600) if scene == "creative" else ""
		var node: Node = load("res://scenes/%s.tscn" % scene).instantiate()
		add_child(node)
		await get_tree().create_timer(0.4).timeout
		# show the editor with something selected, the highlight is the point
		if scene == "creative" and not node.draft.objects.is_empty():
			node._select(0)
			node.queue_redraw()
			await get_tree().process_frame
		await _shot("%s.png" % scene)
		node.queue_free()
		await get_tree().process_frame
	await _shoot_dense()
	GameState.clear_stage()
	# the level select screens only look right with something unlocked
	for i in GameState.cleared.size():
		GameState.cleared[i] = true
	for m: String in Difficulty.MODES:
		GameState.menu_mode = m
		var menu: Node = load("res://scenes/ladder.tscn").instantiate()
		add_child(menu)
		await get_tree().create_timer(0.3).timeout
		await _shot("menu_%s.png" % m)
		menu.queue_free()
		await get_tree().process_frame
	await _shoot_wrong()
	for lv in (0 if only == "editor" else Difficulty.LEVELS.size()):
		GameState.start(lv)
		var game: Node = load("res://scenes/game.tscn").instantiate()
		add_child(game)
		await get_tree().create_timer(0.4).timeout
		await _shot("%s.png" % _slug(lv))
		for i in game.problem.correct:
			game._on_pick(i)
		await get_tree().create_timer(6.5).timeout
		await _shot("%s_revealed.png" % _slug(lv))
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## The widest the bottom of the screen ever gets: the most choices, two answers
## to ask for, and a wrong one so the verdict is at its longest
func _shoot_wrong() -> void:
	GameState.start(Difficulty.LEVELS.size() - 2)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.4).timeout
	await _shot("asking.png")
	for i in game.problem.choices.size():
		if not (game.problem.correct as Array).has(i) and game.picked.size() < (game.problem.correct as Array).size():
			game._on_pick(i)
	await get_tree().create_timer(6.5).timeout
	await _shot("wrong.png")
	game.queue_free()
	await get_tree().process_frame


func _slug(index: int) -> String:
	var m := Difficulty.mode_of(index)
	return "%s%02d" % [m, index - Difficulty.start_of(m) + 1]


## bodies packed as close as the editor allows, to check the label fallbacks
func _shoot_dense() -> void:
	GameState.clear_stage()
	var ed: Node = load("res://scenes/creative.tscn").instantiate()
	add_child(ed)
	await get_tree().create_timer(0.3).timeout
	var packed: Array = []
	var mats := ["water", "silica", "bk7", "polycarb", "diamond"]
	for i in 5:
		packed.append({"kind": "circle", "mat": mats[i], "x": 400.0 + i * 126.0, "y": 250.0, "s1": 60.0, "s2": 0.0, "rot": 0.0})
	packed.append({"kind": "slab", "mat": "soda_glass", "x": 520.0, "y": 420.0, "s1": 220.0, "s2": 60.0, "rot": 0.0})
	packed.append({"kind": "mirror", "mat": "silver", "x": 850.0, "y": 420.0, "s1": 110.0, "s2": 0.0, "rot": 0.4})
	ed.draft.objects = packed
	ed.draft.source_s = 300.0
	ed._refresh()
	await get_tree().process_frame
	await _shot("dense.png")
	# now break it, to show how a bad placement reads
	ed.draft.objects[1].x = ed.draft.objects[0].x + 40.0
	ed.draft.objects[6].y = 90.0
	ed._select(3)
	ed._refresh()
	await get_tree().process_frame
	await _shot("faults.png")
	# manual choices with nothing placed yet: the real exits must still show
	var clean: Array = []
	for i in 4:
		clean.append({"kind": "circle", "mat": mats[i], "x": 420.0 + i * 140.0, "y": 260.0, "s1": 62.0, "s2": 0.0, "rot": 0.0})
	clean.append({"kind": "prism", "mat": "bk7", "x": 620.0, "y": 450.0, "s1": 80.0, "s2": 0.0, "rot": 0.5})
	ed.draft.objects = clean
	ed.draft.manual = true
	ed.draft.decoys.clear()
	ed.auto_box.set_pressed_no_signal(false)
	ed._select(-1)
	ed._refresh()
	await get_tree().process_frame
	await _shot("manual.png")
	ed.queue_free()
	await get_tree().process_frame
	await _shoot_optics()


## the shapes hard mode adds, with the one that carries a number selected
func _shoot_optics() -> void:
	var ed: Node = load("res://scenes/creative.tscn").instantiate()
	add_child(ed)
	await get_tree().create_timer(0.3).timeout
	ed.draft.objects = [
		{"kind": "polarizer", "mat": "polarizer", "x": 400.0, "y": 260.0, "s1": 90.0, "s2": 0.0, "rot": 1.2, "extra": 0},
		{"kind": "polarizer", "mat": "polarizer", "x": 620.0, "y": 260.0, "s1": 90.0, "s2": 0.0, "rot": 1.2, "extra": 90},
		{"kind": "polarizer", "mat": "polarizer", "x": 840.0, "y": 260.0, "s1": 90.0, "s2": 0.0, "rot": 1.2, "extra": 45},
		{"kind": "gradient", "mat": "sf11", "x": 520.0, "y": 460.0, "s1": 240.0, "s2": 100.0, "rot": 0.0, "extra": 200},
		{"kind": "circle", "mat": "sucrose", "x": 880.0, "y": 460.0, "s1": 70.0, "s2": 0.0, "rot": 0.0, "extra": 0},
	]
	ed.draft.fresnel = true
	ed.draft.source_s = 250.0
	ed._select(3)
	ed._refresh()
	await get_tree().process_frame
	await _shot("editor_optics.png")
	ed.queue_free()
	await get_tree().process_frame


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(DIR + file_name)
	print("shot " + file_name)
