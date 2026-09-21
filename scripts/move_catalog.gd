extends RefCounted
## Technique names are researched; frame data and cancel routes are arcade
## design choices. See docs/move-research.md for sources and scope.

static func _move(label: String, pose: String, kind: String, base: String, reach: float, height: float,
	startup: float, active: float, recovery: float, damage: float, push: float, lunge: float = 0.0) -> Dictionary:
	return {"name": label, "pose": pose, "kind": kind, "base": base, "reach": reach, "height": height,
		"startup": startup, "active": active, "recovery": recovery, "damage": damage, "push": push,
		"lunge": lunge, "next_light": "", "next_heavy": "",
		"hitstun": 0.25, "blockstun": 0.15, "cancel_window": 0.1, "special_cancel": false}

static func for_style(style_id: String) -> Dictionary:
	var moves := {
		"jab": _move("Jab", "jab", "punch", "punch", 58, -88, 0.05, 0.05, 0.15, 1.0, 0.3),
		"cross": _move("Cross", "cross", "punch", "punch", 64, -88, 0.07, 0.05, 0.19, 1.25, 0.35, 8),
		"hook": _move("Lead hook", "hook", "punch", "hook", 46, -92, 0.09, 0.06, 0.23, 1.0, 0.8, 18),
		"kick": _move("Round kick", "kick", "kick", "kick", 64, -66, 0.12, 0.08, 0.23, 1.0, 1.0),
		"forward_heavy": _move("Front kick", "front_kick", "kick", "kick", 65, -60, 0.11, 0.07, 0.22, 0.85, 1.15),
		"back_heavy": _move("Straight knee", "knee", "kick", "kick", 33, -69, 0.10, 0.07, 0.24, 1.1, 0.8, 20)
	}
	match style_id:
		"karate":
			moves.jab.name = "Kizami-zuki / lead straight"
			moves.cross.name = "Gyaku-zuki / reverse straight"
			moves.hook = _move("Uraken / backfist", "backfist", "punch", "hook", 53, -97, 0.08, 0.05, 0.22, 0.95, 0.8, 12)
			moves.kick = _move("Mae-geri / front kick", "front_kick", "kick", "kick", 64, -60, 0.10, 0.07, 0.22, 1.0, 1.0)
			moves.forward_heavy = _move("Mawashi-geri / roundhouse", "kick", "kick", "kick", 64, -72, 0.12, 0.08, 0.25, 1.15, 1.0)
			moves.back_heavy = _move("Yoko-geri / side kick", "side_kick", "kick", "kick", 67, -65, 0.14, 0.08, 0.27, 1.2, 1.2)
		"muay_thai":
			moves.hook = _move("Horizontal elbow", "elbow", "punch", "hook", 33, -95, 0.08, 0.07, 0.23, 1.2, 0.65, 26)
			moves.forward_heavy.name = "Teep / push kick"
		"boxing":
			moves.kick = _move("Rear hook", "rear_hook", "punch", "hook", 48, -91, 0.10, 0.06, 0.22, 1.05, 1.0, 10)
			moves.forward_heavy = _move("Rear uppercut", "uppercut", "punch", "hook", 39, -89, 0.10, 0.06, 0.25, 1.2, 1.0, 25)
			moves.back_heavy = _move("Lead body hook", "body_hook", "punch", "hook", 44, -64, 0.09, 0.06, 0.24, 1.1, 0.8, 16)
		"mma":
			moves.hook = _move("Overhand", "overhand", "punch", "hook", 55, -94, 0.12, 0.06, 0.26, 1.2, 1.0, 12)
			moves.kick.name = "Body round kick"
	moves.jab.next_light = "cross"
	moves.jab.startup = 5.0 / 60.0
	moves.cross.startup = 7.0 / 60.0
	moves.jab.hitstun = 14.0 / 60.0
	moves.cross.hitstun = 17.0 / 60.0
	moves.jab.blockstun = 8.0 / 60.0
	moves.cross.blockstun = 10.0 / 60.0
	moves.jab.special_cancel = true
	moves.cross.special_cancel = true
	# Original motion-command enders: committed approach vs. slower space-maker.
	moves.drive = _move("Driving straight", "cross", "punch", "hook", 62, -88, 10.0 / 60.0, 4.0 / 60.0, 23.0 / 60.0, 1.6, 1.35, 35)
	moves.breaker = _move("Turning side kick", "side_kick", "kick", "kick", 70, -65, 19.0 / 60.0, 5.0 / 60.0, 28.0 / 60.0, 1.65, 1.7, 10)
	if style_id == "muay_thai":
		moves.drive = _move("Step-in knee", "knee", "kick", "kick", 35, -69, 11.0 / 60.0, 4.0 / 60.0, 24.0 / 60.0, 1.4, 1.2, 42)
		moves.breaker.name = "Power teep"
		moves.breaker.pose = "front_kick"
	elif style_id == "boxing":
		moves.drive.name = "Step-in cross"
		moves.breaker = _move("Shovel uppercut", "uppercut", "punch", "hook", 42, -89, 17.0 / 60.0, 5.0 / 60.0, 28.0 / 60.0, 1.8, 1.7, 28)
	elif style_id == "mma":
		moves.drive.name = "Driving overhand"
		moves.drive.pose = "overhand"
		moves.breaker.name = "Power body kick"
		moves.breaker.pose = "kick"
	for id in ["drive", "breaker"]:
		moves[id].hitstun = 20.0 / 60.0
		moves[id].blockstun = 13.0 / 60.0
	moves.jab.next_heavy = "kick"
	moves.cross.next_light = "hook"
	moves.cross.next_heavy = "back_heavy" if style_id == "muay_thai" else ("kick" if style_id == "mma" else "forward_heavy")
	return moves

static func guide(style_id: String, custom_moves: Dictionary = {}) -> String:
	var moves := for_style(style_id) if custom_moves.is_empty() else custom_moves
	var result := "LIGHT: F (P1) / K (P2)     HEAVY: G (P1) / L (P2)\nForward / back are relative to your opponent.\n\n"
	var commands := ["Light", "Forward + light", "Back + light", "Heavy", "Forward + heavy", "Back + heavy", "Down, down-forward, forward + heavy", "Down, down-back, back + heavy"]
	var ids := ["jab", "cross", "hook", "kick", "forward_heavy", "back_heavy", "drive", "breaker"]
	for i in ids.size():
		var move: Dictionary = moves[ids[i]]
		var on_block := roundi((float(move.blockstun) - float(move.active) - float(move.recovery)) * 60)
		result += "%s  —  %s\n    %df startup / %df active / %df recovery / %+d on block*\n" % [commands[i], move.name, roundi(move.startup * 60), roundi(move.active * 60), roundi(move.recovery * 60), on_block]
	result += "\nPUNCH CHAIN: Light > Light > Light\n%s > %s > %s\n" % [moves.jab.name, moves.cross.name, moves.hook.name]
	result += "\nMIXED CHAIN: Light > Light > Heavy\n%s > %s > %s\n" % [moves.jab.name, moves.cross.name, moves[moves.cross.next_heavy].name]
	if moves.has("grapple"):
		result += "\nGRAPPLE: H (P1) / J (P2), or Light + Heavy together\n%s / close range / %df startup\n" % [moves.grapple.name, roundi(moves.grapple.startup * 60)]
		result += "Beats guard; loses to jumping, spacing and interruption. Tap grapple or Light + Heavy just before contact to escape. Throws cannot combo from hitstun.\n"
		result += "\nKICK ROUTE: Heavy > Light > Heavy\n%s > %s > %s\n" % [moves.kick.name, moves.chain_bridge.name, moves.chain_finish.name]
		result += "P1: F F G or G F G. P2: K K L or L K L. Release directions and tap each button as the previous strike connects.\n"
	result += "\nCOMMAND ENDER: Light > Light > quarter-circle forward + Heavy\nDown is S (P1) / Down arrow (P2). Roll through the diagonal, finish forward, then press Heavy.\nComplete the motion within 0.4 seconds. Directions mirror when you switch sides."
	result += "\nPress each button separately as the previous hit connects.\nOnly landed hits allow a cancel, within 6 frames after active frames end.\nGuard or whiff denies the cancel. Command enders have long, punishable recovery.\nCounter hit: catch startup for +20% damage and 6 extra stun frames.\nPunish: catch recovery. True combos scale to a 40% damage floor.\n*On-block figures assume earliest contact, rounded to 60 Hz; later contact changes advantage."
	return result
