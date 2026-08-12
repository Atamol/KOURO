class_name BeamLayer
extends Node2D
## Additive pass so overlapping branches build up light


var segments: Array = []
var exits: Array = []
var reveal_t := 0.0


func _init() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func show_path(p_segments: Array, p_exits: Array) -> void:
	segments = p_segments
	exits = p_exits
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
		var i: float = seg.intensity
		var glow := Color(0.30, 0.90, 0.45, 0.10 + 0.20 * i)
		var core := Color(0.45, 1.00, 0.55, clampf(0.25 + 0.75 * i, 0.0, 1.0))
		draw_line(seg.a, b, glow, 7.0 + 6.0 * sqrt(i), true)
		draw_line(seg.a, b, core, 1.5 + 2.5 * sqrt(i), true)
	for e in exits:
		if e.time <= reveal_t:
			draw_circle(e.point, 5.0 + 7.0 * sqrt(e.intensity), Color(0.5, 1.0, 0.6, 0.35 + 0.4 * e.intensity))
