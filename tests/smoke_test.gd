extends SceneTree
## Headless smoke test: loads the Arena and exercises hit/block/KO/restart
## logic directly (no display or real keyboard needed). Not part of the
## shipped game — run manually with:
##   godot --headless --path . -s res://tests/smoke_test.gd
## Deleting this whole `tests/` folder has zero effect on the actual game.

var arena: Node
var frame: int = 0
var failures: Array = []
var done: bool = false

func _initialize() -> void:
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn")
	arena = arena_scene.instantiate()
	get_root().add_child(arena)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3 and not done:
		_run_tests()
		done = true
	if frame >= 6:
		return true
	return false

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func _run_tests() -> void:
	var p1 = arena.get_node("Player1")
	var p2 = arena.get_node("Player2")

	_check(p1.health == 100, "p1 should start at 100 hp, got %s" % p1.health)
	_check(p2.health == 100, "p2 should start at 100 hp, got %s" % p2.health)

	# Force deterministic facing (normally set each physics frame from position).
	p1.facing = 1
	p2.facing = -1

	# p1 (facing right) hits p2 for 20, p2 not blocking -> full damage.
	p2.take_hit(20, 200, 1)
	_check(p2.health == 80, "p2 should drop to 80 hp after a 20-dmg hit, got %s" % p2.health)

	# p2 (facing left) hits p1 while p1 blocks -> chip damage only.
	p1.state = p1.State.BLOCK
	p1.take_hit(20, 200, -1)
	var expected_chip: int = int(ceil(20 * p1.block_chip_multiplier))
	_check(p1.health == 100 - expected_chip,
		"blocked hit should chip %s dmg -> %s hp, got %s" % [expected_chip, 100 - expected_chip, p1.health])

	# Lethal hit -> KO + round should end.
	p2.take_hit(200, 300, 1)
	_check(p2.health == 0, "p2 should be at 0 hp after a lethal hit, got %s" % p2.health)
	_check(p2.state == p2.State.KO, "p2 should be in KO state after lethal hit")
	_check(arena.round_active == false, "round_active should be false after a KO")

	# Restart should fully heal both fighters and reactivate the round.
	arena._start_new_round()
	_check(p1.health == 100 and p2.health == 100, "restart should reset both fighters to full hp")
	_check(arena.round_active == true, "restart should reactivate the round")

	if failures.is_empty():
		print("SMOKE_TEST: ALL PASS")
	else:
		for f in failures:
			print("SMOKE_TEST FAIL: " + f)
