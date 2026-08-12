extends Control
## Mode select and nothing else. Picking levels belongs to the ladder screen,
## which all three modes share


const DONE := "✓"
## wide enough for the longest hint to sit on one line. A hint that had to wrap
## would change the column's width and shift everything each time it appeared
const WIDE := 720
## the same amber the debug notice uses, so what is not a mode reads as not a mode
const ASIDE := Color(1.0, 0.78, 0.45)
const HINTS := {
	"main": "鏡とガラスだけを追う15段階で，最初から遊べる",
	"hard": "偏光板・複屈折・旋光性・屈折率勾配が順に増える10段階．ノーマル Lv. %d で開く",
	"extra": "全ての要素が混ざった総合問題が5問，どれも難しい",
}
const NAMES := {"main": "ノーマル", "hard": "ハード", "extra": "エクストラ"}
const GATES := {"main": "", "hard": "ノーマル Lv. %d を突破すると開く", "extra": "ハードを全て突破すると開く"}

var detail: Label
var buttons: Array = []
## which button the pointer is over, so leaving one that was already left does
## not wipe the hint the next one just put up
var hovered := ""


func _ready() -> void:
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
	title.text = "KOURO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiTheme.title_font())
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "枠に入った光がどこから出るかを当てる    正解するとその段階が開く"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	box.add_child(sub)
	if GameState.dev_mode:
		var dev := Label.new()
		dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dev.add_theme_font_size_override("font_size", 13)
		dev.add_theme_color_override("font_color", ASIDE)
		dev.text = "デバッグ実行    進捗は保存されず，起動のたびに %s へ戻ります" % GameState.dev_path()
		box.add_child(dev)
	box.add_child(_spacer(16))
	for m: String in Difficulty.MODES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(WIDE, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_mode.bind(m))
		b.mouse_entered.connect(_show_hint.bind(m))
		b.mouse_exited.connect(_hide_hint.bind(m))
		box.add_child(b)
		buttons.append(b)
	box.add_child(_spacer(4))
	# the label lives inside a fixed slot: a plain Control keeps its own size
	# whatever its children say, so the text can change without moving anything
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
	var creative := Button.new()
	creative.text = "クリエイティブモード"
	creative.custom_minimum_size = Vector2(WIDE, 40)
	creative.focus_mode = Control.FOCUS_NONE
	creative.add_theme_color_override("font_color", ASIDE)
	creative.add_theme_color_override("font_hover_color", ASIDE.lightened(0.2))
	creative.add_theme_color_override("font_pressed_color", ASIDE)
	creative.pressed.connect(func() -> void:
		GameState.clear_stage()
		get_tree().change_scene_to_file("res://scenes/creative.tscn"))
	box.add_child(creative)
	var quit := Button.new()
	quit.text = "終了"
	quit.custom_minimum_size = Vector2(WIDE, 34)
	quit.focus_mode = Control.FOCUS_NONE
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	_refresh()


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## A locked mode still shows its name and what opens it
func _refresh() -> void:
	for i in Difficulty.MODES.size():
		var m: String = Difficulty.MODES[i]
		var b: Button = buttons[i]
		var open: bool = GameState.mode_open(m)
		var done: bool = GameState.mode_cleared(m)
		b.disabled = not open
		if open:
			b.text = "%s  %sモード   %d / %d" % [DONE if done else "  ", NAMES[m], GameState.cleared_in(m), Difficulty.count_of(m)]
		else:
			b.text = "%sモード   ―――  (%s)" % [NAMES[m], _gate(m)]
		b.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65) if done else Color(0.9, 0.93, 0.97))


func _gate(m: String) -> String:
	return GATES[m] % Difficulty.TEACHING.size() if m == "hard" else GATES[m]


func _show_hint(m: String) -> void:
	hovered = m
	detail.text = HINTS[m] % Difficulty.TEACHING.size() if m == "hard" else HINTS[m]


## Moving between two buttons fires both signals in either order, so only the
## button still being pointed at may clear
func _hide_hint(m: String) -> void:
	if hovered != m:
		return
	hovered = ""
	detail.text = ""


func _on_mode(m: String) -> void:
	GameState.menu_mode = m
	get_tree().change_scene_to_file("res://scenes/ladder.tscn")
