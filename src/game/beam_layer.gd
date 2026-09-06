class_name BeamLayer
extends Node2D
## Additive pass so overlapping branches build up light


var segments: Array = []
var exits: Array = []
var reveal_t := 0.0
## whether the board is one whose answer turns on how much light got where. Only
## the exit marks carry it: along the path every leg is drawn the same, or a beam
## reads as several
var reads_light := false


func _init() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _ready() -> void:
	add_child(Glow.env())


func show_path(p_segments: Array, p_exits: Array, p_reads_light := false) -> void:
	segments = p_segments
	exits = p_exits
	reads_light = p_reads_light
	reveal_t = 0.0
	queue_redraw()


func set_reveal(t: float) -> void:
	reveal_t = t
	queue_redraw()


func clear_path() -> void:
	segments = []
	exits = []
	reveal_t = 0.0
	queue_redraw()


func _draw() -> void:
	for seg in segments:
		if seg.t0 > reveal_t:
			continue
		var frac: float = 1.0 if seg.t1 <= reveal_t else (reveal_t - seg.t0) / (seg.t1 - seg.t0)
		var b: Vector2 = seg.a.lerp(seg.b, frac)
		FieldDraw.beam(self, seg.a, b)
	for e in exits:
		if e.time <= reveal_t:
			var lit: float = e.intensity if reads_light else 1.0
			var spot := Color(0.5, 1.0, 0.6, 0.35 + 0.4 * lit)
			draw_circle(e.point, 3.5 + 4.5 * sqrt(lit), Glow.hot(spot, lit))
