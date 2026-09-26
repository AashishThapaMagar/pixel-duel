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
	# Mixamo X Bot with Mixamo animations. The files were downloaded "With
	# Skin", so each one carries the body; idle.fbx supplies it.
	"anug": {
		"scene": "res://assets/fighters/anug/idle.fbx",
		"enabled": true,
		"height": 1.8,
		"yaw": PI / 2.0,
		"files": {
			"idle": "res://assets/fighters/anug/idle.fbx",
			"walk": "res://assets/fighters/anug/walking.fbx",
			"walk_back": "res://assets/fighters/anug/walking_backwards.fbx",
			"jab": "res://assets/fighters/anug/lead_jab.fbx",
			"cross": "res://assets/fighters/anug/jab_cross.fbx",
			"body": "res://assets/fighters/anug/body_jab_cross.fbx",
			"hit": "res://assets/fighters/anug/head_hit.fbx",
			"hit_body": "res://assets/fighters/anug/hit_to_body.fbx",
			"kick_mid": "res://assets/fighters/anug/mma_kick_2.fbx",
			"kick_front": "res://assets/fighters/anug/mma_kick_1.fbx",
			"kick_high": "res://assets/fighters/anug/mma_kick.fbx",
			"ko": "res://assets/fighters/anug/knocked_out.fbx",
		},
		"clips": {
			"idle": "idle", "walk": "walk", "walk_back": "walk_back", "jab": "jab",
			"punch_heavy": "cross", "hit": "hit", "hit_heavy": "hit_body", "ko": "ko",
			"kick": "kick_mid", "kick_front": "kick_front", "kick_spin": "kick_high",
		},
		# [start, impact, end] seconds, measured from where each fist or foot
		# is fully extended. Jab Cross is two punches; heavy punches use the
		# cross. Mid kick = Mma Kick (2), front = (1), high/spin = Mma Kick.
		"timing": {
			"jab": [0.0, 0.5, 1.2], "punch_heavy": [0.45, 0.7, 1.5],
			"kick": [0.25, 0.6, 1.3], "kick_front": [0.2, 0.6, 1.2], "kick_spin": [0.3, 0.7, 1.4],
		},
	},
	# Test dummy: Kenney "Mini Characters" (CC0), a simple 7-bone rig with
	# idle/walk/sprint/jump/punch/kick/die clips. Kept as a pipeline example
	# under an unused id; rename the key to a fighter id to try it.
	"kenney_test": {
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
