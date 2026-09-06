extends SceneTree
## Headless physics tests. Commands are in CLAUDE.md


var fails := 0
var count := 0


func _init() -> void:
	_test_reflect()
	_test_refract()
	_test_tir()
	_test_fresnel()
	_test_isect()
	_test_tracer_straight()
	_test_tracer_mirror()
	_test_tracer_slab()
	_test_tracer_slab_anywhere()
	_test_tracer_circle_center()
	_test_grazing()
	_test_mistakes()
	_test_birefringence()
	_test_jones()
	_test_polarizer()
	_test_rotation()
	_test_gradient()
	_test_split_count()
	_test_one_path()
	_test_clearance()
	_test_energy()
	_test_level_progression()
	_test_stage_code()
	_test_generation()
	_test_sliced_search()
	_test_early_no_tir()
	print("---")
	print("%d/%d passed" % [count - fails, count])
	quit(1 if fails > 0 else 0)


func check(name: String, cond: bool) -> void:
	count += 1
	if cond:
		print("[PASS] " + name)
	else:
		fails += 1
		print("[FAIL] " + name)


func approx(a: float, b: float, tol := 1e-4) -> bool:
	return absf(a - b) <= tol


func _test_reflect() -> void:
	var n := Vector2(-1, 1).normalized()
	var i := Vector2(1, 0)
	var r := Optics.reflect(i, n)
	check("reflect 45deg mirror", r.is_equal_approx(Vector2(0, 1)))
	check("reflect preserves angle", approx(-i.dot(n), r.dot(n), 1e-6))


func _test_refract() -> void:
	var n_air := OpticsMaterials.AIR
	var n_w: float = OpticsMaterials.TRANSPARENT.water.n
	var normal := Vector2(0, -1)
	var theta_i := deg_to_rad(45.0)
	var i := Vector2(sin(theta_i), cos(theta_i))
	var t = Optics.refract(i, normal, n_air, n_w)
	check("refract returns dir", t != null)
	if t != null:
		var tv: Vector2 = t
		var expected := asin(sin(theta_i) * n_air / n_w)
		check("snell 45deg air->water", approx(acos(clampf(tv.y, -1.0, 1.0)), expected, 1e-5))
		check("refract keeps tangential side", tv.x > 0.0)


func _test_tir() -> void:
	var n_air := OpticsMaterials.AIR
	var n_w: float = OpticsMaterials.TRANSPARENT.water.n
	var normal := Vector2(0, -1)
	var crit := Optics.critical_angle(n_w, n_air)
	check("critical angle water->air", approx(rad_to_deg(crit), 48.63, 0.15))
	var i_over := Vector2(sin(crit + 0.02), cos(crit + 0.02))
	check("tir beyond critical", Optics.refract(i_over, normal, n_w, n_air) == null)
	var i_under := Vector2(sin(crit - 0.02), cos(crit - 0.02))
	check("no tir below critical", Optics.refract(i_under, normal, n_w, n_air) != null)


func _test_fresnel() -> void:
	var n_air := OpticsMaterials.AIR
	var n_g: float = OpticsMaterials.TRANSPARENT.soda_glass.n
	var r0 := Optics.reflectance(Vector2(0, 1), Vector2(0, -1), n_air, n_g)
	var expected := pow((n_air - n_g) / (n_air + n_g), 2.0)
	check("fresnel normal incidence", approx(r0, expected, 1e-9))
	var tb := atan(n_g / n_air)
	var cos_i := cos(tb)
	var sin_t := sin(tb) * n_air / n_g
	var cos_t := sqrt(1.0 - sin_t * sin_t)
	var f := Optics.fresnel_components(cos_i, cos_t, n_air, n_g)
	check("brewster rp=0", f.rp < 1e-9)


func _test_isect() -> void:
	var h := Isect.ray_circle(Vector2(0, 0), Vector2(1, 0), Vector2(10, 0), 3.0)
	check("ray_circle near root", not h.is_empty() and approx(h.t, 7.0, 1e-5) and h.normal.is_equal_approx(Vector2(-1, 0)))
	var h2 := Isect.ray_segment(Vector2(0, 0), Vector2(1, 0), Vector2(5, -5), Vector2(5, 5))
	check("ray_segment hit", not h2.is_empty() and approx(h2.t, 5.0, 1e-6))
	var h3 := Isect.ray_segment(Vector2(0, 0), Vector2(1, 0), Vector2(2, 1), Vector2(8, 1))
	check("ray_segment parallel miss", h3.is_empty())
	var h4 := Isect.ray_rect_exit(Vector2(50, 25), Vector2(1, 0), Rect2(0, 0, 100, 50))
	check("rect exit", not h4.is_empty() and h4.point.distance_to(Vector2(100, 25)) < 1e-4)


func _test_tracer_straight() -> void:
	var f := ProblemGen.FIELD
	var res := RayTracer.trace([], f, Vector2(f.position.x, 300), Vector2(1, 0), {})
	check("straight exit", res.ok and res.exits.size() == 1 and res.exits[0].point.distance_to(Vector2(f.end.x, 300.0)) < 0.05)


func _test_tracer_mirror() -> void:
	var f := ProblemGen.FIELD
	var mir := MirrorObj.new(Vector2(600, 250), Vector2(700, 350))
	var res := RayTracer.trace([mir], f, Vector2(f.position.x, 300), Vector2(1, 0), {})
	check("mirror bounce", res.ok and res.exits[0].events == 1 and res.exits[0].point.distance_to(Vector2(650, f.end.y)) < 0.1)


func _test_tracer_slab() -> void:
	var f := ProblemGen.FIELD
	var slab := PolyBody.new(ProblemGen._rect_points(Vector2(640, 360), 220.0, 60.0, 0.0), "soda_glass")
	var d := Vector2.from_angle(deg_to_rad(25.0))
	var res := RayTracer.trace([slab], f, Vector2(f.position.x, 150.0), d, {})
	var hit_it: bool = res.ok and res.exits.size() == 1 and res.exits[0].events == 2
	check("slab traversed", hit_it)
	if hit_it:
		check("slab exit parallel", res.exits[0].dir.dot(d) > 0.99999)
		# straight line would exit elsewhere: lateral displacement must exist
		var straight := Isect.ray_rect_exit(Vector2(f.position.x, 150.0) + d * 0.001, d, f)
		check("slab lateral offset", res.exits[0].point.distance_to(straight.point) > 1.0)


# the slab above sits square on the middle of the field, where the arithmetic is
# kindest. Away from there a hit point carries enough float32 error that a spawn
# a thousandth of a pixel inside the glass reads as outside it, and the tracer
# then took the exit face for another entry: the beam left bent, and a later
# face could hand back a reflection no angle can produce
func _test_tracer_slab_anywhere() -> void:
	var f := ProblemGen.FIELD
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260817
	var tried := 0
	var odd := 0
	var bounced := 0
	var worst := 0.0
	for _shot in 400:
		var spin := rng.randf_range(0.0, PI)
		var mid := f.get_center() + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-30.0, 30.0))
		var slab := PolyBody.new(ProblemGen._rect_points(mid, 420.0, rng.randf_range(50.0, 90.0), spin), "soda_glass")
		# aimed through the middle and within 70 degrees of the normal, so the beam
		# is bound to cross between the two long faces and no end face can take it
		var d := Vector2.from_angle(spin + PI * 0.5).rotated(rng.randf_range(-1.22, 1.22))
		var src := mid - d * 230.0
		if not f.has_point(src):
			continue
		var res := RayTracer.trace([slab], f, src, d, {})
		if not res.ok or res.exits.size() != 1:
			continue
		tried += 1
		var e: Dictionary = res.exits[0]
		bounced += e.tir as int
		if e.events != 2:
			odd += 1
			continue
		worst = maxf(worst, rad_to_deg(absf(d.angle_to(e.dir))))
	check("enough of the sample lands on the slab to mean anything", tried > 100)
	check("a slab anywhere on the field is one face in and one out", odd == 0)
	check("and never traps the light on the way out", bounced == 0)
	check("and hands the beam back on the heading it came in on", worst < 0.01)


func _test_tracer_circle_center() -> void:
	var f := ProblemGen.FIELD
	var c := CircleBody.new(Vector2(640, 360), 80.0, "water")
	var res := RayTracer.trace([c], f, Vector2(f.position.x, 360.0), Vector2(1, 0), {})
	var okc: bool = res.ok and res.exits.size() == 1 and res.exits[0].events == 2
	check("circle center traversed", okc)
	if okc:
		check("circle center undeviated", res.exits[0].dir.dot(Vector2(1, 0)) > 0.99999 and absf(res.exits[0].point.y - 360.0) < 0.05)


# grazing incidence used to self-reintersect under float32 rounding
func _test_grazing() -> void:
	var f := ProblemGen.FIELD
	var c := Vector2(640, 360)
	var rot := 0.3
	var slab := PolyBody.new(ProblemGen._rect_points(c, 220.0, 60.0, rot), "soda_glass")
	var face_center := c + Vector2(0, -30).rotated(rot)
	var n_out := Vector2(0, -1).rotated(rot)
	var slab_ok := true
	for k in 20:
		var theta := deg_to_rad(80.0 + 0.5 * k)
		var d := (-n_out).rotated(theta)
		var origin := face_center - d * 180.0
		var res := RayTracer.trace([slab], f, origin, d, {})
		if not (res.ok and res.exits.size() == 1 and res.exits[0].events == 2 and res.exits[0].dir.dot(d) > 0.99999):
			slab_ok = false
		for seg in res.segments:
			if seg.a.distance_to(seg.b) < 0.05:
				slab_ok = false
	check("grazing slab entries", slab_ok)
	var ma := Vector2(500, 400)
	var mb := Vector2(800, 320)
	var mir := MirrorObj.new(ma, mb)
	var mid := (ma + mb) * 0.5
	var mdir := (mb - ma).normalized()
	var mnorm := Vector2(-mdir.y, mdir.x)
	var mirror_ok := true
	for k in 12:
		var theta := deg_to_rad(84.0 + 0.5 * k)
		var d := (-mnorm).rotated(theta)
		var origin := mid - d * 150.0
		var res := RayTracer.trace([mir], f, origin, d, {})
		if not (res.ok and res.exits.size() == 1 and res.exits[0].events == 1 and res.segments.size() == 2):
			mirror_ok = false
		for seg in res.segments:
			if seg.a.distance_to(seg.b) < 0.05:
				mirror_ok = false
	check("grazing mirror bounces", mirror_ok)


# the deliberate mistakes have to be wrong in the specific way they claim, or
# the decoys they produce are just noise
func _test_mistakes() -> void:
	var f := ProblemGen.FIELD
	var mirror := ProblemGen.make_object("mirror", "mirror", Vector2(650, 250), 110.0, 0.0, 0.6)
	var from := Vector2(f.position.x, 300)
	var dir := Vector2(1, -0.15).normalized()
	var right := RayTracer.trace([mirror], f, from, dir, {})
	var flipped := RayTracer.trace([mirror], f, from, dir, {"mistake": "reflect_axis"})
	var both: bool = right.ok and flipped.ok and right.segments.size() > 1 and flipped.segments.size() > 1
	check("a mirror still bounces under reflect_axis", both)
	if both:
		# taking the mirror line as the axis instead of its normal sends the ray
		# straight back along the true reflection
		var a: Vector2 = (right.segments[1].b - right.segments[1].a).normalized()
		var b: Vector2 = (flipped.segments[1].b - flipped.segments[1].a).normalized()
		check("reflect_axis reverses the bounce", a.dot(b) < -0.99999)
	# and the belief that light comes straight back off a mirror
	var straight_off := RayTracer.trace([mirror], f, from, dir, {"mistake": "normal_bounce"})
	var bounced: bool = straight_off.ok and straight_off.segments.size() > 1
	check("normal_bounce leaves along the normal", bounced)
	if bounced:
		var away: Vector2 = (straight_off.segments[1].b - straight_off.segments[1].a).normalized()
		var face := Vector2.from_angle(0.6)
		check("normal_bounce ignores the incidence angle", absf(away.dot(face)) < 1e-5)

	var slab := ProblemGen.make_object("slab", "soda_glass", Vector2(640, 300), 240.0, 90.0, 0.0)
	var tilt := Vector2(0.5, 1).normalized()
	var top := Vector2(500, f.position.y)
	var ok_trace := RayTracer.trace([slab], f, top, tilt, {})
	var back := RayTracer.trace([slab], f, top, tilt, {"mistake": "bend_back"})
	var swap := RayTracer.trace([slab], f, top, tilt, {"mistake": "snell_swap"})
	var ready: bool = ok_trace.ok and back.ok and swap.ok and ok_trace.segments.size() > 1 \
			and back.segments.size() > 1 and swap.segments.size() > 1
	check("a slab is still crossed under each mistake", ready)
	if ready:
		var n := Vector2(0, -1)
		var good: Vector2 = (ok_trace.segments[1].b - ok_trace.segments[1].a).normalized()
		var wrong: Vector2 = (back.segments[1].b - back.segments[1].a).normalized()
		# same angle to the normal, opposite side of it
		check("bend_back keeps the angle", approx(absf(good.dot(n)), absf(wrong.dot(n)), 1e-5))
		check("bend_back crosses the normal", good.dot(Vector2(1, 0)) * wrong.dot(Vector2(1, 0)) < 0.0)
		var swapped: Vector2 = (swap.segments[1].b - swap.segments[1].a).normalized()
		# glass bends toward the normal, so reading the ratio upside down bends away
		check("snell_swap bends the other way", absf(swapped.dot(n)) < absf(good.dot(n)))
	# a board with no glass cannot express a refraction mistake, so it comes back
	# identical and gets filtered as a duplicate of the answer
	var nothing := RayTracer.trace([mirror], f, from, dir, {"mistake": "bend_back"})
	check("a refraction mistake is a no-op without glass",
			nothing.ok and nothing.exits[0].point.is_equal_approx(right.exits[0].point))


func _test_birefringence() -> void:
	var cal: Dictionary = OpticsMaterials.TRANSPARENT.calcite
	var no: float = cal.n
	var ne: float = cal.ne
	check("e index along the axis is n_o", approx(Optics.extraordinary_index(Vector2.RIGHT, Vector2.RIGHT, no, ne), no, 1e-9))
	check("e index across the axis is n_e", approx(Optics.extraordinary_index(Vector2.UP, Vector2.RIGHT, no, ne), ne, 1e-9))
	check("no walk-off along the axis", Optics.walk_off(Vector2.RIGHT, Vector2.RIGHT, no, ne).is_equal_approx(Vector2.RIGHT))
	check("no walk-off across the axis", Optics.walk_off(Vector2.UP, Vector2.RIGHT, no, ne).dot(Vector2.UP) > 0.99999)
	# calcite peaks near 45 degrees at the 6.2 degrees quoted in the literature
	var k := Vector2.RIGHT.rotated(deg_to_rad(45.0))
	var s := Optics.walk_off(k, Vector2.RIGHT, no, ne)
	check("calcite walk-off is about 6.2 degrees", absf(rad_to_deg(absf(k.angle_to(s))) - 6.24) < 0.05)
	check("a negative crystal leans away from its axis", absf(Vector2.RIGHT.angle_to(s)) > deg_to_rad(45.0))
	# a positive crystal leans the other way
	var rut: Dictionary = OpticsMaterials.TRANSPARENT.rutile
	var sr := Optics.walk_off(Vector2.RIGHT.rotated(deg_to_rad(45.0)), Vector2.RIGHT, rut.n, rut.ne)
	check("a positive crystal leans toward its axis", absf(Vector2.RIGHT.angle_to(sr)) < deg_to_rad(45.0))

	# the classic double image: straight in, two beams out, parallel and offset
	var f := ProblemGen.FIELD
	var slab := ProblemGen.make_object("slab", "calcite", Vector2(640, 300), 240.0, 120.0, 0.0)
	slab.axis = deg_to_rad(45.0)
	var res := RayTracer.trace([slab], f, Vector2(640, f.position.y), Vector2(0, 1), {})
	var two: bool = res.ok and res.exits.size() == 2
	check("a crystal splits one beam into two", two)
	if two:
		check("the two beams leave parallel", res.exits[0].dir.dot(res.exits[1].dir) > 0.99999)
		var gap: float = absf(res.exits[0].point.x - res.exits[1].point.x)
		check("the offset matches the walk-off", absf(gap - 120.0 * tan(deg_to_rad(6.2413))) < 0.6)
		check("the light divides evenly", approx(res.exits[0].intensity, 0.5, 1e-6) and approx(res.exits[1].intensity, 0.5, 1e-6))
		check("one beam is ordinary and one extraordinary", res.exits[0].pol != res.exits[1].pol)

	# once polarized, a beam has only one mode left, so a second crystal cannot
	# split it again
	var a := ProblemGen.make_object("circle", "calcite", Vector2(500, 300), 70.0, 0.0, 0.7)
	var b := ProblemGen.make_object("circle", "calcite", Vector2(800, 300), 70.0, 0.0, 1.9)
	var chain := RayTracer.trace([a, b], f, Vector2(f.position.x, 300), Vector2(1, 0), {})
	check("a second crystal does not split it again", chain.ok and chain.exits.size() <= 2)

	var lit := RayTracer.trace([slab], f, Vector2(600, f.position.y), Vector2(0.15, 1).normalized(), {"fresnel": true, "min_intensity": 1e-4, "max_events": 400})
	var sum := 0.0
	for e in lit.exits:
		sum += e.intensity
	check("energy holds up through a crystal", lit.ok and sum > 0.985 and sum <= 1.0 + 1e-6)

	# Steep internal incidence puts both solutions' wave normals on the incident
	# side while their energies still part company, so the outgoing branch can
	# only be told apart by where the energy goes. The roots are worked out here
	# independently, so the test does not lean on how the solver picks
	var into := Vector2.UP
	var along := Vector2.RIGHT
	var backward := 0
	var handled := 0
	for turn in 72:
		var axis := Vector2.from_angle(TAU * turn / 72.0)
		var a_n := into.dot(axis)
		var a_t := along.dot(axis)
		var inv_e := 1.0 / (ne * ne)
		var g := 1.0 / (no * no) - inv_e
		var n_t := Optics.extraordinary_index(along, axis, no, ne)
		for step in 24:
			var q := n_t * (1.0 + 0.00025 * step)
			var qa := inv_e + g * a_n * a_n
			var qb := 2.0 * q * a_n * a_t * g
			var qc := q * q * (inv_e + g * a_t * a_t) - 1.0
			var disc := qb * qb - 4.0 * qa * qc
			if disc < 0.0:
				continue
			var r := sqrt(disc)
			var k1 := (into * ((-qb + r) / (2.0 * qa)) + along * q).normalized()
			var k2 := (into * ((-qb - r) / (2.0 * qa)) + along * q).normalized()
			if k1.dot(into) >= 0.0 or k2.dot(into) >= 0.0:
				continue
			backward += 1
			var found = Optics.extraordinary_wave(q, into, along, axis, no, ne)
			if found == null:
				continue
			var kk: Vector2 = found
			var tangential: float = Optics.extraordinary_index(kk, axis, no, ne) * kk.dot(along)
			if absf(tangential - q) < 1e-6 and Optics.walk_off(kk, axis, no, ne).dot(into) > 0.0:
				handled += 1
	check("backward wave normals really occur (%d cases)" % backward, backward >= 20)
	check("they are still solved by energy direction", backward > 0 and handled == backward)

	var leaks := 0
	var checked := 0
	for kind in ["prism", "circle", "slab"]:
		for key in ["calcite", "rutile"]:
			for turn in 12:
				for aim in 10:
					var body := ProblemGen.make_object(kind, key, Vector2(640, 320), 90.0 if kind != "slab" else 240.0, 90.0, TAU * turn / 12.0)
					var r := RayTracer.trace([body], f, Vector2(f.position.x, 320), Vector2.from_angle(-PI * 0.4 + PI * 0.8 * aim / 10.0), {})
					if not r.ok:
						continue
					checked += 1
					var got := 0.0
					for e in r.exits:
						got += e.intensity
					if got < 0.98:
						leaks += 1
	check("no beam is dropped inside a crystal (%d traces)" % checked, leaks == 0)


func _test_jones() -> void:
	var un := Jones.unpolarized()
	check("unpolarized carries all the light", approx(Jones.power(un), 1.0, 1e-12))
	check("unpolarized has no preferred plane", approx(Jones.degree(un), 0.0, 1e-12))
	check("a linear state is fully polarized", approx(Jones.degree(Jones.linear(0.4)), 1.0, 1e-6))
	# a rotator only turns the plane, it cannot make or destroy light
	var turned := Jones.apply(Jones.rotator(0.7), Jones.linear(0.4))
	check("a rotator keeps the light", approx(Jones.power(turned), 1.0, 1e-6))
	check("a rotator adds its angle", approx(Jones.share_s(turned), pow(cos(1.1), 2.0), 1e-6))
	check("a rotator leaves unpolarized light alone", approx(Jones.degree(Jones.apply(Jones.rotator(0.9), un)), 0.0, 1e-12))
	# no element may ever produce a state outside the Poincare sphere
	var legal := true
	for k in 24:
		var phase := TAU * k / 24.0
		var m := Jones.diagonal(Vector2(cos(phase), sin(phase)), Vector2(cos(-phase), sin(-phase)))
		var j := Jones.normalized(Jones.apply(m, Jones.linear(PI * 0.25)))
		if Jones.degree(j) > 1.0 + 1e-6 or absf(j[1].x - j[2].x) > 1e-6 or absf(j[1].y + j[2].y) > 1e-6:
			legal = false
	check("a retarder keeps the state physical", legal)
	# total reflection is exactly that, whatever it does to the phase
	var tir := Optics.fresnel_reflection(cos(deg_to_rad(60.0)), 1.6, 1.0)
	check("total reflection keeps unit modulus", approx(tir[0].length(), 1.0, 1e-9) and approx(tir[1].length(), 1.0, 1e-9))
	check("and puts a phase between s and p", absf(tir[0].angle() - tir[1].angle()) > 0.1)
	var straight := Optics.fresnel_reflection(1.0, 1.0, 1.5)
	check("a normal reflection flips only the out of plane field", approx(straight[0].x, -0.2, 1e-6) and approx(straight[1].x, 0.2, 1e-6))
	var perfect := Optics.mirror_reflection(1.0)
	check("a perfect mirror is (-1, +1)", approx(perfect[0].x, -1.0, 1e-9) and approx(perfect[1].x, 1.0, 1e-9))


func _test_polarizer() -> void:
	var f := ProblemGen.FIELD
	var along := Vector2.RIGHT
	var d := Vector2.RIGHT
	# facing the beam head on, the sheet's own angle is the angle in the frame
	var sheet := Vector2.UP
	var open := Optics.polarizer_matrix(0.0, sheet, d)
	check("an axis out of the plane passes the s field", approx(Jones.throughput(open, Jones.linear(0.0)), 1.0, 1e-6))
	check("and stops the p field", approx(Jones.throughput(open, Jones.linear(PI * 0.5)), 0.0, 1e-6))
	var malus := true
	for k in 13:
		var chi := PI * k / 12.0
		var got := Jones.throughput(Optics.polarizer_matrix(chi, sheet, d), Jones.linear(0.0))
		if not approx(got, pow(cos(chi), 2.0), 1e-6):
			malus = false
	check("Malus holds at every angle", malus)
	check("half of unpolarized light gets through", approx(Jones.throughput(Optics.polarizer_matrix(0.6, sheet, d), Jones.unpolarized()), 0.5, 1e-6))

	# two sheets a quarter turn apart, with a glass plate between them so there
	# is something to trace
	var a := ProblemGen.make_object("polarizer", "polarizer", Vector2(450, 300), 90.0, 0.0, PI * 0.5, 0)
	var b := ProblemGen.make_object("polarizer", "polarizer", Vector2(800, 300), 90.0, 0.0, PI * 0.5, 90)
	var one := RayTracer.trace([a], f, Vector2(f.position.x, 300), along, {})
	check("one sheet halves unpolarized light", one.ok and approx(one.exits[0].intensity, 0.5, 1e-6))
	var crossed := RayTracer.trace([a, b], f, Vector2(f.position.x, 300), along, {})
	check("a crossed pair stops it", not crossed.ok or crossed.exits[0].intensity < 0.02)
	var open_pair := ProblemGen.make_object("polarizer", "polarizer", Vector2(800, 300), 90.0, 0.0, PI * 0.5, 0)
	var lined := RayTracer.trace([a, open_pair], f, Vector2(f.position.x, 300), along, {})
	check("a matched pair passes the same half", lined.ok and approx(lined.exits[0].intensity, 0.5, 1e-6))
	# and a third sheet halfway between them opens the crossed pair back up
	var middle := ProblemGen.make_object("polarizer", "polarizer", Vector2(620, 300), 90.0, 0.0, PI * 0.5, 45)
	var three := RayTracer.trace([a, middle, b], f, Vector2(f.position.x, 300), along, {})
	check("a sheet between crossed ones lets light through", three.ok and approx(three.exits[0].intensity, 0.125, 1e-5))
	check("and all three are on that path", three.ok and ProblemGen._path_sheets(three.exits[0].touched, [a, middle, b]) == 3)
	# the sheet must not bend anything, only dim it
	check("a sheet does not deflect the beam", lined.ok and lined.exits[0].dir.dot(along) > 0.99999)
	# looking at the same sheet from behind must not mirror its axis, or light
	# bounced back would no longer fit through what it just came out of
	var mirror := ProblemGen.make_object("mirror", "mirror", Vector2(1000, 300), 90.0, 0.0, PI * 0.5)
	var there_and_back := RayTracer.trace([a, mirror], f, Vector2(f.position.x, 300), along, {})
	check("what a sheet passes comes back through it", there_and_back.ok and approx(there_and_back.exits[0].intensity, 0.5, 1e-6))


func _test_rotation() -> void:
	var f := ProblemGen.FIELD
	var key := "sucrose"
	var rho := OpticsMaterials.rotary(key)
	check("rotation is quoted per mm and used per pixel",
			approx(rho, deg_to_rad(OpticsMaterials.TRANSPARENT[key].rotation) * OpticsMaterials.PX_MM, 1e-12))
	check("both hands are represented", OpticsMaterials.rotary("fructose") < 0.0 and OpticsMaterials.rotary("limonene") > 0.0)
	# a sugar solution between crossed sheets is the polarimetry demo: nothing
	# gets through without it, and the amount that does says how far it turned
	var a := ProblemGen.make_object("polarizer", "polarizer", Vector2(360, 300), 80.0, 0.0, PI * 0.5, 0)
	var tank := ProblemGen.make_object("slab", key, Vector2(640, 300), 260.0, 110.0, 0.0)
	var b := ProblemGen.make_object("polarizer", "polarizer", Vector2(960, 300), 80.0, 0.0, PI * 0.5, 90)
	var from := Vector2(f.position.x, 300)
	var res := RayTracer.trace([a, tank, b], f, from, Vector2.RIGHT, {})
	var lit: bool = res.ok and res.exits[0].intensity > 0.02
	check("a rotator opens a crossed pair", lit)
	if lit:
		# 260 px of it at this concentration, and the sheets take half at the door
		var want: float = 0.5 * pow(sin(rho * 260.0), 2.0)
		check("and by exactly the angle it turned", approx(res.exits[0].intensity, want, 2e-3))
	var without := RayTracer.trace([a, tank, b], f, from, Vector2.RIGHT, {"mistake": "no_rotation"})
	check("ignoring the rotation shuts it again", not without.ok or without.exits[0].intensity < 1e-3)
	# optical activity is reciprocal, so a beam sent back through undoes it
	var back := ProblemGen.make_object("mirror", "mirror", Vector2(1000, 300), 80.0, 0.0, PI * 0.5)
	var round_trip := RayTracer.trace([a, tank, back], f, from, Vector2.RIGHT, {})
	check("a retraced path unwinds the rotation", round_trip.ok and approx(round_trip.exits[0].intensity, 0.5, 2e-3))


func _test_gradient() -> void:
	var f := ProblemGen.FIELD
	var grad := Vector2(0.0, 0.004)
	var n0 := 1.5
	# the closed form against a plain integration of d/ds (n dr/ds) = grad n
	var p := Vector2.ZERO
	var t := Vector2(n0, 0.0)
	var step := 0.002
	for _i in 50000:
		var k1 := t / t.length()
		var t_half := t + grad * (step * 0.5)
		var p_half := p + k1 * (step * 0.5)
		var k2 := t_half / t_half.length()
		p = p + k2 * step
		t = t + grad * step
	var closed := Optics.grin_advance(Vector2.ZERO, Vector2(n0, 0.0), grad, 100.0)
	check("the exact advance matches an integration", (closed.p as Vector2).distance_to(p) < 0.01)
	check("and the optical direction keeps the local index",
			approx((closed.t as Vector2).length(), n0 + grad.y * (closed.p as Vector2).y, 1e-9))
	var straight := Optics.grin_advance(Vector2.ZERO, Vector2(n0, 0.0), Vector2.ZERO, 100.0)
	check("no gradient means no bend", (straight.p as Vector2).distance_to(Vector2(100, 0)) < 1e-6)

	var block := ProblemGen.make_object("gradient", "bk7", Vector2(640, 300), 260.0, 100.0, 0.0,
			GradientBody.byte_from_slope(0.0015))
	var body: GradientBody = block
	check("the block is denser where it says", body.index_at(Vector2(640, 340)) > body.index_at(Vector2(640, 260)))
	var res := RayTracer.trace([block], f, Vector2(f.position.x, 300), Vector2.RIGHT, {})
	var crossed: bool = res.ok and res.exits.size() == 1
	check("a graded block is crossed", crossed)
	if crossed:
		# entering flat, the ray can only leave bent toward the dense side
		check("and the ray bends toward the dense side", res.exits[0].dir.y > 0.02 and res.exits[0].point.y > 305.0)
		check("the path is drawn as a curve", res.segments.size() > 8)
	var flat := RayTracer.trace([block], f, Vector2(f.position.x, 300), Vector2.RIGHT, {"mistake": "flat_gradient"})
	check("taking it as uniform runs straight through", flat.ok and absf(flat.exits[0].point.y - 300.0) < 0.05)
	check("which is somewhere else entirely", flat.ok and crossed and flat.exits[0].point.distance_to(res.exits[0].point) > 20.0)
	var lit := RayTracer.trace([block], f, Vector2(f.position.x, 280.0), Vector2(1, 0.2).normalized(),
			{"fresnel": true, "min_intensity": 1e-4, "max_events": 400})
	var sum := 0.0
	for e in lit.exits:
		sum += e.intensity
	check("energy holds up through a gradient", lit.ok and sum > 0.985 and sum <= 1.0 + 1e-6)
	# a slope the material cannot carry would put the index below air
	var over := {"kind": "gradient", "mat": "water", "x": 640.0, "y": 300.0, "s1": 200.0, "s2": 100.0, "rot": 0.0, "extra": 255}
	check("an impossible slope is refused", not StageCode.size_ok(over))


# which exits only exist because a surface sent part of the light back, as
# opposed to the ones that carried on through
func _test_split_count() -> void:
	var f := ProblemGen.FIELD
	var slab := ProblemGen.make_object("slab", "sf11", Vector2(640, 300), 240.0, 90.0, 0.4)
	var res := RayTracer.trace([slab], f, Vector2(f.position.x, 300), Vector2.RIGHT,
			{"fresnel": true, "min_intensity": 1e-4, "max_events": 400})
	var branched: bool = res.ok and res.exits.size() > 1
	check("a plate with branches on gives more than one exit", branched)
	if branched:
		check("the beam that went through never turned back", res.exits[0].split == 0)
		var bounced := 0
		for e in res.exits:
			if e.split > 0:
				bounced += 1
		check("the dimmer ones did", bounced > 0)
	# a total reflection is not a branch, it is the whole beam turning round
	var prism := ProblemGen.make_object("prism", "diamond", Vector2(640, 300), 90.0, 0.0, 0.3)
	var tir := RayTracer.trace([prism], f, Vector2(f.position.x, 300), Vector2(1, 0.1).normalized(), {})
	var got_tir := false
	for e in tir.exits:
		if e.tir > 0 and e.split == 0:
			got_tir = true
	check("total reflection does not count as a branch", tir.ok and got_tir)


# picking one exit out of a branching trace and getting the beam that reached it,
# which is all the reveal draws unless a crystal made a second answer
func _test_one_path() -> void:
	var f := ProblemGen.FIELD
	var ball := ProblemGen.make_object("circle", "diamond", Vector2(640, 300), 100.0, 0.0, 0.0)
	var src := Vector2(f.position.x, 300.0)
	var res := RayTracer.trace([ball], f, src, Vector2(1, 0.08).normalized(), {"fresnel": true})
	check("a partial reflection leaves more than one exit", res.ok and res.exits.size() > 1)
	var one := RayTracer.legs_to(res, [res.exits[0]])
	check("one exit takes only some of the legs", not one.is_empty() and one.size() < res.segments.size())
	check("which start at the source", (one[0].a as Vector2).distance_to(src) < 0.01)
	var joined := true
	for i in range(1, one.size()):
		# a leg that did not carry on from the one before it would draw as a gap
		if (one[i].a as Vector2).distance_to(one[i - 1].b) > 0.01:
			joined = false
	check("and run end to end", joined)
	check("ending on that exit", (one[one.size() - 1].b as Vector2).is_equal_approx(res.exits[0].point))
	check("asking for every exit gives every leg back", RayTracer.legs_to(res, res.exits).size() == res.segments.size())


# how near a path came to not happening at all, which is what the easier ladder
# refuses to build a problem out of
func _test_clearance() -> void:
	var f := ProblemGen.FIELD
	var opts := {"clear": true}
	var slab := ProblemGen.make_object("slab", "soda_glass", Vector2(640, 300), 240.0, 90.0, 0.0)
	# straight down 5px inside the corner at x=520
	var clipped := RayTracer.trace([slab], f, Vector2(525, f.position.y), Vector2.DOWN, opts)
	check("clipping a corner reads as marginal", clipped.ok and approx(clipped.exits[0].clear, 5.0, 0.5))
	var square := RayTracer.trace([slab], f, Vector2(640, f.position.y), Vector2.DOWN, opts)
	check("going in through the middle does not", square.ok and square.exits[0].clear > 100.0)
	# lands 10px along the top face, but comes in on the corner's bisector, so
	# 7px of aim would have put it on the side face instead
	var slid := RayTracer.trace([slab], f, Vector2(351.0, f.position.y), Vector2(1, 1).normalized(), opts)
	check("a corner met along its bisector reads as marginal",
			slid.ok and (slid.segments[0].b as Vector2).is_equal_approx(Vector2(530, 255)) and slid.exits[0].clear < 8.0)

	var ball := ProblemGen.make_object("circle", "water", Vector2(640, 300), 60.0, 0.0, 0.0)
	var centred := RayTracer.trace([ball], f, Vector2(f.position.x, 300.0), Vector2.RIGHT, opts)
	check("through the middle of a circle does not", centred.ok and approx(centred.exits[0].clear, 60.0, 0.5))
	var grazed := RayTracer.trace([ball], f, Vector2(f.position.x, 243.0), Vector2.RIGHT, opts)
	check("and grazing its rim reads as marginal too", grazed.ok and grazed.exits[0].clear < 12.0)
	check("the first body a beam meets is measured on its own", approx(grazed.exits[0].entry, grazed.exits[0].clear, 0.01))

	# passing by is a separate reading from clipping, and a far more forgiving one
	var skimmed := RayTracer.trace([ball], f, Vector2(f.position.x, 237.0), Vector2.RIGHT, opts)
	check("skimming past a body reads as marginal", skimmed.ok and approx(skimmed.exits[0].near, 3.0, 0.5))
	check("and is not counted as a hit", skimmed.exits[0].clear == INF and skimmed.exits[0].entry == INF)
	# a body the beam leaves is not a body it nearly missed
	var pair := RayTracer.trace([ball, slab], f, Vector2(f.position.x, 300.0), Vector2.RIGHT, opts)
	check("leaving a body does not count against the next leg", pair.ok and pair.exits[0].near > 12.0)
	# and none of this is measured unless it is asked for
	check("clearance is off by default", RayTracer.trace([ball], f, Vector2(f.position.x, 237.0), Vector2.RIGHT, {}).exits[0].near == INF)


func _test_energy() -> void:
	var f := ProblemGen.FIELD
	var c := CircleBody.new(Vector2(640, 360), 80.0, "water")
	var res := RayTracer.trace([c], f, Vector2(f.position.x, 330.0), Vector2(1, 0), {"fresnel": true, "min_intensity": 1e-4, "max_events": 400})
	var sum := 0.0
	for e in res.exits:
		sum += e.intensity
	check("energy conservation", res.ok and sum > 0.985 and sum <= 1.0 + 1e-6)


# a level must offer everything the earlier levels offered
func _test_level_progression() -> void:
	var grows := true
	var valid := true
	for i in Difficulty.LEVELS.size():
		var lv: Dictionary = Difficulty.LEVELS[i]
		for key in ["kinds", "materials", "metals"]:
			if i > 0 and not _covers(lv[key], Difficulty.LEVELS[i - 1][key]):
				grows = false
				print("  %s lost %s from %s" % [Difficulty.label(i), key, Difficulty.label(i - 1)])
		if not _covers(lv.kinds, lv.require_kinds) or not _covers(lv.kinds, lv.get("place_kinds", [])):
			valid = false
		if lv.min_slips > lv.choices - lv.answers or lv.decoy_clear < ProblemGen.MARKER_CLEAR:
			valid = false
		for m in lv.get("require_mistakes", []):
			if not RayTracer.MISTAKES.has(m):
				valid = false
		for m in lv.materials:
			if not OpticsMaterials.TRANSPARENT.has(m):
				valid = false
		for m in lv.metals:
			if not OpticsMaterials.REFLECTIVE.has(m):
				valid = false
	check("levels stay cumulative", grows)
	check("level tables reference real entries", valid)
	# normal mode never asks anyone to read how bright a beam is, so nothing that
	# would put a brightness on screen may reach it
	var unlit := true
	for i in Difficulty.MAIN_COUNT:
		var lv: Dictionary = Difficulty.LEVELS[i]
		if lv.fresnel or lv.answers > 1 or lv.kinds.has("polarizer"):
			unlit = false
		for m: String in lv.materials:
			if OpticsMaterials.is_crystal(m) or OpticsMaterials.is_rotary(m):
				unlit = false
	check("normal mode is never read by brightness", unlit)
	var stable := OpticsMaterials.ORDER.size() == OpticsMaterials.TRANSPARENT.size()
	for key: String in OpticsMaterials.TRANSPARENT:
		if not OpticsMaterials.ORDER.has(key):
			stable = false
	check("ORDER covers every material", stable)
	check("the two choice caps agree", Difficulty.MAX_CHOICES == StageCode.MAX_CHOICES)
	check("the three ladders line up", Difficulty.LEVELS.size() == Difficulty.MAIN_COUNT + Difficulty.HARD_COUNT + Difficulty.EXTRA_COUNT \
			and Difficulty.HARD.size() == Difficulty.HARD_COUNT and Difficulty.EXTRA.size() == Difficulty.EXTRA_COUNT \
			and StageCode.LABELS.length() >= StageCode.MAX_CHOICES)
	var addressed := true
	for i in Difficulty.LEVELS.size():
		var m := Difficulty.mode_of(i)
		var at := i - Difficulty.start_of(m)
		if at < 0 or at >= Difficulty.count_of(m) or not Difficulty.label(i).contains("Lv. %d " % (at + 1)):
			addressed = false
	check("every level knows which ladder it is on", addressed)
	# polarization is meant to be a hard mode surprise
	var plain := true
	for i in Difficulty.MAIN_COUNT:
		var lv: Dictionary = Difficulty.LEVELS[i]
		if lv.answers != 1 or lv.require_crystal:
			plain = false
		for k: String in lv.kinds:
			if k == "polarizer" or k == "gradient":
				plain = false
		for m: String in lv.materials:
			if OpticsMaterials.is_crystal(m) or OpticsMaterials.is_rotary(m):
				plain = false
	check("the main ladder stays clear of polarization", plain)
	# and every element hard mode adds has a level that is about it
	var taught := {}
	for i in range(Difficulty.HARD_START, Difficulty.EXTRA_START):
		var lv: Dictionary = Difficulty.LEVELS[i]
		for k: String in lv.get("place_kinds", []):
			taught[k] = true
		if lv.get("require_split", false):
			taught["crystal"] = true
		if lv.get("place_rotary", 0) > 0:
			taught["rotary"] = true
	check("hard teaches all four of its elements",
			taught.has("polarizer") and taught.has("gradient") and taught.has("crystal") and taught.has("rotary"))
	check("each ladder is its teaching half plus three mixed",
			Difficulty.TEACHING.size() + Difficulty.MAIN_MIXED.size() == Difficulty.MAIN_COUNT \
			and Difficulty.MAIN_MIXED.size() == 3 and Difficulty.HARD.size() == Difficulty.HARD_COUNT)
	# the mixed levels reuse what came before rather than singling anything out
	var mixed_free := true
	for lv: Dictionary in Difficulty.MAIN_MIXED:
		if not lv.get("require_mistakes", []).is_empty() or not lv.require_kinds.is_empty():
			mixed_free = false
	for i in range(Difficulty.EXTRA_START - 3, Difficulty.EXTRA_START):
		if not Difficulty.LEVELS[i].get("require_mistakes", []).is_empty():
			mixed_free = false
	check("the mixed levels single out nothing", mixed_free)
	# and the three of them step up: normal, then hard, then extra
	var steps := [
		Difficulty.LEVELS[Difficulty.MAIN_COUNT - 1].decoy_clear,
		Difficulty.LEVELS[Difficulty.EXTRA_START - 1].decoy_clear,
		Difficulty.LEVELS[Difficulty.EXTRA_START].decoy_clear,
	]
	check("the mixed sets tighten in order", steps[0] > steps[1] and steps[1] >= steps[2])
	var sorted := OpticsMaterials.BY_INDEX.size() == OpticsMaterials.TRANSPARENT.size()
	for i in range(1, OpticsMaterials.BY_INDEX.size()):
		var prev: String = OpticsMaterials.BY_INDEX[i - 1]
		var cur: String = OpticsMaterials.BY_INDEX[i]
		if not OpticsMaterials.TRANSPARENT.has(cur) or OpticsMaterials.TRANSPARENT[prev].n >= OpticsMaterials.TRANSPARENT[cur].n:
			sorted = false
	check("BY_INDEX ordered by n", sorted)


func _covers(outer: Array, inner: Array) -> bool:
	for x in inner:
		if not outer.has(x):
			return false
	return true


func _sample_draft() -> Dictionary:
	return {
		"fresnel": true, "choices": 5, "source_s": 640.0, "source_tilt": 0.35,
		"objects": [
			{"kind": "circle", "mat": "water", "x": 420.0, "y": 300.0, "s1": 60.0, "s2": 0.0, "rot": 0.0, "extra": 0},
			{"kind": "slab", "mat": "bk7", "x": 760.0, "y": 220.0, "s1": 200.0, "s2": 70.0, "rot": 0.6, "extra": 0},
			{"kind": "mirror", "mat": "silver", "x": 560.0, "y": 440.0, "s1": 80.0, "s2": 0.0, "rot": 1.2, "extra": 0},
			{"kind": "prism", "mat": "diamond", "x": 930.0, "y": 460.0, "s1": 80.0, "s2": 0.0, "rot": 2.0, "extra": 0},
			{"kind": "polarizer", "mat": "polarizer", "x": 300.0, "y": 480.0, "s1": 70.0, "s2": 0.0, "rot": 0.3, "extra": 45},
			{"kind": "gradient", "mat": "sf11", "x": 760.0, "y": 380.0, "s1": 180.0, "s2": 60.0, "rot": 0.0, "extra": 160},
		],
	}


func _test_stage_code() -> void:
	check("seed code text", StageCode.from_seed(6, 0x16c0a2fc) == "L7-16c0a2fc")
	var s := StageCode.read("L7-16c0a2fc")
	check("seed code read", not s.has("error") and s.mode == "seed" and s.level == 6 and s.seed == 0x16c0a2fc)

	var draft := _sample_draft()
	var code := StageCode.from_stage(draft)
	var back := StageCode.read(code)
	var same := not back.has("error")
	if not same:
		print("  round trip error: %s" % back.error)
	if same:
		same = back.fresnel == draft.fresnel and back.choices == draft.choices \
				and absf(back.source_s - draft.source_s) < 1.0 and absf(back.source_tilt - draft.source_tilt) < 1e-3 \
				and back.objects.size() == draft.objects.size()
		for i in back.objects.size():
			var a: Dictionary = back.objects[i]
			var b: Dictionary = draft.objects[i]
			if a.kind != b.kind or a.mat != b.mat or absf(a.x - b.x) > 0.5 or absf(a.y - b.y) > 0.5 \
					or absf(a.s1 - b.s1) > 0.5 or absf(a.s2 - b.s2) > 0.5 or absf(a.rot - b.rot) > 1e-3 \
					or int(a.extra) != int(b.extra):
				same = false
	check("custom code round trip", same)
	# re-encoding what was decoded has to give the identical string, otherwise
	# the editor preview and the shared stage could drift apart
	check("custom code is stable", not back.has("error") and StageCode.from_stage(back) == code)

	var rng := RandomNumberGenerator.new()
	rng.seed = code.hash()
	var built: Dictionary = {}
	if not back.has("error"):
		built = ProblemGen.build_custom(StageCode.objects_of(back), StageCode.source_of(back), back.fresnel, back.choices, rng)
	var playable: bool = not built.is_empty() and built.choices.size() == draft.choices
	check("custom stage is playable", playable)
	if playable:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = code.hash()
		var again := ProblemGen.build_custom(StageCode.objects_of(back), StageCode.source_of(back), back.fresnel, back.choices, rng2)
		var identical: bool = again.correct == built.correct
		for i in built.choices.size():
			if not (built.choices[i] as Vector2).is_equal_approx(again.choices[i]):
				identical = false
		check("custom stage same for everyone", identical)

	var bad := ["", "   ", "hello", "L", "L7", "L0-16c0a2fc", "L99-16c0a2fc", "L999999999999-16c0a2fc", "L7-zzzzzzzz", "L7-16c0a2f", "C-", "C-!!!!", "Xanything"]
	var rejected := true
	for text: String in bad:
		if not StageCode.read(text).has("error"):
			rejected = false
			print("  accepted junk: %s" % text)
	check("junk codes rejected", rejected)

	var over := _sample_draft()
	over.objects[1] = over.objects[0].duplicate()
	check("overlapping code rejected", StageCode.read(StageCode.from_stage(over)).has("error"))
	var many := _sample_draft()
	many.objects = []
	for i in StageCode.MAX_OBJECTS + 1:
		many.objects.append({"kind": "circle", "mat": "water", "x": 200.0 + i * 40.0, "y": 300.0, "s1": 40.0, "s2": 0.0, "rot": 0.0})
	check("overlong code rejected", StageCode.read(StageCode.from_stage(many)).has("error"))
	var huge := _sample_draft()
	huge.objects[0].s1 = 9000.0
	check("oversized body rejected", StageCode.read(StageCode.from_stage(huge)).has("error"))
	var outside := _sample_draft()
	outside.objects[0].x = 60000.0
	check("out of field body rejected", StageCode.read(StageCode.from_stage(outside)).has("error"))
	var raw := Marshalls.base64_to_raw(code.substr(2))
	check("truncated code rejected", StageCode.read("C-" + Marshalls.raw_to_base64(raw.slice(0, raw.size() - 3))).has("error"))
	raw[0] = 99
	check("wrong version rejected", StageCode.read("C-" + Marshalls.raw_to_base64(raw)).has("error"))
	check("overlong paste rejected", StageCode.read("C-" + "A".repeat(StageCode.MAX_TEXT + 4)).has("error"))
	_test_snapping()
	_test_seed_to_editor()


# the editor validates snapped records, so snapping has to be a fixed point and
# never move a legal layout into its neighbour
func _test_snapping() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var stable := true
	var encodes := true
	for _i in 400:
		var kind: String = StageCode.KINDS[rng.randi_range(0, StageCode.KINDS.size() - 1)]
		var r: Dictionary = ProblemGen.SIZE_RANGE[kind]
		var mat := "soda_glass"
		if kind == "mirror":
			mat = "mirror"
		elif kind == "polarizer":
			mat = "polarizer"
		var s2: float = rng.randf_range(r.s2[0], r.s2[1]) if r.s2[1] > 0.0 else 0.0
		var extra := 0
		if kind == "polarizer":
			extra = rng.randi_range(0, 179)
		elif kind == "gradient":
			extra = GradientBody.byte_from_slope(rng.randf_range(-1.0, 1.0) * GradientBody.slope_cap(mat, s2))
		var rec := {
			"kind": kind, "mat": mat,
			"x": rng.randf_range(200.0, 1080.0), "y": rng.randf_range(120.0, 530.0),
			"s1": rng.randf_range(r.s1[0], r.s1[1]), "s2": s2,
			"rot": rng.randf_range(-TAU, 2.0 * TAU), "extra": extra,
		}
		var once := StageCode.snap(rec)
		var twice := StageCode.snap(once)
		for key in ["x", "y", "s1", "s2", "rot", "extra"]:
			if absf(float(once[key]) - float(twice[key])) > 1e-9:
				stable = false
		# a snapped record has to survive a code round trip untouched
		var draft := {"fresnel": false, "choices": 3, "source_s": 400.0, "source_tilt": 0.0, "objects": [once]}
		var parsed := StageCode.read(StageCode.from_stage(draft))
		if parsed.has("error"):
			continue
		var got: Dictionary = parsed.objects[0]
		for key in ["x", "y", "s1", "s2", "rot", "extra"]:
			if absf(float(once[key]) - float(got[key])) > 1e-9:
				encodes = false
	check("snapping is a fixed point", stable)
	check("snapped records survive encoding", encodes)
	var perim := 2.0 * (ProblemGen.FIELD.size.x + ProblemGen.FIELD.size.y)
	var wrapped := true
	for k in 200:
		var s := StageCode.snap_source_s(perim - 0.004 * k)
		if s < 0.0 or s >= perim:
			wrapped = false
	check("source position stays in range", wrapped)
	# a corner source tilted hard enough aims back out of the field
	var corner := {"fresnel": false, "choices": 3, "source_s": 0.0, "source_tilt": StageCode.MAX_TILT, "objects": []}
	check("outward source rejected", StageCode.read(StageCode.from_stage(corner)).has("error"))
	_test_overlap()


# bodies should be placeable right up against each other, but never into each other
func _test_overlap() -> void:
	var a := ProblemGen.make_object("circle", "water", Vector2(600, 300), 60.0, 0.0, 0.0)
	var near := ProblemGen.make_object("circle", "water", Vector2(600 + 60 + 60 + 5, 300), 60.0, 0.0, 0.0)
	var touching := ProblemGen.make_object("circle", "water", Vector2(600 + 60 + 60 - 1, 300), 60.0, 0.0, 0.0)
	check("close bodies allowed", ProblemGen.no_overlap(near, [a]))
	check("overlapping bodies refused", not ProblemGen.no_overlap(touching, [a]))
	# a thin mirror used to reserve a circle the length of the whole segment
	var mirror := ProblemGen.make_object("mirror", "mirror", Vector2(600, 200), 120.0, 0.0, 0.0)
	var beside := ProblemGen.make_object("circle", "water", Vector2(600, 200 + 60 + 12), 60.0, 0.0, 0.0)
	check("a body may sit beside a mirror", ProblemGen.no_overlap(beside, [mirror]))
	var across := ProblemGen.make_object("circle", "water", Vector2(660, 200), 60.0, 0.0, 0.0)
	check("a body may not sit on a mirror", not ProblemGen.no_overlap(across, [mirror]))
	# the old bounding circle rule would have refused every one of these
	check("bounding rule was the loose end", not ProblemGen.fits(near, [a]) and not ProblemGen.fits(beside, [mirror]))
	# a wide flat body used to be held a whole bounding radius from the edge
	var flat := ProblemGen.make_object("slab", "soda_glass", Vector2(600, 105), 240.0, 50.0, 0.0)
	check("a flat body reaches the top edge", StageCode.in_field(flat))
	var over := ProblemGen.make_object("slab", "soda_glass", Vector2(600, 100), 240.0, 50.0, 0.0)
	check("a body may not touch the frame", not StageCode.in_field(over))
	var inward := {"fresnel": false, "choices": 3, "source_s": 400.0, "source_tilt": 0.0, "objects": []}
	check("inward source accepted", not StageCode.read(StageCode.from_stage(inward)).has("error"))


# loading a seed into the editor and sharing it must not lose or move anything
func _test_seed_to_editor() -> void:
	var kept := true
	var faithful := true
	for li in Difficulty.LEVELS.size():
		for k in 6:
			var rng := RandomNumberGenerator.new()
			rng.seed = 4000 + li * 100 + k
			var problem := ProblemGen.generate(Difficulty.LEVELS[li], rng)
			if problem.is_empty():
				continue
			var records: Array = StageCode.records_from(problem.objects)
			if records.size() != problem.objects.size():
				kept = false
				continue
			var stage := {
				"fresnel": Difficulty.LEVELS[li].fresnel, "choices": Difficulty.LEVELS[li].choices,
				"source_s": ProblemGen._border_s(problem.source.p),
				"source_tilt": 0.0, "objects": records,
			}
			var parsed := StageCode.read(StageCode.from_stage(stage))
			if parsed.has("error"):
				kept = false
				print("  %s seed %d: %s" % [Difficulty.label(li), 4000 + li * 100 + k, parsed.error])
				continue
			var rebuilt := StageCode.objects_of(parsed)
			for i in rebuilt.size():
				var a: Dictionary = (problem.objects[i] as SceneObj).bounding()
				var b: Dictionary = (rebuilt[i] as SceneObj).bounding()
				if a.center.distance_to(b.center) > 1.5 or absf(a.radius - b.radius) > 1.5:
					faithful = false
	check("seed loads into the editor", kept)
	check("editor keeps the geometry", faithful)


# an element must not turn up before the level that teaches it. Left open, total
# reflection was landing on a third of the boards five levels before its own
func _test_early_no_tir() -> void:
	var leaked := ""
	for li in 7:
		var level: Dictionary = Difficulty.LEVELS[li]
		for k in 8:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7100 + li * 50 + k
			var p := ProblemGen.generate(level, rng)
			if not p.is_empty() and p.trace.exits[0].tir > 0:
				leaked = level.title
	check("nothing before the critical angle level reflects totally", leaked.is_empty())
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7777
	var taught := ProblemGen.generate(Difficulty.LEVELS[7], rng2)
	check("while the level about it still does", not taught.is_empty() and taught.trace.exits[0].tir > 0)


# the web export has no thread to search on, so it searches a slice at a time.
# Being stopped part way must not move a board onto a different seed
func _test_sliced_search() -> void:
	var level: Dictionary = Difficulty.LEVELS[9]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4600
	var whole := ProblemGen.generate(level, rng)
	var search := ProblemSearch.new(level, 4600, 1)
	var slices := 0
	# small enough that a board this slow to find cannot land in one go
	while not search.step(150) and slices < 200000:
		slices += 1
	check("a sliced search finds a board as well", not whole.is_empty() and not search.found.is_empty())
	check("and it really was stopped along the way", slices > 0)
	if whole.is_empty() or search.found.is_empty():
		return
	var same: bool = (search.found.source.p as Vector2).is_equal_approx(whole.source.p) \
			and (search.found.source.d as Vector2).is_equal_approx(whole.source.d) \
			and (search.found.objects as Array).size() == (whole.objects as Array).size() \
			and (search.found.correct as Array) == (whole.correct as Array) \
			and search.seed_used == 4600
	check("and it is the same board the one shot search found", same)


func _test_generation() -> void:
	for li in Difficulty.LEVELS.size():
		var level: Dictionary = Difficulty.LEVELS[li]
		var all_ok := true
		var det_ok := true
		for k in 12:
			var seed_v := 5000 + li * 100 + k
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_v
			# the game rerolls until it has a problem, so that is what gets
			# tested: the player must never be left without one. Ten rather than
			# six because the slowest level needed 1213 layouts on one of these
			# seeds and six only buys 1200, which tested the cap and not the level
			var p := {}
			for _retry in 10:
				p = ProblemGen.generate(level, rng)
				if not p.is_empty():
					break
			if p.is_empty():
				all_ok = false
				continue
			if p.choices.size() != level.choices or p.correct.size() != level.answers:
				all_ok = false
			for a in p.correct.size():
				var at: int = p.correct[a]
				if at < 0 or at >= p.choices.size():
					all_ok = false
					continue
				var matched := false
				for b in level.answers:
					if (p.choices[at] as Vector2).distance_to(p.trace.exits[b].point) < 0.5:
						matched = true
				if not matched:
					all_ok = false
			for a in p.choices.size():
				for b in range(a + 1, p.choices.size()):
					if (p.choices[a] as Vector2).distance_to(p.choices[b]) < ProblemGen.MARKER_CLEAR:
						all_ok = false
			var win: Dictionary = p.trace.exits[0]
			if win.events < level.min_events or RayTracer.count_objects(win.touched) < level.min_objects or win.tir < level.min_tir:
				all_ok = false
			# the easier ladder must never ask a problem that hangs on a hair
			if win.clear < level.get("min_clear", 0.0):
				all_ok = false
			if not ProblemGen._path_has_kinds(win.touched, p.objects, level.require_kinds):
				all_ok = false
			if level.require_crystal and not ProblemGen._path_has_crystal(win.touched, p.objects):
				all_ok = false
			if level.get("require_split", false) and not ProblemGen._split_by_crystal(p.trace.exits, level.answers):
				all_ok = false
			# the level's own element has to be what decides the answer
			for slip: String in level.get("require_mistakes", []):
				var wrong := RayTracer.trace(p.objects, ProblemGen.FIELD, p.source.p, p.source.d,
						{"fresnel": level.fresnel, "min_intensity": 0.02, "max_events": 96, "mistake": slip})
				if not wrong.ok or (wrong.exits[0].point as Vector2).distance_to(win.point) < level.decoy_clear:
					all_ok = false
			# with two answers both have to be beams you can see
			if level.answers > 1 and p.trace.exits[level.answers - 1].intensity < win.intensity * 0.35:
				all_ok = false
			# every body left on the board has to matter to something
			if ProblemGen._path_has_kinds(0, p.objects, []) and p.objects.is_empty():
				all_ok = false
			# decoys must be points the light really reaches under some slip
			var slips: Array = ProblemGen._slip_points(p.objects, p.source, win.touched, level.fresnel)
			for i in range(1, p.trace.exits.size()):
				slips.append(p.trace.exits[i].point)
			var plausible := 0
			for i in p.choices.size():
				if (p.correct as Array).has(i):
					continue
				for s: Vector2 in slips:
					if (p.choices[i] as Vector2).distance_to(s) < 0.5:
						plausible += 1
						break
			if plausible < level.min_slips:
				all_ok = false
			var straight := Isect.ray_rect_exit(p.source.p + p.source.d * 1e-3, p.source.d, ProblemGen.FIELD)
			if straight.is_empty() or (win.point as Vector2).distance_to(straight.point) < level.min_deviation:
				all_ok = false
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = seed_v
			var p2 := {}
			for _retry in 10:
				p2 = ProblemGen.generate(level, rng2)
				if not p2.is_empty():
					break
			if p2.is_empty() or p2.correct != p.correct or not (p2.choices[p2.correct[0]] as Vector2).is_equal_approx(p.choices[p.correct[0]]):
				det_ok = false
		check("generation %s" % Difficulty.label(li), all_ok)
		check("determinism %s" % Difficulty.label(li), det_ok)
