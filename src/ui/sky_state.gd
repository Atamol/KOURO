extends Node
## The drifting background, kept here rather than in the screen that shows it so
## it carries on across menus instead of starting over on every scene change.
##
## The beams run the same `RayTracer` the boards do, but no answer depends on them


const COUNT := 28
## one piece to a cell, since that many positions drawn at random bunch up
const GRID := Vector2i(7, 4)
## how far past the frame the opening deal reaches. Dealt inside it, the first
## minute looks like the screen is emptying
const SPREAD := 56.0
## only the strong benders, so a beam that meets one visibly changes course
const GLASSES := ["carbon_disulfide", "calcite", "sapphire", "sf11", "zirconia", "diamond", "rutile", "gallium_phosphide"]
## circle, slab, prism, mirror. Mirrors are rarest: a screen of them would have
## nothing to refract through
const KINDS := [0, 1, 2, 0, 1, 2, 3, 0, 1, 2, 3]
const SPRAY := 0.35
const SLOWEST := 6.0
const FASTEST := 15.0
## well past what the tracer needs (no body inside another): this is also what
## keeps the spread even, and at touching distance they clump
const APART := 50.0
const PUSH := 5.0
## clearance past a piece's own edge before it wraps. A single margin for all of
## them had to suit the largest, which kept the small ones off screen too long
const SLACK := 8.0
## a beam outlives the gap between two, so this cap is what decides how many
## are up at once
const BEAMS := 6
const BEAM_LEN := Vector2(170.0, 280.0)
const BEAM_SPEED := Vector2(190.0, 320.0)
const BEAM_GAP := 1.0
const BEAM_COL := Color(0.45, 1.00, 0.55)

var pieces: Array = []
var beams: Array = []
var next_beam := BEAM_GAP
## whether new beams may appear. What is already in flight runs its course
var lit := true
var roll := RandomNumberGenerator.new()
var room := Vector2(1280, 720)


func _ready() -> void:
	# the bloom pass belongs to the viewport rather than to any one screen, and
	# this is the node that outlives all of them
	add_child(Glow.env())
	roll.randomize()
	# one heading for the whole sky, give or take. Independent ones shear the deal
	# into a scatter, and a scatter has bare patches in it by nature
	var flow := roll.randf_range(0.0, TAU)
	# shuffled so the kinds, which are handed out in order, do not come out laid
	# in stripes across the grid
	var cells: Array = []
	for x in GRID.x:
		for y in GRID.y:
			cells.append(Vector2(x, y))
	for i in range(cells.size() - 1, 0, -1):
		var k := roll.randi_range(0, i)
		var held: Vector2 = cells[i]
		cells[i] = cells[k]
		cells[k] = held
	var cell := (room + Vector2(SPREAD, SPREAD) * 2.0) / Vector2(GRID)
	for i in COUNT:
		var span := roll.randf_range(50.0, 170.0)
		var kind: int = KINDS[i % KINDS.size()]
		var mirror: bool = kind == 3
		var mat: String = OpticsMaterials.REFLECTIVE_ORDER[roll.randi() % OpticsMaterials.REFLECTIVE_ORDER.size()] if mirror \
				else GLASSES[roll.randi() % GLASSES.size()]
		var tint: Color = OpticsMaterials.REFLECTIVE[mat].color if mirror else OpticsMaterials.TRANSPARENT[mat].color
		var home: Vector2 = cells[i % cells.size()]
		pieces.append({
			"kind": kind,
			"mat": mat,
			"at": (home + Vector2(roll.randf(), roll.randf())) * cell - Vector2(SPREAD, SPREAD),
			"drift": Vector2.from_angle(flow + roll.randf_range(-SPRAY, SPRAY)) * roll.randf_range(SLOWEST, FASTEST),
			"span": span,
			"tall": span * roll.randf_range(0.42, 0.88),
			"spin": roll.randf_range(-0.10, 0.10),
			"turn": roll.randf_range(0.0, TAU),
			"col": Color(tint, roll.randf_range(0.06, 0.13) if mirror else roll.randf_range(0.04, 0.09)),
		})
	# a cell is not wide enough to hold the largest pieces apart on its own
	for i in 40:
		_keep_apart(0.05)


func _process(delta: float) -> void:
	room = get_viewport().get_visible_rect().size
	for p: Dictionary in pieces:
		p.at += p.drift * delta
		p.turn += p.spin * delta
		# round the other side rather than turning back, or they would gather at
		# the edges over time
		var gone := _reach(p) + SLACK
		if p.at.x < -gone or p.at.x > room.x + gone or p.at.y < -gone or p.at.y > room.y + gone:
			_wrap(p)
	_keep_apart(delta)
	var bodies := _all_bodies()
	_run_beams(delta, bodies)


## Brought back in on the far side, at a spot no other piece is using
func _wrap(p: Dictionary) -> void:
	var gone := _reach(p) + SLACK
	var side := 0 if p.at.x < -gone else 1 if p.at.x > room.x + gone else 2 if p.at.y < -gone else 3
	# the emptiest of several tries, not the first that fits. Leaving the drift to
	# sort the spacing out ends in a full corner and a bare stretch
	var best := Vector2.ZERO
	var best_gap := 0.0
	for _try in 12:
		var spot := _edge_spot(side, gone)
		var gap := _room_at(p, spot)
		if gap > best_gap:
			best_gap = gap
			best = spot
	# nothing clear along that edge: it waits outside and comes round later
	if best_gap > 0.0:
		p.at = best


func _edge_spot(side: int, gone: float) -> Vector2:
	match side:
		0:
			return Vector2(room.x + gone, roll.randf_range(0.0, room.y))
		1:
			return Vector2(-gone, roll.randf_range(0.0, room.y))
		2:
			return Vector2(roll.randf_range(0.0, room.x), room.y + gone)
	return Vector2(roll.randf_range(0.0, room.x), -gone)


## The smallest slack against any other piece. At or below zero it is touching
func _room_at(p: Dictionary, spot: Vector2) -> float:
	var worst := INF
	for other: Dictionary in pieces:
		if other == p:
			continue
		worst = minf(worst, (other.at as Vector2).distance_to(spot) - _reach(p) - _reach(other) - APART)
	return worst


## Nudged apart rather than laid out to avoid it, since they drift and would
## collide again anyway. An overlap is the one thing the tracer cannot read
func _keep_apart(delta: float) -> void:
	var shove := minf(delta * PUSH, 1.0)
	for i in pieces.size():
		var a: Dictionary = pieces[i]
		for k in range(i + 1, pieces.size()):
			var b: Dictionary = pieces[k]
			var want := _reach(a) + _reach(b) + APART
			var away: Vector2 = b.at - a.at
			var gap := away.length()
			if gap >= want or gap < 0.001:
				continue
			var push: Vector2 = away.normalized() * (want - gap) * 0.5 * shove
			a.at -= push
			b.at += push


func _reach(p: Dictionary) -> float:
	if p.kind == 1:
		return sqrt(float(p.span) * float(p.span) + float(p.tall) * float(p.tall)) * 0.5
	return float(p.span) * 0.5


func _run_beams(delta: float, bodies: Array) -> void:
	if lit:
		next_beam -= delta
		if next_beam <= 0.0 and beams.size() < BEAMS:
			next_beam = BEAM_GAP
			var born := _new_beam(bodies)
			if not born.is_empty():
				beams.append(born)
	var keep: Array = []
	for b: Dictionary in beams:
		if _march(b, bodies, delta):
			keep.append(b)
	beams = keep


## The road ahead is retraced each frame, which is what makes a beam follow the
## pieces as they drift. Not while the head is inside one: a trace started in
## there takes itself for one starting in air and comes out wrong
func _march(b: Dictionary, bodies: Array, delta: float) -> bool:
	var head: Vector2 = b.head
	if _outside(bodies, head):
		var plan := _path_from(bodies, head, b.dir)
		# a trace that comes back with nothing leaves it on the road it had: only
		# running off the frame ends a beam
		if not plan.is_empty():
			b.road = plan.path
	var road: PackedVector2Array = b.road
	var left: float = float(b.speed) * delta
	var i := 1
	while left > 0.0 and i < road.size():
		var leg := head.distance_to(road[i])
		if leg < 0.001:
			i += 1
			continue
		b.dir = (road[i] - head).normalized()
		var take := minf(left, leg)
		head += b.dir * take
		left -= take
		if take >= leg:
			i += 1
	var screen := Rect2(Vector2.ZERO, room)
	# past the end of its road. Inside the frame that means it lost track of
	# where it was going, but outside there is simply nothing left to meet
	if left > 0.0:
		if road.size() < 2 and screen.has_point(head):
			return false
		head += b.dir * left
	b.head = head
	var rest := PackedVector2Array([head])
	for k in range(i, road.size()):
		rest.append(road[k])
	b.road = rest
	var trail: PackedVector2Array = b.trail
	trail.append(head)
	b.trail = _tail(trail, b.len)
	# it goes when the last of it has left, not when its head does
	return screen.grow(10.0).has_point((b.trail as PackedVector2Array)[0])


## Open air, which is the only place a trace may start
func _outside(bodies: Array, p: Vector2) -> bool:
	for body: SceneObj in bodies:
		if body.hit(p, 1.0):
			return false
	return true


## The last stretch of where the head has been, trimmed to the length a beam
## shows. Kept as points rather than a distance so the tail never leaps either
func _tail(trail: PackedVector2Array, want: float) -> PackedVector2Array:
	var run := 0.0
	var cut := 0
	for i in range(trail.size() - 1, 0, -1):
		run += (trail[i] as Vector2).distance_to(trail[i - 1])
		if run >= want:
			cut = i - 1
			break
	if cut == 0:
		return trail
	var out := PackedVector2Array()
	for i in range(cut, trail.size()):
		out.append(trail[i])
	return out


## A menu wants the light, a page being read does not
func allow_beams(on: bool) -> void:
	lit = on


## Where it starts and which way it points are settled for good here
func _new_beam(bodies: Array) -> Dictionary:
	# never from inside a piece: the tracer would not know which medium it began in
	var from := Vector2.ZERO
	var clear := false
	for _try in 8:
		from = _edge_point()
		clear = true
		for b: SceneObj in bodies:
			if b.hit(from, 6.0):
				clear = false
		if clear:
			break
	if not clear:
		return {}
	var goal := room * 0.5 + Vector2(roll.randf_range(-300.0, 300.0), roll.randf_range(-180.0, 180.0))
	var dir := (goal - from).normalized()
	var first := _path_from(bodies, from, dir)
	if first.is_empty() or float(first.total) < 40.0:
		return {}
	return {"head": from, "dir": dir, "road": first.path, "trail": PackedVector2Array([from]),
			"len": roll.randf_range(BEAM_LEN.x, BEAM_LEN.y),
			"speed": roll.randf_range(BEAM_SPEED.x, BEAM_SPEED.y)}


## The line it really takes through what is on screen right now, as a polyline.
## An overflow is taken as good as far as it got: in a crowd a ray can run past
## the event cap, and the answer up to there is still where the light goes
func _path_from(bodies: Array, from: Vector2, dir: Vector2) -> Dictionary:
	var res := RayTracer.trace(bodies, Rect2(Vector2.ZERO, room), from, dir,
			{"fresnel": false, "min_intensity": 0.05, "max_events": 12})
	if (res.exits as Array).is_empty():
		return {}
	# one continuous path: a crystal parts the beam in two, and the segments of
	# both are mixed together in the order they were traced
	var legs := RayTracer.legs_to(res, [res.exits[0]])
	if legs.is_empty():
		return {}
	var path := PackedVector2Array([legs[0].a])
	var total := 0.0
	for seg: Dictionary in legs:
		path.append(seg.b)
		total += (seg.a as Vector2).distance_to(seg.b)
	return {"path": path, "total": total}


func _edge_point() -> Vector2:
	match roll.randi_range(0, 3):
		0:
			return Vector2(roll.randf_range(0.0, room.x), 1.0)
		1:
			return Vector2(roll.randf_range(0.0, room.x), room.y - 1.0)
		2:
			return Vector2(1.0, roll.randf_range(0.0, room.y))
	return Vector2(room.x - 1.0, roll.randf_range(0.0, room.y))


## Every piece. They are kept from touching, at the frame and while they drift,
## so the tracer's one requirement holds and nothing a beam crosses is invisible
## to it
func _all_bodies() -> Array:
	var out: Array = []
	for p: Dictionary in pieces:
		out.append(_body(p))
	return out


func _body(p: Dictionary) -> SceneObj:
	if p.kind == 3:
		return ProblemGen.make_object("mirror", p.mat, p.at, p.span * 0.5, 0.0, p.turn)
	if p.kind == 0:
		return ProblemGen.make_object("circle", p.mat, p.at, p.span * 0.5, 0.0, p.turn)
	if p.kind == 1:
		return ProblemGen.make_object("slab", p.mat, p.at, p.span, p.tall, p.turn)
	return ProblemGen.make_object("prism", p.mat, p.at, p.span * 0.5, 0.0, p.turn)


## Drawn straight onto whatever asks for it, so a screen that paints its own
## background can put this over the top and its own contents over that
func paint(ci: CanvasItem) -> void:
	for p: Dictionary in pieces:
		var edge := Color(p.col, p.col.a * 2.4)
		if p.kind == 3:
			var arm: Vector2 = Vector2.from_angle(p.turn) * float(p.span) * 0.5
			ci.draw_line(p.at - arm, p.at + arm, edge, 3.0, true)
			continue
		if p.kind == 0:
			ci.draw_circle(p.at, p.span * 0.5, p.col)
			ci.draw_arc(p.at, p.span * 0.5, 0.0, TAU, 36, edge, 1.5, true)
			continue
		var corners := _corners(p)
		ci.draw_colored_polygon(corners, p.col)
		var loop := corners.duplicate()
		loop.append(corners[0])
		ci.draw_polyline(loop, edge, 1.5, true)
	for b: Dictionary in beams:
		var trail: PackedVector2Array = b.trail
		if trail.size() < 2:
			continue
		# dimmer than a beam on a board: this one is behind the screen, not on it
		ci.draw_polyline(trail, Glow.hot(Color(BEAM_COL, 0.75)), 2.6, true)


func _corners(p: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	if p.kind == 1:
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			out.append(p.at + Vector2(c.x * p.span * 0.5, c.y * p.tall * 0.5).rotated(p.turn))
		return out
	for k in 3:
		out.append(p.at + Vector2.from_angle(p.turn + TAU * k / 3.0) * p.span * 0.5)
	return out
