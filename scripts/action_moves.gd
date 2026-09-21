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
	# Original, character-specific strike routes. Finishers use separate slots
	# so learning an easy chain does not replace directional signature moves.
	var finishers := {
		"anug": ["Goal-line clearance", "front_kick", 64, -65, 0.12, 1.10, 1.35],
		"ish": ["Flash rising fist", "uppercut", 57, -94, 0.10, 1.35, 1.1],
		"sab": ["Anvil elbow", "elbow", 53, -85, 0.14, 1.45, 1.0],
		"bib": ["Relay side kick", "side_kick", 70, -66, 0.09, 1.15, 1.2],
		"abhi": ["Thunder overhand", "overhand", 61, -89, 0.15, 1.55, 1.4],
		"sup": ["Spiral heel", "spin", 69, -65, 0.13, 1.25, 1.3],
		"anant": ["Crown knee", "knee", 53, -70, 0.12, 1.35, 1.2]
	}
	var f: Array = finishers.get(id, finishers.anug)
	var kind := "punch" if id in ["ish", "sab", "abhi"] else "kick"
	m.chain_finish = BASE._move(f[0], f[1], kind, "hook" if kind == "punch" else "kick", f[2], f[3], f[4], 0.07, 0.33, f[5], f[6], 18)
	m.chain_bridge = m.cross.duplicate(true)
	m.chain_bridge.name = {"anug":"Keeper palm", "ish":"Flash body shot", "sab":"Iron body hook", "bib":"Relay backfist", "abhi":"Thunder body shot", "sup":"Spiral palm", "anant":"Crown backfist"}.get(id, "Follow-up palm")
	m.chain_bridge.pose = "body_hook" if id in ["ish", "sab", "abhi"] else "backfist"
	m.chain_bridge.startup = 0.09
	m.chain_bridge.reach = 65.0
	m.chain_bridge.lunge = 16.0
	m.chain_bridge.next_light = ""
	m.chain_bridge.next_heavy = "chain_finish"
	m.chain_bridge.special_cancel = false
	m.chain_bridge.hitstun = 0.30
	m.kick.next_light = "chain_bridge"
	m.kick.hitstun = 0.30
	m.kick.push = 0.25
	m.cross.hitstun = 0.30
	m.cross.next_heavy = "chain_finish"
	# Every character has a short-range throw, with different commitment/payoff.
	var throws := {
		"anug": ["Keeper catch", "clinch_shove", 0.24, 1.15, 1.25],
		"ish": ["Flash shoulder toss", "shoulder_throw", 0.22, 1.10, 1.05],
		"sab": ["Iron hip toss", "hip_throw", 0.28, 1.65, 1.45],
		"bib": ["Relay ankle reap", "trip_throw", 0.23, 1.00, 0.9],
		"abhi": ["Thunder clinch", "clinch_shove", 0.30, 1.50, 1.5],
		"sup": ["Spiral reap", "trip_throw", 0.25, 1.20, 1.1],
		"anant": ["Crown shoulder toss", "shoulder_throw", 0.27, 1.40, 1.3]
	}
	var g: Array = throws.get(id, throws.anug)
	m.grapple = BASE._move(g[0], g[1], "grapple", "hook", 32, -72, g[2], 0.07, 0.42, g[3], g[4], 6)
	m.grapple.hitstun = 0.48
	# Stamina costs are assigned by move slot/kind here rather than per-move
	# above, so every fighter's moves stay priced consistently even though
	# their reach/damage/timing differ.
	for key in m:
		m[key].cost = 5.0 if key in ["jab", "cross", "hook", "chain_bridge"] else (18.0 if key in ["drive", "breaker"] else 11.0)
		if m[key].get("utility", "") == "taunt":
			m[key].cost = 0.0
		if m[key].kind == "grapple":
			m[key].cost = 20.0
		if key in ["drive", "breaker"]:
			m[key].hitstun = 0.34
	# Chains end in strikes, not unavoidable grabs or utility actions.
	return m
