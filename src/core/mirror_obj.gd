class_name MirrorObj
extends SceneObj


var a: Vector2
var b: Vector2


func _init(p_a: Vector2 = Vector2.ZERO, p_b: Vector2 = Vector2.ZERO, key: String = "mirror") -> void:
	a = p_a
	b = p_b
	mat_key = key


func intersect(p: Vector2, d: Vector2) -> Dictionary:
	return Isect.ray_segment(p, d, a, b)


func is_reflector() -> bool:
	return true


func bounding() -> Dictionary:
	return {"center": (a + b) * 0.5, "radius": a.distance_to(b) * 0.5}


func hit(point: Vector2, slack: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) <= slack + 4.0


func vertices() -> PackedVector2Array:
	return PackedVector2Array([a, b])


func outline(inflate: float) -> PackedVector2Array:
	var dir := (b - a).normalized()
	# matches the 5 px the mirror is drawn with
	var side := Vector2(-dir.y, dir.x) * (2.5 + inflate)
	var cap := dir * inflate
	return PackedVector2Array([a - cap + side, b + cap + side, b + cap - side, a - cap - side])


## a metal has no refractive index, so a swapped material means nothing here
func clone_with(_key: String) -> SceneObj:
	var m := MirrorObj.new(a, b, mat_key)
	m.kind = kind
	m.axis = axis
	return m
