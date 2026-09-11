extends RefCounted
## Original characters. Traits layer over round styles without replacing them.
const PROFILES := [
	{"id": "ren", "name": "REN", "title": "The Patient Counter", "trait": "Balanced movement and damage",
		"color": Color("d8e1e9"), "accent": Color("edb64d"), "skin": Color("d6a17c"),
		"hair": Color("202633"), "hair_style": "swept", "outfit": "gi", "build": 1.0,
		"speed": 1.0, "punch_bonus": 0, "kick_bonus": 0, "chip_bonus": 0.0},
	{"id": "nara", "name": "NARA", "title": "The Relentless Striker", "trait": "Heavy strikes +1 damage",
		"color": Color("198e91"), "accent": Color("ffcb75"), "skin": Color("b87952"),
		"hair": Color("222027"), "hair_style": "braid", "outfit": "shorts", "build": 0.92,
		"speed": 1.0, "punch_bonus": 0, "kick_bonus": 1, "chip_bonus": 0.0},
	{"id": "briggs", "name": "BRIGGS", "title": "The Heavy Hitter", "trait": "Punches +1 damage / movement -4%",
		"color": Color("b74745"), "accent": Color("f0d8bd"), "skin": Color("87523f"),
		"hair": Color("241b1c"), "hair_style": "crop", "outfit": "vest", "build": 1.16,
		"speed": 0.96, "punch_bonus": 1, "kick_bonus": 0, "chip_bonus": 0.0},
	{"id": "vale", "name": "VALE", "title": "The Quick Read", "trait": "Movement +6% / reduced guard chip",
		"color": Color("6553b1"), "accent": Color("9fe7cf"), "skin": Color("e0b49a"),
		"hair": Color("ddd2b4"), "hair_style": "crest", "outfit": "suit", "build": 0.96,
		"speed": 1.06, "punch_bonus": 0, "kick_bonus": 0, "chip_bonus": -0.03}
]

static func profile(index: int) -> Dictionary:
	return PROFILES[clampi(index, 0, PROFILES.size() - 1)].duplicate(true)
