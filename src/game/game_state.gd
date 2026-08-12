extends Node
## Session state plus the little that survives between runs. Progress is kept
## deliberately small: one flag per level across all three ladders


const SAVE_PATH := "user://progress.cfg"
const DEV_FILE := "dev_progress.cfg"
const DEV_TEMPLATE := "; デバッグ実行のときだけ読まれます．起動するたびにこの内容へ戻り，遊んだ結果は保存されません
; main   突破済みにしておくノーマルの段階数 (0 で全ロック，15 で全解放)
; hard   同じくハードの段階数 (0-10)
; extra  同じくエクストラの段階数 (0-5)
[dev]
main=0
hard=0
extra=0
"

var mode := "main"
## which ladder the level select screen shows, kept apart from `mode` so
## backing out of a stage loaded from the editor still lands somewhere sane
var menu_mode := "hard"
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

var cleared: Array[bool] = []
## set by the test scene so a test run never rewrites the player's progress
var testing := false
## debug builds start from dev_progress.cfg every time and never write back
var dev_mode := false


func _ready() -> void:
	cleared.resize(Difficulty.LEVELS.size())
	dev_mode = OS.is_debug_build()
	if dev_mode:
		_load_dev()
	else:
		_load()


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


func _save() -> void:
	if testing or dev_mode:
		return
	var cfg := ConfigFile.new()
	var out: Array = []
	for done in cleared:
		out.append(done)
	cfg.set_value("progress", "cleared", out)
	cfg.save(SAVE_PATH)


## A level opens once the one before it in the same ladder has been beaten
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


func reset_progress() -> void:
	for i in cleared.size():
		cleared[i] = false
	_save()


func start(index: int) -> void:
	mode = Difficulty.mode_of(index)
	level_index = index
	stage_code = ""
	from_creative = false
	_reset_counters()


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


func _reset_counters() -> void:
	score = 0
	streak = 0
	best_streak = 0
	asked = 0
	correct = 0


func record(is_correct: bool) -> void:
	asked += 1
	if is_correct:
		correct += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		score += (current_level() + 1) * 100 + maxi(streak - 1, 0) * 25
	else:
		streak = 0


## Only a correct answer on a freshly generated problem counts as beating it
func mark_beaten() -> void:
	if not stage_code.is_empty():
		return
	if level_index < cleared.size() and not cleared[level_index]:
		cleared[level_index] = true
		_save()
