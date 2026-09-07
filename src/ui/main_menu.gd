extends Control
## Mode select and nothing else. Picking levels belongs to the ladder screen,
## which all three modes share


const DONE := "✓"
## an ideographic space, exactly as wide as the tick, so an unbeaten ladder
## still starts its name where a beaten one does
const NOT_DONE := "　"
## wide enough for the longest hint to sit on one line. A hint that had to wrap
## would change the column's width and shift everything each time it appeared
const WIDE := 720
const GUTTER := 26.0
## wide enough for either name the button can carry
const LANG_W := 110.0
## the same amber the debug notice uses, so what is not a mode reads as not a mode
const ASIDE := Color(1.0, 0.78, 0.45)
## what a mode reads as before it opens, matching the tutorial list
const LOCKED := Color(0.45, 0.48, 0.55)
const HINTS := {
	"tutorial": "blurb.tutorial",
	"codex": "blurb.codex",
	"main": "blurb.main",
	"hard": "blurb.hard",
	"extra": "blurb.extra",
}
const GATES := {"main": "", "hard": "gate.hard", "extra": "gate.extra"}


var detail: Label
## the mark that says a topic opened while the player was elsewhere
var badge: Label
var score_label: Label
## built the first time it is needed, since most visits never ask for it
var confirm: ConfirmationDialog
var buttons: Array = []
var names: Array = []
var counts: Array = []
var locks: Array = []
## which button the pointer is over, so leaving one that was already left does
## not wipe the hint the next one just put up
var hovered := ""


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
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = "KOURO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiTheme.title_font())
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	if GameState.dev_mode:
		var dev := Label.new()
		dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dev.add_theme_font_size_override("font_size", 13)
		dev.add_theme_color_override("font_color", ASIDE)
		dev.text = Lang.t("menu.dev") % GameState.dev_path()
		box.add_child(dev)
	box.add_child(_spacer(16))
	var tutorial := Button.new()
	tutorial.text = Lang.t("menu.tutorial")
	tutorial.custom_minimum_size = Vector2(WIDE, 40)
	tutorial.focus_mode = Control.FOCUS_NONE
	tutorial.mouse_entered.connect(_show_hint.bind("tutorial"))
	tutorial.mouse_exited.connect(_hide_hint.bind("tutorial"))
	tutorial.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/tutorial_menu.tscn"))
	box.add_child(tutorial)
	# rides on the button rather than in its text, so only the mark is red
	badge = Label.new()
	badge.text = "!"
	badge.size = Vector2(26, 40)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", 24)
	badge.add_theme_color_override("font_color", Color(1.0, 0.32, 0.32))
	tutorial.add_child(badge)
	var codex := Button.new()
	codex.text = Lang.t("menu.codex")
	codex.custom_minimum_size = Vector2(WIDE, 40)
	codex.focus_mode = Control.FOCUS_NONE
	codex.mouse_entered.connect(_show_hint.bind("codex"))
	codex.mouse_exited.connect(_hide_hint.bind("codex"))
	codex.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/codex.tscn"))
	box.add_child(codex)
	box.add_child(_spacer(8))
	for m: String in Difficulty.MODES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(WIDE, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_mode.bind(m))
		b.mouse_entered.connect(_show_hint.bind(m))
		b.mouse_exited.connect(_hide_hint.bind(m))
		box.add_child(b)
		buttons.append(b)
		# a button centres its own text on its own width, which starts the three
		# names in three different places. Carrying the name and the padlock as
		# children instead lets the block sit centred with every name together
		var lock := TextureRect.new()
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.size = Vector2(26, 26)
		b.add_child(lock)
		locks.append(lock)
		var named := _rider(b)
		names.append(named)
		counts.append(_rider(b))
	box.add_child(_spacer(4))
	# the label lives inside a fixed slot: a plain Control keeps its own size
	# whatever its children say, so the text can change without moving anything
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(WIDE, 34)
	box.add_child(slot)
	detail = Label.new()
	detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 19)
	detail.add_theme_color_override("font_color", Color(0.82, 0.88, 0.98))
	slot.add_child(detail)
	# the score rides across stages, so the one place it can be seen and cleared
	# is here rather than inside a stage
	var tally := HBoxContainer.new()
	tally.custom_minimum_size = Vector2(WIDE, 0)
	tally.add_theme_constant_override("separation", 12)
	box.add_child(tally)
	score_label = Label.new()
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	tally.add_child(score_label)
	var wipe := Button.new()
	wipe.text = Lang.t("menu.wipe")
	wipe.custom_minimum_size = Vector2(158, 32)
	wipe.focus_mode = Control.FOCUS_NONE
	wipe.pressed.connect(_ask_reset)
	tally.add_child(wipe)
	var creative := Button.new()
	creative.text = Lang.t("menu.creative")
	creative.custom_minimum_size = Vector2(WIDE, 40)
	creative.focus_mode = Control.FOCUS_NONE
	creative.add_theme_color_override("font_color", ASIDE)
	creative.add_theme_color_override("font_hover_color", ASIDE.lightened(0.2))
	creative.add_theme_color_override("font_pressed_color", ASIDE)
	creative.pressed.connect(func() -> void:
		GameState.clear_stage()
		get_tree().change_scene_to_file("res://scenes/creative.tscn"))
	box.add_child(creative)
	# quitting a page does nothing a tab does not already do, and on the web it
	# leaves the canvas frozen instead of closing anything
	if OS.is_debug_build():
		var quit := Button.new()
		quit.text = Lang.t("menu.quit")
		quit.custom_minimum_size = Vector2(WIDE, 34)
		quit.focus_mode = Control.FOCUS_NONE
		quit.pressed.connect(func() -> void: get_tree().quit())
		box.add_child(quit)
	_add_language_button()
	_refresh()


## Out of the centred column, since it belongs to the game rather than to this
## screen. Added last on purpose: the centred column covers the whole screen and
## would take the click first
func _add_language_button() -> void:
	var b := Button.new()
	b.text = Lang.other_name()
	b.size = Vector2(LANG_W, 32)
	b.position = Vector2(get_viewport_rect().size.x - LANG_W - 28.0, 22.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", ASIDE)
	b.add_theme_color_override("font_hover_color", ASIDE.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", ASIDE)
	b.pressed.connect(func() -> void:
		Lang.toggle()
		get_tree().reload_current_scene())
	add_child(b)


## A label that rides on a button, placed by hand rather than by the button
func _rider(host: Button) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(WIDE, 48)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	host.add_child(l)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## A locked mode says its name and carries a shut padlock. The count only means
## something once there is something to count, and it keeps its own column so
## the three of them read down the screen
func _refresh() -> void:
	score_label.text = Lang.t("menu.score") % [GameState.score, GameState.best_streak]
	var font := theme.default_font
	var size: int = theme.default_font_size
	var head := 0.0
	var tail := 0.0
	for m: String in Difficulty.MODES:
		head = maxf(head, _wide(font, size, "%s  %s" % [DONE, Difficulty.mode_name(m)]))
		# against the longest either column will ever be, so opening a ladder does
		# not slide the whole block sideways
		tail = maxf(tail, _wide(font, size, "%d / %d" % [Difficulty.count_of(m), Difficulty.count_of(m)]))
	var pad := maxf((WIDE - head - GUTTER - tail) * 0.5, 44.0)
	# measured against the longest of the three rather than each name's own width,
	# so they still start together and opening a ladder does not slide them
	var start := (WIDE - head) * 0.5
	for i in Difficulty.MODES.size():
		var m: String = Difficulty.MODES[i]
		var open: bool = GameState.mode_open(m)
		var col := LOCKED
		if open:
			col = Color(0.55, 1.0, 0.65) if GameState.mode_cleared(m) else Color(0.9, 0.93, 0.97)
		(buttons[i] as Button).disabled = not open
		var named: Label = names[i]
		named.text = "%s  %s" % [DONE if open and GameState.mode_cleared(m) else NOT_DONE, Difficulty.mode_name(m)]
		named.position = Vector2(start, 0.0)
		named.add_theme_color_override("font_color", col)
		var tally: Label = counts[i]
		tally.text = "" if not open else "%d / %d" % [GameState.cleared_in(m), Difficulty.count_of(m)]
		tally.position = Vector2(start + head + GUTTER, 0.0)
		tally.add_theme_color_override("font_color", col)
		# the first ladder is never shut, so a padlock on it would say nothing
		var lock: TextureRect = locks[i]
		lock.texture = null if m == "main" else _lock_icon(open, col)
		lock.position = Vector2(pad - 34.0, 11.0)
	_place_badge(pad)


## In the same column as the padlocks below it, so the marks down the left of the
## menu line up
func _place_badge(pad: float) -> void:
	badge.visible = GameState.tutorial_news()
	badge.position.x = pad - 34.0


func _wide(font: Font, size: int, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func _lock_icon(open: bool, col: Color) -> Texture2D:
	var hex := col.to_html(false)
	var shackle := "M10 11 V8 a4 4 0 0 1 8 0" if open else "M7 11 V8 a4 4 0 0 1 8 0 V11"
	return _svg_icon('<path d="%s" fill="none" stroke="#%s" stroke-width="2.4"/>' % [shackle, hex]
			+ '<rect x="%d" y="11" width="14" height="11" rx="2.5" fill="#%s"/>' % [2 if open else 4, hex])


static func _svg_icon(body: String) -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">%s</svg>' % body
	var img := Image.new()
	if img.load_svg_from_buffer(svg.to_utf8_buffer(), 1.1) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _gate(m: String) -> String:
	return Lang.t(GATES[m]) % Difficulty.TEACHING.size() if m == "hard" else Lang.t(GATES[m])


## What a button says about itself changes once it opens: a shut one explains the
## way in, an open one has nothing left to promise
func _show_hint(m: String) -> void:
	hovered = m
	detail.text = Lang.t(HINTS[m]) if not GATES.has(m) or GameState.mode_open(m) else _gate(m)


## Moving between two buttons fires both signals in either order, so only the
## button still being pointed at may clear
func _hide_hint(m: String) -> void:
	if hovered != m:
		return
	hovered = ""
	detail.text = ""


## The score is a whole run, and the button that clears it sits next to the one
## that opens a ladder. Worth one question
func _ask_reset() -> void:
	if confirm == null:
		confirm = ConfirmationDialog.new()
		confirm.theme = theme
		confirm.title = Lang.t("confirm")
		confirm.ok_button_text = Lang.t("menu.wipe_ok")
		confirm.cancel_button_text = Lang.t("cancel")
		confirm.confirmed.connect(_reset_score)
		add_child(confirm)
	confirm.dialog_text = Lang.t("menu.wipe_ask") % GameState.score
	confirm.popup_centered()


func _reset_score() -> void:
	GameState.reset_score()
	_refresh()
	Toast.show_on(self, Lang.t("menu.wipe_done"), 36.0)


func _on_mode(m: String) -> void:
	GameState.menu_mode = m
	get_tree().change_scene_to_file("res://scenes/ladder.tscn")
