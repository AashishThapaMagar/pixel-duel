extends RefCounted
## Which fighters use a skinned, animated 3D model instead of the procedural
## rig (see fighter_animated.gd). A fighter with no entry, or with "enabled"
## false, keeps the procedural model, so characters can be swapped in one at
## a time.
##
## Entry keys:
##   scene      res:// path of the character (.glb/.fbx/.tscn, rigged)
##   enabled    set true to use it in game
##   height     standing height in metres the model is scaled to
##   yaw        extra turn so the model faces the game's +X (glTF faces +Z)
##   clips      logical clip -> animation name inside `scene` or `files`
##   files      optional extra animation files (e.g. one Mixamo download per
##              move, "Without Skin"); their animations are added under the
##              file name without extension, and can be named in `clips`
##   impact     attack clip -> fraction of the clip where the blow lands;
##              the game's hit timing is lined up to it (default 0.45)
##
## Logical clips (any missing one falls back, see FALLBACK in
## fighter_animated.gd): idle, walk, walk_back, sidestep, run, dash, jump,
## land, block, block_hit, hit, hit_heavy, ko, jab, punch_heavy, kick,
## kick_spin, grapple, taunt.
const MODELS := {
	# Test dummy wired to Anug: Kenney "Mini Characters" (CC0), a simple
	# 7-bone rig with idle/walk/sprint/jump/punch/kick/die clips. Proves the
	# pipeline; replace with the real Anug model when it's ready.
	"anug": {
		"scene": "res://assets/fighters/test-kenney/character-male-a.glb",
		"enabled": false,
		"height": 1.85,
		"yaw": PI / 2.0,
		"clips": {
			"idle": "idle", "walk": "walk", "run": "sprint", "jump": "jump",
			"land": "fall", "jab": "attack-melee-right", "punch_heavy": "attack-melee-left",
			"kick": "attack-kick-right", "kick_spin": "attack-kick-left", "ko": "die",
			"hit": "emote-no", "block": "crouch", "taunt": "emote-yes", "grapple": "pick-up",
		},
		"impact": {"jab": 0.45, "punch_heavy": 0.45, "kick": 0.5, "kick_spin": 0.5},
	},
}

static func entry(fighter_id: String) -> Dictionary:
	var data: Dictionary = MODELS.get(fighter_id, {})
	return data if data.get("enabled", false) else {}
