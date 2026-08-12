extends SceneTree
## Dev tool: how often each level manages to build a problem, and how long it
## takes. Run with `godot_console --headless --path . -s res://tools/diag.gd`


func _init() -> void:
	var only: int = -1
	for arg in OS.get_cmdline_user_args():
		only = int(arg)
	var tries := 24
	var total := 0
	for li in Difficulty.LEVELS.size():
		if only >= 0 and li != only:
			continue
		var level: Dictionary = Difficulty.LEVELS[li]
		var ok := 0
		var start := Time.get_ticks_msec()
		for k in tries:
			var rng := RandomNumberGenerator.new()
			rng.seed = 9000 + li * 137 + k
			var p := {}
			for _r in 6:
				p = ProblemGen.generate(level, rng)
				if not p.is_empty():
					break
			if not p.is_empty():
				ok += 1
		var ms := Time.get_ticks_msec() - start
		total += ms
		print("%-34s %2d/%2d  %6d ms  %5d ms each" % [Difficulty.label(li), ok, tries, ms, ms / tries])
	print("total %d ms" % total)
	quit()
