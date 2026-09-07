extends Node
## Dev tool: every screen in one locale, into user://shots. `-- ja` for Japanese


const DIR := "user://shots/"

var tag := "en"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		tag = arg
	Lang.locale = tag
	GameState.testing = true
	for i in GameState.cleared.size():
		GameState.cleared[i] = true
	DirAccess.make_dir_recursive_absolute(DIR)
	await _shot_scene("main", "res://scenes/main.tscn")
	await _shot_scene("tutorial_menu", "res://scenes/tutorial_menu.tscn")
	for m: String in Difficulty.MODES:
		GameState.menu_mode = m
		await _shot_scene("ladder_%s" % m, "res://scenes/ladder.tscn")
	for topic: String in ["rules", "refract", "split", "sheet", "spin"]:
		GameState.tutorial_topic = topic
		await _shot_scene("tut_%s" % topic, "res://scenes/tutorial.tscn", 3)
	await _shot_scene("codex", "res://scenes/codex.tscn")
	GameState.stage_code = StageCode.from_seed(6, 4600)
	await _shot_scene("creative", "res://scenes/creative.tscn", 0, true)
	GameState.clear_stage()
	for lv in [0, 16, 27]:
		GameState.start(lv)
		await _shot_game(lv)
	get_tree().quit()


func _shot_scene(name: String, path: String, pages := 0, pick := false) -> void:
	var node: Node = load(path).instantiate()
	add_child(node)
	await get_tree().create_timer(0.35).timeout
	if pick:
		node._select(0)
		await get_tree().process_frame
	if pages > 0:
		node._show_page(pages)
		await get_tree().process_frame
	await _save("%s_%s.png" % [name, tag])
	node.queue_free()
	await get_tree().process_frame


func _shot_game(lv: int) -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for _f in 900:
		await get_tree().process_frame
		if not game.problem.is_empty():
			break
	await _save("game_%d_%s.png" % [lv, tag])
	for i in game.problem.correct:
		game._on_pick(i)
	await get_tree().create_timer(6.5).timeout
	await _save("game_%d_done_%s.png" % [lv, tag])
	game.queue_free()
	await get_tree().process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	ShotFix.save(get_viewport().get_texture().get_image(), DIR + file)
	print("shot ", file)
