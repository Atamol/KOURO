extends Node
## Dev tool: one board before and after the answer, into user://shots. Takes a
## level index, so `-- 16` shoots one whose exits differ in brightness


const DIR := "user://shots/"

var level := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		level = int(arg)
	GameState.testing = true
	Lang.locale = "ja"
	DirAccess.make_dir_recursive_absolute(DIR)
	GameState.start(level)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for _f in 900:
		await get_tree().process_frame
		if not game.problem.is_empty():
			break
	await _shot(game, "pre")
	for i in game.problem.correct:
		game._on_pick(i)
	await get_tree().create_timer(6.5).timeout
	await _shot(game, "post")
	get_tree().quit()


func _shot(game: Node, when: String) -> void:
	await RenderingServer.frame_post_draw
	print("%-5s %s  reads_light=%s" % [when, Difficulty.label(level), game.problem.get("reads_light", false)])
	ShotFix.save(get_viewport().get_texture().get_image(), DIR + "bloom_%s.png" % when)
