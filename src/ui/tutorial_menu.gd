extends Control
## Which gimmick to read about. Everything hard mode adds stays greyed out and
## unnamed until hard mode itself opens, so the list says how much is left
## without saying what it is


const DONE := "✓"
const HIDDEN := "???"
const WIDE := 720
const LOCKED := Color(0.45, 0.48, 0.55)

var buttons: Array = []
var ticks: Array = []


func _ready() -> void:
	theme = UiTheme.make()
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.07, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(MenuSky.new())
	SkyState.allow_beams(true)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var title := Label.new()
	title.text = Lang.t("tut.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var sub := Label.new()
	sub.text = Lang.t("tut.sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	box.add_child(sub)
	box.add_child(_spacer(12))
	for i in TutorialTopics.LIST.size():
		var b := Button.new()
		# the rules are not one gimmick among others, they are what the rest is
		# for, so they stand taller and sit apart from the list
		var first: bool = i == 0
		b.custom_minimum_size = Vector2(WIDE, 50 if first else 40)
		if first:
			b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_topic.bind(i))
		box.add_child(b)
		buttons.append(b)
		# in the text, the tick pushed every title off centre by its own width.
		# Riding alongside, it leaves the titles where they belong
		var tick := Label.new()
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.text = DONE
		tick.size = Vector2(26, 50 if first else 40)
		tick.position = Vector2(150, 0)
		tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(tick)
		ticks.append(tick)
		if first:
			box.add_child(_spacer(10))
	box.add_child(_spacer(10))
	var back := Button.new()
	back.text = Lang.t("back_menu")
	back.custom_minimum_size = Vector2(WIDE, 38)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_to_menu)
	box.add_child(back)
	_refresh()


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _open(i: int) -> bool:
	return not TutorialTopics.LIST[i].hard or GameState.mode_open("hard")


func _refresh() -> void:
	for i in buttons.size():
		var b: Button = buttons[i]
		var topic: Dictionary = TutorialTopics.LIST[i]
		var read: bool = GameState.tutorial_read[i]
		b.disabled = not _open(i)
		# a locked topic does not even say what it is about: naming the gimmick
		# would hand over the answer to the levels that introduce it
		b.text = TutorialTopics.title_of(topic) if _open(i) else HIDDEN
		var col := Color(0.55, 1.0, 0.65) if read else Color(0.9, 0.93, 0.97)
		# the rules read as the way in until they have been read
		if i == 0 and not read:
			col = Color(1.0, 0.86, 0.52)
		b.add_theme_color_override("font_color", col if _open(i) else LOCKED)
		b.add_theme_color_override("font_disabled_color", LOCKED)
		(ticks[i] as Label).visible = read
		(ticks[i] as Label).add_theme_color_override("font_color", col)


func _on_topic(i: int) -> void:
	GameState.tutorial_topic = TutorialTopics.LIST[i].key
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		_to_menu()
