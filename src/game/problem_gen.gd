class_name ProblemGen
## Rejection sampled problems. All randomness goes through the passed rng, so
## one seed reproduces one problem


const FIELD := Rect2(150, 76, 980, 500)
const OBJ_MARGIN := 30.0
const GAP := 18.0
## What a loaded or hand placed layout has to clear, measured between the drawn
## shapes so bodies can sit as close as they look. Above zero because the tracer
## needs a gap rather than a tangency
const TOUCH_CLEAR := 3.0
# placing bodies costs far more than tracing, so reuse one layout for many shots
const PLACEMENT_TRIES := 200
const SOURCE_TRIES := 45
# markers are 42 px wide, and two exits a corner apart can be far along the
# border yet touch on screen
const MARKER_CLEAR := 58.0
## how often the shot is worked back from two bodies rather than aimed at one.
## _threaded_source gives up often enough that the rest still lands here
const THREADED_SHARE := 0.85
## the aim error a board has to survive. Nobody reads a surface to better than
## this, so an answer that moves under it was never really being read
const SHAKE := deg_to_rad(0.5)
## how bright the first beam that is not an answer may be against the dimmest
## one that is. Ranking beams by eye is guesswork, so the gap has to be plain
const RUNNER_UP := 0.6


static func generate(level: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var fixed := prepare(level)
	for _placement in PLACEMENT_TRIES:
		var made := attempt(level, rng, fixed)
		if not made.is_empty():
			return made
	return {}


## The parts of a level that never change between attempts, so a search that is
## stopped and picked up again does not work them out over and over
static func prepare(level: Dictionary) -> Dictionary:
	var edge := _edges(level)
	var opts := {"fresnel": level.fresnel, "min_intensity": 0.02, "max_events": 96}
	var measured := opts.duplicate()
	measured.clear = true
	return {"edge": edge, "picky": edge.values().max() > 0.0, "opts": opts, "measured": measured}


## One layout to shoot at, or nothing when the draw could not place the bodies
static func lay_out(level: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var objects := _place_objects(level, rng)
	if objects.is_empty():
		return {}
	# aimed at what the level is about, not at whatever the draw landed on
	return {"objects": objects, "key_bodies": _key_bodies(objects, level)}


## One shot at a laid out board, which is the finest grain the search can be
## stopped on. It draws exactly what one round of the loop used to, so a seed
## still names the same board
static func shoot(level: Dictionary, rng: RandomNumberGenerator, fixed: Dictionary, layout: Dictionary) -> Dictionary:
	var edge: Dictionary = fixed.edge
	var picky: bool = fixed.picky
	var opts: Dictionary = fixed.opts
	var measured: Dictionary = fixed.measured
	var objects: Array = layout.objects
	var key_bodies: Array = layout.key_bodies
	var src := _make_source(rng, objects, key_bodies)
	var result := RayTracer.trace(objects, FIELD, src.p, src.d, opts)
	if not result.ok:
		return {}
	var answers: int = level.answers
	if result.exits.size() < answers:
		return {}
	var win: Dictionary = result.exits[0]
	if win.events < level.min_events:
		return {}
	# the boundary between what counts as an answer and what does not has
	# to be obvious, otherwise picking is a coin toss
	if result.exits.size() > answers and result.exits[answers].intensity > result.exits[answers - 1].intensity * RUNNER_UP:
		return {}
	# and every answer has to be a beam you can see
	if answers > 1 and result.exits[answers - 1].intensity < win.intensity * 0.35:
		return {}
	if level.require_crystal and not _path_has_crystal(win.touched, objects):
		return {}
	# a crystal on the path is not enough for a two point answer: the two
	# answers have to be the polarizations it parted
	if level.get("require_split", false) and not _split_by_crystal(result.exits, answers):
		return {}
	# distinct bodies on the winning path, so extra objects are not just scenery
	if RayTracer.count_objects(win.touched) < level.min_objects:
		return {}
	if win.tir < level.min_tir:
		return {}
	# an element must not turn up before the level that teaches it. Left open,
	# total reflection was landing on a third of the boards five levels early
	if win.tir > level.get("max_tir", 99):
		return {}
	# how many of a shape the path has to meet, where require_kinds only asks for
	# one. Two mirrors or two prisms in a row is a different reading from one
	for kind: String in level.get("min_on_path", {}):
		if _path_kinds(win.touched, objects, kind) < int(level.min_on_path[kind]):
			return {}
	# the level's new element has to be on the answer path, not just on screen
	if not _path_has_kinds(win.touched, objects, level.require_kinds):
		return {}
	# the straight continuation of the source must not land on the answer,
	# otherwise the problem is solvable without any optics
	var straight := Isect.ray_rect_exit(src.p + src.d * 1e-3, src.d, FIELD)
	if straight.is_empty() or win.point.distance_to(straight.point) < level.min_deviation:
		return {}
	if win.point.distance_to(src.p) < 120.0:
		return {}
	# a path that clips a corner, skims a body it never meets, or meets one
	# almost edge on is read off pixels rather than physics. Measuring that
	# walks every body on every leg, so it waits until the path is otherwise
	# worth keeping
	if picky:
		result = RayTracer.trace(objects, FIELD, src.p, src.d, measured)
		if _too_marginal(result.exits, level.answers, edge):
			return {}
	var wins: Array = []
	for i in answers:
		wins.append(result.exits[i].point)
	# an answer that half a degree at the source lands on another marker is
	# one a player can read correctly and still get wrong
	if not _steady(objects, src, wins, opts, level.get("max_shake", 0.0)):
		return {}
	if not _gimmicks_bite(objects, src, wins, level):
		return {}
	if not _polarization_bites(objects, src, wins, level):
		return {}
	var choices := _make_choices(wins, result.exits, src, level, objects, rng)
	if choices.is_empty():
		return {}
	return {
		"objects": _drop_dark(objects, result.exits, choices.lit), "source": src, "trace": result,
		"choices": choices.points, "correct": choices.correct,
		"reads_light": _reads_light(objects, win.touched, wins),
	}


## Polarization on the board has to be the reason the answer is where it is,
## or it is scenery and the board reads the same to someone who never noticed it.
##
## Asked of the whole board rather than of the answer's own path, because the
## sharpest thing a sheet can do is stop the beam a player was following, and a
## beam that dies never reaches the border to say it met one
static func _polarization_bites(objects: Array, src: Dictionary, wins: Array, level: Dictionary) -> bool:
	if not _has_polarization(objects):
		return true
	var blind := RayTracer.trace(objects, FIELD, src.p, src.d,
			{"fresnel": level.fresnel, "min_intensity": 0.02, "max_events": 96, "mistake": "no_polarization"})
	return not blind.ok or _min_point_dist(blind.exits[0].point, wins) >= level.decoy_clear


static func _has_polarization(objects: Array) -> bool:
	for o: SceneObj in objects:
		if o.is_polarizer() or OpticsMaterials.is_rotary(o.mat_key):
			return true
	return false


static func _reads_polarization(objects: Array, touched: int) -> bool:
	return _path_sheets(touched, objects) > 0 or _path_has_rotary(touched, objects)


## Whether answering takes reading how much light got where. A crystal parts the
## beam and both halves are asked for, and polarization on the path has already
## had to earn its place. On every other board the light merely gets dimmer as
## it goes, which nobody is asked to read, so it is not drawn
static func _reads_light(objects: Array, touched: int, wins: Array) -> bool:
	return wins.size() > 1 or _reads_polarization(objects, touched)


static func attempt(level: Dictionary, rng: RandomNumberGenerator, fixed: Dictionary) -> Dictionary:
	var layout := lay_out(level, rng)
	if layout.is_empty():
		return {}
	for _shot in SOURCE_TRIES:
		var made := shoot(level, rng, fixed, layout)
		if not made.is_empty():
			return made
	return {}

## Drops bodies no reading of the board ever sends light near, since all they do
## is clutter it. A dropped body was never hit, but the exits index into the
## object list, so their masks are rewritten to match
static func _drop_dark(objects: Array, exits: Array, lit: int) -> Array:
	var kept: Array = []
	var map: Array = []
	for i in objects.size():
		if (lit & (1 << i)) != 0:
			map.append(kept.size())
			kept.append(objects[i])
		else:
			map.append(-1)
	for e in exits:
		e.touched = _remap(e.touched, map)
	return kept


## The ways a board can come down to eyesight rather than to optics: a hit that
## lands on a corner, a first hit that may or may not happen at all, a beam that
## skims a body it never meets, a mirror taken nearly edge on, and a sheet met so
## far off its normal that its angle stops meaning what it says
static func _edges(level: Dictionary) -> Dictionary:
	return {
		"clear": level.get("min_clear", 0.0),
		"entry": level.get("min_entry", 0.0),
		"near": level.get("min_near", 0.0),
		"cos": level.get("min_cos", 0.0),
		"sheet": level.get("min_sheet", 0.0),
	}


static func _too_marginal(exits: Array, answers: int, edge: Dictionary) -> bool:
	for i in mini(answers, exits.size()):
		var e: Dictionary = exits[i]
		if e.get("clear", INF) < edge.clear or e.get("entry", INF) < edge.entry:
			return true
		if e.get("near", INF) < edge.near or e.get("graze", 1.0) < edge.cos:
			return true
		# a sheet read off its angle
		if e.get("sheet", 1.0) < edge.sheet:
			return true
	return false


## Nudges the shot both ways and asks whether the answer stayed put. Every other
## test looks at one moment of the path; this one asks whether the whole chain
## amplified, which is what a long path through a gradient or a near critical
## surface does
static func _steady(objects: Array, src: Dictionary, wins: Array, opts: Dictionary, limit: float) -> bool:
	if limit <= 0.0:
		return true
	for turn: float in [-SHAKE, SHAKE]:
		var shaken := RayTracer.trace(objects, FIELD, src.p, (src.d as Vector2).rotated(turn), opts)
		if not shaken.ok or shaken.exits.size() < wins.size():
			return false
		var moved: Array = []
		for i in wins.size():
			moved.append(shaken.exits[i].point)
		for w: Vector2 in wins:
			if _min_point_dist(w, moved) > limit:
				return false
	return true


## Each named mistake has to send the light somewhere clearly else. Without
## this a level can require its gimmick on the path and still be solvable by
## someone who never noticed it was there
static func _gimmicks_bite(objects: Array, src: Dictionary, wins: Array, level: Dictionary) -> bool:
	for slip: String in level.get("require_mistakes", []):
		var wrong := RayTracer.trace(objects, FIELD, src.p, src.d,
				{"fresnel": level.fresnel, "min_intensity": 0.02, "max_events": 96, "mistake": slip})
		if not wrong.ok or _min_point_dist(wrong.exits[0].point, wins) < level.decoy_clear:
			return false
	return true


static func _place_objects(level: Dictionary, rng: RandomNumberGenerator) -> Array:
	level = _drawable(level)
	var objects: Array = []
	# required shapes go down first, otherwise a layout can lack the one kind
	# every source shot is then tested against
	var wanted: Array = level.require_kinds.duplicate()
	wanted.append_array(level.get("place_kinds", []))
	var count: int = maxi(rng.randi_range(level.objects_min, level.objects_max), wanted.size())
	var lane := _lane(level, rng)
	var laid := 0
	for i in count:
		var kind: String = wanted[i] if i < wanted.size() else _pick(level.kinds, rng)
		for _try in 50:
			var obj: SceneObj = null
			# the last tries go back to a free draw, so a lane that cannot be filled
			# does not cost the whole layout
			if kind == "polarizer" and not lane.is_empty() and _try < 35:
				obj = _lane_sheet(lane, laid, rng)
			else:
				obj = _make_object(kind, level, rng)
			if fits(obj, objects):
				objects.append(obj)
				if kind == "polarizer":
					laid += 1
				break
	# a material the level is about is far too easy to miss when the draw is
	# uniform, so the ones that carry a gimmick are placed outright
	for pool: String in ["crystal", "rotary"]:
		for _n in level.get("place_" + pool, 0):
			for _try in 60:
				var obj := _make_special(pool, level, rng, _between_bars(objects, rng) if _try < 40 else Vector2.INF)
				if fits(obj, objects):
					objects.append(obj)
					break
	# a step of zero is a level that wants its sheets parallel, which is not the
	# same as a level that never asked, so the key has to be present rather than
	# nonzero
	if level.has("sheet_step"):
		_step_sheets(objects, level.sheet_step)
	if level.has("mirror_step") and not _step_mirrors(objects, level.mirror_step):
		return []
	return objects


## A crystal parts the beam wherever it sits, which is a different question with
## a different number of answers, so the levels that are not about it never draw
## one rather than throwing the board away once the split shows up. Sheets and
## rotary bodies are kept out the same way, since drawn at random neither can
## reach the answer and every board holding one would be thrown away again
static func _drawable(level: Dictionary) -> Dictionary:
	var out := level
	if not _places(level, "polarizer") and (level.kinds as Array).has("polarizer"):
		out = out.duplicate()
		out.kinds = (level.kinds as Array).filter(func(k): return k != "polarizer")
	var keep_crystal: bool = level.require_crystal or level.get("place_crystal", 0) > 0
	var keep_rotary: bool = level.get("place_rotary", 0) > 0
	var plain: Array = []
	for key: String in level.materials:
		if OpticsMaterials.is_crystal(key) and not keep_crystal:
			continue
		if OpticsMaterials.is_rotary(key) and not keep_rotary:
			continue
		plain.append(key)
	if plain.is_empty() or plain.size() == (level.materials as Array).size():
		return out
	if out == level:
		out = level.duplicate()
	out.materials = plain
	return out


static func _places(level: Dictionary, kind: String) -> bool:
	return (level.require_kinds as Array).has(kind) or (level.get("place_kinds", []) as Array).has(kind)


## A line to lay the two sheets and the liquid along, each bar turned across it.
## Dropped independently they almost never leave one beam a way through all three.
##
## Only for the rotation level: a pair whose point is that it stops the light
## wants them apart, not in a row
static func _lane(level: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if level.get("place_rotary", 0) < 1:
		return {}
	var a := _rand_center(rng, 150.0)
	var b := _rand_center(rng, 150.0)
	# a short lane leaves no room to thread. Drawing again until it is long
	# enough sounds better and is worse: every layout then has its sheets in a
	# row, and a beam that runs down a row comes out near the line it went in on
	if a.distance_to(b) < 320.0:
		return {}
	return {"a": a, "b": b, "count": 2}


static func _lane_sheet(lane: Dictionary, index: int, rng: RandomNumberGenerator) -> SceneObj:
	var along := (index + 0.5) / float(lane.count) + rng.randf_range(-0.12, 0.12)
	var at: Vector2 = (lane.a as Vector2).lerp(lane.b, clampf(along, 0.05, 0.95))
	var across: float = ((lane.b - lane.a) as Vector2).angle() + PI * 0.5 + rng.randf_range(-0.5, 0.5)
	var reach := rng.randf_range(55.0, 120.0)
	var phi := PI * 0.25 * rng.randi_range(0, 3)
	return make_object("polarizer", "polarizer", at, reach, 0.0, across, PolarizerObj.byte_from_phi(phi))


## Axes left to chance are rarely near enough to crossed, or to parallel, to do
## anything the level is asking about
static func _step_sheets(objects: Array, step: float) -> void:
	var sheets: Array = []
	for o: SceneObj in objects:
		if o.is_polarizer():
			sheets.append(o)
	for i in range(1, sheets.size()):
		(sheets[i] as PolarizerObj).phi = fposmod((sheets[0] as PolarizerObj).phi + step * i, PI)


## The same for mirrors, except that a mirror carries no angle of its own: it is
## the segment, so the segment is turned about its middle. Turning one moves it,
## unlike setting a sheet's axis, so a layout that fitted before can come out with
## two bodies inside each other. Rather than nudge them apart the whole layout
## goes back, since the tracer cannot read an overlap
static func _step_mirrors(objects: Array, step: float) -> bool:
	var mirrors: Array = []
	for o: SceneObj in objects:
		if o.kind == "mirror":
			mirrors.append(o)
	if mirrors.is_empty():
		return true
	var first: MirrorObj = mirrors[0]
	var base := (first.b - first.a).angle()
	for i in range(1, mirrors.size()):
		var m: MirrorObj = mirrors[i]
		var mid: Vector2 = (m.a + m.b) * 0.5
		var reach: Vector2 = Vector2.from_angle(base + step * i) * (m.a.distance_to(m.b) * 0.5)
		m.a = mid - reach
		m.b = mid + reach
		if not fits(m, objects.filter(func(o): return o != m)):
			return false
	return true


static func _path_kinds(touched: int, objects: Array, kind: String) -> int:
	var n := 0
	for i in objects.size():
		if (touched & (1 << i)) != 0 and (objects[i] as SceneObj).kind == kind:
			n += 1
	return n


## Two sheets stop the beam unless something between them turns its plane, so a
## rotary body dropped anywhere else is a body the level never gets to use
static func _between_bars(objects: Array, rng: RandomNumberGenerator) -> Vector2:
	var bars: Array = []
	for o: SceneObj in objects:
		if o.is_polarizer():
			bars.append((o.bounding() as Dictionary).center)
	if bars.size() < 2:
		return Vector2.INF
	return (bars[0] as Vector2).lerp(bars[1], rng.randf_range(0.35, 0.65))


static func _spot(rng: RandomNumberGenerator, at: Vector2, bound_r: float) -> Vector2:
	var inner := FIELD.grow(-(OBJ_MARGIN + bound_r))
	if not at.is_finite() or inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return _rand_center(rng, bound_r)
	var off := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, 36.0)
	return (at + off).clamp(inner.position, inner.end)


static func _make_special(pool: String, level: Dictionary, rng: RandomNumberGenerator, at: Vector2) -> SceneObj:
	var keys: Array = []
	for key: String in level.materials:
		var wanted: bool = OpticsMaterials.is_crystal(key) if pool == "crystal" else OpticsMaterials.is_rotary(key)
		if wanted:
			keys.append(key)
	if keys.is_empty():
		return null
	var key: String = _pick(keys, rng)
	# rotation goes by path length, so these are built large: easier to thread a
	# beam through and worth more degrees once threaded. Sizing them from the
	# material instead, so that a crossing turns the plane about a quarter, reads
	# better on paper and finds a third as many boards
	if pool == "rotary":
		if rng.randf() < 0.5:
			var r := rng.randf_range(68.0, 85.0)
			return make_object("circle", key, _spot(rng, at, r), r, 0.0, 0.0)
		var w := rng.randf_range(200.0, 270.0)
		var h := rng.randf_range(74.0, 100.0)
		return make_object("slab", key, _spot(rng, at, Vector2(w, h).length() * 0.5), w, h, rng.randf_range(0.0, PI))
	var kind: String = ["circle", "slab", "prism"][rng.randi_range(0, 2)]
	return _make_object(kind, {"materials": [key], "metals": level.metals}, rng)


## Editor bounds for each shape, also what the generator draws from. s2 is only
## meaningful for the two rectangular shapes
const SIZE_RANGE := {
	"mirror": {"s1": [40.0, 160.0], "s2": [0.0, 0.0]},
	"slab": {"s1": [100.0, 300.0], "s2": [30.0, 120.0]},
	"circle": {"s1": [30.0, 120.0], "s2": [0.0, 0.0]},
	"prism": {"s1": [50.0, 130.0], "s2": [0.0, 0.0]},
	"polarizer": {"s1": [40.0, 160.0], "s2": [0.0, 0.0]},
	"gradient": {"s1": [120.0, 300.0], "s2": [50.0, 120.0]},
}
## shapes that carry a per body number in the record's spare byte
const EXTRA_KINDS := ["polarizer", "gradient"]


## One builder for the generator, the editor and the code reader, so a stage
## looks the same however it was made. `extra` is the spare byte, a transmission
## axis in degrees for a sheet and an index slope for a gradient block
static func make_object(kind: String, mat: String, center: Vector2, s1: float, s2: float, rot: float, extra: int = 0) -> SceneObj:
	var obj: SceneObj = null
	match kind:
		"mirror":
			var half := Vector2.from_angle(rot) * s1
			obj = MirrorObj.new(center - half, center + half, mat)
		"polarizer":
			var reach := Vector2.from_angle(rot) * s1
			obj = PolarizerObj.new(center - reach, center + reach, PolarizerObj.phi_from_byte(extra))
		"circle":
			obj = CircleBody.new(center, s1, mat)
		"slab":
			obj = PolyBody.new(_rect_points(center, s1, s2, rot), mat)
		"gradient":
			obj = GradientBody.new(_rect_points(center, s1, s2, rot), mat, center, rot, GradientBody.slope_from_byte(extra))
		"prism":
			obj = PolyBody.new(_ngon_points(center, s1, 3, rot), mat)
	if obj != null:
		obj.kind = kind
		obj.axis = rot
	return obj


static func _make_object(kind: String, level: Dictionary, rng: RandomNumberGenerator) -> SceneObj:
	match kind:
		"mirror":
			var half := rng.randf_range(50.0, 110.0)
			return make_object(kind, _pick(level.metals, rng), _rand_center(rng, 110.0), half, 0.0, rng.randf_range(0.0, PI))
		"polarizer":
			var reach := rng.randf_range(55.0, 120.0)
			# axes a quarter turn apart are what make a pair read as crossed or open
			var phi := PI * 0.25 * rng.randi_range(0, 3)
			return make_object(kind, "polarizer", _rand_center(rng, reach), reach, 0.0,
					rng.randf_range(0.0, PI), PolarizerObj.byte_from_phi(phi))
		"circle":
			var r := rng.randf_range(40.0, 85.0)
			return make_object(kind, _pick(level.materials, rng), _rand_center(rng, r), r, 0.0, 0.0)
		"slab":
			var w := rng.randf_range(140.0, 240.0)
			# thin plates shift the beam by only a few px, which reads as no refraction
			var h := rng.randf_range(48.0, 96.0)
			var c := _rand_center(rng, Vector2(w, h).length() * 0.5)
			return make_object(kind, _pick(level.materials, rng), c, w, h, rng.randf_range(0.0, PI))
		"gradient":
			var gw := rng.randf_range(160.0, 260.0)
			var gh := float(int(round(rng.randf_range(70.0, 110.0))))
			var key: String = _pick(level.materials, rng)
			# the cap is read off the rounded thickness a code will carry, and one
			# step short of it, so the block still validates once encoded
			var cap := minf(GradientBody.slope_cap(key, gh), 0.010) - GradientBody.STEP
			# too rare a material has no room to be graded at all
			if cap < 0.0018:
				return null
			var g := rng.randf_range(0.55, 1.0) * cap * (1.0 if rng.randf() < 0.5 else -1.0)
			var gc := _rand_center(rng, Vector2(gw, gh).length() * 0.5)
			return make_object(kind, key, gc, gw, gh, rng.randf_range(0.0, PI), GradientBody.byte_from_slope(g))
		"prism":
			var side := rng.randf_range(110.0, 170.0)
			var r := side / sqrt(3.0)
			return make_object(kind, _pick(level.materials, rng), _rand_center(rng, r), r, 0.0, rng.randf_range(0.0, TAU))
	return null


## Bodies carrying the level's own element, which is where the shot has to be
## pointed for a level that asks the beam to reach one
static func _key_bodies(objects: Array, level: Dictionary) -> Array:
	var kinds: Array = level.require_kinds + level.get("place_kinds", [])
	var rotary: bool = level.get("place_rotary", 0) > 0
	var crystal: bool = level.require_crystal or level.get("place_crystal", 0) > 0
	var out: Array = []
	for o: SceneObj in objects:
		if kinds.has(o.kind) \
				or (rotary and OpticsMaterials.is_rotary(o.mat_key)) \
				or (crystal and OpticsMaterials.is_crystal(o.mat_key)):
			out.append(o)
	return out


## Lines the shot up with two bodies rather than one. Aiming at a single body
## leaves the beam meeting only that body most of the time, which is not enough
## for a level that wants three interactions on the path
static func _threaded_source(rng: RandomNumberGenerator, objects: Array, priority: Array) -> Dictionary:
	var first: SceneObj = _pick(priority if not priority.is_empty() else objects, rng)
	var second: SceneObj = _pick(objects, rng)
	if first == second:
		return {}
	var from := _spot_in(first, rng)
	var toward := _spot_in(second, rng)
	if from.distance_to(toward) < 1.0:
		return {}
	var d := (toward - from).normalized()
	# walk back from the first body to find where the shot has to start
	var back := Isect.ray_rect_exit(from, -d, FIELD)
	if back.is_empty():
		return {}
	var p: Vector2 = back.point
	# the tilt range a free shot gets, or the editor would clamp it on load
	if d.dot(border_inward(_border_s(p))) < 0.5:
		return {}
	return {"p": p, "d": d, "side": 0}


static func _spot_in(obj: SceneObj, rng: RandomNumberGenerator) -> Vector2:
	# a bar's bounding circle is nearly all empty space, so aim along the bar
	var ends := obj.vertices()
	if ends.size() == 2:
		return (ends[0] as Vector2).lerp(ends[1], rng.randf_range(0.15, 0.85))
	var b: Dictionary = obj.bounding()
	return b.center + Vector2.from_angle(rng.randf_range(0.0, TAU)) * b.radius * sqrt(rng.randf())


static func _make_source(rng: RandomNumberGenerator, objects: Array, priority: Array = []) -> Dictionary:
	if objects.size() > 1 and rng.randf() < THREADED_SHARE:
		var threaded := _threaded_source(rng, objects, priority)
		if not threaded.is_empty():
			return threaded
	var side := rng.randi_range(0, 3)
	var u := rng.randf_range(0.15, 0.85)
	var p: Vector2
	var inward: Vector2
	match side:
		0:
			p = Vector2(FIELD.position.x + FIELD.size.x * u, FIELD.position.y)
			inward = Vector2.DOWN
		1:
			p = Vector2(FIELD.end.x, FIELD.position.y + FIELD.size.y * u)
			inward = Vector2.LEFT
		2:
			p = Vector2(FIELD.position.x + FIELD.size.x * u, FIELD.end.y)
			inward = Vector2.UP
		3:
			p = Vector2(FIELD.position.x, FIELD.position.y + FIELD.size.y * u)
			inward = Vector2.RIGHT
	var d := inward.rotated(rng.randf_range(-PI / 3.0, PI / 3.0))
	# a uniformly aimed beam usually crosses the field untouched, so point it at
	# some body and let the rejection tests handle the rest
	if not objects.is_empty():
		var pool: Array = objects
		if not priority.is_empty() and rng.randf() < 0.65:
			pool = priority
		var target: SceneObj = pool[rng.randi_range(0, pool.size() - 1)]
		var aimed := (_spot_in(target, rng) - p).normalized()
		if aimed.dot(inward) > 0.1:
			d = aimed
	return {"p": p, "d": d, "side": side}


## Builds a playable problem out of a hand made layout. Nothing is resampled
## here, so an empty return is a real failure. Decoys, when given, are border
## positions the author placed and replace the generated ones
static func build_custom(objects: Array, src: Dictionary, fresnel: bool, choices: int, rng: RandomNumberGenerator, decoys: Array = [], manual := false) -> Dictionary:
	var result := RayTracer.trace(objects, FIELD, src.p, src.d, {"fresnel": fresnel, "min_intensity": 0.02, "max_events": 96})
	if not result.ok:
		return {}
	var answers := answers_in(result.exits)
	var wins: Array = []
	for i in answers:
		wins.append(result.exits[i].point)
	if manual:
		# an author who turned the generator off gets nothing until they place
		# something, rather than silently getting generated decoys back
		return {} if decoys.is_empty() else _hand_built(objects, src, result, wins, decoys, rng)
	if not decoys.is_empty():
		return _hand_built(objects, src, result, wins, decoys, rng)
	# capping the answers instead would demote a beam just as bright as the ones
	# being asked for into a decoy, which is unanswerable
	if answers + 2 > choices:
		return {}
	var level := {"fresnel": fresnel, "choices": choices, "min_sep": 90.0, "decoy_clear": MARKER_CLEAR, "min_slips": 0}
	var picks := _make_choices(wins, result.exits, src, level, objects, rng, MARKER_CLEAR)
	if picks.is_empty():
		return {}
	return {"objects": objects, "source": src, "trace": result, "choices": picks.points, "correct": picks.correct,
			"reads_light": _reads_light(objects, result.exits[0].touched, wins)}


static func _hand_built(objects: Array, src: Dictionary, result: Dictionary, wins: Array, decoys: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pts: Array = wins.duplicate()
	for s in decoys:
		var p := _s_to_point(s)
		# a hand placed marker sitting on an answer would make the stage a lie
		if _min_point_dist(p, pts) < MARKER_CLEAR:
			return {}
		pts.append(p)
	var order := range(pts.size())
	_shuffle(order, rng)
	var shuffled: Array = []
	var correct: Array = []
	for i in pts.size():
		shuffled.append(pts[order[i]])
		if order[i] < wins.size():
			correct.append(i)
	return {"objects": objects, "source": src, "trace": result, "choices": shuffled, "correct": correct,
			"reads_light": _reads_light(objects, result.exits[0].touched, wins)}


## A hand made stage has no level table, so how many points count as answers is
## read off the trace: every beam within a third of the brightest one
static func answers_in(exits: Array) -> int:
	var n := 1
	while n < exits.size() and exits[n].intensity >= exits[0].intensity * 0.35:
		n += 1
	return n


## wins holds every point the player has to pick, brightest first
static func _make_choices(wins: Array, exits: Array, src: Dictionary, level: Dictionary, objects: Array, rng: RandomNumberGenerator, src_clear: float = 80.0) -> Dictionary:
	var perim := 2.0 * (FIELD.size.x + FIELD.size.y)
	var s_src := _border_s(src.p)
	var pts: Array = []
	var ss: Array = []
	for w: Vector2 in wins:
		if _wrap_dist(_border_s(w), s_src, perim) < src_clear or _min_point_dist(w, pts) < MARKER_CLEAR:
			return {}
		pts.append(w)
		ss.append(_border_s(w))
	# every candidate here is where the light really would land under one
	# specific slip, so a wrong answer never looks impossible on sight
	var cands: Array = []
	for i in range(wins.size(), exits.size()):
		cands.append(exits[i].point)
	var slips := _slip_scenes(objects, src, exits[0].touched, level.get("fresnel", false))
	cands.append_array(slips.points)
	# closest to any answer first, so decoy_clear alone decides how tight a level plays
	cands.sort_custom(func(x: Vector2, y: Vector2): return _min_point_dist(x, wins) < _min_point_dist(y, wins))
	for p: Vector2 in cands:
		if pts.size() >= level.choices:
			break
		var s := _border_s(p)
		if _min_point_dist(p, wins) >= level.decoy_clear and _wrap_dist(s, s_src, perim) >= src_clear \
				and _min_point_dist(p, pts) >= MARKER_CLEAR:
			pts.append(p)
			ss.append(s)
	# too few plausible wrong answers means the rest would be random points the
	# player can rule out on sight, so start over instead
	if pts.size() - wins.size() < level.min_slips:
		return {}
	for _try in 300:
		if pts.size() >= level.choices:
			break
		var s := rng.randf_range(0.0, perim)
		var p := _s_to_point(s)
		if _min_wrap_dist(s, ss, perim) >= level.min_sep and _wrap_dist(s, s_src, perim) >= src_clear \
				and _min_point_dist(p, pts) >= MARKER_CLEAR:
			pts.append(p)
			ss.append(s)
	if pts.size() < level.choices:
		return {}
	var order := range(pts.size())
	_shuffle(order, rng)
	var shuffled: Array = []
	var correct: Array = []
	for i in pts.size():
		shuffled.append(pts[order[i]])
		if order[i] < wins.size():
			correct.append(i)
	var lit: int = slips.used
	for e in exits:
		lit |= e.touched
	return {"points": shuffled, "correct": correct, "lit": lit}


static func _pick(arr: Array, rng: RandomNumberGenerator) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]


static func _rand_center(rng: RandomNumberGenerator, bound_r: float) -> Vector2:
	var inner := FIELD.grow(-(OBJ_MARGIN + bound_r))
	return Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))


static func _rect_points(c: Vector2, w: float, h: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for corner in [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)]:
		pts.append(c + (corner * 0.5).rotated(rot))
	return pts


static func _ngon_points(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		pts.append(c + Vector2.from_angle(rot + TAU * k / n) * r)
	return pts


## Spacing for generated layouts. Bounding circles keep the field readable,
## which is what the generator wants over how close bodies could legally sit
static func fits(obj: SceneObj, objects: Array, gap: float = GAP) -> bool:
	if obj == null:
		return false
	var b := obj.bounding()
	for other: SceneObj in objects:
		var ob := other.bounding()
		if b.center.distance_to(ob.center) < b.radius + ob.radius + gap:
			return false
	return true


## Shape accurate, for the editor and for loading codes. The tracer only needs
## bodies not to nest, so anything short of touching is allowed
static func no_overlap(obj: SceneObj, objects: Array, clearance: float = TOUCH_CLEAR) -> bool:
	if obj == null:
		return false
	var b := obj.bounding()
	var grown := obj.outline(clearance)
	if grown.is_empty():
		return false
	for other: SceneObj in objects:
		var ob := other.bounding()
		if b.center.distance_to(ob.center) > b.radius + ob.radius + clearance + 8.0:
			continue
		if not Geometry2D.intersect_polygons(grown, other.outline(0.0)).is_empty():
			return false
	return true


static func _border_s(point: Vector2) -> float:
	var r := FIELD
	var dt := absf(point.y - r.position.y)
	var dr := absf(point.x - r.end.x)
	var db := absf(point.y - r.end.y)
	var dl := absf(point.x - r.position.x)
	var m := minf(minf(dt, dr), minf(db, dl))
	if m == dt:
		return clampf(point.x - r.position.x, 0.0, r.size.x)
	if m == dr:
		return r.size.x + clampf(point.y - r.position.y, 0.0, r.size.y)
	if m == db:
		return r.size.x + r.size.y + clampf(r.end.x - point.x, 0.0, r.size.x)
	return 2.0 * r.size.x + r.size.y + clampf(r.end.y - point.y, 0.0, r.size.y)


static func border_inward(s: float) -> Vector2:
	var w := FIELD.size.x
	var h := FIELD.size.y
	s = fposmod(s, 2.0 * (w + h))
	if s < w:
		return Vector2.DOWN
	s -= w
	if s < h:
		return Vector2.LEFT
	s -= h
	if s < w:
		return Vector2.UP
	return Vector2.RIGHT


static func s_to_point(s: float) -> Vector2:
	return _s_to_point(s)


static func _s_to_point(s: float) -> Vector2:
	var r := FIELD
	var w := r.size.x
	var h := r.size.y
	s = fposmod(s, 2.0 * (w + h))
	if s < w:
		return Vector2(r.position.x + s, r.position.y)
	s -= w
	if s < h:
		return Vector2(r.end.x, r.position.y + s)
	s -= h
	if s < w:
		return Vector2(r.end.x - s, r.end.y)
	s -= w
	return Vector2(r.position.x, r.end.y - s)


static func _wrap_dist(s1: float, s2: float, perim: float) -> float:
	var d := absf(s1 - s2)
	return minf(d, perim - d)


static func _min_wrap_dist(s: float, others: Array, perim: float) -> float:
	var m := INF
	for o in others:
		m = minf(m, _wrap_dist(s, o, perim))
	return m


static func _slip_points(objects: Array, src: Dictionary, touched: int, fresnel := false) -> Array:
	return _slip_scenes(objects, src, touched, fresnel).points


## Where the light lands under each plausible reading of the board, and which
## bodies any of those readings met. The second half is what tells scenery from
## a body that matters: if no reading sends light near it, nothing does
static func _slip_scenes(objects: Array, src: Dictionary, touched: int, fresnel := false) -> Dictionary:
	var opts := {"fresnel": false, "min_intensity": 0.02, "max_events": 96}
	var mirrors: Array = []
	var bodies: Array = []
	for o: SceneObj in objects:
		if o.is_reflector():
			mirrors.append(o)
		else:
			bodies.append(o)
	# each entry is a scene plus how its object indices map back to the real ones
	var scenes: Array = [[[], []]]
	var whole := range(objects.size())
	if not mirrors.is_empty() and not bodies.is_empty():
		scenes.append([mirrors, _indices_of(objects, mirrors)])
		scenes.append([bodies, _indices_of(objects, bodies)])
	for i in objects.size():
		if (touched & (1 << i)) == 0:
			continue
		var without: Array = objects.duplicate()
		var map: Array = whole.duplicate()
		without.remove_at(i)
		map.remove_at(i)
		scenes.append([without, map])
		scenes.append([[objects[i]], [i]])
	# misjudged the bending: one index step off lands near the truth, the
	# extremes land well away from it
	if not bodies.is_empty():
		for step in [-1, 1, -2, 2, -8, 8]:
			var swapped: Array = []
			for o: SceneObj in objects:
				swapped.append(o.clone_with(_index_step(o.mat_key, step)))
			scenes.append([swapped, whole])
		# mistaking one body for another lands very close, which is the decoy
		# hardest to rule out
		var nudged := 0
		for i in objects.size():
			if nudged >= 4:
				break
			if (touched & (1 << i)) == 0 or (objects[i] as SceneObj).is_reflector():
				continue
			nudged += 1
			for step in [-1, 1]:
				var one: Array = objects.duplicate()
				one[i] = (objects[i] as SceneObj).clone_with(_index_step((objects[i] as SceneObj).mat_key, step))
				scenes.append([one, whole])
	var pts: Array = []
	var used := 0
	for entry: Array in scenes:
		var r := RayTracer.trace(entry[0], FIELD, src.p, src.d, opts)
		if not r.ok:
			continue
		pts.append(r.exits[0].point)
		for e in r.exits:
			used |= _remap(e.touched, entry[1])
	# getting a law wrong rather than the scene wrong. These work even when the
	# board is too sparse to leave anything out, which is what a first level is.
	# Whether the branches are on matters here: a sheet that swallows one of them
	# only moves the answer once there is more than one beam to choose between
	for slip in RayTracer.mistakes_for(objects):
		var wrong := RayTracer.trace(objects, FIELD, src.p, src.d, {"fresnel": fresnel, "min_intensity": 0.02, "max_events": 96, "mistake": slip})
		if wrong.ok:
			pts.append(wrong.exits[0].point)
			for e in wrong.exits:
				used |= e.touched
	# partial reflections are real light even where the level ignores them, so
	# their exits are the most defensible wrong answers available
	if not bodies.is_empty():
		var split := RayTracer.trace(objects, FIELD, src.p, src.d, {"fresnel": true, "min_intensity": 0.02, "max_events": 96})
		for i in range(1, split.exits.size()):
			pts.append(split.exits[i].point)
		for e in split.exits:
			used |= e.touched
	return {"points": pts, "used": used}


static func _indices_of(objects: Array, subset: Array) -> Array:
	var out: Array = []
	for o in subset:
		out.append(objects.find(o))
	return out


static func _remap(mask: int, map: Array) -> int:
	var out := 0
	for i in map.size():
		if (mask & (1 << i)) != 0 and map[i] >= 0:
			out |= 1 << int(map[i])
	return out


static func _index_step(key: String, step: int) -> String:
	var i := OpticsMaterials.BY_INDEX.find(key)
	if i < 0:
		return key
	return OpticsMaterials.BY_INDEX[clampi(i + step, 0, OpticsMaterials.BY_INDEX.size() - 1)]


static func _path_has_crystal(touched: int, objects: Array) -> bool:
	for i in objects.size():
		if (touched & (1 << i)) != 0 and OpticsMaterials.is_crystal((objects[i] as SceneObj).mat_key):
			return true
	return false


static func _path_sheets(touched: int, objects: Array) -> int:
	var n := 0
	for i in objects.size():
		if (touched & (1 << i)) != 0 and (objects[i] as SceneObj).is_polarizer():
			n += 1
	return n


static func _path_has_rotary(touched: int, objects: Array) -> bool:
	for i in objects.size():
		if (touched & (1 << i)) != 0 and OpticsMaterials.is_rotary((objects[i] as SceneObj).mat_key):
			return true
	return false


## True when the answers are the ordinary and extraordinary halves of one beam
static func _split_by_crystal(exits: Array, answers: int) -> bool:
	var seen := {}
	for i in answers:
		seen[exits[i].pol] = true
	return seen.has("s") and seen.has("p")


static func _path_has_kinds(touched: int, objects: Array, required: Array) -> bool:
	for want: String in required:
		var found := false
		for i in objects.size():
			if (touched & (1 << i)) != 0 and (objects[i] as SceneObj).kind == want:
				found = true
				break
		if not found:
			return false
	return true


static func _min_point_dist(p: Vector2, others: Array) -> float:
	var m := INF
	for o: Vector2 in others:
		m = minf(m, p.distance_to(o))
	return m


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
