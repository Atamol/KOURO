class_name Isect
## Ray intersection helpers. Normals are flipped to face the incoming ray, and
## `margin` says how far the ray would have to slide sideways for the hit to
## come out differently: past the nearer end of the face for a flat one, out
## through the rim for a circle


const EPS := 1e-6


static func ray_segment(p: Vector2, d: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var ab := b - a
	var denom := d.cross(ab)
	if absf(denom) < EPS:
		return {}
	var ap := a - p
	var t := ap.cross(ab) / denom
	var s := ap.cross(d) / denom
	if t <= EPS or s < 0.0 or s > 1.0:
		return {}
	var normal := Vector2(-ab.y, ab.x).normalized()
	if normal.dot(d) > 0.0:
		normal = -normal
	# perpendicular to the ray, not along the face: a beam that comes in almost
	# along a corner's bisector lands well down the face and still passes within
	# a pixel or two of the vertex, which is where the other face takes over
	return {"t": t, "point": p + d * t, "normal": normal, "margin": minf(s, 1.0 - s) * absf(denom)}


static func ray_circle(p: Vector2, d: Vector2, c: Vector2, r: float) -> Dictionary:
	var oc := p - c
	var b := oc.dot(d)
	var q := oc.dot(oc) - r * r
	var disc := b * b - q
	if disc < 0.0:
		return {}
	var sq := sqrt(disc)
	var t := -b - sq
	if t <= EPS:
		t = -b + sq
	if t <= EPS:
		return {}
	var point := p + d * t
	var normal := (point - c) / r
	if normal.dot(d) > 0.0:
		normal = -normal
	return {"t": t, "point": point, "normal": normal, "margin": r - sqrt(maxf(r * r - disc, 0.0))}


static func ray_polygon(p: Vector2, d: Vector2, points: PackedVector2Array) -> Dictionary:
	var best := {}
	for i in points.size():
		var h := ray_segment(p, d, points[i], points[(i + 1) % points.size()])
		if h and (best.is_empty() or h.t < best.t):
			best = h
	return best


## nearest border crossing seen from inside the rect
static func ray_rect_exit(p: Vector2, d: Vector2, rect: Rect2) -> Dictionary:
	var tl := rect.position
	var tr := rect.position + Vector2(rect.size.x, 0.0)
	var br := rect.position + rect.size
	var bl := rect.position + Vector2(0.0, rect.size.y)
	var best := {}
	for side in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		var h := ray_segment(p, d, side[0], side[1])
		if h and (best.is_empty() or h.t < best.t):
			best = h
	return best
