extends SceneTree
## Dev tool: counts which test throws a candidate out. Takes a level index


func _init() -> void:
	var index := 0
	for arg in OS.get_cmdline_user_args():
		index = int(arg)
	var level: Dictionary = Difficulty.LEVELS[index]
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var tally := {}
	var edge := ProblemGen._edges(level)
	var picky: bool = edge.values().max() > 0.0
	var opts := {"fresnel": level.fresnel, "min_intensity": 0.02, "max_events": 96}
	var measured := opts.duplicate()
	measured.clear = true
	var made := 0
	for _placement in 400:
		var objects := ProblemGen._place_objects(level, rng)
		if objects.is_empty():
			_bump(tally, "no layout")
			continue
		for _shot in ProblemGen.SOURCE_TRIES:
			var src := ProblemGen._make_source(rng, objects, ProblemGen._key_bodies(objects, level))
			var result := RayTracer.trace(objects, ProblemGen.FIELD, src.p, src.d, opts)
			var answers: int = level.answers
			if not result.ok or result.exits.size() < answers:
				_bump(tally, "no exit")
				continue
			var win: Dictionary = result.exits[0]
			if win.events < level.min_events:
				_bump(tally, "too few events")
				continue
			if result.exits.size() > answers and result.exits[answers].intensity > result.exits[answers - 1].intensity * ProblemGen.RUNNER_UP:
				_bump(tally, "answer boundary unclear")
				continue
			if answers > 1 and result.exits[answers - 1].intensity < win.intensity * 0.35:
				_bump(tally, "second answer too dim")
				continue
			if level.require_crystal and not ProblemGen._path_has_crystal(win.touched, objects):
				_bump(tally, "no crystal on path")
				continue
			if level.get("require_split", false) and not ProblemGen._split_by_crystal(result.exits, answers):
				_bump(tally, "not a split")
				continue
			if RayTracer.count_objects(win.touched) < level.min_objects:
				_bump(tally, "too few bodies on path")
				continue
			if win.tir < level.min_tir:
				_bump(tally, "no tir")
				continue
			if not ProblemGen._path_has_kinds(win.touched, objects, level.require_kinds):
				_bump(tally, "required kind off path")
				continue
			var straight := Isect.ray_rect_exit(src.p + src.d * 1e-3, src.d, ProblemGen.FIELD)
			if straight.is_empty() or win.point.distance_to(straight.point) < level.min_deviation:
				_bump(tally, "too near the straight line")
				continue
			if win.point.distance_to(src.p) < 120.0:
				_bump(tally, "too near the source")
				continue
			if picky:
				result = RayTracer.trace(objects, ProblemGen.FIELD, src.p, src.d, measured)
			if picky and ProblemGen._too_marginal(result.exits, level.answers, edge):
				var worst := {"clear": INF, "entry": INF, "near": INF, "graze": 1.0, "sheet": 1.0}
				for i in mini(level.answers, result.exits.size()):
					for k: String in worst:
						worst[k] = minf(worst[k], result.exits[i].get(k, worst[k]))
				if worst.clear < edge.clear:
					_bump(tally, "marginal: hit near an edge")
				if worst.entry < edge.entry:
					_bump(tally, "marginal: barely reaches the first body")
				if worst.near < edge.near:
					_bump(tally, "marginal: skims a body")
				if worst.graze < edge.cos:
					_bump(tally, "marginal: grazes a mirror")
				if worst.sheet < edge.sheet:
					_bump(tally, "marginal: meets a sheet askew")
				_bump(tally, "path is too marginal")
				continue
			var wins: Array = []
			for i in answers:
				wins.append(result.exits[i].point)
			if not ProblemGen._steady(objects, src, wins, opts, level.get("max_shake", 0.0)):
				_bump(tally, "answer moves when the shot is nudged")
				continue
			if not ProblemGen._gimmicks_bite(objects, src, wins, level):
				_bump(tally, "gimmick does not change the answer")
				continue
			if not ProblemGen._polarization_bites(objects, src, wins, level):
				_bump(tally, "polarization does not change the answer")
				continue
			if ProblemGen._make_choices(wins, result.exits, src, level, objects, rng).is_empty():
				_bump(tally, "no usable choices")
				continue
			made += 1
			_bump(tally, "ACCEPTED")
	print("%s   accepted %d" % [Difficulty.label(index), made])
	var rows: Array = tally.keys()
	rows.sort_custom(func(a, b): return tally[a] > tally[b])
	for k: String in rows:
		print("  %-36s %d" % [k, tally[k]])
	quit()


func _bump(tally: Dictionary, key: String) -> void:
	tally[key] = tally.get(key, 0) + 1
