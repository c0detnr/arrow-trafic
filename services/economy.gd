extends Node
## Economy autoload: hints, daily reward, daily puzzle, stars and owned purchases.
## Persisted in its own file (never touches save.json); saves after every mutation.

signal hints_changed(count: int)
signal ads_removed_changed(removed: bool)
signal daily_claimed(amount: int, streak: int)

const STARTING_HINTS := 3
const DAILY_HINTS := 1
## Last day of each 7-day streak cycle pays more.
const DAILY_CYCLE := 7
const DAILY_CYCLE_HINTS := 3
## Every Nth distinct level cleared grants a bonus hint.
const CLEAR_BONUS_EVERY := 10
const MAX_TOKENS := 50
## First win of each day's puzzle grants this many hints.
const DAILY_PUZZLE_HINTS := 2
## The daily puzzle comes from level index 150 onward (levels 151+, medium/hard) when the pack is
## large enough; smaller packs use every level.
const DAILY_PUZZLE_FIRST := 150
## Days advance through the range by this stride; coprime with 850 (= levels 151..1000), so a full
## 1000-level pack shows every level once before any repeats.
const DAILY_PUZZLE_STRIDE := 379
const DAY_SECONDS := 86400

var save_path := "user://economy.json"
## Returns today's date as "YYYY-MM-DD"; tests replace it.
var today_provider: Callable

var hints := STARTING_HINTS
var ads_removed := false
var last_daily := ""
var streak := 0
var levels_cleared := 0
## ISO date of the last solved daily puzzle and the run of consecutive days ending on it.
var daily_puzzle_last := ""
var daily_puzzle_streak := 0
var best_stars := {}
var purchased: Array = []
var consumed_tokens: Array = []


func _init() -> void:
	today_provider = func() -> String: return Time.get_date_string_from_system()


func _ready() -> void:
	load_data()


func _defaults() -> void:
	hints = STARTING_HINTS
	ads_removed = false
	last_daily = ""
	streak = 0
	levels_cleared = 0
	daily_puzzle_last = ""
	daily_puzzle_streak = 0
	best_stars = {}
	purchased = []
	consumed_tokens = []


func load_data() -> void:
	_defaults()
	if not FileAccess.file_exists(save_path):
		return
	var json := JSON.new()
	var data = json.data if json.parse(FileAccess.get_file_as_string(save_path)) == OK else null
	if not data is Dictionary:
		push_warning("Economy: unreadable %s, using defaults" % save_path)
		return
	hints = maxi(0, int(_num(data.get("hints"), STARTING_HINTS)))
	ads_removed = data.get("ads_removed") is bool and data.get("ads_removed")
	last_daily = str(data.get("last_daily", "")) if data.get("last_daily") is String else ""
	streak = maxi(0, int(_num(data.get("streak"), 0)))
	levels_cleared = maxi(0, int(_num(data.get("levels_cleared"), 0)))
	daily_puzzle_last = str(data.get("daily_puzzle_last")) if data.get("daily_puzzle_last") is String else ""
	daily_puzzle_streak = maxi(0, int(_num(data.get("daily_puzzle_streak"), 0)))
	var stars = data.get("best_stars")
	if stars is Dictionary:
		for key in stars:
			var value := int(_num(stars[key], 0))
			if str(key).is_valid_int() and value >= 1:
				best_stars[str(key)] = mini(value, 3)
	for key in ["purchased", "consumed_tokens"]:
		var list = data.get(key)
		if list is Array:
			for item in list:
				if item is String:
					(purchased if key == "purchased" else consumed_tokens).append(item)


func _num(value, fallback: float) -> float:
	return value if value is float or value is int else fallback


func save_data() -> void:
	var text := JSON.stringify({"hints": hints, "ads_removed": ads_removed, "last_daily": last_daily,
		"streak": streak, "levels_cleared": levels_cleared, "daily_puzzle_last": daily_puzzle_last,
		"daily_puzzle_streak": daily_puzzle_streak, "best_stars": best_stars,
		"purchased": purchased, "consumed_tokens": consumed_tokens})
	# Write a temp file then rename so a kill mid-write cannot corrupt owned purchases.
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
		if DirAccess.rename_absolute(tmp, save_path) == OK:
			return
	f = FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(text)
	else:
		push_error("Economy: cannot write %s" % save_path)


## Wipes memory and the save file.
func reset_for_tests() -> void:
	_defaults()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


# --- Hints ---

func get_hints() -> int:
	return hints


func add_hints(n: int) -> void:
	if n <= 0:
		return
	hints += n
	save_data()
	hints_changed.emit(hints)


func spend_hint() -> bool:
	if hints <= 0:
		return false
	hints -= 1
	save_data()
	hints_changed.emit(hints)
	return true


# --- Daily reward ---

func _today() -> String:
	return str(today_provider.call())


## Only a date AFTER the last claim counts (ISO "YYYY-MM-DD" strings compare chronologically), so
## moving the device clock back and forth cannot farm the gift: an earlier date reads as "claimed".
func can_claim_daily() -> bool:
	return _today() > last_daily


## Hints the next claim_daily() would grant right now (0 if already claimed / clock moved back).
## For UI hints such as "Tomorrow: +3"; does not change any state.
func next_daily_amount() -> int:
	if not can_claim_daily():
		return 0
	return _daily_amount(_next_streak(_today()))


func _next_streak(today: String) -> int:
	return streak + 1 if _is_day_before(last_daily, today) else 1


func _daily_amount(for_streak: int) -> int:
	return DAILY_CYCLE_HINTS if for_streak % DAILY_CYCLE == 0 else DAILY_HINTS


## Returns hints granted (0 if already claimed today or the date is before the last claim).
func claim_daily() -> int:
	if not can_claim_daily():
		return 0
	var today := _today()
	streak = _next_streak(today)
	last_daily = today
	var amount := _daily_amount(streak)
	hints += amount
	save_data()
	hints_changed.emit(hints)
	daily_claimed.emit(amount, streak)
	return amount


func _is_day_before(earlier: String, later: String) -> bool:
	if earlier.length() != 10 or later.length() != 10:
		return false
	var a := Time.get_unix_time_from_datetime_string(earlier)
	var b := Time.get_unix_time_from_datetime_string(later)
	return b - a == DAY_SECONDS


# --- Daily puzzle ---

## Today's puzzle as a level index: the same for every player on a date and stable across restarts.
func daily_puzzle_index(level_count: int) -> int:
	if level_count <= 0:
		return 0
	var first := DAILY_PUZZLE_FIRST if level_count > DAILY_PUZZLE_FIRST else 0
	var day := floori(Time.get_unix_time_from_datetime_string(_today()) / float(DAY_SECONDS))
	return first + posmod(day * DAILY_PUZZLE_STRIDE, level_count - first)


## Like the daily gift, a date before the last solve counts as done (no farming by clock changes).
func is_daily_puzzle_done() -> bool:
	return not _today() > daily_puzzle_last


## Records today's solve; returns hints granted (0 if already solved today or the date went back).
func complete_daily_puzzle() -> int:
	if is_daily_puzzle_done():
		return 0
	var today := _today()
	daily_puzzle_streak = daily_puzzle_streak + 1 if _is_day_before(daily_puzzle_last, today) else 1
	daily_puzzle_last = today
	hints += DAILY_PUZZLE_HINTS
	save_data()
	hints_changed.emit(hints)
	return DAILY_PUZZLE_HINTS


## Current run of solved days: kept while today or yesterday was solved, otherwise 0.
func daily_puzzle_streak_count() -> int:
	var today := _today()
	if daily_puzzle_last.is_empty():
		return 0
	if daily_puzzle_last >= today or _is_day_before(daily_puzzle_last, today):
		return daily_puzzle_streak
	return 0


# --- Stars and clears ---

func stars_for(mistakes: int) -> int:
	if mistakes <= 0:
		return 3
	return 2 if mistakes <= 2 else 1


## Returns {"stars", "first_clear", "bonus_hints"}; bonus hints are already added.
func record_clear(level_index: int, mistakes: int) -> Dictionary:
	var key := str(level_index)
	var stars := stars_for(mistakes)
	var first_clear := not best_stars.has(key)
	var bonus := 0
	best_stars[key] = maxi(stars, int(best_stars.get(key, 0)))
	if first_clear:
		levels_cleared += 1
		if levels_cleared % CLEAR_BONUS_EVERY == 0:
			bonus = 1
			hints += bonus
	save_data()
	if bonus:
		hints_changed.emit(hints)
	return {"stars": stars, "first_clear": first_clear, "bonus_hints": bonus}


func get_stars(level_index: int) -> int:
	return int(best_stars.get(str(level_index), 0))


func total_stars() -> int:
	var total := 0
	for value in best_stars.values():
		total += int(value)
	return total


# --- Purchases ---

func set_ads_removed(v: bool) -> void:
	if ads_removed == v:
		return
	ads_removed = v
	save_data()
	ads_removed_changed.emit(v)


func is_ads_removed() -> bool:
	return ads_removed


func own(product_id: String) -> void:
	if not purchased.has(product_id):
		purchased.append(product_id)
		save_data()


func owns(product_id: String) -> bool:
	return purchased.has(product_id)


func token_seen(token: String) -> bool:
	return consumed_tokens.has(token)


func mark_token(token: String) -> void:
	if token.is_empty() or consumed_tokens.has(token):
		return
	consumed_tokens.append(token)
	while consumed_tokens.size() > MAX_TOKENS:
		consumed_tokens.remove_at(0)
	save_data()
