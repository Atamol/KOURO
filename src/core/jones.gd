class_name Jones
## Polarization as a coherency matrix <E E*> rather than a Jones vector, because
## unpolarized light is not a field. Four complex numbers, row major, each a
## Vector2 of (real, imaginary), in the ray's own frame with s out of the board
## and p = rotate(d, -90 deg)


const ZERO := Vector2.ZERO


static func cmul(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x)


static func cdiv(a: Vector2, b: Vector2) -> Vector2:
	var d := b.x * b.x + b.y * b.y
	if d < 1e-300:
		return ZERO
	return Vector2((a.x * b.x + a.y * b.y) / d, (a.y * b.x - a.x * b.y) / d)


static func conj(a: Vector2) -> Vector2:
	return Vector2(a.x, -a.y)


static func matmul(m: Array, n: Array) -> Array:
	return [
		cmul(m[0], n[0]) + cmul(m[1], n[2]), cmul(m[0], n[1]) + cmul(m[1], n[3]),
		cmul(m[2], n[0]) + cmul(m[3], n[2]), cmul(m[2], n[1]) + cmul(m[3], n[3]),
	]


static func dagger(m: Array) -> Array:
	return [conj(m[0]), conj(m[2]), conj(m[1]), conj(m[3])]


static func apply(m: Array, j: Array) -> Array:
	return matmul(matmul(m, j), dagger(m))


static func power(j: Array) -> float:
	return j[0].x + j[3].x


static func normalized(j: Array) -> Array:
	var p := power(j)
	if p <= 1e-300:
		return unpolarized()
	return [j[0] / p, j[1] / p, j[2] / p, j[3] / p]


static func unpolarized() -> Array:
	return [Vector2(0.5, 0.0), ZERO, ZERO, Vector2(0.5, 0.0)]


## chi is measured from s
static func linear(chi: float) -> Array:
	var c := cos(chi)
	var s := sin(chi)
	return [Vector2(c * c, 0.0), Vector2(c * s, 0.0), Vector2(c * s, 0.0), Vector2(s * s, 0.0)]


static func pure(mode: String) -> Array:
	return linear(0.0) if mode == "s" else linear(PI * 0.5)


static func diagonal(a: Vector2, b: Vector2) -> Array:
	return [a, ZERO, ZERO, b]


static func symmetric(a: float, b: float, c: float) -> Array:
	return [Vector2(a, 0.0), Vector2(b, 0.0), Vector2(b, 0.0), Vector2(c, 0.0)]


static func rotator(angle: float) -> Array:
	var c := Vector2(cos(angle), 0.0)
	var s := Vector2(sin(angle), 0.0)
	return [c, -s, s, c]


static func share_s(j: Array) -> float:
	var p := power(j)
	return 0.0 if p <= 1e-300 else clampf(j[0].x / p, 0.0, 1.0)


static func throughput(m: Array, j: Array) -> float:
	var p := power(j)
	return 0.0 if p <= 1e-300 else clampf(power(apply(m, j)) / p, 0.0, 1.0)


## 0 unpolarized, 1 pure. Only the tests use it, to check that no element ever
## produces a state outside the Poincare sphere
static func degree(j: Array) -> float:
	var p := power(j)
	if p <= 1e-300:
		return 0.0
	var s1: float = (j[0].x - j[3].x) / p
	var s2: float = 2.0 * j[1].x / p
	var s3: float = -2.0 * j[1].y / p
	return sqrt(s1 * s1 + s2 * s2 + s3 * s3)
