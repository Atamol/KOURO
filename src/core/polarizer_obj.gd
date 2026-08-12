class_name PolarizerObj
extends SceneObj
## A polarizing sheet seen edge on. It stands perpendicular to the board, so its
## plane holds both the out of plane direction and the segment it is drawn as,
## and `phi` is the transmission axis inside that plane measured from out of
## plane: 0 passes s, 90 degrees passes p


var a: Vector2
var b: Vector2
var phi: float = 0.0


func _init(p_a: Vector2 = Vector2.ZERO, p_b: Vector2 = Vector2.ZERO, p_phi: float = 0.0) -> void:
	a = p_a
	b = p_b
	phi = p_phi
	mat_key = "polarizer"
	kind = "polarizer"


## degrees, which is how a stage code carries the axis
static func phi_from_byte(raw: int) -> float:
	return deg_to_rad(float(posmod(raw, 180)))


static func byte_from_phi(angle: float) -> int:
	return posmod(int(round(rad_to_deg(angle))), 180)


func is_polarizer() -> bool:
	return true


func direction() -> Vector2:
	var d := b - a
	return d.normalized() if d.length() > 1e-9 else Vector2.RIGHT


func intersect(p: Vector2, d: Vector2) -> Dictionary:
	return Isect.ray_segment(p, d, a, b)


func hit(point: Vector2, slack: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) <= slack + 4.0


func vertices() -> PackedVector2Array:
	return PackedVector2Array([a, b])


func outline(inflate: float) -> PackedVector2Array:
	var dir := direction()
	var side := Vector2(-dir.y, dir.x) * (3.0 + inflate)
	var cap := dir * inflate
	return PackedVector2Array([a - cap + side, b + cap + side, b + cap - side, a - cap - side])


## a sheet has no index, so a swapped material means nothing here
func clone_with(_key: String) -> SceneObj:
	var p := PolarizerObj.new(a, b, phi)
	p.axis = axis
	return p


func bounding() -> Dictionary:
	return {"center": (a + b) * 0.5, "radius": a.distance_to(b) * 0.5}
