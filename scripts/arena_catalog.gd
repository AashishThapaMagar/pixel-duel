extends RefCounted
## Seven illustrated Himalayan arenas share the same combat floor and bounds.
const ARENAS := [
	{"name": "HIMALAYAN LAKE", "tagline": "Snow peaks above a deep blue lake.",
		"texture": "res://assets/backgrounds/himalayan/himalayan_lake.png", "ground_tint": Color.WHITE},
	{"name": "PRAYER FLAG PASS", "tagline": "Wind, prayer flags, and the roof of the world.",
		"texture": "res://assets/backgrounds/himalayan/prayer_flag_pass.png", "ground_tint": Color.WHITE},
	{"name": "LAKESIDE TEMPLE", "tagline": "Temple bells over still water.",
		"texture": "res://assets/backgrounds/himalayan/lakeside_temple.png", "ground_tint": Color.WHITE},
	{"name": "RHODODENDRON GROVE", "tagline": "Crimson flowers beneath the snowy ridge.",
		"texture": "res://assets/backgrounds/himalayan/rhododendron_forest.png", "ground_tint": Color.WHITE},
	{"name": "TERRACE VILLAGE", "tagline": "Green hills and a mountain horizon.",
		"texture": "res://assets/backgrounds/himalayan/terrace_village.png", "ground_tint": Color.WHITE},
	{"name": "MOONLIT MONASTERY", "tagline": "A quiet monastery under a silver moon.",
		"texture": "res://assets/backgrounds/himalayan/moonlit_monastery.png", "ground_tint": Color.WHITE},
	{"name": "SUNRISE SUMMIT", "tagline": "The first light touches the peaks.",
		"texture": "res://assets/backgrounds/himalayan/sunrise_summit.png", "ground_tint": Color.WHITE},
]

static func arena(index: int) -> Dictionary:
	return ARENAS[clampi(index, 0, ARENAS.size() - 1)]