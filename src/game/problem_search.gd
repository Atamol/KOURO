class_name ProblemSearch
## A rejection search that can be stopped part way and picked up where it left
## off. Builds with a thread run it straight through on one; the web export has
## no thread to run it on, so it takes a slice per frame and the loading panel
## keeps drawing instead of the tab going quiet


## how many seeds it may work through before giving up
var tries := 1
## the board once one turns up, and the seed that named it
var found: Dictionary = {}
var seed_used := 0
var done := false

var _level: Dictionary
var _fixed: Dictionary
var _rng := RandomNumberGenerator.new()
var _first := 0
var _at := 0
var _placement := 0
## the layout being shot at, and how many shots it has had. A whole layout can
## take a tenth of a second, which is long enough to stall the bar it is drawn
## for, so the search stops between shots rather than between layouts
var _layout: Dictionary = {}
var _shot := 0


func _init(level: Dictionary, first: int, how_many: int) -> void:
	_level = level
	_fixed = ProblemGen.prepare(level)
	_first = first
	tries = how_many
	_rng.seed = first


## Works for up to `budget_us` microseconds, or straight through when that is
## zero. Returns whether there is nothing left to do.
##
## The seed is advanced only after a whole layout budget is spent on it, which is
## what the single call used to do, so slicing never moves a board to another seed
func step(budget_us: int) -> bool:
	var until := Time.get_ticks_usec() + budget_us
	while not done:
		# one placement or one shot per turn, so the wait between budget checks is
		# never longer than the slowest single piece of work
		if _layout.is_empty():
			_layout = ProblemGen.lay_out(_level, _rng)
			_shot = 0
			if _layout.is_empty():
				_next_layout()
		else:
			var made := ProblemGen.shoot(_level, _rng, _fixed, _layout)
			if not made.is_empty():
				found = made
				seed_used = _first + _at
				done = true
				break
			_shot += 1
			if _shot >= ProblemGen.SOURCE_TRIES:
				_layout = {}
				_next_layout()
		if budget_us > 0 and Time.get_ticks_usec() >= until:
			break
	return done


func _next_layout() -> void:
	_placement += 1
	if _placement < ProblemGen.PLACEMENT_TRIES:
		return
	_placement = 0
	_at += 1
	if _at >= tries:
		done = true
		return
	_rng.seed = _first + _at
