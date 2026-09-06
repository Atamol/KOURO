extends Node
## Dev tool: where a longer language could push a row past the frame


func _ready() -> void:
	for loc: String in ["ja", "en"]:
		Lang.locale = loc
		await _codex(loc)
		await _creative(loc)
	get_tree().quit()


func _codex(loc: String) -> void:
	var font := UiTheme.body_font()
	var width := 700.0
	var worst_w := 0.0
	var worst_facts := 0
	var worst_trivia := 0
	var codex: Node = load("res://scenes/codex.tscn").instantiate()
	add_child(codex)
	await get_tree().process_frame
	for i in (codex.keys as Array).size():
		codex._select(i)
		var facts: String = codex.facts.text
		worst_facts = maxi(worst_facts, facts.split("\n").size())
		for line: String in facts.split("\n"):
			worst_w = maxf(worst_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
		worst_trivia = maxi(worst_trivia,
				ceili(font.get_string_size(codex.trivia.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x / width))
	print("%s codex: facts %.0f / %.0f wide, %d lines    trivia %d lines"
			% [loc, worst_w, width, worst_facts, worst_trivia])
	codex.queue_free()
	await get_tree().process_frame


func _creative(loc: String) -> void:
	var font := UiTheme.body_font()
	GameState.stage_code = StageCode.from_seed(6, 4600)
	var ed: Node = load("res://scenes/creative.tscn").instantiate()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	var help := 0.0
	var bottom := 0.0
	for child in (ed.ui as Node).get_children():
		if child is Label and (child as Label).position.x > 200.0:
			help = maxf(help, (child as Label).size.x)
			bottom = (child as Label).position.y + (child as Label).size.y
	print("%s editor: help %.0f / 730 wide, bottom %.0f / 68 (frame)" % [loc, help, bottom])
	for picked in [-1, 0]:
		ed._select(picked)
		await get_tree().process_frame
		await get_tree().process_frame
		for child in (ed.ui as Node).get_children():
			if child is HBoxContainer:
				print("  selected %d: row ends at %.0f / 1130"
						% [picked, (child as Control).position.x + (child as Control).size.x])
	_picker(loc, ed)
	ed.queue_free()
	await get_tree().process_frame


## What the material box ends up with against the longest name it has to show
func _picker(loc: String, ed: Node) -> void:
	var font := UiTheme.body_font()
	var widest := 0.0
	var name := ""
	for key: String in OpticsMaterials.BY_INDEX:
		var text := "%s  n=%.3f" % [OpticsMaterials.label_of(key), OpticsMaterials.TRANSPARENT[key].n]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		if w > widest:
			widest = w
			name = text
	print("%s picker: box %.0f wide, longest item %.0f (%s)"
			% [loc, (ed.mat_picker as Control).size.x, widest, name])
