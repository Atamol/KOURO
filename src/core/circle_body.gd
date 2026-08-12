class_name CircleBody
extends SceneObj


var center: Vector2
var radius: float


func _init(p_center: Vector2 = Vector2.ZERO, p_radius: float = 1.0, key: String = "water") -> void:
	center = p_center
	radius = p_radius
	mat_key = key


func intersect(p: Vector2, d: Vector2) -> Dictionary:
	return Isect.ray_circle(p, d, center, radius)


func contains(point: Vector2) -> bool:
	return point.distance_to(center) <= radius


func hit(point: Vector2, slack: float) -> bool:
	return point.distance_to(center) <= radius + slack


func outline(inflate: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# circumscribed, so the polygon never sits inside the real circle
	var r := (radius + inflate) / cos(PI / 24.0)
	for i in 24:
		pts.append(center + Vector2.from_angle(TAU * i / 24.0) * r)
	return pts


func clone_with(key: String) -> SceneObj:
	var c := CircleBody.new(center, radius, key)
	c.kind = kind
	c.axis = axis
	return c


func bounding() -> Dictionary:
	return {"center": center, "radius": radius}
