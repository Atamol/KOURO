extends Control
## Level select, shared by all three ladders. Which one it shows comes from
## GameState.menu_mode


const DONE := "✓"
const WIDE := 1088
const HEADING := {
	"main": {
		"title": "ノーマルモード",
		"sub": "鏡とガラスの15段階で，最後の3つはそれまでを混ぜた総合問題",
		"gate": "",
	},
	"hard": {
		"title": "ハードモード",
		"sub": "偏光板・複屈折・旋光性・屈折率勾配が順に増える10段階",
		"gate": "ノーマル Lv. %d を突破すると開きます",
	},
	"extra": {
		"title": "エクストラモード",
		"sub": "全ての要素が混ざった総合問題が5問，どれも難しい",
		"gate": "ハードを全て突破すると開きます",
	},
}

var mode := "hard"
var detail: Label
var buttons: Array = []
## which button the pointer is over, so leaving one that was already left does
## not wipe the line the next one just put up
var hovered := -1


func _ready() -> void:
	mode = GameState.menu_mode if HEADING.has(GameState.menu_mode) else "main"
	theme = UiTheme.make()
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.07, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = HEADING[mode].title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var sub := Label.new()
	sub.text = HEADING[mode].sub
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	box.add_child(sub)
	box.add_child(_spacer(10))
	var count := Difficulty.count_of(mode)
	# a short ladder fits on one row, a long one wants four to a row
	var columns: int = 4 if count > 6 else count
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var width := float(WIDE - (columns - 1) * 10) / columns
	for i in count:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(width, 42)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_level.bind(i))
		b.mouse_entered.connect(_show_detail.bind(i))
		b.mouse_exited.connect(_hide_detail.bind(i))
		grid.add_child(b)
		buttons.append(b)
	box.add_child(_spacer(6))
	# a plain Control keeps its own size whatever its children say, so the text
	# can change without moving the rest of the screen
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(WIDE, 30)
	box.add_child(slot)
	detail = Label.new()
	detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", Color(0.62, 0.72, 0.88))
	slot.add_child(detail)
	var back := Button.new()
	back.text = "メニューへ戻る"
	back.custom_minimum_size = Vector2(WIDE, 40)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_to_menu)
	box.add_child(back)
	_refresh()


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _index(i: int) -> int:
	return Difficulty.start_of(mode) + i


func _refresh() -> void:
	for i in buttons.size():
		var b: Button = buttons[i]
		var at := _index(i)
		var open: bool = GameState.is_open(at)
		var done: bool = GameState.cleared[at]
		b.disabled = not open
		if open:
			b.text = "%s  %s" % [DONE if done else "  ", Difficulty.short_label(at)]
		else:
			b.text = "     Lv. %d  ―――" % (i + 1)
		b.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65) if done else Color(0.9, 0.93, 0.97))


## Moving between two buttons fires both signals in either order, so only the
## button still being pointed at may clear
func _hide_detail(i: int) -> void:
	if hovered != i:
		return
	hovered = -1
	detail.text = ""


func _show_detail(i: int) -> void:
	hovered = i
	var at := _index(i)
	if GameState.is_open(at):
		detail.text = Difficulty.LEVELS[at].gimmick
	elif GameState.mode_open(mode):
		detail.text = "%sLv. %d を突破すると開きます" % [Difficulty.prefix_of(mode), i]
	else:
		detail.text = HEADING[mode].gate % Difficulty.TEACHING.size() if mode == "hard" else HEADING[mode].gate


func _on_level(i: int) -> void:
	GameState.start(_index(i))
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		_to_menu()
