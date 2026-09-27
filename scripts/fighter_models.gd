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
##   width      extra horizontal scale for a heavier or slighter build
##   tint       [body colour, joint colour] painted over the model's materials
##   yaw        extra turn so the model faces the game's +X (glTF faces +Z)
##   clips      logical clip -> animation name inside `scene` or `files`
##   files      optional extra animation files (e.g. one Mixamo download per
##              move, "Without Skin"); their animations are added under the
##              file key, and can be named in `clips`
##   timing     attack clip -> [start, impact, end] seconds of the clip to use;
##              the game's hit frame is lined up with `impact`
##   impact     attack clip -> fraction of the clip where the blow lands, used
##              when there is no `timing` entry (default 0.45)
##
## Logical clips (any missing one falls back, see FALLBACK in
## fighter_animated.gd): idle, walk, walk_back, sidestep, sidestep_left,
## sidestep_right, run, dash, backdash, jump, land, block, block_hit, hit,
## hit_heavy, ko, jab, punch_heavy, uppercut, kick, kick_front, kick_spin,
## grapple, taunt, victory, injured.
##
## Every Mixamo fighter shares the X Bot body and the shared clips below
## (assets/fighters/anug/, downloaded "With Skin"); each fighter's own style
## clips live in assets/fighters/<id>/style/ ("Without Skin"). Mixamo files
## are not redistributable, so they stay local (.gitignore); without them a
## fighter falls back to the procedural rig. Dropping a rigged body.fbx in a
## fighter's folder gives them their own textured model; a body.glb built by
## tools/build_fighter_body.py is grafted onto the shared skeleton instead.
const SHARED := "res://assets/fighters/anug/"
const SHARED_FILES := {
	"idle": "idle", "walk": "walking", "walk_back": "walking_backwards",
	"jab": "lead_jab", "cross": "jab_cross", "hit": "head_hit", "hit_body": "hit_to_body",
	"kick_mid": "mma_kick_2", "kick_front": "mma_kick_1", "kick_high": "mma_kick",
	"ko": "knocked_out", "block": "body_block", "run": "running", "injured": "injured_run",
}
const SHARED_CLIPS := {
	"idle": "idle", "walk": "walk", "walk_back": "walk_back", "jab": "jab",
	"punch_heavy": "cross", "hit": "hit", "hit_heavy": "hit_body", "ko": "ko",
	"kick": "kick_mid", "kick_front": "kick_front", "kick_spin": "kick_high",
	"block": "block", "block_hit": "block", "run": "run", "injured": "injured",
}
## [start, impact, end] seconds, measured from where each fist or foot is
## fully extended. Jab Cross is two punches; heavy punches use the cross.
const SHARED_TIMING := {
	"jab": [0.0, 0.5, 1.2], "punch_heavy": [0.45, 0.7, 1.5],
	"kick": [0.25, 0.6, 1.3], "kick_front": [0.2, 0.6, 1.2], "kick_spin": [0.3, 0.7, 1.4],
}
## Everyone's own walk, back-step, strafes and run from their style folder.
const STYLE_MOVES := {
	"walk": "walk_forward", "walk_back": "walk_back", "sidestep_left": "strafe_left",
	"sidestep_right": "strafe_right", "run": "run",
}
## Per-fighter style: body build and tint, plus style clips (file in
## style/ -> logical clip) and their timing. Impact times were measured
## from each download (peak extension of the striking hand, foot or head).
const STYLES := {
	"anug": {
		"height": 1.8, "width": 1.12, "tint": [Color("2c5a3e"), Color("d9b45c")],
		"clips": {"idle": "idle", "block_hit": "goalkeeper_catch", "backdash": "dodging"},
	},
	"ish": {
		"height": 1.8, "width": 1.0, "tint": [Color("a2322c"), Color("2a2227")],
		"clips": {"idle": "bouncing_fight_idle", "punch_heavy": "hook_punch", "uppercut": "uppercut"},
		"timing": {"punch_heavy": [0.55, 1.13, 1.75], "uppercut": [0.05, 0.47, 1.0]},
	},
	"sab": {
		"height": 1.92, "width": 1.22, "tint": [Color("27375a"), Color("c48f49")],
		"clips": {"idle": "wrestling_idle_mmaidle", "punch_heavy": "headbutt", "grapple": "grab_and_slam"},
		"timing": {"punch_heavy": [0.2, 0.73, 1.5], "grapple": [0.3, 0.93, 3.3]},
	},
	"bib": {
		"height": 1.7, "width": 0.92, "tint": [Color("223f8a"), Color("9fe0c8")],
		"clips": {"idle": "idle", "jab": "jab", "run": "fast_run", "backdash": "dodging"},
		"timing": {"jab": [0.15, 0.57, 1.0]},
	},
	"abhi": {
		"height": 1.82, "width": 1.1, "tint": [Color("5c2f78"), Color("dbb258")],
		"clips": {"idle": "idle", "punch_heavy": "punching_haymaker", "taunt": "taunt", "victory": "victory"},
		"timing": {"punch_heavy": [0.0, 0.4, 1.0], "taunt": [0.0, 0.8, 1.63]},
	},
	"sup": {
		"height": 1.8, "width": 1.0, "tint": [Color("c29a3c"), Color("2f8a86")],
		"clips": {"idle": "capoeira_ginga", "kick": "roundhouse_kick", "kick_spin": "flip_kick"},
		"timing": {"kick": [0.45, 1.07, 1.9], "kick_spin": [0.4, 1.0, 1.8]},
	},
	"anant": {
		"height": 1.86, "width": 1.02, "tint": [Color("5a2f6a"), Color("d3ac62")],
		"clips": {"idle": "mma_idle", "kick": "martial_arts_kick", "kick_spin": "martial_arts_kick", "victory": "fireball"},
		"timing": {"kick": [0.2, 0.73, 1.5], "kick_spin": [0.2, 0.73, 1.5]},
	},
}
## Other entries, kept as examples of the format.
const MODELS := {
	# Test dummy: Kenney "Mini Characters" (CC0), a simple 7-bone rig with
	# idle/walk/sprint/jump/punch/kick/die clips. Rename the key to a fighter
	# id and set enabled to try it.
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
	if STYLES.has(fighter_id):
		return _mixamo(fighter_id)
	var data: Dictionary = MODELS.get(fighter_id, {})
	return data if data.get("enabled", false) else {}

## Shared body and clips, overlaid with the fighter's own style folder.
static func _mixamo(fighter_id: String) -> Dictionary:
	var style: Dictionary = STYLES[fighter_id]
	var folder := "res://assets/fighters/%s/style/" % fighter_id
	var files := {}
	for key in SHARED_FILES:
		files[key] = SHARED + SHARED_FILES[key] + ".fbx"
	var clips: Dictionary = SHARED_CLIPS.duplicate()
	var own: Dictionary = STYLE_MOVES.duplicate()
	own.merge(style.get("clips", {}), true)
	for logical in own:
		var path: String = folder + own[logical] + ".fbx"
		if ResourceLoader.exists(path):
			files["style_" + logical] = path
			clips[logical] = "style_" + logical
	var timing: Dictionary = SHARED_TIMING.duplicate()
	timing.merge(style.get("timing", {}), true)
	# A fighter's own rigged body (assets/fighters/<id>/body.fbx, from Mixamo
	# "With Skin") replaces the X Bot and keeps its real textures untinted.
	var body := "res://assets/fighters/%s/body.fbx" % fighter_id
	var own_body := ResourceLoader.exists(body)
	var built := "res://assets/fighters/%s/body.glb" % fighter_id
	var graft := "" if own_body or not ResourceLoader.exists(built) else built
	return {
		"scene": body if own_body else SHARED + "idle.fbx",
		"body": graft,
		"enabled": ResourceLoader.exists(SHARED + "idle.fbx"),
		"height": style.get("height", 1.8),
		"width": style.get("width", 1.0),
		"tint": [] if own_body or graft != "" else style.get("tint", []),
		"yaw": PI / 2.0,
		"files": files,
		"clips": clips,
		"timing": timing,
	} if ResourceLoader.exists(SHARED + "idle.fbx") else {}
