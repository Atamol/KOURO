class_name PolyBody
extends SceneObj
## Convex polygon body, winding does not matter


var points: PackedVector2Array
var _bcenter: Vector2
var _bradius: float = 0.0


func _init(p_points: PackedVector2Array = PackedVector2Array(), key: String = "soda_glass") -> void:
	points = p_points
	mat_key = key
	if points.size() > 0:
		var c := Vector2.ZERO
		for pt in points:
			c += pt
		_bcenter = c / points.size()
		for pt in points:
			_bradius = maxf(_bradius, _bcenter.distance_to(pt))


func intersect(p: Vector2, d: Vector2) -> Dictionary:
	return Isect.ray_polygon(p, d, points)


func contains(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, points)


func hit(point: Vector2, slack: float) -> bool:
	if Geometry2D.is_point_in_polygon(point, points):
		return true
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) <= slack:
			return true
	return false


func vertices() -> PackedVector2Array:
	return points


func outline(inflate: float) -> PackedVector2Array:
	if inflate <= 0.0:
		return points
	var grown := Geometry2D.offset_polygon(points, inflate)
	return grown[0] if not grown.is_empty() else points


func clone_with(key: String) -> SceneObj:
	var p := PolyBody.new(points, key)
	p.kind = kind
	p.axis = axis
	return p


func bounding() -> Dictionary:
	return {"center": _bcenter, "radius": _bradius}
