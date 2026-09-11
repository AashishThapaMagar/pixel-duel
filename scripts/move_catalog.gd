extends RefCounted
## Technique names are researched; frame data and cancel routes are arcade
## design choices. See docs/move-research.md for sources and scope.

static func _move(label: String, pose: String, kind: String, base: String, reach: float, height: float,
	startup: float, active: float, recovery: float, damage: float, push: float, lunge: float = 0.0) -> Dictionary:
	return {"name": label, "pose": pose, "kind": kind, "base": base, "reach": reach, "height": height,
		"startup": startup, "active": active, "recovery": recovery, "damage": damage, "push": push,
		"lunge": lunge, "next_light": "", "next_heavy": ""}

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
	moves.jab.next_heavy = "kick"
	moves.cross.next_light = "hook"
	moves.cross.next_heavy = "back_heavy" if style_id == "muay_thai" else ("kick" if style_id == "mma" else "forward_heavy")
	return moves

static func guide(style_id: String) -> String:
	var moves := for_style(style_id)
	var result := "LIGHT: F (P1) / K (P2)     HEAVY: G (P1) / L (P2)\nForward / back are relative to your opponent.\n\n"
	var commands := ["Light", "Forward + light", "Back + light", "Heavy", "Forward + heavy", "Back + heavy"]
	var ids := ["jab", "cross", "hook", "kick", "forward_heavy", "back_heavy"]
	for i in ids.size():
		result += "%s  —  %s\n" % [commands[i], moves[ids[i]].name]
	result += "\nPUNCH CHAIN: Light > Light > Light\n%s > %s > %s\n" % [moves.jab.name, moves.cross.name, moves.hook.name]
	result += "\nMIXED CHAIN: Light > Light > Heavy\n%s > %s > %s\n" % [moves.jab.name, moves.cross.name, moves[moves.cross.next_heavy].name]
	result += "\nPress each button separately as the previous hit connects.\nOnly landed hits allow an early chain. Guard or whiff breaks the route."
	return result
