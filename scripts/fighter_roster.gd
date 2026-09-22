extends RefCounted
## Original action fighters with persistent abilities across all four rounds.
## "signature" is a single extra silhouette accessory (see fighter_visual_3d.gd
## _build_model/_update_profile) layered on top of "outfit" so fighters who
## share an outfit archetype (Ish/Sab/Abhi are all "vest") still read as
## distinct individuals at a glance, the way a design like Ryu's headband
## reads instantly against Ken's or Ken's gloves against Guile's.
const PROFILES := [
	{"id":"anug", "name":"ANUG", "title":"The Last Line", "trait":"Goalkeeper dives and saves / low stamina", "color":Color("258d75"), "accent":Color("e9ed91"), "outfit":"keeper", "speed":1.0, "punch_bonus":1, "kick_bonus":0, "chip_bonus":-0.11, "stamina":65.0, "regen":15.0, "stance":"keeper"},
	{"id":"ish", "name":"ISH", "title":"The Flash Hammer", "trait":"Speed and heavy punches / vulnerable to low strikes", "color":Color("c04435"), "accent":Color("ffd28b"), "outfit":"vest", "signature":"headband", "speed":1.16, "punch_bonus":3, "kick_bonus":-2, "chip_bonus":0.0, "stamina":100.0, "regen":19.0, "stance":"sprinter"},
	{"id":"sab", "name":"SAB", "title":"The Iron Grip", "trait":"Heavy punches and guard-beating grabs / low stamina", "color":Color("38475f"), "accent":Color("dd945d"), "outfit":"vest", "signature":"wraps", "build":1.18, "speed":0.94, "punch_bonus":4, "kick_bonus":0, "chip_bonus":0.0, "stamina":65.0, "regen":14.0, "stance":"grappler"},
	{"id":"bib", "name":"BIB", "title":"The Endless Rush", "trait":"High stamina and speed / light punches", "color":Color("247ca9"), "accent":Color("b5f4d9"), "outfit":"suit", "signature":"anklets", "build":0.9, "speed":1.23, "punch_bonus":-2, "kick_bonus":0, "chip_bonus":0.0, "stamina":135.0, "regen":24.0, "stance":"runner"},
	{"id":"abhi", "name":"ABHI", "title":"The Loud Thunder", "trait":"Stamina and heavy punches / weak guard / recovery taunt", "color":Color("9853b3"), "accent":Color("f5d38a"), "outfit":"vest", "signature":"shades", "build":1.1, "speed":1.0, "punch_bonus":3, "kick_bonus":0, "chip_bonus":0.18, "stamina":125.0, "regen":22.0, "stance":"showman"},
	{"id":"sup", "name":"SUP", "title":"The Spiral", "trait":"Swaying footwork, spinning kicks and retreat feints", "color":Color("d1a635"), "accent":Color("91e5cf"), "outfit":"shorts", "hair_style":"braid", "speed":1.1, "punch_bonus":0, "kick_bonus":1, "chip_bonus":0.0, "stamina":105.0, "regen":20.0, "stance":"flow"},
	{"id":"anant", "name":"ANANT", "title":"The Final Word", "trait":"Final boss / complete toolkit / beat him with reads and punishment", "color":Color("272337"), "accent":Color("efbd55"), "outfit":"gi", "signature":"cape", "hair_style":"crest", "build":1.06, "speed":1.12, "punch_bonus":2, "kick_bonus":1, "chip_bonus":-0.04, "stamina":120.0, "regen":21.0, "stance":"master"}
]

## PROFILES entries omit fields that match these defaults (e.g. most
## fighters don't set "build") to keep the roster table readable; merge
## layers each fighter's overrides on top of them.
## Stylized 3D interpretation of assets/concepts/fighters/roster-photo-likeness-v2.png.
## Keep combat identity and tuning independent of costume changes.
const LIKENESS := {
	"anug": {"color":Color("244337"), "accent":Color("d9b45c"), "outfit":"keeper", "signature":"cap", "hair_style":"crop", "build":1.12, "eyewear":"glasses", "facial_hair":"moustache", "skin":Color("b98460")},
	"ish": {"color":Color("8e302c"), "accent":Color("d9a75c"), "outfit":"vest", "signature":"shades", "hair_style":"crop", "build":1.10, "eyewear":"shades", "facial_hair":"stubble", "skin":Color("b87d59")},
	"sab": {"color":Color("283b59"), "accent":Color("c48f49"), "outfit":"vest", "signature":"wraps", "hair_style":"curls", "build":1.30, "eyewear":"glasses", "facial_hair":"none", "skin":Color("c18e68")},
	"bib": {"color":Color("244779"), "accent":Color("a6d6c6"), "outfit":"suit", "signature":"anklets", "hair_style":"curls", "build":0.88, "facial_hair":"moustache", "skin":Color("bb8968")},
	"abhi": {"color":Color("59345f"), "accent":Color("dbb258"), "outfit":"vest", "signature":"open_vest", "hair_style":"waves", "build":1.12, "facial_hair":"goatee", "skin":Color("bf8a63")},
	"sup": {"color":Color("b78b38"), "accent":Color("438d88"), "outfit":"vest", "signature":"sash", "hair_style":"waves", "build":0.97, "facial_hair":"goatee", "skin":Color("ba8665")},
	"anant": {"color":Color("51354f"), "accent":Color("d3ac62"), "outfit":"gi", "signature":"coat", "hair_style":"swept", "build":1.0, "eyewear":"glasses", "facial_hair":"none", "skin":Color("bd8e70")}
}

static func profile(index: int) -> Dictionary:
	var result := {"skin":Color("ba8665"), "hair":Color("241e25"), "hair_style":"swept", "build":1.0, "signature":""}
	result.merge(PROFILES[clampi(index, 0, PROFILES.size() - 1)], true)
	result.merge(LIKENESS[result.id], true)
	return result
