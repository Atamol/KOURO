class_name MemoLayer
extends Node2D
## Notes over the board, freehand or straight with Shift. One press to one
## release is one stroke, which is also the unit the right button rubs out and
## the unit undo puts back


const INK := Color(1.0, 0.86, 0.52, 0.92)
const WIDTH := 2.5
## how near the pointer has to pass a stroke to rub it out
const REACH := 10.0

var strokes: Array = []
## every change, newest last. Each is {"kind": "add"/"drop", "items": [[at, stroke]]}
var history: Array = []
var _live := PackedVector2Array()
var _taken: Array = []
var mode := ""


func _ready() -> void:
	z_index = 2


func begin(at: Vector2, erasing: bool, straight: bool = false) -> void:
	mode = "erase" if erasing else ("line" if straight else "draw")
	_live = PackedVector2Array()
	_taken = []
	if erasing:
		rub(at)
	else:
		_live.append(at)
		# the far end, dragged around until the button comes up
		if straight:
			_live.append(at)
		queue_redraw()


func extend(at: Vector2) -> void:
	if mode == "erase":
		rub(at)
		return
	if mode == "line":
		_live[1] = at
		queue_redraw()
		return
	if mode != "draw":
		return
	# jitter of a pixel or two is not worth a point
	if _live.is_empty() or _live[_live.size() - 1].distance_to(at) >= 2.0:
		_live.append(at)
		queue_redraw()


func finish() -> void:
	if (mode == "draw" or mode == "line") and _live.size() > 0:
		strokes.append(_live)
		history.append({"kind": "add", "items": [[strokes.size() - 1, _live]]})
	elif mode == "erase" and not _taken.is_empty():
		_taken.sort_custom(func(x, y): return x[0] < y[0])
		history.append({"kind": "drop", "items": _taken})
	mode = ""
	_live = PackedVector2Array()
	_taken = []
	queue_redraw()


func rub(at: Vector2) -> void:
	for i in range(strokes.size() - 1, -1, -1):
		if _touches(strokes[i], at):
			_taken.append([i, strokes[i]])
			strokes.remove_at(i)
			queue_redraw()


func clear_all() -> void:
	if strokes.is_empty():
		return
	var items: Array = []
	for i in strokes.size():
		items.append([i, strokes[i]])
	history.append({"kind": "drop", "items": items})
	strokes = []
	queue_redraw()


func undo() -> void:
	if history.is_empty():
		return
	var op: Dictionary = history.pop_back()
	if op.kind == "add":
		strokes.remove_at(op.items[0][0])
	else:
		for entry: Array in op.items:
			strokes.insert(mini(entry[0], strokes.size()), entry[1])
	queue_redraw()


func wipe() -> void:
	strokes = []
	history = []
	_live = PackedVector2Array()
	_taken = []
	mode = ""
	queue_redraw()


func busy() -> bool:
	return not mode.is_empty()


func _touches(stroke: PackedVector2Array, at: Vector2) -> bool:
	if stroke.size() == 1:
		return stroke[0].distance_to(at) <= REACH
	for i in range(1, stroke.size()):
		if Geometry2D.get_closest_point_to_segment(at, stroke[i - 1], stroke[i]).distance_to(at) <= REACH:
			return true
	return false


func _draw() -> void:
	var all: Array = strokes.duplicate()
	if _live.size() > 0:
		all.append(_live)
	for stroke: PackedVector2Array in all:
		if stroke.size() == 1:
			draw_circle(stroke[0], WIDTH * 0.7, INK)
		else:
			draw_polyline(stroke, INK, WIDTH, true)
