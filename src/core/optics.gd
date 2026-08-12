class_name Optics
## 2D ray optics. Directions and normals must be normalized, and the normal must
## face the incident side (incident.dot(normal) < 0)


static func reflect(incident: Vector2, normal: Vector2) -> Vector2:
	return incident - 2.0 * incident.dot(normal) * normal


## Snell in vector form, null on total internal reflection
static func refract(incident: Vector2, normal: Vector2, n1: float, n2: float) -> Variant:
	var eta := n1 / n2
	var cos_i := clampf(-incident.dot(normal), 0.0, 1.0)
	var sin2_t := eta * eta * (1.0 - cos_i * cos_i)
	if sin2_t > 1.0:
		return null
	var cos_t := sqrt(1.0 - sin2_t)
	return (eta * incident + (eta * cos_i - cos_t) * normal).normalized()


## power reflectance per polarization
static func fresnel_components(cos_i: float, cos_t: float, n1: float, n2: float) -> Dictionary:
	var rs := (n1 * cos_i - n2 * cos_t) / (n1 * cos_i + n2 * cos_t)
	var rp := (n1 * cos_t - n2 * cos_i) / (n1 * cos_t + n2 * cos_i)
	return {"rs": rs * rs, "rp": rp * rp}


## unpolarized reflectance, 1.0 on total reflection
static func reflectance(incident: Vector2, normal: Vector2, n1: float, n2: float) -> float:
	var eta := n1 / n2
	var cos_i := clampf(-incident.dot(normal), 0.0, 1.0)
	var sin2_t := eta * eta * (1.0 - cos_i * cos_i)
	if sin2_t >= 1.0:
		return 1.0
	var cos_t := sqrt(1.0 - sin2_t)
	var f := fresnel_components(cos_i, cos_t, n1, n2)
	return 0.5 * (f.rs + f.rp)


static func critical_angle(n1: float, n2: float) -> float:
	return asin(n2 / n1)


## Signed, and complex past the critical angle. Written for p taken as
## rotate(k, -90 deg), the convention that gives a perfect mirror (-1, +1) and
## so makes it flip the plane of polarization the way a real one does.
## fresnel_components above squares these, so its own sign choice does not matter
static func fresnel_reflection(cos_i: float, n1: float, n2: float) -> Array:
	var ci := clampf(cos_i, 0.0, 1.0)
	var eta := n1 / n2
	var sin2_t := eta * eta * (1.0 - ci * ci)
	if sin2_t <= 1.0:
		var ct := sqrt(1.0 - sin2_t)
		return [
			Vector2((n1 * ci - n2 * ct) / (n1 * ci + n2 * ct), 0.0),
			Vector2((n2 * ci - n1 * ct) / (n2 * ci + n1 * ct), 0.0),
		]
	# the phase these keep between s and p is what turns a linear state elliptical
	var gamma := sqrt(sin2_t - 1.0)
	return [
		Jones.cdiv(Vector2(n1 * ci, -n2 * gamma), Vector2(n1 * ci, n2 * gamma)),
		Jones.cdiv(Vector2(n2 * ci, -n1 * gamma), Vector2(n2 * ci, n1 * gamma)),
	]


## Only the ratio of the two is used: the tracer takes the beam's share of the
## energy from 1 - R, which avoids the cross section factor these would need
static func fresnel_transmission(cos_i: float, cos_t: float, n1: float, n2: float) -> Array:
	var top := 2.0 * n1 * cos_i
	var denom_s := maxf(n1 * cos_i + n2 * cos_t, 1e-12)
	var denom_p := maxf(n2 * cos_i + n1 * cos_t, 1e-12)
	return [Vector2(top / denom_s, 0.0), Vector2(top / denom_p, 0.0)]


## A metal is a perfect conductor scaled by its reflectance, so the out of plane
## field flips and the in plane one does not
static func mirror_reflection(reflectance: float) -> Array:
	var a := sqrt(maxf(reflectance, 0.0))
	return [Vector2(-a, 0.0), Vector2(a, 0.0)]


## I - b b^T with b the blocking axis projected onto the transverse plane, which
## stops being a clean projector at oblique incidence: a sheet seen nearly edge
## on leaks, as a real one does. `phi` is the transmission axis measured inside
## the sheet from out of plane, `sheet` the direction the sheet runs along
static func polarizer_matrix(phi: float, sheet: Vector2, d: Vector2) -> Array:
	var p_hat := Vector2(d.y, -d.x)
	var u := -sin(phi)
	var v := cos(phi) * sheet.dot(p_hat)
	return Jones.symmetric(1.0 - u * u, -u * v, 1.0 - v * v)


## Advance through a linear index field, solving d/ds (n dr/ds) = grad n with
## t = n dr/ds. A constant grad n makes t linear in the path length and its
## length the local index, so the position closes in elementary functions and
## there is no integration error to carry
static func grin_advance(p: Vector2, t: Vector2, grad: Vector2, s: float) -> Dictionary:
	var g := grad.length()
	var n0 := t.length()
	if g < 1e-12 or n0 < 1e-12:
		return {"p": p + t / maxf(n0, 1e-12) * s, "t": t}
	var along := grad / g
	var across := Vector2(-along.y, along.x)
	var tp := t.dot(along)
	var tq := t.dot(across)
	var n1 := Vector2(tp + g * s, tq).length()
	var move := along * ((n1 - n0) / g)
	if absf(tq) > 1e-12:
		move += across * (tq / g) * (asinh((tp + g * s) / absf(tq)) - asinh(tp / absf(tq)))
	return {"p": p + move, "t": t + grad * s}


## `wave` is the wave normal, not the ray
static func extraordinary_index(wave: Vector2, axis: Vector2, n_o: float, n_e: float) -> float:
	var c := clampf(absf(wave.dot(axis)), 0.0, 1.0)
	var s2 := 1.0 - c * c
	return n_o * n_e / sqrt(n_e * n_e * c * c + n_o * n_o * s2)


## In a crystal the ray walks off the wave normal, and it is the ray that decides
## where the light lands
static func walk_off(wave: Vector2, axis: Vector2, n_o: float, n_e: float) -> Vector2:
	var a := axis if axis.dot(wave) >= 0.0 else -axis
	var theta := clampf(a.angle_to(wave), -PI * 0.5 + 1e-9, PI * 0.5 - 1e-9)
	return a.rotated(atan((n_o * n_o) / (n_e * n_e) * tan(theta))).normalized()


## Extraordinary wave normal on the far side of an interface. The index depends
## on the direction being solved for, so this works in wave vector space: the
## locus of n(θ)k is an ellipse, and holding the tangential component at q turns
## it into a quadratic for the normal component.
##
## `into` is the unit normal pointing where the energy has to go. Of the two
## roots exactly one carries energy that way, and it is not always the one whose
## wave normal points that way: at steep internal angles the reflected wave has
## its normal on the incident side, so picking by the wave normal loses that
## branch entirely. Returns null only for total internal reflection
static func extraordinary_wave(q: float, into: Vector2, along: Vector2, axis: Vector2, n_o: float, n_e: float) -> Variant:
	var inv_e := 1.0 / (n_e * n_e)
	var g := 1.0 / (n_o * n_o) - inv_e
	var a_n := into.dot(axis)
	var a_t := along.dot(axis)
	var qa := inv_e + g * a_n * a_n
	var qb := 2.0 * q * a_n * a_t * g
	var qc := q * q * (inv_e + g * a_t * a_t) - 1.0
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return null
	var root := sqrt(disc)
	for p in [(-qb + root) / (2.0 * qa), (-qb - root) / (2.0 * qa)]:
		var k: Vector2 = into * p + along * q
		if k.length() < 1e-12:
			continue
		var kn := k.normalized()
		if walk_off(kn, axis, n_o, n_e).dot(into) > 0.0:
			return kn
	return null
