extends Node
## Autoload (see project.godot): the player's fight record, kept across
## sessions in user://records.cfg. The menus show it (main menu splash strip,
## Records page, per-fighter lines on the select screen); arena.gd reports
## each finished match and round. Nothing in combat reads it.
const SAVE_PATH := "user://records.cfg"
const MODE_NAMES := {"local": "VS BATTLE", "ai": "VS COMPUTER", "arcade": "ARCADE", "story": "STORY"}
## Totals: matches, wins, losses, draws, rounds, round_wins, kos, perfects,
## arcade_clears, streak, best_streak, seconds.
var totals: Dictionary = {}
## Per mode key: {matches, wins}.
var modes: Dictionary = {}
## Per fighter id: {picks, wins, kos}.
var fighters: Dictionary = {}
## Last finished match: {mode, p1, p2, won, score} for the menu strip.
var last: Dictionary = {}
var _session_start := 0

func _ready() -> void:
	_session_start = Time.get_ticks_msec()
	_load()

## Which mode a match was played in, from the shared MatchSetup state.
static func mode_key(setup: Node) -> String:
	return "story" if setup.story else ("arcade" if setup.arcade else ("ai" if setup.vs_ai else "local"))

## One round finished. `winner` is 1, 2 or 0 (draw); `knockout` when it
## ended on a KO; `perfect` when the winner never took damage.
func record_round(winner: int, knockout: bool, perfect: bool) -> void:
	totals.rounds += 1
	if winner == 1:
		totals.round_wins += 1
		if knockout:
			totals.kos += 1
		if perfect:
			totals.perfects += 1
	_save()

## A whole match finished: player one's fighter id, the rival's, the
## match winner (1, 2, 0) and the round score.
func record_match(mode: String, p1_id: String, p2_id: String, winner: int, score: Array) -> void:
	totals.matches += 1
	var won := winner == 1
	if won:
		totals.wins += 1
		totals.streak += 1
		totals.best_streak = maxi(totals.best_streak, totals.streak)
	elif winner == 2:
		totals.losses += 1
		totals.streak = 0
	else:
		totals.draws += 1
	if not modes.has(mode):
		modes[mode] = {"matches": 0, "wins": 0}
	modes[mode].matches += 1
	if won:
		modes[mode].wins += 1
	var mine: Dictionary = fighter_record(p1_id)
	mine.picks += 1
	if won:
		mine.wins += 1
	fighters[p1_id] = mine
	last = {"mode": mode, "p1": p1_id, "p2": p2_id, "won": won, "draw": winner == 0, "score": [int(score[0]), int(score[1])]}
	_save()

func record_arcade_clear() -> void:
	totals.arcade_clears += 1
	_save()

func fighter_record(id: String) -> Dictionary:
	var record: Dictionary = {"picks": 0, "wins": 0}
	record.merge(fighters.get(id, {}), true)
	return record

func win_rate() -> int:
	return roundi(100.0 * totals.wins / maxf(totals.matches, 1.0)) if totals.matches > 0 else 0

## The fighter picked most often, or "" before any match.
func favourite() -> String:
	var best := ""
	var most := 0
	for id in fighters:
		if int(fighters[id].picks) > most:
			most = int(fighters[id].picks)
			best = id
	return best

## Total time in the game, including this session, in whole hours and minutes.
func play_time() -> String:
	var seconds: int = int(totals.seconds) + (Time.get_ticks_msec() - _session_start) / 1000
	return "%dH %02dM" % [seconds / 3600, (seconds % 3600) / 60]

func reset() -> void:
	totals = _blank_totals()
	modes = {}
	fighters = {}
	last = {}
	_session_start = Time.get_ticks_msec()
	_save()

static func _blank_totals() -> Dictionary:
	return {"matches": 0, "wins": 0, "losses": 0, "draws": 0, "rounds": 0, "round_wins": 0, "kos": 0,
		"perfects": 0, "arcade_clears": 0, "streak": 0, "best_streak": 0, "seconds": 0}

func _load() -> void:
	totals = _blank_totals()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in totals:
		totals[key] = cfg.get_value("totals", key, totals[key])
	modes = cfg.get_value("record", "modes", {})
	fighters = cfg.get_value("record", "fighters", {})
	last = cfg.get_value("record", "last", {})

func _save() -> void:
	var cfg := ConfigFile.new()
	var seconds: int = int(totals.seconds) + (Time.get_ticks_msec() - _session_start) / 1000
	_session_start = Time.get_ticks_msec()
	totals.seconds = seconds
	for key in totals:
		cfg.set_value("totals", key, totals[key])
	cfg.set_value("record", "modes", modes)
	cfg.set_value("record", "fighters", fighters)
	cfg.set_value("record", "last", last)
	cfg.save(SAVE_PATH)
