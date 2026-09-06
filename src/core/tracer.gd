class_name RayTracer
## A ray carries two directions: `d` is where the energy goes and decides the
## geometry, `wave` is the wave normal and governs refraction. They differ only
## inside a birefringent body.
##
## Every optic axis lies in the plane of the board, so the plane of incidence
## always contains it and the ordinary wave is the one polarized out of the
## plane. `pol` is the mode a beam travels as inside a crystal, which is the one
## thing the state alone cannot say


# offset along the interface normal, never along the ray: a directional advance
# collapses under float32 rounding at grazing angles. Large enough that a hit
# point's own rounding cannot put the spawn on the wrong side of the surface,
# which used to hand the next surface the wrong medium
const ADVANCE := 0.05
# px/s in air, for the reveal animation only
const SPEED := 720.0
## The advance itself is exact, so this only sets how finely the boundary is
## found and how smoothly the curve draws
const GRIN_STEP := 4.0
const GRIN_MAX := 4000.0

## Ways of getting the optics wrong that a person plausibly would, so a decoy is
## wrong for a reason rather than a point light never reaches
const MISTAKES := [
	"reflect_axis", "normal_bounce", "bend_back", "snell_swap",
	"no_polarizer", "flip_polarizer", "no_rotation", "no_polarization", "flat_gradient", "flip_gradient",
]


## Only the mistakes a board can express. Tracing the rest costs time
## and gives back the true answer, which is then thrown away as a duplicate
static func mistakes_for(objects: Array) -> Array:
	var has := {}
	for o: SceneObj in objects:
		if o.is_reflector():
			has["metal"] = true
		elif o.is_polarizer():
			has["sheet"] = true
		else:
			has["glass"] = true
			if o is GradientBody:
				has["grin"] = true
			if OpticsMaterials.is_rotary(o.mat_key):
				has["rotary"] = true
	var out: Array = []
	for m: String in MISTAKES:
		# reading straight past polarization, the way someone who has not met it
		# yet does. It only says anything the two single slips do not when both
		# kinds of element are on the board
		if m == "no_polarization":
			if has.has("sheet") and has.has("rotary"):
				out.append(m)
			continue
		var need := "glass"
		match m:
			"reflect_axis", "normal_bounce":
				need = "metal"
			"no_polarizer", "flip_polarizer":
				need = "sheet"
			"no_rotation":
				need = "rotary"
			"flat_gradient", "flip_gradient":
				need = "grin"
		if has.has(need):
			out.append(m)
	return out


static func trace(objects: Array, field: Rect2, src_p: Vector2, src_d: Vector2, opts: Dictionary = {}) -> Dictionary:
	var fresnel: bool = opts.get("fresnel", false)
	var min_intensity: float = opts.get("min_intensity", 0.02)
	var max_events: int = opts.get("max_events", 96)
	var mistake: String = opts.get("mistake", "")
	# a pass over every body per leg, so only the levels that ask for it pay
	var measure: bool = opts.get("clear", false)
	var segments: Array = []
	var exits: Array = []
	var events_total := 0
	var overflow := false
	# parent of each branch, so a leg can be traced back to the beam it came off
	var lines: Array = [-1]
	var start := {"events": 0, "touched": 0, "tir": 0, "split": 0, "clear": INF, "entry": INF, "near": INF, "graze": 1.0, "sheet": 1.0, "spin": 0.0, "last": -1, "line": 0}
	var queue: Array = [_ray(src_p + src_d * ADVANCE, src_d, src_d, OpticsMaterials.AIR, 1.0, null, "", Jones.unpolarized(), 0.0, start, src_p)]
	while not queue.is_empty():
		if events_total >= max_events:
			overflow = true
			break
		# brightest first so the caps cut dim tails, not the main path
		queue.sort_custom(func(x, y): return x.intensity > y.intensity)
		var ray: Dictionary = queue.pop_front()
		var hit := {}
		var hit_obj: SceneObj = null
		var hit_index := -1
		if ray.inside is GradientBody and mistake != "flat_gradient":
			hit = _march(ray.inside, ray, mistake)
			hit_index = objects.find(ray.inside)
			if hit.is_empty() or hit_index < 0:
				continue
			hit_obj = ray.inside
		else:
			for i in objects.size():
				var obj: SceneObj = objects[i]
				var h: Dictionary = obj.intersect(ray.p, ray.d)
				if h and (hit.is_empty() or h.t < hit.t):
					hit = h
					hit_obj = obj
					hit_index = i
			var border := Isect.ray_rect_exit(ray.p, ray.d, field)
			if hit.is_empty() or (not border.is_empty() and border.t < hit.t):
				if border.is_empty():
					continue
				var t1: float = ray.time + border.t * ray.n_med / SPEED
				segments.append({"a": ray.origin, "b": border.point, "intensity": ray.intensity, "t0": ray.time, "t1": t1, "line": ray.line})
				var out_near: float = ray.near
				if measure:
					out_near = minf(out_near, _clearance(ray.p, border.point, objects, -1, ray.last))
				exits.append({
					"point": border.point, "dir": ray.d, "intensity": ray.intensity, "time": t1,
					"events": ray.events, "touched": ray.touched, "tir": ray.tir, "split": ray.split,
					"clear": ray.clear, "entry": ray.entry, "near": out_near, "graze": ray.graze,
					"sheet": ray.sheet, "spin": ray.spin + _spin(ray, border.t), "pol": ray.pol,
					"line": ray.line, "jones": _turned(ray, border.t, mistake),
				})
				continue
		events_total += 1
		var t_hit: float = ray.time + hit.get("time", hit.t * ray.n_med / SPEED)
		var touched: int = ray.touched | (1 << hit_index)
		_emit(segments, ray, hit, t_hit)
		# an active medium turns the plane all the way across, so the state that
		# meets this surface is not the one that set out
		var moved: Dictionary = ray.duplicate()
		moved.jones = _turned(ray, hit.t, mistake)
		moved.spin = ray.spin + _spin(ray, hit.t)
		moved.last = hit_index
		if measure:
			var margin: float = hit.get("margin", INF)
			# whether the light reaches the first body at all is the one call a
			# player makes with nothing already drawn to lean on
			if ray.events == 0:
				moved.entry = margin
			moved.clear = minf(ray.clear, margin)
			moved.near = minf(ray.near, _clearance(ray.p, hit.point, objects, hit_index, ray.last))
			# a mirror met almost edge on throws the beam somewhere nobody can
			# read off the board. A glass face met the same way bends hard and
			# obviously, so only reflectors are measured
			if hit_obj.is_reflector():
				moved.graze = minf(ray.graze, absf((hit.dir if hit.has("dir") else ray.d).dot(hit.normal)))
		if hit.has("dir"):
			moved.d = hit.dir
			moved.wave = hit.dir
			moved.n_med = hit.n
		if hit_obj.is_polarizer():
			var sheet: PolarizerObj = hit_obj
			# a sheet met off its normal blocks less than its angle says it should,
			# and the angle is all the player has to go on
			if measure:
				moved.sheet = minf(ray.sheet, absf(sheet.direction().dot(Vector2(moved.d.y, -moved.d.x))))
			var m := _sheet_matrix(sheet, moved.d, mistake)
			var ti: float = moved.intensity * Jones.throughput(m, moved.jones)
			if ti >= min_intensity:
				queue.append(_ray(hit.point - hit.normal * ADVANCE, moved.d, moved.wave, moved.n_med, ti,
						moved.inside, moved.pol, Jones.normalized(Jones.apply(m, moved.jones)), t_hit, _next(moved, touched, false, false, lines), hit.point))
			continue
		if hit_obj.is_reflector():
			var rdir := Optics.reflect(moved.d, hit.normal).normalized()
			var side: Vector2 = hit.normal
			# taking the mirror line as the axis instead of its normal, which sends
			# the reflection on through the surface
			if mistake == "reflect_axis":
				rdir = -rdir
				side = -hit.normal
			# or the belief that light comes straight back off a mirror
			elif mistake == "normal_bounce":
				rdir = hit.normal
			var refl: float = OpticsMaterials.REFLECTIVE[hit_obj.mat_key].reflectance
			var ri: float = moved.intensity * refl
			if ri >= min_intensity:
				var amp := Optics.mirror_reflection(refl)
				var turned := Jones.normalized(Jones.apply(Jones.diagonal(amp[0], amp[1]), moved.jones))
				queue.append(_ray(hit.point + side * ADVANCE, rdir, rdir, moved.n_med, ri, moved.inside, moved.pol, turned, t_hit, _next(moved, touched, false, false, lines), hit.point))
			continue
		queue.append_array(_at_interface(moved, hit, hit_obj, touched, t_hit, fresnel, min_intensity, lines, mistake))
	exits.sort_custom(func(x, y): return x.intensity > y.intensity)
	return {"ok": not overflow and not exits.is_empty(), "segments": segments, "exits": exits,
			"events": events_total, "overflow": overflow, "lines": lines}


static func _emit(segments: Array, ray: Dictionary, hit: Dictionary, t_hit: float) -> void:
	if not hit.has("points"):
		segments.append({"a": ray.origin, "b": hit.point, "intensity": ray.intensity, "t0": ray.time, "t1": t_hit, "line": ray.line})
		return
	var pts: PackedVector2Array = hit.points
	var times: PackedFloat32Array = hit.times
	for i in range(1, pts.size()):
		segments.append({"a": pts[i - 1], "b": pts[i], "intensity": ray.intensity,
				"t0": ray.time + times[i - 1], "t1": ray.time + times[i], "line": ray.line})


## How far an active medium has turned the plane over this leg, which is what
## decides whether the next sheet plainly passes the light or plainly stops it
static func _spin(ray: Dictionary, length: float) -> float:
	if ray.inside == null:
		return 0.0
	return absf(OpticsMaterials.rotary((ray.inside as SceneObj).mat_key) * length)


static func _turned(ray: Dictionary, length: float, mistake: String) -> Array:
	if mistake == "no_rotation" or mistake == "no_polarization" or ray.inside == null:
		return ray.jones
	var rho: float = OpticsMaterials.rotary((ray.inside as SceneObj).mat_key)
	if rho == 0.0:
		return ray.jones
	return Jones.apply(Jones.rotator(rho * length), ray.jones)


static func _sheet_matrix(sheet: PolarizerObj, d: Vector2, mistake: String) -> Array:
	if mistake == "no_polarizer" or mistake == "no_polarization":
		return Jones.symmetric(1.0, 0.0, 1.0)
	# reading the axis off the wrong way round, the slip a crossed pair invites
	var phi: float = PI * 0.5 - sheet.phi if mistake == "flip_polarizer" else sheet.phi
	return Optics.polarizer_matrix(phi, sheet.direction(), d)


## Comes back in the same shape a straight intersection does, plus the points
## the curve is drawn with
static func _march(body: GradientBody, ray: Dictionary, mistake: String) -> Dictionary:
	var grad := body.gradient()
	if mistake == "flip_gradient":
		grad = -grad
	var p: Vector2 = ray.p
	var t_vec: Vector2 = ray.d * body.index_at(p)
	var points := PackedVector2Array([ray.origin])
	var times := PackedFloat32Array([0.0])
	var travelled := 0.0
	var time := 0.0
	while travelled < GRIN_MAX:
		var step := minf(GRIN_STEP, GRIN_MAX - travelled)
		var nxt := Optics.grin_advance(p, t_vec, grad, step)
		var leaving := not body.contains(nxt.p)
		if leaving:
			var lo := 0.0
			var hi := step
			for _i in 30:
				var mid := (lo + hi) * 0.5
				if body.contains(Optics.grin_advance(p, t_vec, grad, mid).p):
					lo = mid
				else:
					hi = mid
			step = lo
			nxt = Optics.grin_advance(p, t_vec, grad, step)
		var n_from: float = t_vec.length()
		var n_to: float = (nxt.t as Vector2).length()
		time += step * (n_from + n_to) * 0.5 / SPEED
		travelled += step
		p = nxt.p
		t_vec = nxt.t
		points.append(p)
		times.append(time)
		if leaving:
			var dir := t_vec.normalized()
			var face := _face_at(body, p, dir)
			return {
				"t": travelled, "point": p, "dir": dir, "n": t_vec.length(), "time": time,
				"normal": face.normal, "margin": face.margin, "points": points, "times": times,
			}
	return {}


## Turned to face the ray, with the margin an intersection would have reported.
## A curve that leaves through a corner is as unreadable as a straight ray that
## meets one, and here the face is picked by nearness, so the corner decides
## nothing at all
static func _face_at(body: PolyBody, point: Vector2, dir: Vector2) -> Dictionary:
	var pts: PackedVector2Array = body.points
	var best := INF
	var normal := Vector2.UP
	var margin := INF
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var on := Geometry2D.get_closest_point_to_segment(point, a, b)
		var away := on.distance_to(point)
		if away < best:
			best = away
			var edge := b - a
			normal = Vector2(-edge.y, edge.x).normalized()
			var span := edge.length()
			var s: float = 0.0 if span < 1e-9 else clampf(a.distance_to(on) / span, 0.0, 1.0)
			margin = minf(s, 1.0 - s) * absf(dir.cross(edge))
	return {"normal": -normal if normal.dot(dir) > 0.0 else normal, "margin": margin}


## Every ray that leaves a transparent boundary: one or two transmitted modes,
## plus the partial reflection when branches are on
static func _at_interface(ray: Dictionary, hit: Dictionary, body: SceneObj, touched: int, t_hit: float, fresnel: bool, min_intensity: float, lines: Array, mistake := "") -> Array:
	# no overlaps allowed, so a ray outside bodies always enters and a ray
	# inside one can only be hitting its own boundary
	var entering: bool = ray.inside == null
	var mat: Dictionary = OpticsMaterials.TRANSPARENT[body.mat_key]
	var normal: Vector2 = hit.normal
	var wave: Vector2 = ray.wave
	var cos_i := clampf(-wave.dot(normal), 0.0, 1.0)
	var sin_i := sqrt(maxf(1.0 - cos_i * cos_i, 0.0))
	# tangential part of the wave vector, conserved across the boundary
	var q: float = ray.n_med * sin_i
	var tang := wave + normal * cos_i
	tang = tang.normalized() if tang.length() > 1e-9 else Vector2(-normal.y, normal.x)
	var splitting: bool = entering and mat.has("ne")
	var n_to := _far_index(body, hit.point, entering, mistake)
	var beams := {"s": {}, "p": {}}
	if splitting:
		beams.s = _transmit("s", true, mat, body, q, normal, tang, wave, ray.n_med, n_to, mistake)
		beams.p = _transmit("p", true, mat, body, q, normal, tang, wave, ray.n_med, n_to, mistake)
	else:
		# an isotropic boundary bends both polarizations the same, only the amount
		# that gets through differs
		var one := _transmit(ray.pol, entering, mat, body, q, normal, tang, wave, ray.n_med, n_to, mistake)
		beams.s = one
		beams.p = one
	var amp := _reflection_amplitudes(cos_i, ray.n_med, beams, splitting, mat, body, tang, n_to)
	var r_mat := Jones.diagonal(amp[0], amp[1])
	var r_pow := Jones.throughput(r_mat, ray.jones)
	var out := []
	if splitting:
		var share_s := Jones.share_s(ray.jones)
		for mode: Array in [["s", share_s, amp[0]], ["p", 1.0 - share_s, amp[1]]]:
			var share: float = mode[1]
			var beam: Dictionary = beams[mode[0]]
			if share <= 1e-9 or beam.is_empty():
				continue
			var r_mode: float = (mode[2] as Vector2).length_squared()
			var ti: float = ray.intensity * share * ((1.0 - r_mode) if fresnel else 1.0)
			if ti >= min_intensity:
				out.append(_ray(hit.point - normal * ADVANCE, beam.d, beam.wave, beam.n, ti,
						body, mode[0], Jones.pure(mode[0]), t_hit, _next(ray, touched, false, false, lines), hit.point))
	elif not beams.s.is_empty():
		var beam: Dictionary = beams.s
		var ti: float = ray.intensity * ((1.0 - r_pow) if fresnel else 1.0)
		if ti >= min_intensity:
			var t_amp := Optics.fresnel_transmission(cos_i, beam.cos_t, ray.n_med, beam.n)
			var state := Jones.normalized(Jones.apply(Jones.diagonal(t_amp[0], t_amp[1]), ray.jones))
			out.append(_ray(hit.point - normal * ADVANCE, beam.d, beam.wave, beam.n, ti,
					body if entering else null, ray.pol, state, t_hit, _next(ray, touched, false, false, lines), hit.point))
	# with no fresnel split, whatever cannot get through is turned back instead
	var back: float = ray.intensity * (r_pow if fresnel else (1.0 if out.is_empty() else 0.0))
	if back >= min_intensity:
		var bounce := _reflect_back(ray, entering, mat, body, q, normal, tang, wave)
		if not bounce.is_empty():
			out.append(_ray(hit.point + normal * ADVANCE, bounce.d, bounce.wave, bounce.n, back,
					ray.inside, ray.pol, Jones.normalized(Jones.apply(r_mat, ray.jones)), t_hit,
					_next(ray, touched, out.is_empty(), not out.is_empty(), lines), hit.point))
	return out


## Only a gradient body makes this depend on where the ray met the surface
static func _far_index(body: SceneObj, point: Vector2, entering: bool, mistake: String) -> float:
	if not entering:
		return OpticsMaterials.AIR
	if body is GradientBody and mistake != "flat_gradient":
		return (body as GradientBody).index_at(point)
	return OpticsMaterials.TRANSPARENT[body.mat_key].n


## A crystal reflects each mode against its own index, and a mode that cannot
## get through at all is measured against the index it would have seen along the
## surface, which is exactly where its critical angle sits
static func _reflection_amplitudes(cos_i: float, n_from: float, beams: Dictionary, splitting: bool, mat: Dictionary, body: SceneObj, tang: Vector2, n_to: float) -> Array:
	if not splitting:
		var far: float = beams.s.n if not beams.s.is_empty() else n_to
		return Optics.fresnel_reflection(cos_i, n_from, far)
	var axis := Vector2.from_angle(body.axis)
	var far_p: float = beams.p.n if not beams.p.is_empty() else Optics.extraordinary_index(tang, axis, mat.n, mat.ne)
	return [
		Optics.fresnel_reflection(cos_i, n_from, mat.n)[0],
		Optics.fresnel_reflection(cos_i, n_from, far_p)[1],
	]


static func _transmit(pol: String, entering: bool, mat: Dictionary, body: SceneObj, q: float, normal: Vector2, tang: Vector2, wave: Vector2, n_from: float, n_to: float, mistake := "") -> Dictionary:
	var into := -normal
	if not mistake.is_empty() and not mat.has("ne"):
		# reading Snell upside down, so the ray bends by the reciprocal ratio
		if mistake == "snell_swap":
			var swapped = Optics.refract(wave, normal, n_to, n_from)
			if swapped == null:
				return {}
			var sd: Vector2 = swapped
			return {"d": sd, "wave": sd, "n": n_to, "cos_t": clampf(sd.dot(into), 0.0, 1.0)}
		# bending the right amount but to the wrong side of the normal
		if mistake == "bend_back":
			var right = Optics.refract(wave, normal, n_from, n_to)
			if right == null:
				return {}
			var rd: Vector2 = right
			var flipped := (normal * (2.0 * rd.dot(normal)) - rd).normalized()
			return {"d": flipped, "wave": flipped, "n": n_to, "cos_t": clampf(flipped.dot(into), 0.0, 1.0)}
	if entering and mat.has("ne") and pol == "p":
		var axis := Vector2.from_angle(body.axis)
		var k = Optics.extraordinary_wave(q, into, tang, axis, mat.n, mat.ne)
		if k == null:
			return {}
		var kk: Vector2 = k
		var n2 := Optics.extraordinary_index(kk, axis, mat.n, mat.ne)
		return {"d": Optics.walk_off(kk, axis, mat.n, mat.ne), "wave": kk, "n": n2, "cos_t": clampf(kk.dot(into), 0.0, 1.0)}
	var t = Optics.refract(wave, normal, n_from, n_to)
	if t == null:
		return {}
	var td: Vector2 = t
	return {"d": td, "wave": td, "n": n_to, "cos_t": clampf(td.dot(into), 0.0, 1.0)}


## The reflected wave stays on the side it came from, so inside a crystal it is
## solved the same way as a refraction rather than mirrored
static func _reflect_back(ray: Dictionary, entering: bool, mat: Dictionary, body: SceneObj, q: float, normal: Vector2, tang: Vector2, wave: Vector2) -> Dictionary:
	if not entering and mat.has("ne") and ray.pol == "p":
		var axis := Vector2.from_angle(body.axis)
		var k = Optics.extraordinary_wave(q, normal, tang, axis, mat.n, mat.ne)
		# the incident wave solves the same chord, so a branch always exists.
		# Falling back keeps the energy rather than deleting the beam if one does not
		if k != null:
			var kk: Vector2 = k
			return {"d": Optics.walk_off(kk, axis, mat.n, mat.ne), "wave": kk, "n": Optics.extraordinary_index(kk, axis, mat.n, mat.ne)}
	var r := Optics.reflect(wave, normal).normalized()
	return {"d": r, "wave": r, "n": ray.n_med}


## `split` counts partial reflections taken, which is what tells a beam that
## merely crossed a surface apart from one a surface sent back
static func _next(ray: Dictionary, touched: int, tir: bool, split: bool, lines: Array) -> Dictionary:
	lines.append(ray.line)
	return {
		"events": ray.events + 1, "touched": touched,
		"tir": ray.tir + (1 if tir else 0), "split": ray.split + (1 if split else 0),
		"clear": ray.clear, "entry": ray.entry, "near": ray.near, "graze": ray.graze,
		"sheet": ray.sheet, "spin": ray.spin, "last": ray.last,
		"line": lines.size() - 1,
	}


## How near this leg came to a body it did not touch. A beam that skims one
## makes a problem nobody can read off the board
static func _clearance(a: Vector2, b: Vector2, objects: Array, hit_index: int, from_index: int) -> float:
	var best := INF
	for i in objects.size():
		if i == hit_index or i == from_index:
			continue
		var obj: SceneObj = objects[i]
		if obj is CircleBody:
			var c: CircleBody = obj
			best = minf(best, Geometry2D.get_closest_point_to_segment(c.center, a, b).distance_to(c.center) - c.radius)
			continue
		var line := obj.outline(0.0)
		for k in line.size():
			var pair := Geometry2D.get_closest_points_between_segments(a, b, line[k], line[(k + 1) % line.size()])
			best = minf(best, (pair[0] as Vector2).distance_to(pair[1]))
	return maxf(best, 0.0)


## `p` is pushed clear of the surface so the next intersection cannot find the
## one just left, `origin` is where the leg really starts and is what gets drawn
static func _ray(p: Vector2, d: Vector2, wave: Vector2, n_med: float, intensity: float, inside, pol: String, jones: Array, time: float, path: Dictionary, origin: Vector2) -> Dictionary:
	# the spawn sits ADVANCE off the surface, but a hit point carries float32
	# error of its own, so a point still inside can read as just outside. Only a
	# spawn well clear of the body, which is what a vertex produces, is demoted
	if inside != null and not inside.hit(p, ADVANCE * 4.0):
		inside = null
		n_med = OpticsMaterials.AIR
		wave = d
	return {
		"p": p, "origin": origin, "d": d, "wave": wave, "n_med": n_med, "intensity": intensity, "inside": inside,
		"pol": pol, "jones": jones, "time": time,
		"events": path.events, "touched": path.touched, "tir": path.tir, "split": path.split,
		"clear": path.clear, "entry": path.entry, "near": path.near, "graze": path.graze,
		"sheet": path.sheet, "spin": path.spin, "last": path.last,
		"line": path.line,
	}


## The legs that led to these exits and nothing else. A reveal that draws every
## branch answers a question nobody was asked, since only one beam is the answer
static func legs_to(trace: Dictionary, exits: Array) -> Array:
	var lines: Array = trace.get("lines", [])
	var keep := {}
	for e: Dictionary in exits:
		var at: int = e.get("line", -1)
		while at >= 0 and at < lines.size() and not keep.has(at):
			keep[at] = true
			at = lines[at]
	var out: Array = []
	for s: Dictionary in trace.segments:
		if keep.has(s.get("line", -1)):
			out.append(s)
	return out


static func count_objects(touched: int) -> int:
	var n := 0
	while touched != 0:
		n += touched & 1
		touched >>= 1
	return n
