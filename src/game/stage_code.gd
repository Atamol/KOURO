class_name StageCode
## Shareable text for a stage. Two forms, both accepted by read():
##   L7-16c0a2fc   a generated problem, replayed from its level and seed
##   C-<base64>    a hand built layout, packed field by field
## Codes come from other people, so read() validates every field and rejects
## anything the tracer could not handle


## 2 added the hand placed decoy block, 3 a spare byte per object. Older codes
## still read, they have neither
const VERSION := 3
const MAX_DECOYS := MAX_CHOICES - 1
## append only, a kind number is what a shared code carries
const KINDS := ["mirror", "slab", "circle", "prism", "polarizer", "gradient"]
const MAX_OBJECTS := 12
const MIN_CHOICES := 3
const MAX_CHOICES := 8
const LABELS := "ABCDEFGH"
# the widest inward tilt a source may have, past this it skims the border
const MAX_TILT := deg_to_rad(80.0)
# a paste far bigger than any real code is not worth parsing
const MAX_TEXT := 8192
# version, flags, choices, source_s, tilt, count
const HEADER_BYTES := 8
# kind, material, x, y, s1, s2, rotation, and from version 3 the spare byte
const OBJECT_BYTES := 12
const OBJECT_BYTES_V3 := 13


static func object_bytes(version: int) -> int:
	return OBJECT_BYTES_V3 if version >= 3 else OBJECT_BYTES


static func from_seed(level_index: int, seed_value: int) -> String:
	return "L%d-%08x" % [level_index + 1, seed_value & 0xffffffff]


## The code holds whole pixels and a u16 angle. Callers snap through here before
## validating, so a layout the editor accepts always survives encoding
static func snap(rec: Dictionary) -> Dictionary:
	var out := rec.duplicate()
	out.x = float(int(round(rec.x)))
	out.y = float(int(round(rec.y)))
	out.s1 = float(int(round(rec.s1)))
	out.s2 = float(int(round(rec.s2)))
	out.rot = _u16_to_angle(_angle_to_u16(rec.rot))
	out.extra = clampi(int(rec.get("extra", 0)), 0, 255)
	return out


static func snap_source_s(s: float) -> float:
	var perim: float = 2.0 * (ProblemGen.FIELD.size.x + ProblemGen.FIELD.size.y)
	return fposmod(float(int(round(fposmod(s, perim)))), perim)


static func snap_tilt(tilt: float) -> float:
	return _u16_to_tilt(_tilt_to_u16(tilt))


static func from_stage(stage: Dictionary) -> String:
	var decoys: Array = stage.get("decoys", [])
	var manual: bool = stage.get("manual", false)
	var buf := StreamPeerBuffer.new()
	buf.put_u8(VERSION)
	buf.put_u8((1 if stage.fresnel else 0) | (2 if manual else 0))
	buf.put_u8(stage.choices)
	buf.put_u16(int(snap_source_s(stage.source_s)))
	buf.put_u16(_tilt_to_u16(stage.source_tilt))
	buf.put_u8(stage.objects.size())
	for raw: Dictionary in stage.objects:
		var rec := snap(raw)
		buf.put_u8(KINDS.find(rec.kind))
		buf.put_u8(_mat_to_index(rec.kind, rec.mat))
		buf.put_u16(int(rec.x))
		buf.put_u16(int(rec.y))
		buf.put_u16(int(rec.s1))
		buf.put_u16(int(rec.s2))
		buf.put_u16(_angle_to_u16(rec.rot))
		buf.put_u8(int(rec.extra))
	buf.put_u8(decoys.size())
	for s in decoys:
		buf.put_u16(int(snap_source_s(s)))
	return "C-" + Marshalls.raw_to_base64(buf.data_array)


## Returns {"mode": "seed", "level":, "seed":} or {"mode": "custom", ...},
## or {"error": "<reason shown to the player>"}
static func read(text: String) -> Dictionary:
	if text.length() > MAX_TEXT:
		return {"error": Lang.t("code.too_long")}
	var code := text.strip_edges()
	if code.begins_with("L") or code.begins_with("l"):
		return _read_seed(code)
	if code.begins_with("C-") or code.begins_with("c-"):
		return _read_custom(code.substr(2))
	return {"error": Lang.t("code.bad_form")}


static func _read_seed(code: String) -> Dictionary:
	var parts := code.substr(1).split("-")
	if parts.size() != 2:
		return {"error": Lang.t("code.bad_form")}
	# to_int() on a huge literal overflows and logs, so bound the digits first
	if parts[0].length() > 3 or not parts[0].is_valid_int():
		return {"error": Lang.t("code.bad_level")}
	var level: int = parts[0].to_int() - 1
	if level < 0 or level >= Difficulty.LEVELS.size():
		return {"error": Lang.t("code.level_range")}
	var hex := parts[1].strip_edges()
	if hex.length() != 8 or not hex.is_valid_hex_number():
		return {"error": Lang.t("code.bad_seed")}
	return {"mode": "seed", "level": level, "seed": ("0x" + hex).hex_to_int()}


static func _read_custom(text: String) -> Dictionary:
	if text.length() > MAX_TEXT:
		return {"error": Lang.t("code.too_long")}
	# pasted codes often pick up line breaks on the way
	var body := text.replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "")
	# base64_to_raw logs an engine error on malformed input, so screen it first
	if not _is_base64(body):
		return {"error": Lang.t("code.broken")}
	var data := Marshalls.base64_to_raw(body)
	if data.size() < HEADER_BYTES:
		return {"error": Lang.t("code.broken")}
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var version := buf.get_u8()
	if version < 1 or version > VERSION:
		return {"error": Lang.t("code.version")}
	var flags := buf.get_u8()
	var fresnel := (flags & 1) != 0
	var manual := (flags & 2) != 0
	var choices := buf.get_u8()
	if choices < MIN_CHOICES or choices > MAX_CHOICES:
		return {"error": Lang.t("code.choice_range")}
	var perim: float = 2.0 * (ProblemGen.FIELD.size.x + ProblemGen.FIELD.size.y)
	var source_s := float(buf.get_u16())
	if source_s >= perim:
		return {"error": Lang.t("code.source_range")}
	var source_tilt := _u16_to_tilt(buf.get_u16())
	# a source on a corner can be tilted right back out of the field
	var probe: Vector2 = ProblemGen.s_to_point(source_s) + ProblemGen.border_inward(source_s).rotated(source_tilt) * 2.0
	if not ProblemGen.FIELD.has_point(probe):
		return {"error": Lang.t("code.source_aim")}
	var count := buf.get_u8()
	if count > MAX_OBJECTS:
		return {"error": Lang.t("code.many_objects")}
	var body_bytes := HEADER_BYTES + count * object_bytes(version)
	if version == 1:
		if data.size() != body_bytes:
			return {"error": Lang.t("code.broken")}
	elif data.size() < body_bytes + 1:
		return {"error": Lang.t("code.broken")}
	var records: Array = []
	var objects: Array = []
	for _i in count:
		var kind_id := buf.get_u8()
		if kind_id >= KINDS.size():
			return {"error": Lang.t("code.bad_kind")}
		var kind: String = KINDS[kind_id]
		var mat := _index_to_mat(kind, buf.get_u8())
		if mat.is_empty():
			return {"error": Lang.t("code.bad_material")}
		var rec := {
			"kind": kind, "mat": mat,
			"x": float(buf.get_u16()), "y": float(buf.get_u16()),
			"s1": float(buf.get_u16()), "s2": float(buf.get_u16()),
			"rot": _u16_to_angle(buf.get_u16()), "extra": 0,
		}
		if version >= 3:
			rec.extra = buf.get_u8()
		if not size_ok(rec):
			return {"error": Lang.t("code.size_range")}
		var obj := ProblemGen.make_object(kind, mat, Vector2(rec.x, rec.y), rec.s1, rec.s2, rec.rot, rec.extra)
		if obj == null or not in_field(obj):
			return {"error": Lang.t("code.outside")}
		# nesting would break the tracer's medium tracking, so never load it
		if not ProblemGen.no_overlap(obj, objects):
			return {"error": Lang.t("code.overlap")}
		records.append(rec)
		objects.append(obj)
	var decoys: Array = []
	if version >= 2:
		var d_count := buf.get_u8()
		if d_count > MAX_DECOYS:
			return {"error": Lang.t("code.many_decoys")}
		if data.size() != body_bytes + 1 + d_count * 2:
			return {"error": Lang.t("code.broken")}
		for _i in d_count:
			var s := float(buf.get_u16())
			if s >= perim:
				return {"error": Lang.t("code.decoy_range")}
			decoys.append(s)
	# a manual stage with no decoys yet is unplayable but readable, and the editor
	# still has to show where the light goes
	return {
		"mode": "custom", "fresnel": fresnel, "choices": choices, "manual": manual,
		"source_s": source_s, "source_tilt": source_tilt, "objects": records, "decoys": decoys,
	}


static func size_ok(rec: Dictionary) -> bool:
	if not ProblemGen.SIZE_RANGE.has(rec.kind):
		return false
	var r: Dictionary = ProblemGen.SIZE_RANGE[rec.kind]
	if rec.s1 < r.s1[0] or rec.s1 > r.s1[1]:
		return false
	if r.s2[1] > 0.0:
		if rec.s2 < r.s2[0] or rec.s2 > r.s2[1]:
			return false
	elif rec.s2 != 0.0:
		return false
	return extra_ok(rec)


## The spare byte carries something different for each shape that has one, and
## nothing at all for the rest
static func extra_ok(rec: Dictionary) -> bool:
	var extra: int = int(rec.get("extra", 0))
	if extra < 0 or extra > 255:
		return false
	match rec.kind:
		"polarizer":
			return extra < 180 and rec.mat == "polarizer"
		"gradient":
			# graded past what the material can carry, the thin side would come
			# out rarer than air and the ray equation would have nothing to solve
			var slope := GradientBody.slope_from_byte(extra)
			return absf(slope) <= GradientBody.slope_cap(rec.mat, rec.s2) + 1e-9
	return extra == 0


## Measured on the drawn shape, not its bounding circle, so a wide flat body can
## sit near the top and bottom edges instead of being held a radius away
static func in_field(obj: SceneObj) -> bool:
	var room := ProblemGen.FIELD.grow(-ProblemGen.TOUCH_CLEAR)
	for p in obj.outline(0.0):
		if not room.has_point(p):
			return false
	return true


static func source_of(stage: Dictionary) -> Dictionary:
	var p := ProblemGen.s_to_point(stage.source_s)
	var d := ProblemGen.border_inward(stage.source_s).rotated(stage.source_tilt)
	return {"p": p, "d": d, "side": 0}


## Live objects back into records. A generated layout carries floats the code
## cannot hold, so this is where a replayed stage gets snapped to the grid
static func records_from(objects: Array) -> Array:
	var out: Array = []
	for obj: SceneObj in objects:
		var b: Dictionary = obj.bounding()
		var rec := {"kind": obj.kind, "mat": obj.mat_key, "x": b.center.x, "y": b.center.y, "s1": 0.0, "s2": 0.0, "rot": 0.0, "extra": 0}
		match obj.kind:
			"mirror":
				rec.s1 = obj.a.distance_to(obj.b) * 0.5
				rec.rot = (obj.b - obj.a).angle()
			"polarizer":
				rec.s1 = obj.a.distance_to(obj.b) * 0.5
				rec.rot = (obj.b - obj.a).angle()
				rec.extra = PolarizerObj.byte_from_phi(obj.phi)
			"circle":
				rec.s1 = obj.radius
			"slab", "gradient":
				rec.s1 = (obj.points[1] - obj.points[0]).length()
				rec.s2 = (obj.points[2] - obj.points[1]).length()
				rec.rot = (obj.points[1] - obj.points[0]).angle()
				if obj is GradientBody:
					rec.extra = GradientBody.byte_from_slope((obj as GradientBody).slope)
			"prism":
				rec.s1 = b.radius
				rec.rot = (obj.points[0] - b.center).angle()
		out.append(rec)
	return out


static func objects_of(stage: Dictionary) -> Array:
	var out: Array = []
	for rec: Dictionary in stage.objects:
		out.append(ProblemGen.make_object(rec.kind, rec.mat, Vector2(rec.x, rec.y), rec.s1, rec.s2, rec.rot, int(rec.get("extra", 0))))
	return out


static func _is_base64(s: String) -> bool:
	if s.is_empty() or s.length() % 4 != 0:
		return false
	var pad := 0
	for i in s.length():
		var c := s[i]
		if c == "=":
			pad += 1
			continue
		if pad > 0:
			return false
		var ok := (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "+" or c == "/"
		if not ok:
			return false
	return pad <= 2


static func _mat_to_index(kind: String, mat: String) -> int:
	if kind == "polarizer":
		return 0
	if kind == "mirror":
		return maxi(OpticsMaterials.REFLECTIVE_ORDER.find(mat), 0)
	return maxi(OpticsMaterials.ORDER.find(mat), 0)


static func _index_to_mat(kind: String, index: int) -> String:
	# a sheet has no index of its own, so only one number reads as one
	if kind == "polarizer":
		return "polarizer" if index == 0 else ""
	var table: Array = OpticsMaterials.REFLECTIVE_ORDER if kind == "mirror" else OpticsMaterials.ORDER
	return table[index] if index < table.size() else ""


static func _angle_to_u16(rot: float) -> int:
	return int(round(fposmod(rot, TAU) / TAU * 65536.0)) & 0xffff


static func _u16_to_angle(raw: int) -> float:
	return float(raw) / 65536.0 * TAU


static func _tilt_to_u16(tilt: float) -> int:
	var t := clampf(tilt, -MAX_TILT, MAX_TILT)
	return int(round((t + MAX_TILT) / (2.0 * MAX_TILT) * 65535.0))


static func _u16_to_tilt(raw: int) -> float:
	return float(raw) / 65535.0 * 2.0 * MAX_TILT - MAX_TILT
