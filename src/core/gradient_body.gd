class_name GradientBody
extends PolyBody
## A rectangular block whose index climbs along its own down direction, so a ray
## inside follows a curve. `slope` carries the sign


## what one step of the stored byte is worth, with 128 a uniform block. The ends
## of the range are about what a real gradient index glass reaches
const STEP := 0.0001
## the block has to stay denser than air everywhere, with room to spare
const MIN_INDEX := 1.02

var centre: Vector2
var rot: float = 0.0
## dn per pixel along the block's local down, signed
var slope: float = 0.0


func _init(p_points: PackedVector2Array = PackedVector2Array(), key: String = "bk7",
		p_centre: Vector2 = Vector2.ZERO, p_rot: float = 0.0, p_slope: float = 0.0) -> void:
	super(p_points, key)
	centre = p_centre
	rot = p_rot
	slope = p_slope
	kind = "gradient"
	axis = p_rot


static func slope_from_byte(raw: int) -> float:
	return float(clampi(raw, 0, 255) - 128) * STEP


static func byte_from_slope(g: float) -> int:
	return clampi(int(round(g / STEP)) + 128, 0, 255)


## Widest slope a block of this material and thickness can carry without its
## thin side turning into something rarer than air
static func slope_cap(key: String, thickness: float) -> float:
	if not OpticsMaterials.TRANSPARENT.has(key) or thickness <= 0.0:
		return 0.0
	return maxf(OpticsMaterials.TRANSPARENT[key].n - MIN_INDEX, 0.0) / (thickness * 0.5)


func base_index() -> float:
	return OpticsMaterials.TRANSPARENT[mat_key].n


func dense() -> Vector2:
	return Vector2.DOWN.rotated(rot) * signf(slope)


func gradient() -> Vector2:
	return Vector2.DOWN.rotated(rot) * slope


func index_at(point: Vector2) -> float:
	return base_index() + (point - centre).dot(Vector2.DOWN.rotated(rot)) * slope


func thickness() -> float:
	var down := Vector2.DOWN.rotated(rot)
	var reach := 0.0
	for p in points:
		reach = maxf(reach, absf((p - centre).dot(down)))
	return reach * 2.0


## half the swing between the two faces, which is what the label shows
func swing() -> float:
	return thickness() * 0.5 * absf(slope)


## A swapped material can be too rare for the same slope, and a block reaching
## below the index of air would put the ray equation off its rails
func clone_with(key: String) -> SceneObj:
	var cap := slope_cap(key, thickness())
	var g := GradientBody.new(points, key, centre, rot, clampf(slope, -cap, cap))
	g.kind = kind
	g.axis = axis
	return g
