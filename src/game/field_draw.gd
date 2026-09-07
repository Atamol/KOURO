class_name FieldDraw
## Shared canvas drawing for the play screen and the editor


const LABEL_SIZE := 13
const LABEL_PAD := Vector2(6, 3)
const TEXT_COL := Color(0.78, 0.84, 0.95, 0.85)
const BOX_COL := Color(0.05, 0.065, 0.10, 0.86)
## a sheet has no material to look a colour up from, so it carries its own
const SHEET := {"color": Color(0.72, 0.76, 0.99)}


static func field(ci: CanvasItem) -> void:
	var f := ProblemGen.FIELD
	ci.draw_rect(f.grow(8.0), Color(0.085, 0.105, 0.15), true)
	ci.draw_rect(f, Color(0.045, 0.055, 0.085), true)
	ci.draw_rect(f, Color(0.45, 0.55, 0.75, 0.8), false, 2.0)


## Shapes first, then a labelling pass that can see all of them at once.
## faults maps an index to the reason that body cannot be used
static func bodies(ci: CanvasItem, objects: Array, font: Font, selected := -1, faults := {}) -> void:
	for i in objects.size():
		shape(ci, objects[i], i == selected, faults.has(i))
	_labels(ci, objects, font, faults)
	var warned: Array[Rect2] = []
	for i in faults:
		warned.append(_warn(ci, font, objects[i], str(faults[i]), warned))


static func shape(ci: CanvasItem, obj: SceneObj, highlight := false, bad := false) -> void:
	var col: Color = Color(1.0, 0.32, 0.32) if bad else _info(obj).color
	if obj is MirrorObj:
		ci.draw_line(obj.a, obj.b, col, 5.0, true)
		ci.draw_line(obj.a, obj.b, Color(1, 1, 1, 0.6), 1.5, true)
	elif obj is PolarizerObj:
		_sheet(ci, obj, col)
	elif obj is GradientBody:
		_graded(ci, obj, col)
	elif obj is CircleBody:
		ci.draw_circle(obj.center, obj.radius, Color(col, 0.16))
		ci.draw_circle(obj.center, obj.radius, Color(col, 0.9), false, 2.0, true)
	elif obj is PolyBody:
		ci.draw_colored_polygon(obj.points, Color(col, 0.16))
		ci.draw_polyline(_closed(obj.points), Color(col, 0.9), 2.0, true)
	# the split depends on where the optic axis points, so it has to be visible
	if OpticsMaterials.is_crystal(obj.mat_key):
		var b: Dictionary = obj.bounding()
		var reach: Vector2 = Vector2.from_angle(obj.axis) * b.radius * 0.82
		ci.draw_dashed_line(b.center - reach, b.center + reach, Color(col, 0.85), 1.5, 7.0, true, true)
	if bad:
		_outline(ci, obj, Color(1.0, 0.35, 0.35, 0.95))
	if highlight:
		_outline(ci, obj, Color(1, 1, 1, 0.95))


static func source(ci: CanvasItem, p: Vector2, d: Vector2, hint_len: float) -> void:
	var perp := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([p + d * 16.0, p - d * 6.0 + perp * 9.0, p - d * 6.0 - perp * 9.0])
	ci.draw_colored_polygon(pts, Glow.hot(Color(0.55, 1.0, 0.65)))
	if hint_len > 18.0:
		ci.draw_line(p + d * 16.0, p + d * hint_len, Glow.hot(Color(0.55, 1.0, 0.65, 0.5), 0.5), 2.0, true)


## Every stretch of beam goes through here, or the piece the player is given, the
## answer path and the tutorial figures drift apart. `lit` drops below 1 only in
## the tutorial, where the share a beam carries is the lesson
static func beam(ci: CanvasItem, a: Vector2, b: Vector2, lit := 1.0, scale := 1.0) -> void:
	var col := Color(0.45, 1.00, 0.55, clampf(0.3 + 0.7 * lit, 0.0, 1.0))
	ci.draw_line(a, b, Glow.hot(col, lit), (1.6 + 2.4 * sqrt(lit)) / scale, true)


## Ticks lie along the bar when the axis is in the plane of the board and across
## it when the axis points out. That leaves nothing to see at 90 degrees, so the
## middle carries a dial too, read in screen terms: upright is out of the board
static func _sheet(ci: CanvasItem, obj: PolarizerObj, col: Color) -> void:
	var dir := obj.direction()
	ci.draw_line(obj.a, obj.b, Color(col, 0.75), 4.0, true)
	var tick := dir.rotated(PI * 0.5 - obj.phi)
	var steps := maxi(int(obj.a.distance_to(obj.b) / 15.0), 2)
	for i in range(1, steps):
		var at := obj.a.lerp(obj.b, float(i) / steps)
		ci.draw_line(at - tick * 7.0, at + tick * 7.0, Color(col, 0.85), 1.5, true)
	var mid := (obj.a + obj.b) * 0.5
	var axis := Vector2(sin(obj.phi), -cos(obj.phi))
	ci.draw_circle(mid, 9.0, Color(0.05, 0.065, 0.10, 0.95))
	ci.draw_circle(mid, 9.0, Color(col, 0.85), false, 1.5, true)
	ci.draw_line(mid - axis * 6.5, mid + axis * 6.5, Color(col, 1.0), 2.0, true)


## Brightest on the dense side, so which way the ray bends can be read off it
static func _graded(ci: CanvasItem, obj: GradientBody, col: Color) -> void:
	ci.draw_colored_polygon(obj.points, Color(col, 0.10))
	var down := Vector2.DOWN.rotated(obj.rot)
	var across := Vector2(-down.y, down.x)
	var reach: float = (obj.points[1] - obj.points[0]).length() * 0.5
	var thick := obj.thickness()
	for i in 7:
		var f := (i + 0.5) / 7.0 - 0.5
		var mid: Vector2 = obj.centre + down * (f * thick)
		ci.draw_line(mid - across * reach, mid + across * reach, Color(col, 0.10 + 0.42 * (0.5 + f * signf(obj.slope))), 2.0)
	ci.draw_polyline(_closed(obj.points), Color(col, 0.9), 2.0, true)


static func _info(obj: SceneObj) -> Dictionary:
	if obj.is_polarizer():
		return SHEET
	return OpticsMaterials.REFLECTIVE[obj.mat_key] if obj.is_reflector() else OpticsMaterials.TRANSPARENT[obj.mat_key]


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	out.append(points[0])
	return out


static func _outline(ci: CanvasItem, obj: SceneObj, col: Color) -> void:
	if obj is MirrorObj or obj is PolarizerObj:
		ci.draw_line(obj.a, obj.b, col, 3.0, true)
	elif obj is CircleBody:
		ci.draw_circle(obj.center, obj.radius, col, false, 3.0, true)
	elif obj is PolyBody:
		ci.draw_polyline(_closed(obj.points), col, 3.0, true)


static func _text_of(obj: SceneObj) -> String:
	var info := _info(obj)
	var name := Lang.t("shape.polarizer") if obj.is_polarizer() else OpticsMaterials.label_of(obj.mat_key)
	if obj is PolarizerObj:
		return "%s φ=%d°" % [name, roundi(rad_to_deg((obj as PolarizerObj).phi))]
	if obj.is_reflector():
		return name
	if obj is GradientBody:
		return "%s n=%.3f±%.3f" % [name, info.n, (obj as GradientBody).swing()]
	if info.has("ne"):
		return "%s no=%.3f ne=%.3f" % [name, info.n, info.ne]
	if info.has("rotation"):
		return "%s n=%.3f %s %+.2f°/mm" % [name, info.n, Lang.t("draw.rotation"), info.rotation]
	return "%s n=%.3f" % [name, info.n]


## Two bodies on top of each other would print their warnings in the same place,
## so each one drops below the last
static func _warn(ci: CanvasItem, font: Font, obj: SceneObj, text: String, taken: Array[Rect2]) -> Rect2:
	var dim := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
	var rect := _rect_at(obj.bounding().center, dim)
	for _step in taken.size():
		var clear := true
		for other in taken:
			if rect.grow(3.0).intersects(other):
				clear = false
				break
		if clear:
			break
		rect.position.y += dim.y + 10.0
	ci.draw_rect(rect.grow_individual(LABEL_PAD.x, LABEL_PAD.y, LABEL_PAD.x, LABEL_PAD.y), Color(0.22, 0.05, 0.06, 0.92), true)
	ci.draw_string(font, rect.position + Vector2(0.0, font.get_ascent(LABEL_SIZE)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(1.0, 0.72, 0.72))
	return rect


## Bodies can sit close enough for their labels to land on a neighbour, so one
## that would be unreadable where it belongs either moves inside its own body or
## steps aside with a box and a leader line
static func _labels(ci: CanvasItem, objects: Array, font: Font, faults := {}) -> void:
	var shapes: Array = []
	for obj: SceneObj in objects:
		shapes.append(obj.outline(0.0))
	var taken: Array[Rect2] = []
	for i in objects.size():
		if faults.has(i):
			continue
		var obj: SceneObj = objects[i]
		var text := _text_of(obj)
		var dim := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
		var b: Dictionary = obj.bounding()
		var home := _rect_at(b.center + Vector2(0.0, b.radius + 8.0 + dim.y * 0.5), dim)
		if _is_free(home, shapes, i, taken):
			_write(ci, font, text, home)
			taken.append(home)
			continue
		if b.radius >= dim.x * 0.5 + 8.0:
			var inside := _rect_at(b.center, dim)
			_box(ci, inside)
			_write(ci, font, text, inside)
			taken.append(inside)
			continue
		var spot := _step_aside(b, dim, shapes, i, taken)
		ci.draw_line(b.center + (spot.get_center() - b.center).normalized() * b.radius, spot.get_center(), Color(0.6, 0.7, 0.85, 0.55), 1.0, true)
		_box(ci, spot)
		_write(ci, font, text, spot)
		taken.append(spot)


static func _rect_at(center: Vector2, dim: Vector2) -> Rect2:
	return Rect2(center - dim * 0.5, dim)


static func _step_aside(b: Dictionary, dim: Vector2, shapes: Array, skip: int, taken: Array[Rect2]) -> Rect2:
	var reach: float = b.radius + 8.0 + maxf(dim.x, dim.y) * 0.5
	var fallback := _rect_at(b.center + Vector2(0.0, -reach), dim)
	for ring in [1.0, 1.5, 2.1]:
		for k in 8:
			var dir := Vector2.from_angle(-PI * 0.5 + TAU * k / 8.0)
			var spot := _rect_at(b.center + dir * reach * ring, dim)
			if _is_free(spot, shapes, skip, taken):
				return spot
	return fallback


static func _is_free(rect: Rect2, shapes: Array, skip: int, taken: Array[Rect2]) -> bool:
	if not ProblemGen.FIELD.grow(6.0).encloses(rect):
		return false
	for other in taken:
		if rect.grow(3.0).intersects(other):
			return false
	var poly := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for i in shapes.size():
		if i == skip:
			continue
		if not Geometry2D.intersect_polygons(poly, shapes[i]).is_empty():
			return false
	return true


static func _box(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect.grow_individual(LABEL_PAD.x, LABEL_PAD.y, LABEL_PAD.x, LABEL_PAD.y), BOX_COL, true)


static func _write(ci: CanvasItem, font: Font, text: String, rect: Rect2) -> void:
	ci.draw_string(font, rect.position + Vector2(0.0, font.get_ascent(LABEL_SIZE)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, TEXT_COL)
