extends RefCounted
## Per-fighter move tables for live (action.tres) matches: starts from the
## shared "action" style's generic six normals + two enders, then reskins
## names/poses and swaps in signature moves per character id. Player.gd
## reads these through available_moves() instead of move_catalog's
## style-generic tables whenever is_action_fight() is true.
const BASE := preload("res://scripts/move_catalog.gd")

static func for_fighter(id: String) -> Dictionary:
	var m := BASE.for_style("action")
	m.jab.name = "Quick check"
	m.cross.name = "Step straight"
	m.hook.name = "Turnaround fist"
	m.kick.name = "Arc kick"
	m.forward_heavy.name = "Push kick"
	m.back_heavy.name = "Rising knee"
	match id:
		"anug":
			m.jab.name = "Glove check"
			m.cross.name = "Clearance punch"
			m.hook.name = "Palm deflection"
			m.drive = BASE._move("Diving clearance", "dive", "punch", "hook", 66, -69, 0.22, 0.10, 0.42, 1.55, 1.25, 52)
			m.breaker = BASE._move("High-ball punch", "uppercut", "punch", "hook", 42, -98, 0.18, 0.08, 0.38, 1.65, 1.5, 16)
			m.back_heavy = BASE._move("Low save", "save", "punch", "hook", 47, -50, 0.14, 0.07, 0.28, 1.1, 1.0, 18)
		"ish":
			m.jab.name = "Flash jab"
			m.cross.name = "Hammer straight"
			m.drive.name = "Flash hammer"
			m.drive.lunge = 46.0
			m.breaker = BASE._move("Sky hammer", "uppercut", "punch", "hook", 42, -96, 0.25, 0.07, 0.43, 1.8, 1.5, 20)
		"sab":
			m.jab.name = "Iron check"
			m.hook.name = "Anvil hook"
			m.forward_heavy = BASE._move("Clinch toss", "grapple", "grapple", "hook", 30, -72, 0.28, 0.06, 0.45, 1.5, 1.4, 8)
			m.breaker = BASE._move("Iron-grip throw", "grapple", "grapple", "hook", 32, -72, 0.32, 0.08, 0.52, 1.9, 1.7, 10)
			m.drive.name = "Battering ram"
			m.drive.pose = "overhand"
		"bib":
			m.jab.name = "Needle check"
			m.cross.name = "Rapid straight"
			m.kick.name = "Running arc"
			m.drive = BASE._move("Rush kick", "side_kick", "kick", "kick", 68, -65, 0.17, 0.07, 0.30, 1.1, 1.0, 43)
			m.breaker.name = "Relay wheel"
			m.breaker.pose = "spin"
		"abhi":
			m.cross.name = "Thunder straight"
			m.hook.name = "Mic drop"
			m.drive.name = "Loud thunder"
			m.drive.pose = "overhand"
			m.back_heavy = BASE._move("Big talk / recover 24 stamina", "taunt", "punch", "punch", 0, -88, 0.22, 0.02, 0.66, 0, 0)
			m.back_heavy.utility = "taunt"
		"sup":
			m.jab.name = "Swaying palm"
			m.kick = BASE._move("Low spiral", "sweep", "kick", "kick", 62, -28, 0.17, 0.08, 0.30, 0.95, 0.8)
			m.drive = BASE._move("Cartwheel strike", "cartwheel", "kick", "kick", 65, -70, 0.24, 0.10, 0.39, 1.4, 1.25, 30)
			m.breaker.name = "Spiral wheel"
			m.breaker.pose = "spin"
			m.back_heavy = BASE._move("Slip away / retreat feint", "feint", "punch", "punch", 0, -88, 0.18, 0.02, 0.20, 0, 0, -45)
			m.back_heavy.utility = "feint"
		"anant":
			m.jab.name = "First word"
			m.cross.name = "Sovereign straight"
			m.hook.name = "Royal backfist"
			m.hook.pose = "backfist"
			m.drive.name = "Final word"
			m.breaker.name = "Crown wheel"
			m.breaker.pose = "spin"
			m.back_heavy = BASE._move("Sovereign throw", "grapple", "grapple", "hook", 30, -72, 0.30, 0.07, 0.48, 1.5, 1.4, 8)
	# Stamina costs are assigned by move slot/kind here rather than per-move
	# above, so every fighter's moves stay priced consistently even though
	# their reach/damage/timing differ.
	for key in m:
		m[key].cost = 5.0 if key in ["jab", "cross", "hook"] else (18.0 if key in ["drive", "breaker"] else 11.0)
		if m[key].get("utility", "") == "taunt":
			m[key].cost = 0.0
		if m[key].kind == "grapple":
			m[key].cost = 20.0
		if key in ["drive", "breaker"]:
			m[key].hitstun = 0.34
	# Chains end in strikes, not unavoidable grabs or utility actions.
	m.cross.next_heavy = "kick"
	return m
