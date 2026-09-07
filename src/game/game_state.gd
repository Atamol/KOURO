extends Node
## Session state plus the little that survives between runs. Progress is kept
## deliberately small: one flag per level across all three ladders


## What a solved board is worth. `miss_cost` comes off the number of marks so
## that guessing gains nothing: a blind pick among C returns 100/C and loses
## (C-1)/C of the cost, which cancel at 100/(C-1)
const SOLVED := 100
## The real cost of a mistake is losing this, not the deduction: a run of ten is
## worth 250 a board, well past what a wrong answer takes off
const CHAIN := 25
const CHAIN_CAP := 10

const SAVE_PATH := "user://progress.cfg"
const DEV_FILE := "dev_progress.cfg"
const DEV_TEMPLATE := "; デバッグ実行のときだけ読まれます．起動するたびにこの内容へ戻り，遊んだ結果は保存されません
; main   クリア済みにしておくノーマルのレベル数 (0 で全ロック，15 で全解放)
; hard   同じくハードのレベル数 (0-9)
; extra  同じくエクストラのレベル数 (0-5)
[dev]
main=0
hard=0
extra=0
"

var mode := "main"
## which ladder the level select screen shows, kept apart from `mode` so
## backing out of a stage loaded from the editor still lands somewhere sane
var menu_mode := "hard"
var tutorial_topic := "refract"
## index into Difficulty.LEVELS, not into the ladder it belongs to
var level_index := 0
## non-empty means play this exact stage instead of generating one
var stage_code := ""
var from_creative := false
var score := 0
var streak := 0
var best_streak := 0
var asked := 0
var correct := 0

## modes that opened while the player was on a stage, waiting to be announced
var just_opened: Array[String] = []
## unityroom's scoreboard, only in a release build that was given a key
var board: UnityroomClient
var board_no := 1
## the highest total the board has confirmed, so the same one is not posted twice
var posted := 0
## handed over and not yet answered for. Apart from `posted` because a request
## can fail, and a total counted as sent when it was not is one nobody sees
var sending := 0
## how long to wait before offering a failed total again. Long enough that a
## network that is down stays down, short enough to catch a run that ends soon
const RESEND_WAIT := 12.0

var cleared: Array[bool] = []
var tutorial_read: Array[bool] = []
## set by the test scene so a test run never rewrites the player's progress
var testing := false
## debug builds start from dev_progress.cfg every time and never write back
var dev_mode := false


func _ready() -> void:
	# Lang is static rather than an autoload, so nothing loads its setting for it
	Lang.load_saved()
	cleared.resize(Difficulty.LEVELS.size())
	tutorial_read.resize(TutorialTopics.LIST.size())
	dev_mode = OS.is_debug_build()
	if dev_mode:
		_load_dev()
	else:
		_load()
	_open_board()


## Without a key the game plays the same and sends nothing, so a debug run
## cannot put junk on the board
func _open_board() -> void:
	if dev_mode:
		return
	var key := Secrets.read("UNITYROOM_HMAC_KEY")
	if key.is_empty():
		return
	board_no = int(Secrets.read("UNITYROOM_SCOREBOARD_NO", "1"))
	board = UnityroomClient.new(key)
	board.score_uploaded.connect(_on_board_answered)
	add_child(board)


## Only ever upward: the scoreboard keeps the best, so a total that went down is
## nothing for it to hear about, and neither is one already in flight
func _post_score() -> void:
	if board == null or score <= maxi(posted, sending):
		return
	sending = score
	board.send_score(board_no, float(score))


## The client keeps whichever queued total is better and drops the rest, so a
## success stands for everything handed over up to that point
func _on_board_answered(success: bool, response: UnityroomClient.Response) -> void:
	var went: int = sending
	sending = 0
	if success:
		posted = maxi(posted, went)
		return
	# a throttled total is still in the client's queue and will go on its own.
	# Anything else is gone, so it is offered again in case the run ends here
	if response is UnityroomClient.ErrorResponse and (response as UnityroomClient.ErrorResponse).type == "throttled":
		return
	get_tree().create_timer(RESEND_WAIT).timeout.connect(_post_score)


## Lives in the project folder while running from the editor, where it can be
## edited by hand
func dev_path() -> String:
	return ("res://" if OS.has_feature("editor") else "user://") + DEV_FILE


func _load_dev() -> void:
	var path := dev_path()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(DEV_TEMPLATE)
			f.close()
		cfg.parse(DEV_TEMPLATE)
	apply_dev(cfg)


func apply_dev(cfg: ConfigFile) -> void:
	for m: String in Difficulty.MODES:
		var count: int = Difficulty.count_of(m)
		var unlocked := clampi(int(cfg.get_value("dev", m, 0)), 0, count)
		for i in count:
			cleared[Difficulty.start_of(m) + i] = i < unlocked


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var saved: Array = cfg.get_value("progress", "cleared", [])
	for i in mini(saved.size(), cleared.size()):
		cleared[i] = bool(saved[i])
	var read: Array = cfg.get_value("progress", "tutorial", [])
	for i in mini(read.size(), tutorial_read.size()):
		tutorial_read[i] = bool(read[i])


func _save() -> void:
	if testing or dev_mode:
		return
	var cfg := ConfigFile.new()
	var out: Array = []
	for done in cleared:
		out.append(done)
	cfg.set_value("progress", "cleared", out)
	var read: Array = []
	for done in tutorial_read:
		read.append(done)
	cfg.set_value("progress", "tutorial", read)
	cfg.save(SAVE_PATH)


func is_open(index: int) -> bool:
	var m := Difficulty.mode_of(index)
	if not mode_open(m):
		return false
	return index == Difficulty.start_of(m) or cleared[index - 1]


## Hard opens once main has handed out every element it has, which is the last
## of the teaching levels rather than the last of the ladder. Extra waits until
## hard is finished
func mode_open(m: String) -> bool:
	if m == "hard":
		return cleared[Difficulty.TEACHING.size() - 1]
	if m == "extra":
		return mode_cleared("hard")
	return true


func mode_cleared(m: String) -> bool:
	for i in Difficulty.count_of(m):
		if not cleared[Difficulty.start_of(m) + i]:
			return false
	return true


func cleared_in(m: String) -> int:
	var n := 0
	for i in Difficulty.count_of(m):
		if cleared[Difficulty.start_of(m) + i]:
			n += 1
	return n


## Set once a topic has been read to its last page
func mark_read(key: String) -> void:
	for i in TutorialTopics.LIST.size():
		if TutorialTopics.LIST[i].key == key and not tutorial_read[i]:
			tutorial_read[i] = true
			_save()
			return


## What the mark on the tutorial button means. The topics open from the start
## are not news, so they do not count
func tutorial_news() -> bool:
	for i in TutorialTopics.LIST.size():
		var topic: Dictionary = TutorialTopics.LIST[i]
		if topic.hard and mode_open("hard") and not tutorial_read[i]:
			return true
	return false


func topic_read(key: String) -> bool:
	for i in TutorialTopics.LIST.size():
		if TutorialTopics.LIST[i].key == key:
			return tutorial_read[i]
	return false


## The score rides across stages and modes, so picking a new one leaves it alone
func start(index: int) -> void:
	mode = Difficulty.mode_of(index)
	level_index = index
	stage_code = ""
	from_creative = false


func current_level() -> int:
	return level_index


## The next level of the same ladder, or -1 at the end of one
func next_level() -> int:
	var last: int = Difficulty.start_of(mode) + Difficulty.count_of(mode) - 1
	return -1 if level_index >= last else level_index + 1


func play_stage(code: String, editing: bool) -> void:
	start(level_index)
	stage_code = code
	from_creative = editing


func clear_stage() -> void:
	stage_code = ""
	from_creative = false


func reset_score() -> void:
	score = 0
	streak = 0
	best_streak = 0
	asked = 0
	correct = 0


## Returns what the score moved by, so the screen can show the same number
## rather than working it out a second time
func record(is_correct: bool, choices: int) -> int:
	# a board from a code could have been built to be trivial. Where it came from
	# rather than whether the editor opened it, since sharing one back to yourself
	# would otherwise be the way round
	if not stage_code.is_empty():
		return 0
	asked += 1
	if is_correct:
		correct += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		var gain := SOLVED + chain_bonus(streak)
		score += gain
		_post_score()
		return gain
	streak = 0
	var cost := mini(miss_cost(choices), score)
	score -= cost
	return -cost


## What one wrong answer costs on a board offering this many marks
static func miss_cost(choices: int) -> int:
	return roundi(float(SOLVED) / maxf(float(choices - 1), 1.0))


## What the run of right answers is worth on top of the board itself
static func chain_bonus(run: int) -> int:
	return CHAIN * mini(maxi(run - 1, 0), CHAIN_CAP)


## Only a correct answer on a freshly generated problem counts as beating it.
## A mode opening is worth saying out loud: the player is on a stage screen at
## the time and would otherwise only find out by going back to the menu
func mark_beaten() -> void:
	if not stage_code.is_empty():
		return
	if level_index >= cleared.size() or cleared[level_index]:
		return
	var was := {}
	for m: String in Difficulty.MODES:
		was[m] = mode_open(m)
	cleared[level_index] = true
	for m: String in Difficulty.MODES:
		if mode_open(m) and not was[m]:
			just_opened.append(m)
	_save()


## The next mode that opened and has not been announced yet, or an empty string
func take_opened() -> String:
	return "" if just_opened.is_empty() else String(just_opened.pop_front())
